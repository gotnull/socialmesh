// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// [PeerRateLimiter] tests — per-kind defaults, burst behaviour,
/// per-peer isolation, refill, idle eviction, never-bypass-global
/// (covered by absence of any global state in the limiter).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/peer_rate_limiter.dart';

void main() {
  group('PeerRateLimiter — defaults', () {
    test('text: burst of 6 then a rate-limit hit', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      for (var i = 0; i < 6; i++) {
        expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      }
      // 7th immediate acquire is denied — burst is 6, refill not in.
      expect(
        limiter.tryAcquire(peer, PeerRateKind.text),
        isFalse,
        reason: 'text burst=6; 7th send within the same instant must fail',
      );
    });

    test('sketch: burst of 2', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      expect(limiter.tryAcquire(peer, PeerRateKind.sketch), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.sketch), isTrue);
      expect(
        limiter.tryAcquire(peer, PeerRateKind.sketch),
        isFalse,
        reason:
            'sketch burst is 2 — kept tight (vs. text=6) because ink '
            'frames are much larger on the wire',
      );
    });

    test('reaction: burst of 6', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      for (var i = 0; i < 6; i++) {
        expect(limiter.tryAcquire(peer, PeerRateKind.reaction), isTrue);
      }
      expect(limiter.tryAcquire(peer, PeerRateKind.reaction), isFalse);
    });
  });

  group('PeerRateLimiter — refill', () {
    test('text refills proportionally over the window', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0x55;

      // Drain the burst.
      for (var i = 0; i < 6; i++) {
        expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      }
      expect(limiter.canSend(peer, PeerRateKind.text), isFalse);

      // 12 tokens per 60s = 0.2 token / s. Advance 5s → +1 token.
      nowMs += 5 * 1000;
      expect(limiter.canSend(peer, PeerRateKind.text), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      expect(limiter.canSend(peer, PeerRateKind.text), isFalse);
    });

    test('sketch refills slower (3 per 60s = 20s per token)', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0x55;

      // Drain the burst (2).
      expect(limiter.tryAcquire(peer, PeerRateKind.sketch), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.sketch), isTrue);
      expect(limiter.canSend(peer, PeerRateKind.sketch), isFalse);

      nowMs += 10 * 1000; // half a refill — still under 1 full token
      expect(limiter.canSend(peer, PeerRateKind.sketch), isFalse);

      nowMs += 11 * 1000; // total +21s → 1 full token replenished
      expect(limiter.canSend(peer, PeerRateKind.sketch), isTrue);
    });

    test('refill never exceeds capacity', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0x55;

      // Idle for hours; capacity is still capped at burst (6 for text).
      nowMs += 60 * 60 * 1000;
      // Idle eviction window is 5 minutes — after an hour of inactivity
      // the bucket is gone, so we get a fresh one at full capacity (6).
      expect(limiter.tokensFor(peer, PeerRateKind.text), equals(6.0));
    });
  });

  group('PeerRateLimiter — peer isolation', () {
    test('peers do not share buckets', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peerA = 0xAAAA;
      const peerB = 0xBBBB;

      // Drain peer A's text burst.
      for (var i = 0; i < 6; i++) {
        expect(limiter.tryAcquire(peerA, PeerRateKind.text), isTrue);
      }
      expect(limiter.canSend(peerA, PeerRateKind.text), isFalse);
      // Peer B's bucket is fresh.
      expect(limiter.canSend(peerB, PeerRateKind.text), isTrue);
      expect(limiter.tryAcquire(peerB, PeerRateKind.text), isTrue);
    });

    test('text and sketch buckets are independent for the same peer', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0x12;

      for (var i = 0; i < 6; i++) {
        expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      }
      // Text is exhausted but sketch is still fresh (burst 2).
      expect(limiter.canSend(peer, PeerRateKind.text), isFalse);
      expect(limiter.canSend(peer, PeerRateKind.sketch), isTrue);
    });
  });

  group('PeerRateLimiter — eviction + reset', () {
    test('idle bucket is evicted after idleEvictionMs', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(
        policy: const PeerRatePolicy(idleEvictionMs: 1000),
        clock: () => nowMs,
      );
      const peer = 0x99;

      expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      expect(limiter.bucketCount, equals(1));
      nowMs += 5 * 1000;
      // Touch any bucket — eviction sweeps run inline.
      limiter.canSend(peer, PeerRateKind.sketch);
      expect(
        limiter.bucketCount,
        equals(1),
        reason:
            'sketch bucket was just allocated; old text bucket should be gone',
      );
    });

    test('resetPeer drops all of one peer\'s buckets', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xC0FFEE;

      limiter.tryAcquire(peer, PeerRateKind.text);
      limiter.tryAcquire(peer, PeerRateKind.sketch);
      limiter.tryAcquire(peer, PeerRateKind.reaction);
      expect(limiter.bucketCount, equals(3));
      limiter.resetPeer(peer);
      expect(limiter.bucketCount, equals(0));
    });

    test('resetAll clears every bucket', () {
      final limiter = PeerRateLimiter(clock: () => 1000);
      limiter.tryAcquire(1, PeerRateKind.text);
      limiter.tryAcquire(2, PeerRateKind.text);
      expect(limiter.bucketCount, equals(2));
      limiter.resetAll();
      expect(limiter.bucketCount, equals(0));
    });
  });

  group('PeerRateLimiter — canSend / recordSend separation', () {
    test('canSend is non-mutating; recordSend deducts', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xFEED;

      expect(limiter.canSend(peer, PeerRateKind.text), isTrue);
      expect(limiter.canSend(peer, PeerRateKind.text), isTrue);
      expect(
        limiter.tokensFor(peer, PeerRateKind.text),
        closeTo(6.0, 0.001),
        reason: 'canSend must not consume tokens',
      );
      limiter.recordSend(peer, PeerRateKind.text);
      expect(limiter.tokensFor(peer, PeerRateKind.text), closeTo(5.0, 0.001));
    });
  });
}
