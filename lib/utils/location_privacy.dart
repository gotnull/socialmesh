// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import '../models/social.dart';

const int kDefaultSignalLocationRadiusMeters = 250;
const double _metersPerDegreeLat = 111320.0;

class LocationPrivacy {
  const LocationPrivacy._();

  static int normalizeRadiusMeters(int radiusMeters) {
    final normalized = radiusMeters.clamp(50, 5000);
    return normalized.toInt();
  }

  static PostLocation? coarseFromCoordinates({
    required double? latitude,
    required double? longitude,
    String? name,
    int radiusMeters = kDefaultSignalLocationRadiusMeters,
  }) {
    if (latitude == null || longitude == null) return null;
    final normalized = normalizeRadiusMeters(radiusMeters);
    final quantized = _quantizeLatLon(latitude, longitude, normalized);
    return PostLocation(
      latitude: quantized.latitude,
      longitude: quantized.longitude,
      name: name,
    );
  }

  static PostLocation? coarsenLocation(
    PostLocation? location, {
    int radiusMeters = kDefaultSignalLocationRadiusMeters,
  }) {
    if (location == null) return null;
    final normalized = normalizeRadiusMeters(radiusMeters);
    final quantized = _quantizeLatLon(
      location.latitude,
      location.longitude,
      normalized,
    );
    return PostLocation(
      latitude: quantized.latitude,
      longitude: quantized.longitude,
      name: location.name,
    );
  }

  static _QuantizedLatLon _quantizeLatLon(
    double latitude,
    double longitude,
    int radiusMeters,
  ) {
    final latStep = radiusMeters / _metersPerDegreeLat;
    final latRad = latitude * pi / 180.0;
    final lonMetersPerDegree = _metersPerDegreeLat * max(0.0001, cos(latRad).abs());
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
