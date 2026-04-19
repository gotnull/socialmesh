// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Game-type → board widget dispatch.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../engine/game_engine_registry.dart';
import '../engine/rps_engine.dart';
import '../engine/tic_tac_toe_engine.dart';
import '../models/mesh_game_session.dart';
import '../models/mesh_game_type.dart';
import 'boards/rps_chooser.dart';
import 'boards/tic_tac_toe_board.dart';

/// Dispatcher that builds the correct board widget for a session.
abstract final class GameBodyRegistry {
  static Widget buildFor({
    required MeshGameSession session,
    required int myNodeNum,
    required void Function(Object move) onMove,
  }) {
    switch (session.gameType) {
      case MeshGameType.rpsV1:
        final state = GameEngineRegistry.rps.decodeState(session.stateBlob);
        return RpsChooser(
          session: session,
          state: state,
          myNodeNum: myNodeNum,
          onCommit: (t) => onMove(RpsMove(t)),
        );
      case MeshGameType.ticTacToeV1:
        final state = GameEngineRegistry.ticTacToe.decodeState(
          session.stateBlob,
        );
        return TicTacToeBoard(
          session: session,
          state: state,
          myNodeNum: myNodeNum,
          onTap: (cell) => onMove(TicTacToeMove(cell)),
        );
    }
  }

  /// Small fallback placeholder used when state cannot be decoded.
  static Widget fallback(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Text(
        message,
        style: context.bodySecondaryStyle?.copyWith(
          color: context.textSecondary,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}
