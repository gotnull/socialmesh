// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/nodedex/models/import_preview.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_store.dart';

void main() {
  late NodeDexStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = NodeDexStore();
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
      sigil: sigil,
    );
  }

  String encodeEntries(List<NodeDexEntry> entries) {
    return NodeDexEntry.encodeList(entries);
  }

  /// Build a raw v1-format JSON string (coSeenNodes as plain ints).
  String buildV1Json(List<Map<String, dynamic>> rawEntries) {
    return jsonEncode(rawEntries);
  }

  // ===========================================================================
  // Initialization and schema
  // ===========================================================================

  group('initialization', () {
    test('init sets schema version', () async {
      final prefs = await SharedPreferences.getInstance();
      final version = prefs.getInt('nodedex_meta');

      expect(version, equals(2));
    });

    test('init is idempotent', () async {
      await store.init();
      await store.init();

      final entries = await store.loadAll();
      expect(entries, isEmpty);
    });

    test('loadAll returns empty list on fresh store', () async {
      final entries = await store.loadAll();

      expect(entries, isEmpty);
    });

    test('entryCount returns 0 on fresh store', () async {
      final count = await store.entryCount;

      expect(count, equals(0));
    });
  });

  // ===========================================================================
  // CRUD operations
  // ===========================================================================

  group('CRUD', () {
    test('saveEntryImmediate persists and is retrievable', () async {
      final entry = makeEntry(nodeNum: 42, encounterCount: 5);

      await store.saveEntryImmediate(entry);

      final retrieved = await store.getEntry(42);
      expect(retrieved, isNotNull);
      expect(retrieved!.nodeNum, equals(42));
      expect(retrieved.encounterCount, equals(5));
    });

    test('saveEntryImmediate upserts existing entry', () async {
      final original = makeEntry(nodeNum: 42, encounterCount: 1);
      await store.saveEntryImmediate(original);

      final updated = makeEntry(nodeNum: 42, encounterCount: 10);
      await store.saveEntryImmediate(updated);

      final retrieved = await store.getEntry(42);
      expect(retrieved!.encounterCount, equals(10));

      final count = await store.entryCount;
      expect(count, equals(1));
    });

    test('hasEntry returns true for existing entry', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 100));

      expect(await store.hasEntry(100), isTrue);
      expect(await store.hasEntry(999), isFalse);
    });

    test('getEntry returns null for missing entry', () async {
      final result = await store.getEntry(999);

      expect(result, isNull);
    });

    test('deleteEntry removes entry', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42));
      await store.saveEntryImmediate(makeEntry(nodeNum: 43));

      await store.deleteEntry(42);

      expect(await store.hasEntry(42), isFalse);
      expect(await store.hasEntry(43), isTrue);
      expect(await store.entryCount, equals(1));
    });

    test('clearAll removes all entries', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 1));
      await store.saveEntryImmediate(makeEntry(nodeNum: 2));
      await store.saveEntryImmediate(makeEntry(nodeNum: 3));

      await store.clearAll();

      expect(await store.entryCount, equals(0));
      expect(await store.loadAll(), isEmpty);
    });

    test('loadAllAsMap returns entries keyed by nodeNum', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 10));
      await store.saveEntryImmediate(makeEntry(nodeNum: 20));
      await store.saveEntryImmediate(makeEntry(nodeNum: 30));

      final map = await store.loadAllAsMap();

      expect(map.length, equals(3));
      expect(map.containsKey(10), isTrue);
      expect(map.containsKey(20), isTrue);
      expect(map.containsKey(30), isTrue);
    });

    test('saveEntries batch saves multiple entries', () async {
      final entries = [
        makeEntry(nodeNum: 1),
        makeEntry(nodeNum: 2),
        makeEntry(nodeNum: 3),
      ];

      store.saveEntries(entries);
      await store.flush();

      expect(await store.entryCount, equals(3));
      expect(await store.hasEntry(1), isTrue);
      expect(await store.hasEntry(2), isTrue);
      expect(await store.hasEntry(3), isTrue);
    });
  });

  // ===========================================================================
  // Social tag and user note operations
  // ===========================================================================

  group('social tag operations', () {
    test('setSocialTag updates tag on existing entry', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42));

      await store.setSocialTag(42, NodeSocialTag.contact);
      await store.flush();

      final retrieved = await store.getEntry(42);
      expect(retrieved!.socialTag, equals(NodeSocialTag.contact));
    });

    test('setSocialTag with null clears tag', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.trustedNode),
      );

      await store.setSocialTag(42, null);
      await store.flush();

      final retrieved = await store.getEntry(42);
      expect(retrieved!.socialTag, isNull);
    });

    test('setSocialTag is no-op for missing entry', () async {
      await store.setSocialTag(999, NodeSocialTag.contact);
      await store.flush();

      expect(await store.hasEntry(999), isFalse);
    });

    test('setUserNote updates note on existing entry', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42));

      await store.setUserNote(42, 'Test note');
      await store.flush();

      final retrieved = await store.getEntry(42);
      expect(retrieved!.userNote, equals('Test note'));
    });

    test('setUserNote with null clears note', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, userNote: 'Old note'),
      );

      await store.setUserNote(42, null);
      await store.flush();

      final retrieved = await store.getEntry(42);
      expect(retrieved!.userNote, isNull);
    });

    test('setUserNote with empty string clears note', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, userNote: 'Old note'),
      );

      await store.setUserNote(42, '');
      await store.flush();

      final retrieved = await store.getEntry(42);
      expect(retrieved!.userNote, isNull);
    });

    test('setUserNote truncates to 280 characters', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42));

      final longNote = 'A' * 500;
      await store.setUserNote(42, longNote);
      await store.flush();

      final retrieved = await store.getEntry(42);
      expect(retrieved!.userNote!.length, equals(280));
    });
  });

  // ===========================================================================
  // Export / import
  // ===========================================================================

  group('export', () {
    test('exportJson returns null for empty store', () async {
      final result = await store.exportJson();

      expect(result, isNull);
    });

    test('exportJson returns valid JSON string', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42, encounterCount: 5));
      await store.saveEntryImmediate(makeEntry(nodeNum: 43, encounterCount: 3));

      final json = await store.exportJson();
      expect(json, isNotNull);

      final parsed = jsonDecode(json!) as List<dynamic>;
      expect(parsed.length, equals(2));
    });

    test('export -> import round-trip preserves data', () async {
      final original = makeEntry(
        nodeNum: 42,
        encounterCount: 5,
        messageCount: 3,
        socialTag: NodeSocialTag.contact,
        userNote: 'Test note',
        coSeenNodes: {
          100: CoSeenRelationship(
            count: 3,
            firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
            messageCount: 2,
          ),
        },
      );
      await store.saveEntryImmediate(original);

      final exported = await store.exportJson();

      // Create a fresh store and import
      SharedPreferences.setMockInitialValues({});
      final newStore = NodeDexStore();
      await newStore.init();

      final count = await newStore.importJson(exported!);
      expect(count, equals(1));

      final retrieved = await newStore.getEntry(42);
      expect(retrieved, isNotNull);
      expect(retrieved!.encounterCount, equals(5));
      expect(retrieved.messageCount, equals(3));
      expect(retrieved.socialTag, equals(NodeSocialTag.contact));
      expect(retrieved.userNote, equals('Test note'));
      expect(retrieved.coSeenNodes[100]!.count, equals(3));
      expect(retrieved.coSeenNodes[100]!.messageCount, equals(2));

      await newStore.dispose();
    });
  });

  // ===========================================================================
  // Import: smart merge
  // ===========================================================================

  group('importJson smart merge', () {
    test('import adds new entries to empty store', () async {
      final entries = [
        makeEntry(nodeNum: 1, encounterCount: 5),
        makeEntry(nodeNum: 2, encounterCount: 3),
      ];
      final json = encodeEntries(entries);

      final count = await store.importJson(json);

      expect(count, equals(2));
      expect(await store.entryCount, equals(2));
      expect((await store.getEntry(1))!.encounterCount, equals(5));
      expect((await store.getEntry(2))!.encounterCount, equals(3));
    });

    test('import merges scalar metrics with existing entries', () async {
      // Local entry
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          firstSeen: DateTime(2024, 3, 1),
          lastSeen: DateTime(2024, 6, 1),
          encounterCount: 5,
          maxDistanceSeen: 1500.0,
          bestSnr: 10,
          bestRssi: -85,
          messageCount: 3,
        ),
      );

      // Imported entry with broader data
      final imported = [
        makeEntry(
          nodeNum: 42,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 8, 1),
          encounterCount: 10,
          maxDistanceSeen: 5000.0,
          bestSnr: 15,
          bestRssi: -70,
          messageCount: 8,
        ),
      ];
      final json = encodeEntries(imported);

      final count = await store.importJson(json);
      expect(count, equals(1));

      final result = await store.getEntry(42);
      expect(result, isNotNull);
      expect(result!.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(result.lastSeen, equals(DateTime(2024, 8, 1)));
      expect(result.encounterCount, equals(10));
      expect(result.maxDistanceSeen, equals(5000.0));
      expect(result.bestSnr, equals(15));
      expect(result.bestRssi, equals(-70));
      expect(result.messageCount, equals(8));
    });

    test('import preserves local socialTag and userNote', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'my local note',
        ),
      );

      final imported = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];
      final json = encodeEntries(imported);

      await store.importJson(json);

      final result = await store.getEntry(42);
      // Local-only fields prefer the existing (local) entry
      expect(result!.socialTag, equals(NodeSocialTag.contact));
      expect(result.userNote, equals('my local note'));
    });

    test('import fills socialTag from import when local is null', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42));

      final imported = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.knownRelay),
      ];
      final json = encodeEntries(imported);

      await store.importJson(json);

      final result = await store.getEntry(42);
      expect(result!.socialTag, equals(NodeSocialTag.knownRelay));
    });

    test('import merges co-seen relationships per edge', () async {
      final now = DateTime(2024, 6, 1);
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 3,
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 5, 1),
              messageCount: 2,
            ),
            200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
        ),
      );

      final imported = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 8,
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              messageCount: 5,
            ),
            300: CoSeenRelationship(
              count: 4,
              firstSeen: now,
              lastSeen: now,
              messageCount: 1,
            ),
          },
        ),
      ];
      final json = encodeEntries(imported);

      await store.importJson(json);

      final result = await store.getEntry(42);
      expect(result, isNotNull);
      expect(result!.coSeenNodes.length, equals(3));

      // Edge 100 merged: higher count, broader time span
      final rel100 = result.coSeenNodes[100]!;
      expect(rel100.count, equals(8));
      expect(rel100.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(rel100.lastSeen, equals(DateTime(2024, 6, 1)));
      expect(rel100.messageCount, equals(5));

      // Edge 200 preserved from local (not in import)
      expect(result.coSeenNodes[200]!.count, equals(1));

      // Edge 300 added from import
      expect(result.coSeenNodes[300]!.count, equals(4));
      expect(result.coSeenNodes[300]!.messageCount, equals(1));
    });

    test('import merges seen regions by regionId', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 5, 1),
              encounterCount: 5,
            ),
          ],
        ),
      );

      final imported = [
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 4, 1),
              encounterCount: 8,
            ),
            SeenRegion(
              regionId: 'r2',
              label: 'Region 2',
              firstSeen: DateTime(2024, 6, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 1,
            ),
          ],
        ),
      ];
      final json = encodeEntries(imported);

      await store.importJson(json);

      final result = await store.getEntry(42);
      expect(result!.seenRegions.length, equals(2));

      final r1 = result.seenRegions.firstWhere((r) => r.regionId == 'r1');
      expect(r1.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(r1.lastSeen, equals(DateTime(2024, 5, 1)));
      expect(r1.encounterCount, equals(8));

      final r2 = result.seenRegions.firstWhere((r) => r.regionId == 'r2');
      expect(r2.encounterCount, equals(1));
    });

    test('import merges encounters and deduplicates', () async {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1700010000000);
      final t3 = DateTime.fromMillisecondsSinceEpoch(1700020000000);

      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t1, snr: 5),
            EncounterRecord(timestamp: t2, snr: 8),
          ],
        ),
      );

      final imported = [
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t2, snr: 8), // duplicate
            EncounterRecord(timestamp: t3, snr: 12), // new
          ],
        ),
      ];
      final json = encodeEntries(imported);

      await store.importJson(json);

      final result = await store.getEntry(42);
      expect(result!.encounters.length, equals(3));
      expect(result.encounters[0].timestamp, equals(t1));
      expect(result.encounters[1].timestamp, equals(t2));
      expect(result.encounters[2].timestamp, equals(t3));
    });

    test('import does not lose existing entries not in import file', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 1, encounterCount: 5));
      await store.saveEntryImmediate(makeEntry(nodeNum: 2, encounterCount: 3));

      // Import only has node 1
      final imported = [makeEntry(nodeNum: 1, encounterCount: 10)];
      final json = encodeEntries(imported);

      await store.importJson(json);

      // Node 2 should still exist
      expect(await store.hasEntry(2), isTrue);
      expect((await store.getEntry(2))!.encounterCount, equals(3));

      // Node 1 should be merged
      expect((await store.getEntry(1))!.encounterCount, equals(10));
    });

    test('import with empty JSON returns 0', () async {
      final count = await store.importJson('[]');

      expect(count, equals(0));
    });

    test('import with invalid JSON returns 0', () async {
      final count = await store.importJson('not valid json');

      expect(count, equals(0));
    });

    test('import multiple entries with mixed new and existing', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 1, encounterCount: 5));

      final imported = [
        makeEntry(nodeNum: 1, encounterCount: 10), // existing
        makeEntry(nodeNum: 2, encounterCount: 3), // new
        makeEntry(nodeNum: 3, encounterCount: 7), // new
      ];
      final json = encodeEntries(imported);

      final count = await store.importJson(json);

      expect(count, equals(3));
      expect(await store.entryCount, equals(3));
      expect((await store.getEntry(1))!.encounterCount, equals(10));
      expect((await store.getEntry(2))!.encounterCount, equals(3));
      expect((await store.getEntry(3))!.encounterCount, equals(7));
    });
  });

  // ===========================================================================
  // Import: v1 legacy migration
  // ===========================================================================

  group('importJson v1 legacy migration', () {
    test('import v1 entries with int coSeenNodes', () async {
      final v1Json = buildV1Json([
        {
          'nn': 42,
          'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
          'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
          'ec': 5,
          'mc': 2,
          'enc': <dynamic>[],
          'sr': <dynamic>[],
          'csn': {'100': 5, '200': 3},
        },
      ]);

      final count = await store.importJson(v1Json);

      expect(count, equals(1));
      final entry = await store.getEntry(42);
      expect(entry, isNotNull);
      expect(entry!.coSeenNodes.length, equals(2));
      expect(entry.coSeenNodes[100]!.count, equals(5));
      expect(entry.coSeenNodes[100]!.messageCount, equals(0));
      expect(entry.coSeenNodes[200]!.count, equals(3));

      // Fallback timestamps should be the entry's firstSeen
      expect(entry.coSeenNodes[100]!.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(entry.coSeenNodes[200]!.firstSeen, equals(DateTime(2024, 1, 1)));
    });

    test('import v2 entries with object coSeenNodes', () async {
      final v2Json = buildV1Json([
        {
          'nn': 42,
          'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
          'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
          'ec': 5,
          'mc': 2,
          'enc': <dynamic>[],
          'sr': <dynamic>[],
          'csn': {
            '100': {
              'c': 5,
              'fs': DateTime(2024, 2, 1).millisecondsSinceEpoch,
              'ls': DateTime(2024, 5, 1).millisecondsSinceEpoch,
              'mc': 2,
            },
          },
        },
      ]);

      final count = await store.importJson(v2Json);

      expect(count, equals(1));
      final entry = await store.getEntry(42);
      expect(entry!.coSeenNodes[100]!.count, equals(5));
      expect(entry.coSeenNodes[100]!.messageCount, equals(2));
      expect(entry.coSeenNodes[100]!.firstSeen, equals(DateTime(2024, 2, 1)));
      expect(entry.coSeenNodes[100]!.lastSeen, equals(DateTime(2024, 5, 1)));
    });

    test('import mixed v1/v2 coSeenNodes in same entry', () async {
      final mixedJson = buildV1Json([
        {
          'nn': 42,
          'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
          'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
          'ec': 5,
          'mc': 2,
          'enc': <dynamic>[],
          'sr': <dynamic>[],
          'csn': {
            '100': 5, // v1 plain int
            '200': {
              // v2 object
              'c': 3,
              'fs': DateTime(2024, 2, 1).millisecondsSinceEpoch,
              'ls': DateTime(2024, 4, 1).millisecondsSinceEpoch,
              'mc': 1,
            },
            '300': 1, // v1 plain int
          },
        },
      ]);

      final count = await store.importJson(mixedJson);

      expect(count, equals(1));
      final entry = await store.getEntry(42);
      expect(entry!.coSeenNodes.length, equals(3));

      // v1 entries: count migrated, timestamps from entry's firstSeen
      expect(entry.coSeenNodes[100]!.count, equals(5));
      expect(entry.coSeenNodes[100]!.messageCount, equals(0));
      expect(entry.coSeenNodes[100]!.firstSeen, equals(DateTime(2024, 1, 1)));

      // v2 entry: full data preserved
      expect(entry.coSeenNodes[200]!.count, equals(3));
      expect(entry.coSeenNodes[200]!.messageCount, equals(1));
      expect(entry.coSeenNodes[200]!.firstSeen, equals(DateTime(2024, 2, 1)));

      // v1 entry
      expect(entry.coSeenNodes[300]!.count, equals(1));
    });

    test('import v1 entry merges with existing v2 entry', () async {
      // Existing v2 entry in store
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 6, 1),
          encounterCount: 10,
          messageCount: 5,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 5,
              firstSeen: DateTime(2024, 2, 1),
              lastSeen: DateTime(2024, 5, 1),
              messageCount: 3,
            ),
          },
        ),
      );

      // Import v1 legacy data
      final v1Json = buildV1Json([
        {
          'nn': 42,
          'fs': DateTime(2023, 11, 1).millisecondsSinceEpoch,
          'ls': DateTime(2024, 4, 1).millisecondsSinceEpoch,
          'ec': 8,
          'mc': 3,
          'enc': <dynamic>[],
          'sr': <dynamic>[],
          'csn': {
            '100': 7, // v1: higher count than local
            '200': 3, // v1: new edge
          },
        },
      ]);

      await store.importJson(v1Json);

      final result = await store.getEntry(42);
      expect(result, isNotNull);

      // Time range broadened
      expect(result!.firstSeen, equals(DateTime(2023, 11, 1)));
      expect(result.lastSeen, equals(DateTime(2024, 6, 1)));

      // Scalar metrics take max
      expect(result.encounterCount, equals(10));
      expect(result.messageCount, equals(5));

      // Co-seen relationships merged
      expect(result.coSeenNodes.length, equals(2));

      // Edge 100: merged — count=7 (from v1 import), messageCount=3 (from local)
      final rel100 = result.coSeenNodes[100]!;
      expect(rel100.count, equals(7));
      expect(rel100.messageCount, equals(3));
      // firstSeen should be the earliest: v1 fallback = entry firstSeen (2023-11-01)
      // vs local firstSeen (2024-02-01)
      expect(rel100.firstSeen, equals(DateTime(2023, 11, 1)));

      // Edge 200: new from v1 import
      final rel200 = result.coSeenNodes[200]!;
      expect(rel200.count, equals(3));
      expect(rel200.messageCount, equals(0));
    });

    test('import multiple v1 entries at once', () async {
      final v1Json = buildV1Json([
        {
          'nn': 1,
          'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
          'ls': DateTime(2024, 3, 1).millisecondsSinceEpoch,
          'ec': 3,
          'mc': 1,
          'enc': <dynamic>[],
          'sr': <dynamic>[],
          'csn': {'2': 5},
        },
        {
          'nn': 2,
          'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
          'ls': DateTime(2024, 3, 1).millisecondsSinceEpoch,
          'ec': 2,
          'mc': 0,
          'enc': <dynamic>[],
          'sr': <dynamic>[],
          'csn': {'1': 5},
        },
      ]);

      final count = await store.importJson(v1Json);

      expect(count, equals(2));
      expect(await store.entryCount, equals(2));

      final entry1 = await store.getEntry(1);
      expect(entry1!.coSeenNodes[2]!.count, equals(5));

      final entry2 = await store.getEntry(2);
      expect(entry2!.coSeenNodes[1]!.count, equals(5));
    });
  });

  // ===========================================================================
  // Persistence across store instances
  // ===========================================================================

  group('persistence', () {
    test('data survives store dispose and re-init', () async {
      final now = DateTime(2024, 6, 1);
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          encounterCount: 5,
          socialTag: NodeSocialTag.contact,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 3,
              firstSeen: now,
              lastSeen: now,
              messageCount: 2,
            ),
          },
        ),
      );

      // Dispose and create new store (same SharedPreferences)
      await store.dispose();
      store = NodeDexStore();
      await store.init();

      final retrieved = await store.getEntry(42);
      expect(retrieved, isNotNull);
      expect(retrieved!.encounterCount, equals(5));
      expect(retrieved.socialTag, equals(NodeSocialTag.contact));
      expect(retrieved.coSeenNodes[100]!.count, equals(3));
      expect(retrieved.coSeenNodes[100]!.messageCount, equals(2));
    });

    test('import persists across store instances', () async {
      final imported = [
        makeEntry(
          nodeNum: 42,
          encounterCount: 10,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 5,
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              messageCount: 3,
            ),
          },
        ),
      ];
      await store.importJson(encodeEntries(imported));

      // Dispose and recreate
      await store.dispose();
      store = NodeDexStore();
      await store.init();

      final retrieved = await store.getEntry(42);
      expect(retrieved, isNotNull);
      expect(retrieved!.encounterCount, equals(10));
      expect(retrieved.coSeenNodes[100]!.count, equals(5));
    });
  });

  // ===========================================================================
  // Debounced save / flush behavior
  // ===========================================================================

  group('flush behavior', () {
    test('saveEntry queues and flush writes to disk', () async {
      store.saveEntry(makeEntry(nodeNum: 42, encounterCount: 7));

      // Before flush, the entry should be in memory cache
      final cached = await store.getEntry(42);
      expect(cached, isNotNull);
      expect(cached!.encounterCount, equals(7));

      // Flush to disk
      await store.flush();

      // Re-create store to verify disk persistence
      await store.dispose();
      store = NodeDexStore();
      await store.init();

      final persisted = await store.getEntry(42);
      expect(persisted, isNotNull);
      expect(persisted!.encounterCount, equals(7));
    });

    test('multiple saves before flush are batched', () async {
      store.saveEntry(makeEntry(nodeNum: 1, encounterCount: 1));
      store.saveEntry(makeEntry(nodeNum: 2, encounterCount: 2));
      store.saveEntry(makeEntry(nodeNum: 1, encounterCount: 10));

      await store.flush();

      // Last save for node 1 should win
      final entry1 = await store.getEntry(1);
      expect(entry1!.encounterCount, equals(10));

      final entry2 = await store.getEntry(2);
      expect(entry2!.encounterCount, equals(2));
    });
  });

  // ===========================================================================
  // Edge cases
  // ===========================================================================

  group('edge cases', () {
    test('import preserves sigil from local when import has none', () async {
      const sigil = SigilData(
        vertices: 5,
        rotation: 1.0,
        innerRings: 2,
        drawRadials: true,
        centerDot: false,
        symmetryFold: 3,
        primaryColor: Color(0xFF0EA5E9),
        secondaryColor: Color(0xFF8B5CF6),
        tertiaryColor: Color(0xFFF97316),
      );
      await store.saveEntryImmediate(makeEntry(nodeNum: 42, sigil: sigil));

      final imported = [makeEntry(nodeNum: 42, encounterCount: 10)];
      await store.importJson(encodeEntries(imported));

      final result = await store.getEntry(42);
      expect(result!.sigil, isNotNull);
      expect(result.sigil!.vertices, equals(5));
    });

    test('import fills sigil from import when local has none', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42));

      const sigil = SigilData(
        vertices: 7,
        rotation: 2.0,
        innerRings: 1,
        drawRadials: false,
        centerDot: true,
        symmetryFold: 5,
        primaryColor: Color(0xFFEF4444),
        secondaryColor: Color(0xFFFBBF24),
        tertiaryColor: Color(0xFF10B981),
      );
      final imported = [makeEntry(nodeNum: 42, sigil: sigil)];
      await store.importJson(encodeEntries(imported));

      final result = await store.getEntry(42);
      expect(result!.sigil, isNotNull);
      expect(result.sigil!.vertices, equals(7));
    });

    test('large import does not lose data', () async {
      // Pre-populate store with some entries
      for (int i = 0; i < 10; i++) {
        await store.saveEntryImmediate(
          makeEntry(nodeNum: i, encounterCount: i + 1),
        );
      }

      // Import 50 entries, some overlapping
      final imported = List.generate(
        50,
        (i) => makeEntry(nodeNum: i, encounterCount: (i + 1) * 2),
      );
      final json = encodeEntries(imported);

      final count = await store.importJson(json);
      expect(count, equals(50));
      expect(await store.entryCount, equals(50));

      // Verify overlapping entries got the higher encounter count
      for (int i = 0; i < 10; i++) {
        final entry = await store.getEntry(i);
        expect(
          entry!.encounterCount,
          equals((i + 1) * 2),
          reason: 'Node $i should have encounter count ${(i + 1) * 2}',
        );
      }
    });

    test(
      'import entry with no coSeenNodes merges with local that has them',
      () async {
        final now = DateTime(2024, 6, 1);
        await store.saveEntryImmediate(
          makeEntry(
            nodeNum: 42,
            coSeenNodes: {
              100: CoSeenRelationship(count: 5, firstSeen: now, lastSeen: now),
            },
          ),
        );

        final imported = [makeEntry(nodeNum: 42, encounterCount: 20)];
        await store.importJson(encodeEntries(imported));

        final result = await store.getEntry(42);
        // Local co-seen relationships should be preserved
        expect(result!.coSeenNodes.length, equals(1));
        expect(result.coSeenNodes[100]!.count, equals(5));
        // Imported scalar metric should be merged
        expect(result.encounterCount, equals(20));
      },
    );

    test(
      'import entry with coSeenNodes merges with local that has none',
      () async {
        await store.saveEntryImmediate(
          makeEntry(nodeNum: 42, encounterCount: 5),
        );

        final now = DateTime(2024, 6, 1);
        final imported = [
          makeEntry(
            nodeNum: 42,
            encounterCount: 3,
            coSeenNodes: {
              100: CoSeenRelationship(count: 8, firstSeen: now, lastSeen: now),
            },
          ),
        ];
        await store.importJson(encodeEntries(imported));

        final result = await store.getEntry(42);
        expect(result!.coSeenNodes.length, equals(1));
        expect(result.coSeenNodes[100]!.count, equals(8));
        // Local encounter count was higher
        expect(result.encounterCount, equals(5));
      },
    );

    test('double import is idempotent', () async {
      final entries = [
        makeEntry(
          nodeNum: 42,
          encounterCount: 5,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 3,
              firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
              messageCount: 2,
            ),
          },
        ),
      ];
      final json = encodeEntries(entries);

      await store.importJson(json);
      await store.importJson(json); // second import

      final result = await store.getEntry(42);
      expect(result!.encounterCount, equals(5));
      expect(result.coSeenNodes[100]!.count, equals(3));
      expect(result.coSeenNodes[100]!.messageCount, equals(2));
    });
  });

  // ===========================================================================
  // parseImportJson
  // ===========================================================================

  group('parseImportJson', () {
    test('parses valid JSON into entries', () {
      final entries = [
        makeEntry(nodeNum: 1, encounterCount: 5),
        makeEntry(nodeNum: 2, encounterCount: 3),
      ];
      final json = encodeEntries(entries);

      final parsed = store.parseImportJson(json);

      expect(parsed.length, equals(2));
      expect(parsed[0].nodeNum, equals(1));
      expect(parsed[0].encounterCount, equals(5));
      expect(parsed[1].nodeNum, equals(2));
      expect(parsed[1].encounterCount, equals(3));
    });

    test('returns empty list for invalid JSON', () {
      final parsed = store.parseImportJson('not valid json');

      expect(parsed, isEmpty);
    });

    test('returns empty list for empty JSON array', () {
      final parsed = store.parseImportJson('[]');

      expect(parsed, isEmpty);
    });

    test('returns empty list for empty string', () {
      final parsed = store.parseImportJson('');

      expect(parsed, isEmpty);
    });

    test('does not modify store state', () async {
      final entries = [makeEntry(nodeNum: 42, encounterCount: 10)];
      final json = encodeEntries(entries);

      store.parseImportJson(json);

      // Store should still be empty
      expect(await store.entryCount, equals(0));
      expect(await store.hasEntry(42), isFalse);
    });

    test('parses entries with full data including co-seen relationships', () {
      final now = DateTime(2024, 6, 1);
      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'test note',
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 5,
              firstSeen: now,
              lastSeen: now,
              messageCount: 3,
            ),
          },
        ),
      ];
      final json = encodeEntries(entries);

      final parsed = store.parseImportJson(json);

      expect(parsed.length, equals(1));
      expect(parsed.first.socialTag, equals(NodeSocialTag.contact));
      expect(parsed.first.userNote, equals('test note'));
      expect(parsed.first.coSeenNodes[100]!.count, equals(5));
      expect(parsed.first.coSeenNodes[100]!.messageCount, equals(3));
    });
  });

  // ===========================================================================
  // previewImport
  // ===========================================================================

  group('previewImport', () {
    test('produces preview for new entries against empty store', () async {
      final entries = [
        makeEntry(nodeNum: 1, encounterCount: 5),
        makeEntry(nodeNum: 2, encounterCount: 3),
      ];

      final preview = await store.previewImport(entries);

      expect(preview.totalImported, equals(2));
      expect(preview.newEntryCount, equals(2));
      expect(preview.mergeEntryCount, equals(0));
      expect(preview.conflictCount, equals(0));
      expect(preview.hasConflicts, isFalse);
    });

    test(
      'produces preview with merge candidates for existing entries',
      () async {
        await store.saveEntryImmediate(
          makeEntry(nodeNum: 42, encounterCount: 5),
        );

        final entries = [makeEntry(nodeNum: 42, encounterCount: 10)];

        final preview = await store.previewImport(entries);

        expect(preview.totalImported, equals(1));
        expect(preview.newEntryCount, equals(0));
        expect(preview.mergeEntryCount, equals(1));
        expect(preview.entries.first.isNew, isFalse);
        expect(preview.entries.first.importHasMoreEncounters, isTrue);
      },
    );

    test('detects socialTag conflict in preview', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      );

      final entries = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.trustedNode),
      ];

      final preview = await store.previewImport(entries);

      expect(preview.hasConflicts, isTrue);
      expect(preview.conflictCount, equals(1));
      expect(preview.entries.first.socialTagConflict, isNotNull);
      expect(
        preview.entries.first.socialTagConflict!.localValue,
        equals(NodeSocialTag.contact),
      );
      expect(
        preview.entries.first.socialTagConflict!.importedValue,
        equals(NodeSocialTag.trustedNode),
      );
    });

    test('detects userNote conflict in preview', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, userNote: 'local note'),
      );

      final entries = [makeEntry(nodeNum: 42, userNote: 'imported note')];

      final preview = await store.previewImport(entries);

      expect(preview.hasConflicts, isTrue);
      expect(preview.entries.first.userNoteConflict, isNotNull);
      expect(
        preview.entries.first.userNoteConflict!.localValue,
        equals('local note'),
      );
      expect(
        preview.entries.first.userNoteConflict!.importedValue,
        equals('imported note'),
      );
    });

    test('does not modify store state', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42, encounterCount: 5));

      final entries = [makeEntry(nodeNum: 42, encounterCount: 50)];
      await store.previewImport(entries);

      // Store should be unchanged
      final stored = await store.getEntry(42);
      expect(stored!.encounterCount, equals(5));
    });

    test('uses displayNameResolver when provided', () async {
      final entries = [makeEntry(nodeNum: 0xABCD)];

      final preview = await store.previewImport(
        entries,
        displayNameResolver: (nodeNum) => 'TestNode-$nodeNum',
      );

      expect(preview.entries.first.displayName, equals('TestNode-43981'));
    });

    test('falls back to hex display name without resolver', () async {
      final entries = [makeEntry(nodeNum: 0x00FF)];

      final preview = await store.previewImport(entries);

      expect(preview.entries.first.displayName, equals('Node 00FF'));
    });

    test('counts new co-seen edges correctly', () async {
      final now = DateTime(2024, 6, 1);
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 3, firstSeen: now, lastSeen: now),
          },
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(count: 5, firstSeen: now, lastSeen: now),
            200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
            300: CoSeenRelationship(count: 2, firstSeen: now, lastSeen: now),
          },
        ),
      ];

      final preview = await store.previewImport(entries);

      expect(preview.entries.first.newCoSeenEdges, equals(2));
    });

    test('counts new encounter records correctly', () async {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1700010000000);
      final t3 = DateTime.fromMillisecondsSinceEpoch(1700020000000);

      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t1, snr: 5),
            EncounterRecord(timestamp: t2, snr: 8),
          ],
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t2, snr: 8),
            EncounterRecord(timestamp: t3, snr: 12),
          ],
        ),
      ];

      final preview = await store.previewImport(entries);

      expect(preview.entries.first.newEncounterRecords, equals(1));
    });

    test('counts new regions correctly', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 5,
            ),
          ],
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 2, 1),
              lastSeen: DateTime(2024, 5, 1),
              encounterCount: 3,
            ),
            SeenRegion(
              regionId: 'r2',
              label: 'Region 2',
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 3, 1),
              encounterCount: 1,
            ),
          ],
        ),
      ];

      final preview = await store.previewImport(entries);

      expect(preview.entries.first.newRegions, equals(1));
    });

    test('mixed new and existing entries in preview', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 10,
          socialTag: NodeSocialTag.contact,
          encounterCount: 5,
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 10,
          socialTag: NodeSocialTag.trustedNode,
          encounterCount: 10,
        ),
        makeEntry(nodeNum: 20, encounterCount: 3),
        makeEntry(nodeNum: 30, encounterCount: 7),
      ];

      final preview = await store.previewImport(entries);

      expect(preview.totalImported, equals(3));
      expect(preview.newEntryCount, equals(2));
      expect(preview.mergeEntryCount, equals(1));
      expect(preview.conflictCount, equals(1));
    });

    test('empty import list produces empty preview', () async {
      final preview = await store.previewImport([]);

      expect(preview.isEmpty, isTrue);
      expect(preview.totalImported, equals(0));
    });
  });

  // ===========================================================================
  // importWithMerge — keepLocal strategy
  // ===========================================================================

  group('importWithMerge — keepLocal strategy', () {
    test('adds new entries directly', () async {
      final entries = [
        makeEntry(
          nodeNum: 42,
          encounterCount: 10,
          socialTag: NodeSocialTag.contact,
          userNote: 'test note',
        ),
      ];

      final preview = await store.previewImport(entries);
      final count = await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      expect(count, equals(1));
      final stored = await store.getEntry(42);
      expect(stored, isNotNull);
      expect(stored!.encounterCount, equals(10));
      expect(stored.socialTag, equals(NodeSocialTag.contact));
      expect(stored.userNote, equals('test note'));
    });

    test('keeps local socialTag on conflict', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          encounterCount: 3,
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          encounterCount: 10,
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.contact));
      expect(stored.encounterCount, equals(10));
    });

    test('keeps local userNote on conflict', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, userNote: 'local note'),
      );

      final entries = [makeEntry(nodeNum: 42, userNote: 'imported note')];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.userNote, equals('local note'));
    });

    test('fills socialTag from import when local has none', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42));

      final entries = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.knownRelay),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.knownRelay));
    });

    test('fills userNote from import when local has none', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 42));

      final entries = [makeEntry(nodeNum: 42, userNote: 'import only note')];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.userNote, equals('import only note'));
    });

    test('merges scalar metrics correctly', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          firstSeen: DateTime(2024, 3, 1),
          lastSeen: DateTime(2024, 6, 1),
          encounterCount: 5,
          maxDistanceSeen: 1500.0,
          bestSnr: 10,
          bestRssi: -85,
          messageCount: 3,
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          firstSeen: DateTime(2024, 1, 1),
          lastSeen: DateTime(2024, 8, 1),
          encounterCount: 10,
          maxDistanceSeen: 5000.0,
          bestSnr: 15,
          bestRssi: -70,
          messageCount: 8,
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(stored.lastSeen, equals(DateTime(2024, 8, 1)));
      expect(stored.encounterCount, equals(10));
      expect(stored.maxDistanceSeen, equals(5000.0));
      expect(stored.bestSnr, equals(15));
      expect(stored.bestRssi, equals(-70));
      expect(stored.messageCount, equals(8));
    });

    test('merges co-seen relationships', () async {
      final now = DateTime(2024, 6, 1);
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 3,
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 5, 1),
              messageCount: 2,
            ),
            200: CoSeenRelationship(count: 1, firstSeen: now, lastSeen: now),
          },
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 8,
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              messageCount: 5,
            ),
            300: CoSeenRelationship(count: 4, firstSeen: now, lastSeen: now),
          },
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.coSeenNodes.length, equals(3));
      expect(stored.coSeenNodes[100]!.count, equals(8));
      expect(stored.coSeenNodes[100]!.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(stored.coSeenNodes[100]!.messageCount, equals(5));
      expect(stored.coSeenNodes[200]!.count, equals(1));
      expect(stored.coSeenNodes[300]!.count, equals(4));
    });

    test('does not lose existing entries not in import', () async {
      await store.saveEntryImmediate(makeEntry(nodeNum: 1, encounterCount: 5));
      await store.saveEntryImmediate(makeEntry(nodeNum: 2, encounterCount: 3));

      final entries = [makeEntry(nodeNum: 1, encounterCount: 10)];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      expect(await store.hasEntry(2), isTrue);
      expect((await store.getEntry(2))!.encounterCount, equals(3));
      expect((await store.getEntry(1))!.encounterCount, equals(10));
    });

    test('persists across store instances', () async {
      final entries = [
        makeEntry(
          nodeNum: 42,
          encounterCount: 10,
          socialTag: NodeSocialTag.contact,
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      // Dispose and re-create
      await store.dispose();
      store = NodeDexStore();
      await store.init();

      final stored = await store.getEntry(42);
      expect(stored, isNotNull);
      expect(stored!.encounterCount, equals(10));
      expect(stored.socialTag, equals(NodeSocialTag.contact));
    });
  });

  // ===========================================================================
  // importWithMerge — preferImport strategy
  // ===========================================================================

  group('importWithMerge — preferImport strategy', () {
    test('uses imported socialTag on conflict', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      );

      final entries = [
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.trustedNode),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.preferImport,
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.trustedNode));
    });

    test('uses imported userNote on conflict', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, userNote: 'local note'),
      );

      final entries = [makeEntry(nodeNum: 42, userNote: 'imported note')];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.preferImport,
      );

      final stored = await store.getEntry(42);
      expect(stored!.userNote, equals('imported note'));
    });

    test('uses both imported fields on dual conflict', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.preferImport,
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.trustedNode));
      expect(stored.userNote, equals('imported note'));
    });

    test('preserves local socialTag when import has none', () async {
      await store.saveEntryImmediate(
        makeEntry(nodeNum: 42, socialTag: NodeSocialTag.contact),
      );

      final entries = [makeEntry(nodeNum: 42)];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.preferImport,
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.contact));
    });

    test('still merges scalar metrics with preferImport', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          encounterCount: 5,
          bestSnr: 10,
          maxDistanceSeen: 1500.0,
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          encounterCount: 10,
          bestSnr: 20,
          maxDistanceSeen: 5000.0,
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.preferImport,
      );

      final stored = await store.getEntry(42);
      expect(stored!.encounterCount, equals(10));
      expect(stored.bestSnr, equals(20));
      expect(stored.maxDistanceSeen, equals(5000.0));
    });
  });

  // ===========================================================================
  // importWithMerge — reviewConflicts strategy
  // ===========================================================================

  group('importWithMerge — reviewConflicts strategy', () {
    test('uses per-entry resolution to pick imported socialTag', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: true,
            useUserNoteFromImport: false,
          ),
        },
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.trustedNode));
      expect(stored.userNote, equals('local note'));
    });

    test('uses per-entry resolution to pick imported userNote', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: false,
            useUserNoteFromImport: true,
          ),
        },
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.contact));
      expect(stored.userNote, equals('imported note'));
    });

    test('uses both imported values when resolution says so', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: true,
            useUserNoteFromImport: true,
          ),
        },
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.trustedNode));
      expect(stored.userNote, equals('imported note'));
    });

    test('falls back to keepLocal when no resolution provided', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {},
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.contact));
      expect(stored.userNote, equals('local note'));
    });

    test('different resolutions for different entries', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 10,
          socialTag: NodeSocialTag.contact,
          userNote: 'local 10',
        ),
      );
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 20,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'local 20',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 10,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported 10',
        ),
        makeEntry(
          nodeNum: 20,
          socialTag: NodeSocialTag.contact,
          userNote: 'imported 20',
        ),
        makeEntry(nodeNum: 30, encounterCount: 5), // new entry
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          // Entry 10: prefer import for both
          10: const ConflictResolution(
            nodeNum: 10,
            useSocialTagFromImport: true,
            useUserNoteFromImport: true,
          ),
          // Entry 20: keep local for tag, import for note
          20: const ConflictResolution(
            nodeNum: 20,
            useSocialTagFromImport: false,
            useUserNoteFromImport: true,
          ),
        },
      );

      final stored10 = await store.getEntry(10);
      expect(stored10!.socialTag, equals(NodeSocialTag.trustedNode));
      expect(stored10.userNote, equals('imported 10'));

      final stored20 = await store.getEntry(20);
      expect(stored20!.socialTag, equals(NodeSocialTag.trustedNode));
      expect(stored20.userNote, equals('imported 20'));

      // New entry should be added directly
      final stored30 = await store.getEntry(30);
      expect(stored30, isNotNull);
      expect(stored30!.encounterCount, equals(5));
    });

    test('null resolution fields fall back to keepLocal', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {42: const ConflictResolution(nodeNum: 42)},
      );

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.contact));
      expect(stored.userNote, equals('local note'));
    });

    test('persists resolved values across store instances', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.reviewConflicts,
        resolutions: {
          42: const ConflictResolution(
            nodeNum: 42,
            useSocialTagFromImport: true,
            useUserNoteFromImport: true,
          ),
        },
      );

      // Dispose and re-create
      await store.dispose();
      store = NodeDexStore();
      await store.init();

      final stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.trustedNode));
      expect(stored.userNote, equals('imported note'));
    });
  });

  // ===========================================================================
  // importWithMerge — empty and edge cases
  // ===========================================================================

  group('importWithMerge — edge cases', () {
    test('returns 0 for empty preview', () async {
      const emptyPreview = ImportPreview(entries: [], totalImported: 0);

      final count = await store.importWithMerge(
        preview: emptyPreview,
        strategy: MergeStrategy.keepLocal,
      );

      expect(count, equals(0));
      expect(await store.entryCount, equals(0));
    });

    test('strategies produce different results for same conflict', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'imported note',
        ),
      ];

      // keepLocal
      var preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );
      var stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.contact));
      expect(stored.userNote, equals('local note'));

      // Reset to original state
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          socialTag: NodeSocialTag.contact,
          userNote: 'local note',
        ),
      );

      // preferImport
      preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.preferImport,
      );
      stored = await store.getEntry(42);
      expect(stored!.socialTag, equals(NodeSocialTag.trustedNode));
      expect(stored.userNote, equals('imported note'));
    });

    test('large import with mixed strategies', () async {
      // Pre-populate with 10 entries
      for (int i = 0; i < 10; i++) {
        await store.saveEntryImmediate(
          makeEntry(
            nodeNum: i,
            encounterCount: i + 1,
            socialTag: NodeSocialTag.contact,
          ),
        );
      }

      // Import 20 entries: 10 overlapping, 10 new
      final entries = List.generate(
        20,
        (i) => makeEntry(
          nodeNum: i,
          encounterCount: (i + 1) * 2,
          socialTag: NodeSocialTag.trustedNode,
        ),
      );

      final preview = await store.previewImport(entries);
      expect(preview.newEntryCount, equals(10));
      expect(preview.mergeEntryCount, equals(10));
      expect(preview.conflictCount, equals(10));

      final count = await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.preferImport,
      );

      expect(count, equals(20));
      expect(await store.entryCount, equals(20));

      // Verify overlapping entries got imported socialTag
      for (int i = 0; i < 10; i++) {
        final entry = await store.getEntry(i);
        expect(
          entry!.socialTag,
          equals(NodeSocialTag.trustedNode),
          reason: 'Node $i should have imported socialTag',
        );
        expect(
          entry.encounterCount,
          equals((i + 1) * 2),
          reason: 'Node $i should have higher encounter count',
        );
      }
    });

    test('importWithMerge merges encounters and deduplicates', () async {
      final t1 = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final t2 = DateTime.fromMillisecondsSinceEpoch(1700010000000);
      final t3 = DateTime.fromMillisecondsSinceEpoch(1700020000000);

      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t1, snr: 5),
            EncounterRecord(timestamp: t2, snr: 8),
          ],
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          encounters: [
            EncounterRecord(timestamp: t2, snr: 8),
            EncounterRecord(timestamp: t3, snr: 12),
          ],
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.encounters.length, equals(3));
      expect(stored.encounters[0].timestamp, equals(t1));
      expect(stored.encounters[1].timestamp, equals(t2));
      expect(stored.encounters[2].timestamp, equals(t3));
    });

    test('importWithMerge merges regions by regionId', () async {
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 3, 1),
              lastSeen: DateTime(2024, 5, 1),
              encounterCount: 5,
            ),
          ],
        ),
      );

      final entries = [
        makeEntry(
          nodeNum: 42,
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 4, 1),
              encounterCount: 8,
            ),
            SeenRegion(
              regionId: 'r2',
              label: 'Region 2',
              firstSeen: DateTime(2024, 6, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 1,
            ),
          ],
        ),
      ];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.seenRegions.length, equals(2));

      final r1 = stored.seenRegions.firstWhere((r) => r.regionId == 'r1');
      expect(r1.firstSeen, equals(DateTime(2024, 1, 1)));
      expect(r1.lastSeen, equals(DateTime(2024, 5, 1)));
      expect(r1.encounterCount, equals(8));

      final r2 = stored.seenRegions.firstWhere((r) => r.regionId == 'r2');
      expect(r2.encounterCount, equals(1));
    });

    test('importWithMerge preserves sigil from local', () async {
      const sigil = SigilData(
        vertices: 5,
        rotation: 1.0,
        innerRings: 2,
        drawRadials: true,
        centerDot: false,
        symmetryFold: 3,
        primaryColor: Color(0xFF0EA5E9),
        secondaryColor: Color(0xFF8B5CF6),
        tertiaryColor: Color(0xFFF97316),
      );
      await store.saveEntryImmediate(makeEntry(nodeNum: 42, sigil: sigil));

      final entries = [makeEntry(nodeNum: 42, encounterCount: 10)];

      final preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.sigil, isNotNull);
      expect(stored.sigil!.vertices, equals(5));
    });

    test(
      'importWithMerge fills sigil from import when local has none',
      () async {
        await store.saveEntryImmediate(makeEntry(nodeNum: 42));

        const sigil = SigilData(
          vertices: 7,
          rotation: 2.0,
          innerRings: 1,
          drawRadials: false,
          centerDot: true,
          symmetryFold: 5,
          primaryColor: Color(0xFFEF4444),
          secondaryColor: Color(0xFFFBBF24),
          tertiaryColor: Color(0xFF10B981),
        );
        final entries = [makeEntry(nodeNum: 42, sigil: sigil)];

        final preview = await store.previewImport(entries);
        await store.importWithMerge(
          preview: preview,
          strategy: MergeStrategy.keepLocal,
        );

        final stored = await store.getEntry(42);
        expect(stored!.sigil, isNotNull);
        expect(stored.sigil!.vertices, equals(7));
      },
    );

    test('double importWithMerge is idempotent', () async {
      final now = DateTime(2024, 6, 1);
      final entries = [
        makeEntry(
          nodeNum: 42,
          encounterCount: 5,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(1700100000000),
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 3,
              firstSeen: now,
              lastSeen: now,
              messageCount: 2,
            ),
          },
        ),
      ];

      // First import
      var preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      // Second import of same data
      preview = await store.previewImport(entries);
      await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );

      final stored = await store.getEntry(42);
      expect(stored!.encounterCount, equals(5));
      expect(stored.coSeenNodes[100]!.count, equals(3));
      expect(stored.coSeenNodes[100]!.messageCount, equals(2));
    });
  });

  // ===========================================================================
  // Full pipeline: parseImportJson -> previewImport -> importWithMerge
  // ===========================================================================

  group('full import pipeline', () {
    test('parse -> preview -> import round trip', () async {
      // Pre-populate store
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          encounterCount: 5,
          socialTag: NodeSocialTag.contact,
          userNote: 'my note',
        ),
      );

      // Create JSON from entries
      final importEntries = [
        makeEntry(
          nodeNum: 42,
          encounterCount: 10,
          socialTag: NodeSocialTag.trustedNode,
          userNote: 'their note',
        ),
        makeEntry(nodeNum: 100, encounterCount: 3),
      ];
      final jsonString = encodeEntries(importEntries);

      // Step 1: parse
      final parsed = store.parseImportJson(jsonString);
      expect(parsed.length, equals(2));

      // Step 2: preview
      final preview = await store.previewImport(parsed);
      expect(preview.totalImported, equals(2));
      expect(preview.newEntryCount, equals(1));
      expect(preview.mergeEntryCount, equals(1));
      expect(preview.conflictCount, equals(1));

      // Step 3: import with keepLocal
      final count = await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );
      expect(count, equals(2));

      // Verify results
      final stored42 = await store.getEntry(42);
      expect(stored42!.encounterCount, equals(10));
      expect(stored42.socialTag, equals(NodeSocialTag.contact));
      expect(stored42.userNote, equals('my note'));

      final stored100 = await store.getEntry(100);
      expect(stored100, isNotNull);
      expect(stored100!.encounterCount, equals(3));
    });

    test('export -> parse -> preview -> importWithMerge round trip', () async {
      // Populate store with rich data
      final now = DateTime(2024, 6, 1);
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 42,
          encounterCount: 5,
          socialTag: NodeSocialTag.contact,
          userNote: 'original note',
          coSeenNodes: {
            100: CoSeenRelationship(
              count: 3,
              firstSeen: now,
              lastSeen: now,
              messageCount: 2,
            ),
          },
          seenRegions: [
            SeenRegion(
              regionId: 'r1',
              label: 'Region 1',
              firstSeen: DateTime(2024, 1, 1),
              lastSeen: DateTime(2024, 6, 1),
              encounterCount: 5,
            ),
          ],
        ),
      );

      // Export
      final exported = await store.exportJson();
      expect(exported, isNotNull);

      // Create a fresh store and import
      await store.dispose();
      SharedPreferences.setMockInitialValues({});
      store = NodeDexStore();
      await store.init();

      // Parse
      final parsed = store.parseImportJson(exported!);
      expect(parsed.length, equals(1));

      // Preview
      final preview = await store.previewImport(parsed);
      expect(preview.newEntryCount, equals(1));
      expect(preview.conflictCount, equals(0));

      // Import
      final count = await store.importWithMerge(
        preview: preview,
        strategy: MergeStrategy.keepLocal,
      );
      expect(count, equals(1));

      // Verify full data round-trip
      final stored = await store.getEntry(42);
      expect(stored, isNotNull);
      expect(stored!.encounterCount, equals(5));
      expect(stored.socialTag, equals(NodeSocialTag.contact));
      expect(stored.userNote, equals('original note'));
      expect(stored.coSeenNodes[100]!.count, equals(3));
      expect(stored.coSeenNodes[100]!.messageCount, equals(2));
      expect(stored.seenRegions.length, equals(1));
      expect(stored.seenRegions.first.regionId, equals('r1'));
    });
  });
}
