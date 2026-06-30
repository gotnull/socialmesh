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
      test('is at least the camera max zoom for every style', () {
        // flutter_map_marker_cluster builds its tree to the camera max zoom and
        // asserts no cluster node deeper than disableClusteringAtZoom is
        // traversed. Co-located nodes cluster at every level, so a value below
        // the camera ceiling crashes when zooming onto a stacked marker. Every
        // style must therefore disable at or above MapConfig.maxZoom.
        for (final style in MapTileStyle.values) {
          expect(
            MapConfig.clusterDisableZoom(style),
            greaterThanOrEqualTo(MapConfig.maxZoom.floor()),
          );
        }
      });

      test('matches the camera max zoom regardless of style', () {
        for (final style in MapTileStyle.values) {
          expect(
            MapConfig.clusterDisableZoom(style),
            MapConfig.maxZoom.floor(),
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

    group('MapTiler terrain provider', () {
      // dotenv is not loaded in unit tests, so AppUrls.maptilerToken is empty —
      // MapTiler is inactive and terrain falls back to OpenTopoMap. These tests
      // pin that contract and the resolver/attribution wiring.
      test('inactive by default in tests (no dotenv loaded)', () {
        expect(MapConfig.isMaptilerActive, isFalse);
      });

      test('maptilerTerrainUrl returns null when inactive', () {
        expect(MapConfig.maptilerTerrainUrl(), isNull);
      });

      test('attribution short form matches MapTiler + OSM TOS', () {
        expect(
          MapConfig.maptilerAttributionLabel,
          '© MapTiler © OpenStreetMap contributors',
        );
        expect(
          MapConfig.maptilerAttributionUrl,
          startsWith('https://www.maptiler.com/'),
        );
      });
    });

    group('resolved style helpers (MapTiler + Mapbox inactive in tests)', () {
      test('urlForStyle falls back to the raw style url', () {
        for (final style in MapTileStyle.values) {
          expect(
            MapConfig.urlForStyle(style, satelliteLabelsOn: false),
            style.url,
          );
        }
        // Terrain specifically stays on OpenTopoMap without a MapTiler key.
        expect(
          MapConfig.urlForStyle(MapTileStyle.terrain, satelliteLabelsOn: false),
          contains('opentopomap.org'),
        );
      });

      test('subdomainsForStyle returns the raw subdomains', () {
        for (final style in MapTileStyle.values) {
          expect(MapConfig.subdomainsForStyle(style), style.subdomains);
        }
      });

      test('resolvedRetinaMode tracks the {r} placeholder', () {
        // CARTO dark/light carry {r}; OpenTopoMap terrain and Esri satellite
        // do not (until a MapTiler key flips terrain on).
        expect(
          MapConfig.resolvedRetinaMode(
            MapTileStyle.dark,
            satelliteLabelsOn: false,
          ),
          isTrue,
        );
        expect(
          MapConfig.resolvedRetinaMode(
            MapTileStyle.light,
            satelliteLabelsOn: false,
          ),
          isTrue,
        );
        expect(
          MapConfig.resolvedRetinaMode(
            MapTileStyle.terrain,
            satelliteLabelsOn: false,
          ),
          isFalse,
        );
        expect(
          MapConfig.resolvedRetinaMode(
            MapTileStyle.satellite,
            satelliteLabelsOn: false,
          ),
          isFalse,
        );
      });

      test('maxNativeZoomForStyle returns the raw native cap', () {
        for (final style in MapTileStyle.values) {
          expect(MapConfig.maxNativeZoomForStyle(style), style.maxNativeZoom);
        }
      });

      test('attribution helpers map each style to its source', () {
        expect(
          MapConfig.attributionLabel(
            MapTileStyle.terrain,
            satelliteLabelsOn: false,
          ),
          '© OpenTopoMap © OSM',
        );
        expect(
          MapConfig.attributionUrl(
            MapTileStyle.terrain,
            satelliteLabelsOn: false,
          ),
          'https://opentopomap.org',
        );
        expect(
          MapConfig.attributionLabel(
            MapTileStyle.satellite,
            satelliteLabelsOn: false,
          ),
          '© Esri',
        );
        expect(
          MapConfig.attributionLabel(
            MapTileStyle.dark,
            satelliteLabelsOn: false,
          ),
          '© OSM © CARTO',
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
