// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_explorer/models/nearby_activity.dart';
import 'package:socialmesh/providers/mrrp_providers.dart';
import 'package:socialmesh/providers/nearby_activity_provider.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_messages_advert.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

/// Helper to create a [MrrpCachedService] with minimal boilerplate.
MrrpCachedService _cachedService({
  required int nodeId,
  required int serviceId,
  int serviceFlags = MrrpServiceFlags.userVisible,
}) {
  return MrrpCachedService(
    nodeId: nodeId,
    descriptor: MrrpAdvertDescriptor(
      serviceId: serviceId,
      serviceType: MrrpServiceType.app,
      versionMajor: 1,
      versionMinor: 0,
      serviceFlags: serviceFlags,
      metadata: Uint8List(0),
    ),
    cachedAt: DateTime.now(),
  );
}

void main() {
  group('NearbyActivityNotifier', () {
    late ProviderContainer container;

    /// Current snapshot, mutable from tests.
    var snapshot = <int, List<MrrpCachedService>>{};

    setUp(() {
      snapshot = {};
      container = ProviderContainer(
        overrides: [mrrpCachedServicesProvider.overrideWithValue(snapshot)],
      );
      // Force first build so first-build suppression runs on the empty set.
      container.read(nearbyActivityProvider);
    });

    tearDown(() => container.dispose());

    test('first build produces empty activity (suppression)', () {
      snapshot = {
        42: [_cachedService(nodeId: 42, serviceId: MrrpServiceId.boardV1)],
      };
      // Create a fresh container that starts with services already present.
      final freshContainer = ProviderContainer(
        overrides: [mrrpCachedServicesProvider.overrideWithValue(snapshot)],
      );
      addTearDown(freshContainer.dispose);

      final result = freshContainer.read(nearbyActivityProvider);
      expect(result, isEmpty, reason: 'First build should suppress activity');
    });

    test('new board advert produces activity', () {
      snapshot = {
        42: [_cachedService(nodeId: 42, serviceId: MrrpServiceId.boardV1)],
      };
      container.updateOverrides([
        mrrpCachedServicesProvider.overrideWithValue(snapshot),
      ]);
      container.invalidate(nearbyActivityProvider);
      final result = container.read(nearbyActivityProvider);

      expect(result, hasLength(1));
      expect(result.first.serviceId, MrrpServiceId.boardV1);
      expect(result.first.nodeId, 42);
      expect(result.first.type, NearbyActivityType.serviceAppeared);
      expect(
        result.first.subtitle,
        'New board nearby', // lint-allow: hardcoded-string
      );
    });

    test('signal advert produces activity', () {
      const signalV1 = 0x00000004;
      snapshot = {
        100: [_cachedService(nodeId: 100, serviceId: signalV1)],
      };
      container.updateOverrides([
        mrrpCachedServicesProvider.overrideWithValue(snapshot),
      ]);
      container.invalidate(nearbyActivityProvider);
      final result = container.read(nearbyActivityProvider);

      expect(result, hasLength(1));
      expect(result.first.serviceId, signalV1);
      expect(
        result.first.subtitle,
        'Signal published', // lint-allow: hardcoded-string
      );
    });

    test('duplicate adverts do not duplicate activity', () {
      snapshot = {
        42: [_cachedService(nodeId: 42, serviceId: MrrpServiceId.boardV1)],
      };
      container.updateOverrides([
        mrrpCachedServicesProvider.overrideWithValue(snapshot),
      ]);
      container.invalidate(nearbyActivityProvider);
      expect(container.read(nearbyActivityProvider), hasLength(1));

      // Rebuild again with same snapshot — no new activity should appear.
      container.invalidate(nearbyActivityProvider);
      final result = container.read(nearbyActivityProvider);
      expect(result, hasLength(1), reason: 'No duplicate activity expected');
    });

    test('test-only services are excluded', () {
      snapshot = {
        42: [
          _cachedService(
            nodeId: 42,
            serviceId: MrrpServiceId.echoTest,
            serviceFlags: MrrpServiceFlags.testOnly,
          ),
        ],
      };
      container.updateOverrides([
        mrrpCachedServicesProvider.overrideWithValue(snapshot),
      ]);
      container.invalidate(nearbyActivityProvider);
      final result = container.read(nearbyActivityProvider);

      expect(result, isEmpty, reason: 'Test-only services should be excluded');
    });

    test('unknown service degrades gracefully', () {
      const unknownId = 0x00009999;
      snapshot = {
        42: [_cachedService(nodeId: 42, serviceId: unknownId)],
      };
      container.updateOverrides([
        mrrpCachedServicesProvider.overrideWithValue(snapshot),
      ]);
      container.invalidate(nearbyActivityProvider);
      final result = container.read(nearbyActivityProvider);

      expect(result, hasLength(1));
      expect(
        result.first.subtitle,
        'New service nearby', // lint-allow: hardcoded-string
      );
      expect(result.first.title, isNotEmpty);
    });

    test('buffer caps at kNearbyActivityMaxItems', () {
      final services = <MrrpCachedService>[];
      for (var i = 0; i < kNearbyActivityMaxItems + 5; i++) {
        services.add(_cachedService(nodeId: 42, serviceId: 0x00010000 + i));
      }
      snapshot = {42: services};
      container.updateOverrides([
        mrrpCachedServicesProvider.overrideWithValue(snapshot),
      ]);
      container.invalidate(nearbyActivityProvider);
      final result = container.read(nearbyActivityProvider);

      expect(
        result.length,
        kNearbyActivityMaxItems,
        reason: 'Buffer should cap at $kNearbyActivityMaxItems',
      );
    });

    test('clearAll empties the feed', () {
      snapshot = {
        42: [_cachedService(nodeId: 42, serviceId: MrrpServiceId.boardV1)],
      };
      container.updateOverrides([
        mrrpCachedServicesProvider.overrideWithValue(snapshot),
      ]);
      container.invalidate(nearbyActivityProvider);
      expect(container.read(nearbyActivityProvider), hasLength(1));

      container.read(nearbyActivityProvider.notifier).clearAll();
      expect(container.read(nearbyActivityProvider), isEmpty);
    });

    test(
      'multiple services from different peers produce separate activities',
      () {
        snapshot = {
          42: [_cachedService(nodeId: 42, serviceId: MrrpServiceId.boardV1)],
          99: [_cachedService(nodeId: 99, serviceId: MrrpServiceId.profileV1)],
        };
        container.updateOverrides([
          mrrpCachedServicesProvider.overrideWithValue(snapshot),
        ]);
        container.invalidate(nearbyActivityProvider);
        final result = container.read(nearbyActivityProvider);

        expect(result, hasLength(2));
        final ids = result.map((a) => a.id).toSet();
        expect(ids, contains('42:3'));
        expect(ids, contains('99:2'));
      },
    );

    test('same service on different peers produces separate activities', () {
      snapshot = {
        42: [_cachedService(nodeId: 42, serviceId: MrrpServiceId.boardV1)],
        99: [_cachedService(nodeId: 99, serviceId: MrrpServiceId.boardV1)],
      };
      container.updateOverrides([
        mrrpCachedServicesProvider.overrideWithValue(snapshot),
      ]);
      container.invalidate(nearbyActivityProvider);
      final result = container.read(nearbyActivityProvider);

      expect(result, hasLength(2));
      expect(result.map((a) => a.nodeId).toSet(), {42, 99});
    });
  });
}
