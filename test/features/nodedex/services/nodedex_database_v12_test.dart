// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/models/observation_source.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sqlite_store.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('v12 schema migration', () {
    test(
      'fresh schema (no upgrade) exposes the v12 columns and round-trips values',
      () async {
        final database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
        final store = NodeDexSqliteStore(database);
        await store.init();
        addTearDown(store.dispose);

        // Round-trip an entry with both new fields populated.
        final entry = NodeDexEntry(
          nodeNum: 0xACB22B4,
          firstSeen: DateTime(2026, 5, 1),
          lastSeen: DateTime(2026, 5, 8),
          sigil: SigilGenerator.generate(0xACB22B4),
          lastObservationSource: ObservationSource.mqtt,
          lastHopsAway: 2,
        );
        await store.saveEntryImmediate(entry);

        // Reload and verify.
        final reloaded = await store.loadAll();
        expect(reloaded, hasLength(1));
        expect(reloaded.first.lastObservationSource, ObservationSource.mqtt);
        expect(reloaded.first.lastHopsAway, 2);
      },
    );

    test('null observation context round-trips as null, not "unknown"', () async {
      final database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final store = NodeDexSqliteStore(database);
      await store.init();
      addTearDown(store.dispose);

      final entry = NodeDexEntry(
        nodeNum: 0xDEADBEEF,
        firstSeen: DateTime(2026, 5, 1),
        lastSeen: DateTime(2026, 5, 1),
        sigil: SigilGenerator.generate(0xDEADBEEF),
        // Both nullable fields explicitly omitted.
      );
      await store.saveEntryImmediate(entry);

      final reloaded = await store.loadAll();
      expect(reloaded, hasLength(1));
      expect(
        reloaded.first.lastObservationSource,
        isNull,
        reason:
            'Legacy/unstamped entries must round-trip as null so the helper '
            'can distinguish "we never classified this" from "we classified it '
            'as unknown".',
      );
      expect(reloaded.first.lastHopsAway, isNull);
    });

    test('all ObservationSource values round-trip cleanly', () async {
      final database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final store = NodeDexSqliteStore(database);
      await store.init();
      addTearDown(store.dispose);

      final entries = <NodeDexEntry>[];
      for (var i = 0; i < ObservationSource.values.length; i++) {
        final source = ObservationSource.values[i];
        entries.add(
          NodeDexEntry(
            nodeNum: 1000 + i,
            firstSeen: DateTime(2026, 5, 1),
            lastSeen: DateTime(2026, 5, 1),
            sigil: SigilGenerator.generate(1000 + i),
            lastObservationSource: source,
            lastHopsAway: i,
          ),
        );
      }
      for (final e in entries) {
        await store.saveEntryImmediate(e);
      }

      final reloaded = await store.loadAll();
      expect(reloaded, hasLength(ObservationSource.values.length));
      for (final source in ObservationSource.values) {
        final match = reloaded.firstWhere(
          (e) => e.lastObservationSource == source,
        );
        expect(match.lastObservationSource, source);
        expect(match.lastHopsAway, source.index);
      }
    });

    test('migration from a simulated v11-shaped database', () async {
      // Build a v11 database directly via raw SQL, then re-open with the
      // current schemaVersion to force the v12 migration to run.
      // Use a real file path: inMemoryDatabasePath ('::memory::') opens a
      // fresh DB on every openDatabase() call, so we'd never see the
      // first instance's contents on re-open.
      final tempDir = Directory.systemTemp.createTempSync('nodedex_v12_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final dbPath = p.join(tempDir.path, 'nodedex_v11.db');

      final v11 = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 11,
          onCreate: (db, version) async {
            // Minimal v11 schema — only the columns this test relies on.
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
      // Seed a row representing a pre-v12 entry.
      await v11.insert(NodeDexTables.entries, {
        NodeDexTables.colNodeNum: 42,
        NodeDexTables.colFirstSeenMs: DateTime(
          2026,
          4,
          1,
        ).millisecondsSinceEpoch,
        NodeDexTables.colLastSeenMs: DateTime(
          2026,
          4,
          2,
        ).millisecondsSinceEpoch,
        NodeDexTables.colEncounterCount: 1,
        NodeDexTables.colMessageCount: 0,
        NodeDexTables.colSigilJson: '{}',
        NodeDexTables.colSchemaVersion: 1,
        NodeDexTables.colUpdatedAtMs: 0,
        NodeDexTables.colDeleted: 0,
      });
      await v11.close();

      // Re-open via NodeDexDatabase so the production _onUpgrade chain
      // actually runs. The bare databaseFactory.openDatabase call would
      // bump the version metadata without applying any migration, which
      // would silently leave the schema at v11.
      final wrapper = NodeDexDatabase(dbPathOverride: dbPath);
      final v12Db = await wrapper.open();
      addTearDown(wrapper.close);

      final cols = await v12Db.rawQuery(
        'PRAGMA table_info(${NodeDexTables.entries})',
      );
      final names = cols.map((r) => r['name'] as String).toSet();
      expect(names, contains(NodeDexTables.colLastObservationSource));
      expect(names, contains(NodeDexTables.colLastHopsAway));

      // The existing row must have NULL in both new columns.
      final row = await v12Db.query(
        NodeDexTables.entries,
        where: '${NodeDexTables.colNodeNum} = ?',
        whereArgs: [42],
      );
      expect(row, hasLength(1));
      expect(row.first[NodeDexTables.colLastObservationSource], isNull);
      expect(row.first[NodeDexTables.colLastHopsAway], isNull);
    });
  });
}
