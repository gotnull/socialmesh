// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
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
      'fresh schema exposes v13 identity columns and the identity_history table',
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
        expect(entryColNames, contains(NodeDexTables.colIdentityResetCount));
        expect(entryColNames, contains(NodeDexTables.colLastIdentityResetAtMs));

        final historyTables = await db.rawQuery(
          "SELECT name FROM sqlite_master "
          "WHERE type='table' AND name=?",
          [NodeDexTables.identityHistory],
        );
        expect(
          historyTables,
          hasLength(1),
          reason: 'identity_history table must be created on fresh schema v13.',
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
        identityResetCount: 2,
        lastIdentityResetAt: observedAt,
      );

      await store.saveEntryImmediate(entry);
      final reloaded = await store.loadAll();
      expect(reloaded, hasLength(1));
      final r = reloaded.first;
      expect(r.identityPubkey, equals(pubkey));
      expect(r.identityObservedAt, observedAt);
      expect(r.identityResetCount, 2);
      expect(r.lastIdentityResetAt, observedAt);
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
        r.identityResetCount,
        0,
        reason:
            'Reset counter must default to 0 so the banner only fires when '
            'a real rotation has been recorded.',
      );
      expect(r.lastIdentityResetAt, isNull);
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

      // New identity columns exist and the pre-existing row has the expected
      // legacy defaults: pubkey NULL, reset_count 0 (NOT NULL DEFAULT 0).
      final cols = await v13Db.rawQuery(
        'PRAGMA table_info(${NodeDexTables.entries})',
      );
      final names = cols.map((r) => r['name'] as String).toSet();
      expect(
        names,
        containsAll([
          NodeDexTables.colIdentityPubkey,
          NodeDexTables.colIdentityObservedAtMs,
          NodeDexTables.colIdentityResetCount,
          NodeDexTables.colLastIdentityResetAtMs,
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
      expect(row.first[NodeDexTables.colIdentityResetCount], 0);
      expect(row.first[NodeDexTables.colLastIdentityResetAtMs], isNull);

      // identity_history table exists and is empty.
      final historyRows = await v13Db.query(NodeDexTables.identityHistory);
      expect(historyRows, isEmpty);
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
      // Stats are preserved on backfill.
      expect(result.entry.encounterCount, 5);
      expect(result.entry.maxDistanceSeen, 100.0);
      expect(result.entry.identityResetCount, 0);
      expect(result.entry.lastIdentityResetAt, isNull);
    });

    test('rotated: differing pubkey archives the prior snapshot, '
        'resets accumulators, and bumps the reset counter', () async {
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
      final reset = result.entry;
      expect(reset.identityPubkey, equals(newPk));
      expect(reset.identityObservedAt, now);
      expect(reset.identityResetCount, 1);
      expect(reset.lastIdentityResetAt, now);
      // Fresh stats post-rotation.
      expect(reset.firstSeen, now);
      expect(reset.lastSeen, now);
      expect(reset.encounterCount, 0);
      expect(reset.maxDistanceSeen, isNull);
      expect(reset.bestSnr, isNull);
      expect(reset.bestRssi, isNull);
      expect(reset.messageCount, 0);
      expect(reset.encounters, isEmpty);
      expect(reset.seenRegions, isEmpty);

      // Archive table now has a snapshot of the prior identity.
      final history = await store.getIdentityHistory(entry.nodeNum);
      expect(history, hasLength(1));
      final snap = history.first;
      expect(snap.identityPubkey, equals(oldPk));
      expect(snap.encounterCount, 5);
      expect(snap.maxDistanceSeen, 100.0);
      expect(snap.archivedAt, now);
    });

    test('rotated twice in succession archives both prior identities '
        'newest-first', () async {
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
      // Simulate post-rotation observation accumulating more stats.
      entry = entry.copyWith(encounterCount: 3, maxDistanceSeen: 50.0);
      await store.saveEntryImmediate(entry);

      final pk2 = Uint8List.fromList(List.generate(32, (i) => (i * 3) & 0xFF));
      result = await store.resolveIdentity(
        existing: entry,
        observedPubkey: pk2,
        now: DateTime(2026, 5, 30, 14),
      );

      expect(result.outcome, IdentityResolutionOutcome.rotated);
      expect(result.entry.identityResetCount, 2);

      final history = await store.getIdentityHistory(entry.nodeNum);
      expect(history, hasLength(2));
      // Newest-first.
      expect(history[0].identityPubkey, equals(pk1));
      expect(history[0].encounterCount, 3);
      expect(history[1].identityPubkey, equals(pk0));
      expect(history[1].encounterCount, 5);
    });

    test('rotation deletes child rows for the node', () async {
      final oldPk = Uint8List.fromList(List.generate(32, (i) => i));
      final entry = seedEntry(pubkey: oldPk);
      await store.saveEntryImmediate(entry);

      // Manually seed a child encounter + region for this node so we can
      // confirm rotation clears them.
      final db = database.database;
      await db.insert(NodeDexTables.encounters, {
        NodeDexTables.colNodeNum: entry.nodeNum,
        NodeDexTables.colEncTsMs: DateTime(2026, 5, 20).millisecondsSinceEpoch,
        NodeDexTables.colEncCreatedAtMs: DateTime(
          2026,
          5,
          20,
        ).millisecondsSinceEpoch,
      });
      await db.insert(NodeDexTables.seenRegions, {
        NodeDexTables.colNodeNum: entry.nodeNum,
        NodeDexTables.colRegionKey: 'g42_7',
        NodeDexTables.colRegionLabel: 'EU868',
        NodeDexTables.colRegionFirstSeenMs: DateTime(
          2026,
          5,
          20,
        ).millisecondsSinceEpoch,
        NodeDexTables.colRegionLastSeenMs: DateTime(
          2026,
          5,
          20,
        ).millisecondsSinceEpoch,
      });

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
      expect(encs, isEmpty, reason: 'rotation must clear encounters');
      final regions = await db.query(
        NodeDexTables.seenRegions,
        where: '${NodeDexTables.colNodeNum} = ?',
        whereArgs: [entry.nodeNum],
      );
      expect(regions, isEmpty, reason: 'rotation must clear regions');
    });

    test(
      'rotation preserves user-curated metadata (note, social tag, nickname)',
      () async {
        final oldPk = Uint8List.fromList(List.generate(32, (i) => i));
        final entry = NodeDexEntry(
          nodeNum: 0xEAAFE4A5,
          firstSeen: DateTime(2026, 5, 12),
          lastSeen: DateTime(2026, 5, 25),
          encounterCount: 5,
          maxDistanceSeen: 100.0,
          userNote: 'this is the megecho radio',
          userNoteUpdatedAtMs: DateTime(2026, 5, 15).millisecondsSinceEpoch,
          localNickname: 'MegEcho',
          localNicknameUpdatedAtMs: DateTime(
            2026,
            5,
            15,
          ).millisecondsSinceEpoch,
          sigil: SigilGenerator.generate(0xEAAFE4A5),
          identityPubkey: oldPk,
          identityObservedAt: DateTime(2026, 5, 12),
          firstUsedAt: DateTime(2026, 5, 12),
          lastUsedAt: DateTime(2026, 5, 25),
        );
        await store.saveEntryImmediate(entry);

        final newPk = Uint8List.fromList(List.generate(32, (i) => 255 - i));
        final result = await store.resolveIdentity(
          existing: entry,
          observedPubkey: newPk,
          now: DateTime(2026, 5, 25),
        );

        expect(result.outcome, IdentityResolutionOutcome.rotated);
        final reset = result.entry;
        expect(reset.userNote, 'this is the megecho radio');
        expect(reset.localNickname, 'MegEcho');
        // Connection-identity timestamps survive — they track the phone's
        // relationship to the nodeNum, not firmware state.
        expect(reset.firstUsedAt, DateTime(2026, 5, 12));
        expect(reset.lastUsedAt, DateTime(2026, 5, 25));
      },
    );

    test(
      'IdentityHistoryRecord.pubkeyFingerprint truncates correctly',
      () async {
        final pk = Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF, 0x12, 0x34]);
        final record = IdentityHistoryRecord(
          historyId: 1,
          nodeNum: 1,
          identityPubkey: pk,
          archivedAt: DateTime(2026, 5, 25),
          firstSeen: DateTime(2026, 5, 12),
          lastSeen: DateTime(2026, 5, 25),
          encounterCount: 1,
          messageCount: 0,
          regionCount: 0,
        );
        expect(record.pubkeyFingerprint, 'deadbeef');
      },
    );

    test(
      'IdentityHistoryRecord.pubkeyFingerprint is null for legacy snapshot',
      () async {
        final record = IdentityHistoryRecord(
          historyId: 1,
          nodeNum: 1,
          identityPubkey: null,
          archivedAt: DateTime(2026, 5, 25),
          firstSeen: DateTime(2026, 5, 12),
          lastSeen: DateTime(2026, 5, 25),
          encounterCount: 1,
          messageCount: 0,
          regionCount: 0,
        );
        expect(record.pubkeyFingerprint, isNull);
      },
    );

    test('archived snapshot preserves encounters + regions JSON', () async {
      final oldPk = Uint8List.fromList(List.generate(32, (i) => i));
      final encounter = EncounterRecord(
        timestamp: DateTime(2026, 5, 20),
        distanceMeters: 35890.0,
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
        maxDistanceSeen: 35890.0,
        sigil: SigilGenerator.generate(0xEAAFE4A5),
        identityPubkey: oldPk,
        identityObservedAt: DateTime(2026, 5, 12),
        encounters: [encounter],
        seenRegions: [region],
      );
      await store.saveEntryImmediate(entry);

      final newPk = Uint8List.fromList(List.generate(32, (i) => 255 - i));
      await store.resolveIdentity(
        existing: entry,
        observedPubkey: newPk,
        now: DateTime(2026, 5, 25),
      );

      final history = await store.getIdentityHistory(entry.nodeNum);
      expect(history, hasLength(1));
      final snap = history.first;
      expect(snap.encountersJson, isNotNull);
      expect(snap.seenRegionsJson, isNotNull);
      final decodedEncs = jsonDecode(snap.encountersJson!) as List<dynamic>;
      expect(decodedEncs, hasLength(1));
      final decodedRegions = jsonDecode(snap.seenRegionsJson!) as List<dynamic>;
      expect(decodedRegions, hasLength(1));
    });
  });
}
