import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/route.dart';

void main() {
  group('Route', () {
    test('creates with default values', () {
      final route = Route(name: 'Test Route');

      expect(route.name, 'Test Route');
      expect(route.id, isNotEmpty);
      expect(route.notes, isNull);
      expect(route.endedAt, isNull);
      expect(route.color, 0xFF33C758);
      expect(route.enabled, true);
      expect(route.locations, isEmpty);
    });

    test('calculates total distance for empty route', () {
      final route = Route(name: 'Empty');
      expect(route.totalDistance, 0);
    });

    test('calculates total distance for single location', () {
      final route = Route(
        name: 'Single',
        locations: [RouteLocation(latitude: -33.8688, longitude: 151.2093)],
      );
      expect(route.totalDistance, 0);
    });

    test('calculates total distance for multiple locations', () {
      final route = Route(
        name: 'Sydney to Nearby',
        locations: [
          RouteLocation(latitude: -33.8688, longitude: 151.2093), // Sydney
          RouteLocation(latitude: -33.8500, longitude: 151.2000), // ~2.3km away
        ],
      );
      // Haversine distance should be approximately 2300 meters
      expect(route.totalDistance, greaterThan(2000));
      expect(route.totalDistance, lessThan(3000));
    });

    test('calculates duration when endedAt is set', () {
      final start = DateTime(2024, 1, 1, 10, 0);
      final end = DateTime(2024, 1, 1, 12, 30);
      final route = Route(name: 'Timed', createdAt: start, endedAt: end);

      expect(route.duration, const Duration(hours: 2, minutes: 30));
    });

    test('duration is null when endedAt is null', () {
      final route = Route(name: 'Ongoing');
      expect(route.duration, isNull);
    });

    test('calculates elevation gain', () {
      final route = Route(
        name: 'Hilly',
        locations: [
          RouteLocation(latitude: 0, longitude: 0, altitude: 100),
          RouteLocation(latitude: 0, longitude: 0, altitude: 150), // +50
          RouteLocation(
            latitude: 0,
            longitude: 0,
            altitude: 120,
          ), // -30 (ignored)
          RouteLocation(latitude: 0, longitude: 0, altitude: 200), // +80
        ],
      );
      expect(route.elevationGain, 130); // 50 + 80
    });

    test('elevation gain is zero for empty route', () {
      final route = Route(name: 'Empty');
      expect(route.elevationGain, 0);
    });

    test('calculates center point', () {
      final route = Route(
        name: 'Centered',
        locations: [
          RouteLocation(latitude: -34.0, longitude: 151.0),
          RouteLocation(latitude: -33.0, longitude: 152.0),
        ],
      );

      final center = route.center;
      expect(center, isNotNull);
      expect(center!.lat, -33.5);
      expect(center.lon, 151.5);
    });

    test('center is null for empty route', () {
      final route = Route(name: 'Empty');
      expect(route.center, isNull);
    });

    test('copyWith preserves unmodified values', () {
      final original = Route(
        name: 'Original',
        notes: 'Test notes',
        color: 0xFF0000FF,
        enabled: true,
      );

      final copied = original.copyWith(name: 'Modified');

      expect(copied.name, 'Modified');
      expect(copied.notes, 'Test notes');
      expect(copied.color, 0xFF0000FF);
      expect(copied.enabled, true);
      expect(copied.id, original.id);
    });

    test('serializes to JSON', () {
      final route = Route(
        id: 'test-id',
        name: 'Test Route',
        notes: 'Some notes',
        color: 0xFF0000FF,
        enabled: false,
        locations: [
          RouteLocation(
            id: 'loc-1',
            latitude: -33.8688,
            longitude: 151.2093,
            altitude: 100,
          ),
        ],
      );

      final json = route.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test Route');
      expect(json['notes'], 'Some notes');
      expect(json['color'], 0xFF0000FF);
      expect(json['enabled'], false);
      expect(json['locations'], isA<List>());
      expect((json['locations'] as List).length, 1);
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'json-id',
        'name': 'JSON Route',
        'notes': 'JSON notes',
        'createdAt': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'endedAt': DateTime(2024, 1, 2).millisecondsSinceEpoch,
        'color': 0xFFFF0000,
        'enabled': true,
        'locations': [
          {
            'id': 'loc-1',
            'latitude': -33.8688,
            'longitude': 151.2093,
            'altitude': 50,
            'heading': 180,
            'speed': 10,
            'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
          },
        ],
      };

      final route = Route.fromJson(json);

      expect(route.id, 'json-id');
      expect(route.name, 'JSON Route');
      expect(route.notes, 'JSON notes');
      expect(route.color, 0xFFFF0000);
      expect(route.enabled, true);
      expect(route.locations.length, 1);
      expect(route.locations.first.latitude, -33.8688);
      expect(route.locations.first.altitude, 50);
    });

    test('roundtrip JSON serialization', () {
      final original = Route(
        name: 'Roundtrip',
        notes: 'Test roundtrip',
        locations: [
          RouteLocation(latitude: -33.8688, longitude: 151.2093, altitude: 100),
          RouteLocation(latitude: -33.8700, longitude: 151.2100, altitude: 110),
        ],
      );

      final json = original.toJson();
      final restored = Route.fromJson(json);

      expect(restored.name, original.name);
      expect(restored.notes, original.notes);
      expect(restored.locations.length, original.locations.length);
      expect(
        restored.locations.first.latitude,
        original.locations.first.latitude,
      );
    });
  });

  group('RouteLocation', () {
    test('creates with default values', () {
      final location = RouteLocation(latitude: -33.8688, longitude: 151.2093);

      expect(location.id, isNotEmpty);
      expect(location.latitude, -33.8688);
      expect(location.longitude, 151.2093);
      expect(location.altitude, isNull);
      expect(location.heading, isNull);
      expect(location.speed, isNull);
      expect(location.timestamp, isNotNull);
    });

    test('serializes to JSON', () {
      final location = RouteLocation(
        id: 'loc-id',
        latitude: -33.8688,
        longitude: 151.2093,
        altitude: 100,
        heading: 90,
        speed: 5,
      );

      final json = location.toJson();

      expect(json['id'], 'loc-id');
      expect(json['latitude'], -33.8688);
      expect(json['longitude'], 151.2093);
      expect(json['altitude'], 100);
      expect(json['heading'], 90);
      expect(json['speed'], 5);
      expect(json['timestamp'], isA<int>());
    });

    test('deserializes from JSON', () {
      final json = {
        'id': 'loc-id',
        'latitude': -33.8688,
        'longitude': 151.2093,
        'altitude': 50,
        'heading': 180,
        'speed': 10,
        'timestamp': DateTime(2024, 1, 1).millisecondsSinceEpoch,
      };

      final location = RouteLocation.fromJson(json);

      expect(location.id, 'loc-id');
      expect(location.latitude, -33.8688);
      expect(location.longitude, 151.2093);
      expect(location.altitude, 50);
      expect(location.heading, 180);
      expect(location.speed, 10);
    });

    test('handles numeric types in JSON', () {
      final json = {
        'latitude': 33, // int instead of double
        'longitude': 151.0,
      };

      final location = RouteLocation.fromJson(json);

      expect(location.latitude, 33.0);
      expect(location.longitude, 151.0);
    });
  });
}
