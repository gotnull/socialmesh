// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_games/engine/game_engine.dart';
import 'package:socialmesh/features/mesh_games/engine/tic_tac_toe_engine.dart';

void main() {
  const engine = TicTacToeEngine();

  TicTacToeState apply(TicTacToeState state, int actor, int cell) {
    final r = engine.applyMove(
      state: state,
      actorIndex: actor,
      move: TicTacToeMove(cell),
    );
    expect(r, isA<GameApplyAccepted<TicTacToeState>>());
    return (r as GameApplyAccepted<TicTacToeState>).state;
  }

  group('TicTacToeEngine rules', () {
    test('initial state is empty with turnIndex 0', () {
      final s = engine.initialState(initiatorIndex: 0);
      expect(s.cells.every((c) => c == TicTacToeMark.empty), isTrue);
      expect(s.turnIndex, 0);
      expect(s.isTerminal, isFalse);
    });

    test('initiatorIndex 1 starts O', () {
      final s = engine.initialState(initiatorIndex: 1);
      expect(s.turnIndex, 1);
    });

    test('turn alternates after each move', () {
      var s = apply(engine.initialState(initiatorIndex: 0), 0, 0);
      expect(s.cells[0], TicTacToeMark.x);
      expect(s.turnIndex, 1);
      s = apply(s, 1, 4);
      expect(s.cells[4], TicTacToeMark.o);
      expect(s.turnIndex, 0);
    });

    test('row win is detected', () {
      var s = engine.initialState(initiatorIndex: 0);
      s = apply(s, 0, 0);
      s = apply(s, 1, 3);
      s = apply(s, 0, 1);
      s = apply(s, 1, 4);
      final r =
          engine.applyMove(
                state: s,
                actorIndex: 0,
                move: const TicTacToeMove(2),
              )
              as GameApplyAccepted<TicTacToeState>;
      expect(r.isTerminal, isTrue);
      expect(r.winnerIndex, 0);
      expect(r.nextTurnIndex, -1);
    });

    test('column win is detected', () {
      var s = engine.initialState(initiatorIndex: 0);
      s = apply(s, 0, 0);
      s = apply(s, 1, 1);
      s = apply(s, 0, 3);
      s = apply(s, 1, 2);
      final r =
          engine.applyMove(
                state: s,
                actorIndex: 0,
                move: const TicTacToeMove(6),
              )
              as GameApplyAccepted<TicTacToeState>;
      expect(r.winnerIndex, 0);
    });

    test('diagonal win is detected', () {
      var s = engine.initialState(initiatorIndex: 0);
      s = apply(s, 0, 0);
      s = apply(s, 1, 1);
      s = apply(s, 0, 4);
      s = apply(s, 1, 2);
      final r =
          engine.applyMove(
                state: s,
                actorIndex: 0,
                move: const TicTacToeMove(8),
              )
              as GameApplyAccepted<TicTacToeState>;
      expect(r.winnerIndex, 0);
    });

    test('draw is detected when board fills with no winner', () {
      var s = engine.initialState(initiatorIndex: 0);
      // Sequence produces a draw:
      // X O X
      // X O O
      // O X X
      s = apply(s, 0, 0); // X
      s = apply(s, 1, 1); // O
      s = apply(s, 0, 2); // X
      s = apply(s, 1, 4); // O
      s = apply(s, 0, 3); // X
      s = apply(s, 1, 5); // O
      s = apply(s, 0, 7); // X
      s = apply(s, 1, 6); // O
      final r =
          engine.applyMove(
                state: s,
                actorIndex: 0,
                move: const TicTacToeMove(8),
              )
              as GameApplyAccepted<TicTacToeState>;
      expect(r.isTerminal, isTrue);
      expect(r.winnerIndex, -1);
    });

    test('move on occupied cell is rejected', () {
      final s = apply(engine.initialState(initiatorIndex: 0), 0, 4);
      final r = engine.applyMove(
        state: s,
        actorIndex: 1,
        move: const TicTacToeMove(4),
      );
      expect(r, isA<GameApplyRejected>());
    });

    test('out-of-turn move is rejected', () {
      final s = engine.initialState(initiatorIndex: 0);
      final r = engine.applyMove(
        state: s,
        actorIndex: 1,
        move: const TicTacToeMove(0),
      );
      expect(r, isA<GameApplyRejected>());
    });

    test('move after terminal state is rejected', () {
      var s = engine.initialState(initiatorIndex: 0);
      s = apply(s, 0, 0);
      s = apply(s, 1, 3);
      s = apply(s, 0, 1);
      s = apply(s, 1, 4);
      s = apply(s, 0, 2); // X wins row
      final r = engine.applyMove(
        state: s,
        actorIndex: 1,
        move: const TicTacToeMove(5),
      );
      expect(r, isA<GameApplyRejected>());
    });

    test('out-of-range cell index is rejected', () {
      final r = engine.applyMove(
        state: engine.initialState(initiatorIndex: 0),
        actorIndex: 0,
        move: const TicTacToeMove(9),
      );
      expect(r, isA<GameApplyRejected>());
    });
  });

  group('TicTacToeEngine serialization', () {
    test('state round-trips byte-for-byte', () {
      var s = engine.initialState(initiatorIndex: 0);
      s = apply(s, 0, 0);
      s = apply(s, 1, 4);
      final bytes = engine.encodeState(s);
      expect(bytes.length, 10);
      final decoded = engine.decodeState(bytes);
      expect(decoded.turnIndex, s.turnIndex);
      expect(decoded.cells, s.cells);
    });

    test('move round-trips for all 9 cells', () {
      for (var i = 0; i < 9; i++) {
        final bytes = engine.encodeMove(TicTacToeMove(i));
        expect(bytes.length, 1);
        expect(engine.decodeMove(bytes).cellIndex, i);
      }
    });

    test('decodeMove rejects cell ≥ 9', () {
      expect(
        () => engine.decodeMove(Uint8List.fromList([9])),
        throwsA(isA<FormatException>()),
      );
    });

    test('decodeState rejects short payload', () {
      expect(
        () => engine.decodeState(Uint8List.fromList([0, 0, 0])),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
