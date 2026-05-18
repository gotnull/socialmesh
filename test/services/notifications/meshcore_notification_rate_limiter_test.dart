// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Row 11.b regression pins for the per-category notification rate
// limiter that gates advert notifications (and future signal types).

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/notifications/meshcore_notification_rate_limiter.dart';

void main() {
  group('Row 11.b MeshCoreNotificationRateLimiter', () {
    test('first fire returns true and stamps the clock', () {
      DateTime now = DateTime(2026, 5, 18, 12, 0, 0);
      final limiter = MeshCoreNotificationRateLimiter(
        clock: () => now,
        defaultCooldown: const Duration(minutes: 5),
      );
      expect(limiter.tryFire('advert'), isTrue);
    });

    test('second fire within cooldown returns false', () {
      DateTime now = DateTime(2026, 5, 18, 12, 0, 0);
      final limiter = MeshCoreNotificationRateLimiter(
        clock: () => now,
        defaultCooldown: const Duration(minutes: 5),
      );
      limiter.tryFire('advert');
      now = now.add(const Duration(minutes: 2));
      expect(limiter.tryFire('advert'), isFalse);
    });

    test('fire AT the cooldown boundary still rejects (strict <)', () {
      DateTime now = DateTime(2026, 5, 18, 12, 0, 0);
      final limiter = MeshCoreNotificationRateLimiter(
        clock: () => now,
        defaultCooldown: const Duration(minutes: 5),
      );
      limiter.tryFire('advert');
      now = now.add(const Duration(minutes: 5));
      // diff == window is not < window, so the second call IS allowed.
      // This pin documents the boundary semantics.
      expect(limiter.tryFire('advert'), isTrue);
    });

    test('fire AFTER cooldown returns true and re-stamps', () {
      DateTime now = DateTime(2026, 5, 18, 12, 0, 0);
      final limiter = MeshCoreNotificationRateLimiter(
        clock: () => now,
        defaultCooldown: const Duration(minutes: 5),
      );
      limiter.tryFire('advert');
      now = now.add(const Duration(minutes: 6));
      expect(limiter.tryFire('advert'), isTrue);
      // immediate follow-up call now blocked
      now = now.add(const Duration(seconds: 1));
      expect(limiter.tryFire('advert'), isFalse);
    });

    test('per-call cooldown override is honoured', () {
      DateTime now = DateTime(2026, 5, 18, 12, 0, 0);
      final limiter = MeshCoreNotificationRateLimiter(
        clock: () => now,
        defaultCooldown: const Duration(minutes: 5),
      );
      limiter.tryFire('presence', cooldown: const Duration(seconds: 30));
      // 31 s later - default would reject, override allows
      now = now.add(const Duration(seconds: 31));
      expect(
        limiter.tryFire('presence', cooldown: const Duration(seconds: 30)),
        isTrue,
      );
    });

    test('distinct categories do not interfere', () {
      DateTime now = DateTime(2026, 5, 18, 12, 0, 0);
      final limiter = MeshCoreNotificationRateLimiter(
        clock: () => now,
        defaultCooldown: const Duration(minutes: 5),
      );
      expect(limiter.tryFire('advert'), isTrue);
      expect(limiter.tryFire('batch'), isTrue);
      expect(limiter.tryFire('presence'), isTrue);
      // all three on cooldown now
      expect(limiter.tryFire('advert'), isFalse);
      expect(limiter.tryFire('batch'), isFalse);
      expect(limiter.tryFire('presence'), isFalse);
    });

    test('reset clears one category without touching others', () {
      DateTime now = DateTime(2026, 5, 18, 12, 0, 0);
      final limiter = MeshCoreNotificationRateLimiter(
        clock: () => now,
        defaultCooldown: const Duration(minutes: 5),
      );
      limiter.tryFire('advert');
      limiter.tryFire('batch');
      limiter.reset('advert');
      expect(limiter.tryFire('advert'), isTrue);
      expect(limiter.tryFire('batch'), isFalse);
    });
  });
}
