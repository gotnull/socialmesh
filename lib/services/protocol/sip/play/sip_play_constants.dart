// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SIP Play v1 — wire constants for the turn-based mini-game framework
// that rides inside accepted SIP Handshake DM sessions.
//
// Wire is intentionally tiny. The full envelope before the SIP DM
// frame wrapper is:
//
//   u8  typeAndVersion   // 0x11 = type=1 (SipPlay) version=1
//   u8  gameType         // see SipPlayGameType — 0x01 = TTT
//   u16 instanceId       // big-endian, scoped to (sessionTag, peer pair)
//   u8  action           // see SipPlayAction
//   u8  seq              // strict per-instance monotonic
//   ... game-specific payload bytes
//
// No partial sync semantics in v1: the `sync` action slot is reserved
// for the wire enum but receivers MUST drop it without applying state
// changes. Recovery from out-of-order or seq-mismatched frames is
// drop-and-log; users resign + re-offer if a game wedges. This keeps
// replay deterministic and tests trivial — the same discipline that
// made SIP Ink robust.

/// Static constants for the SIP Play wire envelope.
abstract final class SipPlayConstants {
  /// First byte of the envelope. High nibble identifies the protocol
  /// family ("SIP Play"), low nibble the version. Receivers reject
  /// any other value.
  static const int envelopeTypeAndVersionV1 = 0x11;

  /// Header size in bytes before the game-specific payload:
  /// `typeAndVersion(1) + gameType(1) + instanceId(2) + action(1) + seq(1)`.
  static const int envelopeHeaderBytes = 6;

  /// Hard upper bound on a single SIP Play envelope's total wire size,
  /// inclusive of the 6-byte header. Per-game payload budgets are
  /// declared by each [SipPlayGame] and validated by the codec; this
  /// constant is the framework-wide ceiling that no game may exceed.
  /// Must stay well below the SIP DM payload max so the rate limiter
  /// pre-account stays accurate even at the largest legal envelope.
  static const int maxEnvelopeBytes = 64;

  /// Maximum legal `seq` value. The seq field is u8 so a long-running
  /// game with many moves must terminate before this wraps. Tic-Tac-Toe
  /// completes in at most 9 moves, so this is comfortable headroom.
  static const int maxSeqValue = 0xFF;
}

/// Game registry id. Receivers that don't have a registered handler
/// for a given id render the entry as the "unsupported game" fallback
/// (no crash, no state mutation).
enum SipPlayGameType {
  /// Tic-Tac-Toe v1 — 3x3 grid, classic rules.
  ticTacToe(0x01);

  const SipPlayGameType(this.code);
  final int code;

  /// Resolve a wire byte to a known game type. Returns null for
  /// unknown / reserved codes — receivers must render those as the
  /// safe unsupported fallback.
  static SipPlayGameType? fromCode(int code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// SIP Play action codes. Each enum value carries its wire byte.
///
/// **`sync` (0x05) is reserved in v1.** The slot exists so future
/// versions can introduce snapshot-based recovery without a wire
/// re-numbering, but v1 senders MUST NOT emit it and v1 receivers
/// MUST drop it without applying state changes. Recovery from
/// out-of-order or seq-mismatched frames in v1 is drop-and-log only.
enum SipPlayAction {
  /// Initiate a game. Game-specific payload is empty. Sender plays
  /// the "first" mark (e.g. X in TTT) by deterministic rule.
  offer(0x00),

  /// Accept a pending offer. Empty payload.
  accept(0x01),

  /// Decline a pending offer. Empty payload. Distinct from `resign`
  /// — declining is "no thanks" before play starts, not surrendering
  /// an active game.
  decline(0x02),

  /// Apply a move. Game-specific payload (e.g. one byte for TTT).
  /// Only legal when the local instance state is `active` AND the
  /// sender is the current turn-holder.
  move(0x03),

  /// Surrender an active game. Empty payload. Only legal when the
  /// instance is `active`. Sets a terminal state — no further moves.
  resign(0x04),

  /// Reserved in v1 — see enum-level dartdoc. Receivers drop without
  /// applying state.
  sync(0x05);

  const SipPlayAction(this.code);
  final int code;

  static SipPlayAction? fromCode(int code) {
    for (final a in values) {
      if (a.code == code) return a;
    }
    return null;
  }
}
