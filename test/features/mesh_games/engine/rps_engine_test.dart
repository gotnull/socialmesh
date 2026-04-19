// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_games/engine/game_engine.dart';
import 'package:socialmesh/features/mesh_games/engine/rps_engine.dart';

void main() {
  const engine = RpsEngine();

  RpsState apply(RpsState state, int actor, RpsThrow t) {
    final r = engine.applyMove(
      state: state,
      actorIndex: actor,
      move: RpsMove(t),
    );
    expect(r, isA<GameApplyAccepted<RpsState>>());
    return (r as GameApplyAccepted<RpsState>).state;
  }

  group('RpsEngine rules', () {
    test('initial state has nothing committed', () {
      final s = engine.initialState(initiatorIndex: 0);
      expect(s.throws, [null, null]);
      expect(s.bothCommitted, isFalse);
      expect(s.winnerIndex, isNull);
    });

    test('single commit advances but is not terminal', () {
      final result = engine.applyMove(
        state: RpsState.empty(),
        actorIndex: 0,
        move: const RpsMove(RpsThrow.rock),
      );
      expect(result, isA<GameApplyAccepted<RpsState>>());
      final accepted = result as GameApplyAccepted<RpsState>;
      expect(accepted.isTerminal, isFalse);
      expect(accepted.nextTurnIndex, 1);
      expect(accepted.state.hasCommitted(0), isTrue);
    });

    test('rock beats scissors', () {
      var s = apply(RpsState.empty(), 0, RpsThrow.rock);
      s = apply(s, 1, RpsThrow.scissors);
      expect(s.bothCommitted, isTrue);
      expect(s.winnerIndex, 0);
    });

    test('paper beats rock', () {
      var s = apply(RpsState.empty(), 0, RpsThrow.rock);
      s = apply(s, 1, RpsThrow.paper);
      expect(s.winnerIndex, 1);
    });

    test('scissors beats paper', () {
      var s = apply(RpsState.empty(), 0, RpsThrow.paper);
      s = apply(s, 1, RpsThrow.scissors);
      expect(s.winnerIndex, 1);
    });

    test('same throws draw', () {
      for (final t in RpsThrow.values) {
        var s = apply(RpsState.empty(), 0, t);
        s = apply(s, 1, t);
        expect(s.winnerIndex, -1, reason: 'draw for $t');
      }
    });

    test('double-commit by same actor is rejected', () {
      final s = apply(RpsState.empty(), 0, RpsThrow.rock);
      final r = engine.applyMove(
        state: s,
        actorIndex: 0,
        move: const RpsMove(RpsThrow.paper),
      );
      expect(r, isA<GameApplyRejected>());
    });

    test('applying to terminal state is rejected', () {
      var s = apply(RpsState.empty(), 0, RpsThrow.rock);
      s = apply(s, 1, RpsThrow.scissors);
      final r = engine.applyMove(
        state: s,
        actorIndex: 0,
        move: const RpsMove(RpsThrow.paper),
      );
      expect(r, isA<GameApplyRejected>());
    });

    test('actor index out of range is rejected', () {
      final r = engine.applyMove(
        state: RpsState.empty(),
        actorIndex: 2,
        move: const RpsMove(RpsThrow.rock),
      );
      expect(r, isA<GameApplyRejected>());
    });
  });

  group('RpsEngine serialization', () {
    test('state round-trips byte-for-byte', () {
      var s = apply(RpsState.empty(), 0, RpsThrow.rock);
      s = apply(s, 1, RpsThrow.paper);
      final bytes = engine.encodeState(s);
      expect(bytes.length, 2);
      final decoded = engine.decodeState(bytes);
      expect(decoded.throws[0], RpsThrow.rock);
      expect(decoded.throws[1], RpsThrow.paper);
      expect(decoded.winnerIndex, 1);
    });

    test('empty state encodes sentinel bytes and round-trips', () {
      final bytes = engine.encodeState(RpsState.empty());
      expect(bytes, [0xFF, 0xFF]);
      final decoded = engine.decodeState(bytes);
      expect(decoded.throws, [null, null]);
    });

    test('move round-trips', () {
      for (final t in RpsThrow.values) {
        final bytes = engine.encodeMove(RpsMove(t));
        expect(bytes.length, 1);
        expect(engine.decodeMove(bytes).throwValue, t);
      }
    });

    test('decodeMove rejects empty payload', () {
      expect(
        () => engine.decodeMove(Uint8List(0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('decodeMove rejects out-of-range byte', () {
      expect(
        () => engine.decodeMove(Uint8List.fromList([0x42])),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
