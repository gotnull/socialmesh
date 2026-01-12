import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/mesh_globe.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:flutter/material.dart';

void main() {
  group('MeshGlobe Widget', () {
    // Note: Tests with enabled: true are skipped because CesiumJS WebView requires
    // a platform-specific WebView context that's not available in widget tests.

    testWidgets('renders when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MeshGlobe(enabled: false))),
      );

      // Should render SizedBox.shrink when disabled
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('accepts custom properties when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeshGlobe(
              enabled: false,
              baseColor: Color(0xFF1a1a2e),
              dotColor: Color(0xFF4a4a6a),
              markerColor: Color(0xFF42A5F5),
              connectionColor: Color(0xFF42A5F5),
              showConnections: true,
              autoRotateSpeed: 0.5,
            ),
          ),
        ),
      );

      expect(find.byType(MeshGlobe), findsOneWidget);
    });

    testWidgets('accepts nodes list when disabled', (tester) async {
      final nodes = [
        MeshNode(
          nodeNum: 1,
          longName: 'Test Node',
          latitude: -33.8688,
          longitude: 151.2093,
          avatarColor: 0xFF42A5F5,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MeshGlobe(enabled: false, nodes: nodes)),
        ),
      );

      expect(find.byType(MeshGlobe), findsOneWidget);
    });

    test('MeshNode filtering for position data', () {
      final nodesWithPosition = [
        MeshNode(
          nodeNum: 1,
          longName: 'Node A',
          latitude: -33.8688,
          longitude: 151.2093,
        ),
        MeshNode(nodeNum: 2, longName: 'Node B'),
        MeshNode(
          nodeNum: 3,
          longName: 'Node C',
          latitude: 40.7128,
          longitude: -74.0060,
        ),
      ];

      final filtered = nodesWithPosition.where((n) => n.hasPosition).toList();
      expect(filtered.length, 2);
      expect(filtered[0].nodeNum, 1);
      expect(filtered[1].nodeNum, 3);
    });

    test('MeshNode hasPosition works correctly', () {
      final nodeWithPos = MeshNode(
        nodeNum: 1,
        latitude: -33.8688,
        longitude: 151.2093,
      );
      final nodeWithoutPos = MeshNode(nodeNum: 2);
      final nodeWithPartialPos = MeshNode(nodeNum: 3, latitude: 10.0);

      expect(nodeWithPos.hasPosition, true);
      expect(nodeWithoutPos.hasPosition, false);
      expect(nodeWithPartialPos.hasPosition, false);
    });
  });
}
