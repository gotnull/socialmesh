import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/widget_builder/models/data_binding.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';
import 'package:socialmesh/models/mesh_models.dart';

void main() {
  group('DataBindingEngine', () {
    late DataBindingEngine engine;

    setUp(() {
      engine = DataBindingEngine();
    });

    group('node bindings', () {
      late MeshNode testNode;

      setUp(() {
        testNode = MeshNode(
          nodeNum: 12345,
          longName: 'Test Node',
          shortName: 'TST',
          userId: '!abcd1234',
          lastHeard: DateTime.now(), // online
          isFavorite: true,
          batteryLevel: 85,
          voltage: 4.1,
          snr: 8,
          rssi: -95,
          temperature: 25.5,
          humidity: 65.0,
          barometricPressure: 1013.25,
          latitude: 37.7749,
          longitude: -122.4194,
          altitude: 10,
        );
        engine.setCurrentNode(testNode);
      });

      test('resolves node.longName', () {
        final binding = BindingSchema(path: 'node.longName');
        final value = engine.resolveBinding(binding);
        expect(value, 'Test Node');
      });

      test('resolves node.shortName', () {
        final binding = BindingSchema(path: 'node.shortName');
        final value = engine.resolveBinding(binding);
        expect(value, 'TST');
      });

      test('resolves node.batteryLevel', () {
        final binding = BindingSchema(path: 'node.batteryLevel');
        final value = engine.resolveBinding(binding);
        expect(value, 85);
      });

      test('resolves node.snr', () {
        final binding = BindingSchema(path: 'node.snr');
        final value = engine.resolveBinding(binding);
        expect(value, 8);
      });

      test('resolves node.rssi', () {
        final binding = BindingSchema(path: 'node.rssi');
        final value = engine.resolveBinding(binding);
        expect(value, -95);
      });

      test('resolves node.temperature', () {
        final binding = BindingSchema(path: 'node.temperature');
        final value = engine.resolveBinding(binding);
        expect(value, 25.5);
      });

      test('resolves node.humidity', () {
        final binding = BindingSchema(path: 'node.humidity');
        final value = engine.resolveBinding(binding);
        expect(value, 65.0);
      });

      test('resolves node.isOnline', () {
        final binding = BindingSchema(path: 'node.isOnline');
        final value = engine.resolveBinding(binding);
        expect(value, true);
      });

      test('resolves node.isFavorite', () {
        final binding = BindingSchema(path: 'node.isFavorite');
        final value = engine.resolveBinding(binding);
        expect(value, true);
      });

      test('resolves node.latitude', () {
        final binding = BindingSchema(path: 'node.latitude');
        final value = engine.resolveBinding(binding);
        expect(value, 37.7749);
      });

      test('resolves node.longitude', () {
        final binding = BindingSchema(path: 'node.longitude');
        final value = engine.resolveBinding(binding);
        expect(value, -122.4194);
      });

      test('returns null for unknown node field', () {
        final binding = BindingSchema(path: 'node.unknownField');
        final value = engine.resolveBinding(binding);
        expect(value, isNull);
      });

      test('returns null when no node set', () {
        engine.setCurrentNode(null);
        final binding = BindingSchema(path: 'node.longName');
        final value = engine.resolveBinding(binding);
        expect(value, isNull);
      });
    });

    group('network bindings', () {
      setUp(() {
        final now = DateTime.now();
        final offline = now.subtract(const Duration(hours: 3));
        final nodes = <int, MeshNode>{
          1: MeshNode(nodeNum: 1, longName: 'Node 1', lastHeard: now),
          2: MeshNode(nodeNum: 2, longName: 'Node 2', lastHeard: now),
          3: MeshNode(nodeNum: 3, longName: 'Node 3', lastHeard: offline),
          4: MeshNode(nodeNum: 4, longName: 'Node 4', lastHeard: now),
        };
        engine.setAllNodes(nodes);
      });

      test('resolves network.totalNodes', () {
        final binding = BindingSchema(path: 'network.totalNodes');
        final value = engine.resolveBinding(binding);
        expect(value, 4);
      });

      test('resolves network.onlineNodes', () {
        final binding = BindingSchema(path: 'network.onlineNodes');
        final value = engine.resolveBinding(binding);
        expect(value, 3);
      });

      test('returns 0 when no nodes set', () {
        engine.setAllNodes(null);
        final binding = BindingSchema(path: 'network.totalNodes');
        final value = engine.resolveBinding(binding);
        expect(value, 0);
      });
    });

    group('formatting', () {
      setUp(() {
        final node = MeshNode(
          nodeNum: 123,
          longName: 'Test',
          batteryLevel: 75,
          temperature: 23.456,
          snr: 8,
        );
        engine.setCurrentNode(node);
      });

      test('applies percent format', () {
        final binding = BindingSchema(
          path: 'node.batteryLevel',
          format: '{value}%',
        );
        final formatted = engine.resolveAndFormat(binding);
        expect(formatted, '75%');
      });

      test('applies suffix format', () {
        final binding = BindingSchema(
          path: 'node.temperature',
          format: '{value}°C',
        );
        final formatted = engine.resolveAndFormat(binding);
        expect(formatted, contains('°C'));
      });

      test('applies custom format', () {
        final binding = BindingSchema(
          path: 'node.snr',
          format: 'SNR: {value} dB',
        );
        final formatted = engine.resolveAndFormat(binding);
        expect(formatted, 'SNR: 8 dB');
      });

      test('uses default value when binding returns null', () {
        engine.setCurrentNode(null);
        final binding = BindingSchema(
          path: 'node.batteryLevel',
          format: '{value}%',
          defaultValue: '--',
        );
        final formatted = engine.resolveAndFormat(binding);
        expect(formatted, '--');
      });
    });

    group('transforms', () {
      setUp(() {
        final node = MeshNode(
          nodeNum: 123,
          longName: 'test node',
          temperature: 23.789,
          batteryLevel: 85,
        );
        engine.setCurrentNode(node);
      });

      test('applies round transform', () {
        final binding = BindingSchema(
          path: 'node.temperature',
          transform: 'round',
        );
        final value = engine.resolveBinding(binding);
        expect(value, 24);
      });

      test('applies floor transform', () {
        final binding = BindingSchema(
          path: 'node.temperature',
          transform: 'floor',
        );
        final value = engine.resolveBinding(binding);
        expect(value, 23);
      });

      test('applies ceil transform', () {
        final binding = BindingSchema(
          path: 'node.temperature',
          transform: 'ceil',
        );
        final value = engine.resolveBinding(binding);
        expect(value, 24);
      });

      test('applies uppercase transform', () {
        final binding = BindingSchema(
          path: 'node.longName',
          transform: 'uppercase',
        );
        final value = engine.resolveBinding(binding);
        expect(value, 'TEST NODE');
      });

      test('applies lowercase transform', () {
        final binding = BindingSchema(
          path: 'node.longName',
          transform: 'lowercase',
        );
        final value = engine.resolveBinding(binding);
        expect(value, 'test node');
      });
    });
  });

  group('ConditionalSchema', () {
    late DataBindingEngine engine;

    setUp(() {
      engine = DataBindingEngine();
      final node = MeshNode(
        nodeNum: 123,
        longName: 'Test',
        batteryLevel: 25,
        lastHeard: DateTime.now(), // online
        snr: 5,
      );
      engine.setCurrentNode(node);
    });

    test('evaluates equals condition', () {
      final condition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.equals,
        value: 25,
      );
      expect(engine.evaluateCondition(condition), isTrue);

      final falseCondition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.equals,
        value: 50,
      );
      expect(engine.evaluateCondition(falseCondition), isFalse);
    });

    test('evaluates notEquals condition', () {
      final condition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.notEquals,
        value: 50,
      );
      expect(engine.evaluateCondition(condition), isTrue);
    });

    test('evaluates greaterThan condition', () {
      final condition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.greaterThan,
        value: 20,
      );
      expect(engine.evaluateCondition(condition), isTrue);

      final falseCondition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.greaterThan,
        value: 30,
      );
      expect(engine.evaluateCondition(falseCondition), isFalse);
    });

    test('evaluates lessThan condition', () {
      final condition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.lessThan,
        value: 30,
      );
      expect(engine.evaluateCondition(condition), isTrue);
    });

    test('evaluates greaterOrEqual condition', () {
      final condition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.greaterOrEqual,
        value: 25,
      );
      expect(engine.evaluateCondition(condition), isTrue);
    });

    test('evaluates lessOrEqual condition', () {
      final condition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.lessOrEqual,
        value: 25,
      );
      expect(engine.evaluateCondition(condition), isTrue);
    });

    test('evaluates isNull condition', () {
      engine.setCurrentNode(null);
      final condition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.isNull,
        value: null,
      );
      expect(engine.evaluateCondition(condition), isTrue);
    });

    test('evaluates isNotNull condition', () {
      final condition = ConditionalSchema(
        bindingPath: 'node.batteryLevel',
        operator: ConditionalOperator.isNotNull,
        value: null,
      );
      expect(engine.evaluateCondition(condition), isTrue);
    });

    test('evaluates isEmpty condition for string', () {
      final node = MeshNode(nodeNum: 123, longName: '');
      engine.setCurrentNode(node);

      final condition = ConditionalSchema(
        bindingPath: 'node.longName',
        operator: ConditionalOperator.isEmpty,
        value: null,
      );
      expect(engine.evaluateCondition(condition), isTrue);
    });

    test('evaluates isNotEmpty condition for string', () {
      final condition = ConditionalSchema(
        bindingPath: 'node.longName',
        operator: ConditionalOperator.isNotEmpty,
        value: null,
      );
      expect(engine.evaluateCondition(condition), isTrue);
    });
  });

  group('BindingCategory', () {
    test('all binding categories exist', () {
      expect(BindingCategory.values, contains(BindingCategory.node));
      expect(BindingCategory.values, contains(BindingCategory.device));
      expect(BindingCategory.values, contains(BindingCategory.network));
      expect(BindingCategory.values, contains(BindingCategory.environment));
      expect(BindingCategory.values, contains(BindingCategory.power));
      expect(BindingCategory.values, contains(BindingCategory.airQuality));
      expect(BindingCategory.values, contains(BindingCategory.gps));
      expect(BindingCategory.values, contains(BindingCategory.messaging));
    });

    test('category values count', () {
      expect(BindingCategory.values.length, 8);
    });
  });

  group('BindingRegistry', () {
    test('all bindings have non-empty labels', () {
      for (final binding in BindingRegistry.bindings) {
        expect(
          binding.label.isNotEmpty,
          isTrue,
          reason: 'Binding ${binding.path} should have a non-empty label',
        );
        // Label should not be the raw path
        expect(
          binding.label,
          isNot(equals(binding.path)),
          reason: 'Binding ${binding.path} label should not be the raw path',
        );
      }
    });

    test('all bindings have valid categories', () {
      for (final binding in BindingRegistry.bindings) {
        expect(
          BindingCategory.values.contains(binding.category),
          isTrue,
          reason: 'Binding ${binding.path} has invalid category',
        );
      }
    });

    test('no duplicate binding paths', () {
      final paths = BindingRegistry.bindings.map((b) => b.path).toList();
      final uniquePaths = paths.toSet();
      expect(
        paths.length,
        equals(uniquePaths.length),
        reason: 'Duplicate binding paths found',
      );
    });

    group('marketplace widget binding aliases', () {
      // These are binding paths used by marketplace widgets that need proper labels
      final marketplaceBindingPaths = [
        'node.pressure',
        'device.snr',
        'device.rssi',
        'device.channelUtilization',
        'device.channelUtil',
        'node.temperature',
        'node.humidity',
        'messaging.recentCount',
        'network.onlineNodes',
        'network.totalNodes',
        'node.displayName',
        'node.firmwareVersion',
        'node.hardwareModel',
        'node.role',
      ];

      for (final path in marketplaceBindingPaths) {
        test('$path exists in registry with proper label', () {
          final binding = BindingRegistry.bindings.firstWhere(
            (b) => b.path == path,
            orElse: () => throw StateError('Binding $path not found'),
          );
          expect(binding.label.isNotEmpty, isTrue);
          expect(binding.label, isNot(equals(path)));
        });
      }
    });

    group('binding value resolution for aliases', () {
      late DataBindingEngine engine;
      late MeshNode testNode;

      setUp(() {
        engine = DataBindingEngine();
        testNode = MeshNode(
          nodeNum: 12345,
          longName: 'Test Node',
          shortName: 'TST',
          snr: 8,
          rssi: -95,
          temperature: 25.5,
          humidity: 65.0,
          barometricPressure: 1013.25,
          channelUtilization: 15.0,
        );
        engine.setCurrentNode(testNode);
      });

      test('node.pressure resolves to barometricPressure', () {
        final binding = BindingSchema(path: 'node.pressure');
        final value = engine.resolveBinding(binding);
        expect(value, 1013.25);
      });

      test('device.snr resolves to snr', () {
        final binding = BindingSchema(path: 'device.snr');
        final value = engine.resolveBinding(binding);
        expect(value, 8);
      });

      test('device.rssi resolves to rssi', () {
        final binding = BindingSchema(path: 'device.rssi');
        final value = engine.resolveBinding(binding);
        expect(value, -95);
      });

      test('device.channelUtilization resolves to channelUtilization', () {
        final binding = BindingSchema(path: 'device.channelUtilization');
        final value = engine.resolveBinding(binding);
        expect(value, 15.0);
      });

      test('device.channelUtil resolves to channelUtilization', () {
        final binding = BindingSchema(path: 'device.channelUtil');
        final value = engine.resolveBinding(binding);
        expect(value, 15.0);
      });
    });

    group('preview mode for marketplace bindings', () {
      late DataBindingEngine engine;

      setUp(() {
        engine = DataBindingEngine();
        engine.setUsePlaceholderData(true);
      });

      test('node.pressure returns placeholder in preview mode', () {
        final binding = BindingSchema(path: 'node.pressure');
        final value = engine.resolveBinding(binding);
        expect(value, isNotNull);
        expect(value, isA<num>());
      });

      test('device.snr returns placeholder in preview mode', () {
        final binding = BindingSchema(path: 'device.snr');
        final value = engine.resolveBinding(binding);
        expect(value, isNotNull);
        expect(value, isA<num>());
      });

      test('device.rssi returns placeholder in preview mode', () {
        final binding = BindingSchema(path: 'device.rssi');
        final value = engine.resolveBinding(binding);
        expect(value, isNotNull);
        expect(value, isA<num>());
      });

      test('device.channelUtil returns placeholder in preview mode', () {
        final binding = BindingSchema(path: 'device.channelUtil');
        final value = engine.resolveBinding(binding);
        expect(value, isNotNull);
        expect(value, isA<num>());
      });
    });
  });
}
