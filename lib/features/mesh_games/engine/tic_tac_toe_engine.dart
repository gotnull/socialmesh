// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tic-Tac-Toe engine (strict turn order, 3×3 grid).
///
/// Wire format:
///   state: [ turn(1), cells(9) ]  (cell values: 0 = empty, 1 = X, 2 = O)
///   move:  [ cellIndex(1) ]      (0–8, row-major)
///
/// X is always `participants[0]`, O is always `participants[1]`.
library;

import 'dart:typed_data';

import '../models/mesh_game_type.dart';
import 'game_engine.dart';

enum TicTacToeMark {
  empty(0),
  x(1),
  o(2);

  const TicTacToeMark(this.code);
  final int code;

  static TicTacToeMark? fromCode(int code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

class TicTacToeState {
  /// Length 9, row-major: 0=TL 1=TM 2=TR 3=ML 4=MM 5=MR 6=BL 7=BM 8=BR.
  final List<TicTacToeMark> cells;

  /// Whose move is expected (0 or 1). -1 when terminal.
  final int turnIndex;

  const TicTacToeState({required this.cells, required this.turnIndex});

  factory TicTacToeState.empty() {
    return TicTacToeState(
      cells: const [
        TicTacToeMark.empty,
        TicTacToeMark.empty,
        TicTacToeMark.empty,
        TicTacToeMark.empty,
        TicTacToeMark.empty,
        TicTacToeMark.empty,
        TicTacToeMark.empty,
        TicTacToeMark.empty,
        TicTacToeMark.empty,
      ],
      turnIndex: 0,
    );
  }

  /// Winning line indices. Exhaustive.
  static const List<List<int>> _winningLines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
    [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
    [0, 4, 8], [2, 4, 6], // diagonals
  ];

  /// Returns 0 if X won, 1 if O won, -1 for draw, null if ongoing.
  int? get winnerIndex {
    for (final line in _winningLines) {
      final a = cells[line[0]];
      if (a == TicTacToeMark.empty) continue;
      if (a == cells[line[1]] && a == cells[line[2]]) {
        return a == TicTacToeMark.x ? 0 : 1;
      }
    }
    final hasEmpty = cells.any((c) => c == TicTacToeMark.empty);
    if (!hasEmpty) return -1;
    return null;
  }

  bool get isTerminal => winnerIndex != null;
}

class TicTacToeMove {
  final int cellIndex;
  const TicTacToeMove(this.cellIndex);
}

class TicTacToeEngine extends GameEngine<TicTacToeState, TicTacToeMove> {
  const TicTacToeEngine();

  @override
  MeshGameType get gameType => MeshGameType.ticTacToeV1;

  @override
  TicTacToeState initialState({required int initiatorIndex}) {
    return TicTacToeState(
      cells: TicTacToeState.empty().cells,
      turnIndex: initiatorIndex == 1 ? 1 : 0,
    );
  }

  @override
  GameApplyResult<TicTacToeState> applyMove({
    required TicTacToeState state,
    required int actorIndex,
    required TicTacToeMove move,
  }) {
    if (state.isTerminal) {
      return const GameApplyRejected('game already terminal');
    }
    if (actorIndex != 0 && actorIndex != 1) {
      return const GameApplyRejected('actorIndex out of range');
    }
    if (actorIndex != state.turnIndex) {
      return const GameApplyRejected('not this actor\'s turn');
    }
    if (move.cellIndex < 0 || move.cellIndex >= 9) {
      return const GameApplyRejected('cellIndex out of range');
    }
    if (state.cells[move.cellIndex] != TicTacToeMark.empty) {
      return const GameApplyRejected('cell already occupied');
    }

    final mark = actorIndex == 0 ? TicTacToeMark.x : TicTacToeMark.o;
    final updated = List<TicTacToeMark>.from(state.cells);
    updated[move.cellIndex] = mark;
    final nextCells = List<TicTacToeMark>.unmodifiable(updated);

    // Compute winner on the new cell state (before flipping turn).
    final preliminary = TicTacToeState(
      cells: nextCells,
      turnIndex: state.turnIndex,
    );
    final winner = preliminary.winnerIndex;
    final terminal = winner != null;
    final nextTurn = terminal ? -1 : (actorIndex ^ 1);

    final next = TicTacToeState(cells: nextCells, turnIndex: nextTurn);
    return GameApplyAccepted<TicTacToeState>(
      state: next,
      nextTurnIndex: nextTurn,
      winnerIndex: winner,
      isTerminal: terminal,
    );
  }

  @override
  bool isActorExpected({
    required TicTacToeState state,
    required int turnIndex,
    required int actorIndex,
  }) {
    if (state.isTerminal) return false;
    return actorIndex == state.turnIndex;
  }

  @override
  Uint8List encodeMove(TicTacToeMove move) =>
      Uint8List.fromList([move.cellIndex & 0xFF]);

  @override
  TicTacToeMove decodeMove(Uint8List data) {
    if (data.isEmpty) {
      throw const FormatException('TTT move requires 1 byte');
    }
    final cell = data[0];
    if (cell >= 9) {
      throw FormatException('TTT cell index out of range: $cell');
    }
    return TicTacToeMove(cell);
  }

  @override
  Uint8List encodeState(TicTacToeState state) {
    final buf = Uint8List(10);
    buf[0] = state.turnIndex & 0xFF;
    for (var i = 0; i < 9; i++) {
      buf[1 + i] = state.cells[i].code & 0xFF;
    }
    return buf;
  }

  @override
  TicTacToeState decodeState(Uint8List data) {
    if (data.length < 10) {
      throw FormatException('TTT state requires 10 bytes, got ${data.length}');
    }
    final turn = data[0] == 0xFF ? -1 : data[0];
    final cells = List<TicTacToeMark>.unmodifiable([
      for (var i = 0; i < 9; i++)
        TicTacToeMark.fromCode(data[1 + i]) ?? TicTacToeMark.empty,
    ]);
    return TicTacToeState(cells: cells, turnIndex: turn);
  }
}
