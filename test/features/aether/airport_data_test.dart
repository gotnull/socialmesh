// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/aether/data/airports.dart';

void main() {
  group('Airport data integrity', () {
    test('kAirports is not empty', () {
      expect(kAirports.length, greaterThan(1000));
    });

    test('all airports have valid ICAO codes (2-7 alphanumeric)', () {
      for (final airport in kAirports) {
        expect(
          airport.icao.length,
          inInclusiveRange(2, 7),
          reason: '${airport.name} has ICAO "${airport.icao}"',
        );
        expect(
          RegExp(r'^[A-Z0-9-]{2,7}$').hasMatch(airport.icao),
          isTrue,
          reason:
              '${airport.name} ICAO "${airport.icao}" is not valid alphanumeric',
        );
      }
    });

    test('all airports have valid ICAO codes', () {
      for (final airport in kAirports) {
        expect(
          airport.icao.length,
          inInclusiveRange(2, 7),
          reason: '${airport.name} has ICAO "${airport.icao}"',
        );
        expect(
          RegExp(r'^[A-Z0-9-]{2,7}$').hasMatch(airport.icao),
          isTrue,
          reason: '${airport.name} ICAO "${airport.icao}" is not valid',
        );
      }
    });

    test('all airports have valid coordinates', () {
      for (final airport in kAirports) {
        expect(
          airport.latitude,
          inInclusiveRange(-90, 90),
          reason: '${airport.iata} lat=${airport.latitude}',
        );
        expect(
          airport.longitude,
          inInclusiveRange(-180, 180),
          reason: '${airport.iata} lon=${airport.longitude}',
        );
        // No (0, 0) — that's in the Gulf of Guinea, no large airports there
        expect(
          airport.latitude == 0 && airport.longitude == 0,
          isFalse,
          reason: '${airport.iata} has zero coordinates',
        );
      }
    });

    test('IATA codes are unique', () {
      final codes = kAirports.map((a) => a.iata).toSet();
      expect(codes.length, kAirports.length);
    });

    test('kAirports is sorted by IATA', () {
      for (var i = 1; i < kAirports.length; i++) {
        expect(
          kAirports[i].iata.compareTo(kAirports[i - 1].iata),
          greaterThan(0),
          reason:
              '${kAirports[i - 1].iata} should come before ${kAirports[i].iata}',
        );
      }
    });
  });

  group('lookupAirport', () {
    test('finds airport by IATA code', () {
      final lax = lookupAirport('LAX');
      expect(lax, isNotNull);
      expect(lax!.iata, 'LAX');
      expect(lax.icao, 'KLAX');
      expect(lax.city, contains('Los Angeles'));
    });

    test('finds airport by ICAO code', () {
      final egll = lookupAirport('EGLL');
      expect(egll, isNotNull);
      expect(egll!.iata, 'LHR');
    });

    test('is case-insensitive', () {
      expect(lookupAirport('jfk'), isNotNull);
      expect(lookupAirport('Jfk'), isNotNull);
      expect(lookupAirport('klax'), isNotNull);
    });

    test('returns null for unknown code', () {
      expect(lookupAirport('ZZZ'), isNull);
      expect(lookupAirport('XXXX'), isNull);
      expect(lookupAirport(''), isNull);
    });

    test('finds ICAO-only military airfield (EGDM)', () {
      final egdm = lookupAirport('EGDM');
      expect(egdm, isNotNull);
      expect(egdm!.icao, 'EGDM');
      expect(egdm.iata, '');
      expect(egdm.name, 'MoD Boscombe Down');
      expect(egdm.city, 'Amesbury');
      expect(egdm.country, 'GB');
    });

    test('finds other ICAO-only military airfields', () {
      expect(lookupAirport('EGVN'), isNotNull); // RAF Brize Norton
      expect(lookupAirport('EGVA'), isNotNull); // RAF Fairford
      expect(lookupAirport('EGUN'), isNotNull); // RAF Mildenhall
      expect(lookupAirport('ETAR'), isNotNull); // Ramstein
    });

    test('ICAO-only airports are case-insensitive', () {
      expect(lookupAirport('egdm'), isNotNull);
      expect(lookupAirport('Egdm'), isNotNull);
    });
  });

  group('Airport display labels (ICAO-only)', () {
    test('displayLabel uses ICAO when IATA is empty', () {
      final egdm = lookupAirport('EGDM')!;
      expect(egdm.displayLabel, 'EGDM - Amesbury');
    });

    test('compactLabel uses ICAO when IATA is empty', () {
      final egdm = lookupAirport('EGDM')!;
      expect(egdm.compactLabel, 'EGDM - Amesbury');
    });

    test('displayLabel uses IATA for civilian airports', () {
      final lhr = lookupAirport('LHR')!;
      expect(lhr.displayLabel, contains('LHR'));
      expect(lhr.displayLabel, contains('EGLL'));
    });
  });

  group('Airport.matches', () {
    test('matches IATA code', () {
      final sfo = lookupAirport('SFO')!;
      expect(sfo.matches('SFO'), isTrue);
      expect(sfo.matches('sfo'), isTrue);
    });

    test('matches ICAO code', () {
      final sfo = lookupAirport('SFO')!;
      expect(sfo.matches('KSFO'), isTrue);
    });

    test('matches city name', () {
      final sfo = lookupAirport('SFO')!;
      expect(sfo.matches('San Fran'), isTrue);
    });

    test('matches country code', () {
      final sfo = lookupAirport('SFO')!;
      expect(sfo.matches('US'), isTrue);
    });

    test('does not match unrelated query', () {
      final sfo = lookupAirport('SFO')!;
      expect(sfo.matches('Tokyo'), isFalse);
    });
  });

  group('Airport.distanceToKm (haversine)', () {
    test('distance from airport to itself is zero', () {
      final lax = lookupAirport('LAX')!;
      expect(lax.distanceToKm(lax), closeTo(0, 0.1));
    });

    test('LAX to JFK is approximately 3,970 km', () {
      final lax = lookupAirport('LAX')!;
      final jfk = lookupAirport('JFK')!;
      final dist = lax.distanceToKm(jfk);
      // Known great-circle distance: ~3,970 km
      expect(dist, closeTo(3970, 50));
    });

    test('LHR to SYD is approximately 17,000 km', () {
      final lhr = lookupAirport('LHR')!;
      final syd = lookupAirport('SYD')!;
      final dist = lhr.distanceToKm(syd);
      // Known great-circle distance: ~17,000 km
      expect(dist, closeTo(17000, 200));
    });

    test('JFK to LGA (same metro) is very short', () {
      final jfk = lookupAirport('JFK')!;
      final lga = lookupAirport('LGA')!;
      final dist = jfk.distanceToKm(lga);
      // JFK to LGA is about 16 km
      expect(dist, lessThan(kMinRoutDistanceKm));
    });

    test('distance is symmetric', () {
      final lax = lookupAirport('LAX')!;
      final nrt = lookupAirport('NRT')!;
      expect(lax.distanceToKm(nrt), closeTo(nrt.distanceToKm(lax), 0.01));
    });
  });

  group('Route validation constants', () {
    test('min distance catches same-metro airports', () {
      // CDG to ORY (Paris) is about 35 km
      final cdg = lookupAirport('CDG')!;
      final ory = lookupAirport('ORY')!;
      final dist = cdg.distanceToKm(ory);
      expect(dist, lessThan(kMinRoutDistanceKm));
    });

    test('max distance allows longest nonstop routes', () {
      // SIN to JFK (~15,350 km) is the longest nonstop route
      final sin = lookupAirport('SIN')!;
      final jfk = lookupAirport('JFK')!;
      final dist = sin.distanceToKm(jfk);
      expect(dist, lessThan(kMaxRouteDistanceKm));
    });

    test('max distance blocks impossible routes', () {
      // No two points on Earth are > 20,015 km apart (half circumference)
      // kMaxRouteDistanceKm should be well below that
      expect(kMaxRouteDistanceKm, lessThan(20100));
      expect(kMaxRouteDistanceKm, greaterThan(17000));
    });

    test('normal domestic route passes both thresholds', () {
      final lax = lookupAirport('LAX')!;
      final jfk = lookupAirport('JFK')!;
      final dist = lax.distanceToKm(jfk);
      expect(dist, greaterThan(kMinRoutDistanceKm));
      expect(dist, lessThan(kMaxRouteDistanceKm));
    });
  });
}
