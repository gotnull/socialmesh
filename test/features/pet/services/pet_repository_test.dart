// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_public_state.dart';
import 'package:socialmesh/features/pet/models/pet_state.dart';
import 'package:socialmesh/features/pet/services/pet_repository.dart';
import 'package:socialmesh/features/pet/storage/pet_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  PetRepository newRepo() =>
      PetRepository(PetDatabase(dbPathOverride: inMemoryDatabasePath));

  group('PetRepository — own pet CRUD', () {
    test('loadOwnPet returns null for unknown owner', () async {
      final repo = newRepo();
      await repo.init();
      expect(await repo.loadOwnPet(42), isNull);
      await repo.close();
    });

    test('save + load round-trip preserves stage, branch, stats', () async {
      final repo = newRepo();
      await repo.init();
      final s = PetState.egg(
        ownerNodeNum: 0x1234,
        hatchedAt: DateTime(2026, 1, 1, 12),
      ).copyWith(energy: 7, mood: 3, stability: 9);
      await repo.saveOwnPet(s);
      final loaded = await repo.loadOwnPet(0x1234);
      expect(loaded, isNotNull);
      expect(loaded!.dnaSeed, s.dnaSeed);
      expect(loaded.energy, 7);
      expect(loaded.mood, 3);
      expect(loaded.stability, 9);
      await repo.close();
    });

    test('save is idempotent — repeated saves replace prior row', () async {
      final repo = newRepo();
      await repo.init();
      final s = PetState.egg(ownerNodeNum: 1, hatchedAt: DateTime(2026, 1, 1));
      await repo.saveOwnPet(s);
      await repo.saveOwnPet(s.copyWith(energy: 2));
      final loaded = await repo.loadOwnPet(1);
      expect(loaded!.energy, 2);
      await repo.close();
    });

    test('clearOwnPet removes the row', () async {
      final repo = newRepo();
      await repo.init();
      final s = PetState.egg(ownerNodeNum: 99, hatchedAt: DateTime(2026, 2, 1));
      await repo.saveOwnPet(s);
      await repo.clearOwnPet(99);
      expect(await repo.loadOwnPet(99), isNull);
      await repo.close();
    });
  });

  group('PetRepository — remote pet cache', () {
    PetPublicState publicState({
      int seed = 0xABCD1234,
      PetStage stage = PetStage.adult,
      PetBranch branch = PetBranch.steady,
      int age = 5,
    }) {
      return PetPublicState(
        dnaSeed: seed,
        stage: stage,
        branch: branch,
        mood: PetMood.content,
        ageInDays: age,
        isAsleep: false,
        isSick: false,
        isCalling: false,
        isEvolving: false,
      );
    }

    test('loadRemotePet returns null when cache is empty', () async {
      final repo = newRepo();
      await repo.init();
      expect(await repo.loadRemotePet(0xFF), isNull);
      await repo.close();
    });

    test('save + load round-trips the public state and timestamp', () async {
      final repo = newRepo();
      await repo.init();
      final observedAt = DateTime(2026, 4, 10, 10);
      await repo.saveRemotePet(
        nodeNum: 7,
        state: publicState(seed: 0xDEADBEEF, branch: PetBranch.luminous),
        observedAt: observedAt,
      );
      final obs = await repo.loadRemotePet(7);
      expect(obs, isNotNull);
      expect(obs!.nodeNum, 7);
      expect(obs.state.dnaSeed, 0xDEADBEEF);
      expect(obs.state.branch, PetBranch.luminous);
      expect(
        obs.observedAt.millisecondsSinceEpoch,
        observedAt.millisecondsSinceEpoch,
      );
      await repo.close();
    });

    test('save overwrites existing row for same nodeNum', () async {
      final repo = newRepo();
      await repo.init();
      await repo.saveRemotePet(
        nodeNum: 1,
        state: publicState(seed: 1, stage: PetStage.juvenile),
        observedAt: DateTime(2026, 4, 1),
      );
      await repo.saveRemotePet(
        nodeNum: 1,
        state: publicState(seed: 2, stage: PetStage.elder),
        observedAt: DateTime(2026, 4, 2),
      );
      final obs = await repo.loadRemotePet(1);
      expect(obs!.state.dnaSeed, 2);
      expect(obs.state.stage, PetStage.elder);
      await repo.close();
    });

    test('recentRemotePets filters by age and orders newest first', () async {
      final repo = newRepo();
      await repo.init();
      // `recentRemotePets` cuts off against real `DateTime.now()`, so
      // the test's observed timestamps MUST be anchored to real now —
      // using a fixed wall-clock date makes this test silently rot as
      // real time drifts past the hardcoded window.
      final now = DateTime.now();
      await repo.saveRemotePet(
        nodeNum: 1,
        state: publicState(seed: 0x11),
        observedAt: now.subtract(const Duration(hours: 2)),
      );
      await repo.saveRemotePet(
        nodeNum: 2,
        state: publicState(seed: 0x22),
        observedAt: now.subtract(const Duration(hours: 50)),
      );
      await repo.saveRemotePet(
        nodeNum: 3,
        state: publicState(seed: 0x33),
        observedAt: now.subtract(const Duration(minutes: 5)),
      );
      final recent = await repo.recentRemotePets(
        maxAge: const Duration(hours: 24),
      );
      // Expect nodes 1 and 3 only (node 2 is 50h old). Newest first = 3, 1.
      expect(recent.map((o) => o.nodeNum).toList(), [3, 1]);
      await repo.close();
    });

    test('clearRemotePet removes the row', () async {
      final repo = newRepo();
      await repo.init();
      await repo.saveRemotePet(
        nodeNum: 5,
        state: publicState(),
        observedAt: DateTime(2026, 4, 1),
      );
      await repo.clearRemotePet(5);
      expect(await repo.loadRemotePet(5), isNull);
      await repo.close();
    });
  });
}
