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
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/boot_timeline.dart';
import '../../../core/logging.dart';
import '../../../core/map_config.dart';
import '../../../core/safe_lat_lng.dart';
import '../../../services/storage/storage_service.dart';
import 'offline_tile_storage.dart';
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

  BuiltInMapCachingProvider? _provider;

  /// Storage resolver, exposed so the download UI can query removable
  /// volumes and size/delete an abandoned cache without re-instantiating.
  final OfflineTileStorage storage = OfflineTileStorage();

  String? _activeCacheRoot;
  bool _fellBackToInternal = false;

  /// Directory the cache is currently rooted at (null before [configure]).
  String? get activeCacheRoot => _activeCacheRoot;

  /// True when the user prefers SD card storage but boot resolved to
  /// internal because the card was missing or unwritable.
  bool get fellBackToInternal => _fellBackToInternal;

  // Reference provider used ONLY to generate tile URLs via flutter_map's own
  // template resolver (guaranteeing subdomain / {r} parity with the live map).
  // It performs no network fetches itself.
  final NetworkTileProvider _urlProvider = NetworkTileProvider();
  final Map<MapTileStyle, TileLayer> _refLayers = {};

  /// Configure the built-in caching singleton to use a durable directory with a
  /// long freshness window. Must run once at startup BEFORE any map tile loads,
  /// because the singleton's configuration is fixed on first use.
  ///
  /// The root honours the SD-card preference when set, degrading silently to
  /// internal storage (with [fellBackToInternal] raised for the UI) when the
  /// card is missing or unwritable — an unwritable root must never reach the
  /// provider, whose constructor would raise an unhandled async error and
  /// leave every cache call awaiting a completer that never completes.
  Future<void> configure() async {
    if (_provider != null) return;
    final prefs = await SharedPreferences.getInstance();
    final preferSd = prefs.getBool(offlineMapStorageOnSdCardKey) ?? false;
    BootTimeline.instance.mark('tile_cache_prefs');
    final resolved = await storage.resolveRoot(
      preferSd
          ? OfflineTileStorageLocation.sdCard
          : OfflineTileStorageLocation.internal,
    );
    BootTimeline.instance.mark('tile_cache_root');
    _fellBackToInternal = resolved.fellBack;
    _activeCacheRoot = resolved.path;
    _provider = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: resolved.path,
      overrideFreshAge: kOfflineTileFreshAge,
      maxCacheSize: kOfflineCacheMaxBytes,
    );
    BootTimeline.instance.mark('tile_cache_provider');
    AppLogging.map(
      'Offline tile cache configured at ${resolved.path}'
      '${resolved.fellBack ? ' (SD card unavailable, fell back)' : ''}',
    );
  }

  /// Re-root the cache at [target], destroying and re-creating the built-in
  /// provider. Throws [OfflineStorageUnavailableException] when the SD card
  /// is requested but missing/unwritable — the preference is persisted only
  /// after the new provider exists. Never call while a region download is
  /// running.
  Future<void> switchStorageLocation(OfflineTileStorageLocation target) async {
    final String newRoot;
    if (target == OfflineTileStorageLocation.sdCard) {
      final sd = await storage.removableRoot();
      if (sd == null || !await storage.probeWritable(sd)) {
        throw const OfflineStorageUnavailableException();
      }
      newRoot = sd;
    } else {
      newRoot = await storage.internalRoot();
    }
    if (newRoot != _activeCacheRoot) {
      // destroy() resets the provider singleton synchronously before its
      // async teardown, so re-creating immediately (without awaiting) leaves
      // no window in which a stray tile load could resurrect a
      // default-configured instance in the wrong directory.
      final destroyed = _provider?.destroy();
      _provider = BuiltInMapCachingProvider.getOrCreateInstance(
        cacheDirectory: newRoot,
        overrideFreshAge: kOfflineTileFreshAge,
        maxCacheSize: kOfflineCacheMaxBytes,
      );
      _activeCacheRoot = newRoot;
      await destroyed;
      AppLogging.map('Offline tile cache moved to $newRoot');
    }
    // A successful switch always lands on the requested location, including
    // accepting internal after a boot-time SD fallback (root unchanged).
    _fellBackToInternal = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      offlineMapStorageOnSdCardKey,
      target == OfflineTileStorageLocation.sdCard,
    );
  }

  MapCachingProvider get _caching =>
      _provider ?? BuiltInMapCachingProvider.getOrCreateInstance();

  TileLayer _refLayer(MapTileStyle style) => _refLayers.putIfAbsent(
    style,
    () => TileLayer(
      // Resolve through MapConfig's offline source so the cache-key URL
      // matches byte-for-byte what the live map requests while offline. The
      // offline source is never Mapbox or MapTiler: both providers' terms
      // prohibit bulk download, so regions come from CARTO (dark / light)
      // and OpenTopoMap (terrain) only.
      urlTemplate: MapConfig.urlForStyle(
        style,
        satelliteLabelsOn: false,
        offlineSource: true,
      ),
      subdomains: MapConfig.subdomainsForStyle(style, offlineSource: true),
      retinaMode: MapConfig.resolvedRetinaMode(
        style,
        satelliteLabelsOn: false,
        offlineSource: true,
      ),
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
