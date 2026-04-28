// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pure rule tests for Tic-Tac-Toe v1.
///
/// These pin: initial state, legal-move predicate, winner detection
/// (rows / cols / diagonals), draw detection, and the deterministic
/// `turnFor` rule that the engine uses to validate turn order.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_rules.dart';

void main() {
  group('TttBoard', () {
    test('starts empty with all 9 cells null', () {
      final b = TttBoard.empty();
      expect(b.cells.length, equals(9));
      expect(b.cells.every((c) => c == null), isTrue);
      expect(b.moveCount, equals(0));
      expect(b.isFull, isFalse);
      expect(b.isDraw, isFalse);
      expect(b.winner, isNull);
    });

    test('isLegalMove rejects out-of-range cells', () {
      final b = TttBoard.empty();
      expect(b.isLegalMove(-1), isFalse);
      expect(b.isLegalMove(9), isFalse);
      expect(b.isLegalMove(0), isTrue);
      expect(b.isLegalMove(8), isTrue);
    });

    test('isLegalMove rejects an already-occupied cell', () {
      final b = TttBoard.empty().apply(4, TttMark.x);
      expect(b.isLegalMove(4), isFalse);
      expect(b.isLegalMove(0), isTrue);
    });

    test('apply does not mutate the input board (immutability)', () {
      final original = TttBoard.empty();
      final next = original.apply(0, TttMark.x);
      expect(original.cells[0], isNull);
      expect(next.cells[0], equals(TttMark.x));
    });

    group('winner detection', () {
      test('every row line wins', () {
        for (final row in [
          [0, 1, 2],
          [3, 4, 5],
          [6, 7, 8],
        ]) {
          var b = TttBoard.empty();
          for (final c in row) {
            b = b.apply(c, TttMark.x);
          }
          expect(b.winner, equals(TttMark.x), reason: 'row $row should win');
        }
      });

      test('every column line wins', () {
        for (final col in [
          [0, 3, 6],
          [1, 4, 7],
          [2, 5, 8],
        ]) {
          var b = TttBoard.empty();
          for (final c in col) {
            b = b.apply(c, TttMark.o);
          }
          expect(b.winner, equals(TttMark.o), reason: 'col $col should win');
        }
      });

      test('both diagonals win', () {
        var b = TttBoard.empty()
            .apply(0, TttMark.x)
            .apply(4, TttMark.x)
            .apply(8, TttMark.x);
        expect(b.winner, equals(TttMark.x));

        b = TttBoard.empty()
            .apply(2, TttMark.o)
            .apply(4, TttMark.o)
            .apply(6, TttMark.o);
        expect(b.winner, equals(TttMark.o));
      });

      test('mixed marks on a line do not win', () {
        final b = TttBoard.empty()
            .apply(0, TttMark.x)
            .apply(1, TttMark.o)
            .apply(2, TttMark.x);
        expect(b.winner, isNull);
      });
    });

    test('draw is full + no winner', () {
      // X O X
      // X O O
      // O X X  -> full, no line wins
      final b = TttBoard.empty()
          .apply(0, TttMark.x)
          .apply(1, TttMark.o)
          .apply(2, TttMark.x)
          .apply(3, TttMark.x)
          .apply(4, TttMark.o)
          .apply(5, TttMark.o)
          .apply(6, TttMark.o)
          .apply(7, TttMark.x)
          .apply(8, TttMark.x);
      expect(b.isFull, isTrue);
      expect(b.winner, isNull);
      expect(b.isDraw, isTrue);
    });
  });

  group('turnFor', () {
    test('empty board → X moves first (offerer convention)', () {
      expect(turnFor(TttBoard.empty()), equals(TttMark.x));
    });

    test('one X placed → O\'s turn', () {
      final b = TttBoard.empty().apply(0, TttMark.x);
      expect(turnFor(b), equals(TttMark.o));
    });

    test('equal counts → X\'s turn', () {
      final b = TttBoard.empty().apply(0, TttMark.x).apply(1, TttMark.o);
      expect(turnFor(b), equals(TttMark.x));
    });
  });

  group('TttMark', () {
    test('opponent flips X<->O', () {
      expect(TttMark.x.opponent, equals(TttMark.o));
      expect(TttMark.o.opponent, equals(TttMark.x));
    });

    test('wire codes are stable (X=0, O=1) — pinned for engine + codec', () {
      expect(TttMark.x.code, equals(0));
      expect(TttMark.o.code, equals(1));
      expect(TttMark.fromCode(0), equals(TttMark.x));
      expect(TttMark.fromCode(1), equals(TttMark.o));
      expect(TttMark.fromCode(2), isNull);
    });
  });
}
