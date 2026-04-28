// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'ttt_payload.dart';

/// Pure Tic-Tac-Toe rules. No I/O, no clock, no logging side effects —
/// a [TttBoard] is just a 9-cell value type that gets transformed by
/// `apply` and queried by `winner` / `isDraw` / `isLegalMove`.
///
/// All higher-level decisions (whose turn, whose mark, seq enforcement,
/// trust-and-safety blocks) live in the engine. The rules here simply
/// say "given this board, is this move legal, and what's the next
/// board."
class TttBoard {
  /// 9-cell state. `null` = empty, otherwise the placed mark.
  ///
  /// Ordering is row-major:
  ///
  /// ```
  /// 0 1 2
  /// 3 4 5
  /// 6 7 8
  /// ```
  final List<TttMark?> cells;

  const TttBoard._(this.cells);

  /// Empty 3x3 board.
  factory TttBoard.empty() {
    return TttBoard._(List<TttMark?>.filled(9, null, growable: false));
  }

  /// Number of placed marks. Used by the engine to derive whose turn
  /// it is without holding extra state.
  int get moveCount => cells.where((c) => c != null).length;

  /// True iff every cell has a mark. Combined with [winner] = null
  /// this is a draw.
  bool get isFull => moveCount == 9;

  /// Winner if there's a winning line, else null. A null winner with
  /// a full board is a draw (use [isDraw]).
  TttMark? get winner {
    for (final line in _winningLines) {
      final a = cells[line[0]];
      final b = cells[line[1]];
      final c = cells[line[2]];
      if (a != null && a == b && b == c) return a;
    }
    return null;
  }

  /// True iff the board is full with no winner.
  bool get isDraw => isFull && winner == null;

  /// True iff [cell] is in range and currently empty.
  bool isLegalMove(int cell) {
    if (cell < 0 || cell > 8) return false;
    return cells[cell] == null;
  }

  /// Return a new board with [mark] placed in [cell]. Caller is
  /// responsible for legality (engine checks via [isLegalMove] +
  /// turn / status guards).
  TttBoard apply(int cell, TttMark mark) {
    final next = List<TttMark?>.of(cells, growable: false);
    next[cell] = mark;
    return TttBoard._(List<TttMark?>.unmodifiable(next));
  }

  static const List<List<int>> _winningLines = [
    // rows
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    // cols
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    // diagonals
    [0, 4, 8],
    [2, 4, 6],
  ];
}

/// Whose turn is it on a fresh / mid-game board?
///
/// X always moves first (offerer convention). After that the board
/// state alone determines turn order: equal counts means X, one more
/// X means O.
TttMark turnFor(TttBoard board) {
  final xs = board.cells.where((c) => c == TttMark.x).length;
  final os = board.cells.where((c) => c == TttMark.o).length;
  return xs == os ? TttMark.x : TttMark.o;
}
