// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for the per-peer rate-limiter `signal` bucket. Values reflect
/// the real-conversation-pacing relaxation in commit 7ef7b2d0.
///
/// Policy (per `PeerRatePolicy.defaultPolicy`):
///   - 6 sustained signal sends per 60 s (1 token / 10 s)
///   - burst capacity 3
///   - independent from text / sketch / reaction / play buckets
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/peer_rate_limiter.dart';

void main() {
  group('PeerRateLimiter — PeerRateKind.signal', () {
    test('starts with burst capacity 3, refuses fourth', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      for (var i = 0; i < 3; i += 1) {
        expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      }
      expect(
        limiter.tryAcquire(peer, PeerRateKind.signal),
        isFalse,
        reason: 'burst is 3 — fourth attempt must fail',
      );
    });

    test('signal bucket independent from text + play buckets', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      for (var i = 0; i < 3; i += 1) {
        expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      }
      expect(limiter.tryAcquire(peer, PeerRateKind.signal), isFalse);

      // Other buckets unaffected.
      expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.play), isTrue);
    });

    test('refills at 6 tokens per 60s window (10 s per token)', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      for (var i = 0; i < 3; i += 1) {
        expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      }
      expect(limiter.canSend(peer, PeerRateKind.signal), isFalse);

      nowMs += 10 * 1000;
      expect(limiter.canSend(peer, PeerRateKind.signal), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      expect(limiter.canSend(peer, PeerRateKind.signal), isFalse);
    });
  });
}
