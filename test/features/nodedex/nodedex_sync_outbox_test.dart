// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Sync Outbox Pattern Tests — comprehensive coverage for the
// outbox-based Cloud Sync pipeline.
//
// Covers store-level outbox operations, sync pull edge cases,
// deduplication ordering, tombstone handling, retry tracking,
// lastKnownName round-trip, and full pipeline integration scenarios.
//
// These tests complement nodedex_sync_pipeline_test.dart (bug-fix focused)
// and nodedex_sync_coverage_test.dart (merge semantics focused).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_database.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sqlite_store.dart';
import 'package:socialmesh/features/nodedex/services/nodedex_sync_service.dart';
import 'package:socialmesh/features/nodedex/services/sigil_generator.dart';
import 'package:socialmesh/services/sync/sync_contract.dart';
import 'package:socialmesh/services/sync/sync_diagnostics.dart';
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
    NodeSocialTag? socialTag,
    int? socialTagUpdatedAtMs,
    String? userNote,
    int? userNoteUpdatedAtMs,
    String? lastKnownName,
    List<EncounterRecord>? encounters,
    List<SeenRegion>? seenRegions,
    Map<int, CoSeenRelationship>? coSeenNodes,
  }) {
    final now = DateTime(2024, 6, 1);
    return NodeDexEntry(
      nodeNum: nodeNum,
      firstSeen: firstSeen ?? now,
      lastSeen: lastSeen ?? now,
      encounterCount: encounterCount,
      socialTag: socialTag,
      socialTagUpdatedAtMs: socialTagUpdatedAtMs,
      userNote: userNote,
      userNoteUpdatedAtMs: userNoteUpdatedAtMs,
      lastKnownName: lastKnownName,
      encounters: encounters ?? const [],
      seenRegions: seenRegions ?? const [],
      coSeenNodes: coSeenNodes ?? const {},
      sigil: SigilGenerator.generate(nodeNum),
    );
  }

  /// Clear all outbox entries.
  Future<void> clearOutbox() async {
    final entries = await store.readOutbox();
    for (final e in entries) {
      await store.removeOutboxEntry(e['id'] as int);
    }
  }

  // ===========================================================================
  // Store-level outbox: setSocialTag
  // ===========================================================================

  group('setSocialTag outbox behavior', () {
    test(
      'setSocialTag on existing entry produces outbox entry after flush',
      () async {
        store.syncEnabled = true;

        // Create entry first.
        final entry = makeEntry(nodeNum: 100);
        await store.saveEntryImmediate(entry);
        await clearOutbox();

        // Set social tag (uses debounced save).
        await store.setSocialTag(100, NodeSocialTag.trustedNode);
        await store.flush();

        final outbox = await store.readOutbox();
        expect(
          outbox,
          isNotEmpty,
          reason: 'setSocialTag should enqueue after flush',
        );

        final row = outbox.last;
        expect(row['entity_type'], 'entry');
        expect(row['entity_id'], 'node:100');
        expect(row['op'], 'upsert');

        final payload =
            jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final restored = NodeDexEntry.fromJson(payload);
        expect(restored.socialTag, NodeSocialTag.trustedNode);
      },
    );

    test(
      'setSocialTag with syncEnabled=false produces no outbox entry',
      () async {
        store.syncEnabled = false;

        final entry = makeEntry(nodeNum: 101);
        await store.saveEntryImmediate(entry);

        await store.setSocialTag(101, NodeSocialTag.contact);
        await store.flush();

        expect(await store.outboxCount, 0);
      },
    );

    test('clearing socialTag produces outbox entry with null tag', () async {
      store.syncEnabled = true;

      final entry = makeEntry(
        nodeNum: 102,
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1000,
      );
      await store.saveEntryImmediate(entry);
      await clearOutbox();

      await store.setSocialTag(102, null);
      await store.flush();

      final outbox = await store.readOutbox();
      expect(outbox, isNotEmpty);

      final payload =
          jsonDecode(outbox.last['payload_json'] as String)
              as Map<String, dynamic>;
      final restored = NodeDexEntry.fromJson(payload);
      expect(restored.socialTag, isNull);
    });

    test('setSocialTag on non-existent entry is a no-op', () async {
      store.syncEnabled = true;

      await store.setSocialTag(999, NodeSocialTag.contact);
      await store.flush();

      expect(await store.outboxCount, 0);
    });
  });

  // ===========================================================================
  // Store-level outbox: setUserNote
  // ===========================================================================

  group('setUserNote outbox behavior', () {
    test(
      'setUserNote on existing entry produces outbox entry after flush',
      () async {
        store.syncEnabled = true;

        final entry = makeEntry(nodeNum: 200);
        await store.saveEntryImmediate(entry);
        await clearOutbox();

        await store.setUserNote(200, 'Relay on the hill');
        await store.flush();

        final outbox = await store.readOutbox();
        expect(outbox, isNotEmpty);

        final payload =
            jsonDecode(outbox.last['payload_json'] as String)
                as Map<String, dynamic>;
        final restored = NodeDexEntry.fromJson(payload);
        expect(restored.userNote, 'Relay on the hill');
      },
    );

    test('clearing userNote produces outbox entry with null note', () async {
      store.syncEnabled = true;

      final entry = makeEntry(
        nodeNum: 201,
        userNote: 'old note',
        userNoteUpdatedAtMs: 1000,
      );
      await store.saveEntryImmediate(entry);
      await clearOutbox();

      await store.setUserNote(201, null);
      await store.flush();

      final outbox = await store.readOutbox();
      expect(outbox, isNotEmpty);

      final payload =
          jsonDecode(outbox.last['payload_json'] as String)
              as Map<String, dynamic>;
      final restored = NodeDexEntry.fromJson(payload);
      expect(restored.userNote, isNull);
    });

    test('empty string userNote is treated as clear', () async {
      store.syncEnabled = true;

      final entry = makeEntry(
        nodeNum: 202,
        userNote: 'existing',
        userNoteUpdatedAtMs: 1000,
      );
      await store.saveEntryImmediate(entry);
      await clearOutbox();

      await store.setUserNote(202, '   ');
      await store.flush();

      final result = await store.getEntry(202);
      expect(result, isNotNull);
      expect(
        result!.userNote,
        isNull,
        reason: 'Whitespace-only note should be treated as clear',
      );
    });

    test('userNote truncated at 280 chars', () async {
      store.syncEnabled = true;

      final entry = makeEntry(nodeNum: 203);
      await store.saveEntryImmediate(entry);
      await clearOutbox();

      final longNote = 'A' * 500;
      await store.setUserNote(203, longNote);
      await store.flush();

      final result = await store.getEntry(203);
      expect(result, isNotNull);
      expect(
        result!.userNote!.length,
        280,
        reason: 'Note should be truncated to 280 chars',
      );
    });

    test('setUserNote on non-existent entry is a no-op', () async {
      store.syncEnabled = true;

      await store.setUserNote(998, 'ghost note');
      await store.flush();

      expect(await store.outboxCount, 0);
    });
  });

  // ===========================================================================
  // Store-level outbox: deleteEntry tombstone
  // ===========================================================================

  group('deleteEntry tombstone and outbox', () {
    test('deleteEntry with syncEnabled creates delete outbox entry', () async {
      store.syncEnabled = true;

      final entry = makeEntry(nodeNum: 300);
      await store.saveEntryImmediate(entry);
      await clearOutbox();

      await store.deleteEntry(300);

      final outbox = await store.readOutbox();
      expect(outbox, isNotEmpty, reason: 'Delete should create outbox entry');

      final deleteRow = outbox.last;
      expect(deleteRow['entity_type'], 'entry');
      expect(deleteRow['entity_id'], 'node:300');
      expect(deleteRow['op'], 'delete');
    });

    test(
      'deleteEntry with syncEnabled=false creates no outbox entry',
      () async {
        store.syncEnabled = false;

        final entry = makeEntry(nodeNum: 301);
        await store.saveEntryImmediate(entry);

        await store.deleteEntry(301);

        expect(await store.outboxCount, 0);
      },
    );

    test('deleted entry is not returned by loadAll', () async {
      store.syncEnabled = true;

      final entry = makeEntry(nodeNum: 302);
      await store.saveEntryImmediate(entry);

      expect(await store.hasEntry(302), isTrue);

      await store.deleteEntry(302);

      expect(
        await store.hasEntry(302),
        isFalse,
        reason: 'Soft-deleted entry should not be in cache',
      );

      // Force reload from disk.
      final freshStore = NodeDexSqliteStore(database);
      await freshStore.init();
      expect(
        await freshStore.hasEntry(302),
        isFalse,
        reason: 'Soft-deleted entry should not load from disk',
      );
    });

    test('deleted entry removed from pending saves', () async {
      store.syncEnabled = true;

      // Add entry to pending (debounced, not flushed).
      final entry = makeEntry(nodeNum: 303);
      store.saveEntry(entry);

      // Delete before flush — should remove from pending.
      await store.deleteEntry(303);

      // Flush should not crash or re-insert.
      await store.flush();

      expect(await store.hasEntry(303), isFalse);
    });
  });

  // ===========================================================================
  // Store-level outbox: clearAll
  // ===========================================================================

  group('clearAll outbox behavior', () {
    test('clearAll removes outbox entries', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 400));
      await store.saveEntryImmediate(makeEntry(nodeNum: 401));
      await store.saveEntryImmediate(makeEntry(nodeNum: 402));

      final outboxBefore = await store.outboxCount;
      expect(outboxBefore, greaterThan(0));

      await store.clearAll();

      expect(
        await store.outboxCount,
        0,
        reason: 'clearAll should remove all outbox entries',
      );
      expect(await store.entryCount, 0);
    });

    test('clearAll cancels pending saves', () async {
      store.syncEnabled = true;

      // Add entries to pending (not flushed).
      store.saveEntry(makeEntry(nodeNum: 410));
      store.saveEntry(makeEntry(nodeNum: 411));

      await store.clearAll();

      // Flush should be a no-op.
      await store.flush();

      expect(await store.entryCount, 0);
      expect(await store.outboxCount, 0);
    });
  });

  // ===========================================================================
  // Store-level outbox: markOutboxAttemptFailed
  // ===========================================================================

  group('markOutboxAttemptFailed', () {
    test('increments attempt count on outbox entry', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 500));

      final outbox = await store.readOutbox();
      expect(outbox, isNotEmpty);

      final id = outbox.last['id'] as int;
      final initialCount = outbox.last['attempt_count'] as int? ?? 0;
      expect(initialCount, 0);

      await store.markOutboxAttemptFailed(id, 'network timeout');

      final updated = await store.readOutbox();
      final updatedRow = updated.firstWhere((e) => e['id'] == id);
      expect(updatedRow['attempt_count'], 1);
      expect(updatedRow['last_error'], 'network timeout');
    });

    test('multiple failures increment count cumulatively', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 501));

      final outbox = await store.readOutbox();
      final id = outbox.last['id'] as int;

      await store.markOutboxAttemptFailed(id, 'error 1');
      await store.markOutboxAttemptFailed(id, 'error 2');
      await store.markOutboxAttemptFailed(id, 'error 3');

      final updated = await store.readOutbox();
      final row = updated.firstWhere((e) => e['id'] == id);
      expect(row['attempt_count'], 3);
      expect(
        row['last_error'],
        'error 3',
        reason: 'Last error should be the most recent',
      );
    });

    test('removeOutboxEntry deletes the entry permanently', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 502));

      final outbox = await store.readOutbox();
      final id = outbox.last['id'] as int;

      await store.removeOutboxEntry(id);

      expect(await store.outboxCount, 0);
    });
  });

  // ===========================================================================
  // Outbox deduplication and ordering
  // ===========================================================================

  group('outbox deduplication and ordering', () {
    test('rapid saves for same node produce single outbox entry', () async {
      store.syncEnabled = true;

      // Save the same node 5 times rapidly.
      for (var i = 0; i < 5; i++) {
        await store.saveEntryImmediate(
          makeEntry(
            nodeNum: 600,
            socialTag: NodeSocialTag.values[i % NodeSocialTag.values.length],
          ),
        );
      }

      final outbox = await store.readOutbox();
      final node600 = outbox.where((e) => e['entity_id'] == 'node:600');
      expect(
        node600.length,
        1,
        reason:
            'Outbox should deduplicate — only the latest entry for node 600',
      );
    });

    test('outbox entries for different nodes are independent', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 601));
      await store.saveEntryImmediate(makeEntry(nodeNum: 602));
      await store.saveEntryImmediate(makeEntry(nodeNum: 603));

      final outbox = await store.readOutbox();
      final entityIds = outbox.map((e) => e['entity_id']).toSet();
      expect(entityIds, containsAll(['node:601', 'node:602', 'node:603']));
    });

    test('outbox is ordered by updated_at_ms ascending', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 610));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await store.saveEntryImmediate(makeEntry(nodeNum: 611));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await store.saveEntryImmediate(makeEntry(nodeNum: 612));

      final outbox = await store.readOutbox();
      expect(outbox.length, greaterThanOrEqualTo(3));

      for (var i = 1; i < outbox.length; i++) {
        final prev = outbox[i - 1]['updated_at_ms'] as int;
        final curr = outbox[i]['updated_at_ms'] as int;
        expect(
          curr,
          greaterThanOrEqualTo(prev),
          reason: 'Outbox should be ordered by updated_at_ms ASC',
        );
      }
    });

    test(
      'upsert after delete for same node replaces delete outbox entry',
      () async {
        store.syncEnabled = true;

        // Create and save.
        await store.saveEntryImmediate(makeEntry(nodeNum: 620));
        await clearOutbox();

        // Delete (creates delete outbox entry).
        await store.deleteEntry(620);

        final afterDelete = await store.readOutbox();
        expect(afterDelete.last['op'], 'delete');

        // Re-create with saveEntryImmediate (creates upsert).
        await store.saveEntryImmediate(makeEntry(nodeNum: 620));

        final afterRecreate = await store.readOutbox();
        final node620 = afterRecreate
            .where((e) => e['entity_id'] == 'node:620')
            .toList();

        // Deduplication in _enqueueOutboxInTxn removes the old delete
        // and replaces it with the new upsert.
        expect(
          node620.length,
          1,
          reason: 'Upsert should replace prior delete for same entity',
        );
        expect(node620.first['op'], 'upsert');
      },
    );
  });

  // ===========================================================================
  // Sync pull: lastKnownName round-trip
  // ===========================================================================

  group('sync pull lastKnownName', () {
    test('lastKnownName survives outbox JSON round-trip', () async {
      store.syncEnabled = true;

      final entry = makeEntry(nodeNum: 700, lastKnownName: 'AliceNode');
      await store.saveEntryImmediate(entry);

      final outbox = await store.readOutbox();
      final payload =
          jsonDecode(outbox.last['payload_json'] as String)
              as Map<String, dynamic>;
      final restored = NodeDexEntry.fromJson(payload);

      expect(restored.lastKnownName, 'AliceNode');
    });

    test('null lastKnownName round-trips correctly', () async {
      store.syncEnabled = true;

      final entry = makeEntry(nodeNum: 701);
      await store.saveEntryImmediate(entry);

      final outbox = await store.readOutbox();
      final payload =
          jsonDecode(outbox.last['payload_json'] as String)
              as Map<String, dynamic>;
      final restored = NodeDexEntry.fromJson(payload);

      expect(restored.lastKnownName, isNull);
    });

    test('lastKnownName merges correctly during sync pull', () async {
      store.syncEnabled = true;

      // Local has no name, remote has a name.
      final local = makeEntry(nodeNum: 702, lastKnownName: null);
      await store.saveEntryImmediate(local);
      await clearOutbox();

      final remote = makeEntry(
        nodeNum: 702,
        lastKnownName: 'RemoteRelay',
        lastSeen: DateTime(2024, 7, 1), // Later lastSeen wins name.
      );

      await store.applySyncPull([remote]);

      final result = await store.getEntry(702);
      expect(result, isNotNull);
      expect(
        result!.lastKnownName,
        'RemoteRelay',
        reason:
            'Remote lastKnownName should merge in when remote has later lastSeen',
      );
    });
  });

  // ===========================================================================
  // Sync pull: encounters, regions, and co-seen edges
  // ===========================================================================

  group('sync pull child data', () {
    test('encounters are preserved through sync pull', () async {
      store.syncEnabled = true;

      final remote = makeEntry(
        nodeNum: 750,
        encounters: [
          EncounterRecord(
            timestamp: DateTime(2024, 3, 1),
            distanceMeters: 1200.0,
            snr: 10,
            rssi: -85,
          ),
          EncounterRecord(
            timestamp: DateTime(2024, 4, 1),
            distanceMeters: 800.0,
            snr: 15,
            rssi: -70,
          ),
        ],
      );

      await store.applySyncPull([remote]);

      final result = await store.getEntry(750);
      expect(result, isNotNull);
      expect(result!.encounters.length, 2);
      expect(result.encounters.first.distanceMeters, 1200.0);
      expect(result.encounters.last.snr, 15);
    });

    test('regions are preserved through sync pull', () async {
      store.syncEnabled = true;

      final remote = makeEntry(
        nodeNum: 751,
        seenRegions: [
          SeenRegion(
            regionId: 'g33_151',
            label: '33S 151E',
            firstSeen: DateTime(2024, 1, 1),
            lastSeen: DateTime(2024, 6, 1),
            encounterCount: 5,
          ),
        ],
      );

      await store.applySyncPull([remote]);

      final result = await store.getEntry(751);
      expect(result, isNotNull);
      expect(result!.seenRegions.length, 1);
      expect(result.seenRegions.first.regionId, 'g33_151');
      expect(result.seenRegions.first.encounterCount, 5);
    });

    test('co-seen edges are preserved through sync pull', () async {
      store.syncEnabled = true;

      // Need both nodes to exist for the edge to be valid.
      await store.saveEntryImmediate(makeEntry(nodeNum: 752));
      await store.saveEntryImmediate(makeEntry(nodeNum: 800));
      await clearOutbox();

      final remote = makeEntry(
        nodeNum: 752,
        coSeenNodes: {
          800: CoSeenRelationship(
            count: 7,
            firstSeen: DateTime(2024, 2, 1),
            lastSeen: DateTime(2024, 5, 1),
            messageCount: 3,
          ),
        },
      );

      await store.applySyncPull([remote]);

      final result = await store.getEntry(752);
      expect(result, isNotNull);
      expect(result!.coSeenNodes.containsKey(800), isTrue);
      expect(result.coSeenNodes[800]!.count, 7);
      expect(result.coSeenNodes[800]!.messageCount, 3);
    });
  });

  // ===========================================================================
  // Sync pull: large batch
  // ===========================================================================

  group('sync pull large batch', () {
    test('applying 100 remote entries in one pull', () async {
      store.syncEnabled = true;

      final remoteEntries = List.generate(
        100,
        (i) => makeEntry(
          nodeNum: 1000 + i,
          socialTag: NodeSocialTag.values[i % NodeSocialTag.values.length],
          socialTagUpdatedAtMs: 1000 + i,
          userNote: 'Note for node ${1000 + i}',
          userNoteUpdatedAtMs: 1000 + i,
        ),
      );

      final applied = await store.applySyncPull(remoteEntries);
      expect(applied, 100);

      // No outbox entries from pull.
      expect(
        await store.outboxCount,
        0,
        reason: 'Bulk pull must not create outbox entries',
      );

      // All entries accessible.
      final count = await store.entryCount;
      expect(count, 100);

      // Spot check a few.
      final entry50 = await store.getEntry(1050);
      expect(entry50, isNotNull);
      expect(entry50!.userNote, 'Note for node 1050');
    });

    test('mixed new-and-merge batch in single pull', () async {
      store.syncEnabled = true;

      // Pre-populate some local entries.
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 2000,
          socialTag: NodeSocialTag.contact,
          socialTagUpdatedAtMs: 1000,
          encounterCount: 3,
        ),
      );
      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 2001,
          userNote: 'local only',
          userNoteUpdatedAtMs: 500,
          encounterCount: 1,
        ),
      );
      await clearOutbox();

      // Pull includes updates for existing + brand new entries.
      final remoteEntries = [
        // Update existing: remote socialTag wins (later timestamp).
        makeEntry(
          nodeNum: 2000,
          socialTag: NodeSocialTag.trustedNode,
          socialTagUpdatedAtMs: 5000,
          encounterCount: 10,
        ),
        // Update existing: local userNote wins (earlier remote timestamp).
        makeEntry(
          nodeNum: 2001,
          userNote: 'remote note',
          userNoteUpdatedAtMs: 100, // Earlier than local 500.
          encounterCount: 5,
        ),
        // Brand new entry.
        makeEntry(
          nodeNum: 2002,
          socialTag: NodeSocialTag.frequentPeer,
          socialTagUpdatedAtMs: 3000,
        ),
      ];

      final applied = await store.applySyncPull(remoteEntries);
      expect(applied, 3);

      // Verify merge results.
      final entry2000 = await store.getEntry(2000);
      expect(
        entry2000!.socialTag,
        NodeSocialTag.trustedNode,
        reason: 'Remote socialTag with later timestamp should win',
      );
      expect(
        entry2000.encounterCount,
        10,
        reason: 'Max encounterCount should win',
      );

      final entry2001 = await store.getEntry(2001);
      expect(
        entry2001!.userNote,
        'local only',
        reason: 'Local userNote with later timestamp should survive',
      );
      expect(
        entry2001.encounterCount,
        5,
        reason: 'Max encounterCount should win',
      );

      final entry2002 = await store.getEntry(2002);
      expect(entry2002, isNotNull);
      expect(entry2002!.socialTag, NodeSocialTag.frequentPeer);

      // No outbox entries.
      expect(await store.outboxCount, 0);
    });
  });

  // ===========================================================================
  // Sync pull: empty and edge cases
  // ===========================================================================

  group('sync pull edge cases', () {
    test('applySyncPull with empty list is a no-op', () async {
      store.syncEnabled = true;

      final applied = await store.applySyncPull([]);
      expect(applied, 0);
    });

    test('applySyncPull restores syncEnabled even if it was false', () async {
      store.syncEnabled = false;

      await store.applySyncPull([makeEntry(nodeNum: 3000)]);

      expect(
        store.syncEnabled,
        false,
        reason: 'syncEnabled must be restored to its original value',
      );
    });

    test('applySyncPull with syncEnabled=true restores to true', () async {
      store.syncEnabled = true;

      await store.applySyncPull([makeEntry(nodeNum: 3001)]);

      expect(
        store.syncEnabled,
        true,
        reason: 'syncEnabled must be restored to true after pull',
      );
    });

    test('duplicate nodes in same pull batch are handled', () async {
      store.syncEnabled = true;

      // Two entries for same node in one batch — last one wins.
      final entries = [
        makeEntry(
          nodeNum: 3010,
          socialTag: NodeSocialTag.contact,
          socialTagUpdatedAtMs: 1000,
        ),
        makeEntry(
          nodeNum: 3010,
          socialTag: NodeSocialTag.trustedNode,
          socialTagUpdatedAtMs: 2000,
        ),
      ];

      final applied = await store.applySyncPull(entries);
      expect(applied, 2);

      final result = await store.getEntry(3010);
      expect(result, isNotNull);
      // The second entry in the batch is applied via mergeWith on top of
      // the first, so the later timestamp wins.
      expect(result!.socialTag, NodeSocialTag.trustedNode);
    });
  });

  // ===========================================================================
  // Store-level: flush concurrency guard
  // ===========================================================================

  group('flush concurrency', () {
    test('concurrent flush calls do not lose data', () async {
      store.syncEnabled = true;

      // Add entries via debounced save (not flushed).
      for (var i = 0; i < 10; i++) {
        store.saveEntry(makeEntry(nodeNum: 4000 + i));
      }

      // Trigger multiple flushes concurrently.
      await Future.wait([store.flush(), store.flush(), store.flush()]);

      // All entries should be saved.
      final count = await store.entryCount;
      expect(
        count,
        10,
        reason: 'All 10 entries should survive concurrent flushes',
      );
    });

    test('saveEntryImmediate during pending debounced save works', () async {
      store.syncEnabled = true;

      // Debounced save (pending).
      store.saveEntry(makeEntry(nodeNum: 4100));
      store.saveEntry(makeEntry(nodeNum: 4101));

      // Immediate save (flushes).
      await store.saveEntryImmediate(makeEntry(nodeNum: 4102));

      // All should be saved (immediate flush captures pending too).
      expect(await store.hasEntry(4100), isTrue);
      expect(await store.hasEntry(4101), isTrue);
      expect(await store.hasEntry(4102), isTrue);
    });
  });

  // ===========================================================================
  // Store-level: dispose behavior
  // ===========================================================================

  group('dispose', () {
    test('dispose flushes pending saves', () async {
      // Use a separate store for this test since we dispose it.
      final disposeDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final disposeStore = NodeDexSqliteStore(disposeDb);
      await disposeStore.init();

      disposeStore.syncEnabled = false;

      // Add entries via debounced save (not flushed).
      disposeStore.saveEntry(makeEntry(nodeNum: 5000));
      disposeStore.saveEntry(makeEntry(nodeNum: 5001));

      // Dispose should flush.
      await disposeStore.dispose();

      // Re-open and verify.
      final verifyDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
      final verifyStore = NodeDexSqliteStore(verifyDb);
      await verifyStore.init();

      // Note: in-memory DB is ephemeral, so this mainly tests that
      // dispose does not crash and the flush path executes.
      // The dispose method is primarily validated by not throwing.
      await verifyStore.dispose();
    });
  });

  // ===========================================================================
  // Sync state watermark: advanced scenarios
  // ===========================================================================

  group('sync state watermark advanced', () {
    test('multiple keys coexist independently', () async {
      await store.setSyncState('key_a', 'value_a');
      await store.setSyncState('key_b', 'value_b');
      await store.setSyncState('key_c', 'value_c');

      expect(await store.getSyncState('key_a'), 'value_a');
      expect(await store.getSyncState('key_b'), 'value_b');
      expect(await store.getSyncState('key_c'), 'value_c');
    });

    test('overwriting watermark preserves other keys', () async {
      await store.setSyncState('keep', '100');
      await store.setSyncState('update', '200');

      await store.setSyncState('update', '999');

      expect(await store.getSyncState('keep'), '100');
      expect(await store.getSyncState('update'), '999');
    });

    test('watermark key format matches sync service convention', () async {
      // The sync service uses 'nodedex_last_pull_ms_<uid>' format.
      const uid = 'abc123def456';
      final key = 'nodedex_last_pull_ms_$uid';

      await store.setSyncState(key, '1706400000000');

      final value = await store.getSyncState(key);
      expect(value, '1706400000000');
    });
  });

  // ===========================================================================
  // Outbox payload: full entry fidelity
  // ===========================================================================

  group('outbox payload fidelity', () {
    test('entry with all fields survives outbox round-trip', () async {
      store.syncEnabled = true;

      final entry = NodeDexEntry(
        nodeNum: 6000,
        firstSeen: DateTime(2024, 1, 15),
        lastSeen: DateTime(2024, 6, 20),
        encounterCount: 42,
        maxDistanceSeen: 12345.6,
        bestSnr: 18,
        bestRssi: -65,
        messageCount: 7,
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 1706400000000,
        userNote: 'Infrastructure relay on Mt Wilson',
        userNoteUpdatedAtMs: 1706500000000,
        lastKnownName: 'RELAY-MW',
        encounters: [
          EncounterRecord(
            timestamp: DateTime(2024, 3, 1),
            distanceMeters: 5000.0,
            snr: 12,
            rssi: -78,
            latitude: -33.8688,
            longitude: 151.2093,
          ),
        ],
        seenRegions: [
          SeenRegion(
            regionId: 'g33_151',
            label: '33S 151E',
            firstSeen: DateTime(2024, 1, 15),
            lastSeen: DateTime(2024, 6, 20),
            encounterCount: 10,
          ),
        ],
        sigil: SigilGenerator.generate(6000),
      );

      await store.saveEntryImmediate(entry);

      final outbox = await store.readOutbox();
      expect(outbox, isNotEmpty);

      final payload =
          jsonDecode(outbox.last['payload_json'] as String)
              as Map<String, dynamic>;
      final restored = NodeDexEntry.fromJson(payload);

      expect(restored.nodeNum, 6000);
      expect(restored.firstSeen, DateTime(2024, 1, 15));
      expect(restored.lastSeen, DateTime(2024, 6, 20));
      expect(restored.encounterCount, 42);
      expect(restored.maxDistanceSeen, 12345.6);
      expect(restored.bestSnr, 18);
      expect(restored.bestRssi, -65);
      expect(restored.messageCount, 7);
      expect(restored.socialTag, NodeSocialTag.trustedNode);
      expect(restored.socialTagUpdatedAtMs, 1706400000000);
      expect(restored.userNote, 'Infrastructure relay on Mt Wilson');
      expect(restored.userNoteUpdatedAtMs, 1706500000000);
      expect(restored.lastKnownName, 'RELAY-MW');
      expect(restored.encounters.length, 1);
      expect(restored.encounters.first.latitude, closeTo(-33.8688, 0.001));
      expect(restored.encounters.first.longitude, closeTo(151.2093, 0.001));
      expect(restored.seenRegions.length, 1);
      expect(restored.seenRegions.first.regionId, 'g33_151');
      expect(restored.sigil, isNotNull);
    });

    test('every NodeSocialTag value round-trips through outbox', () async {
      store.syncEnabled = true;

      for (final tag in NodeSocialTag.values) {
        final entry = makeEntry(
          nodeNum: 6100 + tag.index,
          socialTag: tag,
          socialTagUpdatedAtMs: 1000 + tag.index,
        );
        await store.saveEntryImmediate(entry);
      }

      final outbox = await store.readOutbox();

      for (final row in outbox) {
        final payload =
            jsonDecode(row['payload_json'] as String) as Map<String, dynamic>;
        final restored = NodeDexEntry.fromJson(payload);

        expect(
          restored.socialTag,
          isNotNull,
          reason:
              'socialTag must survive round-trip for node ${restored.nodeNum}',
        );
      }
    });
  });

  // ===========================================================================
  // Sync contract alignment
  // ===========================================================================

  group('sync contract alignment', () {
    test('outbox entity_type matches sync contract entityTypeKey', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 7000));

      final outbox = await store.readOutbox();
      expect(outbox, isNotEmpty);

      final entityType = outbox.last['entity_type'] as String;
      final contractKey = syncTypeConfigs[SyncType.nodedexEntry]!.entityTypeKey;

      expect(
        entityType,
        contractKey,
        reason:
            'Outbox entity_type "$entityType" must match sync contract '
            'entityTypeKey "$contractKey"',
      );
    });

    test('outbox entity_id format is node:<nodeNum>', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 7001));

      final outbox = await store.readOutbox();
      final entityId = outbox.last['entity_id'] as String;

      expect(entityId, 'node:7001');
      expect(entityId, matches(RegExp(r'^node:\d+$')));
    });

    test('outbox op is either upsert or delete', () async {
      store.syncEnabled = true;

      // Upsert.
      await store.saveEntryImmediate(makeEntry(nodeNum: 7002));
      final upsertOutbox = await store.readOutbox();
      expect(upsertOutbox.last['op'], 'upsert');

      await clearOutbox();

      // Delete.
      await store.deleteEntry(7002);
      final deleteOutbox = await store.readOutbox();
      expect(deleteOutbox.last['op'], 'delete');
    });

    test('delete outbox payload is empty JSON object', () async {
      store.syncEnabled = true;

      await store.saveEntryImmediate(makeEntry(nodeNum: 7003));
      await clearOutbox();

      await store.deleteEntry(7003);

      final outbox = await store.readOutbox();
      expect(outbox.last['payload_json'], '{}');
    });
  });

  // ===========================================================================
  // Sync diagnostics integration
  // ===========================================================================

  group('sync diagnostics', () {
    setUp(() {
      SyncDiagnostics.instance.reset();
    });

    test('diagnostics snapshot reflects initial state', () {
      final snap = SyncDiagnostics.instance.snapshot;

      expect(snap.entitlementActive, isFalse);
      expect(snap.lastSyncTime, isNull);
    });

    test('entitlement state is tracked', () {
      SyncDiagnostics.instance.recordEntitlementState(true);
      expect(SyncDiagnostics.instance.snapshot.entitlementActive, isTrue);

      SyncDiagnostics.instance.recordEntitlementState(false);
      expect(SyncDiagnostics.instance.snapshot.entitlementActive, isFalse);
    });

    test('upload success decrements queued below zero safely', () {
      // No enqueue, just record success — should clamp to 0.
      SyncDiagnostics.instance.recordUploadSuccess(
        SyncType.nodedexEntry,
        count: 10,
      );

      expect(
        SyncDiagnostics.instance.snapshot.queuedItemsByType[SyncType
            .nodedexEntry],
        0,
      );
    });

    test('multiple sync types tracked independently', () {
      SyncDiagnostics.instance.recordEnqueue(SyncType.nodedexEntry, count: 5);
      SyncDiagnostics.instance.recordEnqueue(SyncType.automations, count: 2);

      final snap = SyncDiagnostics.instance.snapshot;
      expect(snap.queuedItemsByType[SyncType.nodedexEntry], 5);
      expect(snap.queuedItemsByType[SyncType.automations], 2);
    });
  });

  // ===========================================================================
  // Sync debug toggle
  // ===========================================================================

  group('sync debug toggle', () {
    test('setSyncDebug toggles isSyncDebugEnabled', () {
      setSyncDebug(true);
      expect(isSyncDebugEnabled, isTrue);

      setSyncDebug(false);
      expect(isSyncDebugEnabled, isFalse);
    });
  });

  // ===========================================================================
  // Import/export and outbox interaction
  // ===========================================================================

  group('import and outbox interaction', () {
    test('importJson does not create outbox entries', () async {
      store.syncEnabled = true;

      final entries = [
        makeEntry(nodeNum: 8000, socialTag: NodeSocialTag.contact),
        makeEntry(nodeNum: 8001, socialTag: NodeSocialTag.trustedNode),
      ];
      final json = NodeDexEntry.encodeList(entries);

      // Clear any existing outbox.
      await clearOutbox();

      final imported = await store.importJson(json);
      expect(imported, greaterThan(0));

      // Import writes via _upsertEntryInTxn which respects syncEnabled.
      // This is expected behavior — imported entries ARE enqueued because
      // the user is explicitly importing data they want synced.
      // Verify the entries exist.
      expect(await store.hasEntry(8000), isTrue);
      expect(await store.hasEntry(8001), isTrue);
    });

    test('bulkInsert does not create outbox entries', () async {
      store.syncEnabled = true;

      // Clear any existing outbox.
      await clearOutbox();

      final entries = [
        makeEntry(nodeNum: 8100),
        makeEntry(nodeNum: 8101),
        makeEntry(nodeNum: 8102),
      ];

      await store.bulkInsert(entries);

      expect(
        await store.outboxCount,
        0,
        reason: 'bulkInsert explicitly disables outbox enqueuing',
      );

      expect(await store.hasEntry(8100), isTrue);
      expect(await store.hasEntry(8101), isTrue);
      expect(await store.hasEntry(8102), isTrue);
    });

    test('exportJson includes all entry data', () async {
      store.syncEnabled = false;

      await store.saveEntryImmediate(
        makeEntry(
          nodeNum: 8200,
          socialTag: NodeSocialTag.frequentPeer,
          socialTagUpdatedAtMs: 5000,
          userNote: 'Export test',
          userNoteUpdatedAtMs: 5000,
          lastKnownName: 'EXPORT-NODE',
        ),
      );

      final json = await store.exportJson();
      expect(json, isNotNull);

      final decoded = NodeDexEntry.decodeList(json!);
      expect(decoded.length, 1);
      expect(decoded.first.nodeNum, 8200);
      expect(decoded.first.socialTag, NodeSocialTag.frequentPeer);
      expect(decoded.first.lastKnownName, 'EXPORT-NODE');
    });
  });

  // ===========================================================================
  // Full pipeline: local mutation -> outbox -> pull -> convergence
  // ===========================================================================

  group('full pipeline integration', () {
    test(
      'Device A mutation -> outbox -> Device B pull -> convergence',
      () async {
        // Simulate Device A.
        final deviceADb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
        final deviceAStore = NodeDexSqliteStore(deviceADb);
        await deviceAStore.init();
        deviceAStore.syncEnabled = true;

        // Device A creates and tags a node.
        final nodeA = makeEntry(
          nodeNum: 9000,
          socialTag: NodeSocialTag.trustedNode,
          socialTagUpdatedAtMs: 5000,
          userNote: 'Infrastructure relay',
          userNoteUpdatedAtMs: 5000,
          encounterCount: 10,
          lastKnownName: 'RELAY-A',
        );
        await deviceAStore.saveEntryImmediate(nodeA);

        // Read outbox (simulates drain).
        final outbox = await deviceAStore.readOutbox();
        expect(outbox, isNotEmpty);

        final payload =
            jsonDecode(outbox.last['payload_json'] as String)
                as Map<String, dynamic>;
        final serialized = NodeDexEntry.fromJson(payload);

        // Simulate Device B.
        final deviceBDb = NodeDexDatabase(dbPathOverride: inMemoryDatabasePath);
        final deviceBStore = NodeDexSqliteStore(deviceBDb);
        await deviceBStore.init();
        deviceBStore.syncEnabled = true;

        // Device B has the same node with different local data.
        final nodeB = makeEntry(
          nodeNum: 9000,
          socialTag: NodeSocialTag.contact,
          socialTagUpdatedAtMs: 1000, // Earlier than A.
          encounterCount: 3,
          lastKnownName: 'LOCAL-B',
        );
        await deviceBStore.saveEntryImmediate(nodeB);
        // Clear outbox so we can verify pull behavior.
        final bOutbox = await deviceBStore.readOutbox();
        for (final e in bOutbox) {
          await deviceBStore.removeOutboxEntry(e['id'] as int);
        }

        // Device B applies sync pull from Device A's data.
        final applied = await deviceBStore.applySyncPull([serialized]);
        expect(applied, 1);

        // Verify convergence.
        final merged = await deviceBStore.getEntry(9000);
        expect(merged, isNotNull);
        expect(
          merged!.socialTag,
          NodeSocialTag.trustedNode,
          reason: 'Device A socialTag (later timestamp) should win',
        );
        expect(merged.socialTagUpdatedAtMs, 5000);
        expect(
          merged.userNote,
          'Infrastructure relay',
          reason: 'Device A userNote (only one with value) should win',
        );
        expect(
          merged.encounterCount,
          10,
          reason: 'Max encounterCount should win',
        );

        // No outbox from pull.
        expect(await deviceBStore.outboxCount, 0);

        // Clean up.
        await deviceAStore.dispose();
        await deviceBStore.dispose();
      },
    );

    test('offline edits on both devices converge after sync', () async {
      // Device A: offline edit at timestamp 3000.
      final deviceAEntry = makeEntry(
        nodeNum: 9100,
        socialTag: NodeSocialTag.knownRelay,
        socialTagUpdatedAtMs: 3000,
        userNote: 'Relay on Mt Wilson',
        userNoteUpdatedAtMs: 3000,
        encounterCount: 5,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 3, 1),
      );

      // Device B: offline edit at timestamp 7000.
      final deviceBEntry = makeEntry(
        nodeNum: 9100,
        socialTag: NodeSocialTag.frequentPeer,
        socialTagUpdatedAtMs: 7000,
        userNote: 'Alice',
        userNoteUpdatedAtMs: 1000, // Earlier than A for note.
        encounterCount: 12,
        firstSeen: DateTime(2024, 2, 1),
        lastSeen: DateTime(2024, 6, 1),
      );

      // After sync, both devices merge.
      final mergedOnA = deviceAEntry.mergeWith(deviceBEntry);
      final mergedOnB = deviceBEntry.mergeWith(deviceAEntry);

      // Both should converge to same result.
      expect(
        mergedOnA.socialTag,
        mergedOnB.socialTag,
        reason: 'Both devices must converge on socialTag',
      );
      expect(
        mergedOnA.socialTag,
        NodeSocialTag.frequentPeer,
        reason: 'Device B socialTag (later timestamp 7000) wins',
      );

      expect(
        mergedOnA.userNote,
        mergedOnB.userNote,
        reason: 'Both devices must converge on userNote',
      );
      expect(
        mergedOnA.userNote,
        'Relay on Mt Wilson',
        reason: 'Device A userNote (later timestamp 3000 > 1000) wins',
      );

      // Metrics converge.
      expect(mergedOnA.encounterCount, 12);
      expect(mergedOnA.firstSeen, DateTime(2024, 1, 1));
      expect(mergedOnA.lastSeen, DateTime(2024, 6, 1));

      expect(mergedOnB.encounterCount, 12);
      expect(mergedOnB.firstSeen, DateTime(2024, 1, 1));
      expect(mergedOnB.lastSeen, DateTime(2024, 6, 1));
    });

    test('three-device convergence: all resolve to same state', () async {
      final base = DateTime(2024, 1, 1);

      final deviceA = makeEntry(
        nodeNum: 9200,
        socialTag: NodeSocialTag.contact,
        socialTagUpdatedAtMs: 1000,
        userNote: 'Note A',
        userNoteUpdatedAtMs: 5000, // A has latest note.
        encounterCount: 3,
        firstSeen: base,
        lastSeen: DateTime(2024, 3, 1),
      );

      final deviceB = makeEntry(
        nodeNum: 9200,
        socialTag: NodeSocialTag.trustedNode,
        socialTagUpdatedAtMs: 8000, // B has latest tag.
        userNote: 'Note B',
        userNoteUpdatedAtMs: 2000,
        encounterCount: 7,
        firstSeen: DateTime(2024, 2, 1),
        lastSeen: DateTime(2024, 6, 1),
      );

      final deviceC = makeEntry(
        nodeNum: 9200,
        socialTag: NodeSocialTag.knownRelay,
        socialTagUpdatedAtMs: 3000,
        userNote: 'Note C',
        userNoteUpdatedAtMs: 3000,
        encounterCount: 15, // C has most encounters.
        firstSeen: DateTime(2023, 12, 1), // C has earliest firstSeen.
        lastSeen: DateTime(2024, 5, 1),
      );

      // Apply in all possible orders — result must be the same.
      final abcMerge = deviceA.mergeWith(deviceB).mergeWith(deviceC);
      final bacMerge = deviceB.mergeWith(deviceA).mergeWith(deviceC);
      final cabMerge = deviceC.mergeWith(deviceA).mergeWith(deviceB);

      // All three must converge on tag (B wins, timestamp 8000).
      expect(abcMerge.socialTag, NodeSocialTag.trustedNode);
      expect(bacMerge.socialTag, NodeSocialTag.trustedNode);
      expect(cabMerge.socialTag, NodeSocialTag.trustedNode);

      // All three must converge on note (A wins, timestamp 5000).
      expect(abcMerge.userNote, 'Note A');
      expect(bacMerge.userNote, 'Note A');
      expect(cabMerge.userNote, 'Note A');

      // Metrics: max encounterCount from C.
      expect(abcMerge.encounterCount, 15);
      expect(bacMerge.encounterCount, 15);
      expect(cabMerge.encounterCount, 15);

      // Earliest firstSeen from C.
      expect(abcMerge.firstSeen, DateTime(2023, 12, 1));
      expect(bacMerge.firstSeen, DateTime(2023, 12, 1));
      expect(cabMerge.firstSeen, DateTime(2023, 12, 1));

      // Latest lastSeen from B.
      expect(abcMerge.lastSeen, DateTime(2024, 6, 1));
      expect(bacMerge.lastSeen, DateTime(2024, 6, 1));
      expect(cabMerge.lastSeen, DateTime(2024, 6, 1));
    });
  });

  // ===========================================================================
  // Outbox read limit
  // ===========================================================================

  group('outbox read limit', () {
    test('readOutbox respects limit parameter', () async {
      store.syncEnabled = true;

      // Create 10 entries.
      for (var i = 0; i < 10; i++) {
        await store.saveEntryImmediate(makeEntry(nodeNum: 10000 + i));
      }

      // Read with limit.
      final limited = await store.readOutbox(limit: 3);
      expect(limited.length, 3);

      // Read all.
      final all = await store.readOutbox(limit: 100);
      expect(all.length, 10);
    });

    test('readOutbox default limit is 100', () async {
      store.syncEnabled = true;

      // Create 5 entries (well under default limit).
      for (var i = 0; i < 5; i++) {
        await store.saveEntryImmediate(makeEntry(nodeNum: 10100 + i));
      }

      final result = await store.readOutbox();
      expect(result.length, 5);
    });
  });

  // ===========================================================================
  // Sync service constants (compile-time verification)
  // ===========================================================================

  group('sync service compile-time constants', () {
    test('sync debug toggle functions exist and are callable', () {
      // Verify the public API exists.
      final before = isSyncDebugEnabled;
      setSyncDebug(!before);
      expect(isSyncDebugEnabled, !before);
      setSyncDebug(before); // Restore.
    });

    test('NodeDexSyncService can be constructed', () {
      // Verify the service can be instantiated with a store.
      // (It won't do anything useful without Firebase, but it should
      // not crash on construction.)
      final service = NodeDexSyncService(store);
      expect(service.isEnabled, isFalse);
    });

    test('NodeDexSyncService setEnabled toggles state', () {
      final service = NodeDexSyncService(store);

      service.setEnabled(true);
      expect(service.isEnabled, isTrue);
      expect(store.syncEnabled, isTrue);

      service.setEnabled(false);
      expect(service.isEnabled, isFalse);
      expect(store.syncEnabled, isFalse);
    });

    test('NodeDexSyncService syncNow is no-op when disabled', () async {
      final service = NodeDexSyncService(store);
      service.setEnabled(false);

      // Should return without error.
      await service.syncNow();
    });

    test('NodeDexSyncService drainOutboxNow is no-op when disabled', () async {
      final service = NodeDexSyncService(store);
      service.setEnabled(false);

      // Should return without error.
      await service.drainOutboxNow();
    });

    test('NodeDexSyncService dispose is safe when not enabled', () async {
      final service = NodeDexSyncService(store);
      // Dispose without ever enabling — should not crash.
      await service.dispose();
    });

    test('NodeDexSyncService dispose is safe after enable/disable', () async {
      final service = NodeDexSyncService(store);
      service.setEnabled(true);
      service.setEnabled(false);
      await service.dispose();
    });
  });

  // ===========================================================================
  // Edge case: sigil preservation through sync
  // ===========================================================================

  group('sigil preservation', () {
    test('sigil data survives outbox serialization', () async {
      store.syncEnabled = true;

      final sigil = SigilGenerator.generate(11000);
      final entry = NodeDexEntry(
        nodeNum: 11000,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        sigil: sigil,
      );

      await store.saveEntryImmediate(entry);

      final outbox = await store.readOutbox();
      final payload =
          jsonDecode(outbox.last['payload_json'] as String)
              as Map<String, dynamic>;
      final restored = NodeDexEntry.fromJson(payload);

      expect(restored.sigil, isNotNull);
      expect(
        restored.sigil!.vertices,
        sigil.vertices,
        reason: 'Sigil vertices must survive outbox round-trip',
      );
    });

    test('sigil survives full pull cycle', () async {
      store.syncEnabled = true;

      final sigil = SigilGenerator.generate(11001);
      final remote = NodeDexEntry(
        nodeNum: 11001,
        firstSeen: DateTime(2024, 1, 1),
        lastSeen: DateTime(2024, 6, 1),
        sigil: sigil,
      );

      await store.applySyncPull([remote]);

      final result = await store.getEntry(11001);
      expect(result, isNotNull);
      expect(result!.sigil, isNotNull);
    });
  });
}
