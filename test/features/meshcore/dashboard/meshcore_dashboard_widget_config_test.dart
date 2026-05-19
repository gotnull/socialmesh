// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/dashboard/models/meshcore_dashboard_widget_config.dart';

void main() {
  group('MeshCoreDashboardWidgetConfig', () {
    test('toJson / fromJson round-trips every field', () {
      const config = MeshCoreDashboardWidgetConfig(
        id: 'test_1',
        type: MeshCoreDashboardWidgetType.nearbyContacts,
        size: MeshCoreWidgetSize.large,
        order: 7,
        isFavorite: true,
        isVisible: false,
      );

      final json = config.toJson();
      final restored = MeshCoreDashboardWidgetConfig.fromJson(json);

      expect(restored.id, config.id);
      expect(restored.type, config.type);
      expect(restored.size, config.size);
      expect(restored.order, config.order);
      expect(restored.isFavorite, config.isFavorite);
      expect(restored.isVisible, config.isVisible);
    });

    test('fromJson falls back to defaults on unknown enum values', () {
      final restored = MeshCoreDashboardWidgetConfig.fromJson({
        'id': 'legacy',
        'type': 'unknownTypeFromOlderBuild',
        'size': 'gigantic',
        'order': 1,
        'isFavorite': false,
        'isVisible': true,
      });

      expect(restored.type, MeshCoreDashboardWidgetType.networkOverview);
      expect(restored.size, MeshCoreWidgetSize.medium);
    });

    test('copyWith mutates only the specified fields', () {
      const original = MeshCoreDashboardWidgetConfig(
        id: 'a',
        type: MeshCoreDashboardWidgetType.networkOverview,
      );

      final mutated = original.copyWith(
        isFavorite: true,
        size: MeshCoreWidgetSize.small,
      );

      expect(mutated.id, 'a');
      expect(mutated.type, MeshCoreDashboardWidgetType.networkOverview);
      expect(mutated.isFavorite, true);
      expect(mutated.size, MeshCoreWidgetSize.small);
      expect(original.isFavorite, false);
    });
  });

  group('MeshCoreWidgetRegistry', () {
    test('every widget type has a registry entry', () {
      for (final type in MeshCoreDashboardWidgetType.values) {
        final info = MeshCoreWidgetRegistry.getInfo(type);
        expect(info.type, type);
        expect(info.name, isNotEmpty);
        expect(info.description, isNotEmpty);
      }
    });
  });
}
