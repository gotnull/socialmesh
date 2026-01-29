import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/route.dart';
import 'package:socialmesh/services/storage/route_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late RouteStorageService service;

  setUpAll(() {
    // Initialize FFI for testing
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Use in-memory database for testing
    service = RouteStorageService(testDbPath: inMemoryDatabasePath);
    await service.init();
    // Clear any existing data
    await service.clearAllRoutes();
  });

  tearDown(() async {
    await service.clearAllRoutes();
  });

  group('RouteStorageService', () {
    test('getRoutes returns empty list when no routes saved', () async {
      final routes = await service.getRoutes();
      expect(routes, isEmpty);
    });

    test('saveRoute saves a new route', () async {
      final route = Route(
        id: 'route1',
        name: 'Test Route',
        notes: 'Test notes',
        color: 0xFF00FF00,
      );

      await service.saveRoute(route);
      final routes = await service.getRoutes();

      expect(routes.length, 1);
      expect(routes.first.id, 'route1');
      expect(routes.first.name, 'Test Route');
      expect(routes.first.notes, 'Test notes');
    });

    test('saveRoute updates existing route', () async {
      final route = Route(id: 'route1', name: 'Original Name');

      await service.saveRoute(route);

      final updatedRoute = route.copyWith(name: 'Updated Name');
      await service.saveRoute(updatedRoute);

      final routes = await service.getRoutes();

      expect(routes.length, 1);
      expect(routes.first.name, 'Updated Name');
    });

    test('deleteRoute removes route', () async {
      final route1 = Route(id: 'route1', name: 'Route 1');
      final route2 = Route(id: 'route2', name: 'Route 2');

      await service.saveRoute(route1);
      await service.saveRoute(route2);

      await service.deleteRoute('route1');

      final routes = await service.getRoutes();
      expect(routes.length, 1);
      expect(routes.first.id, 'route2');
    });

    test('clearAllRoutes removes all routes', () async {
      final route1 = Route(id: 'route1', name: 'Route 1');
      final route2 = Route(id: 'route2', name: 'Route 2');

      await service.saveRoute(route1);
      await service.saveRoute(route2);
      await service.clearAllRoutes();

      final routes = await service.getRoutes();
      expect(routes, isEmpty);
    });

    test('active route operations work correctly', () async {
      expect(await service.getActiveRoute(), isNull);

      final route = Route(name: 'Recording Route');
      await service.setActiveRoute(route);

      final active = await service.getActiveRoute();
      expect(active, isNotNull);
      expect(active!.name, 'Recording Route');

      await service.setActiveRoute(null);
      expect(await service.getActiveRoute(), isNull);
    });

    test('addLocationToActiveRoute adds location', () async {
      final route = Route(name: 'Recording Route');
      await service.setActiveRoute(route);

      final location = RouteLocation(
        latitude: 37.7749,
        longitude: -122.4194,
        altitude: 10,
      );

      final updated = await service.addLocationToActiveRoute(location);

      expect(updated, isNotNull);
      expect(updated!.locations.length, 1);
      expect(updated.locations.first.latitude, 37.7749);
    });

    test(
      'addLocationToActiveRoute returns null when no active route',
      () async {
        final location = RouteLocation(latitude: 37.7749, longitude: -122.4194);
        final result = await service.addLocationToActiveRoute(location);
        expect(result, isNull);
      },
    );
  });

  group('GPX Export', () {
    test('exportRouteAsGpx generates valid GPX', () {
      final route = Route(
        name: 'Test Route',
        notes: 'Test description',
        locations: [
          RouteLocation(latitude: 37.7749, longitude: -122.4194, altitude: 10),
          RouteLocation(latitude: 37.7750, longitude: -122.4195),
        ],
      );

      final gpx = service.exportRouteAsGpx(route);

      expect(gpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(gpx, contains('<gpx version="1.1"'));
      expect(gpx, contains('<name>Test Route</name>'));
      expect(gpx, contains('<desc>Test description</desc>'));
      expect(gpx, contains('lat="37.7749"'));
      expect(gpx, contains('lon="-122.4194"'));
      expect(gpx, contains('<ele>10</ele>'));
    });

    test('exportRouteAsGpx escapes XML special characters', () {
      final route = Route(
        name: 'Route <with> & "special" \'chars\'',
        notes: null,
        locations: [],
      );

      final gpx = service.exportRouteAsGpx(route);

      expect(gpx, contains('&lt;with&gt;'));
      expect(gpx, contains('&amp;'));
      expect(gpx, contains('&quot;special&quot;'));
      expect(gpx, contains('&apos;chars&apos;'));
    });

    test('exportRouteAsGpx handles route without notes', () {
      final route = Route(name: 'Simple Route', notes: null, locations: []);

      final gpx = service.exportRouteAsGpx(route);

      expect(gpx, isNot(contains('<desc>')));
    });
  });

  group('GPX Import', () {
    test('importRouteFromGpx parses valid GPX with full trackpoints', () {
      const gpx = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <metadata>
    <name>Imported Route</name>
    <desc>Test description</desc>
  </metadata>
  <trk>
    <trkseg>
      <trkpt lat="37.7749" lon="-122.4194">
        <ele>10</ele>
        <time>2024-01-01T12:00:00Z</time>
      </trkpt>
      <trkpt lat="37.7750" lon="-122.4195">
        <ele>15</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>''';

      final route = service.importRouteFromGpx(gpx);

      expect(route, isNotNull);
      expect(route!.name, 'Imported Route');
      expect(route.notes, 'Test description');
      expect(route.locations.length, 2);
      expect(route.locations.first.latitude, 37.7749);
      expect(route.locations.first.altitude, 10);
    });

    test('importRouteFromGpx parses self-closing trackpoints', () {
      const gpx = '''<?xml version="1.0"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="37.7749" lon="-122.4194" />
      <trkpt lat="37.7750" lon="-122.4195" />
    </trkseg>
  </trk>
</gpx>''';

      final route = service.importRouteFromGpx(gpx);

      expect(route, isNotNull);
      expect(route!.locations.length, 2);
    });

    test('importRouteFromGpx parses waypoints when no trackpoints', () {
      const gpx = '''<?xml version="1.0"?>
<gpx version="1.1">
  <wpt lat="37.7749" lon="-122.4194">
    <ele>10</ele>
  </wpt>
  <wpt lat="37.7750" lon="-122.4195">
    <ele>15</ele>
  </wpt>
</gpx>''';

      final route = service.importRouteFromGpx(gpx);

      expect(route, isNotNull);
      expect(route!.locations.length, 2);
      expect(route.locations.first.altitude, 10);
    });

    test('importRouteFromGpx returns null for empty GPX', () {
      const gpx = '''<?xml version="1.0"?>
<gpx version="1.1">
</gpx>''';

      final route = service.importRouteFromGpx(gpx);
      expect(route, isNull);
    });

    test('importRouteFromGpx uses default name when none provided', () {
      const gpx = '''<?xml version="1.0"?>
<gpx version="1.1">
  <trk>
    <trkseg>
      <trkpt lat="37.7749" lon="-122.4194" />
    </trkseg>
  </trk>
</gpx>''';

      final route = service.importRouteFromGpx(gpx);

      expect(route, isNotNull);
      expect(route!.name, 'Imported Route');
    });

    test('importRouteFromGpx handles invalid GPX gracefully', () {
      const invalidGpx = 'not valid xml at all';
      final route = service.importRouteFromGpx(invalidGpx);
      // Should not throw, just return null
      expect(route, isNull);
    });
  });
}
