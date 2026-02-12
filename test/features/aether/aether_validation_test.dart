// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

/// Flight number validation pattern.
/// Format: 2-char airline (AA, B6, 9W) OR 3-letter airline (UAL, BAW)
///         + 1-4 digit flight number + optional suffix letter
/// Examples: UA123, BA2490, DL1, 9W4567, AA100A, UAL123
final _flightNumberPattern = RegExp(
  r'^(?:'
  r'(?:[A-Z]{2}|[A-Z][0-9]|[0-9][A-Z])[0-9]{1,4}|' // 2-char airline + 1-4 digits
  r'[A-Z]{3}[0-9]{1,4}' // 3-letter airline + 1-4 digits
  r')[A-Z]?$',
);

/// Airport code validation pattern.
/// IATA: 3 uppercase letters (e.g., LAX, JFK, LHR)
/// ICAO: 4 uppercase letters (e.g., KLAX, KJFK, EGLL)
final _airportCodePattern = RegExp(r'^[A-Z]{3,4}$');

/// Validates flight number format.
String? validateFlightNumber(String? value) {
  if (value == null || value.isEmpty) {
    return 'Enter flight number';
  }

  final cleaned = value.toUpperCase().trim();
  if (!_flightNumberPattern.hasMatch(cleaned)) {
    return 'Invalid format (e.g., UA123, BA2490)';
  }

  return null;
}

/// Validates airport code format.
String? validateAirportCode(String? value) {
  if (value == null || value.isEmpty) {
    return 'Required';
  }

  final cleaned = value.toUpperCase().trim();
  if (!_airportCodePattern.hasMatch(cleaned)) {
    return 'Use 3-4 letter code';
  }

  return null;
}

void main() {
  group('Flight Number Validation', () {
    group('valid flight numbers', () {
      test('accepts standard 2-letter airline + 3-digit flight', () {
        expect(validateFlightNumber('UA123'), isNull);
        expect(validateFlightNumber('DL456'), isNull);
        expect(validateFlightNumber('AA789'), isNull);
        expect(validateFlightNumber('BA100'), isNull);
      });

      test('accepts 2-letter airline + 4-digit flight', () {
        expect(validateFlightNumber('UA1234'), isNull);
        expect(validateFlightNumber('BA2490'), isNull);
        expect(validateFlightNumber('DL9999'), isNull);
      });

      test('accepts 2-letter airline + 1-digit flight', () {
        expect(validateFlightNumber('DL1'), isNull);
        expect(validateFlightNumber('UA2'), isNull);
      });

      test('accepts 2-letter airline + 2-digit flight', () {
        expect(validateFlightNumber('AA10'), isNull);
        expect(validateFlightNumber('BA99'), isNull);
      });

      test('accepts alphanumeric airline codes (e.g., 9W, 3K)', () {
        expect(validateFlightNumber('9W123'), isNull);
        expect(validateFlightNumber('3K456'), isNull);
        expect(validateFlightNumber('G31234'), isNull);
      });

      test('accepts 3-letter airline codes', () {
        expect(validateFlightNumber('UAL123'), isNull);
        expect(validateFlightNumber('DAL456'), isNull);
        expect(validateFlightNumber('BAW789'), isNull);
      });

      test('accepts flight numbers with suffix letter', () {
        expect(validateFlightNumber('AA100A'), isNull);
        expect(validateFlightNumber('UA123B'), isNull);
        expect(validateFlightNumber('DL1234X'), isNull);
      });

      test('accepts lowercase input (normalized to uppercase)', () {
        expect(validateFlightNumber('ua123'), isNull);
        expect(validateFlightNumber('dl456'), isNull);
        expect(validateFlightNumber('Ba2490'), isNull);
      });

      test('accepts input with leading/trailing whitespace', () {
        expect(validateFlightNumber(' UA123 '), isNull);
        expect(validateFlightNumber('  DL456'), isNull);
      });
    });

    group('invalid flight numbers', () {
      test('rejects empty string', () {
        expect(validateFlightNumber(''), 'Enter flight number');
      });

      test('rejects null', () {
        expect(validateFlightNumber(null), 'Enter flight number');
      });

      test('rejects 4+ letter airline codes', () {
        expect(validateFlightNumber('ABCD123'), isNot(isNull));
        expect(validateFlightNumber('UNITED1'), isNot(isNull));
      });

      test('rejects flight number with no digits', () {
        expect(validateFlightNumber('UA'), isNot(isNull));
        expect(validateFlightNumber('UAL'), isNot(isNull));
      });

      test('rejects flight number with 5+ digits', () {
        expect(validateFlightNumber('UA12345'), isNot(isNull));
        expect(validateFlightNumber('DL123456'), isNot(isNull));
      });

      test('rejects flight number with multiple suffix letters', () {
        expect(validateFlightNumber('UA123AB'), isNot(isNull));
      });

      test('rejects flight number with special characters', () {
        expect(validateFlightNumber('UA-123'), isNot(isNull));
        expect(validateFlightNumber('UA 123'), isNot(isNull));
        expect(validateFlightNumber('UA#123'), isNot(isNull));
      });

      test('rejects all-numeric input', () {
        expect(validateFlightNumber('12345'), isNot(isNull));
      });

      test('rejects all-alpha input', () {
        expect(validateFlightNumber('UAABC'), isNot(isNull));
      });
    });

    group('edge cases', () {
      test('accepts 2-char letter+digit airline codes (B6, G4, F9)', () {
        // These are real airlines: JetBlue (B6), Allegiant (G4), Frontier (F9)
        expect(validateFlightNumber('B6123'), isNull);
        expect(validateFlightNumber('G4456'), isNull);
        expect(validateFlightNumber('F9789'), isNull);
      });

      test('accepts ambiguous but historically valid codes like U1', () {
        // U1 was a defunct German airline - pattern allows this
        // U123 parses as U1 (airline) + 23 (flight number)
        expect(validateFlightNumber('U123'), isNull);
      });
    });

    group('real-world flight numbers', () {
      test('accepts major US carriers', () {
        expect(validateFlightNumber('UA1'), isNull); // United
        expect(validateFlightNumber('AA100'), isNull); // American
        expect(validateFlightNumber('DL2345'), isNull); // Delta
        expect(validateFlightNumber('WN1234'), isNull); // Southwest
        expect(validateFlightNumber('B61234'), isNull); // JetBlue
        expect(validateFlightNumber('AS123'), isNull); // Alaska
        expect(validateFlightNumber('NK1234'), isNull); // Spirit
        expect(validateFlightNumber('F91234'), isNull); // Frontier
      });

      test('accepts major international carriers', () {
        expect(validateFlightNumber('BA123'), isNull); // British Airways
        expect(validateFlightNumber('LH456'), isNull); // Lufthansa
        expect(validateFlightNumber('AF789'), isNull); // Air France
        expect(validateFlightNumber('EK1234'), isNull); // Emirates
        expect(validateFlightNumber('SQ22'), isNull); // Singapore Airlines
        expect(validateFlightNumber('QF1'), isNull); // Qantas
        expect(validateFlightNumber('CX123'), isNull); // Cathay Pacific
        expect(validateFlightNumber('NH1234'), isNull); // ANA
        expect(validateFlightNumber('JL123'), isNull); // Japan Airlines
        expect(validateFlightNumber('KE1234'), isNull); // Korean Air
      });

      test('accepts numeric-starting airline codes', () {
        expect(validateFlightNumber('9W1234'), isNull); // Jet Airways
        expect(validateFlightNumber('3K123'), isNull); // Jetstar Asia
        expect(validateFlightNumber('7C123'), isNull); // Jeju Air
        expect(validateFlightNumber('8M1234'), isNull); // Myanmar Airways
      });
    });
  });

  group('Airport Code Validation', () {
    group('valid IATA codes (3 letters)', () {
      test('accepts major US airports', () {
        expect(validateAirportCode('LAX'), isNull);
        expect(validateAirportCode('JFK'), isNull);
        expect(validateAirportCode('SFO'), isNull);
        expect(validateAirportCode('ORD'), isNull);
        expect(validateAirportCode('DFW'), isNull);
        expect(validateAirportCode('DEN'), isNull);
        expect(validateAirportCode('ATL'), isNull);
        expect(validateAirportCode('MIA'), isNull);
        expect(validateAirportCode('SEA'), isNull);
        expect(validateAirportCode('BOS'), isNull);
      });

      test('accepts major international airports', () {
        expect(validateAirportCode('LHR'), isNull); // London Heathrow
        expect(validateAirportCode('CDG'), isNull); // Paris CDG
        expect(validateAirportCode('FRA'), isNull); // Frankfurt
        expect(validateAirportCode('SIN'), isNull); // Singapore
        expect(validateAirportCode('HKG'), isNull); // Hong Kong
        expect(validateAirportCode('NRT'), isNull); // Tokyo Narita
        expect(validateAirportCode('SYD'), isNull); // Sydney
        expect(validateAirportCode('DXB'), isNull); // Dubai
        expect(validateAirportCode('AMS'), isNull); // Amsterdam
        expect(validateAirportCode('MEX'), isNull); // Mexico City
      });

      test('accepts lowercase input (normalized to uppercase)', () {
        expect(validateAirportCode('lax'), isNull);
        expect(validateAirportCode('jfk'), isNull);
        expect(validateAirportCode('Lhr'), isNull);
      });

      test('accepts input with leading/trailing whitespace', () {
        expect(validateAirportCode(' LAX '), isNull);
        expect(validateAirportCode('  JFK'), isNull);
      });
    });

    group('valid ICAO codes (4 letters)', () {
      test('accepts US ICAO codes', () {
        expect(validateAirportCode('KLAX'), isNull);
        expect(validateAirportCode('KJFK'), isNull);
        expect(validateAirportCode('KSFO'), isNull);
        expect(validateAirportCode('KORD'), isNull);
        expect(validateAirportCode('KATL'), isNull);
      });

      test('accepts international ICAO codes', () {
        expect(validateAirportCode('EGLL'), isNull); // London Heathrow
        expect(validateAirportCode('LFPG'), isNull); // Paris CDG
        expect(validateAirportCode('EDDF'), isNull); // Frankfurt
        expect(validateAirportCode('WSSS'), isNull); // Singapore
        expect(validateAirportCode('VHHH'), isNull); // Hong Kong
        expect(validateAirportCode('RJTT'), isNull); // Tokyo Haneda
        expect(validateAirportCode('YSSY'), isNull); // Sydney
        expect(validateAirportCode('OMDB'), isNull); // Dubai
      });
    });

    group('invalid airport codes', () {
      test('rejects empty string', () {
        expect(validateAirportCode(''), 'Required');
      });

      test('rejects null', () {
        expect(validateAirportCode(null), 'Required');
      });

      test('rejects 1-2 letter codes', () {
        expect(validateAirportCode('L'), isNot(isNull));
        expect(validateAirportCode('LA'), isNot(isNull));
      });

      test('rejects 5+ letter codes', () {
        expect(validateAirportCode('KLAXS'), isNot(isNull));
        expect(validateAirportCode('LONDON'), isNot(isNull));
      });

      test('rejects codes with numbers', () {
        expect(validateAirportCode('LA1'), isNot(isNull));
        expect(validateAirportCode('123'), isNot(isNull));
        expect(validateAirportCode('L4X'), isNot(isNull));
      });

      test('rejects codes with special characters', () {
        expect(validateAirportCode('LA-X'), isNot(isNull));
        expect(validateAirportCode('LA X'), isNot(isNull));
        expect(validateAirportCode('LA#'), isNot(isNull));
      });
    });
  });
}
