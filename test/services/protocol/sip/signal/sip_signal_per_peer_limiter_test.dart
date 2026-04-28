// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for the per-peer rate-limiter `signal` bucket added in
/// SIP Signal v1.
///
/// Policy (per `PeerRatePolicy.defaultPolicy`):
///   - 4 sustained signal sends per 60 s
///   - burst capacity 2
///   - independent from text / sketch / reaction / play buckets
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/peer_rate_limiter.dart';

void main() {
  group('PeerRateLimiter — PeerRateKind.signal', () {
    test('starts with burst capacity 2, refuses third', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      expect(
        limiter.tryAcquire(peer, PeerRateKind.signal),
        isFalse,
        reason: 'burst is 2 — third attempt must fail',
      );
    });

    test('signal bucket independent from text + play buckets', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      for (var i = 0; i < 2; i += 1) {
        expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      }
      expect(limiter.tryAcquire(peer, PeerRateKind.signal), isFalse);

      // Other buckets unaffected.
      expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.play), isTrue);
    });

    test('refills at 4 tokens per 60s window (15 s per token)', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      for (var i = 0; i < 2; i += 1) {
        expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      }
      expect(limiter.canSend(peer, PeerRateKind.signal), isFalse);

      nowMs += 15 * 1000;
      expect(limiter.canSend(peer, PeerRateKind.signal), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.signal), isTrue);
      expect(limiter.canSend(peer, PeerRateKind.signal), isFalse);
    });
  });
}
