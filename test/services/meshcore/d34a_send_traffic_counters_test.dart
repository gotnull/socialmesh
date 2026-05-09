// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34a — chat-traffic counter regression pins.
//
// These tests pin the in-memory measurement layer that gates the
// future D34 reactions feature. The counters track byte usage,
// rejection counts, per-kind attribution, and rolling 60-s windows;
// the reactions buckets are reserved-only (D34a does NOT implement
// reactions, the buckets exist so D34b can populate them without a
// rename).
//
// Determinism: a fake clock controls every window roll and refill.
// The wall-clock dependency in `_FakeClock` is the only seam; tests
// never sleep.
//
// Privacy invariants pinned:
//   - counters store only ints + kind enum entries + DateTime
//     timestamps. Never a payload, pubkey, channel name, MMF, or
//     envelope byte.
//   - the reactionContact / reactionChannel buckets stay zero across
//     every assertion in this file.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart';

class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  group('MeshCoreSendRateLimiter — D34a counters', () {
    test('initial snapshot is fully empty (zero across all kinds)', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      final s = lim.snapshot();
      expect(s.currentWindowUsedBytes, 0);
      expect(s.currentWindowSentBytes, 0);
      expect(s.currentWindowRejectedBytes, 0);
      expect(s.windowCapacityBytes, 1024);
      expect(s.remainingBytes, 1024);
      expect(s.peakWindowUsage, 0);
      expect(s.rollingAverageBytes, 0.0);
      expect(s.lastRejection, isNull);
      for (final k in MeshCoreSendKind.values) {
        expect(s.sendCountByKind[k], 0, reason: 'send count for $k');
        expect(s.rejectedCountByKind[k], 0, reason: 'rejected count for $k');
      }
      expect(s.isIdle, isTrue);
    });

    test('recordSend(plainContact, allowed) increments plainContact bucket '
        'and bytes', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.recordSend(
        kind: MeshCoreSendKind.plainContact,
        bytes: 42,
        allowed: true,
      );

      final s = lim.snapshot();
      expect(s.currentWindowSentBytes, 42);
      expect(s.currentWindowRejectedBytes, 0);
      expect(s.sendCountByKind[MeshCoreSendKind.plainContact], 1);
      expect(s.sendCountByKind[MeshCoreSendKind.plainChannel], 0);
      expect(s.sendCountByKind[MeshCoreSendKind.replyContact], 0);
      expect(s.sendCountByKind[MeshCoreSendKind.replyChannel], 0);
      expect(s.peakWindowUsage, 42);
      expect(s.lastRejection, isNull);
    });

    test(
      'recordSend(plainChannel, allowed) increments plainChannel bucket',
      () {
        final clock = _FakeClock(DateTime(2026, 5, 9, 12));
        final lim = MeshCoreSendRateLimiter(clock: clock.call);

        lim.recordSend(
          kind: MeshCoreSendKind.plainChannel,
          bytes: 30,
          allowed: true,
        );

        final s = lim.snapshot();
        expect(s.sendCountByKind[MeshCoreSendKind.plainChannel], 1);
        expect(s.sendCountByKind[MeshCoreSendKind.plainContact], 0);
      },
    );

    test(
      'recordSend(replyContact, allowed) increments replyContact bucket',
      () {
        final clock = _FakeClock(DateTime(2026, 5, 9, 12));
        final lim = MeshCoreSendRateLimiter(clock: clock.call);

        lim.recordSend(
          kind: MeshCoreSendKind.replyContact,
          bytes: 80,
          allowed: true,
        );

        final s = lim.snapshot();
        expect(s.sendCountByKind[MeshCoreSendKind.replyContact], 1);
        expect(s.currentWindowSentBytes, 80);
      },
    );

    test(
      'recordSend(replyChannel, allowed) increments replyChannel bucket',
      () {
        final clock = _FakeClock(DateTime(2026, 5, 9, 12));
        final lim = MeshCoreSendRateLimiter(clock: clock.call);

        lim.recordSend(
          kind: MeshCoreSendKind.replyChannel,
          bytes: 70,
          allowed: true,
        );

        final s = lim.snapshot();
        expect(s.sendCountByKind[MeshCoreSendKind.replyChannel], 1);
        expect(s.currentWindowSentBytes, 70);
      },
    );

    test('rate-limited send increments rejected counter and leaves token '
        'bucket unchanged', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      // Drain via tryAcquire+recordSend, mirroring how the session
      // pairs the two calls. After this the bucket is empty AND the
      // sent counter shows 1024.
      lim.tryAcquire(1024);
      lim.recordSend(
        kind: MeshCoreSendKind.plainContact,
        bytes: 1024,
        allowed: true,
      );

      // Next attempt is a genuine rejection: token bucket is empty.
      final r = lim.tryAcquire(50);
      expect(r.allowed, isFalse);
      lim.recordSend(
        kind: MeshCoreSendKind.replyContact,
        bytes: 50,
        allowed: false,
      );

      final s = lim.snapshot();
      expect(s.currentWindowRejectedBytes, 50);
      expect(s.rejectedCountByKind[MeshCoreSendKind.replyContact], 1);
      expect(
        s.currentWindowSentBytes,
        1024,
        reason: 'rejected sends do not bump the sent counter',
      );
      expect(
        s.remainingBytes,
        0,
        reason: 'rejected sends do not consume tokens',
      );
      expect(s.lastRejection, isNotNull);
    });

    test('counters roll over after 60-second window; closing window goes '
        'into rolling average ring', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.recordSend(
        kind: MeshCoreSendKind.plainContact,
        bytes: 200,
        allowed: true,
      );
      expect(lim.snapshot().currentWindowSentBytes, 200);

      // Advance 60 seconds + 1 ms — crosses the boundary.
      clock.advance(const Duration(seconds: 60, milliseconds: 1));
      final s = lim.snapshot();
      expect(
        s.currentWindowSentBytes,
        0,
        reason: 'window rotated; active window is reset',
      );
      expect(
        s.rollingAverageBytes,
        200.0,
        reason: '1 closed window with 200 B → average 200.0',
      );
    });

    test('last 10 windows retained for rolling average; oldest evicts on '
        'the 11th close', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      // Close 11 windows with byte values 1..11. After the 11th
      // close, the rolling average should be over windows 2..11.
      for (int i = 1; i <= 11; i++) {
        lim.recordSend(
          kind: MeshCoreSendKind.plainContact,
          bytes: i,
          allowed: true,
        );
        clock.advance(const Duration(seconds: 60, milliseconds: 1));
      }
      final s = lim.snapshot();
      expect(s.currentWindowSentBytes, 0);
      // Rolling average of [2,3,4,5,6,7,8,9,10,11] = 65/10 = 6.5
      expect(s.rollingAverageBytes, closeTo(6.5, 0.001));
    });

    test('peak usage monotonically tracks the maximum window usage', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.recordSend(
        kind: MeshCoreSendKind.plainContact,
        bytes: 100,
        allowed: true,
      );
      expect(lim.snapshot().peakWindowUsage, 100);

      lim.recordSend(
        kind: MeshCoreSendKind.replyContact,
        bytes: 250,
        allowed: true,
      );
      expect(lim.snapshot().peakWindowUsage, 350);

      // New window — peak holds.
      clock.advance(const Duration(seconds: 60, milliseconds: 1));
      lim.recordSend(
        kind: MeshCoreSendKind.plainChannel,
        bytes: 50,
        allowed: true,
      );
      expect(
        lim.snapshot().peakWindowUsage,
        350,
        reason:
            'peak holds across windows; smaller current win does not '
            'lower it',
      );
    });

    test('reactionContact / reactionChannel buckets exist and stay zero', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.recordSend(
        kind: MeshCoreSendKind.plainContact,
        bytes: 10,
        allowed: true,
      );
      lim.recordSend(
        kind: MeshCoreSendKind.replyChannel,
        bytes: 20,
        allowed: true,
      );

      final s = lim.snapshot();
      expect(s.sendCountByKind[MeshCoreSendKind.reactionContact], 0);
      expect(s.sendCountByKind[MeshCoreSendKind.reactionChannel], 0);
      expect(s.rejectedCountByKind[MeshCoreSendKind.reactionContact], 0);
      expect(s.rejectedCountByKind[MeshCoreSendKind.reactionChannel], 0);
    });

    test('reset() clears all D34a counters AND the token bucket', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.tryAcquire(500);
      lim.recordSend(
        kind: MeshCoreSendKind.replyContact,
        bytes: 500,
        allowed: true,
      );

      lim.reset();

      final s = lim.snapshot();
      expect(s.currentWindowSentBytes, 0);
      expect(s.peakWindowUsage, 0);
      expect(s.remainingBytes, 1024);
      for (final k in MeshCoreSendKind.values) {
        expect(s.sendCountByKind[k], 0);
      }
      expect(s.lastRejection, isNull);
      expect(s.rollingAverageBytes, 0.0);
    });

    test('snapshot maps are unmodifiable (callers cannot mutate the '
        'limiter via the returned view)', () {
      final clock = _FakeClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);
      lim.recordSend(
        kind: MeshCoreSendKind.plainContact,
        bytes: 5,
        allowed: true,
      );
      final s = lim.snapshot();
      expect(
        () => s.sendCountByKind[MeshCoreSendKind.plainContact] = 999,
        throwsUnsupportedError,
      );
      expect(
        () => s.rejectedCountByKind[MeshCoreSendKind.replyContact] = 999,
        throwsUnsupportedError,
      );
    });
  });

  group('MeshCoreSendKind — log tag stability', () {
    test('every kind produces a stable enum-name log tag', () {
      // The log tag is consumed by os_log greps in the field. If a
      // kind is renamed, this test fails so the on-call has to update
      // log analyzers too.
      expect(MeshCoreSendKind.plainContact.logTag, 'plainContact');
      expect(MeshCoreSendKind.plainChannel.logTag, 'plainChannel');
      expect(MeshCoreSendKind.replyContact.logTag, 'replyContact');
      expect(MeshCoreSendKind.replyChannel.logTag, 'replyChannel');
      expect(MeshCoreSendKind.reactionContact.logTag, 'reactionContact');
      expect(MeshCoreSendKind.reactionChannel.logTag, 'reactionChannel');
    });
  });
}
