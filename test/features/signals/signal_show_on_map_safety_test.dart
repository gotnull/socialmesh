// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Boundary regression for the signal "show on map" path.
//
// Production Crashlytics traced a fatal `LatLng is not finite` to
// `TileRangeCalculator._calculatePixelBounds` inside flutter_map. The
// only unguarded path that could push a non-finite LatLng into
// `MapOptions.initialCenter` was the location chip in
// `lib/features/signals/widgets/signal_card.dart`, which constructed
// `LatLng(signal.location!.latitude, signal.location!.longitude)`
// without validation.
//
// The fix routes that construction through `safeLatLng`. When the
// helper returns null the card now logs + shows a "Location
// unavailable" snackbar and skips navigation entirely.
//
// This test pins the contract `_openMap` now relies on: corrupted
// persisted PostLocation values (NaN, infinity, or out of WGS-84
// range) MUST cause `safeLatLng` to return null. Combined with the
// existing widget code, this guarantees the bad coordinate never
// reaches flutter_map.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/safe_lat_lng.dart';
import 'package:socialmesh/models/social.dart';

PostLocation _location(double lat, double lng) =>
    PostLocation(latitude: lat, longitude: lng);

void main() {
  group('signal_card _openMap boundary helper', () {
    test('NaN latitude is rejected', () {
      final loc = _location(double.nan, 0);
      expect(safeLatLng(loc.latitude, loc.longitude), isNull);
    });

    test('NaN longitude is rejected', () {
      final loc = _location(0, double.nan);
      expect(safeLatLng(loc.latitude, loc.longitude), isNull);
    });

    test('infinity is rejected', () {
      final loc = _location(double.infinity, 0);
      expect(safeLatLng(loc.latitude, loc.longitude), isNull);
    });

    test('out-of-range latitude is rejected', () {
      final loc = _location(95.0, 0);
      expect(safeLatLng(loc.latitude, loc.longitude), isNull);
    });

    test('out-of-range longitude is rejected', () {
      final loc = _location(0, -200.0);
      expect(safeLatLng(loc.latitude, loc.longitude), isNull);
    });

    test('finite WGS-84 coordinates produce a usable LatLng', () {
      final loc = _location(-33.8688, 151.2093);
      final point = safeLatLng(loc.latitude, loc.longitude);
      expect(point, isNotNull);
      expect(point!.latitude, -33.8688);
      expect(point.longitude, 151.2093);
    });
  });
}
