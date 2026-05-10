// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Repository for persisted operations progress + event log.
//
// All writes go through here. The notifier holds an in-memory copy of
// progress and only consults the repository for load + save; the engine
// itself is pure and never touches the DB.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/operation_models.dart';
import 'operations_database.dart';

class OperationsRepository {
  final OperationsDatabase _database;

  OperationsRepository(this._database);

  Future<Database> get _db async => _database.database;

  /// Loads every persisted progress row keyed by operationId. Missing
  /// operations (those not yet started) are not returned — callers
  /// reconcile against the catalog.
  Future<Map<String, OperationProgress>> loadAll() async {
    try {
      final db = await _db;
      final rows = await db.query(OperationsTables.progress);
      final out = <String, OperationProgress>{};
      for (final row in rows) {
        final id = row[OperationsTables.colOperationId] as String?;
        if (id == null) continue;
        out[id] = _hydrate(row);
      }
      return out;
    } catch (e) {
      AppLogging.operations('OPERATIONS_PERSIST_FAILED loadAll error=$e');
      rethrow;
    }
  }

  Future<OperationProgress?> loadOne(String operationId) async {
    try {
      final db = await _db;
      final rows = await db.query(
        OperationsTables.progress,
        where: '${OperationsTables.colOperationId} = ?',
        whereArgs: [operationId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return _hydrate(rows.first);
    } catch (e) {
      AppLogging.operations(
        'OPERATIONS_PERSIST_FAILED loadOne id=$operationId error=$e',
      );
      rethrow;
    }
  }

  /// Idempotent upsert. Replaces the row keyed by `operationId`.
  Future<void> saveProgress(OperationProgress progress) async {
    try {
      final db = await _db;
      await db.insert(OperationsTables.progress, {
        OperationsTables.colOperationId: progress.operationId,
        OperationsTables.colObjectiveProgressJson: progress
            .objectiveProgressJson(),
        OperationsTables.colDedupedKeysJson: progress.dedupedKeysJson(),
        OperationsTables.colCompletedAtMs:
            progress.completedAt?.millisecondsSinceEpoch,
        OperationsTables.colClaimedAtMs:
            progress.claimedAt?.millisecondsSinceEpoch,
        OperationsTables.colUpdatedAtMs:
            progress.updatedAt.millisecondsSinceEpoch,
        OperationsTables.colVersion: progress.version,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      AppLogging.operations(
        'OPERATIONS_PERSIST_FAILED save id=${progress.operationId} error=$e',
      );
      rethrow;
    }
  }

  /// Append a record to the event log. Failures here are non-fatal — the
  /// log is best-effort observability, not the source of truth.
  Future<void> appendEvent({
    required String operationId,
    required String eventType,
    required String dedupeKey,
    required int delta,
    required DateTime occurredAt,
    String? objectiveId,
    Map<String, Object?>? payload,
  }) async {
    try {
      final db = await _db;
      await db.insert(OperationsTables.eventLog, {
        OperationsTables.colEventOperationId: operationId,
        OperationsTables.colEventType: eventType,
        OperationsTables.colEventDedupeKey: dedupeKey,
        OperationsTables.colEventObjectiveId: objectiveId,
        OperationsTables.colEventDelta: delta,
        OperationsTables.colEventTsMs: occurredAt.millisecondsSinceEpoch,
        OperationsTables.colEventPayloadJson: payload == null
            ? null
            : jsonEncode(payload),
      });
    } catch (e) {
      AppLogging.operations(
        'OPERATIONS_PERSIST_FAILED appendEvent id=$operationId error=$e',
      );
    }
  }

  /// Returns the most-recent N event-log rows for diagnostics.
  Future<List<Map<String, Object?>>> recentEvents({int limit = 100}) async {
    try {
      final db = await _db;
      return db.query(
        OperationsTables.eventLog,
        orderBy: '${OperationsTables.colEventTsMs} DESC',
        limit: limit,
      );
    } catch (e) {
      AppLogging.operations('OPERATIONS_PERSIST_FAILED recentEvents error=$e');
      return const [];
    }
  }

  /// Wipes progress + event log. Test helper / future "reset" UX.
  Future<void> reset() async {
    final db = await _db;
    await db.delete(OperationsTables.progress);
    await db.delete(OperationsTables.eventLog);
  }

  OperationProgress _hydrate(Map<String, Object?> row) {
    final completedMs = row[OperationsTables.colCompletedAtMs] as int?;
    final claimedMs = row[OperationsTables.colClaimedAtMs] as int?;
    final updatedMs = row[OperationsTables.colUpdatedAtMs] as int? ?? 0;
    return OperationProgress(
      operationId: row[OperationsTables.colOperationId] as String,
      objectiveProgress: OperationProgress.decodeObjectiveProgress(
        row[OperationsTables.colObjectiveProgressJson] as String?,
      ),
      dedupedKeys: OperationProgress.decodeDedupedKeys(
        row[OperationsTables.colDedupedKeysJson] as String?,
      ),
      completedAt: completedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(completedMs),
      claimedAt: claimedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(claimedMs),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedMs),
      version: row[OperationsTables.colVersion] as int? ?? 1,
    );
  }
}
