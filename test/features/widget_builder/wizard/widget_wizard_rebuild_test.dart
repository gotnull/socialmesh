import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';
import 'package:socialmesh/features/widget_builder/models/data_binding.dart';

/// Enum mirrors wizard's LayoutStyle
enum LayoutStyle { vertical, horizontal, grid }

/// Helper that mirrors wizard's `_requiresStructuralRebuild` logic
bool requiresStructuralRebuild({
  required String? oldTemplate,
  required String? newTemplate,
  required LayoutStyle oldLayout,
  required LayoutStyle newLayout,
  required Set<String> oldBindings,
  required Set<String> newBindings,
  required Set<ActionType> oldActions,
  required Set<ActionType> newActions,
  required bool oldShowLabels,
  required bool newShowLabels,
}) {
  if (oldTemplate != newTemplate) return true;
  if (oldLayout != newLayout) return true;
  if (!_setEquals(oldBindings, newBindings)) return true;
  if (!_setEquals(oldActions, newActions)) return true;
  if (oldShowLabels != newShowLabels) return true;
  return false;
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

/// Helper that mirrors wizard's `_detectShowLabels` logic
bool detectShowLabels(ElementSchema? root) {
  if (root == null) return true;
  return _hasStaticTextLabels(root);
}

bool _hasStaticTextLabels(ElementSchema element) {
  // A text element without binding is a static label
  if (element.type == ElementType.text &&
      element.binding == null &&
      element.text != null &&
      element.text!.isNotEmpty) {
    return true;
  }

  for (final child in element.children) {
    if (_hasStaticTextLabels(child)) {
      return true;
    }
  }
  return false;
}

/// Helper that mirrors wizard's `_detectLayoutStyle` logic
LayoutStyle detectLayoutStyle(ElementSchema root) {
  // Check top-level structure
  if (root.type == ElementType.column) {
    // Check if children contain rows (horizontal/grid) or direct elements
    // (vertical)
    final hasRows = root.children.any((child) => child.type == ElementType.row);

    if (!hasRows) {
      return LayoutStyle.vertical;
    }

    // Analyze rows to distinguish horizontal vs grid
    final rows = root.children
        .where((child) => child.type == ElementType.row)
        .toList();
    if (rows.isEmpty) {
      return LayoutStyle.vertical;
    }

    // Check first row structure
    final firstRow = rows.first;
    final itemsPerRow = firstRow.children.length;
    // Style is non-null by design in ElementSchema
    final rowStyle = firstRow.style;
    final spacing = rowStyle.spacing ?? 0;
    final mainAxis = rowStyle.mainAxisAlignment;
    // Note: crossAxis not currently used in detection but preserved for future use

    // Grid detection:
    // - 2 items per row
    // - spacing >= 10
    // - mainAxis is start (with flex children) - NOT spaceEvenly (horizontal uses that)
    if (itemsPerRow <= 2 &&
        spacing >= 10 &&
        mainAxis == MainAxisAlignmentOption.start) {
      return LayoutStyle.grid;
    } else if (itemsPerRow >= 3 &&
        mainAxis == MainAxisAlignmentOption.spaceEvenly) {
      return LayoutStyle.horizontal;
    }

    // Fallback: more items = horizontal, fewer = grid
    return itemsPerRow >= 3 ? LayoutStyle.horizontal : LayoutStyle.grid;
  }

  if (root.type == ElementType.row) {
    return LayoutStyle.horizontal;
  }

  return LayoutStyle.vertical;
}

/// Builds a schema structure similar to what wizard generates for each layout
class TestSchemaBuilder {
  final String colorAccent = '#4F6AF6';

  ElementSchema buildVerticalLayout({
    required List<String> bindings,
    required bool showLabels,
    required String accentColor,
  }) {
    final children = <ElementSchema>[];

    for (final binding in bindings) {
      final bindingDef = BindingRegistry.bindings.firstWhere(
        (b) => b.path == binding,
        orElse: () => BindingDefinition(
          path: binding,
          label: binding.split('.').last,
          description: '',
          category: BindingCategory.node,
          valueType: double,
        ),
      );

      if (showLabels) {
        children.add(
          ElementSchema(
            type: ElementType.text,
            text: bindingDef.label,
            style: StyleSchema(textColor: '#8B8D98', fontSize: 12),
          ),
        );
      }
      children.add(
        ElementSchema(
          type: ElementType.text,
          binding: BindingSchema(path: binding),
          style: StyleSchema(textColor: accentColor, fontSize: 24),
        ),
      );
    }

    return ElementSchema(
      type: ElementType.column,
      style: const StyleSchema(
        padding: 16,
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignmentOption.start,
      ),
      children: children,
    );
  }

  ElementSchema buildHorizontalLayout({
    required List<String> bindings,
    required bool showLabels,
    required String accentColor,
  }) {
    final rowChildren = <ElementSchema>[];

    for (final binding in bindings) {
      final bindingDef = BindingRegistry.bindings.firstWhere(
        (b) => b.path == binding,
        orElse: () => BindingDefinition(
          path: binding,
          label: binding.split('.').last,
          description: '',
          category: BindingCategory.node,
          valueType: double,
        ),
      );

      final itemChildren = <ElementSchema>[];
      if (showLabels) {
        itemChildren.add(
          ElementSchema(
            type: ElementType.text,
            text: bindingDef.label,
            style: const StyleSchema(textColor: '#8B8D98', fontSize: 9),
          ),
        );
      }
      itemChildren.add(
        ElementSchema(
          type: ElementType.text,
          binding: BindingSchema(path: binding),
          style: StyleSchema(
            textColor: accentColor,
            fontSize: 14,
            fontWeight: 'w700',
          ),
        ),
      );

      rowChildren.add(
        ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(
            padding: 6,
            spacing: 2,
            crossAxisAlignment: CrossAxisAlignmentOption.center,
          ),
          children: itemChildren,
        ),
      );
    }

    return ElementSchema(
      type: ElementType.column,
      style: const StyleSchema(padding: 12),
      children: [
        ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(
            mainAxisAlignment: MainAxisAlignmentOption.spaceEvenly,
            spacing: 6,
          ),
          children: rowChildren,
        ),
      ],
    );
  }

  ElementSchema buildGridLayout({
    required List<String> bindings,
    required bool showLabels,
    required String accentColor,
  }) {
    final rows = <ElementSchema>[];

    // Build rows of 2 items each
    for (int i = 0; i < bindings.length; i += 2) {
      final rowChildren = <ElementSchema>[];

      for (int j = i; j < i + 2 && j < bindings.length; j++) {
        final binding = bindings[j];
        final bindingDef = BindingRegistry.bindings.firstWhere(
          (b) => b.path == binding,
          orElse: () => BindingDefinition(
            path: binding,
            label: binding.split('.').last,
            description: '',
            category: BindingCategory.node,
            valueType: double,
          ),
        );

        final itemChildren = <ElementSchema>[];
        if (showLabels) {
          itemChildren.add(
            ElementSchema(
              type: ElementType.text,
              text: bindingDef.label,
              style: const StyleSchema(textColor: '#8B8D98', fontSize: 12),
            ),
          );
        }
        itemChildren.add(
          ElementSchema(
            type: ElementType.text,
            binding: BindingSchema(path: binding),
            style: StyleSchema(
              textColor: accentColor,
              fontSize: 24,
              fontWeight: 'w700',
            ),
          ),
        );

        // Grid items use flex:1 for equal distribution, NOT expanded:true
        // This avoids conflicts with row alignment
        rowChildren.add(
          ElementSchema(
            type: ElementType.column,
            style: StyleSchema(
              padding: 16,
              borderRadius: 12,
              borderColor: accentColor,
              borderWidth: 1,
              alignment: AlignmentOption.center,
              spacing: 8,
              flex: 1, // Use flex instead of expanded
            ),
            children: itemChildren,
          ),
        );
      }

      rows.add(
        ElementSchema(
          type: ElementType.row,
          style: const StyleSchema(
            // Use start alignment with flex children (not spaceBetween)
            // Do NOT use stretch cross-axis - causes unbounded height issues
            mainAxisAlignment: MainAxisAlignmentOption.start,
            crossAxisAlignment: CrossAxisAlignmentOption.start,
            spacing: 12,
          ),
          children: rowChildren,
        ),
      );
    }

    return ElementSchema(
      type: ElementType.column,
      style: const StyleSchema(padding: 16, spacing: 12),
      children: rows,
    );
  }
}

void main() {
  group('Structural Rebuild Predicate', () {
    test('template change triggers rebuild', () {
      final result = requiresStructuralRebuild(
        oldTemplate: 'status',
        newTemplate: 'info',
        oldLayout: LayoutStyle.vertical,
        newLayout: LayoutStyle.vertical,
        oldBindings: {'node.batteryLevel'},
        newBindings: {'node.batteryLevel'},
        oldActions: {},
        newActions: {},
        oldShowLabels: true,
        newShowLabels: true,
      );

      expect(result, true, reason: 'Template change must trigger rebuild');
    });

    test('layout change triggers rebuild', () {
      final result = requiresStructuralRebuild(
        oldTemplate: 'status',
        newTemplate: 'status',
        oldLayout: LayoutStyle.vertical,
        newLayout: LayoutStyle.horizontal,
        oldBindings: {'node.batteryLevel'},
        newBindings: {'node.batteryLevel'},
        oldActions: {},
        newActions: {},
        oldShowLabels: true,
        newShowLabels: true,
      );

      expect(result, true, reason: 'Layout change must trigger rebuild');
    });

    test('binding change triggers rebuild', () {
      final result = requiresStructuralRebuild(
        oldTemplate: 'status',
        newTemplate: 'status',
        oldLayout: LayoutStyle.vertical,
        newLayout: LayoutStyle.vertical,
        oldBindings: {'node.batteryLevel'},
        newBindings: {'node.batteryLevel', 'node.rssi'},
        oldActions: {},
        newActions: {},
        oldShowLabels: true,
        newShowLabels: true,
      );

      expect(result, true, reason: 'Binding change must trigger rebuild');
    });

    test('action change triggers rebuild', () {
      final result = requiresStructuralRebuild(
        oldTemplate: 'actions',
        newTemplate: 'actions',
        oldLayout: LayoutStyle.vertical,
        newLayout: LayoutStyle.vertical,
        oldBindings: {},
        newBindings: {},
        oldActions: {ActionType.traceroute},
        newActions: {ActionType.traceroute, ActionType.requestPositions},
        oldShowLabels: true,
        newShowLabels: true,
      );

      expect(result, true, reason: 'Action change must trigger rebuild');
    });

    test('showLabels change triggers rebuild', () {
      final result = requiresStructuralRebuild(
        oldTemplate: 'status',
        newTemplate: 'status',
        oldLayout: LayoutStyle.vertical,
        newLayout: LayoutStyle.vertical,
        oldBindings: {'node.batteryLevel'},
        newBindings: {'node.batteryLevel'},
        oldActions: {},
        newActions: {},
        oldShowLabels: true,
        newShowLabels: false,
      );

      expect(result, true, reason: 'showLabels toggle must trigger rebuild');
    });

    test('accent color change does NOT trigger rebuild', () {
      // Note: accent color is an appearance change, not structural
      // The predicate doesn't check accent color
      final result = requiresStructuralRebuild(
        oldTemplate: 'status',
        newTemplate: 'status',
        oldLayout: LayoutStyle.vertical,
        newLayout: LayoutStyle.vertical,
        oldBindings: {'node.batteryLevel'},
        newBindings: {'node.batteryLevel'},
        oldActions: {},
        newActions: {},
        oldShowLabels: true,
        newShowLabels: true,
      );

      expect(
        result,
        false,
        reason: 'Accent color is not checked, no structural change',
      );
    });

    test('identical state does NOT trigger rebuild', () {
      final result = requiresStructuralRebuild(
        oldTemplate: 'info',
        newTemplate: 'info',
        oldLayout: LayoutStyle.grid,
        newLayout: LayoutStyle.grid,
        oldBindings: {'node.rssi', 'node.snr'},
        newBindings: {'node.rssi', 'node.snr'},
        oldActions: {},
        newActions: {},
        oldShowLabels: false,
        newShowLabels: false,
      );

      expect(result, false, reason: 'Identical state should not rebuild');
    });

    test(
      'binding order change does NOT trigger rebuild (sets are unordered)',
      () {
        final result = requiresStructuralRebuild(
          oldTemplate: 'status',
          newTemplate: 'status',
          oldLayout: LayoutStyle.vertical,
          newLayout: LayoutStyle.vertical,
          oldBindings: {'node.batteryLevel', 'node.rssi'},
          newBindings: {'node.rssi', 'node.batteryLevel'},
          oldActions: {},
          newActions: {},
          oldShowLabels: true,
          newShowLabels: true,
        );

        expect(
          result,
          false,
          reason: 'Same bindings in different order = same set',
        );
      },
    );
  });

  group('Show Labels Detection', () {
    final builder = TestSchemaBuilder();

    test('detects labels present in vertical layout', () {
      final schema = builder.buildVerticalLayout(
        bindings: ['node.batteryLevel'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final detected = detectShowLabels(schema);
      expect(detected, true, reason: 'Schema with labels should detect true');
    });

    test('detects labels absent in vertical layout', () {
      final schema = builder.buildVerticalLayout(
        bindings: ['node.batteryLevel'],
        showLabels: false,
        accentColor: '#4F6AF6',
      );

      final detected = detectShowLabels(schema);
      expect(
        detected,
        false,
        reason: 'Schema without labels should detect false',
      );
    });

    test('detects labels present in horizontal layout', () {
      final schema = builder.buildHorizontalLayout(
        bindings: ['node.batteryLevel', 'node.rssi', 'node.snr'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final detected = detectShowLabels(schema);
      expect(detected, true);
    });

    test('detects labels absent in horizontal layout', () {
      final schema = builder.buildHorizontalLayout(
        bindings: ['node.batteryLevel', 'node.rssi', 'node.snr'],
        showLabels: false,
        accentColor: '#4F6AF6',
      );

      final detected = detectShowLabels(schema);
      expect(detected, false);
    });

    test('detects labels present in grid layout', () {
      final schema = builder.buildGridLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final detected = detectShowLabels(schema);
      expect(detected, true);
    });

    test('detects labels absent in grid layout', () {
      final schema = builder.buildGridLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: false,
        accentColor: '#4F6AF6',
      );

      final detected = detectShowLabels(schema);
      expect(detected, false);
    });

    test('returns true for null root (safe default)', () {
      final detected = detectShowLabels(null);
      expect(detected, true, reason: 'Null root defaults to showing labels');
    });
  });

  group('Layout Style Detection', () {
    final builder = TestSchemaBuilder();

    test('detects vertical layout', () {
      final schema = builder.buildVerticalLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final detected = detectLayoutStyle(schema);
      expect(detected, LayoutStyle.vertical);
    });

    test('detects horizontal layout', () {
      final schema = builder.buildHorizontalLayout(
        bindings: ['node.batteryLevel', 'node.rssi', 'node.snr'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final detected = detectLayoutStyle(schema);
      expect(detected, LayoutStyle.horizontal);
    });

    test('detects grid layout', () {
      final schema = builder.buildGridLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final detected = detectLayoutStyle(schema);
      expect(detected, LayoutStyle.grid);
    });

    test('grid vs horizontal: different row structure', () {
      // Build both and verify detection
      final gridSchema = builder.buildGridLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final horizontalSchema = builder.buildHorizontalLayout(
        bindings: ['node.batteryLevel', 'node.rssi', 'node.snr'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final gridDetected = detectLayoutStyle(gridSchema);
      final horizontalDetected = detectLayoutStyle(horizontalSchema);

      expect(
        gridDetected,
        LayoutStyle.grid,
        reason: 'Grid with 2 items per row should be detected as grid',
      );
      expect(
        horizontalDetected,
        LayoutStyle.horizontal,
        reason: 'Horizontal with 3+ items and spaceEvenly should be horizontal',
      );
      expect(
        gridDetected,
        isNot(equals(horizontalDetected)),
        reason: 'Grid and horizontal must be differentiated',
      );
    });
  });

  group('Layout Structure Differentiation', () {
    final builder = TestSchemaBuilder();

    test('horizontal layout has compact styling', () {
      final schema = builder.buildHorizontalLayout(
        bindings: ['node.batteryLevel', 'node.rssi', 'node.snr'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      // Check the row structure
      expect(schema.type, ElementType.column);
      final row = schema.children.first;
      expect(row.type, ElementType.row);
      final rowStyle = row.style;
      expect(rowStyle.mainAxisAlignment, MainAxisAlignmentOption.spaceEvenly);
      expect(rowStyle.spacing, 6);

      // Check individual items
      final item = row.children.first;
      final itemStyle = item.style;
      expect(itemStyle.padding, 6);
      expect(itemStyle.crossAxisAlignment, CrossAxisAlignmentOption.center);
    });

    test('grid layout has card styling with borders', () {
      final schema = builder.buildGridLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      // Check the row structure
      expect(schema.type, ElementType.column);
      final schemaStyle = schema.style;
      expect(schemaStyle.spacing, 12);
      final row = schema.children.first;
      expect(row.type, ElementType.row);
      final rowStyle = row.style;
      // Grid uses start alignment with flex children (not spaceBetween)
      // Cross-axis is start (not stretch - that causes layout issues)
      expect(rowStyle.mainAxisAlignment, MainAxisAlignmentOption.start);
      expect(rowStyle.crossAxisAlignment, CrossAxisAlignmentOption.start);
      expect(rowStyle.spacing, 12);

      // Check individual items have card styling
      final item = row.children.first;
      // Grid items are directly column elements with card styling
      expect(item.type, ElementType.column);
      final itemStyle = item.style;
      expect(itemStyle.padding, 16);
      expect(itemStyle.borderRadius, 12);
      expect(itemStyle.borderWidth, 1);
      expect(itemStyle.flex, 1, reason: 'Grid items should use flex:1');
    });

    test('horizontal and grid generate different font sizes', () {
      final horizontalSchema = builder.buildHorizontalLayout(
        bindings: ['node.batteryLevel'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final gridSchema = builder.buildGridLayout(
        bindings: ['node.batteryLevel'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      // Find the value text elements
      ElementSchema? findValueText(ElementSchema element) {
        if (element.type == ElementType.text && element.binding != null) {
          return element;
        }
        for (final child in element.children) {
          final found = findValueText(child);
          if (found != null) return found;
        }
        return null;
      }

      final horizontalValue = findValueText(horizontalSchema);
      final gridValue = findValueText(gridSchema);

      expect(horizontalValue, isNotNull);
      expect(gridValue, isNotNull);
      final horizontalStyle = horizontalValue!.style;
      final gridStyle = gridValue!.style;
      expect(
        horizontalStyle.fontSize,
        14,
        reason: 'Horizontal uses compact 14px value text',
      );
      expect(
        gridStyle.fontSize,
        24,
        reason: 'Grid uses larger 24px value text',
      );
    });
  });

  group('Edit Mode Round-Trip', () {
    final builder = TestSchemaBuilder();

    test('vertical layout round-trips correctly', () {
      final original = builder.buildVerticalLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: true,
        accentColor: '#FF5252',
      );

      final detectedLayout = detectLayoutStyle(original);
      final detectedLabels = detectShowLabels(original);

      expect(detectedLayout, LayoutStyle.vertical);
      expect(detectedLabels, true);
    });

    test('horizontal layout round-trips correctly', () {
      final original = builder.buildHorizontalLayout(
        bindings: ['node.batteryLevel', 'node.rssi', 'node.snr'],
        showLabels: false,
        accentColor: '#4ADE80',
      );

      final detectedLayout = detectLayoutStyle(original);
      final detectedLabels = detectShowLabels(original);

      expect(detectedLayout, LayoutStyle.horizontal);
      expect(detectedLabels, false);
    });

    test('grid layout round-trips correctly', () {
      final original = builder.buildGridLayout(
        bindings: [
          'node.batteryLevel',
          'node.rssi',
          'node.snr',
          'node.hopsAway',
        ],
        showLabels: true,
        accentColor: '#FBBF24',
      );

      final detectedLayout = detectLayoutStyle(original);
      final detectedLabels = detectShowLabels(original);

      expect(detectedLayout, LayoutStyle.grid);
      expect(detectedLabels, true);
    });
  });

  group('Schema Serialization Preserves Layout Properties', () {
    final builder = TestSchemaBuilder();

    test('horizontal layout survives JSON round-trip', () {
      final original = builder.buildHorizontalLayout(
        bindings: ['node.batteryLevel', 'node.rssi', 'node.snr'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      final schema = WidgetSchema(name: 'Test Horizontal', root: original);

      final json = schema.toJson();
      final restored = WidgetSchema.fromJson(json);

      final detectedLayout = detectLayoutStyle(restored.root);
      final detectedLabels = detectShowLabels(restored.root);

      expect(detectedLayout, LayoutStyle.horizontal);
      expect(detectedLabels, true);
    });

    test('grid layout survives JSON round-trip', () {
      final original = builder.buildGridLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: false,
        accentColor: '#FF5252',
      );

      final schema = WidgetSchema(name: 'Test Grid', root: original);

      final json = schema.toJson();
      final restored = WidgetSchema.fromJson(json);

      final detectedLayout = detectLayoutStyle(restored.root);
      final detectedLabels = detectShowLabels(restored.root);

      expect(detectedLayout, LayoutStyle.grid);
      expect(detectedLabels, false);
    });

    test('vertical layout survives JSON round-trip', () {
      final original = builder.buildVerticalLayout(
        bindings: ['node.batteryLevel'],
        showLabels: true,
        accentColor: '#4ADE80',
      );

      final schema = WidgetSchema(name: 'Test Vertical', root: original);

      final json = schema.toJson();
      final restored = WidgetSchema.fromJson(json);

      final detectedLayout = detectLayoutStyle(restored.root);
      final detectedLabels = detectShowLabels(restored.root);

      expect(detectedLayout, LayoutStyle.vertical);
      expect(detectedLabels, true);
    });
  });

  group('Grid Layout Regression Tests', () {
    final builder = TestSchemaBuilder();

    test('grid layout uses flex instead of expanded on children', () {
      // This tests for a specific bug where grid children had expanded: true
      // which causes layout conflicts in Flutter. The fix is to use flex: 1 instead.
      final schema = builder.buildGridLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      // Grid should be column with row children
      expect(schema.type, ElementType.column);
      expect(schema.children.isNotEmpty, true);

      // Each row's children should use flex, NOT expanded
      for (final row in schema.children) {
        if (row.type == ElementType.row) {
          for (final child in row.children) {
            // Children should NOT have expanded: true (causes layout conflicts)
            expect(
              child.style.expanded,
              isNot(true),
              reason:
                  'Grid row children should not use expanded:true '
                  '(causes layout conflicts)',
            );
            // Children SHOULD have flex: 1 for equal distribution
            expect(
              child.style.flex,
              1,
              reason:
                  'Grid row children should use flex:1 for equal distribution',
            );
          }
        }
      }
    });

    test(
      'switching horizontal to grid triggers rebuild and changes structure',
      () {
        // Start with horizontal
        final bindings = {'node.batteryLevel', 'node.rssi', 'node.snr'};

        // Horizontal -> Grid should require rebuild
        final needsRebuild = requiresStructuralRebuild(
          oldTemplate: 'status',
          newTemplate: 'status',
          oldLayout: LayoutStyle.horizontal,
          newLayout: LayoutStyle.grid,
          oldBindings: bindings,
          newBindings: bindings,
          oldActions: {},
          newActions: {},
          oldShowLabels: true,
          newShowLabels: true,
        );

        expect(
          needsRebuild,
          true,
          reason: 'Horizontal->Grid layout change must trigger rebuild',
        );

        // Build both schemas and verify they're structurally different
        final horizontalSchema = builder.buildHorizontalLayout(
          bindings: bindings.toList(),
          showLabels: true,
          accentColor: '#4F6AF6',
        );
        final gridSchema = builder.buildGridLayout(
          bindings: bindings.toList(),
          showLabels: true,
          accentColor: '#4F6AF6',
        );

        // Verify different structure
        final hRows = horizontalSchema.children
            .where((e) => e.type == ElementType.row)
            .toList();
        final gRows = gridSchema.children
            .where((e) => e.type == ElementType.row)
            .toList();

        // Horizontal: single row or rows with 3 items
        // Grid: rows with 2 items
        if (hRows.isNotEmpty && gRows.isNotEmpty) {
          expect(
            hRows.first.children.length,
            isNot(equals(gRows.first.children.length)),
            reason:
                'Grid rows should have different item count than horizontal',
          );
        }
      },
    );

    test('grid to horizontal to grid switching works correctly', () {
      final bindings = {'node.batteryLevel', 'node.rssi', 'node.snr'};

      // Grid -> Horizontal
      final rebuild1 = requiresStructuralRebuild(
        oldTemplate: 'status',
        newTemplate: 'status',
        oldLayout: LayoutStyle.grid,
        newLayout: LayoutStyle.horizontal,
        oldBindings: bindings,
        newBindings: bindings,
        oldActions: {},
        newActions: {},
        oldShowLabels: true,
        newShowLabels: true,
      );
      expect(rebuild1, true, reason: 'Grid->Horizontal must trigger rebuild');

      // Horizontal -> Grid
      final rebuild2 = requiresStructuralRebuild(
        oldTemplate: 'status',
        newTemplate: 'status',
        oldLayout: LayoutStyle.horizontal,
        newLayout: LayoutStyle.grid,
        oldBindings: bindings,
        newBindings: bindings,
        oldActions: {},
        newActions: {},
        oldShowLabels: true,
        newShowLabels: true,
      );
      expect(rebuild2, true, reason: 'Horizontal->Grid must trigger rebuild');
    });

    test(
      'grid schema with odd number of bindings handles last row correctly',
      () {
        // 3 bindings should result in 2 rows: [2 items, 1 item]
        final schema = builder.buildGridLayout(
          bindings: ['node.batteryLevel', 'node.rssi', 'node.snr'],
          showLabels: true,
          accentColor: '#4F6AF6',
        );

        final rows = schema.children
            .where((e) => e.type == ElementType.row)
            .toList();
        expect(rows.length, 2, reason: 'Should have 2 rows for 3 items');
        expect(
          rows[0].children.length,
          2,
          reason: 'First row should have 2 items',
        );
        expect(
          rows[1].children.length,
          1,
          reason: 'Second row should have 1 item',
        );
      },
    );

    test('grid layout produces valid schema that can be rendered', () {
      final schema = builder.buildGridLayout(
        bindings: ['node.batteryLevel', 'node.rssi'],
        showLabels: true,
        accentColor: '#4F6AF6',
      );

      // Should not throw when converting to JSON and back
      final widgetSchema = WidgetSchema(name: 'Grid Test', root: schema);

      expect(() => widgetSchema.toJson(), returnsNormally);
      expect(
        () => WidgetSchema.fromJson(widgetSchema.toJson()),
        returnsNormally,
      );

      // Verify structure is valid
      final restored = WidgetSchema.fromJson(widgetSchema.toJson());
      expect(restored.root.type, ElementType.column);

      // Each row child should be either row or text
      for (final child in restored.root.children) {
        expect(
          [ElementType.row, ElementType.text].contains(child.type),
          true,
          reason: 'Grid children should be rows',
        );
      }
    });
  });
}
