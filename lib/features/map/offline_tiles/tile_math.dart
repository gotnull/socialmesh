// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Slippy-map tile maths for the offline region downloader.
//
// Pure functions only — no Flutter, no IO — so the enumeration and the
// pre-download count/size estimate are fully unit-testable. Conventions follow
// the OpenStreetMap "slippy map tilenames" standard (Web Mercator, z/x/y).

import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';

import '../../../core/map_config.dart';

/// A single tile address at zoom [z], column [x], row [y].
class TileCoord {
  final int z;
  final int x;
  final int y;

  const TileCoord(this.z, this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is TileCoord && other.z == z && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => 'TileCoord($z/$x/$y)';
}

/// Average bytes per raster PNG tile, used only for the pre-download size
/// estimate shown to the user. Real tiles vary widely (empty ocean tiles are
/// tiny, dense terrain tiles larger); 20 KB is a deliberately conservative
/// midpoint so the estimate does not undersell storage cost.
const int kAvgTileBytes = 20 * 1024;

/// Web Mercator is only defined to ~85.0511°; clamp before projecting so
/// near-pole bounds cannot produce NaN tile rows.
const double _maxMercatorLat = 85.05112877980659;

/// Tile column for [lon] at zoom [z], clamped to the valid `[0, 2^z - 1]`.
int lonToTileX(double lon, int z) {
  final n = 1 << z;
  final x = ((lon + 180.0) / 360.0 * n).floor();
  return x.clamp(0, n - 1);
}

/// Tile row for [lat] at zoom [z], clamped to the valid `[0, 2^z - 1]`.
/// Smaller rows are further north (y grows southward).
int latToTileY(double lat, int z) {
  final n = 1 << z;
  final clamped = lat.clamp(-_maxMercatorLat, _maxMercatorLat);
  final latRad = clamped * math.pi / 180.0;
  final y =
      ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
              2 *
              n)
          .floor();
  return y.clamp(0, n - 1);
}

/// Clamp a requested zoom range into the app's supported window and ensure
/// `min <= max`. Returns `(minZoom, maxZoom)`.
({int minZoom, int maxZoom}) clampZoomRange(int minZoom, int maxZoom) {
  final lo = minZoom.clamp(
    MapConfig.minZoom.toInt(),
    MapConfig.maxZoom.toInt(),
  );
  final hi = maxZoom.clamp(
    MapConfig.minZoom.toInt(),
    MapConfig.maxZoom.toInt(),
  );
  return lo <= hi ? (minZoom: lo, maxZoom: hi) : (minZoom: hi, maxZoom: lo);
}

/// Number of tiles covering [bounds] across the (clamped) zoom range, computed
/// without materializing the list — for the pre-download estimate.
int countTilesForBounds(LatLngBounds bounds, int minZoom, int maxZoom) {
  final range = clampZoomRange(minZoom, maxZoom);
  var total = 0;
  for (var z = range.minZoom; z <= range.maxZoom; z++) {
    final xMin = lonToTileX(bounds.west, z);
    final xMax = lonToTileX(bounds.east, z);
    final yMin = latToTileY(bounds.north, z);
    final yMax = latToTileY(bounds.south, z);
    total += (xMax - xMin + 1) * (yMax - yMin + 1);
  }
  return total;
}

/// Every tile covering [bounds] across the (clamped) zoom range, yielded
/// lazily so a large region does not allocate the whole list up front.
Iterable<TileCoord> tilesForBounds(
  LatLngBounds bounds,
  int minZoom,
  int maxZoom,
) sync* {
  final range = clampZoomRange(minZoom, maxZoom);
  for (var z = range.minZoom; z <= range.maxZoom; z++) {
    final xMin = lonToTileX(bounds.west, z);
    final xMax = lonToTileX(bounds.east, z);
    final yMin = latToTileY(bounds.north, z);
    final yMax = latToTileY(bounds.south, z);
    for (var x = xMin; x <= xMax; x++) {
      for (var y = yMin; y <= yMax; y++) {
        yield TileCoord(z, x, y);
      }
    }
  }
}

/// Estimated total bytes for [tileCount] tiles.
int estimateBytes(int tileCount) => tileCount * kAvgTileBytes;
