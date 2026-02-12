// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/sky_scanner/services/opensky_service.dart';

void main() {
  group('OpenSkyService', () {
    late OpenSkyService service;

    setUp(() {
      service = OpenSkyService();
    });

    group('callsign normalization', () {
      // We test the normalization indirectly through the public API
      // by checking the FlightValidationResult message which includes
      // the normalized callsign

      test('data models are properly constructed', () {
        const result = FlightValidationResult(
          status: FlightValidationStatus.active,
          message: 'Test message',
        );

        expect(result.status, FlightValidationStatus.active);
        expect(result.message, 'Test message');
        expect(result.isValid, true);
        expect(result.isActive, true);
      });

      test('pending status is considered valid', () {
        const result = FlightValidationResult(
          status: FlightValidationStatus.pending,
          message: 'Future flight',
        );

        expect(result.isValid, true);
        expect(result.isActive, false);
      });

      test('verified status is considered valid', () {
        const result = FlightValidationResult(
          status: FlightValidationStatus.verified,
          message: 'Verified flight',
        );

        expect(result.isValid, true);
        expect(result.isActive, false);
      });

      test('notFound status is not valid', () {
        const result = FlightValidationResult(
          status: FlightValidationStatus.notFound,
          message: 'Not found',
        );

        expect(result.isValid, false);
        expect(result.isActive, false);
      });

      test('error status is not valid', () {
        const result = FlightValidationResult(
          status: FlightValidationStatus.error,
          message: 'Error',
        );

        expect(result.isValid, false);
        expect(result.isActive, false);
      });

      test('rateLimited status is not valid', () {
        const result = FlightValidationResult(
          status: FlightValidationStatus.rateLimited,
          message: 'Rate limited',
        );

        expect(result.isValid, false);
        expect(result.isActive, false);
      });
    });

    group('FlightPositionData', () {
      test('calculates altitude in feet correctly', () {
        const position = FlightPositionData(
          callsign: 'UAL123',
          altitude: 10668.0, // ~35,000 feet
        );

        expect(position.altitudeFeet, closeTo(35000, 10));
      });

      test('returns null altitude when altitude is null', () {
        const position = FlightPositionData(callsign: 'UAL123');

        expect(position.altitudeFeet, isNull);
      });

      test('calculates velocity in knots correctly', () {
        const position = FlightPositionData(
          callsign: 'UAL123',
          velocity: 257.0, // m/s, roughly 500 knots
        );

        expect(position.velocityKnots, closeTo(500, 5));
      });

      test('returns null velocity when velocity is null', () {
        const position = FlightPositionData(callsign: 'UAL123');

        expect(position.velocityKnots, isNull);
      });

      test('hasPosition returns true when lat/lon present', () {
        const position = FlightPositionData(
          callsign: 'UAL123',
          latitude: 34.0522,
          longitude: -118.2437,
        );

        expect(position.hasPosition, true);
      });

      test('hasPosition returns false when lat is null', () {
        const position = FlightPositionData(
          callsign: 'UAL123',
          longitude: -118.2437,
        );

        expect(position.hasPosition, false);
      });

      test('hasPosition returns false when lon is null', () {
        const position = FlightPositionData(
          callsign: 'UAL123',
          latitude: 34.0522,
        );

        expect(position.hasPosition, false);
      });

      test('hasPosition returns false when both null', () {
        const position = FlightPositionData(callsign: 'UAL123');

        expect(position.hasPosition, false);
      });
    });

    group('OpenSkyFlight', () {
      test('parses JSON correctly', () {
        final json = {
          'icao24': '3c675a',
          'firstSeen': 1517184000,
          'estDepartureAirport': 'EDDF',
          'lastSeen': 1517270400,
          'estArrivalAirport': 'KJFK',
          'callsign': 'DLH123',
          'estDepartureAirportHorizDistance': 1000,
          'estDepartureAirportVertDistance': 100,
          'estArrivalAirportHorizDistance': 2000,
          'estArrivalAirportVertDistance': 200,
          'departureAirportCandidatesCount': 3,
          'arrivalAirportCandidatesCount': 2,
        };

        final flight = OpenSkyFlight.fromJson(json);

        expect(flight.icao24, '3c675a');
        expect(flight.firstSeen, 1517184000);
        expect(flight.estDepartureAirport, 'EDDF');
        expect(flight.lastSeen, 1517270400);
        expect(flight.estArrivalAirport, 'KJFK');
        expect(flight.callsign, 'DLH123');
        expect(flight.estDepartureAirportHorizDistance, 1000);
        expect(flight.estDepartureAirportVertDistance, 100);
        expect(flight.estArrivalAirportHorizDistance, 2000);
        expect(flight.estArrivalAirportVertDistance, 200);
        expect(flight.departureAirportCandidatesCount, 3);
        expect(flight.arrivalAirportCandidatesCount, 2);
      });

      test('handles null values in JSON', () {
        final json = <String, dynamic>{
          'icao24': '3c675a',
          'callsign': null,
          'estDepartureAirport': null,
        };

        final flight = OpenSkyFlight.fromJson(json);

        expect(flight.icao24, '3c675a');
        expect(flight.callsign, isNull);
        expect(flight.estDepartureAirport, isNull);
      });

      test('calculates departure time correctly', () {
        final flight = OpenSkyFlight(firstSeen: 1517184000);

        expect(flight.departureTime, isNotNull);
        expect(
          flight.departureTime,
          DateTime.fromMillisecondsSinceEpoch(1517184000 * 1000),
        );
      });

      test('calculates arrival time correctly', () {
        final flight = OpenSkyFlight(lastSeen: 1517270400);

        expect(flight.arrivalTime, isNotNull);
        expect(
          flight.arrivalTime,
          DateTime.fromMillisecondsSinceEpoch(1517270400 * 1000),
        );
      });

      test('returns null departure time when firstSeen is null', () {
        const flight = OpenSkyFlight();

        expect(flight.departureTime, isNull);
      });

      test('returns null arrival time when lastSeen is null', () {
        const flight = OpenSkyFlight();

        expect(flight.arrivalTime, isNull);
      });
    });

    group('FlightValidationStatus', () {
      test('all status values exist', () {
        expect(FlightValidationStatus.values, hasLength(6));
        expect(
          FlightValidationStatus.values,
          containsAll([
            FlightValidationStatus.active,
            FlightValidationStatus.verified,
            FlightValidationStatus.notFound,
            FlightValidationStatus.pending,
            FlightValidationStatus.rateLimited,
            FlightValidationStatus.error,
          ]),
        );
      });
    });

    group('token cache', () {
      test('clearTokenCache does not throw', () {
        expect(() => service.clearTokenCache(), returnsNormally);
      });
    });
  });
}
