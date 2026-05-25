// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
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

  group('v13 schema migration', () {
    test(
      'fresh schema exposes v13 identity columns and the identity_changes table',
      () async {
        final database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
        final store = NodeDexSqliteStore(database);
        await store.init();
        addTearDown(store.dispose);

        final db = database.database;
        final entryCols = await db.rawQuery(
          'PRAGMA table_info(${NodeDexTables.entries})',
        );
        final entryColNames = entryCols.map((r) => r['name'] as String).toSet();
        expect(entryColNames, contains(NodeDexTables.colIdentityPubkey));
        expect(entryColNames, contains(NodeDexTables.colIdentityObservedAtMs));
        expect(entryColNames, contains(NodeDexTables.colIdentityChangeCount));
        expect(
          entryColNames,
          contains(NodeDexTables.colLastIdentityChangeAtMs),
        );

        final changesTable = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [NodeDexTables.identityChanges],
        );
        expect(
          changesTable,
          hasLength(1),
          reason: 'identity_changes table must be created on fresh schema v13.',
        );
      },
    );

    test('NodeDexEntry round-trips identity fields cleanly', () async {
      final database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final store = NodeDexSqliteStore(database);
      await store.init();
      addTearDown(store.dispose);

      final pubkey = Uint8List.fromList(List.generate(32, (i) => i));
      final observedAt = DateTime(2026, 5, 25, 11, 20);
      final entry = NodeDexEntry(
        nodeNum: 0xEAAFE4A5,
        firstSeen: DateTime(2026, 5, 12),
        lastSeen: DateTime(2026, 5, 25),
        sigil: SigilGenerator.generate(0xEAAFE4A5),
        identityPubkey: pubkey,
        identityObservedAt: observedAt,
        identityChangeCount: 2,
        lastIdentityChangeAt: observedAt,
      );

      await store.saveEntryImmediate(entry);
      final reloaded = await store.loadAll();
      expect(reloaded, hasLength(1));
      final r = reloaded.first;
      expect(r.identityPubkey, equals(pubkey));
      expect(r.identityObservedAt, observedAt);
      expect(r.identityChangeCount, 2);
      expect(r.lastIdentityChangeAt, observedAt);
    });

    test('null identity fields round-trip as null / 0 on a fresh row '
        '(legacy and never-rotated entries)', () async {
      final database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final store = NodeDexSqliteStore(database);
      await store.init();
      addTearDown(store.dispose);

      final entry = NodeDexEntry(
        nodeNum: 0xDEADBEEF,
        firstSeen: DateTime(2026, 5, 1),
        lastSeen: DateTime(2026, 5, 1),
        sigil: SigilGenerator.generate(0xDEADBEEF),
      );
      await store.saveEntryImmediate(entry);

      final reloaded = await store.loadAll();
      expect(reloaded, hasLength(1));
      final r = reloaded.first;
      expect(r.identityPubkey, isNull);
      expect(r.identityObservedAt, isNull);
      expect(
        r.identityChangeCount,
        0,
        reason:
            'Change counter must default to 0 so the banner only fires when '
            'a real rotation has been recorded.',
      );
      expect(r.lastIdentityChangeAt, isNull);
    });

    test('migration from a simulated v12-shaped database', () async {
      final tempDir = Directory.systemTemp.createTempSync('nodedex_v13_test_');
      addTearDown(() {
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });
      final dbPath = p.join(tempDir.path, 'nodedex_v12.db');

      final v12 = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 12,
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
                ${NodeDexTables.colDeleted} INTEGER NOT NULL DEFAULT 0,
                ${NodeDexTables.colLastObservationSource} TEXT,
                ${NodeDexTables.colLastHopsAway} INTEGER
              )
            ''');
          },
        ),
      );
      await v12.insert(NodeDexTables.entries, {
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
        NodeDexTables.colEncounterCount: 7,
        NodeDexTables.colMessageCount: 3,
        NodeDexTables.colSigilJson: '{}',
        NodeDexTables.colSchemaVersion: 1,
        NodeDexTables.colUpdatedAtMs: 0,
        NodeDexTables.colDeleted: 0,
      });
      await v12.close();

      final wrapper = NodeDexDatabase(dbPathOverride: dbPath);
      final v13Db = await wrapper.open();
      addTearDown(wrapper.close);

      final cols = await v13Db.rawQuery(
        'PRAGMA table_info(${NodeDexTables.entries})',
      );
      final names = cols.map((r) => r['name'] as String).toSet();
      expect(
        names,
        containsAll([
          NodeDexTables.colIdentityPubkey,
          NodeDexTables.colIdentityObservedAtMs,
          NodeDexTables.colIdentityChangeCount,
          NodeDexTables.colLastIdentityChangeAtMs,
        ]),
      );

      final row = await v13Db.query(
        NodeDexTables.entries,
        where: '${NodeDexTables.colNodeNum} = ?',
        whereArgs: [42],
      );
      expect(row, hasLength(1));
      expect(row.first[NodeDexTables.colIdentityPubkey], isNull);
      expect(row.first[NodeDexTables.colIdentityObservedAtMs], isNull);
      expect(row.first[NodeDexTables.colIdentityChangeCount], 0);
      expect(row.first[NodeDexTables.colLastIdentityChangeAtMs], isNull);

      // identity_changes table exists and is empty.
      final changeRows = await v13Db.query(NodeDexTables.identityChanges);
      expect(changeRows, isEmpty);
    });
  });

  group('resolveIdentity', () {
    late NodeDexDatabase database;
    late NodeDexSqliteStore store;

    setUp(() async {
      database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      store = NodeDexSqliteStore(database);
      await store.init();
    });

    tearDown(() async {
      await store.dispose();
    });

    NodeDexEntry seedEntry({
      Uint8List? pubkey,
      int encounterCount = 5,
      double? maxDistance = 100.0,
    }) {
      return NodeDexEntry(
        nodeNum: 0xEAAFE4A5,
        firstSeen: DateTime(2026, 5, 12),
        lastSeen: DateTime(2026, 5, 25),
        encounterCount: encounterCount,
        maxDistanceSeen: maxDistance,
        bestSnr: 5,
        bestRssi: -90,
        messageCount: 12,
        sigil: SigilGenerator.generate(0xEAAFE4A5),
        identityPubkey: pubkey,
        identityObservedAt: pubkey != null ? DateTime(2026, 5, 12) : null,
      );
    }

    test('unchanged: matching pubkey returns the entry untouched', () async {
      final pk = Uint8List.fromList(List.generate(32, (i) => i));
      final entry = seedEntry(pubkey: pk);
      final result = await store.resolveIdentity(
        existing: entry,
        observedPubkey: pk,
      );
      expect(result.outcome, IdentityResolutionOutcome.unchanged);
      expect(result.entry, same(entry));
    });

    test('unchanged: null observed pubkey is a no-op', () async {
      final pk = Uint8List.fromList(List.generate(32, (i) => i));
      final entry = seedEntry(pubkey: pk);
      final result = await store.resolveIdentity(
        existing: entry,
        observedPubkey: null,
      );
      expect(result.outcome, IdentityResolutionOutcome.unchanged);
      expect(result.entry, same(entry));
    });

    test('backfilled: legacy entry with no pubkey gains the observed one '
        'without resetting stats', () async {
      final entry = seedEntry(pubkey: null);
      await store.saveEntryImmediate(entry);

      final pk = Uint8List.fromList(List.generate(32, (i) => i + 7));
      final now = DateTime(2026, 5, 25, 12, 0);
      final result = await store.resolveIdentity(
        existing: entry,
        observedPubkey: pk,
        now: now,
      );
      expect(result.outcome, IdentityResolutionOutcome.backfilled);
      expect(result.entry.identityPubkey, equals(pk));
      expect(result.entry.identityObservedAt, now);
      // Stats preserved.
      expect(result.entry.encounterCount, 5);
      expect(result.entry.maxDistanceSeen, 100.0);
      // No change counter bump or change-log row for backfill.
      expect(result.entry.identityChangeCount, 0);
      expect(result.entry.lastIdentityChangeAt, isNull);
      final changes = await store.getIdentityChanges(entry.nodeNum);
      expect(changes, isEmpty);
    });

    test(
      'rotated: differing pubkey updates the active row in place, '
      'preserves all stats, logs a change event, and bumps the counter',
      () async {
        final oldPk = Uint8List.fromList(List.generate(32, (i) => i));
        final entry = seedEntry(pubkey: oldPk);
        await store.saveEntryImmediate(entry);

        final newPk = Uint8List.fromList(List.generate(32, (i) => 255 - i));
        final now = DateTime(2026, 5, 25, 12, 0);
        final result = await store.resolveIdentity(
          existing: entry,
          observedPubkey: newPk,
          now: now,
        );

        expect(result.outcome, IdentityResolutionOutcome.rotated);
        final rotated = result.entry;
        expect(rotated.identityPubkey, equals(newPk));
        expect(rotated.identityObservedAt, now);
        expect(rotated.identityChangeCount, 1);
        expect(rotated.lastIdentityChangeAt, now);
        // Stats are intentionally preserved across rotation. The physical
        // device is continuous: antenna, location and range stay valid.
        expect(rotated.firstSeen, entry.firstSeen);
        expect(rotated.lastSeen, entry.lastSeen);
        expect(rotated.encounterCount, 5);
        expect(rotated.maxDistanceSeen, 100.0);
        expect(rotated.bestSnr, 5);
        expect(rotated.bestRssi, -90);
        expect(rotated.messageCount, 12);

        // The change is logged for the activity timeline.
        final changes = await store.getIdentityChanges(entry.nodeNum);
        expect(changes, hasLength(1));
        final change = changes.first;
        expect(change.previousPubkey, equals(oldPk));
        expect(change.newPubkey, equals(newPk));
        expect(change.timestamp, now);
      },
    );

    test('two rotations in succession log both events newest-first '
        'and stats remain accumulated through both', () async {
      final pk0 = Uint8List.fromList(List.generate(32, (i) => i));
      var entry = seedEntry(pubkey: pk0);
      await store.saveEntryImmediate(entry);

      final pk1 = Uint8List.fromList(List.generate(32, (i) => 255 - i));
      var result = await store.resolveIdentity(
        existing: entry,
        observedPubkey: pk1,
        now: DateTime(2026, 5, 25, 10),
      );
      entry = result.entry;
      expect(entry.encounterCount, 5);
      // Simulate one new encounter under pk1.
      entry = entry.copyWith(encounterCount: 6, maxDistanceSeen: 120.0);
      await store.saveEntryImmediate(entry);

      final pk2 = Uint8List.fromList(List.generate(32, (i) => (i * 3) & 0xFF));
      result = await store.resolveIdentity(
        existing: entry,
        observedPubkey: pk2,
        now: DateTime(2026, 5, 30, 14),
      );

      expect(result.outcome, IdentityResolutionOutcome.rotated);
      expect(result.entry.identityChangeCount, 2);
      // Stats accumulated through both rotations remain.
      expect(result.entry.encounterCount, 6);
      expect(result.entry.maxDistanceSeen, 120.0);

      final changes = await store.getIdentityChanges(entry.nodeNum);
      expect(changes, hasLength(2));
      // Newest-first.
      expect(changes[0].previousPubkey, equals(pk1));
      expect(changes[0].newPubkey, equals(pk2));
      expect(changes[1].previousPubkey, equals(pk0));
      expect(changes[1].newPubkey, equals(pk1));
    });

    test('rotation does NOT delete child rows for the node', () async {
      final oldPk = Uint8List.fromList(List.generate(32, (i) => i));
      // Build an entry whose child rows live in its own encounters /
      // seenRegions lists (the canonical persistence path: saving the
      // entry deletes-and-rewrites child tables from those lists, so
      // raw out-of-band inserts wouldn't survive the next save).
      final encounter = EncounterRecord(
        timestamp: DateTime(2026, 5, 20),
        distanceMeters: 100.0,
        snr: 5,
      );
      final region = SeenRegion(
        regionId: 'g42_7',
        label: 'EU868',
        firstSeen: DateTime(2026, 5, 12),
        lastSeen: DateTime(2026, 5, 25),
        encounterCount: 4,
      );
      final entry = NodeDexEntry(
        nodeNum: 0xEAAFE4A5,
        firstSeen: DateTime(2026, 5, 12),
        lastSeen: DateTime(2026, 5, 25),
        encounterCount: 5,
        maxDistanceSeen: 100.0,
        sigil: SigilGenerator.generate(0xEAAFE4A5),
        identityPubkey: oldPk,
        identityObservedAt: DateTime(2026, 5, 12),
        encounters: [encounter],
        seenRegions: [region],
      );
      await store.saveEntryImmediate(entry);

      final db = database.database;
      final encsBefore = await db.query(
        NodeDexTables.encounters,
        where: '${NodeDexTables.colNodeNum} = ?',
        whereArgs: [entry.nodeNum],
      );
      expect(encsBefore, hasLength(1));

      final newPk = Uint8List.fromList(List.generate(32, (i) => 255 - i));
      await store.resolveIdentity(
        existing: entry,
        observedPubkey: newPk,
        now: DateTime(2026, 5, 25),
      );

      final encs = await db.query(
        NodeDexTables.encounters,
        where: '${NodeDexTables.colNodeNum} = ?',
        whereArgs: [entry.nodeNum],
      );
      expect(
        encs,
        hasLength(1),
        reason:
            'rotation must NOT clear encounters - the physical device is '
            'continuous and the observation history remains valid',
      );
      final regions = await db.query(
        NodeDexTables.seenRegions,
        where: '${NodeDexTables.colNodeNum} = ?',
        whereArgs: [entry.nodeNum],
      );
      expect(regions, hasLength(1), reason: 'rotation must NOT clear regions');
    });

    test(
      'IdentityChangeRecord fingerprint helpers truncate correctly',
      () async {
        final pk = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34]);
        final record = IdentityChangeRecord(
          changeId: 1,
          nodeNum: 1,
          previousPubkey: null,
          newPubkey: pk,
          timestamp: DateTime(2026, 5, 25),
        );
        expect(record.newPubkeyFingerprint, 'deadbeef');
        expect(record.previousPubkeyFingerprint, isNull);
      },
    );
  });
}
