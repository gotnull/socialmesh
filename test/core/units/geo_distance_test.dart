// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/core/units/geo_distance.dart';

void main() {
  // Roughly 400 m apart along a meridian (0.0036 deg of latitude).
  const a = LatLng(-37.8136, 144.9631);
  const b = LatLng(-37.8100, 144.9631);

  group('distanceKmBetween', () {
    test('keeps sub-kilometre resolution instead of rounding to 0 km', () {
      final km = distanceKmBetween(a, b);
      expect(km, greaterThan(0.35));
      expect(km, lessThan(0.45));
    });

    test('does not step in whole kilometres', () {
      // 1.3 km-ish: a whole-kilometre result would read 1.0 exactly.
      const c = LatLng(-37.8019, 144.9631);
      final km = distanceKmBetween(a, c);
      expect(km, greaterThan(1.25));
      expect(km, lessThan(1.35));
      expect(km, isNot(equals(1.0)));
    });

    test('identical points are zero', () {
      expect(distanceKmBetween(a, a), 0);
    });

    test('near-antipodal points do not throw', () {
      const antipode = LatLng(37.8136, -35.0369);
      expect(distanceKmBetween(a, antipode).isFinite, isTrue);
    });
  });

  group('distanceMetersBetween', () {
    test('agrees with the kilometre helper', () {
      final meters = distanceMetersBetween(a, b);
      expect(meters / 1000, closeTo(distanceKmBetween(a, b), 1e-9));
    });
  });
}
