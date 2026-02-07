// SPDX-License-Identifier: GPL-3.0-or-later

// Automation SQLite Store — CRUD operations with Cloud Sync outbox support.
//
// This store manages automations in SQLite and maintains a sync outbox
// for the Cloud Sync pipeline. It follows the same pattern as
// NodeDexSqliteStore:
//
// - Local mutations (save, delete) write to SQLite and enqueue outbox records
// - The sync service drains the outbox to push changes to Firestore
// - Remote changes are applied via applySyncPull with LWW merge
// - syncEnabled flag controls whether outbox enqueuing is active
//
// Each automation is stored as a JSON blob in the `automations` table,
// with an `updated_at_ms` timestamp for last-write-wins conflict resolution.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/automation.dart';
import 'automation_database.dart';

/// SQLite-backed store for automations with Cloud Sync outbox support.
///
/// Thread-safety: all database operations are serialized by sqflite.
/// The [syncEnabled] flag must only be toggled from the main isolate.
class AutomationSqliteStore {
  final AutomationDatabase _database;

  /// In-memory cache of automations keyed by ID.
  Map<String, Automation>? _cache;

  /// Whether cloud sync outbox enqueuing is active.
  ///
  /// When true, local mutations (save, delete) enqueue outbox entries.
  /// When false, mutations are local-only (used during sync pull to
  /// prevent re-enqueuing pulled data).
  bool syncEnabled = false;

  AutomationSqliteStore(this._database);

  Database get _db => _database.database;

  /// Initialize the store by opening the database and loading all
  /// automations into the in-memory cache.
  Future<void> init() async {
    await _database.open();
    await _loadAll();
    AppLogging.storage('AutomationSqliteStore: Initialized');
  }

  /// Whether the store has been initialized.
  bool get isReady => _cache != null;

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// Load all non-deleted automations from SQLite into the cache.
  Future<void> _loadAll() async {
    final rows = await _db.query(
      AutomationTables.automations,
      where: '${AutomationTables.colDeleted} = 0',
    );

    _cache = {};
    for (final row in rows) {
      try {
        final dataJson = row[AutomationTables.colDataJson] as String;
        final automation = Automation.fromJson(
          jsonDecode(dataJson) as Map<String, dynamic>,
        );
        _cache![automation.id] = automation;
      } catch (e) {
        AppLogging.storage('AutomationSqliteStore: Failed to parse row: $e');
      }
    }

    AppLogging.storage(
      'AutomationSqliteStore: Loaded ${_cache!.length} automations',
    );
  }

  /// Get all automations (non-deleted).
  List<Automation> getAll() {
    return List.unmodifiable(_cache?.values.toList() ?? []);
  }

  /// Get a single automation by ID, or null if not found.
  Automation? getById(String id) {
    return _cache?[id];
  }

  /// Whether an automation with the given ID exists (non-deleted).
  bool has(String id) {
    return _cache?.containsKey(id) ?? false;
  }

  /// Number of stored automations (non-deleted).
  int get count => _cache?.length ?? 0;

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Save (upsert) an automation.
  ///
  /// Updates the in-memory cache, persists to SQLite, and enqueues
  /// an outbox entry if [syncEnabled] is true.
  Future<void> save(Automation automation) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dataJson = jsonEncode(automation.toJson());

    _cache ??= {};
    _cache![automation.id] = automation;

    await _db.transaction((txn) async {
      await txn.insert(AutomationTables.automations, {
        AutomationTables.colId: automation.id,
        AutomationTables.colDataJson: dataJson,
        AutomationTables.colUpdatedAtMs: now,
        AutomationTables.colDeleted: 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (syncEnabled) {
        await _enqueueOutboxInTxn(
          txn,
          'automation',
          automation.id,
          'upsert',
          dataJson,
        );
      }
    });
  }

  /// Delete an automation (soft-delete).
  ///
  /// Marks the row as deleted, removes from cache, and enqueues a
  /// delete outbox entry if [syncEnabled] is true.
  Future<void> delete(String id) async {
    _cache?.remove(id);

    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction((txn) async {
      await txn.update(
        AutomationTables.automations,
        {AutomationTables.colDeleted: 1, AutomationTables.colUpdatedAtMs: now},
        where: '${AutomationTables.colId} = ?',
        whereArgs: [id],
      );

      if (syncEnabled) {
        await _enqueueOutboxInTxn(txn, 'automation', id, 'delete', '{}');
      }
    });

    AppLogging.storage('AutomationSqliteStore: Soft-deleted automation $id');
  }

  /// Clear all automations (for testing/reset).
  Future<void> clearAll() async {
    _cache?.clear();
    await _db.delete(AutomationTables.automations);
    await _db.delete(AutomationTables.syncOutbox);
    AppLogging.storage('AutomationSqliteStore: Cleared all automations');
  }

  // ---------------------------------------------------------------------------
  // Bulk import (migration from SharedPreferences)
  // ---------------------------------------------------------------------------

  /// Import automations from a list, typically from SharedPreferences
  /// migration. Does NOT enqueue outbox entries — the sync service
  /// will handle the initial push after migration.
  ///
  /// Returns the number of automations imported.
  Future<int> bulkImport(List<Automation> automations) async {
    if (automations.isEmpty) return 0;

    final prevSync = syncEnabled;
    syncEnabled = false;

    try {
      _cache ??= {};
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction((txn) async {
        for (final automation in automations) {
          final dataJson = jsonEncode(automation.toJson());
          _cache![automation.id] = automation;

          await txn.insert(
            AutomationTables.automations,
            {
              AutomationTables.colId: automation.id,
              AutomationTables.colDataJson: dataJson,
              AutomationTables.colUpdatedAtMs: now,
              AutomationTables.colDeleted: 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      AppLogging.storage(
        'AutomationSqliteStore: Bulk imported ${automations.length} automations',
      );
      return automations.length;
    } finally {
      syncEnabled = prevSync;
    }
  }

  /// Enqueue all existing automations to the outbox for initial sync push.
  ///
  /// Call this after [bulkImport] to ensure migrated data reaches Firestore.
  Future<int> enqueueAllForSync() async {
    final all = getAll();
    if (all.isEmpty) return 0;

    await _db.transaction((txn) async {
      for (final automation in all) {
        final dataJson = jsonEncode(automation.toJson());
        await _enqueueOutboxInTxn(
          txn,
          'automation',
          automation.id,
          'upsert',
          dataJson,
        );
      }
    });

    AppLogging.storage(
      'AutomationSqliteStore: Enqueued ${all.length} automations for sync',
    );
    return all.length;
  }

  // ---------------------------------------------------------------------------
  // Sync pull (apply remote changes)
  // ---------------------------------------------------------------------------

  /// Apply remotely-pulled automations using last-write-wins at the
  /// item level.
  ///
  /// Temporarily disables [syncEnabled] during the pull to prevent
  /// re-enqueuing pulled data to the outbox, which would create
  /// an infinite push/pull sync loop.
  Future<int> applySyncPull(List<Automation> remoteAutomations) async {
    if (remoteAutomations.isEmpty) return 0;

    final prevSync = syncEnabled;
    syncEnabled = false;

    _cache ??= {};
    int appliedCount = 0;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction((txn) async {
        for (final remote in remoteAutomations) {
          // For automations, we use simple last-write-wins at the item level.
          // The remote version always wins during pull because it has the
          // latest server timestamp (the sync service only pulls entries
          // newer than our watermark).
          _cache![remote.id] = remote;

          final dataJson = jsonEncode(remote.toJson());
          await txn.insert(
            AutomationTables.automations,
            {
              AutomationTables.colId: remote.id,
              AutomationTables.colDataJson: dataJson,
              AutomationTables.colUpdatedAtMs: now,
              AutomationTables.colDeleted: 0,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          appliedCount++;
        }
      });

      AppLogging.storage(
        'AutomationSqliteStore: Sync pull applied $appliedCount automations',
      );
    } finally {
      syncEnabled = prevSync;
    }
    return appliedCount;
  }

  /// Apply a remote deletion from sync pull.
  ///
  /// Removes the automation from the cache and marks it as deleted
  /// in SQLite without enqueuing to the outbox.
  Future<void> applySyncDeletion(String id) async {
    _cache?.remove(id);

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      AutomationTables.automations,
      {AutomationTables.colDeleted: 1, AutomationTables.colUpdatedAtMs: now},
      where: '${AutomationTables.colId} = ?',
      whereArgs: [id],
    );

    AppLogging.storage(
      'AutomationSqliteStore: Sync pull deleted automation $id',
    );
  }

  // ---------------------------------------------------------------------------
  // Outbox operations
  // ---------------------------------------------------------------------------

  /// Enqueue an outbox entry within a transaction.
  ///
  /// Deduplicates by removing older entries for the same entity before
  /// inserting the new one, so only the latest mutation is pushed.
  Future<void> _enqueueOutboxInTxn(
    Transaction txn,
    String entityType,
    String entityId,
    String op,
    String payloadJson,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Deduplicate: remove older outbox entries for the same entity.
    await txn.delete(
      AutomationTables.syncOutbox,
      where:
          '${AutomationTables.colOutboxEntityType} = ? AND '
          '${AutomationTables.colOutboxEntityId} = ?',
      whereArgs: [entityType, entityId],
    );

    await txn.insert(AutomationTables.syncOutbox, {
      AutomationTables.colOutboxEntityType: entityType,
      AutomationTables.colOutboxEntityId: entityId,
      AutomationTables.colOutboxOp: op,
      AutomationTables.colOutboxPayloadJson: payloadJson,
      AutomationTables.colOutboxUpdatedAtMs: now,
      AutomationTables.colOutboxAttemptCount: 0,
    });
  }

  /// Read pending outbox entries for sync drain.
  Future<List<Map<String, Object?>>> readOutbox({int limit = 100}) async {
    return _db.query(
      AutomationTables.syncOutbox,
      orderBy: '${AutomationTables.colOutboxUpdatedAtMs} ASC',
      limit: limit,
    );
  }

  /// Mark an outbox entry as sent (delete it).
  Future<void> removeOutboxEntry(int id) async {
    await _db.delete(
      AutomationTables.syncOutbox,
      where: '${AutomationTables.colOutboxId} = ?',
      whereArgs: [id],
    );
  }

  /// Record a failed outbox attempt.
  Future<void> markOutboxAttemptFailed(int id, String error) async {
    await _db.rawUpdate(
      'UPDATE ${AutomationTables.syncOutbox} SET '
      '${AutomationTables.colOutboxAttemptCount} = '
      '${AutomationTables.colOutboxAttemptCount} + 1, '
      '${AutomationTables.colOutboxLastError} = ? '
      'WHERE ${AutomationTables.colOutboxId} = ?',
      [error, id],
    );
  }

  /// Get the count of pending outbox entries.
  Future<int> get outboxCount async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AutomationTables.syncOutbox}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Sync state helpers
  // ---------------------------------------------------------------------------

  /// Get a sync state value by key.
  Future<String?> getSyncState(String key) async {
    final rows = await _db.query(
      AutomationTables.syncState,
      where: '${AutomationTables.colSyncKey} = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first[AutomationTables.colSyncValue] as String?;
  }

  /// Set a sync state value.
  Future<void> setSyncState(String key, String value) async {
    await _db.insert(AutomationTables.syncState, {
      AutomationTables.colSyncKey: key,
      AutomationTables.colSyncValue: value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------------------------
  // Export / Import (JSON)
  // ---------------------------------------------------------------------------

  /// Export all automations as a JSON string.
  String toJsonString() {
    final all = getAll();
    return jsonEncode(all.map((a) => a.toJson()).toList());
  }

  /// Parse a JSON string into a list of automations.
  ///
  /// Does not modify the store — use [bulkImport] to persist.
  static List<Automation> parseJson(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    return list
        .map((item) => Automation.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
