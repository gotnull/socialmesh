// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pin the 1-byte TTT move payload format. Wire format:
/// `bits 7..4 = mark (0=X, 1=O)`, `bits 3..0 = cell (0..8)`.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_codec.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_payload.dart';

void main() {
  group('TttCodec.encodeMove', () {
    test('packs cell + mark into a single byte', () {
      // X (mark code 0) at cell 4 → 0x04
      expect(
        TttCodec.encodeMove(TttMove(cell: 4, mark: TttMark.x)),
        equals(Uint8List.fromList([0x04])),
      );
      // O (mark code 1) at cell 8 → 0x18
      expect(
        TttCodec.encodeMove(TttMove(cell: 8, mark: TttMark.o)),
        equals(Uint8List.fromList([0x18])),
      );
    });

    test('rejects cells out of range', () {
      expect(TttCodec.encodeMove(TttMove(cell: -1, mark: TttMark.x)), isNull);
      expect(TttCodec.encodeMove(TttMove(cell: 9, mark: TttMark.x)), isNull);
    });

    test('payload is exactly 1 byte (declared budget)', () {
      final payload = TttCodec.encodeMove(TttMove(cell: 0, mark: TttMark.x))!;
      expect(payload.length, equals(TttCodec.maxGamePayloadBytes));
      expect(TttCodec.maxGamePayloadBytes, equals(1));
    });
  });

  group('TttCodec.decodeMove', () {
    test('round-trips every (mark, cell) pair', () {
      for (final mark in TttMark.values) {
        for (var cell = 0; cell < 9; cell += 1) {
          final encoded = TttCodec.encodeMove(TttMove(cell: cell, mark: mark))!;
          final decoded = TttCodec.decodeMove(encoded);
          expect(decoded, isNotNull, reason: '($mark, $cell) should decode');
          expect(decoded!.cell, equals(cell));
          expect(decoded.mark, equals(mark));
        }
      }
    });

    test('rejects wrong-length payload', () {
      expect(TttCodec.decodeMove(Uint8List(0)), isNull);
      expect(TttCodec.decodeMove(Uint8List(2)), isNull);
    });

    test('rejects out-of-range cell encoded into the byte', () {
      // 0xFF: cell nibble = 0xF (=15) > 8 — invalid.
      expect(TttCodec.decodeMove(Uint8List.fromList([0xFF])), isNull);
    });

    test('rejects unknown mark code', () {
      // 0x20: mark nibble = 2, cell = 0. Mark 2 is not defined.
      expect(TttCodec.decodeMove(Uint8List.fromList([0x20])), isNull);
    });

    test('never throws on garbage', () {
      for (final byte in <int>[0x00, 0x18, 0xFE, 0xAB, 0x7F]) {
        // Either Some or null — but never an exception. The
        // `decodeMove` contract is no-throw.
        expect(
          () => TttCodec.decodeMove(Uint8List.fromList([byte])),
          returnsNormally,
        );
      }
    });
  });
}
