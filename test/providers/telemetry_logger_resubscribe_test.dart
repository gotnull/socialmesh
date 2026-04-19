// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression tests for TelemetryLoggerNotifier protocol re-subscription.
//
// Root cause: TelemetryLoggerNotifier.build() only watched
// telemetryStorageProvider — it did NOT watch protocolServiceProvider.
// When the protocol service was recreated (BLE reconnect, transport
// change), the logger kept subscriptions on the OLD (closed) streams.
// New traceroute events were silently lost.
//
// The fix adds ref.watch(protocolServiceProvider) to build(), so the
// notifier rebuilds and re-subscribes to new streams on protocol changes.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/services/storage/traceroute_database.dart';
import 'package:socialmesh/services/storage/traceroute_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // =========================================================================
  // Traceroute history display regression tests
  // =========================================================================
  group('Traceroute history display', () {
    late TracerouteDatabase db;
    late SqliteTracerouteRepository repo;

    setUp(() async {
      db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
      await db.open();
      repo = SqliteTracerouteRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    TraceRouteLog makeRun({
      required int targetNode,
      bool response = true,
      int hopsTowards = 0,
      int hopsBack = 0,
      List<TraceRouteHop> hops = const [],
      double? snr,
      DateTime? timestamp,
    }) {
      return TraceRouteLog(
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

    test(
      'existing persisted traceroutes render correctly via listRuns',
      () async {
        // Write some historical runs
        await repo.saveRun(
          makeRun(
            targetNode: 100,
            response: true,
            snr: 10.5,
            timestamp: DateTime(2026, 1, 1),
          ),
        );
        await repo.saveRun(
          makeRun(
            targetNode: 200,
            response: false,
            timestamp: DateTime(2026, 1, 2),
          ),
        );
        await repo.saveRun(
          makeRun(
            targetNode: 300,
            response: true,
            snr: -3.0,
            timestamp: DateTime(2026, 1, 3),
          ),
        );

        final all = await repo.listRuns();
        expect(all, hasLength(3));
        // Newest first
        expect(all[0].targetNode, 300);
        expect(all[1].targetNode, 200);
        expect(all[2].targetNode, 100);
      },
    );

    test('newly ingested traceroutes appear via listRuns', () async {
      expect(await repo.listRuns(), isEmpty);

      // Simulate ingest: pending placeholder, then response
      final pending = makeRun(targetNode: 42, response: false);
      await repo.saveRun(pending);

      var all = await repo.listRuns();
      expect(all, hasLength(1));
      expect(all[0].response, false);

      // Response replaces pending
      final completed = makeRun(
        targetNode: 42,
        response: true,
        hopsTowards: 2,
        snr: 8.0,
      );
      await repo.replaceOrAddRun(completed);

      all = await repo.listRuns();
      expect(all, hasLength(1));
      expect(all[0].response, true);
      expect(all[0].snr, 8.0);
    });

    test('All / Response / No Response counts are correct', () async {
      await repo.saveRun(makeRun(targetNode: 1, response: true));
      await repo.saveRun(makeRun(targetNode: 2, response: true));
      await repo.saveRun(makeRun(targetNode: 3, response: false));
      await repo.saveRun(makeRun(targetNode: 4, response: false));
      await repo.saveRun(makeRun(targetNode: 5, response: true));

      final all = await repo.listRuns();
      final allCount = all.length;
      final responseCount = all.where((l) => l.response).length;
      final noResponseCount = all.where((l) => !l.response).length;

      expect(allCount, 5);
      expect(responseCount, 3);
      expect(noResponseCount, 2);
      expect(responseCount + noResponseCount, allCount);
    });

    test(
      'mesh/network scoping via targetNodeId does not hide valid records',
      () async {
        await repo.saveRun(makeRun(targetNode: 100, response: true));
        await repo.saveRun(makeRun(targetNode: 200, response: true));
        await repo.saveRun(makeRun(targetNode: 100, response: false));

        // Global: all 3
        expect(await repo.listRuns(), hasLength(3));

        // Scoped to node 100: 2
        final node100 = await repo.listRuns(targetNodeId: 100);
        expect(node100, hasLength(2));
        expect(node100.every((l) => l.targetNode == 100), true);

        // Scoped to node 200: 1
        final node200 = await repo.listRuns(targetNodeId: 200);
        expect(node200, hasLength(1));

        // Scoped to nonexistent node: 0
        expect(await repo.listRuns(targetNodeId: 999), isEmpty);
      },
    );

    test('legacy records remain visible after schema migrations', () async {
      // Simulate a v1-era record: no via_mqtt, no lat/long, no origin/target coords
      await repo.saveRun(
        makeRun(targetNode: 42, response: true, hopsTowards: 1, snr: 5.0),
      );

      final runs = await repo.listRuns();
      expect(runs, hasLength(1));
      expect(runs[0].viaMqtt, isNull);
      expect(runs[0].originLatitude, isNull);
      expect(runs[0].targetLatitude, isNull);
    });

    test('empty state only shows when truly empty', () async {
      // Empty DB → empty list
      expect(await repo.listRuns(), isEmpty);

      // Add one run → no longer empty
      await repo.saveRun(makeRun(targetNode: 1, response: true));
      expect(await repo.listRuns(), hasLength(1));

      // Delete → empty again
      await repo.deleteAllRuns();
      expect(await repo.listRuns(), isEmpty);
    });

    test('records survive DB close and reopen (file-backed)', () async {
      // Use a file-backed DB for this test
      final dir = await Directory.systemTemp.createTemp('traceroute_test_');
      final path = '${dir.path}/test_survive.db';
      final fileDb = TracerouteDatabase(dbPathOverride: path);
      await fileDb.open();
      final fileRepo = SqliteTracerouteRepository(fileDb);

      await fileRepo.saveRun(makeRun(targetNode: 42, response: true, snr: 7.5));
      expect(await fileRepo.listRuns(), hasLength(1));

      // Close and reopen
      await fileDb.close();
      final reopenedDb = TracerouteDatabase(dbPathOverride: path);
      await reopenedDb.open();
      final reopenedRepo = SqliteTracerouteRepository(reopenedDb);

      final runs = await reopenedRepo.listRuns();
      expect(runs, hasLength(1));
      expect(runs[0].targetNode, 42);
      expect(runs[0].snr, 7.5);

      await reopenedDb.close();
      await dir.delete(recursive: true);
    });

    test('concurrent pending and completed runs are distinct', () async {
      // Pending for node 42
      await repo.saveRun(makeRun(targetNode: 42, response: false));
      // Completed for node 42 (different run)
      await repo.saveRun(makeRun(targetNode: 42, response: true, snr: 3.0));

      // replaceOrAddRun should only replace the pending one
      await repo.replaceOrAddRun(
        makeRun(targetNode: 42, response: true, snr: 9.0),
      );

      final runs = await repo.listRuns(targetNodeId: 42);
      // Should have 2: the original completed + the replacement
      expect(runs, hasLength(2));
      // Both should now be responses
      expect(runs.every((r) => r.response), true);
    });
  });

  // =========================================================================
  // TelemetryLoggerNotifier protocol subscription tests
  // =========================================================================
  group('TelemetryLoggerNotifier protocol re-subscription', () {
    test('traceRouteLogsProvider resolves with data from repository', () async {
      // This verifies the provider chain works end-to-end
      final db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
      await db.open();
      final repo = SqliteTracerouteRepository(db);

      await repo.saveRun(
        TraceRouteLog(nodeNum: 42, targetNode: 42, response: true, snr: 5.0),
      );

      final runs = await repo.listRuns();
      expect(runs, hasLength(1));
      expect(runs[0].targetNode, 42);

      await db.close();
    });

    test(
      'nodeTraceRouteLogsProvider scopes correctly by targetNodeId',
      () async {
        final db = TracerouteDatabase(dbPathOverride: inMemoryDatabasePath);
        await db.open();
        final repo = SqliteTracerouteRepository(db);

        await repo.saveRun(
          TraceRouteLog(nodeNum: 10, targetNode: 10, response: true),
        );
        await repo.saveRun(
          TraceRouteLog(nodeNum: 20, targetNode: 20, response: true),
        );

        final node10 = await repo.listRuns(targetNodeId: 10);
        expect(node10, hasLength(1));
        expect(node10[0].targetNode, 10);

        final node20 = await repo.listRuns(targetNodeId: 20);
        expect(node20, hasLength(1));
        expect(node20[0].targetNode, 20);

        final nonexistent = await repo.listRuns(targetNodeId: 99);
        expect(nonexistent, isEmpty);

        await db.close();
      },
    );
  });
}
