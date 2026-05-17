// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression for `FlightRouteMap`'s live plane marker.
//
// Aviation tracker feeds can produce malformed `FlightPosition`
// records with NaN / infinite coordinates. Before the fix the plane
// marker was constructed unconditionally as
// `Marker(point: LatLng(position.latitude, position.longitude), ...)`
// — the surrounding `finiteMarkers([...])` wrapper filtered the bad
// marker out at the layer level, but the construction itself is now
// suppressed earlier (and logged) via `_isFiniteFlightPosition`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/aether/models/aether_flight.dart';
import 'package:socialmesh/features/aether/widgets/flight_route_map.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme(AccentColors.magenta),
    home: Scaffold(body: child),
  );
}

FlightPosition _position(double lat, double lng) => FlightPosition(
  callsign: 'TEST123',
  latitude: lat,
  longitude: lng,
  altitude: 10000,
  velocity: 250,
  heading: 90,
  onGround: false,
  lastUpdate: DateTime(2026, 5, 17, 12),
);

void main() {
  testWidgets(
    'NaN livePosition drops the plane marker without crashing the map',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlightRouteMap(
            departure: 'SYD',
            arrival: 'LAX',
            livePosition: _position(double.nan, double.nan),
            isActive: true,
            height: 240,
          ),
        ),
      );

      await tester.pump();

      // No plane Icon should be rendered when the live position is
      // non-finite. Airport markers do not use `Icons.flight`, so the
      // assertion is unambiguous.
      expect(find.byIcon(Icons.flight), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Infinite livePosition drops the plane marker without crashing the map',
    (tester) async {
      await tester.pumpWidget(
        _wrap(
          FlightRouteMap(
            departure: 'SYD',
            arrival: 'LAX',
            livePosition: _position(double.infinity, 0),
            isActive: true,
            height: 240,
          ),
        ),
      );

      await tester.pump();

      expect(find.byIcon(Icons.flight), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Finite livePosition renders the plane marker', (tester) async {
    await tester.pumpWidget(
      _wrap(
        FlightRouteMap(
          departure: 'SYD',
          arrival: 'LAX',
          livePosition: _position(0.0, -150.0),
          isActive: true,
          height: 240,
        ),
      ),
    );

    await tester.pump();

    // flutter_map may rebuild the marker child more than once during a
    // single pump (positioning + repaint boundary), so accept any
    // non-zero count — the regression we care about is the NaN-case
    // findsNothing.
    expect(find.byIcon(Icons.flight), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });
}
