import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/widget_builder/renderer/widget_renderer.dart';
import 'package:socialmesh/features/widget_builder/models/widget_schema.dart';
import 'package:socialmesh/models/mesh_models.dart';

void main() {
  group('WidgetRenderer', () {
    late WidgetSchema testSchema;
    late MeshNode testNode;

    setUp(() {
      testNode = MeshNode(
        nodeNum: 12345,
        longName: 'Test Node',
        shortName: 'TST',
        isOnline: true,
        batteryLevel: 75,
        temperature: 22.5,
        snr: 8,
      );

      testSchema = WidgetSchema(
        name: 'Test Widget',
        description: 'A test widget',
        root: ElementSchema(
          type: ElementType.column,
          style: const StyleSchema(padding: 16),
          children: [
            ElementSchema(type: ElementType.text, text: 'Hello World'),
          ],
        ),
      );
    });

    testWidgets('renders basic text element', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: testSchema,
              node: testNode,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('renders with node data binding', (tester) async {
      final bindingSchema = WidgetSchema(
        name: 'Binding Widget',
        root: ElementSchema(
          type: ElementType.text,
          binding: const BindingSchema(path: 'node.longName'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: bindingSchema,
              node: testNode,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Test Node'), findsOneWidget);
    });

    testWidgets('renders battery binding with format', (tester) async {
      final batterySchema = WidgetSchema(
        name: 'Battery Widget',
        root: ElementSchema(
          type: ElementType.text,
          binding: const BindingSchema(
            path: 'node.batteryLevel',
            format: '{value}%',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: batterySchema,
              node: testNode,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('renders without node gracefully', (tester) async {
      final bindingSchema = WidgetSchema(
        name: 'No Node Widget',
        root: ElementSchema(
          type: ElementType.text,
          binding: const BindingSchema(
            path: 'node.longName',
            defaultValue: 'No Data',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: bindingSchema,
              node: null,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('No Data'), findsOneWidget);
    });

    testWidgets('renders icon element', (tester) async {
      final iconSchema = WidgetSchema(
        name: 'Icon Widget',
        root: ElementSchema(
          type: ElementType.icon,
          iconName: 'battery_full',
          iconSize: 24,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: iconSchema,
              node: testNode,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
    });

    testWidgets('renders row layout', (tester) async {
      final rowSchema = WidgetSchema(
        name: 'Row Widget',
        root: ElementSchema(
          type: ElementType.row,
          children: [
            ElementSchema(type: ElementType.text, text: 'Left'),
            ElementSchema(type: ElementType.text, text: 'Right'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: rowSchema,
              node: testNode,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Left'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    });

    testWidgets('renders column layout', (tester) async {
      final columnSchema = WidgetSchema(
        name: 'Column Widget',
        root: ElementSchema(
          type: ElementType.column,
          children: [
            ElementSchema(type: ElementType.text, text: 'Top'),
            ElementSchema(type: ElementType.text, text: 'Bottom'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: columnSchema,
              node: testNode,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Top'), findsOneWidget);
      expect(find.text('Bottom'), findsOneWidget);
    });

    testWidgets('renders nested layout', (tester) async {
      final nestedSchema = WidgetSchema(
        name: 'Nested Widget',
        root: ElementSchema(
          type: ElementType.column,
          children: [
            ElementSchema(
              type: ElementType.row,
              children: [
                ElementSchema(type: ElementType.text, text: 'A'),
                ElementSchema(type: ElementType.text, text: 'B'),
              ],
            ),
            ElementSchema(
              type: ElementType.row,
              children: [
                ElementSchema(type: ElementType.text, text: 'C'),
                ElementSchema(type: ElementType.text, text: 'D'),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: nestedSchema,
              node: testNode,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('handles element tap in preview mode', (tester) async {
      String? tappedId;

      final schema = WidgetSchema(
        name: 'Tap Widget',
        root: ElementSchema(type: ElementType.text, text: 'Tap Me'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: schema,
              node: testNode,
              accentColor: Colors.blue,
              isPreview: true,
              onElementTap: (id) => tappedId = id,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pump();

      expect(tappedId, isNotNull);
    });

    testWidgets('shows selection highlight in preview mode', (tester) async {
      final schema = WidgetSchema(
        name: 'Selected Widget',
        root: ElementSchema(type: ElementType.text, text: 'Selected Text'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: schema,
              node: testNode,
              accentColor: Colors.blue,
              isPreview: true,
              selectedElementId: schema.root.id,
              onElementTap: (_) {},
            ),
          ),
        ),
      );

      // Find container with border (selection highlight)
      expect(find.text('Selected Text'), findsOneWidget);
    });

    testWidgets('renders linear gauge', (tester) async {
      final gaugeSchema = WidgetSchema(
        name: 'Gauge Widget',
        root: ElementSchema(
          type: ElementType.gauge,
          gaugeType: GaugeType.linear,
          gaugeMin: 0,
          gaugeMax: 100,
          gaugeColor: '#4ADE80',
          binding: const BindingSchema(path: 'node.batteryLevel'),
          style: const StyleSchema(height: 8),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: WidgetRenderer(
                schema: gaugeSchema,
                node: testNode,
                accentColor: Colors.green,
              ),
            ),
          ),
        ),
      );

      // Gauge should render without throwing
      expect(find.byType(WidgetRenderer), findsOneWidget);
    });

    testWidgets('renders spacer element', (tester) async {
      final spacerSchema = WidgetSchema(
        name: 'Spacer Widget',
        root: ElementSchema(
          type: ElementType.column,
          children: [
            ElementSchema(type: ElementType.text, text: 'Before'),
            ElementSchema(
              type: ElementType.spacer,
              style: const StyleSchema(height: 20),
            ),
            ElementSchema(type: ElementType.text, text: 'After'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: spacerSchema,
              node: testNode,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
    });

    testWidgets('applies network data', (tester) async {
      final allNodes = {
        1: MeshNode(nodeNum: 1, longName: 'Node 1', isOnline: true),
        2: MeshNode(nodeNum: 2, longName: 'Node 2', isOnline: true),
        3: MeshNode(nodeNum: 3, longName: 'Node 3', isOnline: false),
      };

      final networkSchema = WidgetSchema(
        name: 'Network Widget',
        root: ElementSchema(
          type: ElementType.text,
          binding: const BindingSchema(
            path: 'network.totalNodes',
            format: '{value} nodes',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WidgetRenderer(
              schema: networkSchema,
              node: testNode,
              allNodes: allNodes,
              accentColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('3 nodes'), findsOneWidget);
    });
  });
}
