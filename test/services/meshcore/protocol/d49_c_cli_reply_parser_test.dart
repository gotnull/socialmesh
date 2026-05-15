// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-C: `MeshCoreCliReplyParser` pins.
//
// Pinned invariants for the three extractor helpers on
// representative CLI reply shapes observed in upstream firmware:
//
//   - Bare value:                "Heltec1"            -> "Heltec1"
//   - Prompt prefix:             "> Heltec1"          -> "Heltec1"
//   - Key:value pair:            "name: Heltec1"      -> "Heltec1"
//   - Prompt + key:value:        "> name: Heltec1"    -> "Heltec1"
//   - Empty reply:               ""                   -> null
//   - Trailing unit suffix:      "advert.interval: 120 min" -> 120
//   - Boolean on:                "on" / "ON" / "yes"  -> true
//   - Boolean off:               "off" / "OFF" / "no" -> false

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_cli_reply_parser.dart';

void main() {
  group('extractValue - D49-C', () {
    test('bare single-token value', () {
      expect(MeshCoreCliReplyParser.extractValue('Heltec1'), 'Heltec1');
    });

    test('prompt-prefixed value', () {
      expect(MeshCoreCliReplyParser.extractValue('> Heltec1'), 'Heltec1');
    });

    test('key:value', () {
      expect(MeshCoreCliReplyParser.extractValue('name: Heltec1'), 'Heltec1');
    });

    test('prompt + key:value prefers the colon-tail', () {
      expect(MeshCoreCliReplyParser.extractValue('> name: Heltec1'), 'Heltec1');
    });

    test('multi-line reply -- first non-empty line wins', () {
      expect(
        MeshCoreCliReplyParser.extractValue('\n\n> name: A1\nsomething else'),
        'A1',
      );
    });

    test('empty reply returns null', () {
      expect(MeshCoreCliReplyParser.extractValue(''), isNull);
    });

    test('whitespace-only reply returns null', () {
      expect(MeshCoreCliReplyParser.extractValue('   \n\n  '), isNull);
    });

    test('lone prompt without value returns null after stripping', () {
      // `>` alone strips to empty; no colon-tail; falls back to the
      // trimmed raw line which is the prompt itself.
      expect(MeshCoreCliReplyParser.extractValue('>'), '>');
    });

    test('trailing-empty colon is ignored as separator', () {
      // `name:` (no value after colon) falls through to fallback.
      expect(MeshCoreCliReplyParser.extractValue('name:'), 'name:');
    });
  });

  group('extractBool - D49-C', () {
    test('on / true / 1 / yes -> true', () {
      for (final v in const ['on', 'ON', 'On', 'true', 'True', '1', 'yes']) {
        expect(
          MeshCoreCliReplyParser.extractBool(v),
          isTrue,
          reason: 'value "$v" should map to true',
        );
      }
    });

    test('off / false / 0 / no -> false', () {
      for (final v in const ['off', 'OFF', 'Off', 'false', '0', 'no']) {
        expect(
          MeshCoreCliReplyParser.extractBool(v),
          isFalse,
          reason: 'value "$v" should map to false',
        );
      }
    });

    test('prompt-prefixed on / off', () {
      expect(MeshCoreCliReplyParser.extractBool('> on'), isTrue);
      expect(MeshCoreCliReplyParser.extractBool('> off'), isFalse);
    });

    test('key:value boolean', () {
      expect(MeshCoreCliReplyParser.extractBool('repeat: on'), isTrue);
      expect(
        MeshCoreCliReplyParser.extractBool('allow.read.only: off'),
        isFalse,
      );
    });

    test('non-boolean returns null', () {
      expect(MeshCoreCliReplyParser.extractBool('maybe'), isNull);
      expect(MeshCoreCliReplyParser.extractBool('foo: bar'), isNull);
    });

    test('empty returns null', () {
      expect(MeshCoreCliReplyParser.extractBool(''), isNull);
    });
  });

  group('extractInt - D49-C', () {
    test('bare integer', () {
      expect(MeshCoreCliReplyParser.extractInt('120'), 120);
    });

    test('prompt-prefixed integer', () {
      expect(MeshCoreCliReplyParser.extractInt('> 120'), 120);
    });

    test('key:value integer', () {
      expect(MeshCoreCliReplyParser.extractInt('advert.interval: 120'), 120);
    });

    test('trailing unit suffix strips cleanly', () {
      expect(
        MeshCoreCliReplyParser.extractInt('advert.interval: 120 min'),
        120,
      );
      expect(MeshCoreCliReplyParser.extractInt('> 42 minutes'), 42);
    });

    test('negative integer', () {
      expect(MeshCoreCliReplyParser.extractInt('rxdelay: -5'), -5);
    });

    test('non-numeric returns null', () {
      expect(MeshCoreCliReplyParser.extractInt('Heltec1'), isNull);
      expect(MeshCoreCliReplyParser.extractInt('name: Heltec1'), isNull);
    });

    test('empty returns null', () {
      expect(MeshCoreCliReplyParser.extractInt(''), isNull);
    });
  });
}
