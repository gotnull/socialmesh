// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Connect Four v1 disc colour. Determined deterministically by the
/// offer protocol: the side that sent the `offer` action plays
/// [red] (and moves first); the side that sent the `accept` action
/// plays [yellow]. Both ends arrive at the same assignment from the
/// entry log alone — no clock, no hash, no initiator tiebreak.
///
/// **Wire-only naming.** The `red` / `yellow` labels exist for
/// spec readability + parser symmetry with TTT's `x` / `o`. The UI
/// rendering layer (board widget + bubble) NEVER references these
/// names directly — it only knows about `localDisc` / `remoteDisc`
/// and chooses between `context.accentColor` and the muted-text
/// peer colour, identical to how TTT picks colours for X/O.
enum C4Disc {
  /// Wire code 0. Always assigned to the offerer.
  red(0),

  /// Wire code 1. Always assigned to the acceptor.
  yellow(1);

  const C4Disc(this.code);
  final int code;

  C4Disc get opponent => this == C4Disc.red ? C4Disc.yellow : C4Disc.red;

  static C4Disc? fromCode(int code) {
    for (final d in values) {
      if (d.code == code) return d;
    }
    return null;
  }
}

/// Decoded Connect Four move payload. Wire format is one byte:
///
/// ```
/// bits 7..4  disc     (0 = red, 1 = yellow)
/// bits 3..0  column   (0..6)
/// ```
///
/// The landing row is NOT transmitted — the receiver derives it from
/// current board state via gravity (lowest empty row in the chosen
/// column). Sending the row would be redundant and would let a
/// malicious or buggy sender desync the board.
class C4Move {
  /// Column index 0..6 (left to right).
  final int column;

  /// Which disc is being dropped. The receiver re-validates this
  /// against its own deterministic disc assignment for the sender —
  /// any mismatch is an instant drop.
  final C4Disc disc;

  const C4Move({required this.column, required this.disc});
}
