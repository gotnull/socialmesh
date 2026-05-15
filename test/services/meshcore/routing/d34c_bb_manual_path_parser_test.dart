// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-B-B: `parseManualPathHexPrefixes` pins.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_manual_path_parser.dart';

void main() {
  group('parseManualPathHexPrefixes - D34c-B-B', () {
    test('canonical 3-hop input parses each token', () {
      final r = parseManualPathHexPrefixes('AB,CD,12');
      expect(r.isOk, isTrue);
      expect(r.bytes, equals([0xAB, 0xCD, 0x12]));
    });

    test('case-insensitive hex', () {
      final r = parseManualPathHexPrefixes('ab,cd');
      expect(r.isOk, isTrue);
      expect(r.bytes, equals([0xAB, 0xCD]));
    });

    test('whitespace around tokens is trimmed', () {
      final r = parseManualPathHexPrefixes(' AB , CD ');
      expect(r.isOk, isTrue);
      expect(r.bytes, equals([0xAB, 0xCD]));
    });

    test('empty / blank tokens are skipped', () {
      final r = parseManualPathHexPrefixes('AB,,CD,');
      expect(r.isOk, isTrue);
      expect(r.bytes, equals([0xAB, 0xCD]));
    });

    test('empty input -> ok with empty bytes', () {
      final r = parseManualPathHexPrefixes('');
      expect(r.isOk, isTrue);
      expect(r.bytes, isNotNull);
      expect(r.bytes, isEmpty);
    });

    test('whitespace-only input -> ok with empty bytes', () {
      final r = parseManualPathHexPrefixes('   ,  ,   ');
      expect(r.isOk, isTrue);
      expect(r.bytes, isEmpty);
    });

    test('non-hex token reports invalidToken', () {
      final r = parseManualPathHexPrefixes('AB,XX');
      expect(r.isInvalidToken, isTrue);
      expect(r.invalidToken, 'XX');
    });

    test('token shorter than 2 chars reports invalidToken', () {
      final r = parseManualPathHexPrefixes('AB,C');
      expect(r.isInvalidToken, isTrue);
      expect(r.invalidToken, 'C');
    });

    test('token longer than 2 chars uses the first 2 chars', () {
      final r = parseManualPathHexPrefixes('ABCD,1234');
      expect(r.isOk, isTrue);
      expect(r.bytes, equals([0xAB, 0x12]));
    });

    test('> 64 tokens reports tooLong', () {
      final tokens = List<String>.filled(65, 'AB').join(',');
      final r = parseManualPathHexPrefixes(tokens);
      expect(r.isTooLong, isTrue);
      expect(r.overflowLength, 65);
    });

    test('exactly 64 tokens stays ok', () {
      final tokens = List<String>.filled(64, 'AB').join(',');
      final r = parseManualPathHexPrefixes(tokens);
      expect(r.isOk, isTrue);
      expect(r.bytes!.length, 64);
    });
  });
}
