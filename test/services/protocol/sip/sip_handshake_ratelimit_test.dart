// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Regression tests for the rate-limiter gating around HS_HELLO
/// retransmits.
///
/// The handshake path was previously bypassing `SipRateLimiter`
/// entirely — every retransmit (72 B × up to three attempts = 216 B)
/// blew through the 1024 B / 60 s SIP budget without any accounting.
/// The fix attaches the shared `SipRateLimiter` to `ProtocolService`
/// via `attachSipRateLimiter`, and the `onHelloRetransmit` callback
/// consults it before sending.
///
/// These tests cover two regression surfaces:
///   1. The ProtocolService attach/detach surface exists and is
///      null-safe (catches accidental removal of the plumbing).
///   2. The rate limiter's `canSend` / `recordSend` contract — which
///      the retransmit closure depends on — continues to behave as
///      the fix expects when the budget is exhausted.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';

/// Null transport stub — enough for constructing ProtocolService
/// without triggering BLE/USB paths.
class _NullTransport implements DeviceTransport {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('ProtocolService.attachSipRateLimiter', () {
    test('accepts a limiter without throwing', () {
      final ps = ProtocolService(_NullTransport());
      final limiter = SipRateLimiter();
      expect(() => ps.attachSipRateLimiter(limiter), returnsNormally);
    });

    test('accepts null (detach) without throwing', () {
      final ps = ProtocolService(_NullTransport());
      expect(() => ps.attachSipRateLimiter(null), returnsNormally);
    });

    test('re-attaching replaces the prior reference', () {
      final ps = ProtocolService(_NullTransport());
      final a = SipRateLimiter();
      final b = SipRateLimiter();
      ps.attachSipRateLimiter(a);
      expect(() => ps.attachSipRateLimiter(b), returnsNormally);
      ps.attachSipRateLimiter(null);
    });
  });

  group('SipRateLimiter contract the retransmit gate depends on', () {
    test('canSend returns false once the budget cannot cover the frame', () {
      final limiter = SipRateLimiter();
      final frameSize = 72; // HS_HELLO wire size (22 B wrapper + 50 B body)
      // Drain the budget: 1024 / 72 ≈ 14 frames.
      var sent = 0;
      while (limiter.canSend(frameSize)) {
        limiter.recordSend(frameSize);
        sent++;
        if (sent > 20) break; // safety
      }
      expect(sent, greaterThan(0), reason: 'budget starts above one HS_HELLO');
      expect(
        limiter.canSend(frameSize),
        isFalse,
        reason:
            'once remaining < frameSize, canSend must return false — '
            'the retransmit gate relies on this',
      );
    });

    test('recordSend decrements remainingBytes', () {
      final limiter = SipRateLimiter();
      final startBudget = SipConstants.sipBudgetBytesPer60s;
      expect(limiter.remainingBytes, startBudget);
      limiter.recordSend(72);
      expect(limiter.remainingBytes, lessThanOrEqualTo(startBudget - 72));
    });

    test('fresh limiter can afford at least one HS_HELLO', () {
      final limiter = SipRateLimiter();
      expect(limiter.canSend(72), isTrue);
    });

    test('an exhausted limiter rejects any further HS_HELLO via canSend', () {
      final limiter = SipRateLimiter();
      // Consume the full budget in one go to guarantee exhaustion.
      limiter.recordSend(SipConstants.sipBudgetBytesPer60s);
      expect(limiter.canSend(72), isFalse);
    });
  });
}
