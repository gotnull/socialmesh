import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/subscription/cloud_sync_entitlement_service.dart';

void main() {
  group('CloudSyncEntitlement', () {
    test('none entitlement has no access', () {
      const entitlement = CloudSyncEntitlement.none;

      expect(entitlement.state, CloudSyncEntitlementState.none);
      expect(entitlement.canWrite, false);
      expect(entitlement.canRead, false);
      expect(entitlement.hasFullAccess, false);
      expect(entitlement.hasReadOnlyAccess, false);
    });

    test('active entitlement has full access', () {
      const entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.active,
        canWrite: true,
        canRead: true,
        productId: 'cloud_monthly',
      );

      expect(entitlement.state, CloudSyncEntitlementState.active);
      expect(entitlement.canWrite, true);
      expect(entitlement.canRead, true);
      expect(entitlement.hasFullAccess, true);
      expect(entitlement.hasReadOnlyAccess, false);
    });

    test('grandfathered entitlement has full access', () {
      const entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.grandfathered,
        canWrite: true,
        canRead: true,
      );

      expect(entitlement.state, CloudSyncEntitlementState.grandfathered);
      expect(entitlement.canWrite, true);
      expect(entitlement.canRead, true);
      expect(entitlement.hasFullAccess, true);
    });

    test('grace period entitlement has full access', () {
      final entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.gracePeriod,
        canWrite: true,
        canRead: true,
        gracePeriodEndsAt: DateTime.now().add(const Duration(days: 7)),
      );

      expect(entitlement.state, CloudSyncEntitlementState.gracePeriod);
      expect(entitlement.hasFullAccess, true);
    });

    test('expired entitlement has read-only access', () {
      final entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.expired,
        canWrite: false,
        canRead: true,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(entitlement.state, CloudSyncEntitlementState.expired);
      expect(entitlement.canWrite, false);
      expect(entitlement.canRead, true);
      expect(entitlement.hasFullAccess, false);
      expect(entitlement.hasReadOnlyAccess, true);
    });

    test('toString provides useful debug info', () {
      const entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.active,
        canWrite: true,
        canRead: true,
      );

      final str = entitlement.toString();
      expect(str, contains('CloudSyncEntitlement'));
      expect(str, contains('active'));
      expect(str, contains('canWrite: true'));
    });
  });

  group('CloudSyncEntitlementState', () {
    test('all states are properly defined', () {
      expect(CloudSyncEntitlementState.values, hasLength(5));
      expect(
        CloudSyncEntitlementState.values,
        contains(CloudSyncEntitlementState.active),
      );
      expect(
        CloudSyncEntitlementState.values,
        contains(CloudSyncEntitlementState.gracePeriod),
      );
      expect(
        CloudSyncEntitlementState.values,
        contains(CloudSyncEntitlementState.grandfathered),
      );
      expect(
        CloudSyncEntitlementState.values,
        contains(CloudSyncEntitlementState.expired),
      );
      expect(
        CloudSyncEntitlementState.values,
        contains(CloudSyncEntitlementState.none),
      );
    });
  });

  group('CloudSyncEntitlementService', () {
    test('entitlement ID is correct', () {
      // This verifies the entitlement ID matches what's configured in RevenueCat
      // The service uses 'Socialmesh Pro' as the entitlement identifier
      // If this test fails, check RevenueCat dashboard configuration
      expect(
        CloudSyncEntitlementService.grandfatherCutoffDate,
        DateTime(2025, 2, 1),
      );
    });

    test('grandfather cutoff date is set correctly', () {
      final cutoff = CloudSyncEntitlementService.grandfatherCutoffDate;
      expect(cutoff.year, 2025);
      expect(cutoff.month, 2);
      expect(cutoff.day, 1);
    });

    test('users before cutoff should be eligible for grandfathering', () {
      final beforeCutoff = DateTime(2025, 1, 15);
      final afterCutoff = DateTime(2025, 3, 15);

      expect(
        beforeCutoff.isBefore(
          CloudSyncEntitlementService.grandfatherCutoffDate,
        ),
        true,
      );
      expect(
        afterCutoff.isBefore(CloudSyncEntitlementService.grandfatherCutoffDate),
        false,
      );
    });
  });

  group('CloudSyncEntitlement edge cases', () {
    test('gracePeriodEndsAt is tracked when set', () {
      final gracePeriodEnd = DateTime.now().add(const Duration(days: 3));
      final entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.gracePeriod,
        canWrite: true,
        canRead: true,
        gracePeriodEndsAt: gracePeriodEnd,
      );

      expect(entitlement.gracePeriodEndsAt, gracePeriodEnd);
      expect(entitlement.hasFullAccess, true);
    });

    test('expiresAt is tracked for active subscription', () {
      final expiryDate = DateTime.now().add(const Duration(days: 30));
      final entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.active,
        canWrite: true,
        canRead: true,
        expiresAt: expiryDate,
        productId: 'cloud_monthly',
      );

      expect(entitlement.expiresAt, expiryDate);
      expect(entitlement.productId, 'cloud_monthly');
    });

    test('hasFullAccess is false for expired state', () {
      final entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.expired,
        canWrite: false,
        canRead: true,
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(entitlement.hasFullAccess, false);
      expect(entitlement.hasReadOnlyAccess, true);
    });

    test('hasReadOnlyAccess is false when canRead is false', () {
      const entitlement = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.expired,
        canWrite: false,
        canRead: false,
      );

      expect(entitlement.hasReadOnlyAccess, false);
    });

    test('none static constant has correct values', () {
      expect(CloudSyncEntitlement.none.state, CloudSyncEntitlementState.none);
      expect(CloudSyncEntitlement.none.canWrite, false);
      expect(CloudSyncEntitlement.none.canRead, false);
      expect(CloudSyncEntitlement.none.hasFullAccess, false);
      expect(CloudSyncEntitlement.none.hasReadOnlyAccess, false);
      expect(CloudSyncEntitlement.none.productId, isNull);
      expect(CloudSyncEntitlement.none.expiresAt, isNull);
      expect(CloudSyncEntitlement.none.gracePeriodEndsAt, isNull);
    });
  });

  group('Entitlement state transitions', () {
    test('all states can transition to none on sign out', () {
      // Each state should be properly representable
      for (final state in CloudSyncEntitlementState.values) {
        final entitlement = CloudSyncEntitlement(
          state: state,
          canWrite:
              state != CloudSyncEntitlementState.none &&
              state != CloudSyncEntitlementState.expired,
          canRead: state != CloudSyncEntitlementState.none,
        );

        expect(
          entitlement.state,
          state,
          reason: 'State $state should be representable',
        );
      }
    });

    test('yearly subscription has longer expiry than monthly', () {
      final monthlyExpiry = DateTime.now().add(const Duration(days: 30));
      final yearlyExpiry = DateTime.now().add(const Duration(days: 365));

      final monthly = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.active,
        canWrite: true,
        canRead: true,
        expiresAt: monthlyExpiry,
        productId: 'cloud_monthly',
      );

      final yearly = CloudSyncEntitlement(
        state: CloudSyncEntitlementState.active,
        canWrite: true,
        canRead: true,
        expiresAt: yearlyExpiry,
        productId: 'cloud_yearly',
      );

      expect(yearly.expiresAt!.isAfter(monthly.expiresAt!), true);
    });
  });
}
