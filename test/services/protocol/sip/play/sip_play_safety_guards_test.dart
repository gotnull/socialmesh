// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the T+S guards specific to the SIP Play DM_PLAY path on
/// [SipDmManager]:
///
///   - Inbound DM_PLAY from a blocked peer: silent drop. No history
///     mutation, no engine invocation, no wire response.
///   - Outbound buildPlayMessage to a blocked peer: returns
///     [SipDmSendError.peerBlocked]. No frame is built, no entry
///     appended.
///   - Malformed inbound DM_PLAY: drop without crash. The codec
///     never throws — the manager logs and discards.
///   - Global airtime budget still authoritative: a starved limiter
///     blocks even an unblocked peer's outbound.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/peer_safety_gate.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_constants.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_payload.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

class _MutableSafetyGate implements PeerSafetyGate {
  final Set<int> blocked = {};
  final Set<int> muted = {};

  @override
  bool isBlocked(int peerNodeId) => blocked.contains(peerNodeId);

  @override
  bool isMuted(int peerNodeId) => muted.contains(peerNodeId);
}

SipDmManager _newDm({
  PeerSafetyGate? gate,
  SipRateLimiter? rateLimiter,
  int Function()? clock,
}) {
  return SipDmManager(
    rateLimiter: rateLimiter ?? SipRateLimiter(),
    safetyGate: gate,
    clock: clock ?? () => 1000000,
  );
}

SipFrame _frame(int sessionId, Uint8List payload) {
  return SipFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: SipMessageType.dmPlay,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: sessionId,
    nonce: 0,
    timestampS: 1234567890,
    payloadLen: payload.length,
    payload: payload,
  );
}

Uint8List _offerBytes() {
  return SipPlayCodec.encode(
    SipPlayEnvelope(
      typeAndVersion: SipPlayConstants.envelopeTypeAndVersionV1,
      gameTypeCode: SipPlayGameType.ticTacToe.code,
      instanceId: 0xAB,
      action: SipPlayAction.offer,
      seq: 0,
      gamePayload: Uint8List(0),
    ),
  )!;
}

void main() {
  group('SipDmManager.handleInboundPlay — block guard', () {
    test('blocked peer DM_PLAY is silently dropped, '
        'no history mutation', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      final result = dm.handleInboundPlay(_frame(0xAA, _offerBytes()));
      expect(result, isNull);
      expect(dm.getHistory(0xAA), isEmpty);
    });

    test('unblocked peer DM_PLAY appends a play history entry', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      final result = dm.handleInboundPlay(_frame(0xAA, _offerBytes()));
      expect(result, isNotNull);
      expect(result!.action, equals(SipPlayAction.offer));
      final history = dm.getHistory(0xAA);
      expect(history, isNotNull);
      expect(history!.length, equals(1));
      expect(history.first.contentType, equals(SipDmContentType.play));
      expect(history.first.direction, equals(SipDmDirection.inbound));
    });

    test('malformed DM_PLAY payload is dropped without crashing', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      // Truncated header → SipPlayDecodeError.truncatedHeader.
      final result = dm.handleInboundPlay(
        _frame(0xAA, Uint8List.fromList([0x11, 0x01])),
      );
      expect(result, isNull);
      expect(dm.getHistory(0xAA), isEmpty);
    });

    test('unknown session tag is dropped', () {
      final dm = _newDm();
      // No session created.
      final result = dm.handleInboundPlay(_frame(0xAA, _offerBytes()));
      expect(result, isNull);
    });
  });

  group('SipDmManager.buildPlayMessage — outbound gates', () {
    test('blocked peer returns peerBlocked, no entry appended, '
        'no rate-limiter consumption', () {
      final gate = _MutableSafetyGate();
      final limiter = SipRateLimiter();
      final dm = _newDm(gate: gate, rateLimiter: limiter);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      final result = dm.buildPlayMessage(
        sessionTag: 0xAA,
        playPayload: _offerBytes(),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.peerBlocked));
      expect(dm.getHistory(0xAA), isEmpty);
      // Limiter budget intact — block fired before any consumption.
      expect(limiter.canSend(64), isTrue);
    });

    test('happy-path build appends an outbound play entry + frame', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      final result = dm.buildPlayMessage(
        sessionTag: 0xAA,
        playPayload: _offerBytes(),
      );
      expect(result.isOk, isTrue);
      expect(result.frame!.msgType, equals(SipMessageType.dmPlay));
      final history = dm.getHistory(0xAA)!;
      expect(history.length, equals(1));
      expect(history.first.contentType, equals(SipDmContentType.play));
      expect(history.first.direction, equals(SipDmDirection.outbound));
    });

    test('global airtime budget still authoritative — outbound blocked '
        'when limiter is starved', () {
      // Default-config limiter starts with full budget. Drain it
      // first, then attempt an unrelated send.
      final limiter = SipRateLimiter();
      // Default limiter is 1024B / 60s. Burn the whole budget.
      // Easiest: repeatedly recordSend until canSend is false.
      while (limiter.canSend(64)) {
        limiter.recordSend(64);
      }
      final dm = _newDm(rateLimiter: limiter);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      final result = dm.buildPlayMessage(
        sessionTag: 0xAA,
        playPayload: _offerBytes(),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.budgetExhausted));
    });

    test('rejects malformed envelope at build time '
        '(defence-in-depth on hand-crafted blob)', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      final result = dm.buildPlayMessage(
        sessionTag: 0xAA,
        // 6 bytes but typeAndVersion = 0x22 (not v1) → decode fails.
        playPayload: Uint8List.fromList([0x22, 0x01, 0x00, 0x00, 0x00, 0x00]),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.invalidSketch));
    });
  });
}
