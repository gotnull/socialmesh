// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SipDmMessages encode/decode
  // ---------------------------------------------------------------------------
  group('SipDmMessages', () {
    test('encodeDm produces valid UTF-8 payload', () {
      final payload = SipDmMessages.encodeDm('Hello');
      expect(payload, isNotNull);
      expect(payload!.length, equals(5));
      // 'Hello' in UTF-8
      expect(
        payload,
        equals(Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F])),
      );
    });

    test('encodeDm rejects empty text', () {
      expect(SipDmMessages.encodeDm(''), isNull);
    });

    test('encodeDm rejects text exceeding max bytes', () {
      // Create a string that exceeds 180 bytes in UTF-8.
      // Each emoji character is 4 bytes in UTF-8.
      final longText = '🎉' * 46; // 46 * 4 = 184 bytes > 180
      expect(SipDmMessages.encodeDm(longText), isNull);
    });

    test('encodeDm accepts text at exactly max bytes', () {
      // 180 ASCII chars = 180 bytes
      final exactText = 'A' * 180;
      final payload = SipDmMessages.encodeDm(exactText);
      expect(payload, isNotNull);
      expect(payload!.length, equals(180));
    });

    test('encodeDm handles multi-byte UTF-8 correctly', () {
      // 'café' = 5 bytes in UTF-8 (c=1, a=1, f=1, é=2)
      final payload = SipDmMessages.encodeDm('café');
      expect(payload, isNotNull);
      expect(payload!.length, equals(5));
    });

    test('decodeDm round-trips with encodeDm', () {
      const original = 'Hello, mesh world! 🌍';
      final encoded = SipDmMessages.encodeDm(original);
      expect(encoded, isNotNull);

      final decoded = SipDmMessages.decodeDm(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.text, equals(original));
      expect(decoded.rawPayload, equals(encoded));
    });

    test('decodeDm rejects empty payload', () {
      expect(SipDmMessages.decodeDm(Uint8List(0)), isNull);
    });

    test('decodeDm rejects oversized payload', () {
      final oversized = Uint8List(SipDmConstants.maxDmTextBytes + 1);
      expect(SipDmMessages.decodeDm(oversized), isNull);
    });

    test('decodeDm rejects invalid UTF-8', () {
      // 0xFF 0xFE is not valid UTF-8
      final invalid = Uint8List.fromList([0xFF, 0xFE]);
      expect(SipDmMessages.decodeDm(invalid), isNull);
    });

    test('utf8ByteLength calculates correctly', () {
      expect(SipDmMessages.utf8ByteLength('Hello'), equals(5));
      expect(SipDmMessages.utf8ByteLength('café'), equals(5));
      expect(SipDmMessages.utf8ByteLength('🎉'), equals(4));
      expect(SipDmMessages.utf8ByteLength(''), equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // SipDmManager session lifecycle
  // ---------------------------------------------------------------------------
  group('SipDmManager session lifecycle', () {
    late SipRateLimiter rateLimiter;
    late int nowMs;
    late SipDmManager dm;

    setUp(() {
      nowMs = 1000000;
      rateLimiter = SipRateLimiter(
        clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      dm = SipDmManager(rateLimiter: rateLimiter, clock: () => nowMs);
    });

    test('createSession creates a new session', () {
      final session = dm.createSession(
        sessionTag: 0x12345678,
        peerNodeId: 0xABCD1234,
      );
      expect(session, isNotNull);
      expect(session!.sessionTag, equals(0x12345678));
      expect(session.peerNodeId, equals(0xABCD1234));
      expect(session.ttlS, equals(SipConstants.dmTtlDefaultS));
      expect(session.isPinned, isFalse);
      expect(session.status, equals(SipDmSessionStatus.active));
      expect(session.messages, isEmpty);
    });

    test('createSession rejects duplicate session tag', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22);
      final dup = dm.createSession(sessionTag: 0x11, peerNodeId: 0x33);
      expect(dup, isNull);
      expect(dm.sessionCount, equals(1));
    });

    test('createSession allows custom TTL', () {
      final session = dm.createSession(
        sessionTag: 0x11,
        peerNodeId: 0x22,
        ttlS: 3600,
      );
      expect(session!.ttlS, equals(3600));
    });

    test('getSession returns active session', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22);
      final session = dm.getSession(0x11);
      expect(session, isNotNull);
      expect(session!.sessionTag, equals(0x11));
    });

    test('getSession returns null for unknown tag', () {
      expect(dm.getSession(0x99), isNull);
    });

    test('getSession returns null for expired session', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22, ttlS: 60);
      // Advance past TTL
      nowMs += 61 * 1000;
      expect(dm.getSession(0x11), isNull);
    });

    test('getSession returns active for pinned session past TTL', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22, ttlS: 60);
      dm.pinSession(0x11);
      // Advance past TTL
      nowMs += 61 * 1000;
      final session = dm.getSession(0x11);
      expect(session, isNotNull);
      expect(session!.isPinned, isTrue);
    });

    test('activeSessions filters expired', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22, ttlS: 60);
      dm.createSession(sessionTag: 0x33, peerNodeId: 0x44, ttlS: 120);
      expect(dm.activeSessions, hasLength(2));

      // Expire first, keep second
      nowMs += 61 * 1000;
      final active = dm.activeSessions;
      expect(active, hasLength(1));
      expect(active.first.sessionTag, equals(0x33));
    });

    test('pinSession returns true and prevents expiry', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22, ttlS: 10);
      expect(dm.pinSession(0x11), isTrue);

      nowMs += 20 * 1000; // Well past TTL
      expect(dm.getSession(0x11), isNotNull);
    });

    test('pinSession returns false for unknown session', () {
      expect(dm.pinSession(0x99), isFalse);
    });

    test('unpinSession returns true and re-enables expiry', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22, ttlS: 10);
      dm.pinSession(0x11);
      expect(dm.unpinSession(0x11), isTrue);

      nowMs += 20 * 1000; // Past TTL
      expect(dm.getSession(0x11), isNull);
    });

    test('unpinSession returns false when not pinned', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22);
      expect(dm.unpinSession(0x11), isFalse);
    });

    test('closeSession marks session as closed and removes it', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22);
      expect(dm.closeSession(0x11), isNotNull);

      // Closed session is still in the map but getSession
      // should return null since status != active on next access
      // Actually closeSession sets status to closed, and
      // getSession returns based on expiry. Let's check
      // behavior: closed sessions should be considered expired.
      // The isExpired method returns true for closed sessions.
      expect(dm.getSession(0x11), isNull);
    });

    test('closeSession returns false for unknown session', () {
      expect(dm.closeSession(0x99), isNull);
    });

    test('cleanExpired removes expired sessions', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22, ttlS: 10);
      dm.createSession(sessionTag: 0x33, peerNodeId: 0x44, ttlS: 120);

      nowMs += 20 * 1000; // First expires, second doesn't
      final removed = dm.cleanExpired();
      expect(removed, equals(1));
      expect(dm.sessionCount, equals(1));
    });

    test('reset clears all sessions', () {
      dm.createSession(sessionTag: 0x11, peerNodeId: 0x22);
      dm.createSession(sessionTag: 0x33, peerNodeId: 0x44);
      dm.reset();
      expect(dm.sessionCount, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // SipDmManager message sending
  // ---------------------------------------------------------------------------
  group('SipDmManager sending', () {
    late SipRateLimiter rateLimiter;
    late int nowMs;
    late SipDmManager dm;

    setUp(() {
      nowMs = 1000000;
      rateLimiter = SipRateLimiter(
        clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      dm = SipDmManager(rateLimiter: rateLimiter, clock: () => nowMs);
      dm.createSession(sessionTag: 0x12345678, peerNodeId: 0xABCD1234);
    });

    test('buildDmMessage produces valid DM_MSG frame', () {
      final result = dm.buildDmMessage(sessionTag: 0x12345678, text: 'Hello');
      expect(result.isOk, isTrue);

      final frame = result.frame!;
      expect(frame.msgType, equals(SipMessageType.dmMsg));
      expect(frame.sessionId, equals(0x12345678));
      expect(frame.payloadLen, equals(5));
      expect(
        frame.payload,
        equals(Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F])),
      );
    });

    test('buildDmMessage adds to session history', () {
      dm.buildDmMessage(sessionTag: 0x12345678, text: 'Hello');
      final history = dm.getHistory(0x12345678);
      expect(history, isNotNull);
      expect(history, hasLength(1));
      expect(history!.first.text, equals('Hello'));
      expect(history.first.direction, equals(SipDmDirection.outbound));
    });

    test('buildDmMessage records against budget', () {
      final initialResult = dm.buildDmMessage(
        sessionTag: 0x12345678,
        text: 'Hello',
      );
      expect(initialResult.isOk, isTrue);
      // Budget should have been decremented by frame size
      expect(rateLimiter.usageFraction, greaterThan(0.0));
    });

    test('buildDmMessage rejects empty text', () {
      final result = dm.buildDmMessage(sessionTag: 0x12345678, text: '');
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.emptyText));
    });

    test('buildDmMessage rejects text exceeding max bytes', () {
      final result = dm.buildDmMessage(
        sessionTag: 0x12345678,
        text: 'A' * 200, // 200 bytes > 180
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.textTooLong));
    });

    test('buildDmMessage rejects unknown session', () {
      final result = dm.buildDmMessage(sessionTag: 0x99999999, text: 'Hello');
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.sessionNotFound));
    });

    test('buildDmMessage rejects expired session', () {
      dm.createSession(sessionTag: 0x44, peerNodeId: 0x55, ttlS: 10);
      nowMs += 20 * 1000;
      final result = dm.buildDmMessage(sessionTag: 0x44, text: 'Hello');
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.sessionNotFound));
    });

    test('buildDmMessage rejects closed session', () {
      dm.closeSession(0x12345678);

      // Create a new session so we can test close behavior
      dm.createSession(sessionTag: 0x55, peerNodeId: 0x66);
      dm.closeSession(0x55);

      // closeSession triggers expiry-removal, so session is gone
      final result = dm.buildDmMessage(sessionTag: 0x55, text: 'Hello');
      expect(result.isOk, isFalse);
      // Session is removed on close (isExpired returns true for closed)
      expect(result.error, equals(SipDmSendError.sessionNotFound));
    });

    test('buildDmMessage rejects when budget exhausted', () {
      // Consume the full budget
      for (var i = 0; i < 40; i++) {
        rateLimiter.recordSend(SipConstants.sipBudgetBytesPer60s ~/ 10);
      }

      final result = dm.buildDmMessage(sessionTag: 0x12345678, text: 'Hello');
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.budgetExhausted));
    });

    test('frame can be encoded to wire format', () {
      final result = dm.buildDmMessage(sessionTag: 0x12345678, text: 'Test');
      expect(result.isOk, isTrue);

      final wire = SipCodec.encode(result.frame!);
      expect(wire, isNotNull);

      // Decode back and verify
      final decoded = SipCodec.decode(wire!);
      expect(decoded, isNotNull);
      expect(decoded!.msgType, equals(SipMessageType.dmMsg));
      expect(decoded.sessionId, equals(0x12345678));

      final msg = SipDmMessages.decodeDm(decoded.payload);
      expect(msg, isNotNull);
      expect(msg!.text, equals('Test'));
    });
  });

  // ---------------------------------------------------------------------------
  // SipDmManager message receiving
  // ---------------------------------------------------------------------------
  group('SipDmManager receiving', () {
    late SipRateLimiter rateLimiter;
    late int nowMs;
    late SipDmManager dm;

    setUp(() {
      nowMs = 1000000;
      rateLimiter = SipRateLimiter(
        clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      dm = SipDmManager(rateLimiter: rateLimiter, clock: () => nowMs);
      dm.createSession(sessionTag: 0x12345678, peerNodeId: 0xABCD1234);
    });

    SipFrame buildInboundDm(int sessionTag, String text) {
      final payload = SipDmMessages.encodeDm(text)!;
      return SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.dmMsg,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: sessionTag,
        nonce: SipCodec.generateNonce(),
        timestampS: nowMs ~/ 1000,
        payloadLen: payload.length,
        payload: payload,
      );
    }

    test('handleInboundDm processes message for known session', () {
      final frame = buildInboundDm(0x12345678, 'Hello back');
      final msg = dm.handleInboundDm(frame);
      expect(msg, isNotNull);
      expect(msg!.text, equals('Hello back'));
    });

    test('handleInboundDm adds to session history', () {
      dm.handleInboundDm(buildInboundDm(0x12345678, 'Msg 1'));
      dm.handleInboundDm(buildInboundDm(0x12345678, 'Msg 2'));

      final history = dm.getHistory(0x12345678);
      expect(history, hasLength(2));
      expect(history![0].direction, equals(SipDmDirection.inbound));
      expect(history[0].text, equals('Msg 1'));
      expect(history[1].text, equals('Msg 2'));
    });

    test('handleInboundDm drops unknown session_tag', () {
      final frame = buildInboundDm(0x99999999, 'Secret');
      final msg = dm.handleInboundDm(frame);
      expect(msg, isNull);
    });

    test('handleInboundDm drops expired session', () {
      dm.createSession(sessionTag: 0x44, peerNodeId: 0x55, ttlS: 10);
      nowMs += 20 * 1000;
      final frame = buildInboundDm(0x44, 'Too late');
      final msg = dm.handleInboundDm(frame);
      expect(msg, isNull);
    });

    test('handleInboundDm drops wrong msg_type', () {
      final frame = SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.capBeacon,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0x12345678,
        nonce: 0,
        timestampS: 0,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      expect(dm.handleInboundDm(frame), isNull);
    });

    test('handleInboundDm drops invalid UTF-8 payload', () {
      final frame = SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.dmMsg,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0x12345678,
        nonce: 0,
        timestampS: nowMs ~/ 1000,
        payloadLen: 2,
        payload: Uint8List.fromList([0xFF, 0xFE]),
      );
      expect(dm.handleInboundDm(frame), isNull);
    });

    test('interleaved send/receive history preserves order', () {
      // Send
      dm.buildDmMessage(sessionTag: 0x12345678, text: 'Out 1');
      // Receive
      dm.handleInboundDm(buildInboundDm(0x12345678, 'In 1'));
      // Send
      dm.buildDmMessage(sessionTag: 0x12345678, text: 'Out 2');

      final history = dm.getHistory(0x12345678)!;
      expect(history, hasLength(3));
      expect(history[0].direction, equals(SipDmDirection.outbound));
      expect(history[0].text, equals('Out 1'));
      expect(history[1].direction, equals(SipDmDirection.inbound));
      expect(history[1].text, equals('In 1'));
      expect(history[2].direction, equals(SipDmDirection.outbound));
      expect(history[2].text, equals('Out 2'));
    });
  });

  // ---------------------------------------------------------------------------
  // SipDmSession expiry logic
  // ---------------------------------------------------------------------------
  group('SipDmSession expiry', () {
    test('isExpired false within TTL', () {
      final session = SipDmSession(
        sessionTag: 0x11,
        peerNodeId: 0x22,
        createdAtMs: 1000,
        ttlS: 60,
      );
      expect(session.isExpired(1000 + 59 * 1000), isFalse);
    });

    test('isExpired true at TTL boundary', () {
      final session = SipDmSession(
        sessionTag: 0x11,
        peerNodeId: 0x22,
        createdAtMs: 1000,
        ttlS: 60,
      );
      expect(session.isExpired(1000 + 60 * 1000), isTrue);
    });

    test('isExpired false when pinned', () {
      final session = SipDmSession(
        sessionTag: 0x11,
        peerNodeId: 0x22,
        createdAtMs: 1000,
        ttlS: 60,
        isPinned: true,
      );
      expect(session.isExpired(1000 + 120 * 1000), isFalse);
    });

    test('isExpired true when closed', () {
      final session = SipDmSession(
        sessionTag: 0x11,
        peerNodeId: 0x22,
        createdAtMs: 1000,
        ttlS: 60,
        status: SipDmSessionStatus.closed,
      );
      // Even within TTL, closed is expired
      expect(session.isExpired(1000), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Full wire round-trip
  // ---------------------------------------------------------------------------
  group('DM wire round-trip', () {
    test('encode -> decode -> handle preserves message', () {
      var nowMs = 1000000;
      final rateLimiter = SipRateLimiter(
        clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );

      // Sender
      final sender = SipDmManager(rateLimiter: rateLimiter, clock: () => nowMs);
      sender.createSession(sessionTag: 0xAA, peerNodeId: 0xBB);

      // Build and encode
      final sendResult = sender.buildDmMessage(
        sessionTag: 0xAA,
        text: 'Hey there! 👋',
      );
      expect(sendResult.isOk, isTrue);

      final wire = SipCodec.encode(sendResult.frame!);
      expect(wire, isNotNull);

      // Receiver: different DM manager, same session_tag
      final receiver = SipDmManager(
        rateLimiter: SipRateLimiter(
          clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
        ),
        clock: () => nowMs,
      );
      receiver.createSession(sessionTag: 0xAA, peerNodeId: 0xCC);

      // Decode and handle
      final decoded = SipCodec.decode(wire!);
      expect(decoded, isNotNull);

      final received = receiver.handleInboundDm(decoded!);
      expect(received, isNotNull);
      expect(received!.text, equals('Hey there! 👋'));

      // Verify both histories
      final senderHistory = sender.getHistory(0xAA)!;
      expect(senderHistory, hasLength(1));
      expect(senderHistory.first.direction, equals(SipDmDirection.outbound));

      final receiverHistory = receiver.getHistory(0xAA)!;
      expect(receiverHistory, hasLength(1));
      expect(receiverHistory.first.direction, equals(SipDmDirection.inbound));
    });
  });
}
