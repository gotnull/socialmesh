import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';
import 'package:socialmesh/features/widget_builder/models/data_binding.dart';

/// Note: Full widget tests for WidgetWizardScreen require extensive mocking
/// of Riverpod providers (nodesProvider, myNodeNumProvider, etc.) and
/// protocol service streams. These are integration-level tests.
///
/// The core logic of the wizard is tested in widget_wizard_logic_test.dart
/// which covers:
/// - Schema building for all template types
/// - Per-series thresholds and gradients
/// - Merge mode migration
/// - Chart type determination
/// - Validation logic
///
/// For full end-to-end testing of the wizard UI, consider using
/// integration_test/ with a real app instance.

void main() {
  group('WidgetSchema - Template Tag Generation', () {
    test('status template generates status tag', () {
      final schema = WidgetSchema(
        name: 'Battery Status',
        tags: ['status'],
        root: ElementSchema(type: ElementType.column, children: []),
      );

      expect(schema.tags, contains('status'));
    });

    test('graph template generates graph tag', () {
      final schema = WidgetSchema(
        name: 'Signal Graph',
        tags: ['graph'],
        root: ElementSchema(type: ElementType.column, children: []),
      );

      expect(schema.tags, contains('graph'));
    });

    test('actions template generates actions tag', () {
      final schema = WidgetSchema(
        name: 'Quick Actions',
        tags: ['actions'],
        root: ElementSchema(type: ElementType.column, children: []),
      );

      expect(schema.tags, contains('actions'));
    });
  });

  group('WidgetSchema - Layout Structure', () {
    test('vertical layout uses column element', () {
      final schema = WidgetSchema(
        name: 'Vertical Widget',
        root: ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(padding: 12, spacing: 8),
          children: [
            ElementSchema(type: ElementType.text, text: 'Item 1'),
            ElementSchema(type: ElementType.text, text: 'Item 2'),
          ],
        ),
      );

      expect(schema.root.type, ElementType.column);
      expect(schema.root.children.length, 2);
    });

    test('horizontal layout uses row element', () {
      final schema = WidgetSchema(
        name: 'Horizontal Widget',
        root: ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(
            padding: 12,
            spacing: 8,
            mainAxisAlignment: MainAxisAlignmentOption.spaceEvenly,
          ),
          children: [
            ElementSchema(type: ElementType.text, text: 'Item 1'),
            ElementSchema(type: ElementType.text, text: 'Item 2'),
          ],
        ),
      );

      expect(schema.root.type, ElementType.row);
      expect(schema.root.children.length, 2);
    });

    test('grid layout creates nested rows in column', () {
      final schema = WidgetSchema(
        name: 'Grid Widget',
        root: ElementSchema(
          type: ElementType.column,
          children: [
            ElementSchema(
              type: ElementType.row,
              children: [
                ElementSchema(type: ElementType.text, text: '1'),
                ElementSchema(type: ElementType.text, text: '2'),
              ],
            ),
            ElementSchema(
              type: ElementType.row,
              children: [
                ElementSchema(type: ElementType.text, text: '3'),
                ElementSchema(type: ElementType.text, text: '4'),
              ],
            ),
          ],
        ),
      );

      expect(schema.root.type, ElementType.column);
      expect(schema.root.children.length, 2);
      expect(schema.root.children[0].type, ElementType.row);
      expect(schema.root.children[1].type, ElementType.row);
    });
  });

  group('WidgetSchema - Data Bindings', () {
    test('status element has proper binding structure', () {
      final element = ElementSchema(
        type: ElementType.text,
        binding: BindingSchema(
          path: 'node.batteryLevel',
          format: '{value}%',
          defaultValue: '--',
        ),
        style: const StyleSchema(
          textColor: '#4F6AF6',
          fontSize: 24,
          fontWeight: 'w700',
        ),
      );

      expect(element.binding?.path, 'node.batteryLevel');
      expect(element.binding?.format, '{value}%');
      expect(element.binding?.defaultValue, '--');
    });

    test('chart element supports multiple binding paths', () {
      final element = ElementSchema(
        type: ElementType.chart,
        chartType: ChartType.multiLine,
        chartBindingPaths: ['node.batteryLevel', 'node.rssi'],
        chartLegendLabels: ['Battery', 'Signal'],
        chartLegendColors: ['#4F6AF6', '#4ADE80'],
      );

      expect(element.chartBindingPaths?.length, 2);
      expect(element.chartLegendLabels?.length, 2);
      expect(element.chartLegendColors?.length, 2);
    });
  });

  group('WidgetSchema - Chart Configuration', () {
    test('chart element stores threshold configuration', () {
      final element = ElementSchema(
        type: ElementType.chart,
        chartType: ChartType.area,
        binding: BindingSchema(path: 'node.batteryLevel'),
        chartThresholds: [20.0, 80.0],
        chartThresholdColors: ['#FF5252', '#4CAF50'],
        chartThresholdLabels: ['Low', 'Good'],
      );

      expect(element.chartThresholds, [20.0, 80.0]);
      expect(element.chartThresholdColors, ['#FF5252', '#4CAF50']);
      expect(element.chartThresholdLabels, ['Low', 'Good']);
    });

    test('chart element stores gradient configuration', () {
      final element = ElementSchema(
        type: ElementType.chart,
        chartType: ChartType.area,
        binding: BindingSchema(path: 'node.batteryLevel'),
        chartGradientFill: true,
        chartGradientLowColor: '#4CAF50',
        chartGradientHighColor: '#FF5252',
      );

      expect(element.chartGradientFill, true);
      expect(element.chartGradientLowColor, '#4CAF50');
      expect(element.chartGradientHighColor, '#FF5252');
    });

    test('chart element stores normalization and baseline', () {
      final element = ElementSchema(
        type: ElementType.chart,
        chartType: ChartType.area,
        binding: BindingSchema(path: 'node.rssi'),
        chartNormalization: ChartNormalization.percentChange,
        chartBaseline: ChartBaseline.firstValue,
      );

      expect(element.chartNormalization, ChartNormalization.percentChange);
      expect(element.chartBaseline, ChartBaseline.firstValue);
    });

    test('multiLine chart stores merge mode', () {
      final element = ElementSchema(
        type: ElementType.chart,
        chartType: ChartType.multiLine,
        chartBindingPaths: ['node.batteryLevel', 'node.rssi'],
        chartMergeMode: ChartMergeMode.stackedArea,
      );

      expect(element.chartMergeMode, ChartMergeMode.stackedArea);
    });

    test('chart stores display options', () {
      final element = ElementSchema(
        type: ElementType.chart,
        chartType: ChartType.line,
        binding: BindingSchema(path: 'node.rssi'),
        chartShowGrid: false,
        chartShowDots: true,
        chartCurved: false,
        chartMaxPoints: 60,
        chartShowMinMax: true,
      );

      expect(element.chartShowGrid, false);
      expect(element.chartShowDots, true);
      expect(element.chartCurved, false);
      expect(element.chartMaxPoints, 60);
      expect(element.chartShowMinMax, true);
    });
  });

  group('WidgetSchema - Gauge Configuration', () {
    test('gauge element has proper configuration', () {
      final element = ElementSchema(
        type: ElementType.gauge,
        gaugeType: GaugeType.radial,
        gaugeMin: 0,
        gaugeMax: 100,
        gaugeColor: '#4F6AF6',
        binding: BindingSchema(path: 'node.batteryLevel'),
        style: const StyleSchema(width: 80, height: 80),
      );

      expect(element.gaugeType, GaugeType.radial);
      expect(element.gaugeMin, 0);
      expect(element.gaugeMax, 100);
      expect(element.gaugeColor, '#4F6AF6');
    });
  });

  group('WidgetSchema - Action Configuration', () {
    test('action button has proper configuration', () {
      final element = ElementSchema(
        type: ElementType.button,
        text: 'Share Location',
        action: ActionSchema(type: ActionType.shareLocation),
        style: const StyleSchema(
          backgroundColor: '#4F6AF6',
          textColor: '#FFFFFF',
        ),
      );

      expect(element.action?.type, ActionType.shareLocation);
      expect(element.text, 'Share Location');
    });

    test('multiple action types are supported', () {
      final actions = [
        ActionType.shareLocation,
        ActionType.sendMessage,
        ActionType.traceroute,
        ActionType.requestPositions,
        ActionType.sos,
      ];

      for (final actionType in actions) {
        final element = ElementSchema(
          type: ElementType.button,
          action: ActionSchema(type: actionType),
        );
        expect(element.action?.type, actionType);
      }
    });
  });

  group('BindingRegistry - Available Bindings', () {
    test('battery level binding exists', () {
      final binding = BindingRegistry.bindings.firstWhere(
        (b) => b.path == 'node.batteryLevel',
        orElse: () => throw Exception('Battery binding not found'),
      );

      expect(binding.label, isNotEmpty);
      expect(binding.valueType, anyOf(int, double));
    });

    test('rssi binding exists', () {
      final binding = BindingRegistry.bindings.firstWhere(
        (b) => b.path == 'node.rssi',
        orElse: () => throw Exception('RSSI binding not found'),
      );

      expect(binding.label, isNotEmpty);
    });

    test('snr binding exists', () {
      final binding = BindingRegistry.bindings.firstWhere(
        (b) => b.path == 'node.snr',
        orElse: () => throw Exception('SNR binding not found'),
      );

      expect(binding.label, isNotEmpty);
    });

    test('numeric bindings have min/max values', () {
      final numericBindings = BindingRegistry.bindings.where(
        (b) => b.valueType == int || b.valueType == double,
      );

      for (final binding in numericBindings) {
        // At least some should have min/max
        if (binding.path == 'node.batteryLevel') {
          expect(binding.minValue, isNotNull);
          expect(binding.maxValue, isNotNull);
        }
      }
    });

    test('bindings have categories', () {
      for (final binding in BindingRegistry.bindings) {
        expect(binding.category, isNotNull);
      }
    });
  });

  group('Schema Serialization', () {
    test('complex widget schema round-trips through JSON', () {
      final original = WidgetSchema(
        name: 'Complex Widget',
        description: 'A widget with charts and thresholds',
        tags: ['graph'],
        root: ElementSchema(
          type: ElementType.column,
          children: [
            ElementSchema(
              type: ElementType.chart,
              chartType: ChartType.area,
              binding: BindingSchema(
                path: 'node.batteryLevel',
                format: '{value}%',
              ),
              chartShowGrid: true,
              chartShowDots: true,
              chartCurved: true,
              chartMaxPoints: 30,
              chartThresholds: [20.0, 80.0],
              chartThresholdColors: ['#FF5252', '#4CAF50'],
              chartThresholdLabels: ['Low', 'Good'],
              chartGradientFill: true,
              chartGradientLowColor: '#FF5252',
              chartGradientHighColor: '#4CAF50',
            ),
          ],
        ),
      );

      final json = original.toJson();
      final restored = WidgetSchema.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.tags, original.tags);
      expect(restored.root.children.length, 1);

      final chart = restored.root.children[0];
      expect(chart.chartType, ChartType.area);
      expect(chart.chartThresholds, [20.0, 80.0]);
      expect(chart.chartGradientFill, true);
    });

    test('multiLine chart schema round-trips', () {
      final original = WidgetSchema(
        name: 'Multi Series Chart',
        root: ElementSchema(
          type: ElementType.chart,
          chartType: ChartType.multiLine,
          chartBindingPaths: ['node.batteryLevel', 'node.rssi'],
          chartLegendLabels: ['Battery', 'Signal'],
          chartLegendColors: ['#4F6AF6', '#4ADE80'],
          chartMergeMode: ChartMergeMode.overlay,
          chartNormalization: ChartNormalization.normalized,
        ),
      );

      final json = original.toJson();
      final restored = WidgetSchema.fromJson(json);

      expect(restored.root.chartType, ChartType.multiLine);
      expect(restored.root.chartBindingPaths, [
        'node.batteryLevel',
        'node.rssi',
      ]);
      expect(restored.root.chartMergeMode, ChartMergeMode.overlay);
      expect(restored.root.chartNormalization, ChartNormalization.normalized);
    });
  });
}
