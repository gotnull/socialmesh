// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/map_config.dart';

void main() {
  group('MapConfig', () {
    test('has default subdomains', () {
      expect(MapConfig.defaultSubdomains, ['a', 'b', 'c', 'd']);
    });

    test('has user agent package name', () {
      expect(MapConfig.userAgentPackageName, 'com.socialmesh.app');
    });

    test('has default location (Sydney)', () {
      expect(MapConfig.defaultLat, -33.8688);
      expect(MapConfig.defaultLon, 151.2093);
    });

    test('has correct zoom levels', () {
      expect(MapConfig.defaultZoom, 13.0);
      expect(MapConfig.minZoom, 3.0);
      expect(MapConfig.maxZoom, 18.0);
    });

    test('minZoom is less than defaultZoom', () {
      expect(MapConfig.minZoom, lessThan(MapConfig.defaultZoom));
    });

    test('defaultZoom is less than maxZoom', () {
      expect(MapConfig.defaultZoom, lessThan(MapConfig.maxZoom));
    });

    group('clusterDisableZoom', () {
      test('terrain separates one level earlier than other styles', () {
        // Terrain tiles top out at native z17, so clusters disable at z14 —
        // a level earlier than the z15 the higher-zoom styles use, giving
        // clusters room to open before the user runs out of usable zoom.
        expect(MapConfig.clusterDisableZoom(MapTileStyle.terrain), 14);
        expect(MapConfig.clusterDisableZoom(MapTileStyle.satellite), 15);
        expect(MapConfig.clusterDisableZoom(MapTileStyle.dark), 15);
        expect(MapConfig.clusterDisableZoom(MapTileStyle.light), 15);
      });

      test('never reaches the interactive ceiling or the tile ceiling', () {
        for (final style in MapTileStyle.values) {
          final z = MapConfig.clusterDisableZoom(style);
          // Clusters must be able to disable below the deepest reachable zoom.
          expect(z, lessThan(MapConfig.maxZoom));
          // And at least one unclustered level must exist before the tiles
          // stop, so clusters never cling past where the map can refine.
          expect(z, lessThan(style.maxNativeZoom));
        }
      });

      test('caps at the intended default for high-zoom styles', () {
        for (final style in MapTileStyle.values) {
          expect(
            MapConfig.clusterDisableZoom(style),
            lessThanOrEqualTo(MapConfig.defaultClusterDisableZoom),
          );
        }
      });
    });

    test('darkTileLayer returns TileLayer', () {
      final layer = MapConfig.darkTileLayer();
      expect(layer, isNotNull);
      expect(layer.urlTemplate, MapTileStyle.dark.url);
    });

    test('tileLayerForStyle returns correct layer', () {
      for (final style in MapTileStyle.values) {
        final layer = MapConfig.tileLayerForStyle(style);
        expect(layer, isNotNull);
        expect(layer.urlTemplate, style.url);
      }
    });

    group('Mapbox tile provider', () {
      // dotenv is not loaded in unit tests, so AppFeatureFlags.isMapboxEnabled
      // returns false by default — Mapbox is inactive. These tests pin that
      // contract so the rest of the app cannot accidentally start hitting the
      // Mapbox endpoint just because the feature was wired in.
      test('inactive by default in tests (no dotenv loaded)', () {
        expect(MapConfig.isMapboxActive, isFalse);
      });

      test('mapboxUrlForStyle returns null when Mapbox is inactive', () {
        for (final style in MapTileStyle.values) {
          expect(
            MapConfig.mapboxUrlForStyle(style, satelliteLabelsOn: true),
            isNull,
          );
          expect(
            MapConfig.mapboxUrlForStyle(style, satelliteLabelsOn: false),
            isNull,
          );
        }
      });

      test('attribution short form matches Mapbox + OSM TOS', () {
        expect(MapConfig.mapboxAttributionLabel, '© Mapbox © OpenStreetMap');
        expect(
          MapConfig.mapboxAttributionUrl,
          startsWith('https://www.mapbox.com/'),
        );
      });
    });

    group('satellite reference labels overlay', () {
      test('url is a transparent Esri reference layer', () {
        expect(MapConfig.satelliteReferenceLabelsUrl, startsWith('https://'));
        expect(
          MapConfig.satelliteReferenceLabelsUrl,
          contains('arcgisonline.com'),
        );
        expect(
          MapConfig.satelliteReferenceLabelsUrl,
          contains('Reference/World_Boundaries_and_Places'),
        );
        expect(MapConfig.satelliteReferenceLabelsUrl, contains('{z}'));
        expect(MapConfig.satelliteReferenceLabelsUrl, contains('{x}'));
        expect(MapConfig.satelliteReferenceLabelsUrl, contains('{y}'));
      });

      test('attribution short form matches base imagery', () {
        expect(MapConfig.satelliteReferenceLabelsAttribution, '© Esri');
      });

      test('factory builds a TileLayer with the overlay url', () {
        final overlay = MapConfig.satelliteReferenceLabelsTileLayer();
        expect(overlay, isNotNull);
        expect(overlay.urlTemplate, MapConfig.satelliteReferenceLabelsUrl);
      });
    });
  });

  group('MapTileStyle', () {
    test('has all expected values', () {
      expect(MapTileStyle.values.length, 4);
      expect(MapTileStyle.values, contains(MapTileStyle.dark));
      expect(MapTileStyle.values, contains(MapTileStyle.satellite));
      expect(MapTileStyle.values, contains(MapTileStyle.terrain));
      expect(MapTileStyle.values, contains(MapTileStyle.light));
    });

    group('dark', () {
      test('has correct properties', () {
        expect(MapTileStyle.dark.label, 'Dark');
        expect(MapTileStyle.dark.url, contains('cartocdn.com'));
        expect(MapTileStyle.dark.url, contains('dark_all'));
        expect(MapTileStyle.dark.subdomains, ['a', 'b', 'c', 'd']);
      });

      test('url contains placeholders', () {
        expect(MapTileStyle.dark.url, contains('{s}'));
        expect(MapTileStyle.dark.url, contains('{z}'));
        expect(MapTileStyle.dark.url, contains('{x}'));
        expect(MapTileStyle.dark.url, contains('{y}'));
      });
    });

    group('satellite', () {
      test('has correct properties', () {
        expect(MapTileStyle.satellite.label, 'Satellite');
        expect(MapTileStyle.satellite.url, contains('arcgisonline.com'));
        expect(MapTileStyle.satellite.url, contains('World_Imagery'));
        expect(MapTileStyle.satellite.subdomains, isEmpty);
      });

      test('url contains placeholders', () {
        expect(MapTileStyle.satellite.url, contains('{z}'));
        expect(MapTileStyle.satellite.url, contains('{x}'));
        expect(MapTileStyle.satellite.url, contains('{y}'));
      });
    });

    group('terrain', () {
      test('has correct properties', () {
        expect(MapTileStyle.terrain.label, 'Terrain');
        expect(MapTileStyle.terrain.url, contains('opentopomap.org'));
        expect(MapTileStyle.terrain.subdomains, ['a', 'b', 'c']);
      });
    });

    group('light', () {
      test('has correct properties', () {
        expect(MapTileStyle.light.label, 'Light');
        expect(MapTileStyle.light.url, contains('cartocdn.com'));
        expect(MapTileStyle.light.url, contains('light_all'));
        expect(MapTileStyle.light.subdomains, ['a', 'b', 'c', 'd']);
      });
    });

    test('all styles have non-empty labels', () {
      for (final style in MapTileStyle.values) {
        expect(style.label, isNotEmpty);
      }
    });

    test('all styles have valid URLs', () {
      for (final style in MapTileStyle.values) {
        expect(style.url, startsWith('https://'));
        expect(style.url, contains('{z}'));
        expect(style.url, contains('{x}'));
        expect(style.url, contains('{y}'));
      }
    });
  });
}
