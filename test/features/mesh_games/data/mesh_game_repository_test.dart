// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_games/data/mesh_game_repository.dart';
import 'package:socialmesh/features/mesh_games/engine/game_engine_registry.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_move.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_status.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_type.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late MeshServiceStore store;
  late MeshGameRepository repo;

  setUp(() async {
    store = MeshServiceStore(dbPathOverride: inMemoryDatabasePath);
    await store.open();
    repo = MeshGameRepository(store: store);
  });

  tearDown(() async {
    await store.close();
  });

  test(
    'createLocalSession persists a session that can be loaded back',
    () async {
      final created = await repo.createLocalSession(
        instanceId: 'abc0123456789def',
        gameType: MeshGameType.ticTacToeV1,
        presetId: MeshServicePresetId.ticTacToeV1,
        title: 'ttt@2',
        participants: [0x11, 0x22],
        initiatorNodeNum: 0x11,
        turnIndex: 0,
        initialStateBlob: GameEngineRegistry.ticTacToe.encodeState(
          GameEngineRegistry.ticTacToe.initialState(initiatorIndex: 0),
        ),
      );
      expect(created, isNotNull);
      final loaded = await repo.loadSession('abc0123456789def');
      expect(loaded, isNotNull);
      expect(loaded!.gameType, MeshGameType.ticTacToeV1);
      expect(loaded.participants, [0x11, 0x22]);
      expect(loaded.revision, 0);
      expect(loaded.status, MeshGameStatus.active);
    },
  );

  test('saveSession persists updated revision + state', () async {
    await repo.createLocalSession(
      instanceId: 'abc0123456789def',
      gameType: MeshGameType.rpsV1,
      participants: [1, 2],
      initiatorNodeNum: 1,
      turnIndex: 0,
      initialStateBlob: Uint8List.fromList([0xFF, 0xFF]),
      title: 't',
    );
    final original = await repo.loadSession('abc0123456789def');
    expect(original, isNotNull);
    final updated = original!.copyWith(
      revision: 5,
      stateBlob: Uint8List.fromList([0, 1]),
      status: MeshGameStatus.completed,
      winnerNodeNum: 1,
      moves: [
        MeshGameMove(
          revision: 5,
          byNodeNum: 1,
          data: Uint8List.fromList([0]),
          acceptedAt: DateTime.now(),
        ),
      ],
    );
    await repo.saveSession(updated);

    final reloaded = await repo.loadSession('abc0123456789def');
    expect(reloaded!.revision, 5);
    expect(reloaded.stateBlob, [0, 1]);
    expect(reloaded.status, MeshGameStatus.completed);
    expect(reloaded.winnerNodeNum, 1);
    expect(reloaded.moves.length, 1);
  });

  test('listActiveGames filters by canonical type game', () async {
    await repo.createLocalSession(
      instanceId: 'gameabcdef123456',
      gameType: MeshGameType.rpsV1,
      participants: [1, 2],
      initiatorNodeNum: 1,
      turnIndex: 0,
      initialStateBlob: Uint8List.fromList([0xFF, 0xFF]),
      title: 't',
    );

    final list = await repo.listActiveGames();
    expect(list.length, 1);
    expect(list.first.gameType, MeshGameType.rpsV1);
  });

  test('listActiveGames returns [] when the store is empty', () async {
    final list = await repo.listActiveGames();
    expect(list, isEmpty);
  });

  test('deleteSession removes a persisted game', () async {
    await repo.createLocalSession(
      instanceId: 'deletionsamplexx',
      gameType: MeshGameType.rpsV1,
      participants: [1, 2],
      initiatorNodeNum: 1,
      turnIndex: 0,
      initialStateBlob: Uint8List.fromList([0xFF, 0xFF]),
      title: 't',
    );
    await repo.deleteSession('deletionsamplexx');
    final loaded = await repo.loadSession('deletionsamplexx');
    expect(loaded, isNull);
  });

  test('loadSession ignores non-game canonical types', () async {
    // Insert a non-game instance manually.
    await store.insert(
      MeshServiceInstance(
        instanceId: 'listxxxxxxxxxxxx',
        canonicalType: MeshServiceType.list,
        title: 'shopping',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
        config: const {
          'items': ['a', 'b'],
        },
      ),
    );
    final loaded = await repo.loadSession('listxxxxxxxxxxxx');
    expect(loaded, isNull);
  });
}
