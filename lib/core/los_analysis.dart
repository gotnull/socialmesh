// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math' as math;

/// Result of a Line-of-Sight analysis between two geographic points.
///
/// Uses earth curvature + Fresnel zone clearance to estimate whether
/// a direct RF path exists. This is a geometric approximation that does
/// NOT account for terrain, buildings, or vegetation obstructions.
/// It only checks whether the earth's curvature itself would block the
/// signal path and whether the first Fresnel zone has adequate clearance.
///
/// Accuracy: Good for flat/ocean paths. Optimistic for hilly or urban
/// terrain because ground obstacles are not modelled. A "Clear" result
/// means the geometry is favorable but does NOT guarantee actual RF
/// connectivity.
class LosResult {
  /// Overall verdict.
  final LosVerdict verdict;

  /// Earth curvature obstruction height at the midpoint of the path (meters).
  /// Positive means the earth bulges into the path.
  final double earthBulgeMeters;

  /// First Fresnel zone radius at the midpoint (meters) for 906 MHz.
  final double fresnelRadiusMeters;

  /// Required clearance (0.6 × F1) at midpoint (meters).
  final double requiredClearanceMeters;

  /// Actual clearance above earth bulge at midpoint (meters).
  /// Negative means the path is obstructed by earth curvature.
  final double actualClearanceMeters;

  /// Great-circle distance between the two points (meters).
  final double distanceMeters;

  const LosResult({
    required this.verdict,
    required this.earthBulgeMeters,
    required this.fresnelRadiusMeters,
    required this.requiredClearanceMeters,
    required this.actualClearanceMeters,
    required this.distanceMeters,
  });
}

/// LOS analysis verdict.
enum LosVerdict {
  /// Clearance exceeds 60% of the first Fresnel zone — strong path.
  clear,

  /// Some clearance exists but less than 60% Fresnel — marginal path.
  marginal,

  /// Earth curvature alone obstructs the direct path.
  obstructed,

  /// Cannot compute (missing altitude data).
  unknown,
}

/// Evaluate line-of-sight between two geographic points.
///
/// Parameters:
///   [altA] / [altB] — altitude in meters above mean sea level.
///   [distanceMeters] — great-circle distance between the two points.
///   [frequencyMhz] — operating frequency (default 906 MHz for LoRa US).
///
/// Uses the standard 4/3 earth radius model for atmospheric refraction.
///
/// Returns [LosResult] with [LosVerdict.unknown] if either altitude is null.
LosResult evaluateLos({
  required int? altA,
  required int? altB,
  required double distanceMeters,
  double frequencyMhz = 906.0,
}) {
  if (altA == null || altB == null) {
    return const LosResult(
      verdict: LosVerdict.unknown,
      earthBulgeMeters: 0,
      fresnelRadiusMeters: 0,
      requiredClearanceMeters: 0,
      actualClearanceMeters: 0,
      distanceMeters: 0,
    );
  }

  // Effective earth radius with 4/3 refraction model
  const double earthRadius = 6371000.0; // meters
  const double kFactor = 4.0 / 3.0;
  final double effectiveRadius = earthRadius * kFactor;

  final double d = distanceMeters;

  // Earth bulge at midpoint: h = d² / (8 × R_eff)
  // where d is the total path distance
  final double earthBulge = (d * d) / (8.0 * effectiveRadius);

  // First Fresnel zone radius at midpoint:
  // F1 = sqrt(λ × d1 × d2 / d) where d1 = d2 = d/2 at midpoint
  // λ = c / f
  final double wavelength = 299792458.0 / (frequencyMhz * 1e6);
  final double d1 = d / 2.0;
  final double d2 = d / 2.0;
  final double fresnelRadius = math.sqrt(wavelength * d1 * d2 / d);

  // Required clearance: 60% of first Fresnel zone
  final double requiredClearance = 0.6 * fresnelRadius;

  // Line-of-sight height at midpoint (interpolated between altA and altB)
  final double midLineHeight = (altA + altB) / 2.0;

  // Actual clearance = midline height - earth bulge
  final double actualClearance = midLineHeight - earthBulge;

  // Determine verdict
  LosVerdict verdict;

  if (actualClearance < 0) {
    verdict = LosVerdict.obstructed;
  } else if (actualClearance >= requiredClearance + earthBulge) {
    verdict = LosVerdict.clear;
  } else {
    verdict = LosVerdict.marginal;
  }

  return LosResult(
    verdict: verdict,
    earthBulgeMeters: earthBulge,
    fresnelRadiusMeters: fresnelRadius,
    requiredClearanceMeters: requiredClearance,
    actualClearanceMeters: actualClearance,
    distanceMeters: d,
  );
}

/// Calculate bearing (initial heading) from point A to point B in degrees.
///
/// Returns a value in the range [0, 360).
double calculateBearing(
  double lat1Deg,
  double lon1Deg,
  double lat2Deg,
  double lon2Deg,
) {
  final lat1 = lat1Deg * math.pi / 180;
  final lat2 = lat2Deg * math.pi / 180;
  final dLon = (lon2Deg - lon1Deg) * math.pi / 180;

  final y = math.sin(dLon) * math.cos(lat2);
  final x =
      math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

  final bearing = math.atan2(y, x) * 180 / math.pi;
  return (bearing + 360) % 360;
}

/// Format a bearing in degrees to a cardinal direction string.
///
/// E.g. 0° → "N", 45° → "NE", 180° → "S", 270° → "W".
String formatBearingCardinal(double degrees) {
  const directions = [
    'N',
    'NNE',
    'NE',
    'ENE',
    'E',
    'ESE',
    'SE',
    'SSE',
    'S',
    'SSW',
    'SW',
    'WSW',
    'W',
    'WNW',
    'NW',
    'NNW',
  ];
  final index = ((degrees + 11.25) / 22.5).floor() % 16;
  return directions[index];
}

// ---------------------------------------------------------------------------
// Terrain-aware LOS analysis
// ---------------------------------------------------------------------------

/// Result of a terrain-profile LOS analysis.
///
/// Unlike [LosResult], which is geometry-only, this result incorporates
/// real terrain elevation from a sampled profile.
class TerrainLosResult {
  /// Overall verdict based on real terrain clearance.
  final LosVerdict verdict;

  /// Per-sample clearance values (meters above terrain). Negative = obstructed.
  /// Same length as the input samples.
  final List<double> perSampleClearanceMeters;

  /// First Fresnel zone radius at each sample point (meters).
  /// Same length as the input samples.
  final List<double> perSampleFresnelRadiusMeters;

  /// LOS line height at each sample point (meters above sea level).
  /// Same length as the input samples.
  final List<double> losLineHeightsMeters;

  /// Index of the worst obstruction point (lowest clearance), or null.
  final int? worstPointIndex;

  /// Clearance at the worst point (negative if obstructed), or null.
  final double? worstClearanceMeters;

  /// Minimum additional height required at the worst obstruction to achieve
  /// 60 % Fresnel clearance. Zero if path is already clear.
  final double additionalClearanceNeededMeters;

  /// Whether endpoint altitude data was provided.
  /// If false, LOS-line-dependent fields are meaningless and the UI should
  /// skip rendering the LOS line and Fresnel band.
  final bool hasAltitudeData;

  const TerrainLosResult({
    required this.verdict,
    required this.perSampleClearanceMeters,
    required this.perSampleFresnelRadiusMeters,
    required this.losLineHeightsMeters,
    required this.worstPointIndex,
    required this.worstClearanceMeters,
    required this.additionalClearanceNeededMeters,
    required this.hasAltitudeData,
  });
}

/// Analyse line-of-sight over a real terrain profile.
///
/// Parameters:
///   [samples] — ordered elevation samples from [ElevationService].
///     Each sample must have a non-null [elevationMeters]; samples with
///     null elevation are treated as sea level (0 m) to avoid crashing.
///   [altAMeters] / [altBMeters] — altitude of endpoint A / B in meters
///     above mean sea level. These are the antenna heights above terrain
///     (or sea level where terrain = 0). When null, the LOS line and
///     Fresnel analysis are skipped; the method returns
///     [LosVerdict.unknown] and [hasAltitudeData] == false.
///   [frequencyMhz] — operating frequency (default 906 MHz for LoRa US).
///
/// Assumptions:
///   - Antenna heights are given as absolute elevations (AMSL), matching the
///     GPS altitude reported by Meshtastic nodes. If you have antenna height
///     above ground, add terrain elevation at the endpoint.
///   - The LOS line is a straight line (in height space) between altA and altB.
///     This ignores atmospheric refraction beyond the WGS-84 ellipsoid, which
///     is acceptable for paths under ~100 km.
///   - The 4/3 earth radius refraction model is NOT applied here; terrain data
///     already absorbs the effective curvature. The Fresnel radius calculation
///     uses the actual great-circle distance between sample points.
TerrainLosResult evaluateLosFromProfile({
  required List<
    ({
      double distanceMeters,
      double latitude,
      double longitude,
      double? elevationMeters,
    })
  >
  samples,
  required int? altAMeters,
  required int? altBMeters,
  double frequencyMhz = 906.0,
}) {
  if (samples.isEmpty) {
    return const TerrainLosResult(
      verdict: LosVerdict.unknown,
      perSampleClearanceMeters: [],
      perSampleFresnelRadiusMeters: [],
      losLineHeightsMeters: [],
      worstPointIndex: null,
      worstClearanceMeters: null,
      additionalClearanceNeededMeters: 0,
      hasAltitudeData: false,
    );
  }

  final n = samples.length;
  final totalDist = samples.last.distanceMeters;

  // Helper: terrain elevation at index, defaulting null to 0.
  double terrain(int i) => samples[i].elevationMeters ?? 0.0;

  if (altAMeters == null || altBMeters == null) {
    // No altitude data — can still return terrain-only profile counts but
    // cannot compute clearance or LOS line.
    return TerrainLosResult(
      verdict: LosVerdict.unknown,
      perSampleClearanceMeters: List.filled(n, 0.0),
      perSampleFresnelRadiusMeters: List.filled(n, 0.0),
      losLineHeightsMeters: List.filled(n, 0.0),
      worstPointIndex: null,
      worstClearanceMeters: null,
      additionalClearanceNeededMeters: 0,
      hasAltitudeData: false,
    );
  }

  // --- Compute LOS line and Fresnel radius at every sample point ---

  final double wavelength = 299792458.0 / (frequencyMhz * 1e6);
  final losHeights = <double>[];
  final fresnelRadii = <double>[];
  final clearances = <double>[];

  for (var i = 0; i < n; i++) {
    final d = samples[i].distanceMeters;
    // Linear interpolation of antenna height between altA and altB.
    final t = totalDist > 0 ? d / totalDist : 0.0;
    final losH = altAMeters + t * (altBMeters - altAMeters);

    // Fresnel zone radius at this point:
    // F1 = sqrt(λ × d1 × d2 / D)  where d1 = distance from A, d2 = from B
    final d1 = d;
    final d2 = totalDist - d;
    final fresnelR = (totalDist > 0 && d1 > 0 && d2 > 0)
        ? math.sqrt(wavelength * d1 * d2 / totalDist)
        : 0.0;

    final terrainH = terrain(i);
    // Clearance = LOS height above terrain, minus 60 % Fresnel requirement.
    // Positive → adequate clearance; negative → intrusion.
    final clearance = losH - terrainH - 0.6 * fresnelR;

    losHeights.add(losH);
    fresnelRadii.add(fresnelR);
    clearances.add(clearance);
  }

  // --- Determine worst obstruction ---
  int worstIdx = 0;
  for (var i = 1; i < n; i++) {
    if (clearances[i] < clearances[worstIdx]) worstIdx = i;
  }
  final worstClearance = clearances[worstIdx];

  // Additional height needed at worst point to achieve 60 % Fresnel clearance.
  final additionalNeeded = worstClearance < 0 ? -worstClearance : 0.0;

  // --- Determine overall verdict ---
  final bool anyObstructed = clearances.any((c) => c < 0);
  final bool anyMarginal = clearances.any(
    (c) => c >= 0 && c < fresnelRadii[clearances.indexOf(c)] * 0.4,
  );

  LosVerdict verdict;

  if (anyObstructed) {
    verdict = LosVerdict.obstructed;
  } else if (anyMarginal) {
    verdict = LosVerdict.marginal;
  } else {
    verdict = LosVerdict.clear;
  }

  return TerrainLosResult(
    verdict: verdict,
    perSampleClearanceMeters: clearances,
    perSampleFresnelRadiusMeters: fresnelRadii,
    losLineHeightsMeters: losHeights,
    worstPointIndex: worstIdx,
    worstClearanceMeters: worstClearance,
    additionalClearanceNeededMeters: additionalNeeded,
    hasAltitudeData: true,
  );
}
