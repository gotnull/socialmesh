// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP engine — orchestrator wiring codec, registry, advert engine,
/// dispatcher, dedup cache, and SIP transport together.
///
/// [MrrpEngine] is the single entry point for all inbound MRRP frames
/// (received via [handleInboundFrame]) and provides the outbound send
/// path (wrapping MRRP frames in SIP mrrpData payloads).
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_advert_engine.dart';
import 'mrrp_codec.dart';
import 'mrrp_constants.dart';
import 'mrrp_counters.dart';
import 'mrrp_dedup_cache.dart';
import 'mrrp_dispatcher.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_registry.dart';
import 'mrrp_traffic_event.dart';
import 'mrrp_types.dart';

/// Callback to send an MRRP frame encoded inside a SIP mrrpData payload.
typedef MrrpSendCallback = Future<bool> Function(Uint8List sipPayload);

/// MRRP engine — lifecycle orchestrator.
class MrrpEngine {
  final MrrpServiceRegistry registry;
  final MrrpAdvertEngine advertEngine;
  final MrrpDispatcher dispatcher;
  final MrrpDedupCache dedupCache;
  final MrrpSendCallback? onSend;

  /// Instrumentation counters (optional, injected by provider layer).
  MrrpCounters? counters;

  /// Callback for traffic event reporting to the harness console.
  void Function(MrrpTrafficEvent event)? onTrafficEvent;

  /// Per-sender inbound request timestamps for rate limiting.
  final Map<int, List<DateTime>> _inboundRequestTimestamps = {};

  bool _running = false;

  MrrpEngine({
    required this.registry,
    required this.advertEngine,
    required this.dispatcher,
    required this.dedupCache,
    this.onSend,
  });

  /// Whether the engine is currently running.
  bool get isRunning => _running;

  /// Start the engine: begin advert broadcasts.
  void start() {
    if (_running) return;
    _running = true;

    final serviceCount = registry.getAll().length;
    final serviceNames = registry
        .getAll()
        .map((d) => MrrpServiceId.nameOf(d.serviceId))
        .join(', ');
    AppLogging.mrrp(
      'MRRP_ENGINE: started, $serviceCount services registered '
      '($serviceNames)', // lint-allow: hardcoded-string
    );

    advertEngine.start();
  }

  /// Stop the engine: halt advert broadcasts.
  void stop() {
    if (!_running) return;
    _running = false;
    advertEngine.stop();
    AppLogging.mrrp('MRRP_ENGINE: stopped'); // lint-allow: hardcoded-string
  }

  /// Dispose all resources.
  void dispose() {
    stop();
    advertEngine.dispose();
    dispatcher.dispose();
    dedupCache.clear();
    _inboundRequestTimestamps.clear();
  }

  // ---------------------------------------------------------------------------
  // Inbound frame handling (from protocol_service)
  // ---------------------------------------------------------------------------

  /// Handle an inbound MRRP frame received from the SIP transport.
  ///
  /// [senderNodeId] is the Meshtastic node ID of the peer.
  /// [sipPayload] is the raw SIP mrrpData payload (MRRP frame bytes).
  void handleInboundFrame(int senderNodeId, Uint8List sipPayload) {
    if (!_running) {
      AppLogging.mrrp(
        'MRRP_ENGINE: not running, dropping inbound '
        'frame', // lint-allow: hardcoded-string
      );
      return;
    }

    // Validate MRRP magic.
    if (sipPayload.length < MrrpConstants.mrrpHeaderMin) {
      AppLogging.mrrp(
        'MRRP_RX: payload too short '
        '(${sipPayload.length}B < ${MrrpConstants.mrrpHeaderMin}B)', // lint-allow: hardcoded-string
      );
      return;
    }
    if (sipPayload[0] != MrrpConstants.mrrpMagicByte0 ||
        sipPayload[1] != MrrpConstants.mrrpMagicByte1) {
      AppLogging.mrrp(
        'MRRP_RX: bad magic bytes '
        '(0x${sipPayload[0].toRadixString(16)} 0x${sipPayload[1].toRadixString(16)})', // lint-allow: hardcoded-string
      );
      return;
    }

    final frame = MrrpCodec.decode(sipPayload);
    if (frame == null) {
      AppLogging.mrrp(
        'MRRP_RX: decode failed, '
        'dropping', // lint-allow: hardcoded-string
      );
      return;
    }

    AppLogging.mrrp(
      'MRRP_RX: MRRP frame from node=0x${senderNodeId.toRadixString(16)}, '
      'msg_type=0x${frame.msgType.code.toRadixString(16)} (${frame.msgType.name}), '
      'service=${frame.serviceName}', // lint-allow: hardcoded-string
    );

    _routeFrame(frame, senderNodeId, sipPayload.length);
  }

  /// Record a traffic event for the harness console.
  void _recordTraffic(
    String direction,
    MrrpFrame frame, {
    int? peerNodeId,
    required int sizeBytes,
    MrrpStatusCode? status,
  }) {
    onTrafficEvent?.call(
      MrrpTrafficEvent(
        timestamp: DateTime.now(),
        direction: direction,
        msgType: frame.msgType,
        serviceId: frame.serviceId != 0 ? frame.serviceId : null,
        actionId: frame.actionId != 0 ? frame.actionId : null,
        requestId: frame.requestId != 0 ? frame.requestId : null,
        peerNodeId: peerNodeId,
        sizeBytes: sizeBytes,
        status: status,
      ),
    );
  }

  void _routeFrame(MrrpFrame frame, int senderNodeId, int frameSizeBytes) {
    // Record inbound traffic event.
    _recordTraffic(
      'RX', // lint-allow: hardcoded-string
      frame,
      peerNodeId: senderNodeId,
      sizeBytes: frameSizeBytes,
    );

    switch (frame.msgType) {
      case MrrpMessageType.serviceAdvert:
        counters?.recordServiceAdvertReceived();
        advertEngine.handleServiceAdvert(frame, senderNodeId);

      case MrrpMessageType.serviceDirReq:
        counters?.recordServiceDirRequestReceived();
        _handleServiceDirReq(frame, senderNodeId);

      case MrrpMessageType.serviceDirResp:
        counters?.recordServiceDirResponseReceived();
        advertEngine.handleServiceDirResp(frame, senderNodeId);

      case MrrpMessageType.request:
        if (_isInboundRequestThrottled(senderNodeId)) {
          counters?.recordBudgetThrottle();
          return;
        }
        _handleInboundRequest(frame, senderNodeId).catchError((
          Object error,
          StackTrace stack,
        ) {
          AppLogging.mrrp(
            'MRRP_ENGINE: unhandled error in request handler '
            'req_id=0x${frame.requestId.toRadixString(16)}: '
            '$error', // lint-allow: hardcoded-string
          );
        });

      case MrrpMessageType.response:
        _handleInboundResponse(frame);

      case MrrpMessageType.error:
        _handleInboundResponse(frame);

      case MrrpMessageType.cancel:
        dispatcher.handleInboundCancel(frame);

      case MrrpMessageType.eventReserved:
        AppLogging.mrrp(
          'MRRP_RX: eventReserved — ignoring '
          '(reserved for future use)', // lint-allow: hardcoded-string
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Inbound per-sender rate limiting
  // ---------------------------------------------------------------------------

  /// Returns true if [senderNodeId] has exceeded the inbound request rate
  /// limit (max N requests per 60 seconds). Records the timestamp if allowed.
  bool _isInboundRequestThrottled(int senderNodeId) {
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 60));

    final timestamps = _inboundRequestTimestamps[senderNodeId];
    if (timestamps != null) {
      timestamps.removeWhere((t) => t.isBefore(cutoff));
      if (timestamps.length >=
          MrrpConstants.mrrpMaxInboundRequestsPerSenderPer60s) {
        AppLogging.mrrp(
          'MRRP_ENGINE: inbound request throttled for '
          'peer=0x${senderNodeId.toRadixString(16)}', // lint-allow: hardcoded-string
        );
        return true;
      }
      timestamps.add(now);
    } else {
      _inboundRequestTimestamps[senderNodeId] = [now];
    }

    // Prune senders with no recent timestamps.
    _inboundRequestTimestamps.removeWhere((_, ts) => ts.isEmpty);

    return false;
  }

  // ---------------------------------------------------------------------------
  // Service directory
  // ---------------------------------------------------------------------------

  void _handleServiceDirReq(MrrpFrame frame, int senderNodeId) {
    final responseFrame = advertEngine.handleServiceDirReq(frame, senderNodeId);
    if (responseFrame != null) {
      counters?.recordServiceDirResponseSent();
      _sendFrame(responseFrame);
    }
  }

  // ---------------------------------------------------------------------------
  // Request handling with dedup
  // ---------------------------------------------------------------------------

  Future<void> _handleInboundRequest(MrrpFrame frame, int senderNodeId) async {
    final dedupKey = buildDedupKey(frame, senderNodeId);

    if (dedupCache.isDuplicate(dedupKey)) {
      // Duplicate request — check for cached response to replay.
      counters?.recordDuplicateRequestIgnored();
      final cachedResponse = dedupCache.checkAndRecordRequest(dedupKey);
      if (cachedResponse != null) {
        counters?.recordCachedResponseServed();
        _sendFrame(cachedResponse);
      }
      return;
    }

    // First-time request — record it and route to dispatcher.
    dedupCache.checkAndRecordRequest(dedupKey);

    final response = await dispatcher.dispatch(frame, senderNodeId);
    dedupCache.cacheResponse(dedupKey, response);
    _sendFrame(response);
  }

  // ---------------------------------------------------------------------------
  // Response handling with dedup
  // ---------------------------------------------------------------------------

  void _handleInboundResponse(MrrpFrame frame) {
    if (!dedupCache.checkAndRecordResponse(frame.requestId)) {
      // Duplicate response — suppress.
      counters?.recordDuplicateResponseIgnored();
      return;
    }
    dispatcher.handleResponse(frame);
  }

  // ---------------------------------------------------------------------------
  // Outbound send path
  // ---------------------------------------------------------------------------

  /// Send an MRRP frame through the SIP transport.
  Future<bool> _sendFrame(MrrpFrame frame) async {
    final encoded = MrrpCodec.encode(frame);
    if (encoded == null) {
      AppLogging.mrrp(
        'MRRP_TX: encode failed for req_id=0x${frame.requestId.toRadixString(16)}', // lint-allow: hardcoded-string
      );
      return false;
    }

    AppLogging.mrrp(
      'MRRP_TX: ${frame.msgType.name} req_id=0x${frame.requestId.toRadixString(16)}, '
      '${frame.payloadLen}B payload, ${encoded.length}B total', // lint-allow: hardcoded-string
    );

    // Record outbound traffic event.
    _recordTraffic(
      'TX', // lint-allow: hardcoded-string
      frame,
      sizeBytes: encoded.length,
    );

    final send = onSend;
    if (send == null) {
      AppLogging.mrrp(
        'MRRP_TX: no send callback — '
        'dropping', // lint-allow: hardcoded-string
      );
      return false;
    }

    return send(encoded);
  }

  /// Send an outbound REQUEST frame. Returns the result future.
  Future<MrrpRequestResult> sendRequest(MrrpFrame request) async {
    return dispatcher.sendRequest(request);
  }
}
