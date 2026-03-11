// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:socialmesh/services/terrain/elevation_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a syntactically valid OpenTopoData response for [count] results.
/// Each result gets a sequential elevation value starting at [baseElevation].
String _buildSuccessResponse(int count, {double baseElevation = 100.0}) {
  final results = List.generate(
    count,
    (i) => {
      'dataset': 'srtm90m',
      'elevation': baseElevation + i.toDouble(),
      'location': {'lat': 0.0, 'lng': 0.0},
    },
  );
  return jsonEncode({'status': 'OK', 'results': results});
}

ElevationService _serviceWith(MockClient client) =>
    ElevationService(client: client);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ElevationService.fetchProfile', () {
    test('returns ElevationProfileSuccess with correct sample count', () async {
      final client = MockClient((request) async {
        return http.Response(
          _buildSuccessResponse(60), // service requests 60 samples
          200,
        );
      });

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(37.7749, -122.4194),
        const LatLng(37.8044, -122.2712),
      );

      expect(result, isA<ElevationProfileSuccess>());
      final success = result as ElevationProfileSuccess;
      expect(success.samples, hasLength(60));
    });

    test('first sample has distanceMeters == 0', () async {
      final client = MockClient(
        (_) async => http.Response(_buildSuccessResponse(60), 200),
      );

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(37.7749, -122.4194),
        const LatLng(37.8044, -122.2712),
      );

      final success = result as ElevationProfileSuccess;
      expect(success.samples.first.distanceMeters, closeTo(0.0, 0.01));
    });

    test('last sample has distanceMeters ~= total path distance', () async {
      final client = MockClient(
        (_) async => http.Response(_buildSuccessResponse(60), 200),
      );

      const start = LatLng(37.7749, -122.4194);
      const end = LatLng(37.8044, -122.2712);
      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(start, end);

      final success = result as ElevationProfileSuccess;
      final lastDist = success.samples.last.distanceMeters;
      // Distance between these two points is roughly 14–16 km.
      expect(lastDist, greaterThan(10000));
      expect(lastDist, lessThan(20000));
    });

    test('elevation values are populated from API response', () async {
      final client = MockClient(
        (_) async =>
            http.Response(_buildSuccessResponse(60, baseElevation: 250.0), 200),
      );

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(37.7749, -122.4194),
        const LatLng(37.8044, -122.2712),
      );

      final success = result as ElevationProfileSuccess;
      expect(success.samples.first.elevationMeters, closeTo(250.0, 0.01));
      expect(success.samples.last.elevationMeters, closeTo(309.0, 1.0));
    });

    test('returns ElevationProfileOffline on ClientException', () async {
      final client = MockClient((_) async {
        throw http.ClientException('No network');
      });

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(37.7749, -122.4194),
        const LatLng(37.8044, -122.2712),
      );

      expect(result, isA<ElevationProfileOffline>());
    });

    test('returns ElevationProfileFailure on HTTP 500', () async {
      final client = MockClient(
        (_) async => http.Response('Internal Server Error', 500),
      );

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(37.7749, -122.4194),
        const LatLng(37.8044, -122.2712),
      );

      expect(result, isA<ElevationProfileFailure>());
      expect((result as ElevationProfileFailure).reason, contains('500'));
    });

    test('returns ElevationProfileFailure on HTTP 429 rate limit', () async {
      final client = MockClient(
        (_) async => http.Response('Too Many Requests', 429),
      );

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(0, 0),
        const LatLng(1, 1),
      );

      expect(result, isA<ElevationProfileFailure>());
      expect(
        (result as ElevationProfileFailure).reason,
        contains('Rate limited'),
      );
    });

    test('returns ElevationProfileFailure when API status != OK', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'status': 'INVALID_REQUEST', 'results': []}),
          200,
        ),
      );

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(0, 0),
        const LatLng(1, 1),
      );

      expect(result, isA<ElevationProfileFailure>());
      expect(
        (result as ElevationProfileFailure).reason,
        contains('INVALID_REQUEST'),
      );
    });

    test(
      'returns ElevationProfileFailure when result count is wrong',
      () async {
        // Return only 1 result when 60 are expected.
        final client = MockClient(
          (_) async => http.Response(_buildSuccessResponse(1), 200),
        );

        final svc = _serviceWith(client);
        final result = await svc.fetchProfile(
          const LatLng(0, 0),
          const LatLng(1, 1),
        );

        expect(result, isA<ElevationProfileFailure>());
      },
    );

    test('returns ElevationProfileFailure on malformed JSON', () async {
      final client = MockClient(
        (_) async => http.Response('not_valid_json{{{', 200),
      );

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(0, 0),
        const LatLng(1, 1),
      );

      expect(result, isA<ElevationProfileFailure>());
    });

    test('samples include first endpoint lat/lon', () async {
      final client = MockClient(
        (_) async => http.Response(_buildSuccessResponse(60), 200),
      );

      const start = LatLng(48.8566, 2.3522);
      const end = LatLng(48.8600, 2.3600);
      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(start, end);

      final success = result as ElevationProfileSuccess;
      // The first sample should be at (or very close to) the start point.
      expect(success.samples.first.latitude, closeTo(start.latitude, 0.0001));
      expect(success.samples.first.longitude, closeTo(start.longitude, 0.0001));
    });

    test('samples include last endpoint lat/lon', () async {
      final client = MockClient(
        (_) async => http.Response(_buildSuccessResponse(60), 200),
      );

      const start = LatLng(48.8566, 2.3522);
      const end = LatLng(48.8600, 2.3600);
      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(start, end);

      final success = result as ElevationProfileSuccess;
      expect(success.samples.last.latitude, closeTo(end.latitude, 0.0001));
      expect(success.samples.last.longitude, closeTo(end.longitude, 0.0001));
    });

    test('distances are monotonically increasing', () async {
      final client = MockClient(
        (_) async => http.Response(_buildSuccessResponse(60), 200),
      );

      final svc = _serviceWith(client);
      final result = await svc.fetchProfile(
        const LatLng(0, 0),
        const LatLng(0, 1),
      );

      final success = result as ElevationProfileSuccess;
      for (var i = 1; i < success.samples.length; i++) {
        expect(
          success.samples[i].distanceMeters,
          greaterThanOrEqualTo(success.samples[i - 1].distanceMeters),
        );
      }
    });
  });
}
