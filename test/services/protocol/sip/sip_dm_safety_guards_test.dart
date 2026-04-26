// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the T+S guards inside [SipDmManager]. For every inbound and
/// outbound handler that takes a session tag, a blocked-peer check
/// fires before any state mutation or wire egress. Inbound is silent
/// (returns null/void without flipping state); outbound returns
/// [SipDmSendError.peerBlocked] on the typed paths and silently
/// suppresses on the void typing/delete builders.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/peer_safety_gate.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_encoder.dart';
import 'package:socialmesh/services/protocol/sip/sip_ink_payload.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_dm.dart';
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

SipDmManager _newDm({PeerSafetyGate? gate, int Function()? clock}) {
  return SipDmManager(
    rateLimiter: SipRateLimiter(),
    safetyGate: gate,
    clock: clock ?? () => 1000000,
  );
}

SipFrame _frame(SipMessageType type, int sessionId, Uint8List payload) {
  return SipFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: type,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: sessionId,
    nonce: 0,
    timestampS: 1234567890,
    payloadLen: payload.length,
    payload: payload,
  );
}

void main() {
  group('SipDmManager — inbound block guards', () {
    test('blocked peer DM_MSG is silently dropped (no history mutation)', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      final result = dm.handleInboundDm(
        _frame(
          SipMessageType.dmMsg,
          0xAA,
          Uint8List.fromList('hello'.codeUnits),
        ),
      );
      expect(result, isNull);
      expect(dm.getHistory(0xAA), isEmpty);
    });

    test('blocked peer DM_TYPING does not surface isPeerTyping', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      dm.handleInboundTyping(
        _frame(SipMessageType.dmTyping, 0xAA, Uint8List(0)),
      );
      expect(dm.isPeerTyping(0xAA), isFalse);
    });

    test('blocked peer DM_REACTION cannot mutate prior history entries', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      // Seed an outbound entry so the reaction has a target to land on.
      dm.buildDmMessage(sessionTag: 0xAA, text: 'mine');
      gate.blocked.add(0xBEEF);

      final reactionPayload = SipDmMessages.encodeReaction(
        emojiIndex: 0,
        targetTimestampS: 1000, // doesn't matter — guard fires first
      )!;
      dm.handleInboundReaction(
        _frame(SipMessageType.dmReaction, 0xAA, reactionPayload),
      );
      final history = dm.getHistory(0xAA)!;
      expect(history, hasLength(1));
      expect(history.first.peerReaction, isNull);
    });

    test('blocked peer DM_DELETE cannot remove local messages', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      dm.buildDmMessage(sessionTag: 0xAA, text: 'mine');
      gate.blocked.add(0xBEEF);

      final deletePayload = SipDmMessages.encodeDelete(
        targetTimestampS: 1000, // doesn't matter — guard fires first
      );
      dm.handleInboundDelete(
        _frame(SipMessageType.dmDelete, 0xAA, deletePayload),
      );
      // Original message is still in history.
      expect(dm.getHistory(0xAA), hasLength(1));
    });

    test('blocked peer DM_CLOSE cannot flip session status', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      dm.handleInboundClose(_frame(SipMessageType.dmClose, 0xAA, Uint8List(0)));
      // Session is still in active state — block prevented status flip.
      expect(dm.getSession(0xAA)?.status, equals(SipDmSessionStatus.active));
    });

    test('blocked peer DM_INK is silently dropped', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      // A valid ink payload (1 stroke, 2 points).
      final inkBytes = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: SipInkConstants.canvas64,
          strokes: const [
            SipInkStroke(
              width: 1,
              points: [SipInkPoint(0, 0), SipInkPoint(1, 1)],
            ),
          ],
        ),
      ).bytes!;

      // Sanity: when not blocked, ink is accepted.
      final acceptedSketch = dm.handleInboundInk(
        _frame(SipMessageType.dmInk, 0xAA, inkBytes),
      );
      expect(acceptedSketch, isNotNull);
      expect(dm.getHistory(0xAA), hasLength(1));

      // Now block; second inbound is silently dropped.
      gate.blocked.add(0xBEEF);
      final blockedSketch = dm.handleInboundInk(
        _frame(SipMessageType.dmInk, 0xAA, inkBytes),
      );
      expect(blockedSketch, isNull);
      expect(
        dm.getHistory(0xAA),
        hasLength(1),
        reason: 'blocked inbound ink must NOT be appended to history',
      );
    });
  });

  group('SipDmManager — outbound block guards', () {
    test('buildDmMessage to a blocked peer fails with peerBlocked', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      final result = dm.buildDmMessage(sessionTag: 0xAA, text: 'hi');
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.peerBlocked));
    });

    test('buildInkMessage to a blocked peer fails with peerBlocked', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      final inkBytes = SipInkEncoder.encode(
        SipInkSketch(
          canvasSize: SipInkConstants.canvas64,
          strokes: const [
            SipInkStroke(
              width: 1,
              points: [SipInkPoint(0, 0), SipInkPoint(1, 1)],
            ),
          ],
        ),
      ).bytes!;
      final result = dm.buildInkMessage(sessionTag: 0xAA, inkPayload: inkBytes);
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.peerBlocked));
    });

    test('buildTypingIndicator to a blocked peer returns null silently', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      expect(dm.buildTypingIndicator(sessionTag: 0xAA), isNull);
    });

    test('buildDmReaction to a blocked peer returns null silently', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      // Seed a target.
      dm.buildDmMessage(sessionTag: 0xAA, text: 'a');
      final target = dm.getHistory(0xAA)!.single;
      gate.blocked.add(0xBEEF);

      expect(
        dm.buildDmReaction(
          sessionTag: 0xAA,
          emojiIndex: 0,
          targetEntry: target,
        ),
        isNull,
      );
    });

    test('buildDmDelete to a blocked peer returns null (UI falls back '
        'to local-only delete)', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      dm.buildDmMessage(sessionTag: 0xAA, text: 'mine');
      final target = dm.getHistory(0xAA)!.single;
      gate.blocked.add(0xBEEF);

      expect(
        dm.buildDmDelete(sessionTag: 0xAA, targetEntry: target),
        isNull,
        reason:
            'wire egress is silent for blocked peers — the UI removes '
            'the message locally via SipDmManager.removeMessage',
      );
    });
  });

  group('SipDmManager — default-safe gate', () {
    test(
      'omitting safetyGate defaults to NoopPeerSafetyGate (no blocking)',
      () {
        // Smoke: existing tests construct SipDmManager without a gate;
        // verify the default-safe path lets every existing behaviour
        // through unchanged.
        final dm = _newDm();
        dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
        final result = dm.buildDmMessage(sessionTag: 0xAA, text: 'hi');
        expect(result.isOk, isTrue);
      },
    );
  });
}
