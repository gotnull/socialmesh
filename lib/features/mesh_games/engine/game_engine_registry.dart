// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Static registry mapping `MeshGameType` to the pure engine instance.
library;

import '../models/mesh_game_type.dart';
import 'game_engine.dart';
import 'rps_engine.dart';
import 'tic_tac_toe_engine.dart';

/// Registry of pure engines for all supported game types.
///
/// Engines are const instances because they hold no mutable state —
/// they are pure functions of input state + move.
abstract final class GameEngineRegistry {
  static const RpsEngine rps = RpsEngine();
  static const TicTacToeEngine ticTacToe = TicTacToeEngine();

  /// Look up the engine implementation for [type]. Returns null for
  /// unknown types (e.g. a future `rps.v2` sent from a newer client).
  static GameEngine<Object?, Object?>? forType(MeshGameType type) {
    return switch (type) {
      MeshGameType.rpsV1 => rps as GameEngine<Object?, Object?>,
      MeshGameType.ticTacToeV1 => ticTacToe as GameEngine<Object?, Object?>,
    };
  }
}
