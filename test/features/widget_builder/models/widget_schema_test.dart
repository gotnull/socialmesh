import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';

void main() {
  group('WidgetSchema', () {
    test('creates with required fields', () {
      final schema = WidgetSchema(
        name: 'Test Widget',
        root: ElementSchema(type: ElementType.text, text: 'Hello'),
      );

      expect(schema.name, 'Test Widget');
      expect(schema.id, isNotEmpty);
      expect(schema.version, '1.0.0');
      expect(schema.root.type, ElementType.text);
    });

    test('generates unique IDs', () {
      final schema1 = WidgetSchema(
        name: 'Widget 1',
        root: ElementSchema(type: ElementType.text),
      );
      final schema2 = WidgetSchema(
        name: 'Widget 2',
        root: ElementSchema(type: ElementType.text),
      );

      expect(schema1.id, isNot(schema2.id));
    });

    test('serializes to JSON', () {
      final schema = WidgetSchema(
        name: 'Test Widget',
        description: 'A test widget',
        version: '1.2.0',
        tags: ['test', 'sample'],
        root: ElementSchema(
          type: ElementType.column,
          children: [ElementSchema(type: ElementType.text, text: 'Hello')],
        ),
      );

      final json = schema.toJson();

      expect(json['name'], 'Test Widget');
      expect(json['description'], 'A test widget');
      expect(json['version'], '1.2.0');
      expect(json['tags'], ['test', 'sample']);
      expect(json['root'], isNotNull);
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'test-id-123',
        'name': 'JSON Widget',
        'description': 'From JSON',
        'version': '2.0.0',
        'tags': ['json', 'test'],
        'root': {'type': 'text', 'text': 'Hello World'},
      };

      final schema = WidgetSchema.fromJson(json);

      expect(schema.id, 'test-id-123');
      expect(schema.name, 'JSON Widget');
      expect(schema.description, 'From JSON');
      expect(schema.version, '2.0.0');
      expect(schema.tags, ['json', 'test']);
      expect(schema.root.type, ElementType.text);
      expect(schema.root.text, 'Hello World');
    });

    test('round-trips through JSON', () {
      final original = WidgetSchema(
        name: 'Round Trip',
        description: 'Testing round trip',
        tags: ['test'],
        root: ElementSchema(
          type: ElementType.row,
          children: [
            ElementSchema(
              type: ElementType.icon,
              iconName: 'star',
              iconSize: 24,
            ),
            ElementSchema(
              type: ElementType.text,
              text: 'Rating',
              style: const StyleSchema(fontSize: 16, textColor: '#FFFFFF'),
            ),
          ],
        ),
      );

      final json = original.toJson();
      final restored = WidgetSchema.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.description, original.description);
      expect(restored.root.type, original.root.type);
      expect(restored.root.children.length, 2);
    });
  });

  group('ElementSchema', () {
    test('creates text element', () {
      final element = ElementSchema(
        type: ElementType.text,
        text: 'Hello',
        style: const StyleSchema(fontSize: 14),
      );

      expect(element.type, ElementType.text);
      expect(element.text, 'Hello');
      expect(element.style.fontSize, 14);
    });

    test('creates element with binding', () {
      final element = ElementSchema(
        type: ElementType.text,
        binding: const BindingSchema(
          path: 'node.batteryLevel',
          format: '{value}%',
          defaultValue: '--',
        ),
      );

      expect(element.binding, isNotNull);
      expect(element.binding!.path, 'node.batteryLevel');
      expect(element.binding!.format, '{value}%');
      expect(element.binding!.defaultValue, '--');
    });

    test('creates gauge element', () {
      final element = ElementSchema(
        type: ElementType.gauge,
        gaugeType: GaugeType.radial,
        gaugeMin: 0,
        gaugeMax: 100,
        gaugeColor: '#4ADE80',
        binding: const BindingSchema(path: 'node.batteryLevel'),
      );

      expect(element.type, ElementType.gauge);
      expect(element.gaugeType, GaugeType.radial);
      expect(element.gaugeMin, 0);
      expect(element.gaugeMax, 100);
      expect(element.gaugeColor, '#4ADE80');
    });

    test('creates container with children', () {
      final element = ElementSchema(
        type: ElementType.column,
        style: const StyleSchema(padding: 16, spacing: 8),
        children: [
          ElementSchema(type: ElementType.text, text: 'Item 1'),
          ElementSchema(type: ElementType.text, text: 'Item 2'),
          ElementSchema(type: ElementType.text, text: 'Item 3'),
        ],
      );

      expect(element.type, ElementType.column);
      expect(element.children, hasLength(3));
      expect(element.style.padding, 16);
      expect(element.style.spacing, 8);
    });

    test('serializes element to JSON', () {
      final element = ElementSchema(
        type: ElementType.icon,
        iconName: 'battery_full',
        iconSize: 24,
        style: const StyleSchema(textColor: '#00FF00'),
      );

      final json = element.toJson();

      expect(json['type'], 'icon');
      expect(json['iconName'], 'battery_full');
      expect(json['iconSize'], 24);
      expect(json['style']['textColor'], '#00FF00');
    });

    test('deserializes element from JSON', () {
      final json = {
        'type': 'gauge',
        'gaugeType': 'linear',
        'gaugeMin': 0,
        'gaugeMax': 100,
        'binding': {'path': 'node.snr'},
      };

      final element = ElementSchema.fromJson(json);

      expect(element.type, ElementType.gauge);
      expect(element.gaugeType, GaugeType.linear);
      expect(element.gaugeMin, 0);
      expect(element.gaugeMax, 100);
      expect(element.binding?.path, 'node.snr');
    });
  });

  group('StyleSchema', () {
    test('creates with default values', () {
      const style = StyleSchema();

      expect(style.fontSize, isNull);
      expect(style.padding, isNull);
      expect(style.backgroundColor, isNull);
    });

    test('parses hex color', () {
      const style = StyleSchema(
        backgroundColor: '#FF5500',
        textColor: '#FFFFFF',
      );

      expect(style.backgroundColorValue, isNotNull);
      expect(style.textColorValue, isNotNull);
    });

    test('creates padding insets', () {
      const style = StyleSchema(padding: 16);

      final insets = style.paddingInsets;

      expect(insets, isNotNull);
      expect(insets!.left, 16);
      expect(insets.right, 16);
      expect(insets.top, 16);
      expect(insets.bottom, 16);
    });

    test('creates individual padding insets', () {
      const style = StyleSchema(
        paddingLeft: 8,
        paddingRight: 16,
        paddingTop: 4,
        paddingBottom: 12,
      );

      final insets = style.paddingInsets;

      expect(insets!.left, 8);
      expect(insets.right, 16);
      expect(insets.top, 4);
      expect(insets.bottom, 12);
    });

    test('serializes to JSON', () {
      const style = StyleSchema(
        fontSize: 14,
        fontWeight: 'bold',
        textColor: '#FFFFFF',
        backgroundColor: '#1E1E1E',
        padding: 12,
        borderRadius: 8,
      );

      final json = style.toJson();

      expect(json['fontSize'], 14);
      expect(json['fontWeight'], 'bold');
      expect(json['textColor'], '#FFFFFF');
      expect(json['backgroundColor'], '#1E1E1E');
      expect(json['padding'], 12);
      expect(json['borderRadius'], 8);
    });
  });

  group('BindingSchema', () {
    test('creates simple binding', () {
      const binding = BindingSchema(path: 'node.batteryLevel');

      expect(binding.path, 'node.batteryLevel');
      expect(binding.format, isNull);
      expect(binding.defaultValue, isNull);
    });

    test('creates binding with format', () {
      const binding = BindingSchema(
        path: 'node.temperature',
        format: '{value}°C',
        defaultValue: '--',
      );

      expect(binding.path, 'node.temperature');
      expect(binding.format, '{value}°C');
      expect(binding.defaultValue, '--');
    });

    test('serializes to JSON', () {
      const binding = BindingSchema(
        path: 'node.snr',
        format: '{value} dB',
        transform: 'round',
      );

      final json = binding.toJson();

      expect(json['path'], 'node.snr');
      expect(json['format'], '{value} dB');
      expect(json['transform'], 'round');
    });

    test('deserializes from JSON', () {
      final json = {
        'path': 'node.rssi',
        'format': '{value} dBm',
        'defaultValue': 'N/A',
      };

      final binding = BindingSchema.fromJson(json);

      expect(binding.path, 'node.rssi');
      expect(binding.format, '{value} dBm');
      expect(binding.defaultValue, 'N/A');
    });
  });

  group('CustomWidgetSize', () {
    test('all sizes exist', () {
      expect(CustomWidgetSize.values, contains(CustomWidgetSize.medium));
      expect(CustomWidgetSize.values, contains(CustomWidgetSize.large));
      expect(CustomWidgetSize.values, contains(CustomWidgetSize.custom));
    });

    test('size values count', () {
      expect(CustomWidgetSize.values.length, 3);
    });
  });

  group('ElementType', () {
    test('all element types exist', () {
      expect(ElementType.values, contains(ElementType.text));
      expect(ElementType.values, contains(ElementType.icon));
      expect(ElementType.values, contains(ElementType.gauge));
      expect(ElementType.values, contains(ElementType.chart));
      expect(ElementType.values, contains(ElementType.map));
      expect(ElementType.values, contains(ElementType.image));
      expect(ElementType.values, contains(ElementType.row));
      expect(ElementType.values, contains(ElementType.column));
      expect(ElementType.values, contains(ElementType.container));
      expect(ElementType.values, contains(ElementType.spacer));
      expect(ElementType.values, contains(ElementType.shape));
      expect(ElementType.values, contains(ElementType.conditional));
      expect(ElementType.values, contains(ElementType.stack));
    });
  });

  group('GaugeType', () {
    test('all gauge types exist', () {
      expect(GaugeType.values, contains(GaugeType.linear));
      expect(GaugeType.values, contains(GaugeType.radial));
      expect(GaugeType.values, contains(GaugeType.arc));
      expect(GaugeType.values, contains(GaugeType.battery));
      expect(GaugeType.values, contains(GaugeType.signal));
    });
  });

  group('Schema Versioning', () {
    test('new widgets have current schema version', () {
      final widget = WidgetSchema(
        name: 'Test Widget',
        root: ElementSchema(type: ElementType.text, text: 'Hello'),
      );

      expect(widget.schemaVersion, kCurrentSchemaVersion);
    });

    test('schemaVersion is serialized to JSON', () {
      final widget = WidgetSchema(
        name: 'Test Widget',
        root: ElementSchema(type: ElementType.text, text: 'Hello'),
      );

      final json = widget.toJson();

      expect(json['schemaVersion'], kCurrentSchemaVersion);
    });

    test('legacy widget without schemaVersion gets migrated', () {
      final json = {
        'id': 'legacy-widget',
        'name': 'Legacy Widget',
        'root': {'type': 'text', 'text': 'Old content'},
        // Note: no schemaVersion field
      };

      final widget = WidgetSchema.fromJson(json);

      // After migration, schema version should be current
      expect(widget.schemaVersion, kCurrentSchemaVersion);
    });

    test('schemaVersion preserved through copyWith', () {
      final widget = WidgetSchema(
        name: 'Test Widget',
        root: ElementSchema(type: ElementType.text, text: 'Hello'),
      );

      final copy = widget.copyWith(name: 'Updated Name');

      expect(copy.schemaVersion, widget.schemaVersion);
    });

    test('schemaVersion can be updated via copyWith', () {
      final widget = WidgetSchema(
        name: 'Test Widget',
        root: ElementSchema(type: ElementType.text, text: 'Hello'),
      );

      final upgraded = widget.copyWith(schemaVersion: 2);

      expect(upgraded.schemaVersion, 2);
    });
  });
}
