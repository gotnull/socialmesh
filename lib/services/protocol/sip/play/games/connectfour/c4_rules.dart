// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'c4_payload.dart';

/// Pure Connect Four rules. No I/O, no clock, no logging side effects —
/// a [C4Board] is just a 42-cell value type that gets transformed by
/// [apply] and queried by [winner] / [isDraw] / [isLegalMove].
///
/// All higher-level decisions (whose turn, whose disc, seq enforcement,
/// trust-and-safety blocks) live in the engine. The rules here simply
/// say "given this board, is this column legal, what row will the
/// disc land on, and what's the next board."
class C4Board {
  /// Number of rows (top → bottom).
  static const int rows = 6;

  /// Number of columns (left → right).
  static const int cols = 7;

  /// 42-cell state. `null` = empty, otherwise the placed disc.
  /// Row-major: `cells[row * cols + col]`. Row 0 is the TOP row,
  /// row 5 is the bottom row (where discs land first).
  final List<C4Disc?> cells;

  const C4Board._(this.cells);

  /// Empty 6×7 board.
  factory C4Board.empty() {
    return C4Board._(List<C4Disc?>.filled(rows * cols, null, growable: false));
  }

  /// **Tests only.** Construct a board directly from a row-major
  /// 42-cell list, bypassing the gravity invariant. Production code
  /// MUST use [C4Board.empty] + [apply] so every disc placement
  /// respects gravity; this factory exists purely to set up
  /// win/draw test fixtures (e.g. row-0 horizontal wins) that aren't
  /// reachable through normal play but are still valid cell
  /// configurations the win detector must score correctly.
  factory C4Board.fromCellsUnchecked(List<C4Disc?> cells) {
    if (cells.length != rows * cols) {
      throw ArgumentError(
        'C4Board.fromCellsUnchecked expects ${rows * cols} cells, '
        'got ${cells.length}',
      );
    }
    return C4Board._(List<C4Disc?>.unmodifiable(cells));
  }

  /// Cell lookup by (row, col). Returns null for empty cells; throws
  /// [RangeError] for out-of-bounds indices (callers gate via
  /// [isLegalMove] / explicit bounds checks).
  C4Disc? cellAt(int row, int col) {
    if (row < 0 || row >= rows || col < 0 || col >= cols) {
      throw RangeError('cell ($row,$col) out of bounds for ${rows}x$cols');
    }
    return cells[row * cols + col];
  }

  /// Number of placed discs. Used by the engine to detect a draw and
  /// for symmetry with TTT's [moveCount].
  int get moveCount => cells.where((c) => c != null).length;

  /// True iff every cell has a disc.
  bool get isFull => moveCount == rows * cols;

  /// Lowest empty row in [column] (0 = top, [rows]-1 = bottom), or
  /// null if the column is full. Discs fall to the bottom under
  /// gravity, so this is the row where a newly-dropped disc would
  /// land. Receivers use this on every inbound move to compute the
  /// row from the column-only payload.
  int? landingRowFor(int column) {
    if (column < 0 || column >= cols) return null;
    for (var row = rows - 1; row >= 0; row -= 1) {
      if (cells[row * cols + column] == null) return row;
    }
    return null;
  }

  /// True iff [column] is in range and not full.
  bool isLegalMove(int column) {
    return landingRowFor(column) != null;
  }

  /// Return a new board with [disc] dropped into [column]. The landing
  /// row is computed internally by gravity. Caller is responsible for
  /// legality (engine checks via [isLegalMove] + turn / status guards).
  /// Returns the same board unchanged if the column is full — callers
  /// MUST gate on [isLegalMove] first; this is a defensive no-op rather
  /// than a throw because `apply` is invoked from the engine's pure
  /// replay path which is designed to drop+log on illegal input.
  C4Board apply(int column, C4Disc disc) {
    final row = landingRowFor(column);
    if (row == null) return this;
    final next = List<C4Disc?>.of(cells, growable: false);
    next[row * cols + column] = disc;
    return C4Board._(List<C4Disc?>.unmodifiable(next));
  }

  /// Winner if there's any 4-in-a-row line (horizontal, vertical, or
  /// either diagonal direction); null otherwise. A null winner with a
  /// full board is a draw (use [isDraw]).
  C4Disc? get winner {
    for (final line in _winningLines) {
      final a = cells[line[0]];
      if (a == null) continue;
      final b = cells[line[1]];
      final c = cells[line[2]];
      final d = cells[line[3]];
      if (a == b && b == c && c == d) return a;
    }
    return null;
  }

  /// True iff the board is full with no winner.
  bool get isDraw => isFull && winner == null;

  /// Pre-computed list of every 4-cell window that constitutes a
  /// winning line. Built once at class-load time:
  ///
  ///   - 6 rows × 4 horizontal starts = 24 horizontal lines
  ///   - 3 vertical starts × 7 cols   = 21 vertical lines
  ///   - 3 row starts × 4 col starts  = 12 ↘ diagonal lines
  ///   - 3 row starts × 4 col starts  = 12 ↙ diagonal lines
  ///   - 69 lines total.
  ///
  /// Each entry is a 4-element list of cell indices into [cells].
  static final List<List<int>> _winningLines = _buildWinningLines();

  static List<List<int>> _buildWinningLines() {
    final out = <List<int>>[];
    int idx(int r, int c) => r * cols + c;

    // Horizontal: row r, cols c..c+3.
    for (var r = 0; r < rows; r += 1) {
      for (var c = 0; c <= cols - 4; c += 1) {
        out.add([idx(r, c), idx(r, c + 1), idx(r, c + 2), idx(r, c + 3)]);
      }
    }
    // Vertical: col c, rows r..r+3.
    for (var c = 0; c < cols; c += 1) {
      for (var r = 0; r <= rows - 4; r += 1) {
        out.add([idx(r, c), idx(r + 1, c), idx(r + 2, c), idx(r + 3, c)]);
      }
    }
    // Diagonal ↘ (down-right): (r, c) to (r+3, c+3).
    for (var r = 0; r <= rows - 4; r += 1) {
      for (var c = 0; c <= cols - 4; c += 1) {
        out.add([
          idx(r, c),
          idx(r + 1, c + 1),
          idx(r + 2, c + 2),
          idx(r + 3, c + 3),
        ]);
      }
    }
    // Diagonal ↙ (down-left): (r, c) to (r+3, c-3).
    for (var r = 0; r <= rows - 4; r += 1) {
      for (var c = 3; c < cols; c += 1) {
        out.add([
          idx(r, c),
          idx(r + 1, c - 1),
          idx(r + 2, c - 2),
          idx(r + 3, c - 3),
        ]);
      }
    }
    return List<List<int>>.unmodifiable(out);
  }
}

/// Whose turn is it on a fresh / mid-game C4 board?
///
/// Red always moves first (offerer convention). After that the board
/// state alone determines turn order: equal counts means red, one more
/// red means yellow.
C4Disc turnFor(C4Board board) {
  final reds = board.cells.where((c) => c == C4Disc.red).length;
  final yellows = board.cells.where((c) => c == C4Disc.yellow).length;
  return reds == yellows ? C4Disc.red : C4Disc.yellow;
}
