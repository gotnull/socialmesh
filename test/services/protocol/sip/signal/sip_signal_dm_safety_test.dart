// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the T+S + dedupe guards specific to the SIP Signal DM_SIGNAL
/// path on [SipDmManager]:
///
///   - inbound DM_SIGNAL from a blocked peer: silent drop. No history
///     mutation, no envelope returned, no wire response.
///   - outbound buildSignalMessage to a blocked peer: returns
///     [SipDmSendError.peerBlocked]; no entry appended.
///   - malformed inbound: drop without crashing.
///   - **Dedupe**: identical envelope received twice (same sequenceId
///     and bytes) appends the entry exactly once. The second copy is
///     silently dropped — replays / MQTT-bridge echoes can't double-
///     play.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/peer_safety_gate.dart';
import 'package:socialmesh/services/protocol/sip/signal/sip_signal_codec.dart';
import 'package:socialmesh/services/protocol/sip/signal/sip_signal_constants.dart';
import 'package:socialmesh/services/protocol/sip/signal/sip_signal_payload.dart';
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
    clock: clock ?? () => 1700000000000,
  );
}

SipFrame _frame(int sessionId, Uint8List payload) {
  return SipFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: SipMessageType.dmSignal,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: sessionId,
    nonce: 0,
    timestampS: 1234567890,
    payloadLen: payload.length,
    payload: payload,
  );
}

Uint8List _phraseBytes({int seq = 0x0001}) {
  return SipSignalCodec.encodePhrase(
    sequenceId: seq,
    instrument: SipSignalInstrument.bell,
    notes: [SipSignalNote(midiNote: 60, durationTicks: 18, velocity: 100)],
  )!;
}

void main() {
  group('SipDmManager.handleInboundSignal — block guard', () {
    test('blocked peer DM_SIGNAL is silently dropped, no history mutation', () {
      final gate = _MutableSafetyGate();
      final dm = _newDm(gate: gate);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      final result = dm.handleInboundSignal(_frame(0xAA, _phraseBytes()));
      expect(result, isNull);
      expect(dm.getHistory(0xAA), isEmpty);
    });

    test('unblocked peer DM_SIGNAL appends a signal history entry', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      final result = dm.handleInboundSignal(_frame(0xAA, _phraseBytes()));
      expect(result, isNotNull);
      expect(result!.kind, equals(SipSignalKind.phrase));
      final history = dm.getHistory(0xAA);
      expect(history, isNotNull);
      expect(history!.length, equals(1));
      expect(history.first.contentType, equals(SipDmContentType.signal));
      expect(history.first.direction, equals(SipDmDirection.inbound));
    });

    test('malformed DM_SIGNAL payload is dropped without crashing', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      // Truncated header → SipSignalDecodeError.truncatedHeader.
      final result = dm.handleInboundSignal(
        _frame(0xAA, Uint8List.fromList([0x21])),
      );
      expect(result, isNull);
      expect(dm.getHistory(0xAA), isEmpty);
    });

    test('unknown session tag is dropped', () {
      final dm = _newDm();
      // No session created.
      final result = dm.handleInboundSignal(_frame(0xAA, _phraseBytes()));
      expect(result, isNull);
    });
  });

  group('SipDmManager.handleInboundSignal — dedupe', () {
    test('duplicate inbound (same seq + same bytes) appends exactly once', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      final bytes = _phraseBytes(seq: 0x0042);
      final first = dm.handleInboundSignal(_frame(0xAA, bytes));
      expect(first, isNotNull);
      expect(dm.getHistory(0xAA)!.length, equals(1));

      final second = dm.handleInboundSignal(_frame(0xAA, bytes));
      expect(
        second,
        isNull,
        reason:
            'duplicate inbound must be silently dropped — retransmits / '
            'MQTT bridge echoes cannot double-play',
      );
      expect(
        dm.getHistory(0xAA)!.length,
        equals(1),
        reason: 'history length must NOT grow on duplicate',
      );
    });

    test('different sequenceId or different bytes append separately', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      // Same sender, different sequenceId — distinct phrases.
      dm.handleInboundSignal(_frame(0xAA, _phraseBytes(seq: 0x0001)));
      dm.handleInboundSignal(_frame(0xAA, _phraseBytes(seq: 0x0002)));
      expect(dm.getHistory(0xAA)!.length, equals(2));
    });
  });

  group('SipDmManager.buildSignalMessage — outbound gates', () {
    test('blocked peer returns peerBlocked, no entry, no rate-limit '
        'consumption', () {
      final gate = _MutableSafetyGate();
      final limiter = SipRateLimiter();
      final dm = _newDm(gate: gate, rateLimiter: limiter);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      gate.blocked.add(0xBEEF);

      final result = dm.buildSignalMessage(
        sessionTag: 0xAA,
        signalPayload: _phraseBytes(),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.peerBlocked));
      expect(dm.getHistory(0xAA), isEmpty);
      expect(limiter.canSend(64), isTrue);
    });

    test('happy-path build appends an outbound signal entry + frame', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      final result = dm.buildSignalMessage(
        sessionTag: 0xAA,
        signalPayload: _phraseBytes(),
      );
      expect(result.isOk, isTrue);
      expect(result.frame!.msgType, equals(SipMessageType.dmSignal));
      final history = dm.getHistory(0xAA)!;
      expect(history.length, equals(1));
      expect(history.first.contentType, equals(SipDmContentType.signal));
      expect(history.first.direction, equals(SipDmDirection.outbound));
    });

    test('global airtime budget remains authoritative — outbound blocked '
        'when limiter is starved', () {
      final limiter = SipRateLimiter();
      // Drain the limiter fully.
      while (limiter.canSend(64)) {
        limiter.recordSend(64);
      }
      final dm = _newDm(rateLimiter: limiter);
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      final result = dm.buildSignalMessage(
        sessionTag: 0xAA,
        signalPayload: _phraseBytes(),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.budgetExhausted));
    });

    test('rejects malformed envelope at build time', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);

      // 4 bytes but typeAndVersion = 0x99 (not v1).
      final result = dm.buildSignalMessage(
        sessionTag: 0xAA,
        signalPayload: Uint8List.fromList([0x99, 0x01, 0x00, 0x00]),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.invalidSketch));
    });

    test('payload size cap enforced', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0xBEEF);
      final result = dm.buildSignalMessage(
        sessionTag: 0xAA,
        signalPayload: Uint8List(SipSignalConstants.maxEnvelopeBytes + 1),
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.textTooLong));
    });
  });
}
