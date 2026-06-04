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

  group('isFiniteCameraPose', () {
    test('true for finite center and zoom', () {
      expect(isFiniteCameraPose(const LatLng(10, 20), 12.0), isTrue);
    });

    test('false for null center', () {
      expect(isFiniteCameraPose(null, 12.0), isFalse);
    });

    test('false for NaN center (flutter_map pinch overflow)', () {
      expect(isFiniteCameraPose(LatLng(double.nan, double.nan), 12.0), isFalse);
    });

    test('false for NaN zoom (math.log(scale<=0) overflow)', () {
      expect(isFiniteCameraPose(const LatLng(10, 20), double.nan), isFalse);
    });

    test('false for infinite zoom', () {
      expect(
        isFiniteCameraPose(const LatLng(10, 20), double.infinity),
        isFalse,
      );
    });

    test('false for out-of-range center', () {
      expect(isFiniteCameraPose(const LatLng(95, 0), 12.0), isFalse);
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

  group('safeLatLngBounds', () {
    test('returns bounds over finite points only', () {
      final bounds = safeLatLngBounds([
        const LatLng(10, 20),
        LatLng(double.nan, double.nan),
        const LatLng(30, 40),
      ]);
      expect(bounds, isNotNull);
      expect(bounds!.southWest.latitude, 10);
      expect(bounds.northEast.latitude, 30);
    });

    test('null when no finite points', () {
      expect(safeLatLngBounds(const []), isNull);
      expect(safeLatLngBounds([LatLng(double.nan, double.nan)]), isNull);
    });
  });

  group('SafeMapControllerMove', () {
    test('safeMove skips non-finite destinations', () {
      final controller = MapController();
      expect(controller.safeMove(null, 10), isFalse);
      expect(controller.safeMove(LatLng(double.nan, 0), 10), isFalse);
      expect(controller.safeMove(const LatLng(10, 20), double.nan), isFalse);
    });

    test('safeMoveAndRotate skips non-finite inputs', () {
      final controller = MapController();
      // Should not throw — we only assert it does not call into flutter_map
      // with bad inputs. A unit-level check on the guard is sufficient here;
      // integration-level behavior is covered by widget tests.
      expect(() => controller.safeMoveAndRotate(null, 10, 0), returnsNormally);
      expect(
        () => controller.safeMoveAndRotate(
          const LatLng(10, 20),
          double.infinity,
          0,
        ),
        returnsNormally,
      );
    });
  });
}
