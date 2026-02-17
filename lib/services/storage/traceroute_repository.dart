// SPDX-License-Identifier: GPL-3.0-or-later

// Traceroute Repository — SQLite-backed persistence for traceroute history.
//
// Provides:
//   - saveRun: transactional insert of a run + its hops
//   - replaceOrAddRun: replace pending placeholder with completed response
//   - listRuns: global or per-node, newest-first, with limit
//   - deleteRunsForNode / deleteAllRuns: cleanup
//   - prune: enforce max runs total and per-node caps
//   - migrateFromSharedPreferences: one-time import of legacy data

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/logging.dart';
import '../../models/telemetry_log.dart';
import 'telemetry_database.dart';
import 'traceroute_database.dart';

/// Retention limits for traceroute history pruning.
abstract final class TracerouteRetention {
  static const int maxRunsTotal = 500;
  static const int maxRunsPerNode = 100;
}

/// Repository interface for traceroute history persistence.
abstract class TracerouteHistoryRepository {
  /// Persist a traceroute run and its hops in a single transaction.
  Future<void> saveRun(TraceRouteLog run);

  /// Replace the most recent pending (no-response) run for the same target
  /// with [run], or insert if no pending entry exists.
  Future<void> replaceOrAddRun(TraceRouteLog run);

  /// List traceroute runs, newest first.
  /// If [targetNodeId] is provided, scopes to that node.
  Future<List<TraceRouteLog>> listRuns({int? targetNodeId, int limit = 200});

  /// Delete all runs targeting a specific node.
  Future<void> deleteRunsForNode(int targetNodeId);

  /// Delete all traceroute runs.
  Future<void> deleteAllRuns();

  /// Prune old runs to stay within retention limits.
  Future<void> prune({
    int maxRunsTotal = TracerouteRetention.maxRunsTotal,
    int maxRunsPerNode = TracerouteRetention.maxRunsPerNode,
  });

  /// One-time migration from SharedPreferences-based storage.
  /// Returns the number of runs migrated, or 0 if already migrated / empty.
  Future<int> migrateFromSharedPreferences(TelemetryDatabase legacy);
}

/// SQLite-backed implementation of [TracerouteHistoryRepository].
class SqliteTracerouteRepository implements TracerouteHistoryRepository {
  final TracerouteDatabase _database;
  static const _uuid = Uuid();

  SqliteTracerouteRepository(this._database);

  Database get _db => _database.database;

  @override
  Future<void> saveRun(TraceRouteLog run) async {
    try {
      await _db.transaction((txn) async {
        await _insertRun(txn, run);
        await _insertHops(txn, run.id, run.hops);
      });

      // Prune after each successful save (fire-and-forget with error logging)
      try {
        await prune();
      } catch (e) {
        AppLogging.storage('TracerouteRepository: Prune after save failed: $e');
      }
    } catch (e) {
      AppLogging.storage('TracerouteRepository: saveRun failed: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // replaceOrAddRun
  // ---------------------------------------------------------------------------

  @override
  Future<void> replaceOrAddRun(TraceRouteLog run) async {
    try {
      await _db.transaction((txn) async {
        // Find the most recent pending run for this target node
        final pending = await txn.query(
          TracerouteTables.runs,
          columns: [TracerouteTables.colId],
          where:
              '${TracerouteTables.colTargetNodeId} = ? AND '
              '${TracerouteTables.colResponseReceived} = 0',
          whereArgs: [run.targetNode],
          orderBy: '${TracerouteTables.colCreatedAt} DESC',
          limit: 1,
        );

        if (pending.isNotEmpty) {
          final pendingId = pending.first[TracerouteTables.colId] as String;
          // Delete old hops (cascade should handle it, but be explicit)
          await txn.delete(
            TracerouteTables.hops,
            where: '${TracerouteTables.colRunId} = ?',
            whereArgs: [pendingId],
          );
          // Delete the pending run
          await txn.delete(
            TracerouteTables.runs,
            where: '${TracerouteTables.colId} = ?',
            whereArgs: [pendingId],
          );
        }

        // Insert the new (completed) run
        await _insertRun(txn, run);
        await _insertHops(txn, run.id, run.hops);
      });

      try {
        await prune();
      } catch (e) {
        AppLogging.storage(
          'TracerouteRepository: Prune after replaceOrAdd failed: $e',
        );
      }
    } catch (e) {
      AppLogging.storage('TracerouteRepository: replaceOrAddRun failed: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // listRuns
  // ---------------------------------------------------------------------------

  @override
  Future<List<TraceRouteLog>> listRuns({
    int? targetNodeId,
    int limit = 200,
  }) async {
    try {
      final String? where;
      final List<Object?>? whereArgs;

      if (targetNodeId != null) {
        where = '${TracerouteTables.colTargetNodeId} = ?';
        whereArgs = [targetNodeId];
      } else {
        where = null;
        whereArgs = null;
      }

      final runRows = await _db.query(
        TracerouteTables.runs,
        where: where,
        whereArgs: whereArgs,
        orderBy: '${TracerouteTables.colCreatedAt} DESC',
        limit: limit,
      );

      if (runRows.isEmpty) return [];

      // Batch-fetch all hops for these runs
      final runIds = runRows.map((r) => r[TracerouteTables.colId]).toList();
      final hopRows = await _fetchHopsForRuns(runIds);

      // Group hops by run_id
      final hopsByRunId = <String, List<Map<String, Object?>>>{};
      for (final hop in hopRows) {
        final runId = hop[TracerouteTables.colRunId] as String;
        hopsByRunId.putIfAbsent(runId, () => []).add(hop);
      }

      // Assemble TraceRouteLog objects
      return runRows.map((row) {
        final runId = row[TracerouteTables.colId] as String;
        final hops = _hopsFromRows(hopsByRunId[runId] ?? []);
        return _runFromRow(row, hops);
      }).toList();
    } catch (e) {
      AppLogging.storage('TracerouteRepository: listRuns failed: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // deleteRunsForNode
  // ---------------------------------------------------------------------------

  @override
  Future<void> deleteRunsForNode(int targetNodeId) async {
    try {
      // Hops are cascade-deleted via foreign key
      await _db.delete(
        TracerouteTables.runs,
        where: '${TracerouteTables.colTargetNodeId} = ?',
        whereArgs: [targetNodeId],
      );
      AppLogging.storage(
        'TracerouteRepository: Deleted runs for node $targetNodeId',
      );
    } catch (e) {
      AppLogging.storage('TracerouteRepository: deleteRunsForNode failed: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // deleteAllRuns
  // ---------------------------------------------------------------------------

  @override
  Future<void> deleteAllRuns() async {
    try {
      await _db.delete(TracerouteTables.hops);
      await _db.delete(TracerouteTables.runs);
      AppLogging.storage('TracerouteRepository: Deleted all runs');
    } catch (e) {
      AppLogging.storage('TracerouteRepository: deleteAllRuns failed: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // prune
  // ---------------------------------------------------------------------------

  @override
  Future<void> prune({
    int maxRunsTotal = TracerouteRetention.maxRunsTotal,
    int maxRunsPerNode = TracerouteRetention.maxRunsPerNode,
  }) async {
    try {
      await _db.transaction((txn) async {
        // 1. Global cap: delete oldest runs beyond maxRunsTotal
        final totalCount =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM ${TracerouteTables.runs}',
              ),
            ) ??
            0;

        if (totalCount > maxRunsTotal) {
          final excess = totalCount - maxRunsTotal;
          // Find the IDs of the oldest excess runs
          final oldestRows = await txn.query(
            TracerouteTables.runs,
            columns: [TracerouteTables.colId],
            orderBy: '${TracerouteTables.colCreatedAt} ASC',
            limit: excess,
          );

          if (oldestRows.isNotEmpty) {
            final ids = oldestRows
                .map((r) => r[TracerouteTables.colId] as String)
                .toList();
            await _deleteRunsByIds(txn, ids);
            AppLogging.storage(
              'TracerouteRepository: Pruned $excess runs (global cap)',
            );
          }
        }

        // 2. Per-node cap: delete oldest runs per node beyond maxRunsPerNode
        final nodeRows = await txn.rawQuery(
          'SELECT ${TracerouteTables.colTargetNodeId}, COUNT(*) as cnt '
          'FROM ${TracerouteTables.runs} '
          'GROUP BY ${TracerouteTables.colTargetNodeId} '
          'HAVING cnt > ?',
          [maxRunsPerNode],
        );

        for (final nodeRow in nodeRows) {
          final nodeId = nodeRow[TracerouteTables.colTargetNodeId] as int;
          final count = nodeRow['cnt'] as int;
          final nodeExcess = count - maxRunsPerNode;

          if (nodeExcess > 0) {
            final oldestForNode = await txn.query(
              TracerouteTables.runs,
              columns: [TracerouteTables.colId],
              where: '${TracerouteTables.colTargetNodeId} = ?',
              whereArgs: [nodeId],
              orderBy: '${TracerouteTables.colCreatedAt} ASC',
              limit: nodeExcess,
            );

            if (oldestForNode.isNotEmpty) {
              final ids = oldestForNode
                  .map((r) => r[TracerouteTables.colId] as String)
                  .toList();
              await _deleteRunsByIds(txn, ids);
              AppLogging.storage(
                'TracerouteRepository: Pruned $nodeExcess runs '
                'for node $nodeId (per-node cap)',
              );
            }
          }
        }
      });
    } catch (e) {
      AppLogging.storage('TracerouteRepository: prune failed: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // migrateFromSharedPreferences
  // ---------------------------------------------------------------------------

  @override
  Future<int> migrateFromSharedPreferences(TelemetryDatabase legacy) async {
    try {
      // Check if migration was already done
      final existing = await _db.query(TracerouteTables.runs, limit: 1);

      // If there are already runs in the DB, skip migration
      if (existing.isNotEmpty) {
        AppLogging.storage(
          'TracerouteRepository: Migration skipped — DB already has data',
        );
        return 0;
      }

      final allLogs = await legacy.getAllTraceRouteLogs();
      if (allLogs.isEmpty) {
        AppLogging.storage(
          'TracerouteRepository: Migration skipped — no legacy data',
        );
        return 0;
      }

      var migrated = 0;
      await _db.transaction((txn) async {
        for (final log in allLogs) {
          await _insertRun(txn, log);
          await _insertHops(txn, log.id, log.hops);
          migrated++;
        }
      });

      AppLogging.storage(
        'TracerouteRepository: Migrated $migrated runs from SharedPreferences',
      );

      return migrated;
    } catch (e) {
      AppLogging.storage(
        'TracerouteRepository: Migration from SharedPreferences failed: $e',
      );
      // Migration failure is not fatal — new data will still be written to DB
      return 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _insertRun(DatabaseExecutor txn, TraceRouteLog run) async {
    final status = run.response
        ? TracerouteTables.statusCompleted
        : TracerouteTables.statusPending;

    await txn.insert(TracerouteTables.runs, {
      TracerouteTables.colId: run.id,
      TracerouteTables.colCreatedAt: run.timestamp.millisecondsSinceEpoch,
      TracerouteTables.colTargetNodeId: run.targetNode,
      TracerouteTables.colStatus: status,
      TracerouteTables.colForwardHops: run.hopsTowards,
      TracerouteTables.colReturnHops: run.hopsBack,
      TracerouteTables.colResponseReceived: run.response ? 1 : 0,
      TracerouteTables.colSnr: run.snr,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _insertHops(
    DatabaseExecutor txn,
    String runId,
    List<TraceRouteHop> hops,
  ) async {
    for (var i = 0; i < hops.length; i++) {
      final hop = hops[i];
      final direction = hop.back
          ? TracerouteTables.directionReturn
          : TracerouteTables.directionForward;

      await txn.insert(TracerouteTables.hops, {
        TracerouteTables.colHopId: _uuid.v4(),
        TracerouteTables.colRunId: runId,
        TracerouteTables.colHopIndex: i,
        TracerouteTables.colNodeId: hop.nodeNum,
        TracerouteTables.colHopSnr: hop.snr,
        TracerouteTables.colRssi: null,
        TracerouteTables.colDirection: direction,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, Object?>>> _fetchHopsForRuns(
    List<Object?> runIds,
  ) async {
    if (runIds.isEmpty) return [];

    // Use batched IN clauses for efficiency
    // SQLite has a limit of ~999 variables, so batch if needed
    final results = <Map<String, Object?>>[];
    const batchSize = 500;

    for (var i = 0; i < runIds.length; i += batchSize) {
      final batch = runIds.sublist(
        i,
        i + batchSize > runIds.length ? runIds.length : i + batchSize,
      );
      final placeholders = List.filled(batch.length, '?').join(',');

      final rows = await _db.rawQuery(
        'SELECT * FROM ${TracerouteTables.hops} '
        'WHERE ${TracerouteTables.colRunId} IN ($placeholders) '
        'ORDER BY ${TracerouteTables.colHopIndex} ASC',
        batch,
      );
      results.addAll(rows);
    }

    return results;
  }

  List<TraceRouteHop> _hopsFromRows(List<Map<String, Object?>> rows) {
    return rows.map((row) {
      final direction = row[TracerouteTables.colDirection] as String;
      return TraceRouteHop(
        nodeNum: row[TracerouteTables.colNodeId] as int,
        snr: row[TracerouteTables.colHopSnr] as double?,
        back: direction == TracerouteTables.directionReturn,
      );
    }).toList();
  }

  TraceRouteLog _runFromRow(
    Map<String, Object?> row,
    List<TraceRouteHop> hops,
  ) {
    final responseReceived =
        (row[TracerouteTables.colResponseReceived] as int) == 1;
    final targetNodeId = row[TracerouteTables.colTargetNodeId] as int;
    final createdAtMs = row[TracerouteTables.colCreatedAt] as int;

    return TraceRouteLog(
      id: row[TracerouteTables.colId] as String,
      nodeNum: targetNodeId,
      timestamp: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
      targetNode: targetNodeId,
      sent: true,
      response: responseReceived,
      hopsTowards: row[TracerouteTables.colForwardHops] as int? ?? 0,
      hopsBack: row[TracerouteTables.colReturnHops] as int? ?? 0,
      hops: hops,
      snr: row[TracerouteTables.colSnr] as double?,
    );
  }

  Future<void> _deleteRunsByIds(DatabaseExecutor txn, List<String> ids) async {
    if (ids.isEmpty) return;

    // Delete hops first (in case foreign keys are not enforced in some
    // build configurations), then delete runs.
    const batchSize = 500;

    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.sublist(
        i,
        i + batchSize > ids.length ? ids.length : i + batchSize,
      );
      final placeholders = List.filled(batch.length, '?').join(',');

      await txn.rawDelete(
        'DELETE FROM ${TracerouteTables.hops} '
        'WHERE ${TracerouteTables.colRunId} IN ($placeholders)',
        batch,
      );
      await txn.rawDelete(
        'DELETE FROM ${TracerouteTables.runs} '
        'WHERE ${TracerouteTables.colId} IN ($placeholders)',
        batch,
      );
    }
  }
}
