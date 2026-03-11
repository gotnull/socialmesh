// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/logging.dart';

/// A single elevation sample along a terrain profile path.
class ElevationSample {
  /// Distance from the start point along the path, in meters.
  final double distanceMeters;

  /// Geographic latitude of this sample point.
  final double latitude;

  /// Geographic longitude of this sample point.
  final double longitude;

  /// Terrain elevation at this point in meters above mean sea level.
  /// Null if the API did not return a value for this point.
  final double? elevationMeters;

  const ElevationSample({
    required this.distanceMeters,
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
  });
}

/// Result of a terrain profile fetch operation.
sealed class ElevationProfileResult {
  const ElevationProfileResult();
}

/// Successful profile fetch with elevation samples.
final class ElevationProfileSuccess extends ElevationProfileResult {
  final List<ElevationSample> samples;
  const ElevationProfileSuccess(this.samples);
}

/// Fetch failed because of network connectivity or API error.
final class ElevationProfileFailure extends ElevationProfileResult {
  final String reason;
  const ElevationProfileFailure(this.reason);
}

/// Fetch failed because the device is offline.
final class ElevationProfileOffline extends ElevationProfileResult {
  const ElevationProfileOffline();
}

/// Stateless service that fetches terrain elevation profiles for a path.
///
/// Uses the OpenTopoData SRTM 90m API (https://api.opentopodata.org) which
/// is free, requires no API key, and supports batches of up to 100 locations.
///
/// Callers own the lifecycle. Do not instantiate inside build().
class ElevationService {
  static const String _apiBase = 'https://api.opentopodata.org/v1/srtm90m';
  static const int _sampleCount = 60;
  static const Duration _timeout = Duration(seconds: 20);

  // Effective Earth radius for great-circle interpolation (meters).
  static const double _earthRadiusMeters = 6371000.0;

  final http.Client _client;

  ElevationService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch a terrain elevation profile along the great-circle path from
  /// [start] to [end].
  ///
  /// Samples [_sampleCount] evenly-spaced points (including both endpoints)
  /// and batches them into a single API request.
  ///
  /// Returns [ElevationProfileSuccess] on success,
  /// [ElevationProfileOffline] on connectivity failure,
  /// [ElevationProfileFailure] on other errors.
  Future<ElevationProfileResult> fetchProfile(LatLng start, LatLng end) async {
    final samples = _samplePoints(start, end);
    final locationParam = samples
        .map((s) => '${s.latitude},${s.longitude}')
        .join('|');

    final uri = Uri.parse('$_apiBase?locations=$locationParam');

    AppLogging.maps(
      '[ElevationService] Fetching ${samples.length} samples '
      'from ${start.latitude.toStringAsFixed(4)},${start.longitude.toStringAsFixed(4)}'
      ' to ${end.latitude.toStringAsFixed(4)},${end.longitude.toStringAsFixed(4)}',
    );

    try {
      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        return _parseResponse(response.body, samples);
      } else if (response.statusCode == 429) {
        AppLogging.maps(
          '[ElevationService] Rate limited (429). Returning failure.',
        );
        return const ElevationProfileFailure('Rate limited by elevation API.');
      } else {
        AppLogging.maps('[ElevationService] API error ${response.statusCode}.');
        return ElevationProfileFailure(
          'Elevation API returned ${response.statusCode}.',
        );
      }
    } on http.ClientException catch (e) {
      AppLogging.maps('[ElevationService] Network error: $e');
      return const ElevationProfileOffline();
    } catch (e) {
      AppLogging.maps('[ElevationService] Unexpected error: $e');
      // Treat any socket/OS-level error as offline; other errors as failure.
      final msg = e.toString().toLowerCase();
      if (msg.contains('socketexception') ||
          msg.contains('connection refused') ||
          msg.contains('network') ||
          msg.contains('unreachable') ||
          msg.contains('timeout')) {
        return const ElevationProfileOffline();
      }
      return ElevationProfileFailure('$e');
    }
  }

  /// Parse the OpenTopoData JSON response and merge elevation values with
  /// the pre-computed sample points.
  ElevationProfileResult _parseResponse(
    String body,
    List<ElevationSample> samples,
  ) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final status = json['status'] as String?;
      if (status != 'OK') {
        return ElevationProfileFailure('API status: $status');
      }

      final results = json['results'] as List<dynamic>?;
      if (results == null || results.length != samples.length) {
        return const ElevationProfileFailure(
          'Unexpected result count from elevation API.',
        );
      }

      final enriched = <ElevationSample>[];
      for (var i = 0; i < samples.length; i++) {
        final entry = results[i] as Map<String, dynamic>;
        final elevation = (entry['elevation'] as num?)?.toDouble();
        enriched.add(
          ElevationSample(
            distanceMeters: samples[i].distanceMeters,
            latitude: samples[i].latitude,
            longitude: samples[i].longitude,
            elevationMeters: elevation,
          ),
        );
      }

      AppLogging.maps(
        '[ElevationService] Parsed ${enriched.length} samples successfully.',
      );
      return ElevationProfileSuccess(enriched);
    } catch (e) {
      AppLogging.maps('[ElevationService] Parse error: $e');
      return ElevationProfileFailure('Failed to parse elevation response.');
    }
  }

  /// Generate [_sampleCount] evenly-spaced intermediate points along the
  /// great-circle path from [start] to [end], including both endpoints.
  ///
  /// Uses spherical linear interpolation (SLERP) for accurate great-circle
  /// sampling.
  List<ElevationSample> _samplePoints(LatLng start, LatLng end) {
    // Compute total great-circle distance for distance labels.
    final totalDistM = _haversineMeters(start, end);

    final points = <ElevationSample>[];
    for (var i = 0; i < _sampleCount; i++) {
      final fraction = i / (_sampleCount - 1);
      final point = _interpolate(start, end, fraction);
      points.add(
        ElevationSample(
          distanceMeters: fraction * totalDistM,
          latitude: point.latitude,
          longitude: point.longitude,
          elevationMeters: null, // filled in after API response
        ),
      );
    }
    return points;
  }

  /// Spherical interpolation between two LatLng points at fraction [t] ∈ [0,1].
  LatLng _interpolate(LatLng a, LatLng b, double t) {
    final lat1 = a.latitude * math.pi / 180;
    final lon1 = a.longitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final lon2 = b.longitude * math.pi / 180;

    // Angular distance between the two points.
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    final sinHalfLat = math.sin(dLat / 2);
    final sinHalfLon = math.sin(dLon / 2);
    final angularDist =
        2 *
        math.asin(
          math.sqrt(
            sinHalfLat * sinHalfLat +
                math.cos(lat1) * math.cos(lat2) * sinHalfLon * sinHalfLon,
          ),
        );

    // For very short paths, fall back to linear interpolation.
    if (angularDist < 1e-10) {
      return LatLng(
        a.latitude + t * (b.latitude - a.latitude),
        a.longitude + t * (b.longitude - a.longitude),
      );
    }

    final sinD = math.sin(angularDist);
    final aa = math.sin((1 - t) * angularDist) / sinD;
    final bb = math.sin(t * angularDist) / sinD;

    final x1 = math.cos(lat1) * math.cos(lon1);
    final y1 = math.cos(lat1) * math.sin(lon1);
    final z1 = math.sin(lat1);

    final x2 = math.cos(lat2) * math.cos(lon2);
    final y2 = math.cos(lat2) * math.sin(lon2);
    final z2 = math.sin(lat2);

    final x = aa * x1 + bb * x2;
    final y = aa * y1 + bb * y2;
    final z = aa * z1 + bb * z2;

    final lat = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
    final lon = math.atan2(y, x) * 180 / math.pi;
    return LatLng(lat, lon);
  }

  /// Haversine great-circle distance in meters.
  double _haversineMeters(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final sinHalfLat = math.sin(dLat / 2);
    final sinHalfLon = math.sin(dLon / 2);
    final a2 =
        sinHalfLat * sinHalfLat +
        math.cos(lat1) * math.cos(lat2) * sinHalfLon * sinHalfLon;
    final c = 2 * math.atan2(math.sqrt(a2), math.sqrt(1 - a2));
    return _earthRadiusMeters * c;
  }
}
