// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/features/nodedex/models/node_group.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_groups_store.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  NodeGroup makeGroup(
    String id, {
    String name = 'Group',
    int color = 0xFF22C55E,
    String iconKey = 'label',
    int sortOrder = 0,
    int ts = 1000,
  }) {
    return NodeGroup(
      id: id,
      name: name,
      colorValue: color,
      iconKey: iconKey,
      sortOrder: sortOrder,
      createdAtMs: ts,
      updatedAtMs: ts,
    );
  }

  group('v15 schema migration', () {
    test('fresh schema exposes the groups + node_groups tables', () async {
      final database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      await database.open();
      addTearDown(database.close);

      final db = database.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(names, contains(NodeDexTables.groups));
      expect(names, contains(NodeDexTables.nodeGroups));
    });

    test('migration from a simulated v14-shaped database adds group tables '
        'without disturbing existing entries', () async {
      final tempDir = Directory.systemTemp.createTempSync('nodedex_v15_test_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      final dbPath = p.join(tempDir.path, 'nodedex_v14.db');

      // Minimal v14-shaped entries table with one row.
      final v14 = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 14,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE ${NodeDexTables.entries} (
                ${NodeDexTables.colNodeNum} INTEGER PRIMARY KEY,
                ${NodeDexTables.colFirstSeenMs} INTEGER NOT NULL,
                ${NodeDexTables.colLastSeenMs} INTEGER NOT NULL,
                ${NodeDexTables.colEncounterCount} INTEGER NOT NULL DEFAULT 1,
                ${NodeDexTables.colMessageCount} INTEGER NOT NULL DEFAULT 0,
                ${NodeDexTables.colSigilJson} TEXT NOT NULL,
                ${NodeDexTables.colSchemaVersion} INTEGER NOT NULL DEFAULT 1,
                ${NodeDexTables.colUpdatedAtMs} INTEGER NOT NULL,
                ${NodeDexTables.colDeleted} INTEGER NOT NULL DEFAULT 0
              )
            ''');
          },
        ),
      );
      await v14.insert(NodeDexTables.entries, {
        NodeDexTables.colNodeNum: 42,
        NodeDexTables.colFirstSeenMs: 1,
        NodeDexTables.colLastSeenMs: 2,
        NodeDexTables.colEncounterCount: 7,
        NodeDexTables.colMessageCount: 3,
        NodeDexTables.colSigilJson: '{}',
        NodeDexTables.colSchemaVersion: 1,
        NodeDexTables.colUpdatedAtMs: 0,
        NodeDexTables.colDeleted: 0,
      });
      await v14.close();

      final wrapper = NodeDexDatabase(dbPathOverride: dbPath);
      final db = await wrapper.open();
      addTearDown(wrapper.close);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(
        names,
        containsAll([NodeDexTables.groups, NodeDexTables.nodeGroups]),
      );

      // Existing entry survived the upgrade untouched.
      final rows = await db.query(NodeDexTables.entries);
      expect(rows, hasLength(1));
      expect(rows.first[NodeDexTables.colEncounterCount], 7);
    });
  });

  group('NodeGroupsStore', () {
    late NodeDexDatabase database;
    late NodeGroupsStore store;

    setUp(() async {
      database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      await database.open();
      store = NodeGroupsStore(database);
    });

    tearDown(() async {
      await database.close();
    });

    test('group CRUD round-trips', () async {
      await store.upsertGroup(makeGroup('a', name: 'Repeaters', sortOrder: 0));
      await store.upsertGroup(makeGroup('b', name: 'My Team', sortOrder: 1));

      var groups = await store.loadGroups();
      expect(groups.map((g) => g.id), ['a', 'b']);
      expect(groups.first.name, 'Repeaters');
      expect(groups.first.iconKey, 'label');

      // Update (rename + recolor + icon).
      await store.upsertGroup(
        groups.first.copyWith(
          name: 'Routers',
          colorValue: 0xFF4F6AF6,
          iconKey: 'router',
        ),
      );
      groups = await store.loadGroups();
      final a = groups.firstWhere((g) => g.id == 'a');
      expect(a.name, 'Routers');
      expect(a.colorValue, 0xFF4F6AF6);
      expect(a.iconKey, 'router');

      await store.deleteGroup('a');
      groups = await store.loadGroups();
      expect(groups.map((g) => g.id), ['b']);
    });

    test('membership round-trips and setNodeGroups replaces', () async {
      await store.upsertGroup(makeGroup('a'));
      await store.upsertGroup(makeGroup('b'));

      await store.setNodeGroups(100, {'a', 'b'}, nowMs: 5);
      await store.setNodeGroups(200, {'a'}, nowMs: 5);

      var membership = await store.loadMembership();
      expect(membership[100], {'a', 'b'});
      expect(membership[200], {'a'});

      // Replace node 100's groups with just {b}.
      await store.setNodeGroups(100, {'b'}, nowMs: 6);
      membership = await store.loadMembership();
      expect(membership[100], {'b'});
    });

    test('add/remove single membership', () async {
      await store.upsertGroup(makeGroup('a'));
      await store.addNodeToGroup(100, 'a', nowMs: 5);
      // Idempotent re-add.
      await store.addNodeToGroup(100, 'a', nowMs: 6);
      expect((await store.loadMembership())[100], {'a'});

      await store.removeNodeFromGroup(100, 'a');
      expect((await store.loadMembership())[100], isNull);
    });

    test('removeNodesFromGroup removes only the named nodes from one '
        'group', () async {
      await store.upsertGroup(makeGroup('a'));
      await store.upsertGroup(makeGroup('b'));
      // 100 -> {a, b}, 200 -> {a}, 300 -> {a}, 400 -> {b}
      await store.setNodeGroups(100, {'a', 'b'}, nowMs: 5);
      await store.setNodeGroups(200, {'a'}, nowMs: 5);
      await store.setNodeGroups(300, {'a'}, nowMs: 5);
      await store.setNodeGroups(400, {'b'}, nowMs: 5);

      // Empty set is a no-op.
      await store.removeNodesFromGroup(<int>{}, 'a');
      expect((await store.loadMembership())[100], {'a', 'b'});

      await store.removeNodesFromGroup({100, 200}, 'a');

      final membership = await store.loadMembership();
      // 100 keeps b (only its 'a' membership was cleared).
      expect(membership[100], {'b'});
      // 200 had only 'a' and is now gone.
      expect(membership[200], isNull);
      // 300 was not in the removal set; its 'a' membership survives.
      expect(membership[300], {'a'});
      // 400's membership in the other group is untouched.
      expect(membership[400], {'b'});
    });

    test('deleting a group clears its membership rows', () async {
      await store.upsertGroup(makeGroup('a'));
      await store.upsertGroup(makeGroup('b'));
      await store.setNodeGroups(100, {'a', 'b'}, nowMs: 5);

      await store.deleteGroup('a');

      final membership = await store.loadMembership();
      // Node 100 retains only group b; the orphaned 'a' rows are gone.
      expect(membership[100], {'b'});
    });
  });
}
