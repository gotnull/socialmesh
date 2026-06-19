// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Production CanvasOutboundChannel — wraps a canvas codec payload in
// MRRP + SIP frames and pushes it through ProtocolService.sendSipGated
// with the canvas's bound channelIndex.
//
// Maintains the S4 anti-starvation invariant: this layer pre-checks the
// SIP rate limiter BEFORE building any frames so a SIP-denial path can
// return [CanvasSendOutcome.sipRateLimited] without the coordinator
// having charged its 250 B / 60 s governor. sendSipGated itself
// re-checks the limiter and consumes on success; the race window
// between the pre-check and the consume is narrow (single isolate, no
// awaits between) and the coordinator only charges its governor on
// `CanvasSendOutcome.sent`, so a lost race correctly reports as
// sipRateLimited.
library;

import 'dart:typed_data';

import '../../core/logging.dart';
import '../protocol/protocol_service.dart';
import '../protocol/sip/mrrp_codec.dart';
import '../protocol/sip/mrrp_constants.dart';
import '../protocol/sip/mrrp_frame.dart';
import '../protocol/sip/mrrp_types.dart';
import '../protocol/sip/sip_codec.dart';
import '../protocol/sip/sip_constants.dart';
import '../protocol/sip/sip_frame.dart';
import '../protocol/sip/sip_rate_limiter.dart';
import '../protocol/sip/sip_types.dart';
import 'canvas_codec.dart';
import 'canvas_send_coordinator.dart';

/// Minimal facade over the bits of `ProtocolService` that the canvas
/// outbound channel needs. Lets unit tests substitute a fake without
/// instantiating the whole protocol stack.
abstract class CanvasSipSender {
  /// Send a pre-encoded SIP frame, rate-limited via the SIP limiter
  /// inside [ProtocolService.sendSipGated].
  Future<bool> sendSipGated({
    required Uint8List encoded,
    required SipMessageType type,
    required int channelIndex,
  });
}

/// Adapter binding [CanvasSipSender] to a real [ProtocolService].
class ProtocolServiceCanvasSipSender implements CanvasSipSender {
  final ProtocolService _protocol;
  ProtocolServiceCanvasSipSender(this._protocol);

  @override
  Future<bool> sendSipGated({
    required Uint8List encoded,
    required SipMessageType type,
    required int channelIndex,
  }) => _protocol.sendSipGated(encoded, type, channelIndex: channelIndex);
}

/// Production [CanvasOutboundChannel] implementation.
///
/// Build order on every send:
///   1. Sniff the canvas op-type byte to determine MRRP `action_id`.
///   2. Wrap the canvas payload in an MRRP REQUEST frame (no `ack_required`).
///   3. Wrap the MRRP frame in a SIP `mrrpData` envelope.
///   4. Pre-check the SIP rate limiter against the on-wire SIP frame
///      length. If denied → return [CanvasSendOutcome.sipRateLimited]
///      WITHOUT touching the wire. Coordinator preserves canvas
///      governor budget on this outcome.
///   5. Hand the SIP frame to [CanvasSipSender.sendSipGated] which
///      re-checks + consumes the SIP budget and forwards to the
///      transport on the configured channel index.
class ProductionCanvasOutboundChannel implements CanvasOutboundChannel {
  final CanvasSipSender _sender;
  final SipRateLimiter? _sipRateLimiter;

  /// In-process u32 counter feeding the MRRP `request_id` field. Wraps
  /// at 0xFFFFFFFF and resets to 1. Canvas frames are broadcasts that
  /// expect no response, so the value is informational only; we still
  /// vary it to keep the engine's dedup cache from spuriously matching
  /// on legacy receivers that route canvas frames through the engine
  /// path (i.e. peers running pre-S6 builds).
  int _nextRequestId = 1;

  ProductionCanvasOutboundChannel({
    required this._sender,
    this._sipRateLimiter,
  });

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    // 1. Determine MRRP action_id from the canvas op-type byte.
    final action = CanvasCodec.sniffAction(canvasPayload);
    if (action == null) {
      AppLogging.meshCanvas(
        'outbound channel: refusing to send unrecognized canvas '
        'payload (${canvasPayload.length}B)',
      );
      return CanvasSendResult.failure('unrecognized-canvas-payload');
    }

    // 2. Build the MRRP frame. msg_type=REQUEST is the only inbound
    // path the engine routes via service handlers on peers running
    // older code paths; receivers running S6 demux skip the engine.
    // No ack_required flag — canvas frames are fire-and-forget.
    final requestId = _nextRequestId;
    _nextRequestId = (_nextRequestId + 1) & 0xFFFFFFFF;
    if (_nextRequestId == 0) _nextRequestId = 1;

    final mrrpFrame = MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.request,
      flags: 0, // NOT ack_required: broadcasts do not expect responses.
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: requestId,
      serviceId: MrrpServiceId.canvasV1,
      actionId: action.code,
      payloadLen: canvasPayload.length,
      payload: canvasPayload,
    );
    final mrrpEncoded = MrrpCodec.encode(mrrpFrame);
    if (mrrpEncoded == null) {
      AppLogging.meshCanvas(
        'outbound channel: MRRP encode rejected '
        '(canvas payload ${canvasPayload.length}B)',
      );
      return CanvasSendResult.failure('mrrp-encode-failed');
    }

    // 3. Wrap in a SIP envelope.
    final sipFrame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.mrrpData,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: 0,
      nonce: SipCodec.generateNonce(),
      timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      payloadLen: mrrpEncoded.length,
      payload: mrrpEncoded,
    );
    final sipEncoded = SipCodec.encode(sipFrame);
    if (sipEncoded == null) {
      AppLogging.meshCanvas(
        'outbound channel: SIP encode rejected '
        '(MRRP frame ${mrrpEncoded.length}B)',
      );
      return CanvasSendResult.failure('sip-encode-failed');
    }

    // 4. Pre-check SIP rate limiter against the same byte basis
    // sendSipGated will charge. On denial we report sipRateLimited
    // WITHOUT calling the wire send; coordinator preserves canvas
    // governor budget in this branch.
    final limiter = _sipRateLimiter;
    if (limiter != null && !limiter.canSend(sipEncoded.length)) {
      AppLogging.meshCanvas(
        'outbound channel: SIP limiter denied '
        '${sipEncoded.length}B (remaining=${limiter.remainingBytes})',
      );
      return CanvasSendResult.sipRateLimited;
    }

    // 5. Hand to ProtocolService. sendSipGated re-checks SIP and
    // consumes on success.
    final ok = await _sender.sendSipGated(
      encoded: sipEncoded,
      type: SipMessageType.mrrpData,
      channelIndex: channelIndex,
    );
    if (ok) {
      AppLogging.meshCanvas(
        'outbound channel: sent action=0x'
        '${action.code.toRadixString(16).padLeft(4, '0')} '
        'canvas=${canvasPayload.length}B '
        'sip=${sipEncoded.length}B channel=$channelIndex',
      );
      return CanvasSendResult.sent(wireBytes: sipEncoded.length);
    }

    // sendSipGated returns false for either (a) SIP limiter raced and
    // denied between pre-check and consume, or (b) transport refused
    // (not connected, encoder rejection, etc.). Disambiguate using the
    // limiter's current state: empty headroom → SIP race; non-empty →
    // transient.
    if (limiter != null && !limiter.canSend(1)) {
      AppLogging.meshCanvas(
        'outbound channel: SIP limiter denied on second check '
        '(race with another sender)',
      );
      return CanvasSendResult.sipRateLimited;
    }
    AppLogging.meshCanvas(
      'outbound channel: sendSipGated returned false '
      '(transient failure: transport not connected or send refused)',
    );
    return CanvasSendResult.failure('send-sip-gated-false');
  }
}
