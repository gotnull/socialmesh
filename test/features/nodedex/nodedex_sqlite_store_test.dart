// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/nodedex/models/import_preview.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_migration.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sqlite_store.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NodeDexDatabase database;
  late NodeDexSqliteStore store;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
    store = NodeDexSqliteStore(database);
    await store.init();
  });

  tearDown(() async {
    await store.dispose();
  });

  // ===========================================================================
  // Helpers
  // ===========================================================================

  NodeDexEntry makeEntry({
    required int nodeNum,
    DateTime? firstSeen,
    DateTime? lastSeen,
    int encounterCount = 1,
    double? maxDistanceSeen,
    int? bestSnr,
    int? bestRssi,
    int messageCount = 0,
    NodeSocialTag? socialTag,
    String? userNote,
    List<EncounterRecord> encounters = const [],
    List<SeenRegion> seenRegions = const [],
    Map<int, CoSeenRelationship> coSeenNodes = const {},
    SigilData? sigil,
  }) {
    return NodeDexEntry(
      nodeNum: nodeNum,
      firstSeen: firstSeen ?? DateTime(2024, 1, 1),
      lastSeen: lastSeen ?? DateTime(2024, 6, 1),
      encounterCount: encounterCount,
      maxDistanceSeen: maxDistanceSeen,
      bestSnr: bestSnr,
      bestRssi: bestRssi,
      messageCount: messageCount,
      socialTag: socialTag,
      userNote: userNote,
      encounters: encounters,
      seenRegions: seenRegions,
      coSeenNodes: coSeenNodes,
      sigil: sigil ?? SigilGenerator.generate(nodeNum),
    );
  }

  EncounterRecord makeEncounter({
    required DateTime timestamp,
    double? distance,
    int? snr,
    int? rssi,
    double? lat,
    double? lon,
  }) {
    return EncounterRecord(
      timestamp: timestamp,
      distanceMeters: distance,
      snr: snr,
      rssi: rssi,
      latitude: lat,
      longitude: lon,
    );
  }

  // ===========================================================================
  // Initialization and basic CRUD
  // ===========================================================================

  group('initialization', () {
    test('loadAll returns empty list on fresh store', () async {
      final entries = await store.loadAll();
      expect(entries, isEmpty);
    });

    test('entryCount returns 0 on fresh store', () async {
      final count = await store.entryCount;
      expect(count, equals(0));
    });

    test('getEntry returns null for nonexistent node', () async {
      final entry = await store.getEntry(12345);
      expect(entry, isNull);
    });

    test('hasEntry returns false for nonexistent node', () async {
      final has = await store.hasEntry(12345);
      expect(has, isFalse);
    });
  });

  group('CRUD operations', () {
    test('saveEntry and getEntry roundtrip', () async {
      final entry = makeEntry(nodeNum: 100);
      await store.saveEntryImmediate(entry);

      final loaded = await store.getEntry(100);
      expect(loaded, isNotNull);
      expect(loaded!.nodeNum, equals(100));
      expect(loaded.firstSeen, equals(entry.firstSeen));
      expect(loaded.lastSeen, equals(entry.lastSeen));
      expect(loaded.encounterCount, equals(1));
    });

    test('saveEntries batch write', () async {
      final entries = [
        makeEntry(nodeNum: 1),
        makeEntry(nodeNum: 2),
        makeEntry(nodeNum: 3),
      ];
      store.saveEntries(entries);
      await store.flush();

      final count = await store.entryCount;
      expect(count, equals(3));
    });

    test('upsert overwrites existing entry', () async {
      final v1 = makeEntry(nodeNum: 100, encounterCount: 1, userNote: 'first');
      await store.saveEntryImmediate(v1);

      final v2 = makeEntry(
        nodeNum: 100,
        encounterCount: 5,
        userNote: 'updated',
      );
      await store.saveEntryImmediate(v2);

      final loaded = await store.getEntry(100);
      expect(loaded!.encounterCount, equals(5));
      expect(loaded.userNote, equals('updated'));
    });

    test('deleteEntry soft-deletes', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));
      await store.deleteEntry(100);

      // Invalidate cache to force a reload from DB.
      final loaded = await store.getEntry(100);
      expect(loaded, isNull);
    });

    test('clearAll removes everything', () async {
      store.saveEntries([makeEntry(nodeNum: 1), makeEntry(nodeNum: 2)]);
      await store.flush();
      await store.clearAll();

      final count = await store.entryCount;
      expect(count, equals(0));
    });
  });

  // ===========================================================================
  // Social tag and user note
  // ===========================================================================

  group('social tag', () {
    test('setSocialTag updates the tag', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));
      await store.setSocialTag(100, NodeSocialTag.contact);
      await store.flush();

      final loaded = await store.getEntry(100);
      expect(loaded!.socialTag, equals(NodeSocialTag.contact));
    });

    test('setSocialTag null clears the tag', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, socialTag: NodeSocialTag.contact),
      );
      await store.setSocialTag(100, null);
      await store.flush();

      final loaded = await store.getEntry(100);
      expect(loaded!.socialTag, isNull);
    });
  });

  group('user note', () {
    test('setUserNote updates the note', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));
      await store.setUserNote(100, 'Hello world');
      await store.flush();

      final loaded = await store.getEntry(100);
      expect(loaded!.userNote, equals('Hello world'));
    });

    test('setUserNote truncates to 280 chars', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));
      final longNote = 'x' * 300;
      await store.setUserNote(100, longNote);
      await store.flush();

      final loaded = await store.getEntry(100);
      expect(loaded!.userNote!.length, equals(280));
    });

    test('setUserNote null clears the note', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 100, userNote: 'test'));
      await store.setUserNote(100, null);
      await store.flush();

      final loaded = await store.getEntry(100);
      expect(loaded!.userNote, isNull);
    });
  });

  // ===========================================================================
  // Encounters
  // ===========================================================================

  group('encounters', () {
    test('encounters are preserved through roundtrip', () async {
      final encounters = [
        makeEncounter(
          timestamp: DateTime(2024, 1, 1),
          distance: 100.0,
          snr: 10,
          rssi: -80,
          lat: 37.7749,
          lon: -122.4194,
        ),
        makeEncounter(
          timestamp: DateTime(2024, 2, 1),
          distance: 200.0,
          snr: 15,
        ),
      ];

      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, encounters: encounters),
      );

      final loaded = await store.getEntry(100);
      expect(loaded!.encounters.length, equals(2));
      expect(loaded.encounters[0].distanceMeters, closeTo(100.0, 0.01));
      expect(loaded.encounters[0].snr, equals(10));
      expect(loaded.encounters[0].latitude, closeTo(37.7749, 0.001));
      expect(loaded.encounters[1].distanceMeters, closeTo(200.0, 0.01));
    });
  });

  // ===========================================================================
  // Regions
  // ===========================================================================

  group('regions', () {
    test('regions preserved through roundtrip', () async {
      final regions = [
        SeenRegion(
          regionId: 'g37_-122',
          label: '37N 122W',
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          encounterCount: 5,
        ),
      ];

      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, seenRegions: regions),
      );

      final loaded = await store.getEntry(100);
      expect(loaded!.seenRegions.length, equals(1));
      expect(loaded.seenRegions[0].regionId, equals('g37_-122'));
      expect(loaded.seenRegions[0].label, equals('37N 122W'));
      expect(loaded.seenRegions[0].encounterCount, equals(5));
    });
  });

  // ===========================================================================
  // Co-seen edges
  // ===========================================================================

  group('co-seen edges', () {
    test('co-seen relationships preserved through roundtrip', () async {
      final coSeen = {
        200: CoSeenRelationship(
          count: 3,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          messageCount: 10,
        ),
        300: CoSeenRelationship(
          count: 1,
          firstSeen: DateTime(2024, 3, 1),
          lastSeen: DateTime(2024, 3, 1),
        ),
      };

      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, coSeenNodes: coSeen),
      );

      final loaded = await store.getEntry(100);
      expect(loaded!.coSeenNodes.length, equals(2));
      expect(loaded.coSeenNodes[200]!.count, equals(3));
      expect(loaded.coSeenNodes[200]!.messageCount, equals(10));
      expect(loaded.coSeenNodes[300]!.count, equals(1));
    });
  });

  // ===========================================================================
  // Sigil determinism
  // ===========================================================================

  group('sigil determinism', () {
    test('same nodeNum produces identical sigil across instances', () {
      final sigil1 = SigilGenerator.generate(42);
      final sigil2 = SigilGenerator.generate(42);

      expect(sigil1.vertices, equals(sigil2.vertices));
      expect(sigil1.rotation, equals(sigil2.rotation));
      expect(sigil1.innerRings, equals(sigil2.innerRings));
      expect(sigil1.drawRadials, equals(sigil2.drawRadials));
      expect(sigil1.centerDot, equals(sigil2.centerDot));
      expect(sigil1.symmetryFold, equals(sigil2.symmetryFold));
      expect(sigil1.primaryColor, equals(sigil2.primaryColor));
    });

    test('sigil roundtrips through SQLite unchanged', () async {
      final sigil = SigilGenerator.generate(42);
      await store.saveEntryImmediate(makeEntry(nodeNum: 42, sigil: sigil));

      final loaded = await store.getEntry(42);
      expect(loaded!.sigil!.vertices, equals(sigil.vertices));
      expect(loaded.sigil!.rotation, closeTo(sigil.rotation, 0.001));
      expect(loaded.sigil!.innerRings, equals(sigil.innerRings));
      expect(loaded.sigil!.primaryColor, equals(sigil.primaryColor));
    });

    test('missing sigil is recomputed from nodeNum on load', () async {
      // Save entry with sigil, then override the sigil_json to empty.
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, sigil: SigilGenerator.generate(42)),
      );

      // Directly update the DB to remove sigil.
      final db = database.database;
      await db.update(
        NodeDexTables.entries,
        {'sigil_json': ''},
        where: 'node_num = ?',
        whereArgs: [42],
      );

      // Create a new store on the SAME database (cache cleared).
      final freshStore = NodeDexSqliteStore(database);
      await freshStore.init();

      final loaded = await freshStore.getEntry(42);
      expect(loaded, isNotNull);
      expect(loaded!.sigil, isNotNull);
      expect(
        loaded.sigil!.vertices,
        equals(SigilGenerator.generate(42).vertices),
      );
    });
  });

  // ===========================================================================
  // Export / Import
  // ===========================================================================

  group('export/import', () {
    test('export returns null for empty store', () async {
      final json = await store.exportJson();
      expect(json, isNull);
    });

    test('export produces valid JSON matching legacy format', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 100,
          socialTag: NodeSocialTag.contact,
          userNote: 'Test node',
        ),
      );

      final json = await store.exportJson();
      expect(json, isNotNull);

      final decoded = jsonDecode(json!) as List<dynamic>;
      expect(decoded.length, equals(1));
      final entry = decoded[0] as Map<String, dynamic>;
      expect(entry['nn'], equals(100));
      expect(entry['st'], equals(NodeSocialTag.contact.index));
      expect(entry['un'], equals('Test node'));
    });

    test('import merges with existing entries', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, encounterCount: 3, userNote: 'local'),
      );

      final importEntry = makeEntry(
        nodeNum: 100,
        encounterCount: 5,
        userNote: 'imported',
      );
      final importJson = NodeDexEntry.encodeList([importEntry]);

      final count = await store.importJson(importJson);
      expect(count, equals(1));

      final loaded = await store.getEntry(100);
      // mergeWith takes max encounterCount.
      expect(loaded!.encounterCount, equals(5));
      // mergeWith keeps local userNote when it exists.
      expect(loaded.userNote, equals('local'));
    });

    test('import adds new entries', () async {
      final importEntry = makeEntry(nodeNum: 200);
      final importJson = NodeDexEntry.encodeList([importEntry]);

      final count = await store.importJson(importJson);
      expect(count, equals(1));

      final loaded = await store.getEntry(200);
      expect(loaded, isNotNull);
    });
  });

  // ===========================================================================
  // Import with merge strategy
  // ===========================================================================

  group('import with merge strategy', () {
    test('preview correctly identifies new and existing entries', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));

      final importEntries = [
        makeEntry(nodeNum: 100), // existing
        makeEntry(nodeNum: 200), // new
      ];

      final preview = await store.previewImport(importEntries);
      expect(preview.totalImported, equals(2));
      expect(preview.newEntryCount, equals(1));
      expect(preview.mergeEntryCount, equals(1));
    });

    test('keepLocal strategy preserves local socialTag', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, socialTag: NodeSocialTag.contact),
      );

      final importEntries = [
        makeEntry(nodeNum: 100, socialTag: NodeSocialTag.knownRelay),
      ];

      final preview = await store.previewImport(importEntries);
      final count = await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      expect(count, equals(1));
      final loaded = await store.getEntry(100);
      expect(loaded!.socialTag, equals(NodeSocialTag.contact));
    });

    test('preferImport strategy uses imported socialTag', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, socialTag: NodeSocialTag.contact),
      );

      final importEntries = [
        makeEntry(nodeNum: 100, socialTag: NodeSocialTag.knownRelay),
      ];

      final preview = await store.previewImport(importEntries);
      final count = await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.preferImport,
      );

      expect(count, equals(1));
      final loaded = await store.getEntry(100);
      expect(loaded!.socialTag, equals(NodeSocialTag.knownRelay));
    });
  });

  // ===========================================================================
  // Sync outbox
  // ===========================================================================

  group('sync outbox', () {
    test('outbox empty when sync disabled', () async {
      store.syncEnabled = false;
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));

      final count = await store.outboxCount;
      expect(count, equals(0));
    });

    test('outbox enqueues on write when sync enabled', () async {
      store.syncEnabled = true;
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));

      final count = await store.outboxCount;
      expect(count, equals(1));

      final entries = await store.readOutbox();
      expect(entries.length, equals(1));
      expect(entries[0]['entity_type'], equals('entry'));
      expect(entries[0]['entity_id'], equals('node:100'));
      expect(entries[0]['op'], equals('upsert'));
    });

    test('outbox deduplicates on repeated writes', () async {
      store.syncEnabled = true;
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, encounterCount: 2),
      );

      final count = await store.outboxCount;
      // Should be 1 because the second write replaces the first.
      expect(count, equals(1));
    });

    test('removeOutboxEntry removes specific entry', () async {
      store.syncEnabled = true;
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));

      final entries = await store.readOutbox();
      await store.removeOutboxEntry(entries[0]['id'] as int);

      final count = await store.outboxCount;
      expect(count, equals(0));
    });

    test('markOutboxAttemptFailed increments count', () async {
      store.syncEnabled = true;
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));

      final entries = await store.readOutbox();
      final id = entries[0]['id'] as int;
      await store.markOutboxAttemptFailed(id, 'network error');

      final updated = await store.readOutbox();
      expect(updated[0]['attempt_count'], equals(1));
      expect(updated[0]['last_error'], equals('network error'));
    });
  });

  // ===========================================================================
  // Sync state
  // ===========================================================================

  group('sync state', () {
    test('getSyncState returns null for unknown key', () async {
      final value = await store.getSyncState('nonexistent');
      expect(value, isNull);
    });

    test('setSyncState and getSyncState roundtrip', () async {
      await store.setSyncState('test_key', 'test_value');
      final value = await store.getSyncState('test_key');
      expect(value, equals('test_value'));
    });

    test('setSyncState overwrites previous value', () async {
      await store.setSyncState('key', 'value1');
      await store.setSyncState('key', 'value2');
      final value = await store.getSyncState('key');
      expect(value, equals('value2'));
    });
  });

  // ===========================================================================
  // Sync pull
  // ===========================================================================

  group('sync pull', () {
    test('applySyncPull adds new entries', () async {
      final remote = [makeEntry(nodeNum: 100)];
      final count = await store.applySyncPull(remote);

      expect(count, equals(1));
      final loaded = await store.getEntry(100);
      expect(loaded, isNotNull);
    });

    test('applySyncPull merges with existing', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 100,
          encounterCount: 3,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 3, 1),
          userNote: 'local note',
        ),
      );

      final remote = [
        makeEntry(
          nodeNum: 100,
          encounterCount: 5,
          firstSeen: DateTime(2024, 2, 1),
          lastSeen: DateTime(2024, 6, 1),
        ),
      ];

      await store.applySyncPull(remote);

      final loaded = await store.getEntry(100);
      // firstSeen: min
      expect(loaded!.firstSeen, equals(DateTime(2024, 1, 1)));
      // lastSeen: max
      expect(loaded.lastSeen, equals(DateTime(2024, 6, 1)));
      // encounterCount: max
      expect(loaded.encounterCount, equals(5));
      // userNote: local wins (mergeWith prefers local)
      expect(loaded.userNote, equals('local note'));
    });

    test('applySyncPull merge keeps broadest co-seen', () async {
      final localCoSeen = {
        200: CoSeenRelationship(
          count: 3,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 3, 1),
          messageCount: 5,
        ),
      };
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 100, coSeenNodes: localCoSeen),
      );

      final remoteCoSeen = {
        200: CoSeenRelationship(
          count: 5,
          firstSeen: DateTime(2024, 2, 1),
          lastSeen: DateTime(2024, 6, 1),
          messageCount: 3,
        ),
        300: CoSeenRelationship(
          count: 1,
          firstSeen: DateTime(2024, 4, 1),
          lastSeen: DateTime(2024, 4, 1),
        ),
      };
      await store.applySyncPull([
        makeEntry(nodeNum: 100, coSeenNodes: remoteCoSeen),
      ]);

      final loaded = await store.getEntry(100);
      // Merged edge 200: count=max(3,5)=5, firstSeen=min, lastSeen=max
      expect(loaded!.coSeenNodes[200]!.count, equals(5));
      expect(loaded.coSeenNodes[200]!.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(loaded.coSeenNodes[200]!.lastSeen, equals(DateTime(2024, 6, 1)));
      // New edge 300 from remote.
      expect(loaded.coSeenNodes[300], isNotNull);
      expect(loaded.coSeenNodes[300]!.count, equals(1));
    });
  });

  // ===========================================================================
  // Bulk insert (migration)
  // ===========================================================================

  group('bulk insert', () {
    test('bulkInsert adds all entries', () async {
      final entries = List.generate(10, (i) => makeEntry(nodeNum: i + 1));
      await store.bulkInsert(entries);

      final count = await store.entryCount;
      expect(count, equals(10));
    });

    test('bulkInsert does not enqueue outbox', () async {
      store.syncEnabled = true;
      await store.bulkInsert([makeEntry(nodeNum: 100)]);

      final outbox = await store.outboxCount;
      expect(outbox, equals(0));
    });
  });

  // ===========================================================================
  // Migration from SharedPreferences
  // ===========================================================================

  group('migration from SharedPreferences', () {
    test('migration completes when legacy data exists', () async {
      // Set up legacy SharedPreferences data.
      final legacyEntries = [
        makeEntry(
          nodeNum: 100,
          socialTag: NodeSocialTag.contact,
          userNote: 'My relay',
          encounterCount: 5,
          encounters: [
            makeEncounter(timestamp: DateTime(2024, 1, 1), snr: 10),
            makeEncounter(timestamp: DateTime(2024, 2, 1), snr: 15),
          ],
          seenRegions: [
            SeenRegion(
              regionId: 'g37_-122',
              label: '37N 122W',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 5,
            ),
          ],
        ),
        makeEntry(nodeNum: 200, encounterCount: 3),
      ];

      final legacyJson = NodeDexEntry.encodeList(legacyEntries);
      SharedPreferences.setMockInitialValues({
        'nodedex_entries': legacyJson,
        'nodedex_meta': 2,
      });

      // Create a fresh store for migration.
      final migrationDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final migrationStore = NodeDexSqliteStore(migrationDb);
      await migrationStore.init();

      final migration = NodeDexMigration(migrationStore);
      final result = await migration.migrateIfNeeded();

      expect(result, isTrue);

      // Verify entries were migrated.
      final count = await migrationStore.entryCount;
      expect(count, equals(2));

      final entry100 = await migrationStore.getEntry(100);
      expect(entry100, isNotNull);
      expect(entry100!.socialTag, equals(NodeSocialTag.contact));
      expect(entry100.userNote, equals('My relay'));
      expect(entry100.encounterCount, equals(5));
      expect(entry100.encounters.length, equals(2));
      expect(entry100.seenRegions.length, equals(1));
      expect(entry100.sigil, isNotNull);

      final entry200 = await migrationStore.getEntry(200);
      expect(entry200, isNotNull);
      expect(entry200!.encounterCount, equals(3));

      // Verify migration flag is set.
      final complete = await migration.isMigrationComplete();
      expect(complete, isTrue);

      await migrationStore.dispose();
    });

    test('migration skips when no legacy data', () async {
      SharedPreferences.setMockInitialValues({});

      final migrationDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final migrationStore = NodeDexSqliteStore(migrationDb);
      await migrationStore.init();

      final migration = NodeDexMigration(migrationStore);
      final result = await migration.migrateIfNeeded();

      expect(result, isFalse);
      final complete = await migration.isMigrationComplete();
      expect(complete, isTrue);

      await migrationStore.dispose();
    });

    test('migration is idempotent', () async {
      final legacyEntries = [makeEntry(nodeNum: 100)];
      final legacyJson = NodeDexEntry.encodeList(legacyEntries);
      SharedPreferences.setMockInitialValues({
        'nodedex_entries': legacyJson,
        'nodedex_meta': 2,
      });

      final migrationDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final migrationStore = NodeDexSqliteStore(migrationDb);
      await migrationStore.init();

      final migration = NodeDexMigration(migrationStore);

      final result1 = await migration.migrateIfNeeded();
      expect(result1, isTrue);

      final result2 = await migration.migrateIfNeeded();
      expect(result2, isFalse);

      final count = await migrationStore.entryCount;
      expect(count, equals(1));

      await migrationStore.dispose();
    });

    test('migration trims encounters to 50', () async {
      final manyEncounters = List.generate(
        60,
        (i) => makeEncounter(
          timestamp: DateTime(2024, 1, 1).add(Duration(hours: i)),
        ),
      );

      final legacyEntries = [
        makeEntry(nodeNum: 100, encounters: manyEncounters),
      ];
      final legacyJson = NodeDexEntry.encodeList(legacyEntries);
      SharedPreferences.setMockInitialValues({
        'nodedex_entries': legacyJson,
        'nodedex_meta': 2,
      });

      final migrationDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final migrationStore = NodeDexSqliteStore(migrationDb);
      await migrationStore.init();

      final migration = NodeDexMigration(migrationStore);
      await migration.migrateIfNeeded();

      final loaded = await migrationStore.getEntry(100);
      expect(loaded!.encounters.length, equals(50));

      await migrationStore.dispose();
    });

    test('migration preserves SigilData', () async {
      final sigil = SigilGenerator.generate(42);
      final legacyEntries = [makeEntry(nodeNum: 42, sigil: sigil)];
      final legacyJson = NodeDexEntry.encodeList(legacyEntries);
      SharedPreferences.setMockInitialValues({
        'nodedex_entries': legacyJson,
        'nodedex_meta': 2,
      });

      final migrationDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final migrationStore = NodeDexSqliteStore(migrationDb);
      await migrationStore.init();

      final migration = NodeDexMigration(migrationStore);
      await migration.migrateIfNeeded();

      final loaded = await migrationStore.getEntry(42);
      expect(loaded!.sigil, isNotNull);
      expect(loaded.sigil!.vertices, equals(sigil.vertices));
      expect(loaded.sigil!.rotation, closeTo(sigil.rotation, 0.001));
      expect(loaded.sigil!.primaryColor, equals(sigil.primaryColor));

      await migrationStore.dispose();
    });

    test('migration generates sigil when missing', () async {
      // Create entry without sigil.
      final entry = NodeDexEntry(
        nodeNum: 99,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
      );
      final legacyJson = NodeDexEntry.encodeList([entry]);
      SharedPreferences.setMockInitialValues({
        'nodedex_entries': legacyJson,
        'nodedex_meta': 2,
      });

      final migrationDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final migrationStore = NodeDexSqliteStore(migrationDb);
      await migrationStore.init();

      final migration = NodeDexMigration(migrationStore);
      await migration.migrateIfNeeded();

      final loaded = await migrationStore.getEntry(99);
      expect(loaded!.sigil, isNotNull);
      // Should be deterministically generated from nodeNum.
      final expected = SigilGenerator.generate(99);
      expect(loaded.sigil!.vertices, equals(expected.vertices));

      await migrationStore.dispose();
    });
  });

  // ===========================================================================
  // Merge semantics parity
  // ===========================================================================

  group('merge semantics parity', () {
    test('merge takes min firstSeen and max lastSeen', () {
      final a = makeEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 3, 1),
      );
      final b = makeEntry(
        nodeNum: 1,
        firstSeen: DateTime(2024, 2, 1),
        lastSeen: DateTime(2024, 6, 1),
      );

      final merged = a.mergeWith(b);
      expect(merged.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(merged.lastSeen, equals(DateTime(2024, 6, 1)));
    });

    test('merge takes max encounterCount', () {
      final a = makeEntry(nodeNum: 1, encounterCount: 3);
      final b = makeEntry(nodeNum: 1, encounterCount: 7);

      final merged = a.mergeWith(b);
      expect(merged.encounterCount, equals(7));
    });

    test('merge prefers local socialTag', () {
      final a = makeEntry(nodeNum: 1, socialTag: NodeSocialTag.contact);
      final b = makeEntry(nodeNum: 1, socialTag: NodeSocialTag.knownRelay);

      final merged = a.mergeWith(b);
      expect(merged.socialTag, equals(NodeSocialTag.contact));
    });

    test('merge fills missing socialTag from other', () {
      final a = makeEntry(nodeNum: 1);
      final b = makeEntry(nodeNum: 1, socialTag: NodeSocialTag.trustedNode);

      final merged = a.mergeWith(b);
      expect(merged.socialTag, equals(NodeSocialTag.trustedNode));
    });

    test('merge prefers local userNote', () {
      final a = makeEntry(nodeNum: 1, userNote: 'local');
      final b = makeEntry(nodeNum: 1, userNote: 'remote');

      final merged = a.mergeWith(b);
      expect(merged.userNote, equals('local'));
    });

    test('merge encounter union capped at 50', () {
      final encA = List.generate(
        30,
        (i) => makeEncounter(
          timestamp: DateTime(2024, 1, 1).add(Duration(hours: i)),
        ),
      );
      final encB = List.generate(
        30,
        (i) => makeEncounter(
          timestamp: DateTime(2024, 2, 1).add(Duration(hours: i)),
        ),
      );

      final a = makeEntry(nodeNum: 1, encounters: encA);
      final b = makeEntry(nodeNum: 1, encounters: encB);

      final merged = a.mergeWith(b);
      // Union of 60 unique encounters, capped at 50 (most recent).
      expect(merged.encounters.length, equals(50));
    });

    test('merge co-seen uses max count and broadest time span', () {
      final coSeenA = {
        200: CoSeenRelationship(
          count: 3,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 3, 1),
          messageCount: 5,
        ),
      };
      final coSeenB = {
        200: CoSeenRelationship(
          count: 5,
          firstSeen: DateTime(2024, 2, 1),
          lastSeen: DateTime(2024, 6, 1),
          messageCount: 8,
        ),
      };

      final a = makeEntry(nodeNum: 1, coSeenNodes: coSeenA);
      final b = makeEntry(nodeNum: 1, coSeenNodes: coSeenB);

      final merged = a.mergeWith(b);
      final rel = merged.coSeenNodes[200]!;
      expect(rel.count, equals(5));
      expect(rel.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(rel.lastSeen, equals(DateTime(2024, 6, 1)));
      expect(rel.messageCount, equals(8));
    });

    test('merge regions uses merge method', () {
      final regionsA = [
        SeenRegion(
          regionId: 'r1',
          label: 'Label A',
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 3, 1),
          encounterCount: 3,
        ),
      ];
      final regionsB = [
        SeenRegion(
          regionId: 'r1',
          label: 'Label B',
          firstSeen: DateTime(2024, 2, 1),
          lastSeen: DateTime(2024, 6, 1),
          encounterCount: 5,
        ),
        SeenRegion(
          regionId: 'r2',
          label: 'New Region',
          firstSeen: DateTime(2024, 4, 1),
          lastSeen: DateTime(2024, 4, 1),
          encounterCount: 1,
        ),
      ];

      final a = makeEntry(nodeNum: 1, seenRegions: regionsA);
      final b = makeEntry(nodeNum: 1, seenRegions: regionsB);

      final merged = a.mergeWith(b);
      expect(merged.seenRegions.length, equals(2));

      final r1 = merged.seenRegions.firstWhere((r) => r.regionId == 'r1');
      expect(r1.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(r1.lastSeen, equals(DateTime(2024, 6, 1)));
      expect(r1.encounterCount, equals(5));
    });
  });

  // ===========================================================================
  // Database schema
  // ===========================================================================

  group('database schema', () {
    test('database creates all expected tables', () async {
      final db = database.database;
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' "
        "AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
      );

      final tableNames = tables.map((r) => r['name'] as String).toSet();
      expect(tableNames, contains('nodedex_entries'));
      expect(tableNames, contains('nodedex_encounters'));
      expect(tableNames, contains('nodedex_seen_regions'));
      expect(tableNames, contains('nodedex_coseen_edges'));
      expect(tableNames, contains('sync_state'));
      expect(tableNames, contains('sync_outbox'));
    });

    test('co-seen edge enforces a < b ordering', () async {
      final db = database.database;

      // Inserting a valid edge (a < b) should succeed.
      await db.insert('nodedex_entries', {
        'node_num': 100,
        'first_seen_ms': 1000,
        'last_seen_ms': 2000,
        'encounter_count': 1,
        'message_count': 0,
        'sigil_json': '{}',
        'schema_version': 1,
        'updated_at_ms': 3000,
        'deleted': 0,
      });
      await db.insert('nodedex_entries', {
        'node_num': 200,
        'first_seen_ms': 1000,
        'last_seen_ms': 2000,
        'encounter_count': 1,
        'message_count': 0,
        'sigil_json': '{}',
        'schema_version': 1,
        'updated_at_ms': 3000,
        'deleted': 0,
      });

      await db.insert('nodedex_coseen_edges', {
        'a_node_num': 100,
        'b_node_num': 200,
        'first_seen_ms': 1000,
        'last_seen_ms': 2000,
        'count': 1,
        'message_count': 0,
      });

      // Inserting a reversed edge (a > b) should fail due to CHECK.
      expect(
        () => db.insert('nodedex_coseen_edges', {
          'a_node_num': 200,
          'b_node_num': 100,
          'first_seen_ms': 1000,
          'last_seen_ms': 2000,
          'count': 1,
          'message_count': 0,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
