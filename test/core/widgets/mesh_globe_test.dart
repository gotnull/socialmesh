import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/mesh_globe.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:flutter/material.dart';

void main() {
  group('GlobeNodeMarker', () {
    test('fromNode creates marker with correct values', () {
      final node = MeshNode(
        nodeNum: 123,
        longName: 'Test Node',
        latitude: -33.8688,
        longitude: 151.2093,
        avatarColor: 0xFF42A5F5,
        isOnline: true,
      );

      final marker = GlobeNodeMarker.fromNode(node);

      expect(marker.nodeNum, 123);
      expect(marker.name, 'Test Node');
      expect(marker.latitude, -33.8688);
      expect(marker.longitude, 151.2093);
      expect(marker.color, const Color(0xFF42A5F5));
      expect(marker.isOnline, true);
    });

    test('fromNode uses displayName when longName is null', () {
      final node = MeshNode(
        nodeNum: 456,
        shortName: 'SHORT',
        latitude: 40.7128,
        longitude: -74.0060,
      );

      final marker = GlobeNodeMarker.fromNode(node);

      expect(marker.name, 'SHORT');
    });

    test('fromNode handles missing position', () {
      final node = MeshNode(nodeNum: 789, longName: 'No Position Node');

      final marker = GlobeNodeMarker.fromNode(node);

      expect(marker.latitude, 0);
      expect(marker.longitude, 0);
    });

    test('fromNode uses default color when avatarColor is null', () {
      final node = MeshNode(nodeNum: 123, latitude: 0.0, longitude: 0.0);

      final marker = GlobeNodeMarker.fromNode(node);

      expect(marker.color, const Color(0xFF42A5F5));
    });
  });

  group('GlobeConnection', () {
    test('creates connection between two markers', () {
      final from = GlobeNodeMarker(
        nodeNum: 1,
        name: 'Node A',
        latitude: -33.8688,
        longitude: 151.2093,
        color: Colors.blue,
      );
      final to = GlobeNodeMarker(
        nodeNum: 2,
        name: 'Node B',
        latitude: 40.7128,
        longitude: -74.0060,
        color: Colors.red,
      );

      final connection = GlobeConnection(from: from, to: to, distance: 15989.0);

      expect(connection.from.nodeNum, 1);
      expect(connection.to.nodeNum, 2);
      expect(connection.distance, 15989.0);
    });

    test('distance is optional', () {
      final from = GlobeNodeMarker(
        nodeNum: 1,
        name: 'Node A',
        latitude: 0,
        longitude: 0,
        color: Colors.blue,
      );
      final to = GlobeNodeMarker(
        nodeNum: 2,
        name: 'Node B',
        latitude: 10,
        longitude: 10,
        color: Colors.red,
      );

      final connection = GlobeConnection(from: from, to: to);

      expect(connection.distance, null);
    });
  });

  group('MeshGlobe Widget', () {
    testWidgets('renders with empty markers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MeshGlobe(enabled: true, markers: [])),
        ),
      );

      // Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MeshGlobe(enabled: false))),
      );

      // Should render nothing when disabled
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('accepts custom colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeshGlobe(
              enabled: true,
              baseColor: Color(0xFF1a1a2e),
              dotColor: Color(0xFF4a4a6a),
              markerColor: Color(0xFF42A5F5),
              connectionColor: Color(0xFF42A5F5),
            ),
          ),
        ),
      );

      // Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('accepts markers list', (tester) async {
      final markers = [
        const GlobeNodeMarker(
          nodeNum: 1,
          name: 'Test Node',
          latitude: -33.8688,
          longitude: 151.2093,
          color: Color(0xFF42A5F5),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MeshGlobe(enabled: true, markers: markers)),
        ),
      );

      expect(find.byType(MeshGlobe), findsOneWidget);
    });
  });
}
