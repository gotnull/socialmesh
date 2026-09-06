// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/painting.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
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

    group('terrain fallback', () {
      setUp(MapConfig.resetTerrainFallback);
      tearDown(MapConfig.resetTerrainFallback);

      final maptilerTile = Uri.parse(
        'https://api.maptiler.com/maps/outdoor-v2/256/10/900/600.png?key=x',
      );
      final openTopoTile = Uri.parse(
        'https://a.tile.opentopomap.org/10/900/600.png',
      );

      test('recognises only a 403 from the MapTiler host as a key refusal', () {
        expect(
          MapConfig.isMaptilerKeyRefusal(
            NetworkImageLoadException(statusCode: 403, uri: maptilerTile),
          ),
          isTrue,
        );
        expect(
          MapConfig.isMaptilerKeyRefusal(
            NetworkImageLoadException(statusCode: 500, uri: maptilerTile),
          ),
          isFalse,
          reason: 'a server error is transient, not a refused key',
        );
        expect(
          MapConfig.isMaptilerKeyRefusal(
            NetworkImageLoadException(statusCode: 403, uri: openTopoTile),
          ),
          isFalse,
          reason: 'another host refusing a request must not move terrain',
        );
        expect(
          MapConfig.isMaptilerKeyRefusal(const FormatException('bad png')),
          isFalse,
        );
      });

      test('starts inactive and arms once', () {
        expect(MapConfig.terrainFallbackActive.value, isFalse);
        var notifications = 0;
        void count() => notifications++;
        MapConfig.terrainFallbackActive.addListener(count);
        addTearDown(
          () => MapConfig.terrainFallbackActive.removeListener(count),
        );

        MapConfig.activateTerrainFallback();
        MapConfig.activateTerrainFallback();

        expect(MapConfig.terrainFallbackActive.value, isTrue);
        expect(notifications, 1, reason: 'a repeat refusal must not re-notify');
      });

      test('moves terrain onto OpenTopoMap while active', () {
        dotenv.loadFromString(envString: 'MAPTILER_TOKEN=test-key');
        addTearDown(dotenv.clean);

        expect(MapConfig.isMaptilerActive, isTrue);
        expect(
          MapConfig.urlForStyle(MapTileStyle.terrain, satelliteLabelsOn: false),
          contains(MapConfig.maptilerHost),
        );
        expect(MapConfig.maxNativeZoomForStyle(MapTileStyle.terrain), 20);

        MapConfig.activateTerrainFallback();

        expect(MapConfig.isMaptilerActive, isFalse);
        expect(
          MapConfig.urlForStyle(MapTileStyle.terrain, satelliteLabelsOn: false),
          MapTileStyle.terrain.url,
        );
        expect(
          MapConfig.subdomainsForStyle(MapTileStyle.terrain),
          MapTileStyle.terrain.subdomains,
        );
        expect(
          MapConfig.maxNativeZoomForStyle(MapTileStyle.terrain),
          MapTileStyle.terrain.maxNativeZoom,
        );
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
        // Other styles are untouched by a MapTiler refusal.
        expect(
          MapConfig.urlForStyle(MapTileStyle.dark, satelliteLabelsOn: false),
          isNot(contains(MapConfig.maptilerHost)),
        );
      });

      test('tile provider does not decode HTTP error bodies', () {
        final provider = MapConfig.networkTileProvider();
        expect(provider, isA<NetworkTileProvider>());
        expect(
          (provider as NetworkTileProvider).attemptDecodeOfHttpErrorResponses,
          isFalse,
          reason:
              'a decoded 403 placeholder would render as a tile and never '
              'reach the error callback that arms the fallback',
        );
      });
    });

    test('has default location (Sydney)', () {
      expect(MapConfig.defaultLat, -33.8688);
      expect(MapConfig.defaultLon, 151.2093);
    });

    test('has correct zoom levels', () {
      expect(MapConfig.defaultZoom, 13.0);
      expect(MapConfig.minZoom, 3.0);
      expect(MapConfig.maxZoom, 18.0);
      expect(MapConfig.verifiedNativeZoomCap, 18);
      expect(MapConfig.liveMapMaxZoom, 21.0);
    });

    test('live camera range encloses the offline download window', () {
      // The camera may zoom deeper than the downloader pre-seeds (overzoom
      // covers the gap), but the downloader must never be asked for a zoom
      // the camera cannot reach.
      expect(MapConfig.liveMapMinZoom, lessThanOrEqualTo(MapConfig.minZoom));
      expect(MapConfig.liveMapMaxZoom, greaterThanOrEqualTo(MapConfig.maxZoom));
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
        // style must therefore disable at or above MapConfig.liveMapMaxZoom.
        for (final style in MapTileStyle.values) {
          expect(
            MapConfig.clusterDisableZoom(style),
            greaterThanOrEqualTo(MapConfig.liveMapMaxZoom.floor()),
          );
        }
      });

      test('matches the live camera max zoom regardless of style', () {
        for (final style in MapTileStyle.values) {
          expect(
            MapConfig.clusterDisableZoom(style),
            MapConfig.liveMapMaxZoom.floor(),
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

      test('maxNativeZoomForStyle caps fallback tile requests', () {
        for (final style in MapTileStyle.values) {
          expect(
            MapConfig.maxNativeZoomForStyle(style),
            style.maxNativeZoom.clamp(0, MapConfig.verifiedNativeZoomCap),
          );
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

    group('CARTO basemaps API key', () {
      // dotenv is not loaded by default in this file, so the key is empty and
      // dark / light resolve to their keyless templates. The keyed cases load
      // dotenv explicitly and clean it again so every other group keeps its
      // "no dotenv" contract regardless of test order.
      tearDown(dotenv.clean);

      test('inactive by default in tests (no dotenv loaded)', () {
        expect(MapConfig.isCartoKeyActive, isFalse);
        for (final style in MapTileStyle.values) {
          expect(MapConfig.cartoUrlForStyle(style), isNull);
        }
      });

      test('isCartoStyle covers exactly dark and light', () {
        expect(MapConfig.isCartoStyle(MapTileStyle.dark), isTrue);
        expect(MapConfig.isCartoStyle(MapTileStyle.light), isTrue);
        expect(MapConfig.isCartoStyle(MapTileStyle.satellite), isFalse);
        expect(MapConfig.isCartoStyle(MapTileStyle.terrain), isFalse);
      });

      test('stays inactive when dotenv is loaded without the key', () {
        dotenv.loadFromString(envString: 'TEST_MODE=true');
        expect(MapConfig.isCartoKeyActive, isFalse);
        expect(
          MapConfig.urlForStyle(MapTileStyle.dark, satelliteLabelsOn: false),
          MapTileStyle.dark.url,
        );
      });

      test('stays inactive when the key is present but blank', () {
        dotenv.loadFromString(envString: 'TEST_MODE=true\nCARTO_API_KEY=');
        expect(MapConfig.isCartoKeyActive, isFalse);
        expect(MapConfig.cartoUrlForStyle(MapTileStyle.dark), isNull);
      });

      test('appends the key to dark and light only', () {
        dotenv.loadFromString(envString: 'CARTO_API_KEY=abc123');
        expect(MapConfig.isCartoKeyActive, isTrue);
        expect(
          MapConfig.urlForStyle(MapTileStyle.dark, satelliteLabelsOn: false),
          '${MapTileStyle.dark.url}?key=abc123',
        );
        expect(
          MapConfig.urlForStyle(MapTileStyle.light, satelliteLabelsOn: false),
          '${MapTileStyle.light.url}?key=abc123',
        );
        expect(
          MapConfig.urlForStyle(
            MapTileStyle.satellite,
            satelliteLabelsOn: false,
          ),
          MapTileStyle.satellite.url,
        );
        expect(
          MapConfig.urlForStyle(MapTileStyle.terrain, satelliteLabelsOn: false),
          MapTileStyle.terrain.url,
        );
      });

      test('key sits after the {r} placeholder so @2x substitution holds', () {
        dotenv.loadFromString(envString: 'CARTO_API_KEY=abc123');
        final url = MapConfig.urlForStyle(
          MapTileStyle.dark,
          satelliteLabelsOn: false,
        );
        expect(url.indexOf('{r}'), lessThan(url.indexOf('?key=')));
        expect(url, endsWith('{r}.png?key=abc123'));
      });

      test('keyed dark / light keep subdomains, retina and capped zoom', () {
        dotenv.loadFromString(envString: 'CARTO_API_KEY=abc123');
        expect(MapConfig.subdomainsForStyle(MapTileStyle.dark), [
          'a',
          'b',
          'c',
          'd',
        ]);
        expect(
          MapConfig.resolvedRetinaMode(
            MapTileStyle.dark,
            satelliteLabelsOn: false,
          ),
          isTrue,
        );
        expect(
          MapConfig.maxNativeZoomForStyle(MapTileStyle.light),
          MapConfig.verifiedNativeZoomCap,
        );
      });

      test('key is query-encoded', () {
        dotenv.loadFromString(envString: 'CARTO_API_KEY=a b&c=d');
        expect(
          MapConfig.cartoUrlForStyle(MapTileStyle.dark),
          endsWith('?key=a+b%26c%3Dd'),
        );
      });

      test('Mapbox wins over the CARTO key when active', () {
        dotenv.loadFromString(
          envString:
              'CARTO_API_KEY=abc123\nMAPBOX_ENABLED=true\nMAPBOX_TOKEN=pk.test',
        );
        expect(
          MapConfig.urlForStyle(MapTileStyle.dark, satelliteLabelsOn: false),
          startsWith('https://api.mapbox.com/'),
        );
      });

      test('tile layer factories carry the key', () {
        dotenv.loadFromString(envString: 'CARTO_API_KEY=abc123');
        expect(MapConfig.darkTileLayer().urlTemplate, endsWith('?key=abc123'));
        expect(
          MapConfig.tileLayerForStyle(MapTileStyle.light).urlTemplate,
          endsWith('?key=abc123'),
        );
        expect(
          MapConfig.tileLayerForStyle(MapTileStyle.satellite).urlTemplate,
          MapTileStyle.satellite.url,
        );
      });

      test('flutter_map resolves a concrete keyed retina tile URL', () {
        // Runs the template through flutter_map's own resolver, the same path
        // the live map and the offline cache key use, so the {s} / {r}
        // substitutions are pinned against the query string. Subdomain index
        // is (x + y) % 4, so (1, 2) lands on 'd'.
        dotenv.loadFromString(envString: 'CARTO_API_KEY=abc123');
        final url = NetworkTileProvider().getTileUrl(
          TileCoordinates(1, 2, 3),
          MapConfig.darkTileLayer(),
        );
        expect(
          url,
          'https://d.basemaps.cartocdn.com/dark_all/3/1/2@2x.png?key=abc123',
        );
      });

      test('attribution is unchanged by the key', () {
        // CARTO's free tier is conditioned on CARTO + OSM attribution staying
        // visible, so the key must never swap the label or link.
        dotenv.loadFromString(envString: 'CARTO_API_KEY=abc123');
        expect(
          MapConfig.attributionLabel(
            MapTileStyle.dark,
            satelliteLabelsOn: false,
          ),
          '© OSM © CARTO',
        );
        expect(
          MapConfig.attributionUrl(
            MapTileStyle.light,
            satelliteLabelsOn: false,
          ),
          'https://carto.com/attributions',
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

      test('factory builds a TileLayer capped at the verified native zoom', () {
        final overlay = MapConfig.satelliteReferenceLabelsTileLayer();
        expect(overlay, isNotNull);
        expect(overlay.urlTemplate, MapConfig.satelliteReferenceLabelsUrl);
        expect(overlay.maxNativeZoom, MapConfig.verifiedNativeZoomCap);
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
