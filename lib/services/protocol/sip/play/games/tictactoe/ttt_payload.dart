// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tic-Tac-Toe v1 mark. Determined deterministically by the offer
/// protocol: the side that sent the `offer` action is [x] (and moves
/// first); the side that sent the `accept` action is [o]. Both ends
/// arrive at the same assignment from the entry log alone — no clock,
/// no hash, no initiator tiebreak.
enum TttMark {
  /// Wire code 0. Always assigned to the offerer.
  x(0),

  /// Wire code 1. Always assigned to the acceptor.
  o(1);

  const TttMark(this.code);
  final int code;

  TttMark get opponent => this == TttMark.x ? TttMark.o : TttMark.x;

  static TttMark? fromCode(int code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// Decoded TTT move payload. Wire format is one byte:
///
/// ```
/// bits 7..4  mark   (0 = X, 1 = O)
/// bits 3..0  cell   (0..8)
/// ```
class TttMove {
  /// Cell index 0..8 (row-major: 0,1,2 = top row).
  final int cell;

  /// Which mark is being placed. The receiver re-validates this
  /// against its own deterministic mark assignment for the sender —
  /// any mismatch is an instant drop.
  final TttMark mark;

  const TttMove({required this.cell, required this.mark});
}
