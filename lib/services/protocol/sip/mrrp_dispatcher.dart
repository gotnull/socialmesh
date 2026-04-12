// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP request dispatcher and response correlator.
///
/// The dispatcher routes inbound REQUEST frames to registered service
/// handlers by service_id + action_id, and tracks outbound pending
/// requests for response/error correlation and timeout management.
///
/// Responsibilities:
/// - Route inbound REQUEST to correct handler
/// - Return ERROR(NOT_FOUND) for unknown services
/// - Return ERROR(UNSUPPORTED) for unknown actions
/// - Track outbound pending requests (max 4)
/// - Correlate inbound RESPONSE/ERROR to pending requests
/// - Fire timeout callbacks after MRRP_REQUEST_TIMEOUT_S
/// - Handle CANCEL messages
library;

import 'dart:async';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_codec.dart';
import 'mrrp_constants.dart';
import 'mrrp_counters.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_registry.dart';
import 'mrrp_types.dart';

/// Result of a dispatched outbound request.
class MrrpRequestResult {
  /// The response frame (null if timed out or cancelled).
  final MrrpFrame? response;

  /// The status code of the result.
  final MrrpStatusCode status;

  /// Round-trip latency.
  final Duration? latency;

  const MrrpRequestResult({this.response, required this.status, this.latency});

  /// Whether this result is a successful response.
  bool get isSuccess => status == MrrpStatusCode.ok;
}

/// Internal tracking of a pending outbound request.
class _PendingRequest {
  final int requestId;
  final int serviceId;
  final int actionId;
  final DateTime sentAt;
  final Completer<MrrpRequestResult> completer;
  Timer? timeoutTimer;
  bool cancelled = false;

  _PendingRequest({
    required this.requestId,
    required this.serviceId,
    required this.actionId,
    required this.sentAt,
    required this.completer,
  });
}

/// MRRP request dispatcher and response correlator.
class MrrpDispatcher {
  final MrrpServiceRegistry _registry;

  /// Callback to send a raw MRRP frame via SIP transport.
  Future<bool> Function(Uint8List payload)? onSend;

  /// Optional callback for sim peer request interception.
  ///
  /// Returns response frames from a simulated peer, or null to
  /// proceed with normal (over-the-wire) send.
  Future<List<MrrpFrame>?> Function(MrrpFrame request)? onSimPeerRequest;

  /// Instrumentation counters (optional, injected by provider layer).
  MrrpCounters? counters;

  /// Pending outbound requests indexed by request_id.
  final Map<int, _PendingRequest> _pending = {};

  /// Next request ID (wrapping uint16 counter).
  int _nextRequestId = 1;

  MrrpDispatcher({required MrrpServiceRegistry registry})
    : _registry = registry;

  // ---------------------------------------------------------------------------
  // Inbound REQUEST dispatch
  // ---------------------------------------------------------------------------

  /// Dispatch an inbound REQUEST frame to the appropriate service handler.
  ///
  /// Returns a RESPONSE or ERROR frame to be sent back to the requester.
  Future<MrrpFrame> dispatch(MrrpFrame request, int senderNodeId) async {
    counters?.recordRequestReceived(serviceId: request.serviceId);

    AppLogging.mrrp(
      'MRRP_TRACE_REQ_RX '
      'sender=0x${senderNodeId.toRadixString(16)} '
      'req_id=0x${request.requestId.toRadixString(16)} '
      'service=0x${request.serviceId.toRadixString(16).padLeft(8, '0')} '
      'action=0x${request.actionId.toRadixString(16).padLeft(4, '0')} '
      'flags=0x${request.flags.toRadixString(16)} '
      'payload=${request.payload.length}B',
    );

    final handler = _registry.getHandler(request.serviceId);

    if (handler == null) {
      AppLogging.mrrp(
        'MRRP_DISPATCH: REQUEST req_id=0x${request.requestId.toRadixString(16)} '
        'service=0x${request.serviceId.toRadixString(16).padLeft(8, '0')} '
        '-> NOT_FOUND', // lint-allow: hardcoded-string
      );
      counters?.recordErrorSent();
      return _buildError(request, MrrpStatusCode.notFound);
    }

    if (!handler.supportedActions.contains(request.actionId)) {
      AppLogging.mrrp(
        'MRRP_DISPATCH: REQUEST req_id=0x${request.requestId.toRadixString(16)} '
        'service=${MrrpServiceId.nameOf(request.serviceId)} '
        'action=0x${request.actionId.toRadixString(16)} '
        '-> UNSUPPORTED', // lint-allow: hardcoded-string
      );
      counters?.recordErrorSent();
      return _buildError(request, MrrpStatusCode.unsupported);
    }

    AppLogging.mrrp(
      'MRRP_DISPATCH: REQUEST req_id=0x${request.requestId.toRadixString(16)} '
      'service=0x${request.serviceId.toRadixString(16).padLeft(8, '0')} '
      'action=0x${request.actionId.toRadixString(16).padLeft(4, '0')} '
      '-> handler found', // lint-allow: hardcoded-string
    );

    try {
      final response = await handler.handleRequest(request, senderNodeId);
      final statusTlv = response.findExtension(MrrpTlvType.statusCode);
      final statusName =
          response.isError && statusTlv != null && statusTlv.value.isNotEmpty
          ? (MrrpStatusCode.fromCode(statusTlv.value[0])?.name ?? 'unknown')
          : MrrpStatusCode.ok.name;

      AppLogging.mrrp(
        'MRRP_TRACE_RESP_BUILT '
        'req_id=0x${response.requestId.toRadixString(16)} '
        'service=0x${response.serviceId.toRadixString(16).padLeft(8, '0')} '
        'action=0x${response.actionId.toRadixString(16).padLeft(4, '0')} '
        'msgType=${response.msgType.name} '
        'status=$statusName '
        'flags=0x${response.flags.toRadixString(16)} '
        'payload=${response.payload.length}B',
      );

      AppLogging.mrrp(
        'MRRP_DISPATCH: RESPONSE req_id=0x${request.requestId.toRadixString(16)} '
        'status=OK, ${response.payload.length}B payload', // lint-allow: hardcoded-string
      );

      counters?.recordResponseSent(serviceId: request.serviceId);
      return response;
    } on Exception catch (e) {
      AppLogging.mrrp(
        'MRRP_DISPATCH: handler error for '
        'req_id=0x${request.requestId.toRadixString(16)}: $e', // lint-allow: hardcoded-string
      );
      counters?.recordErrorSent();
      return _buildError(request, MrrpStatusCode.internal);
    }
  }

  // ---------------------------------------------------------------------------
  // Outbound REQUEST: send and track
  // ---------------------------------------------------------------------------

  /// Send an outbound REQUEST and track it for response/timeout.
  ///
  /// Returns a [Future] that completes with the result (response, error,
  /// timeout, or busy). Caller provides a pre-built MrrpFrame with
  /// msg_type=REQUEST.
  Future<MrrpRequestResult> sendRequest(MrrpFrame request) async {
    if (_pending.length >= MrrpConstants.mrrpMaxPendingRequests) {
      AppLogging.mrrp(
        'MRRP_DISPATCH: req_id=0x${request.requestId.toRadixString(16)} '
        'rejected, ${_pending.length}/${MrrpConstants.mrrpMaxPendingRequests} '
        'pending (BUSY)', // lint-allow: hardcoded-string
      );
      return const MrrpRequestResult(status: MrrpStatusCode.busy);
    }

    final requestId = _allocateRequestId();
    final frame = MrrpFrame(
      versionMajor: request.versionMajor,
      versionMinor: request.versionMinor,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: request.headerLen,
      requestId: requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: request.payloadLen,
      headerExtensions: request.headerExtensions,
      payload: request.payload,
    );

    final completer = Completer<MrrpRequestResult>();
    final pending = _PendingRequest(
      requestId: requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      sentAt: DateTime.now(),
      completer: completer,
    );

    // Schedule timeout.
    pending.timeoutTimer = Timer(MrrpConstants.mrrpRequestTimeout, () {
      _handleTimeout(requestId);
    });

    _pending[requestId] = pending;

    counters?.recordRequestSent(serviceId: request.serviceId);

    // Check sim peer interception.
    final simHandler = onSimPeerRequest;
    if (simHandler != null) {
      final simResponses = await simHandler(frame);
      if (simResponses != null) {
        // Sim peer handled — inject responses through correlation path.
        for (final response in simResponses) {
          handleResponse(response);
        }
        return completer.future;
      }
    }

    // Encode and send via SIP transport.
    final encoded = _encodeFrame(frame);
    if (encoded != null) {
      await onSend?.call(encoded);
    }

    return completer.future;
  }

  // ---------------------------------------------------------------------------
  // Inbound RESPONSE/ERROR correlation
  // ---------------------------------------------------------------------------

  /// Handle an inbound RESPONSE or ERROR frame by correlating to a pending
  /// outbound request.
  void handleResponse(MrrpFrame frame) {
    final pending = _pending.remove(frame.requestId);
    if (pending == null) {
      final pendingSummary = _pending.values
          .map(
            (p) =>
                '0x${p.requestId.toRadixString(16)}:'
                '0x${p.serviceId.toRadixString(16).padLeft(8, '0')}/'
                '0x${p.actionId.toRadixString(16).padLeft(4, '0')}',
          )
          .join(',');
      AppLogging.mrrp(
        'MRRP_TRACE_RESP_UNMATCHED '
        'req_id=0x${frame.requestId.toRadixString(16)} '
        'service=0x${frame.serviceId.toRadixString(16).padLeft(8, '0')} '
        'action=0x${frame.actionId.toRadixString(16).padLeft(4, '0')} '
        'msgType=${frame.msgType.name} '
        'pending=${_pending.length}${pendingSummary.isEmpty ? '' : ' [$pendingSummary]'}',
      );
      AppLogging.mrrp(
        'MRRP_DISPATCH: stale ${frame.msgType.name} '
        'req_id=0x${frame.requestId.toRadixString(16)}, '
        'no pending request — dropped', // lint-allow: hardcoded-string
      );
      return;
    }

    if (pending.cancelled) {
      AppLogging.mrrp(
        'MRRP_TRACE_RESP_REJECT '
        'req_id=0x${frame.requestId.toRadixString(16)} '
        'reason=cancelled '
        'service=0x${frame.serviceId.toRadixString(16).padLeft(8, '0')} '
        'action=0x${frame.actionId.toRadixString(16).padLeft(4, '0')}',
      );
      AppLogging.mrrp(
        'MRRP_DISPATCH: ${frame.msgType.name} '
        'req_id=0x${frame.requestId.toRadixString(16)} '
        'arrived after CANCEL — dropped', // lint-allow: hardcoded-string
      );
      pending.timeoutTimer?.cancel();
      return;
    }

    pending.timeoutTimer?.cancel();
    final latency = DateTime.now().difference(pending.sentAt);

    final statusTlv = frame.isError
        ? frame.findExtension(MrrpTlvType.statusCode)
        : null;

    MrrpStatusCode status;
    if (frame.isError) {
      final statusCode = statusTlv != null && statusTlv.value.isNotEmpty
          ? MrrpStatusCode.fromCode(statusTlv.value[0])
          : null;
      status = statusCode ?? MrrpStatusCode.internal;
    } else {
      status = MrrpStatusCode.ok;
    }

    AppLogging.mrrp(
      'MRRP_TRACE_RESP_MATCH '
      'req_id=0x${frame.requestId.toRadixString(16)} '
      'pending_service=0x${pending.serviceId.toRadixString(16).padLeft(8, '0')} '
      'frame_service=0x${frame.serviceId.toRadixString(16).padLeft(8, '0')} '
      'pending_action=0x${pending.actionId.toRadixString(16).padLeft(4, '0')} '
      'frame_action=0x${frame.actionId.toRadixString(16).padLeft(4, '0')} '
      'status=${status.name} '
      'latency=${latency.inMilliseconds}ms',
    );

    AppLogging.mrrp(
      'MRRP_DISPATCH: ${frame.msgType.name} '
      'req_id=0x${frame.requestId.toRadixString(16)} '
      'status=${status.name}, '
      '${frame.payload.length}B payload, '
      'latency=${latency.inMilliseconds}ms', // lint-allow: hardcoded-string
    );

    if (frame.isError) {
      counters?.recordErrorReceived(
        statusCode: statusTlv != null && statusTlv.value.isNotEmpty
            ? statusTlv.value[0]
            : null,
      );
    } else {
      counters?.recordResponseReceived(serviceId: pending.serviceId);
      counters?.recordLatency(pending.serviceId, latency);
    }

    if (!pending.completer.isCompleted) {
      pending.completer.complete(
        MrrpRequestResult(response: frame, status: status, latency: latency),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // CANCEL
  // ---------------------------------------------------------------------------

  /// Cancel a pending outbound request.
  ///
  /// Sends a CANCEL frame and marks the pending request as cancelled.
  Future<void> cancelRequest(int requestId) async {
    final pending = _pending[requestId];
    if (pending == null) return;

    pending.cancelled = true;
    pending.timeoutTimer?.cancel();
    _pending.remove(requestId);

    AppLogging.mrrp(
      'MRRP_DISPATCH: CANCEL req_id=0x${requestId.toRadixString(16)}', // lint-allow: hardcoded-string
    );

    counters?.recordRequestCancellation();

    // Send CANCEL frame to peer.
    final cancelFrame = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.cancel,
      flags: 0,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: requestId,
      serviceId: pending.serviceId,
      actionId: pending.actionId,
      payloadLen: 0,
      payload: Uint8List(0),
    );

    final encoded = _encodeFrame(cancelFrame);
    if (encoded != null) {
      await onSend?.call(encoded);
    }

    if (!pending.completer.isCompleted) {
      pending.completer.complete(
        const MrrpRequestResult(status: MrrpStatusCode.timeout),
      );
    }
  }

  /// Handle an inbound CANCEL frame — the remote peer is cancelling a
  /// request they sent to us.
  ///
  /// This is informational; the dispatcher logs it. The request may
  /// already be processed.
  void handleInboundCancel(MrrpFrame frame) {
    AppLogging.mrrp(
      'MRRP_DISPATCH: inbound CANCEL '
      'req_id=0x${frame.requestId.toRadixString(16)}', // lint-allow: hardcoded-string
    );
  }

  // ---------------------------------------------------------------------------
  // Timeout handling
  // ---------------------------------------------------------------------------

  void _handleTimeout(int requestId) {
    final pending = _pending.remove(requestId);
    if (pending == null || pending.cancelled) return;

    AppLogging.mrrp(
      'MRRP_DISPATCH: req_id=0x${requestId.toRadixString(16)} '
      'TIMEOUT after ${MrrpConstants.mrrpRequestTimeoutS}s', // lint-allow: hardcoded-string
    );

    counters?.recordRequestTimeout(serviceId: pending.serviceId);

    if (!pending.completer.isCompleted) {
      pending.completer.complete(
        const MrrpRequestResult(status: MrrpStatusCode.timeout),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _allocateRequestId() {
    final id = _nextRequestId;
    _nextRequestId = (_nextRequestId + 1) & 0xFFFF;
    if (_nextRequestId == 0) _nextRequestId = 1;
    return id;
  }

  Uint8List? _encodeFrame(MrrpFrame frame) {
    return MrrpCodec.encode(frame);
  }

  /// Number of pending outbound requests.
  int get pendingCount => _pending.length;

  /// Dispose: cancel all pending requests and their timers.
  void dispose() {
    for (final pending in _pending.values) {
      pending.timeoutTimer?.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.complete(
          const MrrpRequestResult(status: MrrpStatusCode.timeout),
        );
      }
    }
    _pending.clear();
  }

  MrrpFrame _buildError(MrrpFrame request, MrrpStatusCode status) {
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.error,
      flags: MrrpFlags.isResponse | MrrpFlags.isError,
      headerLen: MrrpConstants.mrrpHeaderMin + 3, // TLV: status_code(1+1+1)
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: 0,
      headerExtensions: [
        MrrpTlvEntry(
          type: MrrpTlvType.statusCode.code,
          value: Uint8List.fromList([status.code]),
        ),
      ],
      payload: Uint8List(0),
    );
  }
}
