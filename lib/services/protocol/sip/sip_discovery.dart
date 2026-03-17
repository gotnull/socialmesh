// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP-0 capability discovery engine.
///
/// Handles CAP_BEACON emission, ROLLCALL request/response, and
/// caching of discovered peer capabilities. All transmissions are
/// rate-limited by the SIP token bucket.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'sip_codec.dart';
import 'sip_constants.dart';
import 'sip_counters.dart';
import 'sip_frame.dart';
import 'sip_messages_cap.dart';
import 'sip_rate_limiter.dart';
import 'sip_replay_cache.dart';
import 'sip_types.dart';

/// A discovered SIP peer's capabilities.
class SipPeerCapability {
  /// The peer's Meshtastic node ID.
  final int nodeId;

  /// SIP feature bitmap advertised by the peer.
  final int features;

  /// Device class (1 = phone-app).
  final int deviceClass;

  /// Maximum protocol minor version supported.
  final int maxProtoMinor;

  /// MTU hint from the peer.
  final int mtuHint;

  /// Receive window in seconds.
  final int rxWindowS;

  /// Capability hash for change detection.
  final int capsHash;

  /// When this entry was last updated (ms since epoch).
  int lastSeenMs;

  SipPeerCapability({
    required this.nodeId,
    required this.features,
    required this.deviceClass,
    required this.maxProtoMinor,
    required this.mtuHint,
    required this.rxWindowS,
    required this.capsHash,
    required this.lastSeenMs,
  });

  /// Whether this peer supports SIP-1 (identity/handshake).
  bool get supportsSip1 =>
      (features & SipFeatureBits.sip1) == SipFeatureBits.sip1;

  /// Whether this peer supports SIP-3 (micro-exchange).
  bool get supportsSip3 =>
      (features & SipFeatureBits.sip3) == SipFeatureBits.sip3;
}

/// Outbound SIP frame ready to send via the transport.
class SipOutbound {
  final SipFrame frame;
  final Uint8List encoded;

  const SipOutbound({required this.frame, required this.encoded});
}

/// SIP-0 capability discovery engine.
///
/// Manages:
/// - CAP_BEACON emission (foreground-only, jittered, budget-enforced)
/// - ROLLCALL_REQ/ROLLCALL_RESP handling
/// - Peer capability cache (max 16 entries, 24h TTL)
class SipDiscovery {
  /// Creates a discovery engine.
  ///
  /// [rateLimiter] enforces the byte budget.
  /// [localNodeId] is this device's Meshtastic node number.
  /// [clock] is injectable for testing.
  SipDiscovery({
    required SipRateLimiter rateLimiter,
    required int localNodeId,
    SipCounters? counters,
    SipReplayCache? replayCache,
    int? Function()? clock,
    this.maxPeers = 16,
    this.cacheTtlMs = 24 * 60 * 60 * 1000, // 24 hours
    this.beaconIntervalMs = 300 * 1000, // 300s
    this.beaconJitterMs = 30 * 1000, // 0-30s
    this.rollcallCooldownMs = 60 * 1000, // 60s
    this.rollcallRespDelayMaxMs = 3000, // 0-3s
  }) : _rateLimiter = rateLimiter,
       _localNodeId = localNodeId,
       _counters = counters,
       _replayCache = replayCache,
       _clock = clock;

  /// Callback to send an encoded SIP frame via the mesh transport.
  ///
  /// Set by the provider layer to wire into ProtocolService.
  Future<bool> Function(Uint8List encoded)? onSend;

  /// Optional callback invoked whenever the peer cache changes.
  ///
  /// Set by the provider layer to trigger Riverpod invalidation so the
  /// UI rebuilds when peers are discovered or evicted.
  void Function()? onPeersChanged;

  /// Optional callback invoked when a new peer is discovered or updated.
  ///
  /// Set by the provider layer to bridge SIP discovery into NodeDex.
  /// The callback receives the node ID of the discovered peer.
  void Function(int nodeId)? onPeerDiscovered;

  final SipRateLimiter _rateLimiter;
  final int _localNodeId;
  final SipCounters? _counters;
  final SipReplayCache? _replayCache;
  final int? Function()? _clock;

  /// Timer for periodic CAP_BEACON broadcast.
  Timer? _beaconTimer;

  /// Maximum peers in the capability cache.
  final int maxPeers;

  /// Cache entry TTL in milliseconds.
  final int cacheTtlMs;

  /// Beacon emission interval in milliseconds.
  final int beaconIntervalMs;

  /// Maximum jitter added to beacon interval in milliseconds.
  final int beaconJitterMs;

  /// Minimum interval between rollcall requests in milliseconds.
  final int rollcallCooldownMs;

  /// Maximum random delay before sending rollcall response.
  final int rollcallRespDelayMaxMs;

  /// Peer capability cache: node_id -> capability.
  final Map<int, SipPeerCapability> _cache = {};

  /// Whether discovery (beacon emission, rollcall responses) is enabled.
  ///
  /// Set by the provider layer from the mesh privacy discoverable setting.
  /// When false, outbound CAP_BEACON and ROLLCALL_RESP are suppressed
  /// (unless a scan window is active — see [_scanWindowExpiresMs]).
  /// Inbound processing (caching discovered peers) continues regardless.
  bool isDiscoverable = false;

  /// Scan-window expiry timestamp (ms since epoch).
  ///
  /// When a user-initiated rollcall request is sent (force=true), a 10-second
  /// scan window opens. During this window, rollcall responses bypass the
  /// [isDiscoverable] privacy gate so that bi-directional discovery works:
  /// Device A scans → Device B (also scanning) receives the request and
  /// responds, even if its persistent privacy toggle is off.
  ///
  /// The beacon gate is NOT bypassed — beacons remain suppressed when
  /// not discoverable, as they are unsolicited background broadcasts.
  int _scanWindowExpiresMs = 0;

  /// Whether a user-initiated scan window is currently active.
  bool get isInScanWindow => _nowMs() < _scanWindowExpiresMs;

  /// Timestamp (ms) of last beacon emission.
  ///
  /// Publicly settable for resume restoration (prevents burst after app resume).
  int lastBeaconMs = 0;

  /// Timestamp (ms) of last rollcall request sent.
  ///
  /// Publicly settable for resume restoration (prevents burst after app resume).
  int lastRollcallReqMs = 0;

  /// Rate limiter for per-peer rollcall responses: node_id -> last response ms.
  final Map<int, int> _lastRollcallRespMs = {};

  /// Duration of the scan window opened by a user-initiated rollcall request.
  static const int _kScanWindowMs = 10 * 1000; // 10s

  static final Random _jitterRng = Random();

  int _nowMs() => _clock?.call() ?? DateTime.now().millisecondsSinceEpoch;

  int _nowS() => _nowMs() ~/ 1000;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Start the periodic CAP_BEACON broadcast.
  void start() {
    _scheduleNextBeacon();
    AppLogging.sip(
      'SIP_DISCOVERY: CAP_BEACON scheduled, '
      'interval=${beaconIntervalMs ~/ 1000}s+jitter', // lint-allow: hardcoded-string
    );
  }

  /// Stop the periodic beacon broadcast.
  void stop() {
    _beaconTimer?.cancel();
    _beaconTimer = null;
  }

  /// Dispose: stop timer and clear state.
  void dispose() {
    stop();
    _cache.clear();
    _lastRollcallRespMs.clear();
    onSend = null;
    onPeersChanged = null;
    onPeerDiscovered = null;
  }

  void _scheduleNextBeacon() {
    final jitterMs = _jitterRng.nextInt(beaconJitterMs + 1);
    final delayMs = beaconIntervalMs + jitterMs;
    _beaconTimer?.cancel();
    _beaconTimer = Timer(Duration(milliseconds: delayMs), _emitPeriodicBeacon);
  }

  Future<void> _emitPeriodicBeacon() async {
    final outbound = buildBeacon();
    if (outbound != null) {
      await onSend?.call(outbound.encoded);
    }
    _scheduleNextBeacon();
  }

  // ---------------------------------------------------------------------------
  // Peer cache
  // ---------------------------------------------------------------------------

  /// All currently cached peers.
  Iterable<SipPeerCapability> get discoveredPeers => _cache.values;

  /// Number of cached peers.
  int get peerCount => _cache.length;

  /// Look up a specific peer.
  SipPeerCapability? getPeer(int nodeId) => _cache[nodeId];

  /// Clear the entire peer cache and notify listeners.
  void clearPeerCache() {
    if (_cache.isEmpty) return;
    _cache.clear();
    _lastRollcallRespMs.clear();
    onPeersChanged?.call();
    AppLogging.sip('SIP_DISCOVERY: peer cache cleared by user');
  }

  /// Evict expired entries. Returns the number evicted.
  int evictExpired() {
    final nowMs = _nowMs();
    final before = _cache.length;
    _cache.removeWhere((_, v) => nowMs - v.lastSeenMs > cacheTtlMs);
    final evicted = before - _cache.length;
    if (evicted > 0) {
      AppLogging.sip(
        'SIP_DISCOVERY: evicted $evicted expired cache entries, '
        'remaining=${_cache.length}',
      );
    }
    return evicted;
  }

  // ---------------------------------------------------------------------------
  // Outbound: CAP_BEACON
  // ---------------------------------------------------------------------------

  /// Build a CAP_BEACON frame if enough time has elapsed and budget allows.
  ///
  /// Returns null if beacon was recently sent, budget insufficient,
  /// congestion detected, or non-essential sends suppressed. If [force]
  /// is true, skips the interval check (but still respects budget and
  /// congestion).
  SipOutbound? buildBeacon({bool force = false}) {
    // Privacy gate: suppress beacon when not discoverable.
    if (!isDiscoverable) {
      AppLogging.sip(
        'SIP_DISCOVERY: CAP_BEACON suppressed (discoverable=false)',
      );
      return null;
    }

    final nowMs = _nowMs();

    // Suppress non-essential discovery during congestion or budget pressure.
    if (_rateLimiter.shouldSuppressNonEssential) {
      AppLogging.sip(
        'SIP_DISCOVERY: CAP_BEACON suppressed (non-essential suppression '
        'active, congested=${_rateLimiter.isCongested}, '
        'budget_high=${_rateLimiter.isBudgetHigh})',
      );
      _counters?.recordCongestionPause();
      return null;
    }

    if (!force) {
      final elapsed = nowMs - lastBeaconMs;
      final jitterMs = _jitterRng.nextInt(beaconJitterMs + 1);
      final nextBeaconMs = beaconIntervalMs + jitterMs;
      if (elapsed < nextBeaconMs) {
        return null;
      }
      AppLogging.sip(
        'SIP_DISCOVERY: beacon scheduled '
        '(base=${beaconIntervalMs ~/ 1000}s jitter=${jitterMs ~/ 1000}s)',
      );
    }

    // Build the beacon payload.
    final beacon = SipCapBeacon(
      features: SipFeatureBits.allV01,
      deviceClass: 1, // phone-app
      maxProtoMinor: SipConstants.sipVersionMinor,
      mtuHint: SipConstants.sipMaxPayload,
      rxWindowS: 10,
    );
    final payload = SipCapMessages.encodeCapBeacon(beacon);

    // Build the frame.
    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.capBeacon,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: 0,
      nonce: SipCodec.generateNonce(),
      timestampS: _nowS(),
      payloadLen: payload.length,
      payload: payload,
    );

    final encoded = SipCodec.encode(frame);
    if (encoded == null) return null;

    // Check byte budget.
    if (!_rateLimiter.canSend(encoded.length)) {
      AppLogging.sip(
        'SIP_DISCOVERY: CAP_BEACON suppressed (budget insufficient for '
        '${encoded.length}B)',
      );
      _counters?.recordBudgetThrottle();
      return null;
    }

    _rateLimiter.recordSend(encoded.length);
    lastBeaconMs = nowMs;

    AppLogging.sip(
      'SIP_DISCOVERY: CAP_BEACON emitted, ${encoded.length}B total, '
      'budget=${_rateLimiter.remainingBytes}/${SipConstants.sipBudgetBytesPer60s} 60s',
    );

    return SipOutbound(frame: frame, encoded: encoded);
  }

  // ---------------------------------------------------------------------------
  // Outbound: ROLLCALL_REQ
  // ---------------------------------------------------------------------------

  /// Build a ROLLCALL_REQ frame.
  ///
  /// For periodic/automatic sends, rate-limited to 1 per cooldown plus jitter.
  /// For user-initiated scans, pass [force] = true to bypass the time cooldown
  /// and resume-suppression window while still respecting active mesh
  /// congestion and the hard byte budget.
  ///
  /// Returns null if rate-limited, budget insufficient, or congested.
  SipOutbound? buildRollcallReq({bool force = false}) {
    final nowMs = _nowMs();

    // Always suppress during active mesh congestion. For automatic sends also
    // suppress on budget pressure / resume suppression window.
    if (force) {
      if (_rateLimiter.isCongested) {
        AppLogging.sip(
          'SIP_DISCOVERY: ROLLCALL_REQ (force) suppressed '
          '(active congestion)',
        );
        return null;
      }
    } else if (_rateLimiter.shouldSuppressNonEssential) {
      AppLogging.sip(
        'SIP_DISCOVERY: ROLLCALL_REQ suppressed (non-essential suppression '
        'active, congested=${_rateLimiter.isCongested}, '
        'budget_high=${_rateLimiter.isBudgetHigh})',
      );
      _counters?.recordCongestionPause();
      return null;
    }

    // Time cooldown only applies to automatic (non-forced) sends.
    if (!force) {
      final jitterMs = _jitterRng.nextInt(
        SipConstants.rollcallReqJitter.inMilliseconds + 1,
      );
      final effectiveCooldownMs = rollcallCooldownMs + jitterMs;

      if (nowMs - lastRollcallReqMs < effectiveCooldownMs) {
        AppLogging.sip(
          'SIP_DISCOVERY: ROLLCALL_REQ rate-limited '
          '(${(nowMs - lastRollcallReqMs) ~/ 1000}s < '
          '${effectiveCooldownMs ~/ 1000}s, '
          'base=${rollcallCooldownMs ~/ 1000}s jitter=${jitterMs ~/ 1000}s)',
        );
        return null;
      }
    }

    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.rollcallReq,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: 0,
      nonce: SipCodec.generateNonce(),
      timestampS: _nowS(),
      payloadLen: 0,
      payload: Uint8List(0),
    );

    final encoded = SipCodec.encode(frame);
    if (encoded == null) return null;

    if (!_rateLimiter.canSend(encoded.length)) {
      AppLogging.sip(
        'SIP_DISCOVERY: ROLLCALL_REQ suppressed (budget insufficient)',
      );
      _counters?.recordBudgetThrottle();
      return null;
    }

    _rateLimiter.recordSend(encoded.length);
    lastRollcallReqMs = nowMs;

    // Open scan window on user-initiated (forced) requests so that incoming
    // rollcall responses from other scanning peers are allowed through even
    // when the persistent discoverable toggle is off.
    if (force) {
      _scanWindowExpiresMs = nowMs + _kScanWindowMs;
      AppLogging.sip(
        'SIP_DISCOVERY: scan window opened for ${_kScanWindowMs ~/ 1000}s',
      );
    }

    AppLogging.sip(
      'SIP_DISCOVERY: ROLLCALL_REQ broadcast, ${encoded.length}B total',
    );

    return SipOutbound(frame: frame, encoded: encoded);
  }

  // ---------------------------------------------------------------------------
  // Outbound: ROLLCALL_RESP
  // ---------------------------------------------------------------------------

  /// Build a ROLLCALL_RESP for a specific peer. Rate-limited per-peer (60s).
  ///
  /// Returns null if rate-limited or budget insufficient.
  /// The caller should apply a random delay (0-3s) before sending.
  SipOutbound? buildRollcallResp(int peerNodeId) {
    // Privacy gate: suppress rollcall responses when not discoverable,
    // unless a user-initiated scan window is active (allows bi-directional
    // discovery between two scanning peers).
    if (!isDiscoverable && !isInScanWindow) {
      AppLogging.sip(
        'SIP_DISCOVERY: ROLLCALL_RESP suppressed (discoverable=false)',
      );
      return null;
    }

    final nowMs = _nowMs();

    final lastMs = _lastRollcallRespMs[peerNodeId];
    if (lastMs != null && nowMs - lastMs < rollcallCooldownMs) {
      AppLogging.sip(
        'SIP_DISCOVERY: ROLLCALL_RESP to 0x${peerNodeId.toRadixString(16)} '
        'rate-limited',
      );
      return null;
    }

    final beacon = SipCapBeacon(
      features: SipFeatureBits.allV01,
      deviceClass: 1,
      maxProtoMinor: SipConstants.sipVersionMinor,
      mtuHint: SipConstants.sipMaxPayload,
      rxWindowS: 10,
    );
    final capsHash = SipCapMessages.computeCapsHash(beacon);
    final resp = SipRollcallResp(capabilities: beacon, capsHash: capsHash);
    final payload = SipCapMessages.encodeRollcallResp(resp);

    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.rollcallResp,
      flags: SipFlags.isResponse,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: 0,
      nonce: SipCodec.generateNonce(),
      timestampS: _nowS(),
      payloadLen: payload.length,
      payload: payload,
    );

    final encoded = SipCodec.encode(frame);
    if (encoded == null) return null;

    if (!_rateLimiter.canSend(encoded.length)) {
      AppLogging.sip(
        'SIP_DISCOVERY: ROLLCALL_RESP suppressed (budget insufficient)',
      );
      _counters?.recordBudgetThrottle();
      return null;
    }

    _rateLimiter.recordSend(encoded.length);
    _lastRollcallRespMs[peerNodeId] = nowMs;
    _boundRollcallRespMap();

    AppLogging.sip(
      'SIP_DISCOVERY: ROLLCALL_RESP to 0x${peerNodeId.toRadixString(16)} '
      '${encoded.length}B total',
    );

    return SipOutbound(frame: frame, encoded: encoded);
  }

  // ---------------------------------------------------------------------------
  // Inbound: CAP_BEACON / ROLLCALL_RESP
  // ---------------------------------------------------------------------------

  /// Handle an inbound CAP_BEACON.
  /// Stores the peer in the capability cache.
  /// Ignores duplicate packets (same sender + nonce) seen via multi-hop.
  void handleBeacon(SipFrame frame, int senderNodeId) {
    // Duplicate suppression: ignore if we already processed this exact frame.
    if (_isDuplicateDiscovery(senderNodeId, frame)) return;

    final beacon = SipCapMessages.decodeCapBeacon(frame.payload);
    if (beacon == null) {
      AppLogging.sip(
        'SIP_DISCOVERY: CAP_BEACON from 0x${senderNodeId.toRadixString(16)} '
        'decode failed',
      );
      return;
    }

    _upsertPeer(
      nodeId: senderNodeId,
      features: beacon.features,
      deviceClass: beacon.deviceClass,
      maxProtoMinor: beacon.maxProtoMinor,
      mtuHint: beacon.mtuHint,
      rxWindowS: beacon.rxWindowS,
      capsHash: SipCapMessages.computeCapsHash(beacon),
    );
  }

  /// Handle an inbound ROLLCALL_RESP.
  /// Ignores duplicate packets seen via multi-hop.
  void handleRollcallResp(SipFrame frame, int senderNodeId) {
    // Duplicate suppression: ignore if we already processed this exact frame.
    if (_isDuplicateDiscovery(senderNodeId, frame)) return;

    final resp = SipCapMessages.decodeRollcallResp(frame.payload);
    if (resp == null) {
      AppLogging.sip(
        'SIP_DISCOVERY: ROLLCALL_RESP from 0x${senderNodeId.toRadixString(16)} '
        'decode failed',
      );
      return;
    }

    _upsertPeer(
      nodeId: senderNodeId,
      features: resp.capabilities.features,
      deviceClass: resp.capabilities.deviceClass,
      maxProtoMinor: resp.capabilities.maxProtoMinor,
      mtuHint: resp.capabilities.mtuHint,
      rxWindowS: resp.capabilities.rxWindowS,
      capsHash: resp.capsHash,
    );
  }

  /// Whether a given node ID is us (ignore our own broadcasts).
  bool isLocalNode(int nodeId) => nodeId == _localNodeId;

  // ---------------------------------------------------------------------------
  // Inbound: ROLLCALL_REQ
  // ---------------------------------------------------------------------------

  /// Handle an inbound ROLLCALL_REQ. Returns a response to send, or null.
  ///
  /// Also performs **passive discovery**: receiving a ROLLCALL_REQ proves the
  /// sender is a SIP peer. If they are not already cached, an entry with
  /// minimal capabilities (SIP-0 only, capsHash=0) is created so the peer
  /// appears in the UI immediately. The entry is upgraded when a
  /// ROLLCALL_RESP or CAP_BEACON arrives with full capability data.
  ///
  /// Ignores duplicate packets seen via multi-hop.
  /// The caller should delay sending by 0-3s (random jitter).
  SipOutbound? handleRollcallReq(int senderNodeId, {SipFrame? frame}) {
    if (senderNodeId == _localNodeId) return null;

    // Duplicate suppression for the request itself.
    if (frame != null && _isDuplicateDiscovery(senderNodeId, frame)) {
      return null;
    }

    // Passive discovery: a ROLLCALL_REQ proves the sender is a SIP peer.
    // If already cached with full capabilities, just refresh the timestamp.
    // Otherwise create a minimal entry so the peer is visible immediately.
    final existing = _cache[senderNodeId];
    if (existing != null) {
      existing.lastSeenMs = _nowMs();
    } else {
      AppLogging.sip(
        'SIP_DISCOVERY: passive discovery from ROLLCALL_REQ, '
        'node=0x${senderNodeId.toRadixString(16)}',
      );
      _upsertPeer(
        nodeId: senderNodeId,
        features: SipFeatureBits.sip0,
        deviceClass: 0,
        maxProtoMinor: frame?.versionMinor ?? 0,
        mtuHint: 0,
        rxWindowS: 0,
        capsHash: 0,
      );
    }

    return buildRollcallResp(senderNodeId);
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _upsertPeer({
    required int nodeId,
    required int features,
    required int deviceClass,
    required int maxProtoMinor,
    required int mtuHint,
    required int rxWindowS,
    required int capsHash,
  }) {
    final nowMs = _nowMs();
    final existing = _cache[nodeId];

    if (existing != null) {
      // Update if caps changed or stale.
      existing.lastSeenMs = nowMs;
      if (existing.capsHash != capsHash) {
        _cache[nodeId] = SipPeerCapability(
          nodeId: nodeId,
          features: features,
          deviceClass: deviceClass,
          maxProtoMinor: maxProtoMinor,
          mtuHint: mtuHint,
          rxWindowS: rxWindowS,
          capsHash: capsHash,
          lastSeenMs: nowMs,
        );
        AppLogging.sip(
          'SIP_DISCOVERY: peer 0x${nodeId.toRadixString(16)} caps updated, '
          'features=0x${features.toRadixString(16)}, hash=$capsHash',
        );
        onPeersChanged?.call();
      }
      return;
    }

    // New peer.
    if (_cache.length >= maxPeers) {
      _evictOldest();
    }

    _cache[nodeId] = SipPeerCapability(
      nodeId: nodeId,
      features: features,
      deviceClass: deviceClass,
      maxProtoMinor: maxProtoMinor,
      mtuHint: mtuHint,
      rxWindowS: rxWindowS,
      capsHash: capsHash,
      lastSeenMs: nowMs,
    );

    AppLogging.sip(
      'SIP_DISCOVERY: CAP_RESP received from node=0x${nodeId.toRadixString(16)}, '
      'features=0x${features.toRadixString(16)}, mtu_hint=$mtuHint',
    );
    AppLogging.sip('SIP_DISCOVERY: peer_count=${_cache.length} cached');
    onPeersChanged?.call();
    onPeerDiscovered?.call(nodeId);
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;
    int? oldestNodeId;
    int oldestMs = 0x7FFFFFFFFFFFFFFF;
    for (final entry in _cache.entries) {
      if (entry.value.lastSeenMs < oldestMs) {
        oldestMs = entry.value.lastSeenMs;
        oldestNodeId = entry.key;
      }
    }
    if (oldestNodeId != null) {
      _cache.remove(oldestNodeId);
      AppLogging.sip(
        'SIP_DISCOVERY: evicted oldest peer 0x${oldestNodeId.toRadixString(16)}',
      );
    }
  }

  /// Check if this discovery frame is a duplicate (same sender + nonce
  /// seen via multi-hop mesh rebroadcast). Uses the shared replay cache.
  ///
  /// Returns true if duplicate (caller should ignore the packet).
  bool _isDuplicateDiscovery(int senderNodeId, SipFrame frame) {
    if (_replayCache == null) return false;

    if (_replayCache.isReplay(
      nodeId: senderNodeId,
      nonce: frame.nonce,
      msgType: frame.msgType.code,
    )) {
      AppLogging.sip(
        'SIP_DISCOVERY: duplicate packet ignored '
        'type=${frame.msgType.name} '
        'peer=0x${senderNodeId.toRadixString(16)} '
        'nonce=0x${frame.nonce.toRadixString(16)}',
      );
      return true;
    }

    // Record this nonce so future copies are deduplicated.
    _replayCache.recordNonce(
      nodeId: senderNodeId,
      nonce: frame.nonce,
      msgType: frame.msgType.code,
      timestampS: frame.timestampS,
    );
    return false;
  }

  /// Bound the per-peer rollcall response timestamp map to prevent
  /// unbounded growth from a flood of distinct peer node IDs.
  void _boundRollcallRespMap() {
    while (_lastRollcallRespMs.length > SipConstants.maxRollcallRespTracked) {
      // Evict oldest entry.
      int? oldestKey;
      int oldestMs = 0x7FFFFFFFFFFFFFFF;
      for (final entry in _lastRollcallRespMs.entries) {
        if (entry.value < oldestMs) {
          oldestMs = entry.value;
          oldestKey = entry.key;
        }
      }
      if (oldestKey != null) {
        _lastRollcallRespMs.remove(oldestKey);
      }
    }
  }
}
