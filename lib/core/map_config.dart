// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_map/flutter_map.dart';

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
