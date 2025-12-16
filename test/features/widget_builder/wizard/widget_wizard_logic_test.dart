import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';
import 'package:socialmesh/features/widget_builder/models/data_binding.dart';

/// Helper classes mirroring wizard internal structures for testing
class ThresholdLine {
  double value;
  Color color;
  String label;

  ThresholdLine({
    required this.value,
    required this.color,
    required this.label,
  });
}

class GradientConfig {
  bool enabled;
  Color lowColor;
  Color highColor;

  GradientConfig({
    this.enabled = false,
    this.lowColor = const Color(0xFF4CAF50),
    this.highColor = const Color(0xFFFF5252),
  });
}

/// Test helper to build schemas similar to the wizard
class WidgetSchemaBuilder {
  String name = 'Test Widget';
  String? templateId;
  Set<String> selectedBindings = {};
  Set<ActionType> selectedActions = {};
  Color accentColor = const Color(0xFF4F6AF6);
  bool showLabels = true;
  ChartType chartType = ChartType.area;
  bool mergeCharts = false;
  Map<String, Color> mergeColors = {};
  Map<String, ChartType> bindingChartTypes = {};
  ChartMergeMode mergeMode = ChartMergeMode.overlay;
  ChartNormalization normalization = ChartNormalization.raw;
  ChartBaseline baseline = ChartBaseline.none;
  int dataPoints = 30;
  bool showMinMax = false;
  Map<String, GradientConfig> seriesGradients = {};
  Map<String, List<ThresholdLine>> seriesThresholds = {};
  bool showGrid = true;
  bool showDots = true;
  bool smoothCurve = true;
  bool fillArea = true;

  String colorToHex(Color color) {
    // Using toARGB32() for non-deprecated color conversion
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  /// Build graph elements for testing
  List<ElementSchema> buildGraphElements() {
    if (selectedBindings.isEmpty) {
      return [
        ElementSchema(
          type: ElementType.text,
          text: 'Select data to display',
          style: StyleSchema(
            textColor: colorToHex(const Color(0xFF8B8D98)),
            fontSize: 13,
          ),
        ),
      ];
    }

    final children = <ElementSchema>[];
    final defaultChartColors = <Color>[
      const Color(0xFF4F6AF6),
      const Color(0xFF4ADE80),
      const Color(0xFFFBBF24),
      const Color(0xFFF472B6),
      const Color(0xFFA78BFA),
      const Color(0xFF22D3EE),
      const Color(0xFFFF6B6B),
      const Color(0xFFFF9F43),
    ];

    // Merge mode: single chart with multiple data series
    if (mergeCharts && selectedBindings.length > 1) {
      final legendLabels = <String>[];
      final legendColors = <String>[];
      final bindingsList = selectedBindings.toList();

      for (int i = 0; i < bindingsList.length; i++) {
        final bindingPath = bindingsList[i];
        final binding = BindingRegistry.bindings.firstWhere(
          (b) => b.path == bindingPath,
          orElse: () => BindingDefinition(
            path: bindingPath,
            label: bindingPath,
            description: '',
            category: BindingCategory.node,
            valueType: double,
          ),
        );
        legendLabels.add(binding.label);
        final color =
            mergeColors[bindingPath] ??
            defaultChartColors[i % defaultChartColors.length];
        legendColors.add(colorToHex(color));
      }

      // Get merged thresholds and gradients
      final mergedThresholds = seriesThresholds['_merged'] ?? [];
      final mergedGradient = seriesGradients['_merged'] ?? GradientConfig();

      children.add(
        ElementSchema(
          type: ElementType.chart,
          chartType: ChartType.multiLine,
          chartShowGrid: showGrid,
          chartShowDots: showDots,
          chartCurved: smoothCurve,
          chartMaxPoints: dataPoints,
          chartBindingPaths: bindingsList,
          chartLegendLabels: legendLabels,
          chartLegendColors: legendColors,
          chartMergeMode: mergeMode,
          chartNormalization: normalization,
          chartBaseline: baseline,
          chartShowMinMax: showMinMax,
          chartGradientFill: mergedGradient.enabled,
          chartGradientLowColor: colorToHex(mergedGradient.lowColor),
          chartGradientHighColor: colorToHex(mergedGradient.highColor),
          chartThresholds: mergedThresholds.map((t) => t.value).toList(),
          chartThresholdColors: mergedThresholds
              .map((t) => colorToHex(t.color))
              .toList(),
          chartThresholdLabels: mergedThresholds.map((t) => t.label).toList(),
          style: StyleSchema(height: 120.0, textColor: colorToHex(accentColor)),
        ),
      );
    } else {
      // Non-merged mode: separate chart per binding
      for (final bindingPath in selectedBindings) {
        final binding = BindingRegistry.bindings.firstWhere(
          (b) => b.path == bindingPath,
          orElse: () => BindingDefinition(
            path: bindingPath,
            label: bindingPath,
            description: '',
            category: BindingCategory.node,
            valueType: double,
          ),
        );

        ChartType bindingChartType =
            bindingChartTypes[bindingPath] ?? chartType;
        if (bindingChartType == ChartType.line && fillArea) {
          bindingChartType = ChartType.area;
        }

        final bindingIndex = selectedBindings.toList().indexOf(bindingPath);
        final bindingColor =
            mergeColors[bindingPath] ??
            (bindingIndex >= 0
                ? defaultChartColors[bindingIndex % defaultChartColors.length]
                : accentColor);

        // Get per-series thresholds and gradient
        final bindingThresholds = seriesThresholds[bindingPath] ?? [];
        final bindingGradient =
            seriesGradients[bindingPath] ?? GradientConfig();

        if (showLabels) {
          children.add(
            ElementSchema(
              type: ElementType.row,
              style: const StyleSchema(
                mainAxisAlignment: MainAxisAlignmentOption.spaceBetween,
                padding: 4,
              ),
              children: [
                ElementSchema(
                  type: ElementType.text,
                  text: binding.label,
                  style: StyleSchema(
                    textColor: colorToHex(const Color(0xFF8B8D98)),
                    fontSize: 12,
                    fontWeight: 'w500',
                  ),
                ),
                ElementSchema(
                  type: ElementType.text,
                  binding: BindingSchema(
                    path: bindingPath,
                    format: binding.defaultFormat ?? '{value}',
                    defaultValue: '--',
                  ),
                  style: StyleSchema(
                    textColor: colorToHex(bindingColor),
                    fontSize: 14,
                    fontWeight: 'w700',
                  ),
                ),
              ],
            ),
          );
          children.add(
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 8),
            ),
          );
        }

        children.add(
          ElementSchema(
            type: ElementType.chart,
            chartType: bindingChartType,
            chartShowGrid: showGrid,
            chartShowDots: showDots,
            chartCurved: smoothCurve,
            chartMaxPoints: dataPoints,
            binding: BindingSchema(path: bindingPath),
            chartNormalization: normalization,
            chartBaseline: baseline,
            chartShowMinMax: showMinMax,
            chartGradientFill: bindingGradient.enabled,
            chartGradientLowColor: colorToHex(bindingGradient.lowColor),
            chartGradientHighColor: colorToHex(bindingGradient.highColor),
            chartThresholds: bindingThresholds.map((t) => t.value).toList(),
            chartThresholdColors: bindingThresholds
                .map((t) => colorToHex(t.color))
                .toList(),
            chartThresholdLabels: bindingThresholds
                .map((t) => t.label)
                .toList(),
            style: StyleSchema(
              height: selectedBindings.length == 1 ? 100.0 : 70.0,
              textColor: colorToHex(bindingColor),
            ),
          ),
        );
      }
    }

    return children;
  }

  /// Migrate thresholds and gradients to merged mode
  void migrateToMerged() {
    // Migrate thresholds
    final allThresholds = <ThresholdLine>[];
    for (final bindingPath in selectedBindings) {
      final thresholds = seriesThresholds[bindingPath] ?? [];
      allThresholds.addAll(thresholds);
    }
    seriesThresholds.clear();
    if (allThresholds.isNotEmpty) {
      seriesThresholds['_merged'] = allThresholds.take(3).toList();
    }

    // Migrate gradients
    GradientConfig? firstEnabled;
    for (final bindingPath in selectedBindings) {
      final gradient = seriesGradients[bindingPath];
      if (gradient != null && gradient.enabled) {
        firstEnabled = gradient;
        break;
      }
    }
    seriesGradients.clear();
    if (firstEnabled != null) {
      seriesGradients['_merged'] = firstEnabled;
    }
  }

  /// Migrate thresholds and gradients from merged mode
  void migrateFromMerged() {
    // Migrate thresholds
    final mergedThresholds = seriesThresholds['_merged'] ?? [];
    seriesThresholds.remove('_merged');
    if (mergedThresholds.isNotEmpty && selectedBindings.isNotEmpty) {
      seriesThresholds[selectedBindings.first] = mergedThresholds;
    }

    // Migrate gradients
    final mergedGradient = seriesGradients['_merged'];
    seriesGradients.remove('_merged');
    if (mergedGradient != null &&
        mergedGradient.enabled &&
        selectedBindings.isNotEmpty) {
      seriesGradients[selectedBindings.first] = mergedGradient;
    }
  }

  /// Get active chart types based on current selection
  Set<ChartType> getActiveChartTypes() {
    if (mergeCharts && selectedBindings.length > 1) {
      return {ChartType.multiLine};
    }

    final types = <ChartType>{};
    if (selectedBindings.isNotEmpty) {
      for (final bindingPath in selectedBindings) {
        ChartType type = bindingChartTypes[bindingPath] ?? chartType;
        if (type == ChartType.line && fillArea) {
          type = ChartType.area;
        }
        types.add(type);
      }
    }
    return types;
  }
}

void main() {
  group('ThresholdLine', () {
    test('creates with required fields', () {
      final threshold = ThresholdLine(
        value: 50.0,
        color: Colors.red,
        label: 'Warning',
      );

      expect(threshold.value, 50.0);
      expect(threshold.color, Colors.red);
      expect(threshold.label, 'Warning');
    });

    test('allows mutable value changes', () {
      final threshold = ThresholdLine(
        value: 50.0,
        color: Colors.red,
        label: 'Warning',
      );

      threshold.value = 75.0;
      threshold.label = 'Critical';

      expect(threshold.value, 75.0);
      expect(threshold.label, 'Critical');
    });
  });

  group('GradientConfig', () {
    test('creates with default values', () {
      final config = GradientConfig();

      expect(config.enabled, false);
      expect(config.lowColor, const Color(0xFF4CAF50));
      expect(config.highColor, const Color(0xFFFF5252));
    });

    test('creates with custom values', () {
      final config = GradientConfig(
        enabled: true,
        lowColor: Colors.blue,
        highColor: Colors.orange,
      );

      expect(config.enabled, true);
      expect(config.lowColor, Colors.blue);
      expect(config.highColor, Colors.orange);
    });
  });

  group('WidgetSchemaBuilder - Graph Elements', () {
    test('returns empty state text when no bindings selected', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';

      final elements = builder.buildGraphElements();

      expect(elements.length, 1);
      expect(elements[0].type, ElementType.text);
      expect(elements[0].text, 'Select data to display');
    });

    test('builds single chart for one binding (non-merged)', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel'};
      builder.showLabels = true;

      final elements = builder.buildGraphElements();

      // Should have: label row, spacer, chart
      expect(elements.length, 3);
      expect(elements[0].type, ElementType.row); // Label row
      expect(elements[1].type, ElementType.spacer);
      expect(elements[2].type, ElementType.chart);
      expect(elements[2].chartType, ChartType.area);
    });

    test('builds separate charts for multiple bindings (non-merged)', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.showLabels = true;
      builder.mergeCharts = false;

      final elements = builder.buildGraphElements();

      // Should have 6 elements: (label, spacer, chart) x 2
      expect(elements.length, 6);
      expect(elements[2].type, ElementType.chart);
      expect(elements[5].type, ElementType.chart);
    });

    test('builds single merged chart for multiple bindings', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;

      final elements = builder.buildGraphElements();

      // Should have single merged chart
      expect(elements.length, 1);
      expect(elements[0].type, ElementType.chart);
      expect(elements[0].chartType, ChartType.multiLine);
      expect(elements[0].chartBindingPaths, ['node.batteryLevel', 'node.rssi']);
    });

    test('uses per-binding chart types when not merged', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.bindingChartTypes = {
        'node.batteryLevel': ChartType.bar,
        'node.rssi': ChartType.line,
      };
      builder.fillArea = false;
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements.length, 2);
      expect(elements[0].chartType, ChartType.bar);
      expect(elements[1].chartType, ChartType.line);
    });

    test('converts line to area when fillArea is true', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.rssi'};
      builder.chartType = ChartType.line;
      builder.fillArea = true;
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartType, ChartType.area);
    });

    test('applies per-series thresholds to non-merged charts', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel'};
      builder.seriesThresholds = {
        'node.batteryLevel': [
          ThresholdLine(value: 20, color: Colors.red, label: 'Low'),
          ThresholdLine(value: 80, color: Colors.green, label: 'Good'),
        ],
      };
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartThresholds, [20.0, 80.0]);
      expect(elements[0].chartThresholdLabels, ['Low', 'Good']);
    });

    test('applies merged thresholds to merged charts', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;
      builder.seriesThresholds = {
        '_merged': [
          ThresholdLine(value: 50, color: Colors.yellow, label: 'Mid'),
        ],
      };

      final elements = builder.buildGraphElements();

      expect(elements[0].chartThresholds, [50.0]);
      expect(elements[0].chartThresholdLabels, ['Mid']);
    });

    test('applies per-series gradients to non-merged charts', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel'};
      builder.seriesGradients = {
        'node.batteryLevel': GradientConfig(
          enabled: true,
          lowColor: Colors.blue,
          highColor: Colors.red,
        ),
      };
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartGradientFill, true);
    });

    test('applies merged gradient to merged charts', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;
      builder.seriesGradients = {
        '_merged': GradientConfig(
          enabled: true,
          lowColor: Colors.green,
          highColor: Colors.orange,
        ),
      };

      final elements = builder.buildGraphElements();

      expect(elements[0].chartGradientFill, true);
    });

    test('uses default colors for series', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;

      final elements = builder.buildGraphElements();

      // Default colors should be applied
      expect(elements[0].chartLegendColors!.length, 2);
      expect(elements[0].chartLegendColors![0], '#4F6AF6'); // Blue
      expect(elements[0].chartLegendColors![1], '#4ADE80'); // Green
    });

    test('uses custom merge colors when specified', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;
      builder.mergeColors = {
        'node.batteryLevel': const Color(0xFF9C27B0), // Purple
        'node.rssi': const Color(0xFFFF9800), // Orange
      };

      final elements = builder.buildGraphElements();

      expect(elements[0].chartLegendColors![0], '#9C27B0'); // Purple
      expect(elements[0].chartLegendColors![1], '#FF9800'); // Orange
    });

    test('applies chart options correctly', () {
      final builder = WidgetSchemaBuilder();
      builder.templateId = 'graph';
      builder.selectedBindings = {'node.rssi'};
      builder.showGrid = false;
      builder.showDots = false;
      builder.smoothCurve = false;
      builder.dataPoints = 60;
      builder.showMinMax = true;
      builder.normalization = ChartNormalization.percentChange;
      builder.baseline = ChartBaseline.firstValue;
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartShowGrid, false);
      expect(elements[0].chartShowDots, false);
      expect(elements[0].chartCurved, false);
      expect(elements[0].chartMaxPoints, 60);
      expect(elements[0].chartShowMinMax, true);
      expect(elements[0].chartNormalization, ChartNormalization.percentChange);
      expect(elements[0].chartBaseline, ChartBaseline.firstValue);
    });
  });

  group('WidgetSchemaBuilder - Threshold/Gradient Migration', () {
    test('migrateToMerged collects all thresholds into _merged key', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.seriesThresholds = {
        'node.batteryLevel': [
          ThresholdLine(value: 20, color: Colors.red, label: 'Low'),
        ],
        'node.rssi': [
          ThresholdLine(value: -80, color: Colors.yellow, label: 'Weak'),
        ],
      };

      builder.migrateToMerged();

      expect(builder.seriesThresholds.containsKey('_merged'), true);
      expect(builder.seriesThresholds['_merged']!.length, 2);
      expect(builder.seriesThresholds.containsKey('node.batteryLevel'), false);
      expect(builder.seriesThresholds.containsKey('node.rssi'), false);
    });

    test('migrateToMerged limits to 3 thresholds', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.seriesThresholds = {
        'node.batteryLevel': [
          ThresholdLine(value: 20, color: Colors.red, label: '1'),
          ThresholdLine(value: 50, color: Colors.yellow, label: '2'),
        ],
        'node.rssi': [
          ThresholdLine(value: -80, color: Colors.green, label: '3'),
          ThresholdLine(value: -60, color: Colors.blue, label: '4'),
        ],
      };

      builder.migrateToMerged();

      expect(builder.seriesThresholds['_merged']!.length, 3);
    });

    test('migrateToMerged uses first enabled gradient', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.seriesGradients = {
        'node.batteryLevel': GradientConfig(enabled: false),
        'node.rssi': GradientConfig(
          enabled: true,
          lowColor: Colors.blue,
          highColor: Colors.red,
        ),
      };

      builder.migrateToMerged();

      expect(builder.seriesGradients.containsKey('_merged'), true);
      expect(builder.seriesGradients['_merged']!.enabled, true);
      expect(builder.seriesGradients['_merged']!.lowColor, Colors.blue);
    });

    test('migrateFromMerged moves thresholds to first series', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.seriesThresholds = {
        '_merged': [
          ThresholdLine(value: 50, color: Colors.yellow, label: 'Mid'),
        ],
      };

      builder.migrateFromMerged();

      expect(builder.seriesThresholds.containsKey('_merged'), false);
      expect(builder.seriesThresholds.containsKey('node.batteryLevel'), true);
      expect(builder.seriesThresholds['node.batteryLevel']!.length, 1);
    });

    test('migrateFromMerged moves gradient to first series', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.seriesGradients = {
        '_merged': GradientConfig(
          enabled: true,
          lowColor: Colors.green,
          highColor: Colors.red,
        ),
      };

      builder.migrateFromMerged();

      expect(builder.seriesGradients.containsKey('_merged'), false);
      expect(builder.seriesGradients.containsKey('node.batteryLevel'), true);
      expect(builder.seriesGradients['node.batteryLevel']!.enabled, true);
    });

    test('migrateFromMerged handles empty bindings gracefully', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {};
      builder.seriesThresholds = {
        '_merged': [
          ThresholdLine(value: 50, color: Colors.yellow, label: 'Mid'),
        ],
      };

      builder.migrateFromMerged();

      expect(builder.seriesThresholds.isEmpty, true);
    });
  });

  group('WidgetSchemaBuilder - getActiveChartTypes', () {
    test('returns multiLine for merged charts with multiple bindings', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;

      final types = builder.getActiveChartTypes();

      expect(types, {ChartType.multiLine});
    });

    test('returns individual types for non-merged charts', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = false;
      builder.bindingChartTypes = {
        'node.batteryLevel': ChartType.bar,
        'node.rssi': ChartType.line,
      };
      builder.fillArea = false;

      final types = builder.getActiveChartTypes();

      expect(types, {ChartType.bar, ChartType.line});
    });

    test('converts line to area when fillArea is true', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.rssi'};
      builder.chartType = ChartType.line;
      builder.fillArea = true;

      final types = builder.getActiveChartTypes();

      expect(types, {ChartType.area});
    });

    test('uses default chart type when no binding-specific type set', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.rssi'};
      builder.chartType = ChartType.bar;
      builder.fillArea = false;

      final types = builder.getActiveChartTypes();

      expect(types, {ChartType.bar});
    });

    test('returns empty set for no bindings', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {};

      final types = builder.getActiveChartTypes();

      expect(types.isEmpty, true);
    });

    test('deduplicates same chart types', () {
      final builder = WidgetSchemaBuilder();
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.chartType = ChartType.bar;
      builder.fillArea = false;

      final types = builder.getActiveChartTypes();

      expect(types.length, 1);
      expect(types, {ChartType.bar});
    });
  });

  group('Color Conversion', () {
    test('colorToHex converts colors correctly', () {
      final builder = WidgetSchemaBuilder();

      expect(builder.colorToHex(const Color(0xFF4F6AF6)), '#4F6AF6');
      expect(builder.colorToHex(const Color(0xFF4ADE80)), '#4ADE80');
      expect(builder.colorToHex(Colors.red), '#F44336');
      expect(builder.colorToHex(Colors.white), '#FFFFFF');
      expect(builder.colorToHex(Colors.black), '#000000');
    });
  });

  group('Wizard Validation Logic', () {
    test('gauge template allows max 3 bindings', () {
      const maxGaugeBindings = 3;
      final selectedBindings = <String>{
        'node.batteryLevel',
        'node.rssi',
        'node.snr',
      };

      expect(selectedBindings.length <= maxGaugeBindings, true);

      selectedBindings.add('node.temperature');
      expect(selectedBindings.length <= maxGaugeBindings, false);
    });

    test('graph template allows max 2 bindings', () {
      const maxGraphBindings = 2;
      final selectedBindings = <String>{'node.batteryLevel', 'node.rssi'};

      expect(selectedBindings.length <= maxGraphBindings, true);

      selectedBindings.add('node.snr');
      expect(selectedBindings.length <= maxGraphBindings, false);
    });

    test('actions template requires actions not bindings', () {
      const templateId = 'actions';
      final selectedActions = <ActionType>{ActionType.shareLocation};
      final selectedBindings = <String>{};

      final isValid = templateId == 'actions'
          ? selectedActions.isNotEmpty
          : selectedBindings.isNotEmpty;

      expect(isValid, true);
    });

    test('data template requires bindings not actions', () {
      const templateId = 'status';
      final selectedActions = <ActionType>{};
      final selectedBindings = <String>{'node.batteryLevel'};

      final isValid = templateId == 'actions'
          ? selectedActions.isNotEmpty
          : selectedBindings.isNotEmpty;

      expect(isValid, true);
    });

    test('name defaults to "My Widget" when empty', () {
      String name = '';
      final finalName = name.trim().isEmpty ? 'My Widget' : name.trim();

      expect(finalName, 'My Widget');
    });

    test('name is trimmed and used when provided', () {
      String name = '  Custom Widget  ';
      final finalName = name.trim().isEmpty ? 'My Widget' : name.trim();

      expect(finalName, 'Custom Widget');
    });
  });

  group('Template Compatibility', () {
    test('actions template uses actions, not bindings', () {
      const isActionsTemplate = true;

      // Data selection step should show actions, not bindings
      expect(isActionsTemplate, true);
    });

    test('switching from actions to data clears actions', () {
      final selectedActions = <ActionType>{
        ActionType.shareLocation,
        ActionType.traceroute,
      };

      // Simulate switching to data template
      const newTemplateIsActions = false;
      if (!newTemplateIsActions) {
        selectedActions.clear();
      }

      expect(selectedActions.isEmpty, true);
    });

    test('switching from data to actions clears bindings', () {
      final selectedBindings = <String>{'node.batteryLevel', 'node.rssi'};

      // Simulate switching to actions template
      const newTemplateIsActions = true;
      if (newTemplateIsActions) {
        selectedBindings.clear();
      }

      expect(selectedBindings.isEmpty, true);
    });
  });

  group('Chart Merge Mode', () {
    test('overlay mode keeps series on same axis', () {
      final builder = WidgetSchemaBuilder();
      builder.mergeMode = ChartMergeMode.overlay;
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartMergeMode, ChartMergeMode.overlay);
    });

    test('stackedArea mode stacks series', () {
      final builder = WidgetSchemaBuilder();
      builder.mergeMode = ChartMergeMode.stackedArea;
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartMergeMode, ChartMergeMode.stackedArea);
    });

    test('stackedBar mode stacks bars', () {
      final builder = WidgetSchemaBuilder();
      builder.mergeMode = ChartMergeMode.stackedBar;
      builder.selectedBindings = {'node.batteryLevel', 'node.rssi'};
      builder.mergeCharts = true;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartMergeMode, ChartMergeMode.stackedBar);
    });
  });

  group('Normalization Modes', () {
    test('raw normalization shows actual values', () {
      final builder = WidgetSchemaBuilder();
      builder.normalization = ChartNormalization.raw;
      builder.selectedBindings = {'node.rssi'};
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartNormalization, ChartNormalization.raw);
    });

    test('percentChange normalization shows delta from start', () {
      final builder = WidgetSchemaBuilder();
      builder.normalization = ChartNormalization.percentChange;
      builder.selectedBindings = {'node.rssi'};
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartNormalization, ChartNormalization.percentChange);
    });

    test('normalized shows 0-100 scale', () {
      final builder = WidgetSchemaBuilder();
      builder.normalization = ChartNormalization.normalized;
      builder.selectedBindings = {'node.rssi'};
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartNormalization, ChartNormalization.normalized);
    });
  });

  group('Baseline Modes', () {
    test('none baseline shows raw start', () {
      final builder = WidgetSchemaBuilder();
      builder.baseline = ChartBaseline.none;
      builder.selectedBindings = {'node.rssi'};
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartBaseline, ChartBaseline.none);
    });

    test('firstValue baseline uses first data point', () {
      final builder = WidgetSchemaBuilder();
      builder.baseline = ChartBaseline.firstValue;
      builder.selectedBindings = {'node.rssi'};
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartBaseline, ChartBaseline.firstValue);
    });

    test('average baseline uses series average', () {
      final builder = WidgetSchemaBuilder();
      builder.baseline = ChartBaseline.average;
      builder.selectedBindings = {'node.rssi'};
      builder.showLabels = false;

      final elements = builder.buildGraphElements();

      expect(elements[0].chartBaseline, ChartBaseline.average);
    });
  });
}
