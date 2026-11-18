// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math';

import '../core/legal/age_safety_policy.dart';

const int kDefaultSignalLocationRadiusMeters = 250;

/// Location blur radius applied when [AgeSafetyPolicy.shouldHidePreciseLocation]
/// is true (minor users). Four times the default radius produces an area that
/// is ~16× larger, which prevents street-level resolution while still
/// allowing city-level context.
const int kMinorSignalLocationRadiusMeters = 1000;

const double _metersPerDegreeLat = 111320.0;

class LocationPrivacy {
  const LocationPrivacy._();

  static int normalizeRadiusMeters(int radiusMeters) {
    final normalized = radiusMeters.clamp(50, 5000);
    return normalized.toInt();
  }

  /// Coarsen raw latitude/longitude pair according to [policy].
  ///
  /// Returns $1 the input values unchanged when the user is an adult, or
  /// $2 quantized values when [policy.shouldHidePreciseLocation] is true.
  /// Used by map share/copy actions that work with raw coordinates.
  static ({double latitude, double longitude}) coarsenCoordsForPolicy(
    double latitude,
    double longitude,
    AgeSafetyPolicy policy, {
    int radiusMeters = kDefaultSignalLocationRadiusMeters,
    int minorRadiusMeters = kMinorSignalLocationRadiusMeters,
  }) {
    final effective = policy.shouldHidePreciseLocation
        ? minorRadiusMeters > radiusMeters
              ? minorRadiusMeters
              : radiusMeters
        : radiusMeters;
    final q = _quantizeLatLon(latitude, longitude, effective);
    return (latitude: q.latitude, longitude: q.longitude);
  }

  static _QuantizedLatLon _quantizeLatLon(
    double latitude,
    double longitude,
    int radiusMeters,
  ) {
    final latStep = radiusMeters / _metersPerDegreeLat;
    final latRad = latitude * pi / 180.0;
    final lonMetersPerDegree =
        _metersPerDegreeLat * max(0.0001, cos(latRad).abs());
    final lonStep = radiusMeters / lonMetersPerDegree;
    final quantizedLat = (latitude / latStep).round() * latStep;
    final quantizedLon = (longitude / lonStep).round() * lonStep;
    return _QuantizedLatLon(quantizedLat, quantizedLon);
  }
}

class _QuantizedLatLon {
  final double latitude;
  final double longitude;

  const _QuantizedLatLon(this.latitude, this.longitude);
}
