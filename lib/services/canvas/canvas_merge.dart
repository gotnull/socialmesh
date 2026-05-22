// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Shared Last-Write-Wins comparator for canvas paint operations.
//
// Authoritative spec: docs/canvas/CANVAS_V0_1.md §8. Both the
// repository (when applying inbound ops to the cell table) and the
// codec/router layer (for any pre-DB conflict resolution in tests or
// future merge-in-batch optimizations) call into this one place so
// they cannot diverge.
//
// Invariants this function MUST preserve forever:
//
//   I1.LWW.totalOrder
//     The comparator induces a deterministic total order on the tuple
//     (op_ts, author_id, op_seq mod 256). Two peers applying the same
//     accepted op set in different arrival orders converge to the
//     same per-cell state.
//
//   I1.LWW.modSeq
//     The third clause uses an unsigned 8-bit "forward window" of
//     [1..127] — values outside that window are rejected. This makes
//     op_seq rollover safe within a single wall-clock second.
//
// Do NOT inline or duplicate this comparator. Tests pin its behaviour
// directly; future changes must update spec + tests + every call site
// in one slice.
library;

/// Pure Last-Write-Wins comparator. Returns `true` when the inbound
/// `(opTs, opAuthor, opSeq)` triple should overwrite the cell's
/// currently-stored `(currentTs, currentAuthor, currentSeq)`.
///
/// Implements exactly the rule from CANVAS_V0_1.md §8:
///
/// ```
/// accept_op(op, current):
///   if op.ts > current.last_ts: return true
///   if op.ts == current.last_ts and op.author < current.last_author: return true
///   if op.ts == current.last_ts and op.author == current.last_author
///      and ((op.seq - current.last_seq) & 0xFF) in [1..127]: return true
///   return false
/// ```
bool canvasMergeAccept({
  required int opTs,
  required int opAuthor,
  required int opSeq,
  required int currentTs,
  required int currentAuthor,
  required int currentSeq,
}) {
  if (opTs > currentTs) return true;
  if (opTs == currentTs && opAuthor < currentAuthor) return true;
  if (opTs == currentTs && opAuthor == currentAuthor) {
    final delta = (opSeq - currentSeq) & 0xFF;
    if (delta >= 1 && delta <= 127) return true;
  }
  return false;
}
