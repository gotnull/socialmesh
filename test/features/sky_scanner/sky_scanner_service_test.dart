// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/sky_scanner/models/sky_node.dart';
import 'package:socialmesh/features/sky_scanner/services/sky_scanner_service.dart';

void main() {
  group('FlightPosition', () {
    group('constructor', () {
      test('creates instance with all required fields', () {
        final lastUpdate = DateTime(2025, 6, 15, 14, 30);
        final position = FlightPosition(
          callsign: 'UAL123',
          latitude: 34.0522,
          longitude: -118.2437,
          altitude: 10668.0, // ~35,000 feet in meters
          velocity: 250.0, // m/s
          heading: 90.0,
          onGround: false,
          lastUpdate: lastUpdate,
        );

        expect(position.callsign, 'UAL123');
        expect(position.latitude, 34.0522);
        expect(position.longitude, -118.2437);
        expect(position.altitude, 10668.0);
        expect(position.velocity, 250.0);
        expect(position.heading, 90.0);
        expect(position.onGround, false);
        expect(position.lastUpdate, lastUpdate);
      });

      test('handles zero values correctly', () {
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 0.0,
          velocity: 0.0,
          heading: 0.0,
          onGround: true,
          lastUpdate: DateTime.now(),
        );

        expect(position.latitude, 0.0);
        expect(position.longitude, 0.0);
        expect(position.altitude, 0.0);
        expect(position.onGround, true);
      });

      test('handles negative coordinates correctly', () {
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: -33.8688, // Sydney
          longitude: 151.2093,
          altitude: 11000.0,
          velocity: 240.0,
          heading: 270.0,
          onGround: false,
          lastUpdate: DateTime.now(),
        );

        expect(position.latitude, -33.8688);
        expect(position.longitude, 151.2093);
      });
    });

    group('altitudeFeet', () {
      test('converts meters to feet correctly', () {
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 10668.0, // ~35,000 feet
          velocity: 0.0,
          heading: 0.0,
          onGround: false,
          lastUpdate: DateTime.now(),
        );

        // 10668 meters * 3.28084 = ~35,000 feet
        expect(position.altitudeFeet, closeTo(35000, 10));
      });

      test('returns zero for zero altitude', () {
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 0.0,
          velocity: 0.0,
          heading: 0.0,
          onGround: true,
          lastUpdate: DateTime.now(),
        );

        expect(position.altitudeFeet, 0.0);
      });

      test('converts typical cruise altitude correctly', () {
        // FL390 = 39,000 feet = 11,887.2 meters
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 11887.2,
          velocity: 0.0,
          heading: 0.0,
          onGround: false,
          lastUpdate: DateTime.now(),
        );

        expect(position.altitudeFeet, closeTo(39000, 10));
      });
    });

    group('velocityKnots', () {
      test('converts m/s to knots correctly', () {
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 10000.0,
          velocity: 257.0, // m/s, roughly 500 knots
          heading: 0.0,
          onGround: false,
          lastUpdate: DateTime.now(),
        );

        // 257 m/s * 1.94384 = ~499.5 knots
        expect(position.velocityKnots, closeTo(500, 5));
      });

      test('returns zero for stationary aircraft', () {
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 0.0,
          velocity: 0.0,
          heading: 0.0,
          onGround: true,
          lastUpdate: DateTime.now(),
        );

        expect(position.velocityKnots, 0.0);
      });
    });

    group('radioHorizonKm', () {
      test('calculates radio horizon for cruise altitude', () {
        // At 10,668m (35,000 ft), radio horizon should be roughly 370 km
        // Formula: d = 3.57 * sqrt(h) where h is in meters
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 10668.0,
          velocity: 0.0,
          heading: 0.0,
          onGround: false,
          lastUpdate: DateTime.now(),
        );

        final expectedHorizon = 3.57 * math.sqrt(10668.0);
        expect(position.radioHorizonKm, closeTo(expectedHorizon, 0.1));
        expect(position.radioHorizonKm, closeTo(369, 5));
      });

      test('handles zero altitude by using 1 meter minimum', () {
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 0.0,
          velocity: 0.0,
          heading: 0.0,
          onGround: true,
          lastUpdate: DateTime.now(),
        );

        // Should use 1 meter as minimum
        expect(position.radioHorizonKm, closeTo(3.57, 0.01));
      });

      test('handles negative altitude by using 1 meter minimum', () {
        // Negative altitude (below sea level) should still work
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: -100.0,
          velocity: 0.0,
          heading: 0.0,
          onGround: true,
          lastUpdate: DateTime.now(),
        );

        expect(position.radioHorizonKm, closeTo(3.57, 0.01));
      });

      test('calculates for low altitude flight', () {
        // At 3,048m (10,000 ft) - typical approach altitude
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 3048.0,
          velocity: 0.0,
          heading: 0.0,
          onGround: false,
          lastUpdate: DateTime.now(),
        );

        final expectedHorizon = 3.57 * math.sqrt(3048.0);
        expect(position.radioHorizonKm, closeTo(expectedHorizon, 0.1));
        expect(position.radioHorizonKm, closeTo(197, 5));
      });
    });

    group('coverageRadiusKm', () {
      test('returns 80% of radio horizon', () {
        final position = FlightPosition(
          callsign: 'TEST',
          latitude: 0.0,
          longitude: 0.0,
          altitude: 10668.0,
          velocity: 0.0,
          heading: 0.0,
          onGround: false,
          lastUpdate: DateTime.now(),
        );

        expect(
          position.coverageRadiusKm,
          closeTo(position.radioHorizonKm * 0.8, 0.1),
        );
      });
    });
  });

  group('SkyScannerService', () {
    group('calculateDistance', () {
      test('returns zero for same coordinates', () {
        final distance = SkyScannerService.calculateDistance(
          34.0522,
          -118.2437,
          34.0522,
          -118.2437,
        );

        expect(distance, 0.0);
      });

      test('calculates LAX to JFK distance correctly', () {
        // LAX: 33.9425° N, 118.4081° W
        // JFK: 40.6413° N, 73.7781° W
        // Expected distance: ~3,983 km
        final distance = SkyScannerService.calculateDistance(
          33.9425,
          -118.4081,
          40.6413,
          -73.7781,
        );

        expect(distance, closeTo(3983, 50));
      });

      test('calculates London to Sydney distance correctly', () {
        // LHR: 51.4700° N, 0.4543° W
        // SYD: 33.8688° S, 151.2093° E
        // Expected distance: ~16,994 km
        final distance = SkyScannerService.calculateDistance(
          51.4700,
          -0.4543,
          -33.8688,
          151.2093,
        );

        expect(distance, closeTo(16994, 100));
      });

      test('calculates short distance correctly', () {
        // Two points about 1 km apart in Los Angeles
        // Moving roughly 0.009 degrees north = ~1 km
        final distance = SkyScannerService.calculateDistance(
          34.0522,
          -118.2437,
          34.0612,
          -118.2437,
        );

        expect(distance, closeTo(1.0, 0.1));
      });

      test('handles crossing prime meridian', () {
        // London (west of prime meridian) to Paris (east of prime meridian)
        // Expected distance: ~344 km
        final distance = SkyScannerService.calculateDistance(
          51.5074,
          -0.1278,
          48.8566,
          2.3522,
        );

        expect(distance, closeTo(344, 10));
      });

      test('handles crossing equator', () {
        // Quito, Ecuador (near equator) to Bogota, Colombia
        // Expected distance: ~714 km
        final distance = SkyScannerService.calculateDistance(
          -0.1807,
          -78.4678,
          4.7110,
          -74.0721,
        );

        expect(distance, closeTo(714, 20));
      });

      test('handles crossing international date line', () {
        // Fiji to Samoa (crossing date line)
        // Expected distance: ~1,152 km
        final distance = SkyScannerService.calculateDistance(
          -18.1416,
          178.4419,
          -13.8333,
          -171.7500,
        );

        expect(distance, closeTo(1152, 10));
      });

      test('handles antipodal points', () {
        // Points on opposite sides of Earth (max distance ~20,000 km)
        final distance = SkyScannerService.calculateDistance(
          0.0,
          0.0,
          0.0,
          180.0,
        );

        // Half Earth circumference at equator ~20,000 km
        expect(distance, closeTo(20015, 50));
      });

      test('is symmetric', () {
        final distanceAtoB = SkyScannerService.calculateDistance(
          34.0522,
          -118.2437,
          40.7128,
          -74.0060,
        );

        final distanceBtoA = SkyScannerService.calculateDistance(
          40.7128,
          -74.0060,
          34.0522,
          -118.2437,
        );

        expect(distanceAtoB, distanceBtoA);
      });
    });

    group('calculateSlantRange', () {
      test('equals ground distance when altitudes are equal', () {
        final groundDistance = SkyScannerService.calculateDistance(
          34.0522,
          -118.2437,
          34.1522,
          -118.2437,
        );

        final slantRange = SkyScannerService.calculateSlantRange(
          34.0522,
          -118.2437,
          100.0, // 100m altitude
          34.1522,
          -118.2437,
          100.0, // Same altitude
        );

        expect(slantRange, closeTo(groundDistance, 0.01));
      });

      test('accounts for altitude difference', () {
        // Ground station at sea level, aircraft at 10km altitude directly overhead
        final slantRange = SkyScannerService.calculateSlantRange(
          34.0522,
          -118.2437,
          0.0, // Ground station at sea level
          34.0522,
          -118.2437,
          10000.0, // Aircraft at 10km altitude
        );

        // Distance should be exactly 10km (vertical only)
        expect(slantRange, closeTo(10.0, 0.01));
      });

      test('calculates Pythagorean distance for offset aircraft', () {
        // Ground station at 0m, aircraft at 10km altitude and 10km horizontal distance
        // Expected slant range: sqrt(10^2 + 10^2) = ~14.14 km

        // First calculate what ground distance gives us ~10 km
        // At ~34° latitude, 0.09° ~ 10km
        final groundDistance = SkyScannerService.calculateDistance(
          34.0522,
          -118.2437,
          34.1422,
          -118.2437,
        );

        final slantRange = SkyScannerService.calculateSlantRange(
          34.0522,
          -118.2437,
          0.0, // Ground
          34.1422,
          -118.2437,
          10000.0, // 10km up
        );

        // Slant should be greater than ground distance
        expect(slantRange, greaterThan(groundDistance));

        // Should follow Pythagorean theorem
        final expectedSlant = math.sqrt(
          groundDistance * groundDistance + 10.0 * 10.0,
        );
        expect(slantRange, closeTo(expectedSlant, 0.1));
      });

      test('handles negative altitude difference', () {
        // Aircraft below ground station (unlikely but possible)
        final slantRange = SkyScannerService.calculateSlantRange(
          34.0522,
          -118.2437,
          2000.0, // Ground station at 2km (mountain top)
          34.0522,
          -118.2437,
          1000.0, // Aircraft at 1km (valley flight)
        );

        // Should still be 1km vertical distance
        expect(slantRange, closeTo(1.0, 0.01));
      });

      test('realistic air-to-ground scenario', () {
        // Ground station in LA, aircraft 100km away at FL350 (10,668m)
        // LAX area to somewhere ~100km east

        // Get coordinates ~100km east
        // At 34° N, 1° longitude ≈ 93km
        final groundDistance = SkyScannerService.calculateDistance(
          34.0522,
          -118.2437,
          34.0522,
          -117.1437, // ~100km east
        );

        final slantRange = SkyScannerService.calculateSlantRange(
          34.0522,
          -118.2437,
          100.0, // Ground at 100m
          34.0522,
          -117.1437,
          10668.0, // FL350
        );

        // Altitude diff in km: (10668 - 100) / 1000 = 10.568 km
        // Expected slant: sqrt(groundDistance^2 + 10.568^2)
        final altDiffKm = (10668.0 - 100.0) / 1000.0;
        final expectedSlant = math.sqrt(
          groundDistance * groundDistance + altDiffKm * altDiffKm,
        );

        expect(slantRange, closeTo(expectedSlant, 1.0));
        expect(slantRange, greaterThan(groundDistance));
      });

      test('is symmetric', () {
        final rangeAtoB = SkyScannerService.calculateSlantRange(
          34.0522,
          -118.2437,
          100.0,
          40.7128,
          -74.0060,
          10000.0,
        );

        final rangeBtoA = SkyScannerService.calculateSlantRange(
          40.7128,
          -74.0060,
          10000.0,
          34.0522,
          -118.2437,
          100.0,
        );

        expect(rangeAtoB, closeTo(rangeBtoA, 0.001));
      });
    });
  });
}
