// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Rock-Paper-Scissors engine (best-of-one, commit-reveal).
///
/// Both participants may submit a throw at any time. Once both have
/// committed, the winner is determined and the session is terminal.
///
/// Wire format:
///   state: [ throw0(1), throw1(1) ]  (0xFF sentinel = not committed)
///   move:  [ throwOrdinal(1) ]
///
/// Throw ordinals: 0 = rock, 1 = paper, 2 = scissors.
library;

import 'dart:typed_data';

import '../models/mesh_game_type.dart';
import 'game_engine.dart';

enum RpsThrow {
  rock(0),
  paper(1),
  scissors(2);

  const RpsThrow(this.code);
  final int code;

  static RpsThrow? fromCode(int code) {
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// Immutable RPS state. `throws` is length 2; `null` = not yet committed.
class RpsState {
  final List<RpsThrow?> throws;

  const RpsState(this.throws);

  factory RpsState.empty() => const RpsState([null, null]);

  bool get bothCommitted => throws[0] != null && throws[1] != null;

  bool hasCommitted(int actorIndex) =>
      actorIndex >= 0 && actorIndex < 2 && throws[actorIndex] != null;

  /// Index of winner (0 or 1), -1 for draw, null if incomplete.
  int? get winnerIndex {
    if (!bothCommitted) return null;
    final a = throws[0]!;
    final b = throws[1]!;
    if (a == b) return -1;
    if ((a == RpsThrow.rock && b == RpsThrow.scissors) ||
        (a == RpsThrow.paper && b == RpsThrow.rock) ||
        (a == RpsThrow.scissors && b == RpsThrow.paper)) {
      return 0;
    }
    return 1;
  }
}

class RpsMove {
  final RpsThrow throwValue;
  const RpsMove(this.throwValue);
}

class RpsEngine extends GameEngine<RpsState, RpsMove> {
  const RpsEngine();

  /// Sentinel byte for "not yet committed" on the wire.
  static const int _uncommitted = 0xFF;

  @override
  MeshGameType get gameType => MeshGameType.rpsV1;

  @override
  RpsState initialState({required int initiatorIndex}) => RpsState.empty();

  @override
  GameApplyResult<RpsState> applyMove({
    required RpsState state,
    required int actorIndex,
    required RpsMove move,
  }) {
    if (actorIndex != 0 && actorIndex != 1) {
      return const GameApplyRejected('actorIndex out of range');
    }
    if (state.bothCommitted) {
      return const GameApplyRejected('game already terminal');
    }
    if (state.hasCommitted(actorIndex)) {
      return const GameApplyRejected('actor already committed');
    }
    final updated = List<RpsThrow?>.from(state.throws);
    updated[actorIndex] = move.throwValue;
    final next = RpsState(List.unmodifiable(updated));
    final isTerminal = next.bothCommitted;
    final nextTurnIndex = isTerminal ? -1 : _firstUncommitted(next);
    return GameApplyAccepted<RpsState>(
      state: next,
      nextTurnIndex: nextTurnIndex,
      winnerIndex: next.winnerIndex,
      isTerminal: isTerminal,
    );
  }

  int _firstUncommitted(RpsState state) {
    if (state.throws[0] == null) return 0;
    if (state.throws[1] == null) return 1;
    return -1;
  }

  @override
  bool isActorExpected({
    required RpsState state,
    required int turnIndex,
    required int actorIndex,
  }) {
    // RPS is commit-reveal — either actor may commit any time until
    // they personally have committed.
    if (actorIndex != 0 && actorIndex != 1) return false;
    if (state.bothCommitted) return false;
    return !state.hasCommitted(actorIndex);
  }

  @override
  Uint8List encodeMove(RpsMove move) =>
      Uint8List.fromList([move.throwValue.code]);

  @override
  RpsMove decodeMove(Uint8List data) {
    if (data.isEmpty) {
      throw const FormatException('RPS move requires 1 byte');
    }
    final t = RpsThrow.fromCode(data[0]);
    if (t == null) {
      throw FormatException('RPS throw ordinal out of range: ${data[0]}');
    }
    return RpsMove(t);
  }

  @override
  Uint8List encodeState(RpsState state) {
    return Uint8List.fromList([
      state.throws[0]?.code ?? _uncommitted,
      state.throws[1]?.code ?? _uncommitted,
    ]);
  }

  @override
  RpsState decodeState(Uint8List data) {
    if (data.length < 2) {
      throw FormatException('RPS state requires 2 bytes, got ${data.length}');
    }
    return RpsState(
      List.unmodifiable([
        data[0] == _uncommitted ? null : RpsThrow.fromCode(data[0]),
        data[1] == _uncommitted ? null : RpsThrow.fromCode(data[1]),
      ]),
    );
  }
}
