// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_explorer/models/nearby_activity.dart';

void main() {
  group('NearbyActivity', () {
    final now = DateTime.now();
    final activity = NearbyActivity(
      id: '42:3',
      type: NearbyActivityType.serviceAppeared,
      serviceId: 3,
      nodeId: 42,
      title: 'Bulletin Board', // lint-allow: hardcoded-string
      subtitle: 'New board nearby', // lint-allow: hardcoded-string
      icon: Icons.dashboard_outlined,
      occurredAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
    );

    test('equality is based on id', () {
      final same = NearbyActivity(
        id: '42:3',
        type: NearbyActivityType.serviceUpdated,
        serviceId: 99,
        nodeId: 99,
        title: 'Different', // lint-allow: hardcoded-string
        subtitle: 'Different', // lint-allow: hardcoded-string
        icon: Icons.abc,
        occurredAt: now,
        expiresAt: now,
      );
      expect(activity, equals(same));
      expect(activity.hashCode, same.hashCode);
    });

    test('different id means not equal', () {
      final other = NearbyActivity(
        id: '99:3',
        type: NearbyActivityType.serviceAppeared,
        serviceId: 3,
        nodeId: 99,
        title: 'Board', // lint-allow: hardcoded-string
        subtitle: 'New', // lint-allow: hardcoded-string
        icon: Icons.dashboard_outlined,
        occurredAt: now,
        expiresAt: now.add(const Duration(minutes: 10)),
      );
      expect(activity, isNot(equals(other)));
    });

    test('isExpired returns false when not expired', () {
      expect(activity.isExpired, isFalse);
    });

    test('isExpired returns true when past expiresAt', () {
      final expired = NearbyActivity(
        id: '42:3',
        type: NearbyActivityType.serviceAppeared,
        serviceId: 3,
        nodeId: 42,
        title: 'Board', // lint-allow: hardcoded-string
        subtitle: 'New', // lint-allow: hardcoded-string
        icon: Icons.dashboard_outlined,
        occurredAt: now.subtract(const Duration(hours: 1)),
        expiresAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(expired.isExpired, isTrue);
    });
  });

  group('NearbyActivityType', () {
    test('has expected values', () {
      expect(NearbyActivityType.values.length, 3);
      expect(
        NearbyActivityType.values,
        contains(NearbyActivityType.serviceAppeared),
      );
      expect(
        NearbyActivityType.values,
        contains(NearbyActivityType.serviceUpdated),
      );
      expect(
        NearbyActivityType.values,
        contains(NearbyActivityType.serviceExpired),
      );
    });
  });
}
