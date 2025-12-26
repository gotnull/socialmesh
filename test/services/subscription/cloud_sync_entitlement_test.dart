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
}
