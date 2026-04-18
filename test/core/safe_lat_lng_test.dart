// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/core/safe_lat_lng.dart';

void main() {
  group('safeLatLng', () {
    test('accepts finite in-range coordinates', () {
      final p = safeLatLng(-33.8688, 151.2093);
      expect(p, isNotNull);
      expect(p!.latitude, -33.8688);
      expect(p.longitude, 151.2093);
    });

    test('accepts 0,0', () {
      expect(safeLatLng(0, 0), isNotNull);
    });

    test('rejects null inputs', () {
      expect(safeLatLng(null, 0), isNull);
      expect(safeLatLng(0, null), isNull);
    });

    test('rejects NaN', () {
      expect(safeLatLng(double.nan, 0), isNull);
      expect(safeLatLng(0, double.nan), isNull);
    });

    test('rejects infinities', () {
      expect(safeLatLng(double.infinity, 0), isNull);
      expect(safeLatLng(0, double.negativeInfinity), isNull);
    });

    test('rejects out-of-range latitude', () {
      expect(safeLatLng(91, 0), isNull);
      expect(safeLatLng(-91, 0), isNull);
    });

    test('rejects out-of-range longitude', () {
      expect(safeLatLng(0, 181), isNull);
      expect(safeLatLng(0, -181), isNull);
    });
  });

  group('isFiniteLatLng', () {
    test('true for valid', () {
      expect(isFiniteLatLng(const LatLng(10, 20)), isTrue);
    });

    test('false for null', () {
      expect(isFiniteLatLng(null), isFalse);
    });

    test('false for NaN', () {
      expect(isFiniteLatLng(LatLng(double.nan, 0)), isFalse);
    });

    test('false for out-of-range', () {
      expect(isFiniteLatLng(const LatLng(95, 0)), isFalse);
    });
  });

  group('finiteMarkers', () {
    test('filters out non-finite marker points', () {
      final good = Marker(point: const LatLng(10, 20), child: const SizedBox());
      final bad = Marker(point: LatLng(double.nan, 0), child: const SizedBox());
      final result = finiteMarkers([good, bad, good]);
      expect(result.length, 2);
      expect(result.every((m) => m.point.latitude.isFinite), isTrue);
    });

    test('empty input yields empty output', () {
      expect(finiteMarkers(const []), isEmpty);
    });
  });
}
