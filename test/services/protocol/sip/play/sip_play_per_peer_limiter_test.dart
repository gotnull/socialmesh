// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the per-peer rate-limiter behaviour for the new
/// [PeerRateKind.play] bucket added in SIP Play v1.
///
/// Bucket policy (per `PeerRatePolicy.defaultPolicy`):
///   - 6 sustained sends per 60s window,
///   - burst capacity 3,
///   - separate from text/sketch/reaction so a flurry of moves
///     can't starve text DM and vice versa.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/peer_rate_limiter.dart';

void main() {
  group('PeerRateLimiter — PeerRateKind.play', () {
    test('starts with burst capacity 3, then refuses', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      expect(limiter.tryAcquire(peer, PeerRateKind.play), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.play), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.play), isTrue);
      expect(
        limiter.tryAcquire(peer, PeerRateKind.play),
        isFalse,
        reason: 'Burst is 3 — fourth attempt must fail',
      );
    });

    test('play bucket is independent from text bucket', () {
      var nowMs = 1700000000000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      // Burn all play tokens.
      for (var i = 0; i < 3; i += 1) {
        expect(limiter.tryAcquire(peer, PeerRateKind.play), isTrue);
      }
      expect(limiter.tryAcquire(peer, PeerRateKind.play), isFalse);

      // Text bucket is untouched — still has its own burst.
      expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.text), isTrue);
    });

    test('play refills at 6 tokens per 60s window (10s per token)', () {
      var nowMs = 1000;
      final limiter = PeerRateLimiter(clock: () => nowMs);
      const peer = 0xAA;

      for (var i = 0; i < 3; i += 1) {
        expect(limiter.tryAcquire(peer, PeerRateKind.play), isTrue);
      }
      expect(limiter.canSend(peer, PeerRateKind.play), isFalse);

      // Advance 10s → +1 token.
      nowMs += 10 * 1000;
      expect(limiter.canSend(peer, PeerRateKind.play), isTrue);
      expect(limiter.tryAcquire(peer, PeerRateKind.play), isTrue);
      expect(limiter.canSend(peer, PeerRateKind.play), isFalse);
    });
  });
}
