// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the non-destructive downgrade contract: a schema downgrade retains
// every table and row, and the subsequent re-upgrade re-runs migration
// blocks idempotently. A regression here is silent loss of the user's
// entire NodeDex observation history.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _allTables = <String>[
  NodeDexTables.entries,
  NodeDexTables.encounters,
  NodeDexTables.seenRegions,
  NodeDexTables.observedFromRegions,
  NodeDexTables.coSeenEdges,
  NodeDexTables.presenceTransitions,
  NodeDexTables.syncState,
  NodeDexTables.syncOutbox,
  NodeDexTables.identityChanges,
];

Future<void> _seedAllTables(Database db) async {
  await db.insert(NodeDexTables.entries, {
    NodeDexTables.colNodeNum: 42,
    NodeDexTables.colFirstSeenMs: DateTime(2026, 4, 1).millisecondsSinceEpoch,
    NodeDexTables.colLastSeenMs: DateTime(2026, 4, 2).millisecondsSinceEpoch,
    NodeDexTables.colSigilJson: '{}',
    NodeDexTables.colUpdatedAtMs: 0,
  });
  await db.insert(NodeDexTables.encounters, {
    NodeDexTables.colNodeNum: 42,
    NodeDexTables.colEncTsMs: 1000,
    NodeDexTables.colEncCreatedAtMs: 1000,
  });
  await db.insert(NodeDexTables.seenRegions, {
    NodeDexTables.colNodeNum: 42,
    NodeDexTables.colRegionKey: 'r1',
    NodeDexTables.colRegionFirstSeenMs: 1000,
    NodeDexTables.colRegionLastSeenMs: 2000,
  });
  await db.insert(NodeDexTables.observedFromRegions, {
    NodeDexTables.colNodeNum: 42,
    NodeDexTables.colRegionKey: 'r2',
    NodeDexTables.colRegionFirstSeenMs: 1000,
    NodeDexTables.colRegionLastSeenMs: 2000,
  });
  await db.insert(NodeDexTables.coSeenEdges, {
    NodeDexTables.colEdgeA: 1,
    NodeDexTables.colEdgeB: 2,
    NodeDexTables.colEdgeFirstSeenMs: 1000,
    NodeDexTables.colEdgeLastSeenMs: 2000,
  });
  await db.insert(NodeDexTables.presenceTransitions, {
    NodeDexTables.colPtNodeNum: 42,
    NodeDexTables.colPtFromState: 'offline',
    NodeDexTables.colPtToState: 'active',
    NodeDexTables.colPtTsMs: 1000,
  });
  await db.insert(NodeDexTables.syncState, {
    NodeDexTables.colSyncKey: 'watermark',
    NodeDexTables.colSyncValue: '12345',
  });
  await db.insert(NodeDexTables.syncOutbox, {
    NodeDexTables.colOutboxEntityType: 'entry',
    NodeDexTables.colOutboxEntityId: '42',
    NodeDexTables.colOutboxOp: 'upsert',
    NodeDexTables.colOutboxPayloadJson: '{}',
    NodeDexTables.colOutboxUpdatedAtMs: 1000,
  });
  await db.insert(NodeDexTables.identityChanges, {
    NodeDexTables.colNodeNum: 42,
    NodeDexTables.colIcNewPubkey: Uint8List.fromList([1, 2, 3]),
    NodeDexTables.colIcTsMs: 1000,
  });
}

Future<Map<String, int>> _rowCounts(Database db) async {
  final counts = <String, int>{};
  for (final table in _allTables) {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM $table');
    counts[table] = rows.first['n']! as int;
  }
  return counts;
}

Future<Set<String>> _existingTables(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  return rows.map((r) => r['name'] as String).toSet();
}

Future<int> _userVersion(Database db) async {
  final rows = await db.rawQuery('PRAGMA user_version');
  return rows.first.values.first! as int;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tempDir;
  late String dbPath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nodedex_downgrade_test_');
    dbPath = p.join(tempDir.path, 'nodedex.db');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<Database> openSeededCurrent() async {
    final wrapper = NodeDexDatabase(dbPathOverride: dbPath);
    final db = await wrapper.open();
    await _seedAllTables(db);
    return db;
  }

  group('non-destructive downgrade', () {
    test('reopening at an older schema version retains all data', () async {
      final db = await openSeededCurrent();
      final before = await _rowCounts(db);
      expect(before.values, everyElement(1));
      await db.close();

      // Reopen as an older binary would: the production _onDowngrade runs.
      final older = NodeDexDatabase(
        dbPathOverride: dbPath,
        schemaVersionOverride: nodedexSchemaVersion - 2,
      );
      final downgraded = await older.open();

      expect(await _existingTables(downgraded), containsAll(_allTables));
      expect(await _rowCounts(downgraded), before);
      expect(await _userVersion(downgraded), nodedexSchemaVersion - 2);
      final watermark = await downgraded.query(
        NodeDexTables.syncState,
        where: '${NodeDexTables.colSyncKey} = ?',
        whereArgs: ['watermark'],
      );
      expect(watermark.single[NodeDexTables.colSyncValue], '12345');
      // The file surviving with data also proves _attemptRecovery (which
      // deletes the file) was never reached.
      expect(File(dbPath).existsSync(), isTrue);
      await older.close();
    });

    test(
      're-upgrade after downgrade re-runs migrations idempotently',
      () async {
        final db = await openSeededCurrent();
        final before = await _rowCounts(db);
        await db.close();

        final older = NodeDexDatabase(
          dbPathOverride: dbPath,
          schemaVersionOverride: nodedexSchemaVersion - 2,
        );
        await older.open();
        await older.close();

        // Reopen at the current version: the v13/v14 blocks re-run against
        // a schema that already has their columns and tables.
        final current = NodeDexDatabase(dbPathOverride: dbPath);
        final upgraded = await current.open();

        expect(await _userVersion(upgraded), nodedexSchemaVersion);
        expect(await _rowCounts(upgraded), before);
        final cols = (await upgraded.rawQuery(
          'PRAGMA table_info(${NodeDexTables.entries})',
        )).map((r) => r['name'] as String).toSet();
        expect(cols, contains(NodeDexTables.colIdentityPubkey));
        expect(cols, contains(NodeDexTables.colIdentityChangeCount));
        await current.close();
      },
    );

    test(
      'full migration chain re-runs as a no-op from user_version 1',
      () async {
        final db = await openSeededCurrent();
        final before = await _rowCounts(db);
        await db.close();

        // Force the worst case: full v14 schema on disk, version stamp at 1,
        // so every block v2 through v14 re-executes.
        final raw = await databaseFactory.openDatabase(dbPath);
        await raw.execute('PRAGMA user_version = 1');
        await raw.close();

        final current = NodeDexDatabase(dbPathOverride: dbPath);
        final reopened = await current.open();

        expect(await _userVersion(reopened), nodedexSchemaVersion);
        expect(await _rowCounts(reopened), before);
        expect(File(dbPath).existsSync(), isTrue);
        await current.close();
      },
    );

    test('sqflite stamps user_version down on raw downgrade open', () async {
      // Pins the sqflite behavior the no-op downgrade depends on: a
      // version-only open with no handlers down-stamps without throwing,
      // and the production wrapper then re-upgrades cleanly.
      final db = await openSeededCurrent();
      final before = await _rowCounts(db);
      await db.close();

      final raw = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(version: nodedexSchemaVersion - 2),
      );
      expect(await _userVersion(raw), nodedexSchemaVersion - 2);
      await raw.close();

      final current = NodeDexDatabase(dbPathOverride: dbPath);
      final reopened = await current.open();
      expect(await _userVersion(reopened), nodedexSchemaVersion);
      expect(await _rowCounts(reopened), before);
      await current.close();
    });
  });
}
