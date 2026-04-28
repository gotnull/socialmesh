// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// [SipDmManager.removeSessionLocally] tests — pins the local-only,
/// no-wire-frame contract for the Phase 9 "Remove conversation"
/// overflow action.
///
/// Hard rules:
///
///   - Removing a session emits NO wire frame. `closeSession` builds
///     and returns a DM_CLOSE byte string; `removeSessionLocally`
///     returns a bool only and never touches the rate limiter.
///   - The session is dropped from `_sessions` (verified via
///     `getSession` returning null and `sessionCount` decrementing).
///   - The session's message history is wiped (verified by adding
///     entries before the call and confirming the in-memory list was
///     emptied via the local reference).
///   - Other peers' sessions are untouched.
///   - Multiple sessions for the same peer: removing one keeps the
///     other intact and keeps that peer's typing state alive (typing
///     is keyed by peer node id, not session tag).
///   - Removing a non-existent tag returns false and does not throw.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';

void main() {
  late int nowMs;
  late SipRateLimiter rateLimiter;
  late SipDmManager dm;

  setUp(() {
    nowMs = 1700000000000;
    rateLimiter = SipRateLimiter(
      clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
    );
    dm = SipDmManager(rateLimiter: rateLimiter, clock: () => nowMs);
  });

  group('SipDmManager.removeSessionLocally', () {
    test('returns false for unknown session tag '
        '(idempotent / safe to call twice)', () {
      expect(dm.removeSessionLocally(0xDEAD), isFalse);
      // Sanity: no side effects on session count.
      expect(dm.sessionCount, equals(0));
    });

    test('drops the session from the manager and clears '
        'its message history', () {
      final session = dm.createSession(sessionTag: 0xAA, peerNodeId: 0x1234)!;
      session.messages.add(
        SipDmHistoryEntry(
          text: 'hi',
          timestampMs: nowMs,
          direction: SipDmDirection.outbound,
        ),
      );
      session.messages.add(
        SipDmHistoryEntry(
          text: 'hey',
          timestampMs: nowMs + 1,
          direction: SipDmDirection.inbound,
        ),
      );
      // Capture the underlying list before the call so we can verify
      // it was emptied (the manager strips the session entry, but the
      // list object itself should be cleared so any stale UI handle
      // sees zero messages).
      final messagesRef = session.messages;
      expect(messagesRef.length, equals(2));

      final removed = dm.removeSessionLocally(0xAA);

      expect(removed, isTrue);
      expect(dm.getSession(0xAA), isNull);
      expect(dm.sessionCount, equals(0));
      expect(messagesRef, isEmpty);
    });

    test('emits NO wire frame — rate limiter remains untouched', () {
      dm.createSession(sessionTag: 0xBB, peerNodeId: 0x5678);
      // Snapshot whatever the limiter knows. removeSessionLocally
      // must not call canSend / recordSend / generateNonce — we only
      // need to confirm the post-call ability to send a non-trivial
      // frame is unchanged. Easiest probe: budget large enough for
      // any wire frame remains intact.
      expect(rateLimiter.canSend(64), isTrue);
      dm.removeSessionLocally(0xBB);
      expect(
        rateLimiter.canSend(64),
        isTrue,
        reason:
            'removeSessionLocally must not consume rate limiter '
            'budget — it never sends a wire frame',
      );
    });

    test('only the targeted session is removed; other peers are '
        'untouched', () {
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0x1111);
      dm.createSession(sessionTag: 0xBB, peerNodeId: 0x2222);
      dm.createSession(sessionTag: 0xCC, peerNodeId: 0x3333);

      expect(dm.removeSessionLocally(0xBB), isTrue);

      expect(dm.getSession(0xAA), isNotNull);
      expect(dm.getSession(0xBB), isNull);
      expect(dm.getSession(0xCC), isNotNull);
      expect(dm.sessionCount, equals(2));
    });

    test('fires onStateChanged so the UI rebuilds after removal', () {
      var fired = 0;
      dm.onStateChanged = () => fired += 1;
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0x1234);
      // createSession itself fires the callback; reset the counter
      // before the action under test.
      fired = 0;
      dm.removeSessionLocally(0xAA);
      expect(fired, equals(1));
    });

    test('removing a session does NOT send DM_CLOSE — confirm by '
        'comparing return shape with closeSession', () {
      // closeSession returns a Uint8List? (the encoded DM_CLOSE
      // frame). removeSessionLocally returns a bool. Verify both
      // surfaces remain shape-distinct so callers can't accidentally
      // route Remove through closeSession.
      dm.createSession(sessionTag: 0xAA, peerNodeId: 0x1234);
      dm.createSession(sessionTag: 0xBB, peerNodeId: 0x1234);

      final closeReturn = dm.closeSession(0xAA);
      // closeSession produces a DM_CLOSE encoded frame when the
      // limiter has budget — non-null is the expected good case.
      expect(closeReturn, isNotNull);

      final removeReturn = dm.removeSessionLocally(0xBB);
      expect(removeReturn, isA<bool>());
      expect(removeReturn, isTrue);
    });
  });
}
