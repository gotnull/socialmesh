// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pin the 1-byte Connect Four move payload format. Wire format:
/// `bits 7..4 = disc (0=red, 1=yellow)`, `bits 3..0 = column (0..6)`.
/// The receiver derives the landing row from current board state via
/// gravity — the row is NOT transmitted.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/play/games/connectfour/c4_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/games/connectfour/c4_payload.dart';

void main() {
  group('C4Codec.encodeMove', () {
    test('packs column + disc into a single byte', () {
      // red (disc code 0) at column 3 → 0x03
      expect(
        C4Codec.encodeMove(C4Move(column: 3, disc: C4Disc.red)),
        equals(Uint8List.fromList([0x03])),
      );
      // yellow (disc code 1) at column 6 → 0x16
      expect(
        C4Codec.encodeMove(C4Move(column: 6, disc: C4Disc.yellow)),
        equals(Uint8List.fromList([0x16])),
      );
      // red at column 0 → 0x00 (the all-zero edge case)
      expect(
        C4Codec.encodeMove(C4Move(column: 0, disc: C4Disc.red)),
        equals(Uint8List.fromList([0x00])),
      );
    });

    test('rejects columns out of range', () {
      expect(C4Codec.encodeMove(C4Move(column: -1, disc: C4Disc.red)), isNull);
      expect(C4Codec.encodeMove(C4Move(column: 7, disc: C4Disc.red)), isNull);
    });

    test('payload is exactly 1 byte (declared budget)', () {
      final payload = C4Codec.encodeMove(C4Move(column: 0, disc: C4Disc.red))!;
      expect(payload.length, equals(C4Codec.maxGamePayloadBytes));
      expect(C4Codec.maxGamePayloadBytes, equals(1));
    });
  });

  group('C4Codec.decodeMove', () {
    test('round-trips every (disc, column) pair', () {
      for (final disc in C4Disc.values) {
        for (var col = 0; col < 7; col += 1) {
          final encoded = C4Codec.encodeMove(C4Move(column: col, disc: disc))!;
          final decoded = C4Codec.decodeMove(encoded);
          expect(decoded, isNotNull, reason: '($disc, $col) should decode');
          expect(decoded!.column, equals(col));
          expect(decoded.disc, equals(disc));
        }
      }
    });

    test('rejects wrong-length payload', () {
      expect(C4Codec.decodeMove(Uint8List(0)), isNull);
      expect(C4Codec.decodeMove(Uint8List(2)), isNull);
    });

    test('rejects out-of-range column encoded into the byte', () {
      // 0x07: column nibble = 7 — out of range (legal max is 6).
      expect(C4Codec.decodeMove(Uint8List.fromList([0x07])), isNull);
      // 0xFF: column nibble = 0xF — out of range.
      expect(C4Codec.decodeMove(Uint8List.fromList([0xFF])), isNull);
    });

    test('rejects unknown disc code', () {
      // 0x20: disc nibble = 2, column = 0. Disc 2 is not defined.
      expect(C4Codec.decodeMove(Uint8List.fromList([0x20])), isNull);
    });

    test('never throws on garbage', () {
      for (final byte in <int>[0x00, 0x16, 0xFE, 0xAB, 0x7F]) {
        expect(
          () => C4Codec.decodeMove(Uint8List.fromList([byte])),
          returnsNormally,
        );
      }
    });
  });

  group('C4Disc wire codes', () {
    test('red=0, yellow=1 (pinned for engine + codec)', () {
      expect(C4Disc.red.code, equals(0));
      expect(C4Disc.yellow.code, equals(1));
    });

    test('opponent flips red<->yellow', () {
      expect(C4Disc.red.opponent, equals(C4Disc.yellow));
      expect(C4Disc.yellow.opponent, equals(C4Disc.red));
    });

    test('fromCode returns null for unknown values', () {
      expect(C4Disc.fromCode(0), equals(C4Disc.red));
      expect(C4Disc.fromCode(1), equals(C4Disc.yellow));
      expect(C4Disc.fromCode(2), isNull);
      expect(C4Disc.fromCode(15), isNull);
    });
  });
}
