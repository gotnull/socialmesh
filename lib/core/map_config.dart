// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_map/flutter_map.dart';

import 'constants.dart';
import 'logging.dart';
import 'safe_lat_lng.dart';

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

  /// Minimum interactive zoom for the live mesh map. Kept low enough that
  /// "fit all" can zoom out to frame globally-distributed nodes: a radio with
  /// an MQTT uplink learns positions worldwide, so the bounding box of all
  /// nodes can span continents. flutter_map's `CameraFit.fit` clamps its
  /// computed zoom up to the camera's minimum, so a higher floor here strands
  /// the camera on the empty centroid of that box with every node off-screen.
  /// Distinct from [minZoom], which scopes the offline-tile download range.
  static const double liveMapMinZoom = 2.0;

  /// Zoom at or below which marker clusters stay merged. Wired into
  /// [MarkerClusterLayerOptions.disableClusteringAtZoom].
  ///
  /// flutter_map_marker_cluster builds its cluster tree down to the camera's
  /// max zoom and asserts that no cluster node deeper than this value is ever
  /// traversed — so this MUST be at least the camera's max zoom. (Its own
  /// defaults encode the same contract: disableClusteringAtZoom 20 vs maxZoom
  /// 17.) Co-located nodes share identical coordinates and therefore cluster at
  /// every level up to the max, so any value below the camera ceiling crashes
  /// the moment the user zooms past it onto a stacked marker. Returning the
  /// camera max keeps clusters intact for genuinely co-located nodes while
  /// markers that exceed `maxClusterRadius` still separate naturally.
  static int clusterDisableZoom(MapTileStyle style) => maxZoom.floor();

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

  /// Whether a style serves true `@2x` retina tiles (URL carries the `{r}`
  /// placeholder). Enabling retina for a source WITHOUT `{r}` makes flutter_map
  /// "simulate" retina via a zoom offset, which (a) costs extra tile requests
  /// and (b) shifts the requested tile coordinates — breaking parity between
  /// what the live map fetches and what the offline downloader pre-seeds. So
  /// retina is gated strictly on real server support.
  static bool styleSupportsRetina(MapTileStyle style) =>
      style.url.contains('{r}');

  /// Create a TileLayer with the default dark style, resolved through the
  /// same provider chain as the live map widgets.
  static TileLayer darkTileLayer() => tileLayerForStyle(MapTileStyle.dark);

  /// Create a TileLayer for a given style. URL, subdomains, native zoom and
  /// retina mode all resolve through [urlForStyle] and its siblings so the
  /// layer never leaks a keyless CARTO URL, or a raw OpenTopoMap URL, when a
  /// keyed provider is configured.
  static TileLayer tileLayerForStyle(MapTileStyle style) {
    return TileLayer(
      urlTemplate: urlForStyle(style, satelliteLabelsOn: false),
      subdomains: subdomainsForStyle(style),
      maxNativeZoom: maxNativeZoomForStyle(style),
      retinaMode: resolvedRetinaMode(style, satelliteLabelsOn: false),
      userAgentPackageName: userAgentPackageName,
      evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
      errorTileCallback: _onTileError,
      tileUpdateTransformer: finiteCameraTileUpdateTransformer,
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
      tileUpdateTransformer: finiteCameraTileUpdateTransformer,
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

  /// True when a MapTiler key is present. Gates the terrain basemap onto
  /// MapTiler Outdoor (real `@2x` tiles) instead of OpenTopoMap (1x only).
  /// No feature flag — presence of the key is the switch.
  static bool get isMaptilerActive => AppUrls.maptilerToken.isNotEmpty;

  /// MapTiler Outdoor raster URL for the terrain style, or null when no key is
  /// configured. The `{r}` placeholder makes flutter_map request true `@2x`
  /// tiles via its server-retina path (coordinates unchanged), so offline-cache
  /// parity holds. 256-tile path matches flutter_map's default `tileSize`.
  static String? maptilerTerrainUrl() {
    if (!isMaptilerActive) return null;
    final key = AppUrls.maptilerToken;
    return 'https://api.maptiler.com/maps/outdoor-v2/256/{z}/{x}/{y}{r}.png?key=$key';
  }

  // MapTiler TOS requires the © MapTiler + © OpenStreetMap line plus a link to
  // the copyright page.
  static const String maptilerAttributionLabel =
      '© MapTiler © OpenStreetMap contributors';
  static const String maptilerAttributionUrl =
      'https://www.maptiler.com/copyright/';

  /// True when a CARTO basemaps API key is present. CARTO still serves its
  /// raster basemaps without a key but overlays an "API key required"
  /// watermark on every tile, so the key is what makes dark / light render
  /// clean. No feature flag: presence of the key is the switch, as for
  /// MapTiler.
  static bool get isCartoKeyActive => AppUrls.cartoApiKey.isNotEmpty;

  /// Whether [style] is served from CARTO's raster basemaps.
  static bool isCartoStyle(MapTileStyle style) =>
      style == MapTileStyle.dark || style == MapTileStyle.light;

  /// [style]'s CARTO URL with the API key appended as a `key` query
  /// parameter, or null when [style] is not a CARTO basemap or no key is
  /// configured. The query string sits after the `{r}` placeholder, so
  /// flutter_map's `@2x` substitution is untouched and the offline cache key
  /// (a hash of the resolved URL) is the same one the live map requests.
  static String? cartoUrlForStyle(MapTileStyle style) {
    if (!isCartoStyle(style) || !isCartoKeyActive) return null;
    final key = Uri.encodeQueryComponent(AppUrls.cartoApiKey);
    return '${style.url}?key=$key';
  }

  /// Resolved tile URL for a style: Mapbox when active, else MapTiler for
  /// terrain when active, else CARTO with its API key for dark / light when a
  /// key is configured, else the style's own template. Single source of truth
  /// so map widgets stop hand-writing `mapboxUrlForStyle(...) ?? style.url`.
  static String urlForStyle(
    MapTileStyle style, {
    required bool satelliteLabelsOn,
  }) {
    final mapbox = mapboxUrlForStyle(
      style,
      satelliteLabelsOn: satelliteLabelsOn,
    );
    if (mapbox != null) return mapbox;
    if (style == MapTileStyle.terrain) {
      final maptiler = maptilerTerrainUrl();
      if (maptiler != null) return maptiler;
    }
    final carto = cartoUrlForStyle(style);
    if (carto != null) return carto;
    return style.url;
  }

  /// Subdomains for the resolved URL. Mapbox and MapTiler URLs carry no `{s}`
  /// placeholder, so they must be served subdomain-less.
  static List<String> subdomainsForStyle(MapTileStyle style) {
    if (isMapboxActive) return const <String>[];
    if (style == MapTileStyle.terrain && isMaptilerActive) {
      return const <String>[];
    }
    return style.subdomains;
  }

  /// Whether the resolved URL serves real `@2x` tiles (carries `{r}`). True for
  /// Mapbox, CARTO dark/light, and MapTiler terrain; false for raw OpenTopoMap
  /// and Esri satellite. Replaces the inline `isMapboxActive ? true : ...`.
  static bool resolvedRetinaMode(
    MapTileStyle style, {
    required bool satelliteLabelsOn,
  }) =>
      urlForStyle(style, satelliteLabelsOn: satelliteLabelsOn).contains('{r}');

  /// Highest zoom the resolved source actually serves. Mapbox styles serve
  /// deeper than the interaction cap; MapTiler Outdoor serves to z22 so its
  /// terrain no longer overzooms at the old z17 native cap.
  static int maxNativeZoomForStyle(MapTileStyle style) {
    if (isMapboxActive) return 18;
    if (style == MapTileStyle.terrain && isMaptilerActive) return 20;
    return style.maxNativeZoom;
  }

  /// Attribution label for the resolved source.
  static String attributionLabel(
    MapTileStyle style, {
    required bool satelliteLabelsOn,
  }) {
    if (isMapboxActive) return mapboxAttributionLabel;
    switch (style) {
      case MapTileStyle.satellite:
        return '© Esri';
      case MapTileStyle.terrain:
        return isMaptilerActive
            ? maptilerAttributionLabel
            : '© OpenTopoMap © OSM';
      case MapTileStyle.dark:
      case MapTileStyle.light:
        return '© OSM © CARTO';
    }
  }

  /// Attribution link for the resolved source.
  static String attributionUrl(
    MapTileStyle style, {
    required bool satelliteLabelsOn,
  }) {
    if (isMapboxActive) return mapboxAttributionUrl;
    switch (style) {
      case MapTileStyle.satellite:
        return 'https://www.esri.com';
      case MapTileStyle.terrain:
        return isMaptilerActive
            ? maptilerAttributionUrl
            : 'https://opentopomap.org';
      case MapTileStyle.dark:
      case MapTileStyle.light:
        return 'https://carto.com/attributions';
    }
  }
}

/// Map tile style options.
///
/// [maxNativeZoom] is the highest zoom level the tile server actually serves.
/// Setting it below the interaction [MapConfig.maxZoom] lets flutter_map
/// "overzoom" — upscaling the last real tiles — instead of requesting
/// non-existent tiles (which return a server placeholder, e.g. OpenTopoMap's
/// "max zoom layer 17" error image).
enum MapTileStyle {
  // CARTO templates are keyless here; MapConfig.cartoUrlForStyle appends the
  // API key at resolve time so the key never sits in a const.
  dark(
    'Dark',
    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
    ['a', 'b', 'c', 'd'],
    // CARTO basemaps serve to z20.
    maxNativeZoom: 20,
  ),
  satellite(
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    [], // No subdomains
    // Esri World_Imagery serves to z19 across most regions.
    maxNativeZoom: 19,
  ),
  terrain(
    'Terrain',
    'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    ['a', 'b', 'c'],
    // OpenTopoMap only serves to z17; beyond that flutter_map upscales.
    maxNativeZoom: 17,
  ),
  light(
    'Light',
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
    ['a', 'b', 'c', 'd'],
    // CARTO basemaps serve to z20.
    maxNativeZoom: 20,
  );

  final String label;
  final String url;
  final List<String> subdomains;
  final int maxNativeZoom;

  const MapTileStyle(
    this.label,
    this.url,
    this.subdomains, {
    required this.maxNativeZoom,
  });
}
