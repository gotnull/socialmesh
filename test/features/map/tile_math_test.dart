// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/features/map/offline_tiles/tile_math.dart';

void main() {
  group('slippy tile coordinates', () {
    test('zoom 0 maps everything to tile 0,0', () {
      expect(lonToTileX(-180, 0), 0);
      expect(lonToTileX(179.9, 0), 0);
      expect(latToTileY(85, 0), 0);
      expect(latToTileY(-85, 0), 0);
    });

    test('zoom 1 splits the world into quadrants', () {
      // Western hemisphere -> x0, eastern -> x1.
      expect(lonToTileX(-90, 1), 0);
      expect(lonToTileX(90, 1), 1);
      // Northern hemisphere -> y0, southern -> y1.
      expect(latToTileY(45, 1), 0);
      expect(latToTileY(-45, 1), 1);
    });

    test('null island sits at the grid centre at zoom 2', () {
      // n = 4; (0+180)/360*4 = 2; lat 0 -> y = 2.
      expect(lonToTileX(0, 2), 2);
      expect(latToTileY(0, 2), 2);
    });

    test('coordinates are clamped to the valid range', () {
      // Out-of-range lon/lat must never exceed 2^z - 1 or go negative.
      expect(lonToTileX(180, 1), 1);
      expect(lonToTileX(-181, 1), 0);
      expect(latToTileY(90, 1), inInclusiveRange(0, 1));
      expect(latToTileY(-90, 1), inInclusiveRange(0, 1));
    });
  });

  group('clampZoomRange', () {
    test('orders min/max', () {
      final r = clampZoomRange(17, 12);
      expect(r.minZoom, 12);
      expect(r.maxZoom, 17);
    });

    test('clamps to the supported window', () {
      final r = clampZoomRange(0, 99);
      expect(r.minZoom, greaterThanOrEqualTo(3));
      expect(r.maxZoom, lessThanOrEqualTo(18));
    });
  });

  group('countTilesForBounds', () {
    final bounds = LatLngBounds(
      const LatLng(67.0, 17.0), // northern Sweden-ish
      const LatLng(68.0, 19.0),
    );

    test('single zoom counts the covering rectangle', () {
      // At one zoom level the count is (dx+1)*(dy+1).
      const z = 8;
      final xMin = lonToTileX(17.0, z);
      final xMax = lonToTileX(19.0, z);
      final yMin = latToTileY(68.0, z); // north -> smaller y
      final yMax = latToTileY(67.0, z);
      final expected = (xMax - xMin + 1) * (yMax - yMin + 1);
      expect(countTilesForBounds(bounds, z, z), expected);
    });

    test('count equals the length of the enumerated tiles', () {
      final count = countTilesForBounds(bounds, 8, 11);
      final enumerated = tilesForBounds(bounds, 8, 11).length;
      expect(count, enumerated);
      expect(count, greaterThan(0));
    });

    test('enumerated tiles are unique', () {
      final tiles = tilesForBounds(bounds, 8, 10).toSet();
      final list = tilesForBounds(bounds, 8, 10).toList();
      expect(tiles.length, list.length);
    });

    test('a wider zoom range covers at least as many tiles', () {
      final narrow = countTilesForBounds(bounds, 10, 10);
      final wide = countTilesForBounds(bounds, 8, 12);
      expect(wide, greaterThan(narrow));
    });
  });

  group('estimateBytes', () {
    test('scales linearly with the average tile size', () {
      expect(estimateBytes(0), 0);
      expect(estimateBytes(10), 10 * kAvgTileBytes);
    });
  });
}
