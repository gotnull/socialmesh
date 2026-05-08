// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_map/flutter_map.dart';

import 'constants.dart';
import 'logging.dart';

/// Centralized map configuration
class MapConfig {
  MapConfig._();

  /// Default subdomains for tile servers that support them
  static const List<String> defaultSubdomains = ['a', 'b', 'c', 'd'];

  /// User agent package name for tile requests
  static const String userAgentPackageName = 'com.socialmesh.app';

  /// Default map center (Sydney, Australia)
  static const double defaultLat = -33.8688;
  static const double defaultLon = 151.2093;

  /// Default zoom levels
  static const double defaultZoom = 13.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 18.0;

  // Esri's transparent reference tile service that publishes country / state /
  // province boundaries and populated-place labels (cities, towns, villages)
  // designed to sit on top of World_Imagery. Same provider, same TOS, same
  // attribution as the base imagery.
  static const String satelliteReferenceLabelsUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';

  // Short-form attribution; matches base imagery so the strip stays compact.
  static const String satelliteReferenceLabelsAttribution = '© Esri';

  /// Error tile callback for logging tile load failures
  static void _onTileError(
    TileImage tile,
    Object error,
    StackTrace? stackTrace,
  ) {
    // Log at debug level to avoid spamming logs during network issues
    AppLogging.map('Tile load failed: ${tile.coordinates} - $error');
  }

  /// Create a TileLayer with the default dark style
  static TileLayer darkTileLayer() {
    return TileLayer(
      urlTemplate: MapTileStyle.dark.url,
      subdomains: MapTileStyle.dark.subdomains,
      userAgentPackageName: userAgentPackageName,
      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
      errorTileCallback: _onTileError,
    );
  }

  /// Create a TileLayer for a given style
  static TileLayer tileLayerForStyle(MapTileStyle style) {
    return TileLayer(
      urlTemplate: style.url,
      subdomains: style.subdomains,
      userAgentPackageName: userAgentPackageName,
      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
      errorTileCallback: _onTileError,
    );
  }

  // Transparent reference overlay (boundaries + place names) intended to be
  // stacked above the satellite base layer.
  static TileLayer satelliteReferenceLabelsTileLayer() {
    return TileLayer(
      urlTemplate: satelliteReferenceLabelsUrl,
      userAgentPackageName: userAgentPackageName,
      // Reference layer has no @2x assets; matching base satellite retina off.
      retinaMode: false,
      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
      errorTileCallback: _onTileError,
    );
  }

  // Mapbox style slug per non-satellite enum. Satellite is special-cased
  // below because it switches between two slugs based on the labels toggle.
  static const Map<MapTileStyle, String> _mapboxStyleSlugs = {
    MapTileStyle.dark: 'mapbox/dark-v11',
    MapTileStyle.light: 'mapbox/light-v11',
    MapTileStyle.terrain: 'mapbox/outdoors-v12',
  };

  // Mapbox does not ship a transparent labels-only raster style. The closest
  // equivalent to "satellite + labels" is satellite-streets-v12, which bakes
  // labels and roads into the imagery. Satellite-only is satellite-v9.
  static String _mapboxSatelliteSlug({required bool labelsOn}) =>
      labelsOn ? 'mapbox/satellite-streets-v12' : 'mapbox/satellite-v9';

  /// True when the Mapbox feature flag is on AND a token is present.
  /// Callers use this to swap base tile URLs and attribution.
  static bool get isMapboxActive {
    if (!AppFeatureFlags.isMapboxEnabled) return false;
    return AppUrls.mapboxToken.isNotEmpty;
  }

  /// Mapbox raster-tile URL for the given style, or null when Mapbox is not
  /// active. Callers fall back to [MapTileStyle.url].
  ///
  /// 256-pixel tiles match flutter_map's default `tileSize`; setting
  /// `retinaMode: true` on the [TileLayer] appends `@2x` at request time.
  static String? mapboxUrlForStyle(
    MapTileStyle style, {
    required bool satelliteLabelsOn,
  }) {
    if (!isMapboxActive) return null;
    final slug = style == MapTileStyle.satellite
        ? _mapboxSatelliteSlug(labelsOn: satelliteLabelsOn)
        : _mapboxStyleSlugs[style];
    if (slug == null) return null;
    final token = AppUrls.mapboxToken;
    return 'https://api.mapbox.com/styles/v1/$slug/tiles/256/{z}/{x}/{y}?access_token=$token';
  }

  // Mapbox TOS requires the © Mapbox + © OpenStreetMap line on the map view
  // and a link back to mapbox.com/about/maps. The "Improve this map"
  // anchor is also required for Mapbox-hosted styles when the link is
  // tappable; we point the chip at the about page which satisfies both.
  static const String mapboxAttributionLabel = '© Mapbox © OpenStreetMap';
  static const String mapboxAttributionUrl =
      'https://www.mapbox.com/about/maps/';
}

/// Map tile style options
enum MapTileStyle {
  dark(
    'Dark',
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    ['a', 'b', 'c', 'd'],
  ),
  satellite(
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    [], // No subdomains
  ),
  terrain('Terrain', 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png', [
    'a',
    'b',
    'c',
  ]),
  light(
    'Light',
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    ['a', 'b', 'c', 'd'],
  );

  final String label;
  final String url;
  final List<String> subdomains;

  const MapTileStyle(this.label, this.url, this.subdomains);
}
