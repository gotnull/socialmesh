// SPDX-License-Identifier: GPL-3.0-or-later

// Widget SQLite Store — CRUD operations with Cloud Sync outbox support.
//
// This store manages custom widget schemas in SQLite and maintains a sync
// outbox for the Cloud Sync pipeline. It follows the same pattern as
// NodeDexSqliteStore and AutomationSqliteStore:
//
// - Local mutations (save, delete) write to SQLite and enqueue outbox records
// - The sync service drains the outbox to push changes to Firestore
// - Remote changes are applied via applySyncPull with LWW merge
// - syncEnabled flag controls whether outbox enqueuing is active
//
// Each widget schema is stored as a JSON blob in the `widgets` table,
// with an `updated_at_ms` timestamp for last-write-wins conflict resolution.

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/widget_schema.dart';
import 'widget_database.dart';

/// SQLite-backed store for custom widget schemas with Cloud Sync outbox support.
///
/// Thread-safety: all database operations are serialized by sqflite.
/// The [syncEnabled] flag must only be toggled from the main isolate.
class WidgetSqliteStore {
  final WidgetDatabase _database;

  /// In-memory cache of widget schemas keyed by ID.
  Map<String, WidgetSchema>? _cache;

  /// Whether cloud sync outbox enqueuing is active.
  ///
  /// When true, local mutations (save, delete) enqueue outbox entries.
  /// When false, mutations are local-only (used during sync pull to
  /// prevent re-enqueuing pulled data).
  bool _syncEnabled = false;

  /// Getter for [_syncEnabled] with logging on changes.
  bool get syncEnabled => _syncEnabled;

  /// Setter for [_syncEnabled] that logs every transition.
  set syncEnabled(bool value) {
    final old = _syncEnabled;
    _syncEnabled = value;
    if (old != value) {
      AppLogging.sync(
        '[WidgetStore] syncEnabled changed: $old -> $value '
        '(store hashCode=${identityHashCode(this)})',
      );
    }
  }

  WidgetSqliteStore(this._database);

  Database get _db => _database.database;

  /// Initialize the store by opening the database and loading all
  /// widget schemas into the in-memory cache.
  Future<void> init() async {
    await _database.open();
    await _loadAll();
    AppLogging.storage('WidgetSqliteStore: Initialized');
    AppLogging.sync(
      '[WidgetStore] init complete — ${_cache?.length ?? 0} widgets loaded, '
      'syncEnabled=$_syncEnabled, store hashCode=${identityHashCode(this)}',
    );
  }

  /// Whether the store has been initialized.
  bool get isReady => _cache != null;

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// Load all non-deleted widget schemas from SQLite into the cache.
  Future<void> _loadAll() async {
    final rows = await _db.query(
      WidgetTables.widgets,
      where: '${WidgetTables.colDeleted} = 0',
    );

    _cache = {};
    for (final row in rows) {
      try {
        final dataJson = row[WidgetTables.colDataJson] as String;
        final widget = WidgetSchema.fromJson(
          jsonDecode(dataJson) as Map<String, dynamic>,
        );
        _cache![widget.id] = widget;
      } catch (e) {
        AppLogging.storage('WidgetSqliteStore: Failed to parse row: $e');
      }
    }

    AppLogging.storage(
      'WidgetSqliteStore: Loaded ${_cache!.length} widget schemas',
    );
  }

  /// Get all widget schemas (non-deleted).
  List<WidgetSchema> getAll() {
    return List.unmodifiable(_cache?.values.toList() ?? []);
  }

  /// Get a single widget schema by ID, or null if not found.
  WidgetSchema? getById(String id) {
    return _cache?[id];
  }

  /// Whether a widget schema with the given ID exists (non-deleted).
  bool has(String id) {
    return _cache?.containsKey(id) ?? false;
  }

  /// Number of stored widget schemas (non-deleted).
  int get count => _cache?.length ?? 0;

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Save (upsert) a widget schema.
  ///
  /// Updates the in-memory cache, persists to SQLite, and enqueues
  /// an outbox entry if [syncEnabled] is true.
  Future<void> save(WidgetSchema widget) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dataJson = jsonEncode(widget.toJson());

    AppLogging.sync(
      '[WidgetStore] save() ENTER — id=${widget.id}, name=${widget.name}, '
      'syncEnabled=$_syncEnabled, store hashCode=${identityHashCode(this)}',
    );

    _cache ??= {};
    _cache![widget.id] = widget;

    await _db.transaction((txn) async {
      await txn.insert(WidgetTables.widgets, {
        WidgetTables.colId: widget.id,
        WidgetTables.colDataJson: dataJson,
        WidgetTables.colUpdatedAtMs: now,
        WidgetTables.colDeleted: 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      if (syncEnabled) {
        AppLogging.sync(
          '[WidgetStore] save() — syncEnabled=true, ENQUEUING outbox entry '
          'for widget ${widget.id}',
        );
        await _enqueueOutboxInTxn(txn, 'widget', widget.id, 'upsert', dataJson);
      } else {
        AppLogging.sync(
          '[WidgetStore] save() — syncEnabled=FALSE, NOT enqueuing outbox '
          'for widget ${widget.id}. This widget will NOT sync!',
        );
      }
    });

    AppLogging.sync(
      '[WidgetStore] save() EXIT — widget ${widget.id} saved to SQLite, '
      'cache count=${_cache?.length ?? 0}',
    );
  }

  /// Delete a widget schema (soft-delete).
  ///
  /// Marks the row as deleted, removes from cache, and enqueues a
  /// delete outbox entry if [syncEnabled] is true.
  Future<void> delete(String id) async {
    AppLogging.sync(
      '[WidgetStore] delete() ENTER — id=$id, syncEnabled=$_syncEnabled',
    );

    _cache?.remove(id);

    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction((txn) async {
      await txn.update(
        WidgetTables.widgets,
        {WidgetTables.colDeleted: 1, WidgetTables.colUpdatedAtMs: now},
        where: '${WidgetTables.colId} = ?',
        whereArgs: [id],
      );

      if (syncEnabled) {
        AppLogging.sync(
          '[WidgetStore] delete() — syncEnabled=true, ENQUEUING delete '
          'outbox for widget $id',
        );
        await _enqueueOutboxInTxn(txn, 'widget', id, 'delete', '{}');
      } else {
        AppLogging.sync(
          '[WidgetStore] delete() — syncEnabled=FALSE, NOT enqueuing delete '
          'outbox for widget $id. This deletion will NOT sync!',
        );
      }
    });

    AppLogging.storage('WidgetSqliteStore: Soft-deleted widget $id');
    AppLogging.sync('[WidgetStore] delete() EXIT — widget $id soft-deleted');
  }

  /// Clear all widget schemas (for testing/reset).
  Future<void> clearAll() async {
    _cache?.clear();
    await _db.delete(WidgetTables.widgets);
    await _db.delete(WidgetTables.syncOutbox);
    AppLogging.storage('WidgetSqliteStore: Cleared all widget schemas');
  }

  // ---------------------------------------------------------------------------
  // Bulk import (migration from SharedPreferences)
  // ---------------------------------------------------------------------------

  /// Import widget schemas from a list, typically from SharedPreferences
  /// migration. Does NOT enqueue outbox entries — the sync service
  /// will handle the initial push after migration.
  ///
  /// Returns the number of widget schemas imported.
  Future<int> bulkImport(List<WidgetSchema> widgets) async {
    if (widgets.isEmpty) return 0;

    AppLogging.sync(
      '[WidgetStore] bulkImport() — importing ${widgets.length} widgets '
      '(syncEnabled temporarily disabled)',
    );

    final prevSync = syncEnabled;
    syncEnabled = false;

    try {
      _cache ??= {};
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction((txn) async {
        for (final widget in widgets) {
          final dataJson = jsonEncode(widget.toJson());
          _cache![widget.id] = widget;

          await txn.insert(WidgetTables.widgets, {
            WidgetTables.colId: widget.id,
            WidgetTables.colDataJson: dataJson,
            WidgetTables.colUpdatedAtMs: now,
            WidgetTables.colDeleted: 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

      AppLogging.storage(
        'WidgetSqliteStore: Bulk imported ${widgets.length} widget schemas',
      );
      AppLogging.sync(
        '[WidgetStore] bulkImport() complete — ${widgets.length} widgets '
        'imported, restoring syncEnabled=$prevSync',
      );
      return widgets.length;
    } finally {
      syncEnabled = prevSync;
    }
  }

  /// Enqueue all existing widget schemas to the outbox for initial sync push.
  ///
  /// Call this after [bulkImport] to ensure migrated data reaches Firestore.
  Future<int> enqueueAllForSync() async {
    final all = getAll();
    AppLogging.sync(
      '[WidgetStore] enqueueAllForSync() — ${all.length} widgets to enqueue',
    );
    if (all.isEmpty) return 0;

    await _db.transaction((txn) async {
      for (final widget in all) {
        final dataJson = jsonEncode(widget.toJson());
        await _enqueueOutboxInTxn(txn, 'widget', widget.id, 'upsert', dataJson);
      }
    });

    AppLogging.storage(
      'WidgetSqliteStore: Enqueued ${all.length} widget schemas for sync',
    );
    AppLogging.sync(
      '[WidgetStore] enqueueAllForSync() complete — ${all.length} entries '
      'now in outbox',
    );
    return all.length;
  }

  // ---------------------------------------------------------------------------
  // Sync pull (apply remote changes)
  // ---------------------------------------------------------------------------

  /// Apply remotely-pulled widget schemas using last-write-wins at the
  /// item level.
  ///
  /// Temporarily disables [syncEnabled] during the pull to prevent
  /// re-enqueuing pulled data to the outbox, which would create
  /// an infinite push/pull sync loop.
  Future<int> applySyncPull(List<WidgetSchema> remoteWidgets) async {
    if (remoteWidgets.isEmpty) return 0;

    AppLogging.sync(
      '[WidgetStore] applySyncPull() — applying ${remoteWidgets.length} '
      'remote widgets (syncEnabled temporarily disabled to prevent re-enqueue)',
    );

    final prevSync = syncEnabled;
    syncEnabled = false;

    _cache ??= {};
    int appliedCount = 0;

    try {
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction((txn) async {
        for (final remote in remoteWidgets) {
          // For widget schemas, we use simple last-write-wins at the item
          // level. The remote version always wins during pull because it
          // has the latest server timestamp (the sync service only pulls
          // entries newer than our watermark).
          _cache![remote.id] = remote;

          final dataJson = jsonEncode(remote.toJson());
          await txn.insert(WidgetTables.widgets, {
            WidgetTables.colId: remote.id,
            WidgetTables.colDataJson: dataJson,
            WidgetTables.colUpdatedAtMs: now,
            WidgetTables.colDeleted: 0,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          appliedCount++;
        }
      });

      AppLogging.storage(
        'WidgetSqliteStore: Sync pull applied $appliedCount widget schemas',
      );
      AppLogging.sync(
        '[WidgetStore] applySyncPull() complete — applied $appliedCount, '
        'restoring syncEnabled=$prevSync',
      );
    } finally {
      syncEnabled = prevSync;
    }
    return appliedCount;
  }

  /// Apply a remote deletion from sync pull.
  ///
  /// Removes the widget schema from the cache and marks it as deleted
  /// in SQLite without enqueuing to the outbox.
  Future<void> applySyncDeletion(String id) async {
    _cache?.remove(id);

    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      WidgetTables.widgets,
      {WidgetTables.colDeleted: 1, WidgetTables.colUpdatedAtMs: now},
      where: '${WidgetTables.colId} = ?',
      whereArgs: [id],
    );

    AppLogging.storage('WidgetSqliteStore: Sync pull deleted widget $id');
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

    AppLogging.sync(
      '[WidgetStore] _enqueueOutboxInTxn() — '
      'entityType=$entityType, entityId=$entityId, op=$op, ts=$now',
    );

    // Deduplicate: remove older outbox entries for the same entity.
    await txn.delete(
      WidgetTables.syncOutbox,
      where:
          '${WidgetTables.colOutboxEntityType} = ? AND '
          '${WidgetTables.colOutboxEntityId} = ?',
      whereArgs: [entityType, entityId],
    );

    await txn.insert(WidgetTables.syncOutbox, {
      WidgetTables.colOutboxEntityType: entityType,
      WidgetTables.colOutboxEntityId: entityId,
      WidgetTables.colOutboxOp: op,
      WidgetTables.colOutboxPayloadJson: payloadJson,
      WidgetTables.colOutboxUpdatedAtMs: now,
      WidgetTables.colOutboxAttemptCount: 0,
    });

    AppLogging.sync(
      '[WidgetStore] _enqueueOutboxInTxn() — outbox entry INSERTED for '
      '$entityType/$entityId op=$op',
    );
  }

  /// Read pending outbox entries for sync drain.
  Future<List<Map<String, Object?>>> readOutbox({int limit = 100}) async {
    final rows = await _db.query(
      WidgetTables.syncOutbox,
      orderBy: '${WidgetTables.colOutboxUpdatedAtMs} ASC',
      limit: limit,
    );
    AppLogging.sync(
      '[WidgetStore] readOutbox() — ${rows.length} pending entries '
      '(limit=$limit)',
    );
    return rows;
  }

  /// Mark an outbox entry as sent (delete it).
  Future<void> removeOutboxEntry(int id) async {
    await _db.delete(
      WidgetTables.syncOutbox,
      where: '${WidgetTables.colOutboxId} = ?',
      whereArgs: [id],
    );
    AppLogging.sync(
      '[WidgetStore] removeOutboxEntry() — removed outbox id=$id',
    );
  }

  /// Record a failed outbox attempt.
  Future<void> markOutboxAttemptFailed(int id, String error) async {
    await _db.rawUpdate(
      'UPDATE ${WidgetTables.syncOutbox} SET '
      '${WidgetTables.colOutboxAttemptCount} = '
      '${WidgetTables.colOutboxAttemptCount} + 1, '
      '${WidgetTables.colOutboxLastError} = ? '
      'WHERE ${WidgetTables.colOutboxId} = ?',
      [error, id],
    );
    AppLogging.sync(
      '[WidgetStore] markOutboxAttemptFailed() — id=$id error=$error',
    );
  }

  /// Get the count of pending outbox entries.
  Future<int> get outboxCount async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${WidgetTables.syncOutbox}',
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    AppLogging.sync('[WidgetStore] outboxCount = $count');
    return count;
  }

  // ---------------------------------------------------------------------------
  // Sync state helpers
  // ---------------------------------------------------------------------------

  /// Get a sync state value by key.
  Future<String?> getSyncState(String key) async {
    final rows = await _db.query(
      WidgetTables.syncState,
      where: '${WidgetTables.colSyncKey} = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) {
      AppLogging.sync('[WidgetStore] getSyncState($key) = null (no entry)');
      return null;
    }
    final val = rows.first[WidgetTables.colSyncValue] as String?;
    AppLogging.sync('[WidgetStore] getSyncState($key) = $val');
    return val;
  }

  /// Set a sync state value.
  Future<void> setSyncState(String key, String value) async {
    await _db.insert(WidgetTables.syncState, {
      WidgetTables.colSyncKey: key,
      WidgetTables.colSyncValue: value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    AppLogging.sync('[WidgetStore] setSyncState($key, $value)');
  }

  // ---------------------------------------------------------------------------
  // Export / Import (JSON)
  // ---------------------------------------------------------------------------

  /// Export all widget schemas as a JSON string.
  String toJsonString() {
    final all = getAll();
    return jsonEncode(all.map((w) => w.toJson()).toList());
  }

  /// Parse a JSON string into a list of widget schemas.
  ///
  /// Does not modify the store — use [bulkImport] to persist.
  static List<WidgetSchema> parseJson(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    return list
        .map((item) => WidgetSchema.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
