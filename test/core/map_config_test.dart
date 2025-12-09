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
