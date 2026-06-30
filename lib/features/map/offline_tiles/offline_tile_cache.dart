// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Offline Tile Cache — durable configuration of flutter_map's built-in tile
// cache, plus the pre-download primitives used by the region downloader.
//
// flutter_map 8.x already persists tiles to disk by default, but in an
// OS-managed cache directory that the system may evict under storage pressure,
// with freshness derived from each tile's HTTP headers (so tiles can also
// expire). Neither is acceptable for a "download a region now, use it off-grid
// in weeks" workflow. This module reconfigures the built-in cache singleton to
// a durable app-documents directory with a long fixed freshness window, and
// exposes helpers to pre-seed that cache so the live map renders the tiles
// later with no network.

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/logging.dart';
import '../../../core/map_config.dart';
import '../../../core/safe_lat_lng.dart';
import 'tile_math.dart';

/// Durable freshness window for cached tiles. Basemaps change slowly, and the
/// point of a pre-trip download is that tiles survive offline without
/// re-validation, so we override flutter_map's header-derived freshness.
const Duration kOfflineTileFreshAge = Duration(days: 365);

/// Generous ceiling for the on-disk cache. Pre-downloaded regions can be large;
/// the built-in size reducer trims beyond this on the next launch.
const int kOfflineCacheMaxBytes = 4 * 1000 * 1000 * 1000; // 4 GB

/// Styles eligible for bulk pre-download.
///
/// Excludes Esri [MapTileStyle.satellite] (its TOS restricts bulk caching) and
/// is moot for Mapbox (TOS forbids persistent raster storage; the feature is
/// gated off entirely when Mapbox is active).
const Set<MapTileStyle> kDownloadableStyles = {
  MapTileStyle.dark,
  MapTileStyle.light,
  MapTileStyle.terrain,
};

/// Thrown when a tile server returns HTTP 429 so the downloader can back off.
class TileRateLimitedException implements Exception {
  const TileRateLimitedException();
}

/// Durable wrapper around flutter_map's built-in tile cache.
class OfflineTileCache {
  OfflineTileCache._();

  /// App-wide singleton. The built-in caching provider is itself a singleton,
  /// so this just centralises configuration and URL generation.
  static final OfflineTileCache instance = OfflineTileCache._();

  MapCachingProvider? _provider;

  // Reference provider used ONLY to generate tile URLs via flutter_map's own
  // template resolver (guaranteeing subdomain / {r} parity with the live map).
  // It performs no network fetches itself.
  final NetworkTileProvider _urlProvider = NetworkTileProvider();
  final Map<MapTileStyle, TileLayer> _refLayers = {};

  /// Configure the built-in caching singleton to use a durable directory with a
  /// long freshness window. Must run once at startup BEFORE any map tile loads,
  /// because the singleton's configuration is fixed on first use.
  Future<void> configure() async {
    if (_provider != null) return;
    final docs = await getApplicationDocumentsDirectory();
    final dir = p.join(docs.path, 'offline_map_cache');
    _provider = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: dir,
      overrideFreshAge: kOfflineTileFreshAge,
      maxCacheSize: kOfflineCacheMaxBytes,
    );
    AppLogging.map('Offline tile cache configured at $dir');
  }

  MapCachingProvider get _caching =>
      _provider ?? BuiltInMapCachingProvider.getOrCreateInstance();

  TileLayer _refLayer(MapTileStyle style) => _refLayers.putIfAbsent(
    style,
    () => TileLayer(
      // Resolve through MapConfig so the cache-key URL matches the live map
      // byte-for-byte (Mapbox / MapTiler terrain when active, else the raw
      // source). MapTiler retina is the server path, so coordinates are
      // unchanged and the only delta is the @2x suffix in the cache key.
      urlTemplate: MapConfig.urlForStyle(style, satelliteLabelsOn: false),
      subdomains: MapConfig.subdomainsForStyle(style),
      retinaMode: MapConfig.resolvedRetinaMode(style, satelliteLabelsOn: false),
      // This layer is never rendered — it exists only so flutter_map's own
      // resolver generates cache-parity URLs. The transformer satisfies the
      // lint and is harmless on an unrendered layer.
      tileUpdateTransformer: finiteCameraTileUpdateTransformer,
    ),
  );

  /// The exact URL the live map requests for [coord] under [style], generated
  /// by flutter_map's own resolver so the cache key matches byte-for-byte.
  String tileUrl(MapTileStyle style, TileCoord coord) => _urlProvider
      .getTileUrl(TileCoordinates(coord.x, coord.y, coord.z), _refLayer(style));

  /// Whether a tile is already cached and still fresh (skip re-download).
  Future<bool> isCached(MapTileStyle style, TileCoord coord) async {
    if (!_caching.isSupported) return false;
    try {
      final hit = await _caching.getTile(tileUrl(style, coord));
      return hit != null && !hit.metadata.isStale;
    } catch (_) {
      return false;
    }
  }

  /// Fetch a single tile and store it durably. Returns the bytes written, or
  /// null on a non-fatal failure (caller counts it as failed and continues).
  /// Throws [TileRateLimitedException] on HTTP 429 so the caller can back off.
  Future<int?> downloadTile(
    MapTileStyle style,
    TileCoord coord,
    http.Client client,
  ) async {
    final url = tileUrl(style, coord);
    final http.Response response;
    try {
      response = await client.get(
        Uri.parse(url),
        headers: const {'User-Agent': MapConfig.userAgentPackageName},
      );
    } catch (e) {
      AppLogging.map('Tile download error $url: $e');
      return null;
    }

    if (response.statusCode == 429) {
      throw const TileRateLimitedException();
    }
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return null;
    }

    final bytes = response.bodyBytes;
    if (_caching.isSupported) {
      try {
        await _caching.putTile(
          url: url,
          metadata: CachedMapTileMetadata(
            staleAt: DateTime.timestamp().add(kOfflineTileFreshAge),
            lastModified: null,
            etag: null,
          ),
          bytes: bytes,
        );
      } catch (e) {
        AppLogging.map('Tile cache write failed $url: $e');
        return null;
      }
    }
    return bytes.length;
  }
}
