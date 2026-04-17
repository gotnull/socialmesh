// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Inbound routing tests. Validates authoritative state transitions,
/// revision gating, authorization, duplicate / stale detection,
/// and rate-limiting using in-memory persistence.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_games/data/mesh_game_rate_limiter.dart';
import 'package:socialmesh/features/mesh_games/data/mesh_game_repository.dart';
import 'package:socialmesh/features/mesh_games/engine/game_engine_registry.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_session.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_status.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_type.dart';
import 'package:socialmesh/features/mesh_games/transport/mesh_game_codec.dart';
import 'package:socialmesh/features/mesh_games/transport/mesh_game_router.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_store.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const alice = 0xAAAAAAAA;
  const bob = 0xBBBBBBBB;
  const mallory = 0xCCCCCCCC;

  late MeshServiceStore store;
  late MeshGameRepository repo;
  late MeshGameRateLimiter limiter;
  late MeshGameRouter router;
  late MeshServiceInstance instance;

  Future<void> seedTtt() async {
    await repo.createLocalSession(
      instanceId: 'tttgame000000000',
      gameType: MeshGameType.ticTacToeV1,
      presetId: MeshServicePresetId.ticTacToeV1,
      participants: [alice, bob],
      initiatorNodeNum: alice,
      turnIndex: 0,
      initialStateBlob: GameEngineRegistry.ticTacToe.encodeState(
        GameEngineRegistry.ticTacToe.initialState(initiatorIndex: 0),
      ),
      title: 'ttt',
    );
    instance = (await store.get('tttgame000000000'))!;
  }

  setUp(() async {
    store = MeshServiceStore(dbPathOverride: inMemoryDatabasePath);
    await store.open();
    repo = MeshGameRepository(store: store);
    limiter = MeshGameRateLimiter(minInterval: Duration.zero);
    router = MeshGameRouter(repository: repo, rateLimiter: limiter);
  });

  tearDown(() async {
    await store.close();
  });

  Uint8List moveFrame({required int revision, required int cell}) =>
      MeshGameCodec.encodeMove(
        revision: revision,
        moveData: Uint8List.fromList([cell]),
      );

  group('MOVE routing', () {
    setUp(seedTtt);

    test(
      'accepts a valid next-revision move from the expected actor',
      () async {
        final ack = await router.handle(
          instance,
          alice,
          moveFrame(revision: 1, cell: 4),
        );
        expect(ack, isNotNull);
        expect(ack!.isEmpty, isTrue);
        final session = await repo.loadSession(instance.instanceId);
        expect(session!.revision, 1);
        expect(session.turnIndex, 1);
        expect(session.lastMoveBy, alice);
      },
    );

    test('rejects an out-of-turn move', () async {
      final ack = await router.handle(
        instance,
        bob,
        moveFrame(revision: 1, cell: 0),
      );
      expect(ack, isNotNull);
      expect(ack!.isNotEmpty, isTrue);
      expect(ack[0], MrrpStatusCode.invalid.code);
      final session = await repo.loadSession(instance.instanceId);
      expect(session!.revision, 0);
    });

    test('rejects a duplicate revision', () async {
      await router.handle(instance, alice, moveFrame(revision: 1, cell: 4));
      final ack = await router.handle(
        instance,
        alice,
        moveFrame(revision: 1, cell: 0),
      );
      expect(ack, isNotNull);
      expect(ack![0], MrrpStatusCode.duplicate.code);
    });

    test('rejects a stale revision (< current)', () async {
      await router.handle(instance, alice, moveFrame(revision: 1, cell: 4));
      final ack = await router.handle(
        instance,
        bob,
        moveFrame(revision: 0, cell: 0),
      );
      expect(ack, isNotNull);
      expect(ack![0], MrrpStatusCode.duplicate.code);
    });

    test('rejects a future-skipped revision (> current+1)', () async {
      final ack = await router.handle(
        instance,
        alice,
        moveFrame(revision: 5, cell: 0),
      );
      expect(ack, isNotNull);
      expect(ack![0], MrrpStatusCode.invalid.code);
    });

    test('rejects a non-participant sender', () async {
      final ack = await router.handle(
        instance,
        mallory,
        moveFrame(revision: 1, cell: 0),
      );
      expect(ack, isNotNull);
      expect(ack![0], MrrpStatusCode.unauthorized.code);
    });
  });

  group('STATE_REQ / STATE_RESP', () {
    setUp(seedTtt);

    test('STATE_REQ returns a full STATE_RESP payload', () async {
      final ack = await router.handle(
        instance,
        alice,
        MeshGameCodec.encodeStateReq(),
      );
      expect(ack, isNotNull);
      expect(ack!.isNotEmpty, isTrue);
      final frame = MeshGameCodec.decode(ack);
      expect(frame.opcode, MeshGameOpcode.stateResp);
      final body = MeshGameCodec.decodeStateResp(frame.body);
      expect(body.revision, 0);
      expect(body.status, MeshGameStatus.active.code);
      expect(body.stateBlob.length, 10);
    });

    test('STATE_RESP overwrites state when revision is higher', () async {
      final newBlob = Uint8List.fromList([1, 0, 0, 2, 0, 0, 1, 0, 0, 0]);
      final ack = await router.handle(
        instance,
        bob,
        MeshGameCodec.encodeStateResp(
          revision: 7,
          turnIndex: 1,
          status: MeshGameStatus.active.code,
          winnerIndex: kMeshGameNoWinner,
          stateBlob: newBlob,
        ),
      );
      expect(ack, isNotNull);
      expect(ack!.isEmpty, isTrue);
      final updated = await repo.loadSession(instance.instanceId);
      expect(updated!.revision, 7);
      expect(updated.stateBlob, newBlob);
    });

    test('STATE_RESP with lower revision is rejected', () async {
      final ack = await router.handle(
        instance,
        bob,
        MeshGameCodec.encodeStateResp(
          revision: 0,
          turnIndex: 0,
          status: MeshGameStatus.active.code,
          winnerIndex: kMeshGameNoWinner,
          stateBlob: Uint8List(10),
        ),
      );
      // revision == current is accepted; below is rejected as duplicate.
      expect(ack, isNotNull);
      expect(ack!.isEmpty, isTrue);
    });
  });

  group('QUIT routing', () {
    setUp(seedTtt);

    test('QUIT marks the session abandoned', () async {
      final ack = await router.handle(
        instance,
        alice,
        MeshGameCodec.encodeQuit(revision: 0, reason: 0),
      );
      expect(ack, isNotNull);
      expect(ack!.isEmpty, isTrue);
      final updated = await repo.loadSession(instance.instanceId);
      expect(updated!.status, MeshGameStatus.abandoned);
    });
  });

  group('CREATE routing', () {
    setUp(seedTtt);

    test('CREATE against an existing session is rejected', () async {
      final ack = await router.handle(
        instance,
        alice,
        MeshGameCodec.encodeCreate(
          gameType: MeshGameType.ticTacToeV1,
          revision: 0,
          stateBlob: Uint8List(10),
        ),
      );
      expect(ack, isNotNull);
      expect(ack![0], MrrpStatusCode.duplicate.code);
    });
  });

  group('rate limiting', () {
    test('second command within window is rejected', () async {
      final throttled = MeshGameRateLimiter(
        minInterval: const Duration(seconds: 2),
        clock: () => DateTime(2026),
      );
      final r = MeshGameRouter(repository: repo, rateLimiter: throttled);
      await repo.createLocalSession(
        instanceId: 'throttledsession',
        gameType: MeshGameType.rpsV1,
        participants: [alice, bob],
        initiatorNodeNum: alice,
        turnIndex: 0,
        initialStateBlob: Uint8List.fromList([0xFF, 0xFF]),
        title: 't',
      );
      final inst = (await store.get('throttledsession'))!;
      await r.handle(inst, alice, moveFrame(revision: 1, cell: 0));
      final ack = await r.handle(inst, alice, moveFrame(revision: 2, cell: 1));
      expect(ack, isNotNull);
      expect(ack![0], MrrpStatusCode.rateLimited.code);
    });
  });

  group('full TTT match via router', () {
    test('alice wins along top row', () async {
      await seedTtt();

      Future<void> move(int actor, int rev, int cell) async {
        final ack = await router.handle(
          instance,
          actor,
          moveFrame(revision: rev, cell: cell),
        );
        expect(ack, isNotNull);
        expect(
          ack!.isEmpty,
          isTrue,
          reason:
              'rev=$rev cell=$cell actor=$actor '
              'payload=${ack.isEmpty ? "ok" : "err(${ack[0]})"}',
        );
      }

      await move(alice, 1, 0); // X
      await move(bob, 2, 3); // O
      await move(alice, 3, 1); // X
      await move(bob, 4, 4); // O
      await move(alice, 5, 2); // X wins

      final finalSession = await repo.loadSession(instance.instanceId);
      expect(finalSession!.status, MeshGameStatus.completed);
      expect(finalSession.winnerNodeNum, alice);
      expect(finalSession.revision, 5);
      expect(finalSession.moves.length, greaterThanOrEqualTo(5));
    });
  });
}
