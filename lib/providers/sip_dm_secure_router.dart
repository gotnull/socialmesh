// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Phase 2 DM transport router: decides between the v0.3 secure
/// overlay path and the v0.1 plaintext SIP DM path for a given send.
///
/// Callers use [SipDmRouter.sendText] / [SipDmRouter.sendReaction] as
/// a single entry point. The router evaluates the encrypt-when-all-
/// true gate per message, picks exactly one transport, and executes
/// it. It never duplicates: a message is either secure or plaintext,
/// not both.
///
/// Typing (`0x41`) is explicitly NOT routed here — it stays on the
/// existing plaintext path unconditionally per product policy.
///
/// Incoming secure DM / reaction traffic is handled by
/// [sipSecureDmIngressProvider]: it subscribes to the secure
/// manager's inbound stream, rebuilds synthetic SIP frames from the
/// decrypted payload, and feeds them through the existing
/// `SipDmManager.handleInboundDm` / `handleInboundReaction` path so
/// the rest of the DM pipeline (timeline, reactions, dedup, UI
/// rebuild) continues to work identically.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../services/protocol/overlay/overlay_secure_session_manager.dart';
import '../services/protocol/overlay/overlay_types.dart';
import '../services/protocol/sip/peer_rate_limiter.dart';
import '../services/protocol/sip/sip_codec.dart';
import '../services/protocol/sip/sip_constants.dart';
import '../services/protocol/sip/sip_dm.dart';
import '../services/protocol/sip/sip_frame.dart';
import '../services/protocol/sip/sip_messages_dm.dart';
import '../services/protocol/sip/sip_types.dart';
import 'app_providers.dart';
import 'overlay_providers.dart';
import 'peer_safety_providers.dart';
import 'sip_providers.dart';

/// Which transport a DM send actually used.
enum SipDmTransport { plaintext, secure }

/// Why the router fell back to plaintext (for diagnostics).
enum SipDmFallbackReason {
  /// Secure feature flag is off.
  secureFlagOff,

  /// Peer's last-advertised CAP_RESP did not include `overlaySecureV03`.
  peerMissingSecureBit,

  /// No canonical overlay link exists for the peer.
  noCanonicalLink,

  /// Canonical link exists but the secure session has not been
  /// negotiated (or failed).
  sessionNotEstablished,

  /// Secure stack is not wired (no manager or store). Safety net for
  /// tests and early startup.
  secureStackUnavailable,
}

/// Why a SIP Ink send was hard-blocked at the router (no fallback).
///
/// Distinct from [SipDmFallbackReason] because these are terminal —
/// e.g. no point falling back to plaintext when the peer has not
/// advertised support for the type at all.
enum SipDmInkBlockReason {
  /// Peer has not advertised `dmInkV1` in its CAP_RESP. Sending would
  /// be wasted airtime; the peer would drop the unknown msg_type.
  peerUnsupported,

  /// SIP discovery has not surfaced a peer entry for the session yet.
  peerUnknown,
}

/// Result of a routed DM send.
class SipDmRouterOutcome {
  final bool isOk;
  final SipDmTransport? transport;
  final SipDmFallbackReason? fallbackReason;
  final SipDmSendError? error;
  final SipDmInkBlockReason? inkBlockReason;

  const SipDmRouterOutcome._({
    required this.isOk,
    this.transport,
    this.fallbackReason,
    this.error,
    this.inkBlockReason,
  });

  const SipDmRouterOutcome.ok({
    required SipDmTransport transport,
    SipDmFallbackReason? fallbackReason,
  }) : this._(isOk: true, transport: transport, fallbackReason: fallbackReason);

  const SipDmRouterOutcome.fail(SipDmSendError error)
    : this._(isOk: false, error: error);

  const SipDmRouterOutcome.failInk({
    required SipDmInkBlockReason reason,
    required SipDmSendError error,
  }) : this._(isOk: false, error: error, inkBlockReason: reason);
}

/// Single entry point the UI uses for DM send. Not a `Notifier` —
/// just a plain helper that takes a [Ref] and pulls collaborators on
/// demand.
class SipDmRouter {
  final Ref _ref;
  SipDmRouter(this._ref);

  /// Send a DM text message. Picks secure when the gate passes,
  /// plaintext otherwise. Never both.
  Future<SipDmRouterOutcome> sendText({
    required int sessionTag,
    required String text,
  }) async {
    final dm = _ref.read(sipDmManagerProvider);
    if (dm == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }
    final session = dm.getSession(sessionTag);
    if (session == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }

    // T+S gate stack (in canonical order):
    //   1. hard safety gate
    //   2. peer capability + session state (existing — handled inside
    //      `_evaluateGate` and the plaintext/secure send paths)
    //   3. per-peer rate gate
    //   4. global SipRateLimiter (handled inside `buildDmMessage`)
    //   5. send
    if (_ref.read(peerSafetyGateProvider).isBlocked(session.peerNodeId)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerBlocked);
    }
    if (!_ref
        .read(peerRateLimiterProvider)
        .tryAcquire(session.peerNodeId, PeerRateKind.text)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerRateLimited);
    }

    final gate = await _evaluateGate(session.peerNodeId);
    if (gate is _GatePass) {
      return _sendSecureText(
        sessionTag: sessionTag,
        peerNodeId: session.peerNodeId,
        linkId: gate.linkId,
        text: text,
      );
    }
    return _sendPlaintextText(
      sessionTag: sessionTag,
      text: text,
      fallbackReason: (gate as _GateFail).reason,
    );
  }

  /// Send a SIP Ink (sketch) message.
  ///
  /// [inkPayload] must be the byte sequence produced by
  /// `SipInkEncoder.encode`. The router enforces:
  ///   1. peer has advertised `dmInkV1` (terminal block on miss),
  ///   2. session is active and known,
  ///   3. encoded size + envelope fits the rate limiter,
  ///   4. secure-when-all-true gate same as [sendText].
  ///
  /// Returns `SipDmRouterOutcome.failInk(...)` when the peer does not
  /// support sketches — the UI should disable the Sketch tab in that
  /// case so this branch is defence-in-depth, not the primary gate.
  Future<SipDmRouterOutcome> sendSketch({
    required int sessionTag,
    required Uint8List inkPayload,
  }) async {
    final dm = _ref.read(sipDmManagerProvider);
    if (dm == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }
    final session = dm.getSession(sessionTag);
    if (session == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }

    // Hard peer-feature gate. Distinct from the secure gate because
    // this is "peer can't render sketches at all" — falling back to
    // plaintext over a non-supporting peer just wastes airtime.
    final discovery = _ref.read(sipDiscoveryProvider);
    if (discovery == null) {
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnknown,
        error: SipDmSendError.peerUnsupported,
      );
    }
    final peer = discovery.getPeer(session.peerNodeId);
    if (peer == null) {
      AppLogging.sipInk(
        'send_blocked reason=peer_unknown peer=0x'
        '${session.peerNodeId.toRadixString(16)}',
      );
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnknown,
        error: SipDmSendError.peerUnsupported,
      );
    }
    if (!peer.supportsDmInkV1) {
      AppLogging.sipInk(
        'send_blocked reason=peer_unsupported peer=0x'
        '${session.peerNodeId.toRadixString(16)}',
      );
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnsupported,
        error: SipDmSendError.peerUnsupported,
      );
    }

    // T+S gate stack (canonical order — see sendText for the full
    // rationale). Block check fires AFTER the peer-feature gate so
    // we don't re-leak the unsupported-peer signal to a blocked
    // peer; both terminate the send before the global limiter is
    // touched.
    if (_ref.read(peerSafetyGateProvider).isBlocked(session.peerNodeId)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerBlocked);
    }
    if (!_ref
        .read(peerRateLimiterProvider)
        .tryAcquire(session.peerNodeId, PeerRateKind.sketch)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerRateLimited);
    }

    final gate = await _evaluateGate(session.peerNodeId);
    if (gate is _GatePass) {
      return _sendSecureSketch(
        sessionTag: sessionTag,
        peerNodeId: session.peerNodeId,
        linkId: gate.linkId,
        inkPayload: inkPayload,
      );
    }
    return _sendPlaintextSketch(
      sessionTag: sessionTag,
      inkPayload: inkPayload,
      fallbackReason: (gate as _GateFail).reason,
    );
  }

  /// Send a SIP Play (turn-based mini-game) action.
  ///
  /// [playPayload] must be the byte sequence produced by
  /// `SipPlayCodec.encode` (a v1 SIP Play envelope). The router enforces:
  ///   1. peer has advertised `dmPlayV1` (terminal block on miss),
  ///   2. session is active and known,
  ///   3. T+S block + per-peer rate gate (PeerRateKind.play),
  ///   4. encoded size + envelope fits the rate limiter,
  ///   5. secure-when-all-true gate same as [sendText].
  ///
  /// Returns `SipDmRouterOutcome.failInk(...)` shape (reusing
  /// [SipDmInkBlockReason] — peer-feature gate is the same family of
  /// terminal failure) when the peer does not advertise SIP Play.
  /// The UI should hide the Play composer mode when this fails.
  Future<SipDmRouterOutcome> sendPlay({
    required int sessionTag,
    required Uint8List playPayload,
  }) async {
    final dm = _ref.read(sipDmManagerProvider);
    if (dm == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }
    final session = dm.getSession(sessionTag);
    if (session == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }

    // Hard peer-feature gate. Distinct from the secure gate — peers
    // without dmPlayV1 silently drop unknown 0x46 frames, so sending
    // would be wasted airtime.
    final discovery = _ref.read(sipDiscoveryProvider);
    if (discovery == null) {
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnknown,
        error: SipDmSendError.peerUnsupported,
      );
    }
    final peer = discovery.getPeer(session.peerNodeId);
    if (peer == null) {
      AppLogging.sipPlay(
        'send_blocked reason=peer_unknown peer=0x'
        '${session.peerNodeId.toRadixString(16)}',
      );
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnknown,
        error: SipDmSendError.peerUnsupported,
      );
    }
    if (!peer.supportsDmPlayV1) {
      AppLogging.sipPlay(
        'send_blocked reason=peer_unsupported peer=0x'
        '${session.peerNodeId.toRadixString(16)}',
      );
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnsupported,
        error: SipDmSendError.peerUnsupported,
      );
    }

    // T+S gate stack — canonical order, matches sendText/sendSketch.
    if (_ref.read(peerSafetyGateProvider).isBlocked(session.peerNodeId)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerBlocked);
    }
    if (!_ref
        .read(peerRateLimiterProvider)
        .tryAcquire(session.peerNodeId, PeerRateKind.play)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerRateLimited);
    }

    final gate = await _evaluateGate(session.peerNodeId);
    if (gate is _GatePass) {
      return _sendSecurePlay(
        sessionTag: sessionTag,
        peerNodeId: session.peerNodeId,
        linkId: gate.linkId,
        playPayload: playPayload,
      );
    }
    return _sendPlaintextPlay(
      sessionTag: sessionTag,
      playPayload: playPayload,
      fallbackReason: (gate as _GateFail).reason,
    );
  }

  /// Send a SIP Signal (musical phrase or Morse) envelope.
  ///
  /// [signalPayload] must be the byte sequence produced by
  /// `SipSignalCodec.encodePhrase` or `SipSignalCodec.encodeMorse`.
  /// The router enforces:
  ///   1. peer has advertised `dmSignalV1` (terminal block on miss),
  ///   2. session is active and known,
  ///   3. T+S block + per-peer rate gate (PeerRateKind.signal),
  ///   4. encoded size + envelope fits the rate limiter,
  ///   5. secure-when-all-true gate same as [sendText].
  Future<SipDmRouterOutcome> sendSignal({
    required int sessionTag,
    required Uint8List signalPayload,
  }) async {
    final dm = _ref.read(sipDmManagerProvider);
    if (dm == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }
    final session = dm.getSession(sessionTag);
    if (session == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }

    // Hard peer-feature gate. Distinct from the secure gate — peers
    // without dmSignalV1 silently drop unknown 0x47 frames.
    final discovery = _ref.read(sipDiscoveryProvider);
    if (discovery == null) {
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnknown,
        error: SipDmSendError.peerUnsupported,
      );
    }
    final peer = discovery.getPeer(session.peerNodeId);
    if (peer == null) {
      AppLogging.sipSignal(
        'send_blocked reason=peer_unknown peer=0x'
        '${session.peerNodeId.toRadixString(16)}',
      );
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnknown,
        error: SipDmSendError.peerUnsupported,
      );
    }
    if (!peer.supportsDmSignalV1) {
      AppLogging.sipSignal(
        'send_blocked reason=peer_unsupported peer=0x'
        '${session.peerNodeId.toRadixString(16)}',
      );
      return const SipDmRouterOutcome.failInk(
        reason: SipDmInkBlockReason.peerUnsupported,
        error: SipDmSendError.peerUnsupported,
      );
    }

    // T+S gate stack — canonical order, matches sendText/sendSketch/sendPlay.
    if (_ref.read(peerSafetyGateProvider).isBlocked(session.peerNodeId)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerBlocked);
    }
    if (!_ref
        .read(peerRateLimiterProvider)
        .tryAcquire(session.peerNodeId, PeerRateKind.signal)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerRateLimited);
    }

    final gate = await _evaluateGate(session.peerNodeId);
    if (gate is _GatePass) {
      return _sendSecureSignal(
        sessionTag: sessionTag,
        peerNodeId: session.peerNodeId,
        linkId: gate.linkId,
        signalPayload: signalPayload,
      );
    }
    return _sendPlaintextSignal(
      sessionTag: sessionTag,
      signalPayload: signalPayload,
      fallbackReason: (gate as _GateFail).reason,
    );
  }

  /// Send a DM reaction. Same routing rules as [sendText].
  Future<SipDmRouterOutcome> sendReaction({
    required int sessionTag,
    required int emojiIndex,
    required SipDmHistoryEntry targetEntry,
  }) async {
    final dm = _ref.read(sipDmManagerProvider);
    if (dm == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }
    final session = dm.getSession(sessionTag);
    if (session == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionNotFound);
    }

    // T+S gate stack — same as sendText.
    if (_ref.read(peerSafetyGateProvider).isBlocked(session.peerNodeId)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerBlocked);
    }
    if (!_ref
        .read(peerRateLimiterProvider)
        .tryAcquire(session.peerNodeId, PeerRateKind.reaction)) {
      return const SipDmRouterOutcome.fail(SipDmSendError.peerRateLimited);
    }

    final gate = await _evaluateGate(session.peerNodeId);
    if (gate is _GatePass) {
      return _sendSecureReaction(
        sessionTag: sessionTag,
        peerNodeId: session.peerNodeId,
        linkId: gate.linkId,
        emojiIndex: emojiIndex,
        targetEntry: targetEntry,
      );
    }
    return _sendPlaintextReaction(
      sessionTag: sessionTag,
      emojiIndex: emojiIndex,
      targetEntry: targetEntry,
      fallbackReason: (gate as _GateFail).reason,
    );
  }

  // ---------------------------------------------------------------
  // Gate evaluation
  // ---------------------------------------------------------------

  Future<_GateResult> _evaluateGate(int peerNodeId) async {
    final flags = _ref.read(overlayFlagProvider);
    if (!flags.secureActive) {
      return const _GateFail(SipDmFallbackReason.secureFlagOff);
    }
    final discovery = _ref.read(sipDiscoveryProvider);
    if (discovery == null) {
      return const _GateFail(SipDmFallbackReason.secureStackUnavailable);
    }
    final peer = discovery.getPeer(peerNodeId);
    if (peer == null || !peer.supportsOverlaySecureV03) {
      return const _GateFail(SipDmFallbackReason.peerMissingSecureBit);
    }

    final store = await _ref.read(overlayLinkStoreProvider.future);
    final records = await store.getNonTerminalForPeerNode(peerNodeId);
    if (records.isEmpty) {
      return const _GateFail(SipDmFallbackReason.noCanonicalLink);
    }
    final canonical = records.first;

    final secureMgr = await _ref.read(
      overlaySecureSessionManagerProvider.future,
    );
    if (!secureMgr.isEstablished(canonical.linkId)) {
      return const _GateFail(SipDmFallbackReason.sessionNotEstablished);
    }
    return _GatePass(linkId: canonical.linkId, manager: secureMgr);
  }

  // ---------------------------------------------------------------
  // Secure send paths
  // ---------------------------------------------------------------

  Future<SipDmRouterOutcome> _sendSecureText({
    required int sessionTag,
    required int peerNodeId,
    required int linkId,
    required String text,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final session = dm.getSession(sessionTag)!;
    if (session.status != SipDmSessionStatus.active) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionClosed);
    }
    if (text.isEmpty) {
      return const SipDmRouterOutcome.fail(SipDmSendError.emptyText);
    }
    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = SipDmMessages.encodeSecureDmText(
      text: text,
      timestampS: nowS,
    );
    if (payload == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }

    final manager = await _ref.read(overlaySecureSessionManagerProvider.future);
    final sent = await manager.sendEncrypted(
      linkId,
      payload,
      subtype: OverlaySecureDataSubtype.dmText,
    );
    if (!sent) {
      // Manager rejected (session went away mid-flight). Treat as
      // plaintext fallback so the message still goes out.
      AppLogging.sip(
        'SIP_DM: secure send rejected mid-flight linkId=0x'
        '${linkId.toRadixString(16)} — falling back to plaintext',
      );
      return _sendPlaintextText(
        sessionTag: sessionTag,
        text: text,
        fallbackReason: SipDmFallbackReason.sessionNotEstablished,
      );
    }

    // Mirror plaintext bookkeeping: append to local history so the
    // sender's own timeline renders the message they just sent. Use
    // [SipDmManager.parseReplyToText] for the quote — historically
    // this branch incorrectly used `extractReplyBody`, which returns
    // the BODY (the user's reply text) and stored that as the quote,
    // making the sender's local bubble appear to reply to itself.
    session.messages.add(
      SipDmHistoryEntry(
        text: text,
        timestampMs: nowS * 1000,
        direction: SipDmDirection.outbound,
        replyToText: SipDmManager.parseReplyToText(text),
      ),
    );
    dm.onStateChanged?.call();

    AppLogging.sip(
      'SIP_DM: secure_selected tag=0x${sessionTag.toRadixString(16)} '
      'linkId=0x${linkId.toRadixString(16)} subtype=dmText '
      'peer=0x${peerNodeId.toRadixString(16)}',
    );
    return const SipDmRouterOutcome.ok(transport: SipDmTransport.secure);
  }

  Future<SipDmRouterOutcome> _sendSecureReaction({
    required int sessionTag,
    required int peerNodeId,
    required int linkId,
    required int emojiIndex,
    required SipDmHistoryEntry targetEntry,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final session = dm.getSession(sessionTag)!;
    if (session.status != SipDmSessionStatus.active) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionClosed);
    }

    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final payload = SipDmMessages.encodeSecureReaction(
      timestampS: nowS,
      emojiIndex: emojiIndex,
      targetTimestampS: targetEntry.timestampMs ~/ 1000,
    );
    if (payload == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }

    final manager = await _ref.read(overlaySecureSessionManagerProvider.future);
    final sent = await manager.sendEncrypted(
      linkId,
      payload,
      subtype: OverlaySecureDataSubtype.dmReaction,
    );
    if (!sent) {
      AppLogging.sip(
        'SIP_DM: secure reaction rejected mid-flight — plaintext fallback',
      );
      return _sendPlaintextReaction(
        sessionTag: sessionTag,
        emojiIndex: emojiIndex,
        targetEntry: targetEntry,
        fallbackReason: SipDmFallbackReason.sessionNotEstablished,
      );
    }

    targetEntry.localReaction = emojiIndex;
    dm.onStateChanged?.call();

    AppLogging.sip(
      'SIP_DM: secure_selected tag=0x${sessionTag.toRadixString(16)} '
      'linkId=0x${linkId.toRadixString(16)} subtype=dmReaction '
      'peer=0x${peerNodeId.toRadixString(16)}',
    );
    return const SipDmRouterOutcome.ok(transport: SipDmTransport.secure);
  }

  Future<SipDmRouterOutcome> _sendSecureSketch({
    required int sessionTag,
    required int peerNodeId,
    required int linkId,
    required Uint8List inkPayload,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final session = dm.getSession(sessionTag)!;
    if (session.status != SipDmSessionStatus.active) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionClosed);
    }
    if (inkPayload.isEmpty) {
      return const SipDmRouterOutcome.fail(SipDmSendError.emptyText);
    }

    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final wrapped = SipDmMessages.encodeSecureDmInk(
      inkPayload: inkPayload,
      timestampS: nowS,
    );
    if (wrapped == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }

    final manager = await _ref.read(overlaySecureSessionManagerProvider.future);
    final sent = await manager.sendEncrypted(
      linkId,
      wrapped,
      subtype: OverlaySecureDataSubtype.dmInk,
    );
    if (!sent) {
      AppLogging.sipInk(
        'secure_send_rejected mid_flight linkId=0x'
        '${linkId.toRadixString(16)} — falling back to plaintext',
      );
      return _sendPlaintextSketch(
        sessionTag: sessionTag,
        inkPayload: inkPayload,
        fallbackReason: SipDmFallbackReason.sessionNotEstablished,
      );
    }

    // Mirror plaintext bookkeeping so the sender's own timeline
    // renders the sketch immediately.
    session.messages.add(
      SipDmHistoryEntry(
        text: '',
        timestampMs: nowS * 1000,
        direction: SipDmDirection.outbound,
        contentType: SipDmContentType.ink,
        payload: Uint8List.fromList(inkPayload),
      ),
    );
    dm.onStateChanged?.call();

    AppLogging.sipInk(
      'secure_selected tag=0x${sessionTag.toRadixString(16)} '
      'linkId=0x${linkId.toRadixString(16)} subtype=dmInk '
      'peer=0x${peerNodeId.toRadixString(16)} '
      'payload_bytes=${inkPayload.length} envelope_bytes=${wrapped.length}',
    );
    return const SipDmRouterOutcome.ok(transport: SipDmTransport.secure);
  }

  // ---------------------------------------------------------------
  // Plaintext fallback paths (unchanged semantics vs pre-Phase-2)
  // ---------------------------------------------------------------

  Future<SipDmRouterOutcome> _sendPlaintextText({
    required int sessionTag,
    required String text,
    required SipDmFallbackReason fallbackReason,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final result = dm.buildDmMessage(sessionTag: sessionTag, text: text);
    if (!result.isOk) {
      return SipDmRouterOutcome.fail(result.error ?? SipDmSendError.emptyText);
    }
    final encoded = SipCodec.encode(result.frame!);
    if (encoded == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }
    final protocol = _ref.read(protocolServiceProvider);
    await protocol.sendSipPacket(encoded);
    _ref
        .read(sipCountersProvider)
        .recordTx(result.frame!.msgType, encoded.length);

    AppLogging.sip(
      'SIP_DM: plaintext_selected tag=0x${sessionTag.toRadixString(16)} '
      'subtype=dmText reason=${fallbackReason.name}',
    );
    return SipDmRouterOutcome.ok(
      transport: SipDmTransport.plaintext,
      fallbackReason: fallbackReason,
    );
  }

  Future<SipDmRouterOutcome> _sendPlaintextSketch({
    required int sessionTag,
    required Uint8List inkPayload,
    required SipDmFallbackReason fallbackReason,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final result = dm.buildInkMessage(
      sessionTag: sessionTag,
      inkPayload: inkPayload,
    );
    if (!result.isOk) {
      return SipDmRouterOutcome.fail(result.error ?? SipDmSendError.emptyText);
    }
    final encoded = SipCodec.encode(result.frame!);
    if (encoded == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }
    final protocol = _ref.read(protocolServiceProvider);
    await protocol.sendSipPacket(encoded);
    _ref
        .read(sipCountersProvider)
        .recordTx(result.frame!.msgType, encoded.length);

    AppLogging.sipInk(
      'plaintext_selected tag=0x${sessionTag.toRadixString(16)} '
      'subtype=dmInk reason=${fallbackReason.name} '
      'payload_bytes=${inkPayload.length} frame_bytes=${encoded.length}',
    );
    return SipDmRouterOutcome.ok(
      transport: SipDmTransport.plaintext,
      fallbackReason: fallbackReason,
    );
  }

  Future<SipDmRouterOutcome> _sendSecurePlay({
    required int sessionTag,
    required int peerNodeId,
    required int linkId,
    required Uint8List playPayload,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final session = dm.getSession(sessionTag)!;
    if (session.status != SipDmSessionStatus.active) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionClosed);
    }
    if (playPayload.isEmpty) {
      return const SipDmRouterOutcome.fail(SipDmSendError.emptyText);
    }

    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final wrapped = SipDmMessages.encodeSecureDmPlay(
      playPayload: playPayload,
      timestampS: nowS,
    );
    if (wrapped == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }

    final manager = await _ref.read(overlaySecureSessionManagerProvider.future);
    final sent = await manager.sendEncrypted(
      linkId,
      wrapped,
      subtype: OverlaySecureDataSubtype.dmPlay,
    );
    if (!sent) {
      AppLogging.sipPlay(
        'secure_send_rejected mid_flight linkId=0x'
        '${linkId.toRadixString(16)} — falling back to plaintext',
      );
      return _sendPlaintextPlay(
        sessionTag: sessionTag,
        playPayload: playPayload,
        fallbackReason: SipDmFallbackReason.sessionNotEstablished,
      );
    }

    // Mirror plaintext bookkeeping so the sender's own timeline
    // renders the game move immediately. The engine derives state
    // from the entry stream regardless of which transport carried
    // the bytes.
    session.messages.add(
      SipDmHistoryEntry(
        text: '',
        timestampMs: nowS * 1000,
        direction: SipDmDirection.outbound,
        contentType: SipDmContentType.play,
        payload: Uint8List.fromList(playPayload),
      ),
    );
    dm.onStateChanged?.call();

    AppLogging.sipPlay(
      'secure_selected tag=0x${sessionTag.toRadixString(16)} '
      'linkId=0x${linkId.toRadixString(16)} subtype=dmPlay '
      'peer=0x${peerNodeId.toRadixString(16)} '
      'payload_bytes=${playPayload.length} envelope_bytes=${wrapped.length}',
    );
    return const SipDmRouterOutcome.ok(transport: SipDmTransport.secure);
  }

  Future<SipDmRouterOutcome> _sendPlaintextPlay({
    required int sessionTag,
    required Uint8List playPayload,
    required SipDmFallbackReason fallbackReason,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final result = dm.buildPlayMessage(
      sessionTag: sessionTag,
      playPayload: playPayload,
    );
    if (!result.isOk) {
      return SipDmRouterOutcome.fail(result.error ?? SipDmSendError.emptyText);
    }
    final encoded = SipCodec.encode(result.frame!);
    if (encoded == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }
    final protocol = _ref.read(protocolServiceProvider);
    await protocol.sendSipPacket(encoded);
    _ref
        .read(sipCountersProvider)
        .recordTx(result.frame!.msgType, encoded.length);

    AppLogging.sipPlay(
      'plaintext_selected tag=0x${sessionTag.toRadixString(16)} '
      'subtype=dmPlay reason=${fallbackReason.name} '
      'payload_bytes=${playPayload.length} frame_bytes=${encoded.length}',
    );
    return SipDmRouterOutcome.ok(
      transport: SipDmTransport.plaintext,
      fallbackReason: fallbackReason,
    );
  }

  Future<SipDmRouterOutcome> _sendSecureSignal({
    required int sessionTag,
    required int peerNodeId,
    required int linkId,
    required Uint8List signalPayload,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final session = dm.getSession(sessionTag)!;
    if (session.status != SipDmSessionStatus.active) {
      return const SipDmRouterOutcome.fail(SipDmSendError.sessionClosed);
    }
    if (signalPayload.isEmpty) {
      return const SipDmRouterOutcome.fail(SipDmSendError.emptyText);
    }

    final nowS = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final wrapped = SipDmMessages.encodeSecureDmSignal(
      signalPayload: signalPayload,
      timestampS: nowS,
    );
    if (wrapped == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }

    final manager = await _ref.read(overlaySecureSessionManagerProvider.future);
    final sent = await manager.sendEncrypted(
      linkId,
      wrapped,
      subtype: OverlaySecureDataSubtype.dmSignal,
    );
    if (!sent) {
      AppLogging.sipSignal(
        'secure_send_rejected mid_flight linkId=0x'
        '${linkId.toRadixString(16)} — falling back to plaintext',
      );
      return _sendPlaintextSignal(
        sessionTag: sessionTag,
        signalPayload: signalPayload,
        fallbackReason: SipDmFallbackReason.sessionNotEstablished,
      );
    }

    // Mirror plaintext bookkeeping so the sender's own timeline
    // renders the signal immediately. The receiver dedupes by
    // (sequenceId, payloadHash) so a sender-side echo is irrelevant.
    session.messages.add(
      SipDmHistoryEntry(
        text: '',
        timestampMs: nowS * 1000,
        direction: SipDmDirection.outbound,
        contentType: SipDmContentType.signal,
        payload: Uint8List.fromList(signalPayload),
      ),
    );
    dm.onStateChanged?.call();

    AppLogging.sipSignal(
      'secure_selected tag=0x${sessionTag.toRadixString(16)} '
      'linkId=0x${linkId.toRadixString(16)} subtype=dmSignal '
      'peer=0x${peerNodeId.toRadixString(16)} '
      'payload_bytes=${signalPayload.length} envelope_bytes=${wrapped.length}',
    );
    return const SipDmRouterOutcome.ok(transport: SipDmTransport.secure);
  }

  Future<SipDmRouterOutcome> _sendPlaintextSignal({
    required int sessionTag,
    required Uint8List signalPayload,
    required SipDmFallbackReason fallbackReason,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final result = dm.buildSignalMessage(
      sessionTag: sessionTag,
      signalPayload: signalPayload,
    );
    if (!result.isOk) {
      return SipDmRouterOutcome.fail(result.error ?? SipDmSendError.emptyText);
    }
    final encoded = SipCodec.encode(result.frame!);
    if (encoded == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.textTooLong);
    }
    final protocol = _ref.read(protocolServiceProvider);
    await protocol.sendSipPacket(encoded);
    _ref
        .read(sipCountersProvider)
        .recordTx(result.frame!.msgType, encoded.length);

    AppLogging.sipSignal(
      'plaintext_selected tag=0x${sessionTag.toRadixString(16)} '
      'subtype=dmSignal reason=${fallbackReason.name} '
      'payload_bytes=${signalPayload.length} frame_bytes=${encoded.length}',
    );
    return SipDmRouterOutcome.ok(
      transport: SipDmTransport.plaintext,
      fallbackReason: fallbackReason,
    );
  }

  Future<SipDmRouterOutcome> _sendPlaintextReaction({
    required int sessionTag,
    required int emojiIndex,
    required SipDmHistoryEntry targetEntry,
    required SipDmFallbackReason fallbackReason,
  }) async {
    final dm = _ref.read(sipDmManagerProvider)!;
    final encoded = dm.buildDmReaction(
      sessionTag: sessionTag,
      emojiIndex: emojiIndex,
      targetEntry: targetEntry,
    );
    if (encoded == null) {
      return const SipDmRouterOutcome.fail(SipDmSendError.budgetExhausted);
    }
    final protocol = _ref.read(protocolServiceProvider);
    await protocol.sendSipPacket(encoded);

    AppLogging.sip(
      'SIP_DM: plaintext_selected tag=0x${sessionTag.toRadixString(16)} '
      'subtype=dmReaction reason=${fallbackReason.name}',
    );
    return SipDmRouterOutcome.ok(
      transport: SipDmTransport.plaintext,
      fallbackReason: fallbackReason,
    );
  }
}

/// Provider for the router. Rebuilds only when upstream providers
/// invalidate — the router itself is cheap to construct.
final sipDmRouterProvider = Provider<SipDmRouter>((ref) {
  return SipDmRouter(ref);
});

/// Result of [SipDmRouter._evaluateGate]. Private sealed hierarchy.
sealed class _GateResult {
  const _GateResult();
}

class _GatePass extends _GateResult {
  final int linkId;
  final OverlaySecureSessionManager manager;
  const _GatePass({required this.linkId, required this.manager});
}

class _GateFail extends _GateResult {
  final SipDmFallbackReason reason;
  const _GateFail(this.reason);
}

// =============================================================================
// Secure inbound DM ingress
// =============================================================================

/// Resolve which [SipDmSession] should receive a decrypted secure
/// inbound DM payload.
///
/// Primary path — match by the `peerNodeNum` carried on the link
/// store record for the inbound `linkId`. That's the authoritative
/// pairing when overlay link state is consistent.
///
/// Recovery path — when the canonical lookup yields no session AND
/// exactly one DM session is active, route the frame to that session
/// and emit `secure_decrypt_recovered`. This salvages the multi-device
/// cross-peer linkId-collision scenario where the link store's
/// `peerNodeNum` is stale from a prior link to a different peer (the
/// AEAD decrypt has already succeeded by the time we get here, so
/// the secure session keys are authoritatively tied to whichever
/// peer the frame really came from). With 0 or 2+ sessions we refuse
/// to guess and emit `secure_decrypt_dropped reason=no_dm_session`.
///
/// This is a recovery path, NOT normal routing — the underlying
/// poisoned link record is fixed in `OverlayLinkEngine._handleLinkOpen`
/// (cross-peer linkId collisions are now rejected at LINK_OPEN time).
/// Public so the regression test can pin both branches.
SipDmSession? resolveSecureInboundDmSession({
  required SipDmManager dm,
  required int linkRecordPeerNodeId,
  required int linkId,
}) {
  final byPeer = dm.activeSessions
      .where((s) => s.peerNodeId == linkRecordPeerNodeId)
      .fold<SipDmSession?>(null, (_, s) => s);
  if (byPeer != null) return byPeer;

  final candidates = dm.activeSessions;
  if (candidates.length == 1) {
    final fallback = candidates.first;
    AppLogging.sip(
      'SIP_DM: secure_decrypt_recovered '
      'linkId=0x${linkId.toRadixString(16)} '
      'record_peer=0x${linkRecordPeerNodeId.toRadixString(16)} '
      'session_peer=0x${fallback.peerNodeId.toRadixString(16)} '
      'session_tag=0x${fallback.sessionTag.toRadixString(16)} '
      '— link store reported a stale peer for this linkId; falling '
      'back to the only active DM session',
    );
    return fallback;
  }

  AppLogging.sip(
    'SIP_DM: secure_decrypt_dropped reason=no_dm_session '
    'peer=0x${linkRecordPeerNodeId.toRadixString(16)} '
    'active_sessions=${candidates.length}',
  );
  return null;
}

/// Subscribes to [OverlaySecureSessionManager.inbound] and routes
/// decrypted DM / reaction payloads into the existing plaintext DM
/// ingress path by rebuilding a synthetic [SipFrame].
///
/// Design choice: reuse, don't duplicate. The synthesized frame has
/// `msg_type = dmMsg | dmReaction` and the sender-provided
/// `timestampS`, so `SipDmManager.handleInboundDm` and
/// `handleInboundReaction` behave identically whether the frame
/// arrived plaintext or over the secure substrate.
///
/// The provider is a `FutureProvider<void>` because it awaits the
/// manager future; its return value is ignored. Its sole purpose is
/// lifecycle ownership of the stream subscription.
final sipSecureDmIngressProvider = FutureProvider<void>((ref) async {
  final flags = ref.watch(overlayFlagProvider);
  if (!flags.secureActive) return;

  final secureMgr = await ref.watch(overlaySecureSessionManagerProvider.future);
  final linkStore = await ref.watch(overlayLinkStoreProvider.future);

  final sub = secureMgr.inbound.listen((payload) {
    _handleSecureDmInbound(ref: ref, linkStore: linkStore, payload: payload);
  });
  ref.onDispose(sub.cancel);
});

Future<void> _handleSecureDmInbound({
  required Ref ref,
  required dynamic
  linkStore, // OverlayLinkStore — kept dynamic to avoid import circularity
  required OverlaySecureInboundPayload payload,
}) async {
  final dm = ref.read(sipDmManagerProvider);
  if (dm == null) return;

  // Resolve peerNodeNum from the link record so we can find the
  // matching DM session and synthesize a SIP frame with the right
  // session_id.
  final record = await linkStore.getByLinkId(payload.linkId);
  if (record == null) {
    AppLogging.sip(
      'SIP_DM: secure_decrypt_dropped reason=no_link '
      'linkId=0x${payload.linkId.toRadixString(16)}',
    );
    return;
  }
  final peerNodeId = record.peerNodeNum as int;

  final dmSession = resolveSecureInboundDmSession(
    dm: dm,
    linkRecordPeerNodeId: peerNodeId,
    linkId: payload.linkId,
  );
  if (dmSession == null) return;

  // T+S guard: silent drop of secure DM payloads from blocked
  // peers. Fires AFTER `resolveSecureInboundDmSession` so the
  // recovery path (which uses the only-active-session fallback for
  // poisoned link records) has produced the authoritative peer
  // node id. Defence-in-depth — the SipDmManager.handleInbound*
  // guards would also catch this, but stopping here keeps the
  // peer node id out of any `secure_decrypt_ok` log line.
  final safetyGate = ref.read(peerSafetyGateProvider);
  if (safetyGate.isBlocked(dmSession.peerNodeId)) return;

  switch (payload.subtype) {
    case OverlaySecureDataSubtype.dmText:
      final decoded = SipDmMessages.decodeSecureDmText(payload.cleartext);
      if (decoded == null) {
        AppLogging.sip(
          'SIP_DM: secure_decrypt_dropped reason=malformed subtype=dmText',
        );
        return;
      }
      final frame = _synthesizeDmFrame(
        sessionTag: dmSession.sessionTag,
        timestampS: decoded.timestampS,
        body: decoded.message.rawPayload,
        msgType: SipMessageType.dmMsg,
      );
      dm.handleInboundDm(frame);
      AppLogging.sip(
        'SIP_DM: secure_decrypt_ok linkId=0x${payload.linkId.toRadixString(16)} '
        'subtype=dmText peer=0x${peerNodeId.toRadixString(16)} '
        'len=${decoded.message.rawPayload.length}B',
      );
      return;

    case OverlaySecureDataSubtype.dmInk:
      final decoded = SipDmMessages.decodeSecureDmInk(payload.cleartext);
      if (decoded == null) {
        AppLogging.sipInk(
          'secure_decrypt_dropped reason=malformed subtype=dmInk',
        );
        return;
      }
      final frame = _synthesizeDmFrame(
        sessionTag: dmSession.sessionTag,
        timestampS: decoded.timestampS,
        body: decoded.inkPayload,
        msgType: SipMessageType.dmInk,
      );
      dm.handleInboundInk(frame);
      AppLogging.sipInk(
        'secure_decrypt_ok linkId=0x${payload.linkId.toRadixString(16)} '
        'subtype=dmInk peer=0x${peerNodeId.toRadixString(16)} '
        'bytes=${decoded.inkPayload.length}',
      );
      return;

    case OverlaySecureDataSubtype.dmPlay:
      final decoded = SipDmMessages.decodeSecureDmPlay(payload.cleartext);
      if (decoded == null) {
        AppLogging.sipPlay(
          'secure_decrypt_dropped reason=malformed subtype=dmPlay',
        );
        return;
      }
      final frame = _synthesizeDmFrame(
        sessionTag: dmSession.sessionTag,
        timestampS: decoded.timestampS,
        body: decoded.playPayload,
        msgType: SipMessageType.dmPlay,
      );
      dm.handleInboundPlay(frame);
      AppLogging.sipPlay(
        'secure_decrypt_ok linkId=0x${payload.linkId.toRadixString(16)} '
        'subtype=dmPlay peer=0x${peerNodeId.toRadixString(16)} '
        'bytes=${decoded.playPayload.length}',
      );
      return;

    case OverlaySecureDataSubtype.dmSignal:
      final decoded = SipDmMessages.decodeSecureDmSignal(payload.cleartext);
      if (decoded == null) {
        AppLogging.sipSignal(
          'secure_decrypt_dropped reason=malformed subtype=dmSignal',
        );
        return;
      }
      final frame = _synthesizeDmFrame(
        sessionTag: dmSession.sessionTag,
        timestampS: decoded.timestampS,
        body: decoded.signalPayload,
        msgType: SipMessageType.dmSignal,
      );
      dm.handleInboundSignal(frame);
      AppLogging.sipSignal(
        'secure_decrypt_ok linkId=0x${payload.linkId.toRadixString(16)} '
        'subtype=dmSignal peer=0x${peerNodeId.toRadixString(16)} '
        'bytes=${decoded.signalPayload.length}',
      );
      return;

    case OverlaySecureDataSubtype.dmReaction:
      final decoded = SipDmMessages.decodeSecureReaction(payload.cleartext);
      if (decoded == null) {
        AppLogging.sip(
          'SIP_DM: secure_decrypt_dropped reason=malformed subtype=dmReaction',
        );
        return;
      }
      final body = SipDmMessages.encodeReaction(
        emojiIndex: decoded.reaction.emojiIndex,
        targetTimestampS: decoded.reaction.targetTimestampS,
      );
      if (body == null) {
        AppLogging.sip(
          'SIP_DM: secure_decrypt_dropped reason=reencode_failed '
          'subtype=dmReaction',
        );
        return;
      }
      final frame = _synthesizeDmFrame(
        sessionTag: dmSession.sessionTag,
        timestampS: decoded.timestampS,
        body: body,
        msgType: SipMessageType.dmReaction,
      );
      dm.handleInboundReaction(frame);
      AppLogging.sip(
        'SIP_DM: secure_decrypt_ok linkId=0x${payload.linkId.toRadixString(16)} '
        'subtype=dmReaction peer=0x${peerNodeId.toRadixString(16)}',
      );
      return;

    default:
      AppLogging.sip(
        'SIP_DM: secure subtype=${payload.subtype.name} ignored '
        '(not a DM subtype)',
      );
      return;
  }
}

/// Build a synthetic [SipFrame] for feeding decrypted secure DM /
/// reaction bodies into the existing plaintext ingress path. Fields
/// that the handlers read (msgType, sessionId, timestampS, payload)
/// are populated; fields that aren't read (nonce, flags, headerLen,
/// version) get sensible defaults.
SipFrame _synthesizeDmFrame({
  required int sessionTag,
  required int timestampS,
  required Uint8List body,
  required SipMessageType msgType,
}) {
  return SipFrame(
    versionMajor: SipConstants.sipVersionMajor,
    versionMinor: SipConstants.sipVersionMinor,
    msgType: msgType,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: sessionTag,
    nonce: 0,
    timestampS: timestampS,
    payloadLen: body.length,
    payload: body,
  );
}
