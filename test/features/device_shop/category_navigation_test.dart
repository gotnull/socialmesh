import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/device_shop/models/shop_models.dart';

void main() {
  group('Category Navigation', () {
    test('all categories have labels', () {
      for (final category in DeviceCategory.values) {
        expect(category.label, isNotEmpty);
        expect(category.description, isNotEmpty);
      }
    });

    test('category labels are properly formatted', () {
      expect(DeviceCategory.node.label, 'Nodes');
      expect(DeviceCategory.module.label, 'Modules');
      expect(DeviceCategory.antenna.label, 'Antennas');
      expect(DeviceCategory.enclosure.label, 'Enclosures');
      expect(DeviceCategory.accessory.label, 'Accessories');
      expect(DeviceCategory.kit.label, 'Kits');
      expect(DeviceCategory.solar.label, 'Solar');
    });

    test('categories have descriptions', () {
      expect(DeviceCategory.node.description, 'Complete Meshtastic devices');
      expect(DeviceCategory.module.description, 'Add-on modules and boards');
      expect(DeviceCategory.antenna.description, 'Antennas and RF accessories');
      expect(DeviceCategory.enclosure.description, 'Cases and enclosures');
      expect(
        DeviceCategory.accessory.description,
        'Cables, batteries, and more',
      );
      expect(DeviceCategory.kit.description, 'DIY kits and bundles');
      expect(
        DeviceCategory.solar.description,
        'Solar panels and power solutions',
      );
    });

    test('fromString converts correctly', () {
      expect(DeviceCategory.fromString('node'), DeviceCategory.node);
      expect(DeviceCategory.fromString('module'), DeviceCategory.module);
      expect(DeviceCategory.fromString('antenna'), DeviceCategory.antenna);
      expect(DeviceCategory.fromString('enclosure'), DeviceCategory.enclosure);
      expect(DeviceCategory.fromString('accessory'), DeviceCategory.accessory);
      expect(DeviceCategory.fromString('kit'), DeviceCategory.kit);
      expect(DeviceCategory.fromString('solar'), DeviceCategory.solar);
    });

    test('fromString handles invalid input', () {
      // Should default to node for invalid input
      expect(DeviceCategory.fromString('invalid'), DeviceCategory.node);
      expect(DeviceCategory.fromString(''), DeviceCategory.node);
    });

    test('category enum name matches string value', () {
      for (final category in DeviceCategory.values) {
        expect(DeviceCategory.fromString(category.name), category);
      }
    });

    test('all categories are unique', () {
      final labels = DeviceCategory.values.map((c) => c.label).toSet();
      expect(labels.length, DeviceCategory.values.length);

      final names = DeviceCategory.values.map((c) => c.name).toSet();
      expect(names.length, DeviceCategory.values.length);
    });
  });
}
