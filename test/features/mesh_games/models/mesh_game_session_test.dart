// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_move.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_session.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_status.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_type.dart';

void main() {
  MeshGameSession sample() {
    return MeshGameSession(
      instanceId: '0123456789abcdef',
      gameType: MeshGameType.ticTacToeV1,
      participants: List<int>.unmodifiable([0x11111111, 0x22222222]),
      initiatorNodeNum: 0x11111111,
      turnIndex: 0,
      revision: 3,
      lastMoveAt: DateTime.fromMillisecondsSinceEpoch(1744819200000),
      lastMoveBy: 0x22222222,
      status: MeshGameStatus.active,
      winnerNodeNum: null,
      stateBlob: Uint8List.fromList([0, 1, 0, 2, 1, 0, 0, 0, 0, 0]),
      moves: [
        MeshGameMove(
          revision: 3,
          byNodeNum: 0x22222222,
          data: Uint8List.fromList([4]),
          acceptedAt: DateTime.fromMillisecondsSinceEpoch(1744819200000),
        ),
      ],
    );
  }

  test('toConfig survives JSON round-trip', () {
    final s = sample();
    final encoded = jsonEncode(s.toConfig());
    final decoded = MeshGameSession.tryFromConfig(
      instanceId: s.instanceId,
      config: Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );
    expect(decoded, isNotNull);
    expect(decoded!.gameType, s.gameType);
    expect(decoded.participants, s.participants);
    expect(decoded.initiatorNodeNum, s.initiatorNodeNum);
    expect(decoded.turnIndex, s.turnIndex);
    expect(decoded.revision, s.revision);
    expect(decoded.status, s.status);
    expect(decoded.stateBlob, s.stateBlob);
    expect(decoded.moves.length, 1);
    expect(decoded.moves.first.revision, 3);
    expect(decoded.moves.first.byNodeNum, 0x22222222);
    expect(decoded.moves.first.data, [4]);
  });

  test('tryFromConfig rejects wrong participant count', () {
    final config = sample().toConfig();
    config['participants'] = [0x11111111];
    final decoded = MeshGameSession.tryFromConfig(
      instanceId: 'x',
      config: config,
    );
    expect(decoded, isNull);
  });

  test('tryFromConfig rejects unknown gameType identifier', () {
    final config = sample().toConfig();
    config['gameType'] = 'rps.v99';
    final decoded = MeshGameSession.tryFromConfig(
      instanceId: 'x',
      config: config,
    );
    expect(decoded, isNull);
  });

  test('copyWith supports clearing winnerNodeNum back to null', () {
    final s = sample().copyWith(winnerNodeNum: 0x11111111);
    expect(s.winnerNodeNum, 0x11111111);
    final cleared = s.copyWith(winnerNodeNum: null);
    expect(cleared.winnerNodeNum, isNull);
  });

  test('copyWith preserves winnerNodeNum when argument omitted', () {
    final s = sample().copyWith(winnerNodeNum: 0x22222222);
    final next = s.copyWith(revision: 9);
    expect(next.winnerNodeNum, 0x22222222);
  });

  test('isLocalTurn matches currentTurnNodeNum', () {
    final s = sample();
    expect(s.isLocalTurn(0x11111111), isTrue);
    expect(s.isLocalTurn(0x22222222), isFalse);
  });

  test('opponentNodeNum resolves the other participant', () {
    final s = sample();
    expect(s.opponentNodeNum(0x11111111), 0x22222222);
    expect(s.opponentNodeNum(0x22222222), 0x11111111);
  });

  test('terminal status is exposed via isTerminal', () {
    final s = sample().copyWith(status: MeshGameStatus.completed);
    expect(s.status.isTerminal, isTrue);
  });
}
