// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D33 P2 — MeshCoreSendRateLimiter unit tests.
//
// Pins the token-bucket invariants the chat-meta envelope (and
// future reaction frames) rely on for fair airtime sharing.
// Determinism via injected clock so the proportional-refill maths
// stays decoupled from wall-clock flakiness.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart';

class _FakeClock {
  DateTime _now;
  _FakeClock(this._now);
  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}

void main() {
  group('MeshCoreSendRateLimiter — token bucket basics', () {
    test('starts with full bucket at default capacity 1024 B', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);
      expect(lim.capacity, 1024);
      expect(lim.remainingBytes, 1024);
      expect(lim.usageFraction, 0.0);
    });

    test('tryAcquire(<=remaining) succeeds and deducts', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      final r1 = lim.tryAcquire(100);
      expect(r1.allowed, isTrue);
      expect(r1.remainingBytes, 924);
      expect(r1.nextSendIn, Duration.zero);

      final r2 = lim.tryAcquire(200);
      expect(r2.allowed, isTrue);
      expect(r2.remainingBytes, 724);
      expect(r2.nextSendIn, Duration.zero);
    });

    test('tryAcquire(>remaining) rejects without deducting', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      // Drain to 50 bytes left.
      lim.tryAcquire(974);
      expect(lim.remainingBytes, 50);

      // Request 100 bytes — over budget.
      final rejected = lim.tryAcquire(100);
      expect(rejected.allowed, isFalse);
      expect(
        rejected.remainingBytes,
        50,
        reason: 'reject must NOT deduct from the bucket',
      );
      expect(rejected.nextSendIn, greaterThan(Duration.zero));

      // Verify the bucket is still 50 bytes for the next caller.
      expect(lim.remainingBytes, 50);
    });

    test('tryAcquire(0) and tryAcquire(<0) are no-op pass-throughs', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      final r0 = lim.tryAcquire(0);
      expect(r0.allowed, isTrue);
      expect(r0.remainingBytes, 1024);

      final rNeg = lim.tryAcquire(-50);
      expect(rNeg.allowed, isTrue);
      expect(rNeg.remainingBytes, 1024);
    });

    test('tryAcquire(>capacity) rejects permanently with full-window wait', () {
      // A single payload larger than the entire bucket can never fit.
      // Useful: surfaces "message too large" via the long nextSendIn
      // hint instead of looping the user through retries.
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      final huge = lim.tryAcquire(2000);
      expect(huge.allowed, isFalse);
      // nextSendIn equals the full window when over-capacity.
      expect(huge.nextSendIn, Duration(milliseconds: lim.windowMs));
      // Bucket is unchanged.
      expect(lim.remainingBytes, 1024);
    });
  });

  group('MeshCoreSendRateLimiter — proportional refill', () {
    test('partial-window elapsed time refills proportionally', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      // Drain entirely.
      lim.tryAcquire(1024);
      expect(lim.remainingBytes, 0);

      // Advance 30s = half-window. Should refill ~512 bytes.
      clock.advance(const Duration(seconds: 30));
      // remainingBytes triggers a refill.
      final remaining = lim.remainingBytes;
      // Allow ±1 byte for integer-division rounding.
      expect(
        remaining,
        inInclusiveRange(511, 513),
        reason: 'half-window refill should be ~512 B (proportional)',
      );
    });

    test('full-window elapsed time refills to capacity', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.tryAcquire(1024);
      expect(lim.remainingBytes, 0);

      clock.advance(const Duration(seconds: 60));
      expect(lim.remainingBytes, 1024);
    });

    test('over-window elapsed time clamps refill at capacity', () {
      // Idle for an hour after a full drain. Bucket must NOT
      // accumulate beyond capacity (no "saved-up" sends).
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.tryAcquire(1024);
      expect(lim.remainingBytes, 0);

      clock.advance(const Duration(hours: 1));
      expect(lim.remainingBytes, 1024);
    });

    test('refill happens lazily on access, not on idle ticks', () {
      // Time-skew test: a long sleep followed by a single tryAcquire
      // should refill correctly without needing intervening calls.
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.tryAcquire(1024);
      clock.advance(const Duration(seconds: 60));

      final r = lim.tryAcquire(500);
      expect(r.allowed, isTrue);
      expect(r.remainingBytes, 524);
    });
  });

  group('MeshCoreSendRateLimiter — nextSendIn estimate', () {
    test('nextSendIn equals the time required to refill the shortfall', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.tryAcquire(1000); // 24 left
      // Request 124 bytes — short by 100.
      final rejected = lim.tryAcquire(124);
      expect(rejected.allowed, isFalse);

      // Refill rate at default = 1024 B / 60_000 ms = ~17 B/s.
      // 100 bytes shortfall / (1024 / 60000) = ~5859 ms.
      // Allow generous tolerance for ceil() + integer maths.
      expect(
        rejected.nextSendIn.inMilliseconds,
        inInclusiveRange(5500, 6200),
        reason: 'nextSendIn ~= 100 / (1024/60000) ms = ~5859 ms',
      );
    });

    test('successful acquire returns Duration.zero for nextSendIn', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);
      final r = lim.tryAcquire(50);
      expect(r.allowed, isTrue);
      expect(r.nextSendIn, Duration.zero);
    });
  });

  group('MeshCoreSendRateLimiter — reset', () {
    test('reset() restores capacity and resets refill clock', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      lim.tryAcquire(900);
      expect(lim.remainingBytes, 124);

      lim.reset();
      expect(lim.remainingBytes, 1024);

      // After reset, partial-window refills count from "now",
      // not the original construction time.
      lim.tryAcquire(1024);
      expect(lim.remainingBytes, 0);
      clock.advance(const Duration(seconds: 30));
      final r = lim.remainingBytes;
      expect(r, inInclusiveRange(511, 513));
    });
  });

  group('MeshCoreSendRateLimiter — custom config', () {
    test('honours injected capacity / window', () {
      final clock = _FakeClock(DateTime(2026, 5, 7, 12));
      final lim = MeshCoreSendRateLimiter(
        clock: clock.call,
        capacityBytes: 256,
        windowSeconds: 10,
      );
      expect(lim.capacity, 256);
      expect(lim.windowMs, 10000);
      expect(lim.remainingBytes, 256);

      lim.tryAcquire(256);
      clock.advance(const Duration(seconds: 5));
      // Half-window of 256 = ~128.
      expect(lim.remainingBytes, inInclusiveRange(127, 129));
    });
  });
}
