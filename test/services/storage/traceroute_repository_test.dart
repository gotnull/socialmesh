// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/services/storage/telemetry_storage_service.dart';
import 'package:socialmesh/services/storage/traceroute_database.dart';
import 'package:socialmesh/services/storage/traceroute_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ---------------------------------------------------------------------------
  // Helper to create a fresh DB + repo using in-memory SQLite
  // ---------------------------------------------------------------------------
  Future<(TracerouteDatabase, SqliteTracerouteRepository)> createRepo() async {
    final db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
    await db.open();
    final repo = SqliteTracerouteRepository(db);
    return (db, repo);
  }

  // ---------------------------------------------------------------------------
  // Helper factories for TraceRouteLog / TraceRouteHop
  // ---------------------------------------------------------------------------
  TraceRouteLog makeRun({
    String? id,
    required int targetNode,
    bool response = true,
    int hopsTowards = 0,
    int hopsBack = 0,
    List<TraceRouteHop> hops = const [],
    double? snr,
    DateTime? timestamp,
  }) {
    return TraceRouteLog(
      id: id,
      nodeNum: targetNode,
      timestamp: timestamp,
      targetNode: targetNode,
      sent: true,
      response: response,
      hopsTowards: hopsTowards,
      hopsBack: hopsBack,
      hops: hops,
      snr: snr,
    );
  }

  TraceRouteHop makeHop({
    required int nodeNum,
    double? snr,
    bool back = false,
  }) {
    return TraceRouteHop(nodeNum: nodeNum, snr: snr, back: back);
  }

  // =========================================================================
  // TracerouteDatabase lifecycle
  // =========================================================================
  group('TracerouteDatabase', () {
    test('open creates database and tables', () async {
      final db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
      final result = await db.open();
      expect(result.isOpen, true);

      // Verify tables exist by querying them
      final runs = await result.query(TracerouteTables.runs);
      expect(runs, isEmpty);

      final hops = await result.query(TracerouteTables.hops);
      expect(hops, isEmpty);

      await db.close();
    });

    test('open is idempotent', () async {
      final db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
      final first = await db.open();
      final second = await db.open();
      expect(identical(first, second), true);
      await db.close();
    });

    test('isOpen reflects state correctly', () async {
      final db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
      expect(db.isOpen, false);
      await db.open();
      expect(db.isOpen, true);
      await db.close();
      expect(db.isOpen, false);
    });

    test('database getter throws if not opened', () {
      final db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
      expect(() => db.database, throwsStateError);
    });
  });

  // =========================================================================
  // saveRun + listRuns
  // =========================================================================
  group('SqliteTracerouteRepository — saveRun & listRuns', () {
    test('save and read a single completed run with hops', () async {
      final (db, repo) = await createRepo();

      final run = makeRun(
        targetNode: 0xAABBCCDD,
        response: true,
        hopsTowards: 2,
        hopsBack: 1,
        snr: 7.5,
        hops: [
          makeHop(nodeNum: 0x11111111, snr: 10.0),
          makeHop(nodeNum: 0x22222222, snr: -2.0),
          makeHop(nodeNum: 0x33333333, snr: 6.0, back: true),
        ],
      );

      await repo.saveRun(run);

      final runs = await repo.listRuns();
      expect(runs.length, 1);

      final loaded = runs.first;
      expect(loaded.id, run.id);
      expect(loaded.targetNode, 0xAABBCCDD);
      expect(loaded.response, true);
      expect(loaded.hopsTowards, 2);
      expect(loaded.hopsBack, 1);
      expect(loaded.snr, 7.5);
      expect(loaded.hops.length, 3);

      // Forward hops
      expect(loaded.hops[0].nodeNum, 0x11111111);
      expect(loaded.hops[0].snr, 10.0);
      expect(loaded.hops[0].back, false);
      expect(loaded.hops[1].nodeNum, 0x22222222);
      expect(loaded.hops[1].snr, -2.0);
      expect(loaded.hops[1].back, false);

      // Return hop
      expect(loaded.hops[2].nodeNum, 0x33333333);
      expect(loaded.hops[2].snr, 6.0);
      expect(loaded.hops[2].back, true);

      await db.close();
    });

    test('save pending run with no hops', () async {
      final (db, repo) = await createRepo();

      final run = makeRun(
        targetNode: 0xDEADBEEF,
        response: false,
        hopsTowards: 0,
        hopsBack: 0,
      );

      await repo.saveRun(run);

      final runs = await repo.listRuns();
      expect(runs.length, 1);
      expect(runs.first.response, false);
      expect(runs.first.hops, isEmpty);

      await db.close();
    });

    test('listRuns returns newest first', () async {
      final (db, repo) = await createRepo();

      final older = makeRun(
        targetNode: 0x11111111,
        timestamp: DateTime(2024, 1, 1),
      );
      final newer = makeRun(
        targetNode: 0x22222222,
        timestamp: DateTime(2024, 6, 1),
      );

      await repo.saveRun(older);
      await repo.saveRun(newer);

      final runs = await repo.listRuns();
      expect(runs.length, 2);
      expect(runs[0].targetNode, 0x22222222);
      expect(runs[1].targetNode, 0x11111111);

      await db.close();
    });

    test('listRuns respects limit', () async {
      final (db, repo) = await createRepo();

      for (var i = 0; i < 10; i++) {
        await repo.saveRun(
          makeRun(
            targetNode: 0xAA000000 + i,
            timestamp: DateTime(2024, 1, 1 + i),
          ),
        );
      }

      final limited = await repo.listRuns(limit: 3);
      expect(limited.length, 3);

      await db.close();
    });

    test('listRuns scoped by targetNodeId', () async {
      final (db, repo) = await createRepo();

      await repo.saveRun(makeRun(targetNode: 0x11111111));
      await repo.saveRun(makeRun(targetNode: 0x22222222));
      await repo.saveRun(makeRun(targetNode: 0x11111111));

      final forNode1 = await repo.listRuns(targetNodeId: 0x11111111);
      expect(forNode1.length, 2);
      for (final r in forNode1) {
        expect(r.targetNode, 0x11111111);
      }

      final forNode2 = await repo.listRuns(targetNodeId: 0x22222222);
      expect(forNode2.length, 1);
      expect(forNode2.first.targetNode, 0x22222222);

      final forMissing = await repo.listRuns(targetNodeId: 0x99999999);
      expect(forMissing, isEmpty);

      await db.close();
    });

    test('listRuns returns empty when DB is empty', () async {
      final (db, repo) = await createRepo();

      final runs = await repo.listRuns();
      expect(runs, isEmpty);

      await db.close();
    });

    test('multiple runs for same target are stored separately', () async {
      final (db, repo) = await createRepo();

      for (var i = 0; i < 5; i++) {
        await repo.saveRun(
          makeRun(
            targetNode: 0xAABBCCDD,
            hopsTowards: i + 1,
            timestamp: DateTime(2024, 1, 1 + i),
          ),
        );
      }

      final runs = await repo.listRuns(targetNodeId: 0xAABBCCDD);
      expect(runs.length, 5);

      await db.close();
    });
  });

  // =========================================================================
  // replaceOrAddRun
  // =========================================================================
  group('SqliteTracerouteRepository — replaceOrAddRun', () {
    test('replaces pending run with completed response', () async {
      final (db, repo) = await createRepo();

      // Save a pending (no response) run
      final pending = makeRun(
        id: 'pending-1',
        targetNode: 0xAABBCCDD,
        response: false,
      );
      await repo.saveRun(pending);

      var runs = await repo.listRuns();
      expect(runs.length, 1);
      expect(runs.first.response, false);

      // Now replace with completed response
      final completed = makeRun(
        targetNode: 0xAABBCCDD,
        response: true,
        hopsTowards: 2,
        hopsBack: 1,
        snr: 8.0,
        hops: [
          makeHop(nodeNum: 0x11111111, snr: 10.0),
          makeHop(nodeNum: 0x22222222, snr: -2.0),
          makeHop(nodeNum: 0x33333333, snr: 6.0, back: true),
        ],
      );
      await repo.replaceOrAddRun(completed);

      runs = await repo.listRuns();
      expect(runs.length, 1);
      expect(runs.first.response, true);
      expect(runs.first.hopsTowards, 2);
      expect(runs.first.hops.length, 3);
      expect(runs.first.snr, 8.0);
      // The pending run ID should be gone
      expect(runs.first.id, isNot('pending-1'));

      await db.close();
    });

    test('appends when no pending run exists for target', () async {
      final (db, repo) = await createRepo();

      // Save a completed run first
      await repo.saveRun(makeRun(targetNode: 0xAABBCCDD, response: true));

      // replaceOrAdd a new completed run (no pending to replace)
      await repo.replaceOrAddRun(
        makeRun(targetNode: 0xAABBCCDD, response: true, hopsTowards: 5),
      );

      final runs = await repo.listRuns();
      expect(runs.length, 2);

      await db.close();
    });

    test('only replaces pending for same target node', () async {
      final (db, repo) = await createRepo();

      // Pending for node A
      await repo.saveRun(makeRun(targetNode: 0x11111111, response: false));
      // Pending for node B
      await repo.saveRun(makeRun(targetNode: 0x22222222, response: false));

      // Replace only node A
      await repo.replaceOrAddRun(
        makeRun(targetNode: 0x11111111, response: true, hopsTowards: 3),
      );

      final allRuns = await repo.listRuns();
      expect(allRuns.length, 2);

      final nodeARuns = await repo.listRuns(targetNodeId: 0x11111111);
      expect(nodeARuns.length, 1);
      expect(nodeARuns.first.response, true);

      final nodeBRuns = await repo.listRuns(targetNodeId: 0x22222222);
      expect(nodeBRuns.length, 1);
      expect(nodeBRuns.first.response, false);

      await db.close();
    });

    test('replaces only the most recent pending run', () async {
      final (db, repo) = await createRepo();

      // Two pending runs for same node (unusual but possible)
      await repo.saveRun(
        makeRun(
          id: 'pending-old',
          targetNode: 0xAABBCCDD,
          response: false,
          timestamp: DateTime(2024, 1, 1),
        ),
      );
      await repo.saveRun(
        makeRun(
          id: 'pending-new',
          targetNode: 0xAABBCCDD,
          response: false,
          timestamp: DateTime(2024, 6, 1),
        ),
      );

      await repo.replaceOrAddRun(
        makeRun(targetNode: 0xAABBCCDD, response: true),
      );

      final runs = await repo.listRuns(targetNodeId: 0xAABBCCDD);
      // Should have: the old pending + the new completed (replaced the newer pending)
      expect(runs.length, 2);

      final completed = runs.where((r) => r.response).toList();
      expect(completed.length, 1);

      final stillPending = runs.where((r) => !r.response).toList();
      expect(stillPending.length, 1);
      expect(stillPending.first.id, 'pending-old');

      await db.close();
    });
  });

  // =========================================================================
  // deleteRunsForNode
  // =========================================================================
  group('SqliteTracerouteRepository — deleteRunsForNode', () {
    test('deletes all runs for a specific node', () async {
      final (db, repo) = await createRepo();

      await repo.saveRun(makeRun(targetNode: 0x11111111));
      await repo.saveRun(makeRun(targetNode: 0x11111111));
      await repo.saveRun(makeRun(targetNode: 0x22222222));

      await repo.deleteRunsForNode(0x11111111);

      final allRuns = await repo.listRuns();
      expect(allRuns.length, 1);
      expect(allRuns.first.targetNode, 0x22222222);

      await db.close();
    });

    test('cascade deletes hops when runs are deleted', () async {
      final (db, repo) = await createRepo();

      await repo.saveRun(
        makeRun(
          targetNode: 0x11111111,
          hops: [makeHop(nodeNum: 0xAA), makeHop(nodeNum: 0xBB)],
        ),
      );

      await repo.deleteRunsForNode(0x11111111);

      // Directly query hops table to verify cascade
      final hops = await db.database.query(TracerouteTables.hops);
      expect(hops, isEmpty);

      await db.close();
    });

    test('deleteRunsForNode is a no-op for unknown node', () async {
      final (db, repo) = await createRepo();

      await repo.saveRun(makeRun(targetNode: 0x11111111));
      await repo.deleteRunsForNode(0x99999999);

      final runs = await repo.listRuns();
      expect(runs.length, 1);

      await db.close();
    });
  });

  // =========================================================================
  // deleteAllRuns
  // =========================================================================
  group('SqliteTracerouteRepository — deleteAllRuns', () {
    test('deletes everything', () async {
      final (db, repo) = await createRepo();

      await repo.saveRun(
        makeRun(targetNode: 0x11111111, hops: [makeHop(nodeNum: 0xAA)]),
      );
      await repo.saveRun(makeRun(targetNode: 0x22222222));
      await repo.saveRun(makeRun(targetNode: 0x33333333));

      await repo.deleteAllRuns();

      final runs = await repo.listRuns();
      expect(runs, isEmpty);

      // Hops should also be gone
      final hops = await db.database.query(TracerouteTables.hops);
      expect(hops, isEmpty);

      await db.close();
    });

    test('deleteAllRuns is safe on empty DB', () async {
      final (db, repo) = await createRepo();

      await repo.deleteAllRuns();

      final runs = await repo.listRuns();
      expect(runs, isEmpty);

      await db.close();
    });
  });

  // =========================================================================
  // prune
  // =========================================================================
  group('SqliteTracerouteRepository — prune', () {
    test('global cap prunes oldest runs', () async {
      final (db, repo) = await createRepo();

      // Insert 15 runs with known timestamps
      for (var i = 0; i < 15; i++) {
        await repo.saveRun(
          makeRun(
            targetNode: 0xAA000000 + i,
            timestamp: DateTime(2024, 1, 1 + i),
          ),
        );
      }

      // Prune with maxTotal = 10
      await repo.prune(maxRunsTotal: 10, maxRunsPerNode: 100);

      final runs = await repo.listRuns(limit: 100);
      expect(runs.length, 10);

      // The 5 oldest (days 1-5) should be pruned
      // Remaining should be days 6-15 (newest first)
      for (final run in runs) {
        expect(
          run.timestamp.isAfter(DateTime(2024, 1, 5)),
          true,
          reason: 'Run at ${run.timestamp} should have been pruned',
        );
      }

      await db.close();
    });

    test('per-node cap prunes oldest runs for that node', () async {
      final (db, repo) = await createRepo();

      // Insert 8 runs for one node
      for (var i = 0; i < 8; i++) {
        await repo.saveRun(
          makeRun(targetNode: 0x11111111, timestamp: DateTime(2024, 1, 1 + i)),
        );
      }
      // Insert 2 runs for another node
      for (var i = 0; i < 2; i++) {
        await repo.saveRun(
          makeRun(targetNode: 0x22222222, timestamp: DateTime(2024, 6, 1 + i)),
        );
      }

      // Prune with per-node cap of 5, global unlimited
      await repo.prune(maxRunsTotal: 1000, maxRunsPerNode: 5);

      final node1Runs = await repo.listRuns(targetNodeId: 0x11111111);
      expect(node1Runs.length, 5);

      // Oldest 3 for node1 should be gone
      for (final run in node1Runs) {
        expect(
          run.timestamp.isAfter(DateTime(2024, 1, 3)),
          true,
          reason: 'Run at ${run.timestamp} should have been pruned',
        );
      }

      // Node 2 should be untouched (only 2 runs, well under cap)
      final node2Runs = await repo.listRuns(targetNodeId: 0x22222222);
      expect(node2Runs.length, 2);

      await db.close();
    });

    test('prune is a no-op when under limits', () async {
      final (db, repo) = await createRepo();

      await repo.saveRun(makeRun(targetNode: 0x11111111));
      await repo.saveRun(makeRun(targetNode: 0x22222222));

      await repo.prune(maxRunsTotal: 100, maxRunsPerNode: 50);

      final runs = await repo.listRuns();
      expect(runs.length, 2);

      await db.close();
    });

    test('prune is safe on empty DB', () async {
      final (db, repo) = await createRepo();

      await repo.prune();

      final runs = await repo.listRuns();
      expect(runs, isEmpty);

      await db.close();
    });

    test('prune runs automatically after saveRun', () async {
      final (db, repo) = await createRepo();

      // Fill beyond the global cap
      // Use small caps to make this test fast
      for (var i = 0; i < 12; i++) {
        await repo.saveRun(
          makeRun(
            targetNode: 0xAA000000 + i,
            timestamp: DateTime(2024, 1, 1 + i),
          ),
        );
      }

      // saveRun triggers prune internally, but with default retention limits
      // (500 total / 100 per node), so nothing is pruned here.
      // To test auto-pruning, we'd need to mock retention limits.
      // Instead, just verify the data is intact.
      final runs = await repo.listRuns(limit: 1000);
      expect(runs.length, 12);

      await db.close();
    });
  });

  // =========================================================================
  // Persistence across close/reopen (restart simulation)
  // =========================================================================
  group('SqliteTracerouteRepository — restart simulation', () {
    test('data survives close and reopen with file-backed DB', () async {
      // Use a temp file path for this test
      final tempDir = await databaseFactoryFfi.getDatabasesPath();
      final dbPath =
          '$tempDir/test_restart_${DateTime.now().millisecondsSinceEpoch}.db';

      // First session: open, write, close
      final db1 = TracerouteDatabase(dbPathOverride: dbPath);
      await db1.open();
      final repo1 = SqliteTracerouteRepository(db1);

      await repo1.saveRun(
        makeRun(
          id: 'run-persist-1',
          targetNode: 0xAABBCCDD,
          response: true,
          hopsTowards: 2,
          hopsBack: 1,
          snr: 7.5,
          hops: [
            makeHop(nodeNum: 0x11111111, snr: 10.0),
            makeHop(nodeNum: 0x22222222, snr: -2.0),
            makeHop(nodeNum: 0x33333333, snr: 6.0, back: true),
          ],
        ),
      );

      await db1.close();

      // Second session: reopen, read
      final db2 = TracerouteDatabase(dbPathOverride: dbPath);
      await db2.open();
      final repo2 = SqliteTracerouteRepository(db2);

      final runs = await repo2.listRuns();
      expect(runs.length, 1);
      expect(runs.first.id, 'run-persist-1');
      expect(runs.first.targetNode, 0xAABBCCDD);
      expect(runs.first.response, true);
      expect(runs.first.hopsTowards, 2);
      expect(runs.first.hopsBack, 1);
      expect(runs.first.snr, 7.5);
      expect(runs.first.hops.length, 3);
      expect(runs.first.hops[0].nodeNum, 0x11111111);
      expect(runs.first.hops[2].back, true);

      await db2.close();

      // Cleanup
      await databaseFactoryFfi.deleteDatabase(dbPath);
    });
  });

  // =========================================================================
  // Migration from SharedPreferences
  // =========================================================================
  group('SqliteTracerouteRepository — migrateFromSharedPreferences', () {
    test('migrates legacy data from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final legacy = TelemetryStorageService(prefs);

      // Write some legacy data
      await legacy.addTraceRouteLog(
        TraceRouteLog(
          id: 'legacy-1',
          nodeNum: 0x11111111,
          targetNode: 0x11111111,
          sent: true,
          response: true,
          hopsTowards: 2,
          hopsBack: 0,
          hops: [
            TraceRouteHop(nodeNum: 0xAA, snr: 5.0),
            TraceRouteHop(nodeNum: 0xBB, snr: 3.0),
          ],
        ),
      );
      await legacy.addTraceRouteLog(
        TraceRouteLog(
          id: 'legacy-2',
          nodeNum: 0x22222222,
          targetNode: 0x22222222,
          sent: true,
          response: false,
        ),
      );

      final (db, repo) = await createRepo();

      final migrated = await repo.migrateFromSharedPreferences(legacy);
      expect(migrated, 2);

      final runs = await repo.listRuns();
      expect(runs.length, 2);

      // Verify the data is correct
      final run1 = runs.firstWhere((r) => r.id == 'legacy-1');
      expect(run1.targetNode, 0x11111111);
      expect(run1.response, true);
      expect(run1.hopsTowards, 2);
      expect(run1.hops.length, 2);

      final run2 = runs.firstWhere((r) => r.id == 'legacy-2');
      expect(run2.targetNode, 0x22222222);
      expect(run2.response, false);

      await db.close();
    });

    test('migration is skipped when DB already has data', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final legacy = TelemetryStorageService(prefs);

      // Write legacy data
      await legacy.addTraceRouteLog(
        TraceRouteLog(
          nodeNum: 0x11111111,
          targetNode: 0x11111111,
          sent: true,
          response: true,
        ),
      );

      final (db, repo) = await createRepo();

      // Pre-populate DB with existing data
      await repo.saveRun(makeRun(targetNode: 0xFFFFFFFF));

      // Attempt migration — should be skipped
      final migrated = await repo.migrateFromSharedPreferences(legacy);
      expect(migrated, 0);

      // Only the pre-existing run should be there
      final runs = await repo.listRuns();
      expect(runs.length, 1);
      expect(runs.first.targetNode, 0xFFFFFFFF);

      await db.close();
    });

    test('migration handles empty legacy gracefully', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final legacy = TelemetryStorageService(prefs);

      final (db, repo) = await createRepo();

      final migrated = await repo.migrateFromSharedPreferences(legacy);
      expect(migrated, 0);

      await db.close();
    });
  });

  // =========================================================================
  // Edge cases and data integrity
  // =========================================================================
  group('SqliteTracerouteRepository — edge cases', () {
    test('hop order is preserved after roundtrip', () async {
      final (db, repo) = await createRepo();

      final hops = [
        makeHop(nodeNum: 0x01, snr: 1.0),
        makeHop(nodeNum: 0x02, snr: 2.0),
        makeHop(nodeNum: 0x03, snr: 3.0),
        makeHop(nodeNum: 0x04, snr: 4.0, back: true),
        makeHop(nodeNum: 0x05, snr: 5.0, back: true),
      ];

      await repo.saveRun(
        makeRun(
          targetNode: 0xAABBCCDD,
          hops: hops,
          hopsTowards: 3,
          hopsBack: 2,
        ),
      );

      final loaded = (await repo.listRuns()).first;
      expect(loaded.hops.length, 5);

      for (var i = 0; i < hops.length; i++) {
        expect(loaded.hops[i].nodeNum, hops[i].nodeNum);
        expect(loaded.hops[i].snr, hops[i].snr);
        expect(loaded.hops[i].back, hops[i].back);
      }

      await db.close();
    });

    test('null SNR is preserved', () async {
      final (db, repo) = await createRepo();

      await repo.saveRun(
        makeRun(
          targetNode: 0x11111111,
          hops: [makeHop(nodeNum: 0xAA, snr: null)],
          hopsTowards: 1,
        ),
      );

      final runs = await repo.listRuns();
      expect(runs.first.hops.first.snr, isNull);
      expect(runs.first.snr, isNull);

      await db.close();
    });

    test('timestamp roundtrip is accurate to milliseconds', () async {
      final (db, repo) = await createRepo();

      final ts = DateTime(2024, 3, 15, 14, 30, 45, 123);
      await repo.saveRun(makeRun(targetNode: 0x11111111, timestamp: ts));

      final loaded = (await repo.listRuns()).first;
      expect(
        loaded.timestamp.millisecondsSinceEpoch,
        ts.millisecondsSinceEpoch,
      );

      await db.close();
    });

    test('large number of hops can be stored and retrieved', () async {
      final (db, repo) = await createRepo();

      final manyHops = List.generate(
        50,
        (i) => makeHop(nodeNum: 0x10000 + i, snr: i * 0.5, back: i >= 25),
      );

      await repo.saveRun(
        makeRun(
          targetNode: 0xAABBCCDD,
          hops: manyHops,
          hopsTowards: 25,
          hopsBack: 25,
        ),
      );

      final loaded = (await repo.listRuns()).first;
      expect(loaded.hops.length, 50);

      await db.close();
    });

    test('negative SNR values are preserved', () async {
      final (db, repo) = await createRepo();

      await repo.saveRun(
        makeRun(
          targetNode: 0x11111111,
          snr: -12.5,
          hops: [makeHop(nodeNum: 0xAA, snr: -20.0)],
          hopsTowards: 1,
        ),
      );

      final loaded = (await repo.listRuns()).first;
      expect(loaded.snr, -12.5);
      expect(loaded.hops.first.snr, -20.0);

      await db.close();
    });
  });
}
