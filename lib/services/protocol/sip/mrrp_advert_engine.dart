// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP advertisement engine — SERVICE_ADVERT broadcast, SERVICE_DIR_REQ/RESP,
/// and remote peer advert cache.
///
/// The advert engine is responsible for:
/// - Periodically broadcasting SERVICE_ADVERT frames (jittered interval)
/// - Handling inbound SERVICE_DIR_REQ and responding with SERVICE_DIR_RESP
/// - Caching discovered services from remote peers
/// - Deduplicating adverts by payload hash
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/logging.dart';
import 'mrrp_codec.dart';
import 'mrrp_constants.dart';
import 'mrrp_counters.dart';
import 'mrrp_frame.dart';
import 'mrrp_messages_advert.dart';
import 'mrrp_service_registry.dart';
import 'mrrp_types.dart';

/// Key for the advert cache: (nodeId, serviceId).
typedef _AdvertCacheKey = ({int nodeId, int serviceId});

/// Cached service entry from a remote peer.
class MrrpCachedService {
  final int nodeId;
  final MrrpAdvertDescriptor descriptor;
  final DateTime cachedAt;

  MrrpCachedService({
    required this.nodeId,
    required this.descriptor,
    required this.cachedAt,
  });

  /// Whether this cache entry has expired.
  bool get isExpired =>
      DateTime.now().difference(cachedAt).inSeconds >
      MrrpConstants.mrrpAdvertCacheTtlS;
}

/// MRRP advertisement engine.
///
/// Manages SERVICE_ADVERT broadcasting and remote peer service caching.
class MrrpAdvertEngine {
  final MrrpServiceRegistry _registry;

  /// Callback to send a raw MRRP frame via SIP transport.
  Future<bool> Function(Uint8List payload)? onSend;

  /// Callback when the advert cache changes.
  void Function()? onCacheChanged;

  /// Instrumentation counters (optional, injected by provider layer).
  MrrpCounters? counters;

  /// Cache of discovered services from remote peers.
  final Map<_AdvertCacheKey, MrrpCachedService> _advertCache = {};

  /// Last known advert hash per peer for dedup.
  final Map<int, String> _lastAdvertHash = {};

  /// Timer for periodic SERVICE_ADVERT broadcast.
  Timer? _advertTimer;

  /// Random source for jitter.
  final Random _random;

  MrrpAdvertEngine({
    required MrrpServiceRegistry registry,
    this.onSend,
    this.onCacheChanged,
    Random? random,
  }) : _registry = registry,
       _random = random ?? Random();

  /// Start the periodic SERVICE_ADVERT broadcast.
  void start() {
    _scheduleNextAdvert();
    AppLogging.mrrp(
      'MRRP_ADVERT: SERVICE_ADVERT scheduled, '
      'interval=${MrrpConstants.mrrpAdvertIntervalS}s+jitter', // lint-allow: hardcoded-string
    );
  }

  /// Stop the periodic broadcast.
  void stop() {
    _advertTimer?.cancel();
    _advertTimer = null;
  }

  /// Dispose: stop timer and clear caches.
  void dispose() {
    stop();
    _advertCache.clear();
    _lastAdvertHash.clear();
  }

  // ---------------------------------------------------------------------------
  // Outbound: SERVICE_ADVERT broadcast
  // ---------------------------------------------------------------------------

  void _scheduleNextAdvert() {
    final jitter = _random.nextInt(MrrpConstants.mrrpAdvertJitterS);
    final delayS = MrrpConstants.mrrpAdvertIntervalS + jitter;
    _advertTimer?.cancel();
    _advertTimer = Timer(Duration(seconds: delayS), _broadcastAdvert);
  }

  Future<void> _broadcastAdvert() async {
    if (_registry.isEmpty) {
      _scheduleNextAdvert();
      return;
    }

    final payload = _registry.buildAdvertPayload();
    if (payload == null) {
      _scheduleNextAdvert();
      return;
    }

    final frame = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.serviceAdvert,
      flags: 0,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: 0,
      serviceId: 0,
      actionId: 0,
      payloadLen: payload.length,
      payload: payload,
    );

    final encoded = MrrpCodec.encode(frame);
    if (encoded == null) {
      _scheduleNextAdvert();
      return;
    }

    final sent = await onSend?.call(encoded) ?? false;
    if (sent) {
      counters?.recordServiceAdvertSent();
      AppLogging.mrrp(
        'MRRP_ADVERT: SERVICE_ADVERT broadcast, '
        '${_registry.count} services, '
        '${encoded.length}B total', // lint-allow: hardcoded-string
      );
    }

    _scheduleNextAdvert();
  }

  // ---------------------------------------------------------------------------
  // Inbound: SERVICE_ADVERT from remote peer
  // ---------------------------------------------------------------------------

  /// Handle an inbound SERVICE_ADVERT frame from a remote peer.
  void handleServiceAdvert(MrrpFrame frame, int senderNodeId) {
    final descriptors = MrrpMessagesAdvert.decodeAdvertPayload(frame.payload);
    if (descriptors == null) {
      AppLogging.mrrp(
        'MRRP_ADVERT: malformed SERVICE_ADVERT from '
        'node=0x${senderNodeId.toRadixString(16)}', // lint-allow: hardcoded-string
      );
      return;
    }

    // Dedup: compare payload hash with last seen for this peer.
    final payloadHash = sha256.convert(frame.payload).toString();
    if (_lastAdvertHash[senderNodeId] == payloadHash) {
      AppLogging.mrrp(
        'MRRP_ADVERT: duplicate advert from '
        'node=0x${senderNodeId.toRadixString(16)}, '
        'hash unchanged, skipped', // lint-allow: hardcoded-string
      );
      return;
    }
    _lastAdvertHash[senderNodeId] = payloadHash;

    _cacheServicesFromPeer(senderNodeId, descriptors);
  }

  // ---------------------------------------------------------------------------
  // Inbound: SERVICE_DIR_REQ
  // ---------------------------------------------------------------------------

  /// Handle an inbound SERVICE_DIR_REQ. Returns a SERVICE_DIR_RESP frame.
  MrrpFrame? handleServiceDirReq(MrrpFrame request, int senderNodeId) {
    AppLogging.mrrp(
      'MRRP_ADVERT: SERVICE_DIR_REQ received from '
      'node=0x${senderNodeId.toRadixString(16)}', // lint-allow: hardcoded-string
    );

    final allDescriptors = _registry.getAll();
    final advertDescriptors = allDescriptors.map((d) {
      return MrrpAdvertDescriptor(
        serviceId: d.serviceId,
        serviceType: d.serviceType,
        versionMajor: d.versionMajor,
        versionMinor: d.versionMinor,
        serviceFlags: d.serviceFlags,
        metadata: d.metadata,
      );
    }).toList();

    final respPayload = MrrpMessagesAdvert.encodeDirectoryResponse(
      advertDescriptors,
    );
    if (respPayload == null) return null;

    AppLogging.mrrp(
      'MRRP_ADVERT: SERVICE_DIR_RESP sent to '
      'node=0x${senderNodeId.toRadixString(16)}, '
      '${advertDescriptors.length} services, '
      '${respPayload.length}B', // lint-allow: hardcoded-string
    );

    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.serviceDirResp,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: 0,
      actionId: 0,
      payloadLen: respPayload.length,
      payload: respPayload,
    );
  }

  // ---------------------------------------------------------------------------
  // Inbound: SERVICE_DIR_RESP
  // ---------------------------------------------------------------------------

  /// Handle an inbound SERVICE_DIR_RESP from a remote peer.
  void handleServiceDirResp(MrrpFrame frame, int senderNodeId) {
    final descriptors = MrrpMessagesAdvert.decodeAdvertPayload(frame.payload);
    if (descriptors == null) {
      AppLogging.mrrp(
        'MRRP_ADVERT: malformed SERVICE_DIR_RESP from '
        'node=0x${senderNodeId.toRadixString(16)}', // lint-allow: hardcoded-string
      );
      return;
    }
    _cacheServicesFromPeer(senderNodeId, descriptors);
  }

  // ---------------------------------------------------------------------------
  // Advert cache management
  // ---------------------------------------------------------------------------

  void _cacheServicesFromPeer(
    int nodeId,
    List<MrrpAdvertDescriptor> descriptors,
  ) {
    final now = DateTime.now();

    // Enforce max tracked peers by evicting oldest if needed.
    final trackedPeers = _advertCache.keys.map((k) => k.nodeId).toSet();
    if (!trackedPeers.contains(nodeId) &&
        trackedPeers.length >= MrrpConstants.mrrpMaxTrackedPeers) {
      _evictOldestPeer();
    }

    for (final d in descriptors) {
      final key = (nodeId: nodeId, serviceId: d.serviceId);
      _advertCache[key] = MrrpCachedService(
        nodeId: nodeId,
        descriptor: d,
        cachedAt: now,
      );
    }

    AppLogging.mrrp(
      'MRRP_ADVERT: cached ${descriptors.length} services from '
      'node=0x${nodeId.toRadixString(16)}', // lint-allow: hardcoded-string
    );

    onCacheChanged?.call();
  }

  void _evictOldestPeer() {
    if (_advertCache.isEmpty) return;

    DateTime? oldest;
    int? oldestPeer;

    for (final entry in _advertCache.entries) {
      if (oldest == null || entry.value.cachedAt.isBefore(oldest)) {
        oldest = entry.value.cachedAt;
        oldestPeer = entry.key.nodeId;
      }
    }

    if (oldestPeer != null) {
      _advertCache.removeWhere((k, _) => k.nodeId == oldestPeer);
      _lastAdvertHash.remove(oldestPeer);
    }
  }

  /// Get all cached services for a specific peer.
  List<MrrpCachedService> getServicesForPeer(int nodeId) {
    _purgeExpiredEntries();
    return _advertCache.entries
        .where((e) => e.key.nodeId == nodeId && !e.value.isExpired)
        .map((e) => e.value)
        .toList();
  }

  /// Get all cached services across all peers.
  Map<int, List<MrrpCachedService>> getAllCachedServices() {
    _purgeExpiredEntries();
    final result = <int, List<MrrpCachedService>>{};
    for (final entry in _advertCache.entries) {
      if (!entry.value.isExpired) {
        result.putIfAbsent(entry.key.nodeId, () => []).add(entry.value);
      }
    }
    return result;
  }

  /// Number of cached service entries (for metrics).
  int get cachedEntryCount => _advertCache.length;

  /// Number of tracked peers.
  int get trackedPeerCount =>
      _advertCache.keys.map((k) => k.nodeId).toSet().length;

  void _purgeExpiredEntries() {
    _advertCache.removeWhere((_, v) => v.isExpired);

    // Clean _lastAdvertHash for peers with no remaining cache entries.
    final livePeers = _advertCache.keys.map((k) => k.nodeId).toSet();
    _lastAdvertHash.removeWhere((nodeId, _) => !livePeers.contains(nodeId));
  }

  // ---------------------------------------------------------------------------
  // Simulated peer injection (harness only)
  // ---------------------------------------------------------------------------

  /// Inject a simulated peer's services into the advert cache.
  ///
  /// Used by the Simulated Peer Lab to make virtual peers visible
  /// in the peer inspector, service browser, and request composer.
  void injectSimulatedPeer(int nodeId, List<MrrpAdvertDescriptor> descriptors) {
    _cacheServicesFromPeer(nodeId, descriptors);
  }

  /// Remove all cached services for a simulated peer.
  void removeSimulatedPeer(int nodeId) {
    _advertCache.removeWhere((key, _) => key.nodeId == nodeId);
    _lastAdvertHash.remove(nodeId);
    onCacheChanged?.call();
  }
}
