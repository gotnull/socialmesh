// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/aether/models/aether_flight.dart';
import 'package:socialmesh/features/aether/providers/aether_flight_matcher_provider.dart';
import 'package:socialmesh/features/aether/widgets/aether_flight_match_card.dart';
import 'package:socialmesh/models/mesh_models.dart';

AetherFlightMatch _makeMatch({
  String flightNumber = 'UA123',
  String departure = 'LAX',
  String arrival = 'JFK',
  String nodeId = '!a1b2c3d4',
  int nodeNum = 0xa1b2c3d4,
  String nodeName = 'SkyNode',
  int? rssi = -75,
  int? snr = 8,
}) {
  final now = DateTime.now();
  return AetherFlightMatch(
    flight: AetherFlight(
      id: 'test-flight',
      nodeId: nodeId,
      nodeName: nodeName,
      flightNumber: flightNumber,
      departure: departure,
      arrival: arrival,
      scheduledDeparture: now.subtract(const Duration(hours: 1)),
      scheduledArrival: now.add(const Duration(hours: 4)),
      userId: 'user-1',
      isActive: true,
      createdAt: now,
      receptionCount: 3,
    ),
    node: MeshNode(
      nodeNum: nodeNum,
      userId: nodeId,
      longName: nodeName,
      rssi: rssi,
      snr: snr,
      lastHeard: now,
    ),
    detectedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AetherFlightMatchCard', () {
    testWidgets('displays flight number', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AetherFlightMatchCard(
              match: _makeMatch(flightNumber: 'DL456'),
            ),
          ),
        ),
      );

      expect(find.text('DL456'), findsOneWidget);
    });

    testWidgets('displays departure and arrival airports', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AetherFlightMatchCard(
              match: _makeMatch(departure: 'SFO', arrival: 'ORD'),
            ),
          ),
        ),
      );

      expect(find.text('SFO'), findsOneWidget);
      expect(find.text('ORD'), findsOneWidget);
    });

    testWidgets('displays IN FLIGHT badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AetherFlightMatchCard(match: _makeMatch())),
        ),
      );

      expect(find.text('IN FLIGHT'), findsOneWidget);
    });

    testWidgets('displays node name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AetherFlightMatchCard(
              match: _makeMatch(nodeName: 'MountainRelay'),
            ),
          ),
        ),
      );

      expect(find.text('MountainRelay'), findsOneWidget);
    });

    testWidgets('displays RSSI when available', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AetherFlightMatchCard(match: _makeMatch(rssi: -82)),
          ),
        ),
      );

      expect(find.text('-82 dBm'), findsOneWidget);
    });

    testWidgets('displays SNR when available', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AetherFlightMatchCard(match: _makeMatch(snr: 12)),
          ),
        ),
      );

      expect(find.text('SNR 12'), findsOneWidget);
    });

    testWidgets('hides RSSI and SNR when null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AetherFlightMatchCard(
              match: _makeMatch(rssi: null, snr: null),
            ),
          ),
        ),
      );

      expect(find.text('dBm'), findsNothing);
      expect(find.text('SNR'), findsNothing);
    });

    testWidgets('shows report CTA text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AetherFlightMatchCard(match: _makeMatch())),
        ),
      );

      expect(find.text('Tap to report your reception'), findsOneWidget);
    });

    testWidgets('shows flight icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AetherFlightMatchCard(match: _makeMatch())),
        ),
      );

      expect(find.byIcon(Icons.flight), findsOneWidget);
    });
  });
}
