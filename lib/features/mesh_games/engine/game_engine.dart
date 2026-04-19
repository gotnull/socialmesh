// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pure, deterministic game engine abstraction.
///
/// Engines know nothing about Flutter, transport, persistence, or
/// Riverpod. They own rules, move validation, win/draw detection,
/// and binary state serialization. See
/// `docs/mesh_games/MESH_GAMES_V0_1.md` § 2.
library;

import 'dart:typed_data';

import '../models/mesh_game_type.dart';

/// Result of applying a move.
sealed class GameApplyResult<TState> {
  const GameApplyResult();
}

/// Move was accepted; resulting `state` includes the applied move.
class GameApplyAccepted<TState> extends GameApplyResult<TState> {
  final TState state;

  /// Index into `participants` for the next mover, or -1 if terminal.
  final int nextTurnIndex;

  /// Winner index (0 or 1), or -1 for draw, null for ongoing.
  final int? winnerIndex;

  /// True if the game is now terminal (win or draw).
  final bool isTerminal;

  const GameApplyAccepted({
    required this.state,
    required this.nextTurnIndex,
    required this.winnerIndex,
    required this.isTerminal,
  });
}

/// Move was rejected. `reason` is an engine-specific human-readable
/// hint for logging only.
class GameApplyRejected<TState> extends GameApplyResult<TState> {
  final String reason;

  const GameApplyRejected(this.reason);
}

/// Pure rules engine.
///
/// * `TState` — the engine's in-memory state type.
/// * `TMove`  — the engine's in-memory move type.
abstract class GameEngine<TState, TMove> {
  const GameEngine();

  /// Which game this engine implements.
  MeshGameType get gameType;

  /// Build initial state for a fresh session between two participants.
  ///
  /// `initiatorIndex` identifies which participant starts (0 or 1).
  TState initialState({required int initiatorIndex});

  /// Validate and apply `move` produced by `actorIndex`. Returns
  /// [GameApplyAccepted] or [GameApplyRejected].
  GameApplyResult<TState> applyMove({
    required TState state,
    required int actorIndex,
    required TMove move,
  });

  /// Whether `actorIndex` is expected to move at `turnIndex`.
  ///
  /// For simultaneous-commit games (RPS), both actors may be valid
  /// until both have committed.
  bool isActorExpected({
    required TState state,
    required int turnIndex,
    required int actorIndex,
  });

  /// Serialize a move to ≤ [MeshGameType.maxMoveBytes] bytes.
  Uint8List encodeMove(TMove move);

  /// Parse a move from a wire payload. Throws on malformed input.
  TMove decodeMove(Uint8List data);

  /// Serialize `state` to ≤ [MeshGameType.maxStateBytes] bytes.
  Uint8List encodeState(TState state);

  /// Parse state from a wire payload. Throws on malformed input.
  TState decodeState(Uint8List data);
}
