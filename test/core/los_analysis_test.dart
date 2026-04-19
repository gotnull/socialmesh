// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/los_analysis.dart';

void main() {
  group('evaluateLos', () {
    test('returns unknown when altA is null', () {
      final result = evaluateLos(altA: null, altB: 100, distanceMeters: 1000);
      expect(result.verdict, LosVerdict.unknown);
    });

    test('returns unknown when altB is null', () {
      final result = evaluateLos(altA: 100, altB: null, distanceMeters: 1000);
      expect(result.verdict, LosVerdict.unknown);
    });

    test('returns unknown when both altitudes are null', () {
      final result = evaluateLos(altA: null, altB: null, distanceMeters: 1000);
      expect(result.verdict, LosVerdict.unknown);
    });

    test('short distance at high altitude is clear', () {
      // Two nodes at 500m altitude, 1km apart — trivially clear
      final result = evaluateLos(altA: 500, altB: 500, distanceMeters: 1000);
      expect(result.verdict, LosVerdict.clear);
      expect(result.earthBulgeMeters, greaterThan(0));
      expect(result.fresnelRadiusMeters, greaterThan(0));
      expect(result.actualClearanceMeters, greaterThan(0));
    });

    test('very long distance at sea level is obstructed', () {
      // Two nodes at 2m altitude, 200km apart — earth curvature blocks
      final result = evaluateLos(altA: 2, altB: 2, distanceMeters: 200000);
      expect(result.verdict, LosVerdict.obstructed);
      expect(result.actualClearanceMeters, lessThan(0));
    });

    test('earth bulge formula is correct for known distance', () {
      // Earth bulge at midpoint for 10km path with 4/3 radius model:
      // h = d² / (8 × R_eff) = 10000² / (8 × 6371000 × 4/3)
      // = 1e8 / 67,957,333 ≈ 1.47m
      final result = evaluateLos(altA: 1000, altB: 1000, distanceMeters: 10000);
      expect(result.earthBulgeMeters, closeTo(1.47, 0.05));
    });

    test('fresnel radius is reasonable for 10km at 906MHz', () {
      // λ = 299792458 / 906e6 ≈ 0.331m
      // F1 = sqrt(λ × d/2 × d/2 / d) = sqrt(λ × d / 4)
      // = sqrt(0.331 × 10000 / 4) ≈ sqrt(827.5) ≈ 28.8m
      final result = evaluateLos(altA: 1000, altB: 1000, distanceMeters: 10000);
      expect(result.fresnelRadiusMeters, closeTo(28.8, 1.0));
    });

    test('required clearance is 60% of Fresnel radius', () {
      final result = evaluateLos(altA: 1000, altB: 1000, distanceMeters: 10000);
      expect(
        result.requiredClearanceMeters,
        closeTo(result.fresnelRadiusMeters * 0.6, 0.01),
      );
    });

    test('distanceMeters is preserved in result', () {
      final result = evaluateLos(altA: 100, altB: 200, distanceMeters: 5000);
      expect(result.distanceMeters, 5000);
    });

    test('asymmetric altitudes uses midline height correctly', () {
      // Node A at 0m, Node B at 1000m, 50km apart
      // Midline = 500m. Earth bulge at midpoint for 50km:
      // h = 50000² / (8 × 8494667) ≈ 36.8m
      // 500 - 36.8 = 463.2 clearance → should be clear
      final result = evaluateLos(altA: 0, altB: 1000, distanceMeters: 50000);
      expect(result.verdict, isNot(LosVerdict.obstructed));
      expect(result.actualClearanceMeters, greaterThan(0));
    });
  });

  group('calculateBearing', () {
    test('north bearing is approximately 0', () {
      // Point A to point B directly north
      final bearing = calculateBearing(0, 0, 1, 0);
      expect(bearing, closeTo(0, 0.1));
    });

    test('east bearing is approximately 90', () {
      final bearing = calculateBearing(0, 0, 0, 1);
      expect(bearing, closeTo(90, 0.1));
    });

    test('south bearing is approximately 180', () {
      final bearing = calculateBearing(1, 0, 0, 0);
      expect(bearing, closeTo(180, 0.1));
    });

    test('west bearing is approximately 270', () {
      final bearing = calculateBearing(0, 1, 0, 0);
      expect(bearing, closeTo(270, 0.1));
    });

    test('northeast bearing is approximately 45', () {
      // Small distances to avoid great-circle distortion
      final bearing = calculateBearing(0, 0, 0.01, 0.01);
      expect(bearing, closeTo(45, 1.0));
    });

    test('bearing is always in [0, 360)', () {
      final bearing = calculateBearing(10, 20, -10, -20);
      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });

    test('same point returns 0', () {
      final bearing = calculateBearing(45.0, 13.0, 45.0, 13.0);
      expect(bearing, closeTo(0, 0.01));
    });
  });

  group('formatBearingCardinal', () {
    test('0 degrees is N', () {
      expect(formatBearingCardinal(0), 'N');
    });

    test('90 degrees is E', () {
      expect(formatBearingCardinal(90), 'E');
    });

    test('180 degrees is S', () {
      expect(formatBearingCardinal(180), 'S');
    });

    test('270 degrees is W', () {
      expect(formatBearingCardinal(270), 'W');
    });

    test('45 degrees is NE', () {
      expect(formatBearingCardinal(45), 'NE');
    });

    test('135 degrees is SE', () {
      expect(formatBearingCardinal(135), 'SE');
    });

    test('225 degrees is SW', () {
      expect(formatBearingCardinal(225), 'SW');
    });

    test('315 degrees is NW', () {
      expect(formatBearingCardinal(315), 'NW');
    });

    test('359 degrees is N', () {
      expect(formatBearingCardinal(359), 'N');
    });

    test('22 degrees is NNE', () {
      expect(formatBearingCardinal(22), 'NNE');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // evaluateLosFromProfile
  // ─────────────────────────────────────────────────────────────────────────

  /// Helper: builds a flat-terrain sample list of [n] points over [distanceM]
  /// meters, all at [terrainElevation] meters.
  List<
    ({
      double distanceMeters,
      double latitude,
      double longitude,
      double? elevationMeters,
    })
  >
  flatSamples(int n, double distanceM, double terrainElevation) {
    return List.generate(n, (i) {
      final frac = n > 1 ? i / (n - 1) : 0.0;
      return (
        distanceMeters: frac * distanceM,
        latitude: 0.0 + frac * 1.0,
        longitude: 0.0,
        elevationMeters: terrainElevation,
      );
    });
  }

  group('evaluateLosFromProfile', () {
    test('returns unknown verdict when altAMeters is null', () {
      final samples = flatSamples(10, 10000, 100.0);
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: null,
        altBMeters: 200,
      );
      expect(result.verdict, LosVerdict.unknown);
      expect(result.hasAltitudeData, isFalse);
    });

    test('returns unknown verdict when altBMeters is null', () {
      final samples = flatSamples(10, 10000, 100.0);
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 200,
        altBMeters: null,
      );
      expect(result.verdict, LosVerdict.unknown);
      expect(result.hasAltitudeData, isFalse);
    });

    test('returns unknown verdict for empty sample list', () {
      final result = evaluateLosFromProfile(
        samples: [],
        altAMeters: 100,
        altBMeters: 100,
      );
      expect(result.verdict, LosVerdict.unknown);
    });

    test('clear path — antennas high above flat terrain', () {
      // Antennas at 500m altitude, terrain at 10m — trivially clear.
      final samples = flatSamples(20, 5000, 10.0);
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 500,
        altBMeters: 500,
      );
      expect(result.verdict, LosVerdict.clear);
      expect(result.hasAltitudeData, isTrue);
      expect(result.worstClearanceMeters, greaterThan(0));
      expect(result.additionalClearanceNeededMeters, equals(0.0));
    });

    test('obstructed path — terrain peak higher than LOS line', () {
      // Antennas at 100m altitude, terrain spike to 200m at midpoint.
      final n = 11;
      final dist = 10000.0;
      final samples = List.generate(n, (i) {
        final frac = i / (n - 1);
        // Terrain peaks at the midpoint (i == 5).
        final elevationM = i == 5 ? 250.0 : 50.0;
        return (
          distanceMeters: frac * dist,
          latitude: frac,
          longitude: 0.0,
          elevationMeters: elevationM,
        );
      });
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 100,
        altBMeters: 100,
      );
      expect(result.verdict, LosVerdict.obstructed);
      expect(result.worstClearanceMeters, isNotNull);
      expect(result.worstClearanceMeters! < 0, isTrue);
      expect(result.additionalClearanceNeededMeters, greaterThan(0));
    });

    test('per-sample arrays have same length as input samples', () {
      final samples = flatSamples(30, 15000, 50.0);
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 200,
        altBMeters: 200,
      );
      expect(result.perSampleClearanceMeters, hasLength(30));
      expect(result.perSampleFresnelRadiusMeters, hasLength(30));
      expect(result.losLineHeightsMeters, hasLength(30));
    });

    test('LOS line is linearly interpolated between endpoints', () {
      final samples = flatSamples(3, 10000, 0.0);
      // altA = 0, altB = 100 → midpoint LOS = 50
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 0,
        altBMeters: 100,
      );
      expect(result.losLineHeightsMeters[0], closeTo(0.0, 0.01));
      expect(result.losLineHeightsMeters[1], closeTo(50.0, 0.01));
      expect(result.losLineHeightsMeters[2], closeTo(100.0, 0.01));
    });

    test('Fresnel radius is 0 at endpoints', () {
      final samples = flatSamples(5, 10000, 0.0);
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 500,
        altBMeters: 500,
      );
      // At distance 0 and distance D, F1 = sqrt(λ × 0 × D / D) = 0.
      expect(result.perSampleFresnelRadiusMeters.first, closeTo(0.0, 0.01));
      expect(result.perSampleFresnelRadiusMeters.last, closeTo(0.0, 0.01));
    });

    test('Fresnel radius is largest at midpoint', () {
      final samples = flatSamples(11, 10000, 0.0);
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 500,
        altBMeters: 500,
      );
      final radii = result.perSampleFresnelRadiusMeters;
      final midIdx = radii.length ~/ 2;
      for (var i = 0; i < radii.length; i++) {
        expect(radii[midIdx], greaterThanOrEqualTo(radii[i]));
      }
    });

    test('insufficient data — single sample returns unknown', () {
      final samples = flatSamples(1, 0, 100.0);
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 200,
        altBMeters: 200,
      );
      // With 1 sample, totalDist == 0 and Fresnel radius is 0 everywhere.
      // No actual obstruction, so verdict should be clear (all clearances
      // will be LOS line height minus terrain height = 200 - 100 = 100 > 0).
      expect(result.verdict, LosVerdict.clear);
    });

    test('null terrain elevation treated as 0m', () {
      final samples = [
        (
          distanceMeters: 0.0,
          latitude: 0.0,
          longitude: 0.0,
          elevationMeters: null as double?,
        ),
        (
          distanceMeters: 5000.0,
          latitude: 0.5,
          longitude: 0.0,
          elevationMeters: null as double?,
        ),
        (
          distanceMeters: 10000.0,
          latitude: 1.0,
          longitude: 0.0,
          elevationMeters: null as double?,
        ),
      ];
      // Should not throw; null elevation defaults to 0.
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 100,
        altBMeters: 100,
      );
      expect(result.verdict, isA<LosVerdict>());
    });

    test('worst point index points to lowest clearance', () {
      final n = 11;
      final dist = 10000.0;
      // Build profile where the lowest clearance is at index 3.
      final samples = List.generate(n, (i) {
        final frac = i / (n - 1);
        final elevation = i == 3 ? 300.0 : 10.0;
        return (
          distanceMeters: frac * dist,
          latitude: frac,
          longitude: 0.0,
          elevationMeters: elevation,
        );
      });
      final result = evaluateLosFromProfile(
        samples: samples,
        altAMeters: 100,
        altBMeters: 100,
      );
      expect(result.worstPointIndex, isNotNull);
      // The worst clearance should come from the spike at index 3.
      final worstClearanceAtIdx3 = result.perSampleClearanceMeters[3];
      expect(result.worstClearanceMeters, closeTo(worstClearanceAtIdx3, 0.001));
    });
  });
}
