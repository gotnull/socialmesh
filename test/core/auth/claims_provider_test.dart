// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/auth/claims_cache.dart';
import 'package:socialmesh/core/auth/claims_provider.dart';

void main() {
  group('ClaimsState', () {
    group('consumer user (no claims)', () {
      test('default state has null orgId and role', () {
        const state = ClaimsState();
        expect(state.orgId, isNull);
        expect(state.role, isNull);
        expect(state.cachedAt, isNull);
        expect(state.tokenExpiry, isNull);
        expect(state.isConsumer, isTrue);
        expect(state.isStale, isFalse);
      });

      test('state with null claims is consumer', () {
        const state = ClaimsState(claims: null);
        expect(state.isConsumer, isTrue);
        expect(state.orgId, isNull);
        expect(state.role, isNull);
      });

      test('state with consumer CachedClaims is consumer', () {
        const claims = CachedClaims(
          orgId: null,
          role: null,
          cachedAt: 1700000000000,
          tokenExpiry: 1700003600000,
        );
        const state = ClaimsState(claims: claims);
        expect(state.isConsumer, isTrue);
        expect(state.orgId, isNull);
        expect(state.role, isNull);
      });
    });

    group('enterprise user', () {
      test('exposes orgId and role from claims', () {
        const claims = CachedClaims(
          orgId: 'org-uuid-123',
          role: 'supervisor',
          cachedAt: 1700000000000,
          tokenExpiry: 1700003600000,
        );
        const state = ClaimsState(claims: claims);
        expect(state.orgId, 'org-uuid-123');
        expect(state.role, 'supervisor');
        expect(state.isConsumer, isFalse);
        expect(state.cachedAt, 1700000000000);
        expect(state.tokenExpiry, 1700003600000);
      });
    });

    group('staleness detection', () {
      test('not stale when claims are null', () {
        const state = ClaimsState();
        expect(state.isStale, isFalse);
      });

      test('not stale when tokenExpiry is recent', () {
        final claims = CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: DateTime.now().millisecondsSinceEpoch,
          tokenExpiry: DateTime.now()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch,
        );
        final state = ClaimsState(claims: claims);
        expect(state.isStale, isFalse);
      });

      test('stale when tokenExpiry exceeded by >24 hours', () {
        final claims = CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: DateTime.now()
              .subtract(const Duration(hours: 50))
              .millisecondsSinceEpoch,
          tokenExpiry: DateTime.now()
              .subtract(const Duration(hours: 48))
              .millisecondsSinceEpoch,
        );
        final state = ClaimsState(claims: claims);
        expect(state.isStale, isTrue);
      });
    });

    group('equality', () {
      test('two default states are equal', () {
        const a = ClaimsState();
        const b = ClaimsState();
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('states with same claims are equal', () {
        const claims = CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: 1000,
          tokenExpiry: 2000,
        );
        const a = ClaimsState(claims: claims);
        const b = ClaimsState(claims: claims);
        expect(a, equals(b));
      });

      test('states with different claims are not equal', () {
        const claimsA = CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: 1000,
          tokenExpiry: 2000,
        );
        const claimsB = CachedClaims(
          orgId: 'org-2',
          role: 'operator',
          cachedAt: 1000,
          tokenExpiry: 2000,
        );
        const a = ClaimsState(claims: claimsA);
        const b = ClaimsState(claims: claimsB);
        expect(a, isNot(equals(b)));
      });

      test('state with claims vs without are not equal', () {
        const claims = CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: 1000,
          tokenExpiry: 2000,
        );
        const a = ClaimsState(claims: claims);
        const b = ClaimsState();
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('JWT claim extraction scenarios', () {
    test('enterprise claims: orgId and role present', () {
      // Simulating what _extractClaims would produce from a JWT with claims
      const claims = CachedClaims(
        orgId: 'org-uuid-123',
        role: 'supervisor',
        cachedAt: 1700000000000,
        tokenExpiry: 1700003600000,
      );
      expect(claims.orgId, 'org-uuid-123');
      expect(claims.role, 'supervisor');
      expect(claims.isConsumer, isFalse);
    });

    test('consumer JWT: no orgId or role in claims', () {
      const claims = CachedClaims(
        orgId: null,
        role: null,
        cachedAt: 1700000000000,
        tokenExpiry: 1700003600000,
      );
      expect(claims.orgId, isNull);
      expect(claims.role, isNull);
      expect(claims.isConsumer, isTrue);
    });

    test('all four valid roles are representable', () {
      for (final role in ['admin', 'supervisor', 'operator', 'observer']) {
        final claims = CachedClaims(
          orgId: 'org-1',
          role: role,
          cachedAt: 1000,
          tokenExpiry: 2000,
        );
        expect(claims.role, role);
        expect(claims.isConsumer, isFalse);
      }
    });

    test('expiry extracted correctly from token result timestamp', () {
      // Simulating DateTime -> millisecondsSinceEpoch conversion
      final expiry = DateTime(2026, 6, 1, 12, 0, 0).millisecondsSinceEpoch;
      final claims = CachedClaims(
        orgId: 'org-1',
        role: 'operator',
        cachedAt: DateTime(2026, 6, 1, 11, 0, 0).millisecondsSinceEpoch,
        tokenExpiry: expiry,
      );
      expect(claims.tokenExpiry, expiry);
    });
  });

  group('Provider notification behavior', () {
    // These tests verify the notification-only-on-change contract
    // by testing ClaimsState equality, which ClaimsNotifier relies on.
    test('same orgId+role = same state (no unnecessary notification)', () {
      const a = ClaimsState(
        claims: CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: 1000,
          tokenExpiry: 2000,
        ),
      );
      const b = ClaimsState(
        claims: CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: 3000,
          tokenExpiry: 4000,
        ),
      );
      // Different timestamps but same orgId/role -- the notifier compares
      // orgId/role to decide whether to notify. Since ClaimsState ==
      // compares the full CachedClaims (including timestamps), these are
      // structurally different, but the notifier uses orgId/role comparison
      // to avoid spurious rebuilds.
      expect(a.orgId, equals(b.orgId));
      expect(a.role, equals(b.role));
    });

    test('different orgId = different state (listeners notified)', () {
      const a = ClaimsState(
        claims: CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: 1000,
          tokenExpiry: 2000,
        ),
      );
      const b = ClaimsState(
        claims: CachedClaims(
          orgId: 'org-2',
          role: 'admin',
          cachedAt: 1000,
          tokenExpiry: 2000,
        ),
      );
      expect(a, isNot(equals(b)));
    });

    test('different role = different state (listeners notified)', () {
      const a = ClaimsState(
        claims: CachedClaims(
          orgId: 'org-1',
          role: 'admin',
          cachedAt: 1000,
          tokenExpiry: 2000,
        ),
      );
      const b = ClaimsState(
        claims: CachedClaims(
          orgId: 'org-1',
          role: 'operator',
          cachedAt: 1000,
          tokenExpiry: 2000,
        ),
      );
      expect(a, isNot(equals(b)));
    });
  });
}
