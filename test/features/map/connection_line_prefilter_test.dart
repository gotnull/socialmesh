// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the connection-line prefilter's correctness contract: the screen
// may pass pairs that Vincenty later rejects (harmless, Vincenty is the
// decision function) but must NEVER reject a pair whose true distance is
// within the threshold. A false rejection would silently drop a visible
// connection line, changing rendered output.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/features/map/map_screen.dart';

// Mirrors _MapScreenState._calculateDistance exactly: latlong2's
// Distance() ROUNDS to whole kilometers by default, and that rounded
// value is what production compares against the threshold.
double _productionDecisionKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  if (lat1 == lat2 && lng1 == lng2) return 0.0;
  try {
    return const Distance().as(
      LengthUnit.Kilometer,
      LatLng(lat1, lng1),
      LatLng(lat2, lng2),
    );
  } catch (_) {
    return 0.0;
  }
}

double _unroundedVincentyKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  if (lat1 == lat2 && lng1 == lng2) return 0.0;
  try {
    return const Distance(
      roundResult: false,
    ).as(LengthUnit.Kilometer, LatLng(lat1, lng1), LatLng(lat2, lng2));
  } catch (_) {
    return 0.0;
  }
}

void main() {
  test('prefilter never rejects a pair Vincenty accepts (randomized)', () {
    final random = math.Random(424242);
    const maxKm = 15.0;
    var rejected = 0;
    var accepted = 0;

    for (var i = 0; i < 5000; i++) {
      // Cluster pairs around a random anchor so a meaningful share of
      // them land inside the 15 km threshold.
      final anchorLat = random.nextDouble() * 160 - 80;
      final anchorLng = random.nextDouble() * 360 - 180;
      final lat1 = anchorLat + (random.nextDouble() - 0.5) * 0.6;
      final lng1 = anchorLng + (random.nextDouble() - 0.5) * 0.6;
      final lat2 = anchorLat + (random.nextDouble() - 0.5) * 0.6;
      final lng2 = anchorLng + (random.nextDouble() - 0.5) * 0.6;

      final mayBeWithin = connectionPrefilterMayBeWithin(
        lat1,
        lng1,
        lat2,
        lng2,
        maxKm,
      );
      if (mayBeWithin) {
        accepted++;
        continue;
      }
      rejected++;
      final decisionKm = _productionDecisionKm(lat1, lng1, lat2, lng2);
      expect(
        decisionKm > maxKm,
        isTrue,
        reason:
            'Prefilter rejected ($lat1,$lng1)-($lat2,$lng2) but the '
            'production decision function measures '
            '${decisionKm.toStringAsFixed(3)} km <= $maxKm km. '
            'A false rejection drops a visible connection line.',
      );
    }
    // Sanity: the randomized sweep exercised both branches.
    expect(accepted, greaterThan(100));
    expect(rejected, greaterThan(100));
  });

  test('prefilter accepts in-range pairs at edge latitudes and the '
      'antimeridian', () {
    // Within ~1.5 km at high latitude.
    expect(
      connectionPrefilterMayBeWithin(78.0, 16.0, 78.01, 16.01, 15.0),
      isTrue,
    );
    // Within a few km straddling the antimeridian. The haversine screen
    // measures through the date line correctly via its trigonometric
    // form; a naive longitude-delta screen would reject this pair.
    expect(
      connectionPrefilterMayBeWithin(0.0, 179.99, 0.0, -179.99, 15.0),
      isTrue,
    );
    // Identical points are trivially in range.
    expect(connectionPrefilterMayBeWithin(45.0, 7.0, 45.0, 7.0, 15.0), isTrue);
  });

  test('prefilter rejects pairs that are far out of range', () {
    expect(
      connectionPrefilterMayBeWithin(45.0, 7.0, 46.0, 7.0, 15.0),
      isFalse,
      reason: 'One degree of latitude is ~111 km.',
    );
    expect(
      connectionPrefilterMayBeWithin(0.0, 0.0, 0.0, 1.0, 15.0),
      isFalse,
      reason: 'One degree of equatorial longitude is ~111 km.',
    );
  });

  test('haversine stays within 1% of Vincenty over random pairs', () {
    final random = math.Random(7);
    for (var i = 0; i < 2000; i++) {
      final lat1 = random.nextDouble() * 160 - 80;
      final lng1 = random.nextDouble() * 360 - 180;
      final lat2 = (lat1 + (random.nextDouble() - 0.5) * 2).clamp(-89.9, 89.9);
      final lng2 = lng1 + (random.nextDouble() - 0.5) * 2;
      final h = haversineKm(lat1, lng1, lat2, lng2.toDouble());
      final v = _unroundedVincentyKm(lat1, lng1, lat2, lng2.toDouble());
      if (v < 0.1) continue;
      expect(
        (h - v).abs() / v,
        lessThan(0.01),
        reason: 'haversine=$h vincenty=$v at ($lat1,$lng1)-($lat2,$lng2)',
      );
    }
  });
}
