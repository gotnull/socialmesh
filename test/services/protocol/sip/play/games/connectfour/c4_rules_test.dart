// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pure rule tests for Connect Four v1.
///
/// These pin: initial state, legal-move predicate (column-based),
/// gravity (landingRowFor), winner detection on every line type
/// (horizontal / vertical / both diagonals), draw detection, and the
/// deterministic `turnFor` rule the engine uses to validate turn
/// order.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/play/games/connectfour/c4_payload.dart';
import 'package:socialmesh/services/protocol/sip/play/games/connectfour/c4_rules.dart';

void main() {
  group('C4Board', () {
    test('starts empty with all 42 cells null', () {
      final b = C4Board.empty();
      expect(b.cells.length, equals(42));
      expect(b.cells.every((c) => c == null), isTrue);
      expect(b.moveCount, equals(0));
      expect(b.isFull, isFalse);
      expect(b.isDraw, isFalse);
      expect(b.winner, isNull);
    });

    test('rows = 6, cols = 7 (pinned for spec + widget layout)', () {
      expect(C4Board.rows, equals(6));
      expect(C4Board.cols, equals(7));
    });

    group('landingRowFor (gravity)', () {
      test('empty column → bottom row (5)', () {
        final b = C4Board.empty();
        expect(b.landingRowFor(0), equals(5));
        expect(b.landingRowFor(3), equals(5));
        expect(b.landingRowFor(6), equals(5));
      });

      test('partially-filled column → next-empty row above', () {
        var b = C4Board.empty();
        // Drop 3 discs into column 2 — they land at rows 5, 4, 3.
        b = b.apply(2, C4Disc.red);
        expect(b.landingRowFor(2), equals(4));
        b = b.apply(2, C4Disc.yellow);
        expect(b.landingRowFor(2), equals(3));
        b = b.apply(2, C4Disc.red);
        expect(b.landingRowFor(2), equals(2));
      });

      test('full column → null', () {
        var b = C4Board.empty();
        // Fill all 6 rows of column 1 alternating colours.
        for (var i = 0; i < 6; i += 1) {
          b = b.apply(1, i.isEven ? C4Disc.red : C4Disc.yellow);
        }
        expect(b.landingRowFor(1), isNull);
        // Other columns still have space.
        expect(b.landingRowFor(0), equals(5));
      });

      test('out-of-range column → null', () {
        final b = C4Board.empty();
        expect(b.landingRowFor(-1), isNull);
        expect(b.landingRowFor(7), isNull);
      });
    });

    group('isLegalMove', () {
      test('empty board: every column legal', () {
        final b = C4Board.empty();
        for (var col = 0; col < 7; col += 1) {
          expect(b.isLegalMove(col), isTrue, reason: 'col $col');
        }
      });

      test('rejects out-of-range columns', () {
        final b = C4Board.empty();
        expect(b.isLegalMove(-1), isFalse);
        expect(b.isLegalMove(7), isFalse);
      });

      test('rejects a full column but not its neighbours', () {
        var b = C4Board.empty();
        for (var i = 0; i < 6; i += 1) {
          b = b.apply(3, i.isEven ? C4Disc.red : C4Disc.yellow);
        }
        expect(b.isLegalMove(3), isFalse);
        expect(b.isLegalMove(2), isTrue);
        expect(b.isLegalMove(4), isTrue);
      });
    });

    test('apply does not mutate the input board (immutability)', () {
      final original = C4Board.empty();
      final modified = original.apply(0, C4Disc.red);
      expect(original.cells.every((c) => c == null), isTrue);
      expect(modified.cellAt(5, 0), equals(C4Disc.red));
    });

    test('apply on a full column is a no-op (caller must gate)', () {
      var b = C4Board.empty();
      for (var i = 0; i < 6; i += 1) {
        b = b.apply(0, C4Disc.red);
      }
      expect(b.moveCount, equals(6));
      // 7th drop is silently no-op'd (engine gates via isLegalMove
      // first; this is defensive).
      final after = b.apply(0, C4Disc.yellow);
      expect(after.moveCount, equals(6));
    });

    group('winner detection', () {
      test('every horizontal four-in-a-row wins', () {
        // For each row, every starting column 0..3 yields a win.
        for (var row = 0; row < 6; row += 1) {
          for (var startCol = 0; startCol <= 3; startCol += 1) {
            final cells = List<C4Disc?>.filled(42, null);
            for (var c = startCol; c < startCol + 4; c += 1) {
              cells[row * 7 + c] = C4Disc.red;
            }
            final b = C4Board.fromCellsUnchecked(cells);
            expect(
              b.winner,
              equals(C4Disc.red),
              reason: 'row=$row startCol=$startCol',
            );
          }
        }
      });

      test('every vertical four-in-a-row wins', () {
        // For each column, every starting row 0..2 yields a win.
        for (var col = 0; col < 7; col += 1) {
          for (var startRow = 0; startRow <= 2; startRow += 1) {
            final cells = List<C4Disc?>.filled(42, null);
            for (var r = startRow; r < startRow + 4; r += 1) {
              cells[r * 7 + col] = C4Disc.yellow;
            }
            final b = C4Board.fromCellsUnchecked(cells);
            expect(
              b.winner,
              equals(C4Disc.yellow),
              reason: 'col=$col startRow=$startRow',
            );
          }
        }
      });

      test('every ↘ diagonal four-in-a-row wins', () {
        for (var startRow = 0; startRow <= 2; startRow += 1) {
          for (var startCol = 0; startCol <= 3; startCol += 1) {
            final cells = List<C4Disc?>.filled(42, null);
            for (var k = 0; k < 4; k += 1) {
              cells[(startRow + k) * 7 + (startCol + k)] = C4Disc.red;
            }
            final b = C4Board.fromCellsUnchecked(cells);
            expect(
              b.winner,
              equals(C4Disc.red),
              reason: '↘ startRow=$startRow startCol=$startCol',
            );
          }
        }
      });

      test('every ↙ diagonal four-in-a-row wins', () {
        for (var startRow = 0; startRow <= 2; startRow += 1) {
          for (var startCol = 3; startCol < 7; startCol += 1) {
            final cells = List<C4Disc?>.filled(42, null);
            for (var k = 0; k < 4; k += 1) {
              cells[(startRow + k) * 7 + (startCol - k)] = C4Disc.yellow;
            }
            final b = C4Board.fromCellsUnchecked(cells);
            expect(
              b.winner,
              equals(C4Disc.yellow),
              reason: '↙ startRow=$startRow startCol=$startCol',
            );
          }
        }
      });

      test('mixed colours on a line do not win', () {
        // 3 reds + 1 yellow on row 0: not a winner.
        final cells = List<C4Disc?>.filled(42, null);
        cells[0] = C4Disc.red;
        cells[1] = C4Disc.red;
        cells[2] = C4Disc.red;
        cells[3] = C4Disc.yellow;
        expect(C4Board.fromCellsUnchecked(cells).winner, isNull);
      });

      test('three-in-a-row does not win', () {
        final cells = List<C4Disc?>.filled(42, null);
        cells[0] = C4Disc.red;
        cells[1] = C4Disc.red;
        cells[2] = C4Disc.red;
        expect(C4Board.fromCellsUnchecked(cells).winner, isNull);
      });
    });

    group('isDraw', () {
      test('full board with no winner → draw', () {
        // Construct a deliberately drawn board (no four-in-a-row).
        // Pattern: alternating rows shifted to avoid alignments.
        // Simplest valid filler: column-major alternating discs that
        // don't form 4 consecutive matches.
        final cells = List<C4Disc?>.filled(42, null);
        // Hand-design a no-winner full board:
        // row 0: R Y R Y R Y R
        // row 1: Y R Y R Y R Y
        // row 2: R Y R Y R Y R
        // row 3: Y R Y R Y R Y
        // row 4: R Y R Y R Y R
        // row 5: Y R Y R Y R Y
        // This DOES produce diagonal wins. Use a different pattern:
        // Pairs of 2 stacked: RR-YY-RR-YY-RR-YY-RR (column 0)
        // We need a hand-tested no-winner full board. Easier: pick
        // a known-drawn pattern.
        const drawPattern = [
          // row 0
          'R', 'Y', 'R', 'Y', 'R', 'Y', 'R',
          // row 1
          'R', 'Y', 'R', 'Y', 'R', 'Y', 'R',
          // row 2
          'Y', 'R', 'Y', 'R', 'Y', 'R', 'Y',
          // row 3
          'Y', 'R', 'Y', 'R', 'Y', 'R', 'Y',
          // row 4
          'R', 'Y', 'R', 'Y', 'R', 'Y', 'R',
          // row 5
          'R', 'Y', 'R', 'Y', 'R', 'Y', 'R',
        ];
        for (var i = 0; i < 42; i += 1) {
          cells[i] = drawPattern[i] == 'R' ? C4Disc.red : C4Disc.yellow;
        }
        final b = C4Board.fromCellsUnchecked(cells);
        expect(b.isFull, isTrue);
        // If this layout happens to contain a 4-in-a-row we'd flag
        // it; test scaffolding will catch with a clear message.
        if (b.winner != null) {
          fail(
            'Test scaffolding error: chosen "draw" pattern has '
            'a winning line for ${b.winner}',
          );
        }
        expect(b.isDraw, isTrue);
      });

      test('partially-filled board is never a draw', () {
        var b = C4Board.empty();
        b = b.apply(0, C4Disc.red);
        b = b.apply(1, C4Disc.yellow);
        expect(b.isDraw, isFalse);
      });
    });
  });

  group('turnFor', () {
    test('empty board → red moves first (offerer convention)', () {
      expect(turnFor(C4Board.empty()), equals(C4Disc.red));
    });

    test('one red placed → yellow\'s turn', () {
      final b = C4Board.empty().apply(0, C4Disc.red);
      expect(turnFor(b), equals(C4Disc.yellow));
    });

    test('equal counts → red\'s turn', () {
      final b = C4Board.empty().apply(0, C4Disc.red).apply(1, C4Disc.yellow);
      expect(turnFor(b), equals(C4Disc.red));
    });
  });
}
