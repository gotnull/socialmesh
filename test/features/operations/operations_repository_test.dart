// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/features/operations/data/operations_database.dart';
import 'package:socialmesh/features/operations/data/operations_repository.dart';
import 'package:socialmesh/features/operations/models/operation_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late OperationsDatabase db;
  late OperationsRepository repo;

  setUp(() {
    db = OperationsDatabase(testDbPath: inMemoryDatabasePath);
    repo = OperationsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  OperationProgress sampleProgress({
    String id = 'op_x',
    int unique = 1,
    Set<String>? deduped,
    DateTime? completedAt,
  }) {
    return OperationProgress(
      operationId: id,
      objectiveProgress: {'unique': unique},
      dedupedKeys: deduped ?? const {'node_encounter:1'},
      completedAt: completedAt,
      updatedAt: DateTime.utc(2026, 5, 9, 12),
      version: 1,
    );
  }

  test('save then loadAll round-trips a single row', () async {
    final p = sampleProgress();
    await repo.saveProgress(p);

    final loaded = await repo.loadAll();
    expect(loaded.keys, {'op_x'});
    final got = loaded['op_x']!;
    expect(got.objectiveProgress, {'unique': 1});
    expect(got.dedupedKeys, {'node_encounter:1'});
    expect(got.completedAt, isNull);
    expect(got.version, 1);
  });

  test('save twice replaces the previous row (upsert)', () async {
    await repo.saveProgress(sampleProgress(unique: 1));
    await repo.saveProgress(
      sampleProgress(
        unique: 5,
        deduped: const {'node_encounter:1', 'node_encounter:2'},
        completedAt: DateTime.utc(2026, 5, 9, 13),
      ),
    );

    final loaded = await repo.loadAll();
    expect(loaded.keys.length, 1);
    final got = loaded['op_x']!;
    expect(got.objectiveProgress, {'unique': 5});
    expect(got.dedupedKeys, hasLength(2));
    // Persisted as ms-since-epoch and rehydrated as a local DateTime, so
    // compare instants rather than the DateTime instances themselves.
    expect(
      got.completedAt!.millisecondsSinceEpoch,
      DateTime.utc(2026, 5, 9, 13).millisecondsSinceEpoch,
    );
  });

  test('loadOne returns null for a missing operation id', () async {
    final loaded = await repo.loadOne('does_not_exist');
    expect(loaded, isNull);
  });

  test('appendEvent records to the event log', () async {
    await repo.saveProgress(sampleProgress());
    await repo.appendEvent(
      operationId: 'op_x',
      eventType: 'OperationNodeEncountered',
      dedupeKey: 'node_encounter:1',
      delta: 1,
      occurredAt: DateTime.utc(2026, 5, 9, 12),
      objectiveId: 'unique',
    );

    final events = await repo.recentEvents();
    expect(events, hasLength(1));
    expect(events.first['operation_id'], 'op_x');
    expect(events.first['dedupe_key'], 'node_encounter:1');
    expect(events.first['delta'], 1);
  });

  test('reset clears progress and event log', () async {
    await repo.saveProgress(sampleProgress());
    await repo.appendEvent(
      operationId: 'op_x',
      eventType: 'OperationNodeEncountered',
      dedupeKey: 'node_encounter:1',
      delta: 1,
      occurredAt: DateTime.utc(2026, 5, 9, 12),
    );

    await repo.reset();
    expect(await repo.loadAll(), isEmpty);
    expect(await repo.recentEvents(), isEmpty);
  });

  test(
    'progress survives a fresh repository wrapping the same database',
    () async {
      await repo.saveProgress(sampleProgress(unique: 7));

      final repo2 = OperationsRepository(db);
      final loaded = await repo2.loadAll();
      expect(loaded['op_x']!.objectiveProgress['unique'], 7);
    },
  );
}
