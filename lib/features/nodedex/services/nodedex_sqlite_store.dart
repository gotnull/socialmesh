// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex SQLite Store — persistent local storage backed by SQLite.
//
// Replaces the SharedPreferences + JSON store with structured SQLite
// tables for better query performance, relational integrity, and
// Cloud Sync support via an outbox pattern.
//
// All public methods match the interface expected by NodeDexNotifier
// so the provider layer can switch stores transparently.

import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../models/import_preview.dart';
import '../models/nodedex_entry.dart';
import '../services/sigil_generator.dart';
import 'nodedex_database.dart';

/// SQLite-backed persistent storage for NodeDex entries.
///
/// Exposes the same capabilities as the legacy SharedPreferences store
/// while adding relational queries, efficient filtering, and sync
/// outbox support.
class NodeDexSqliteStore {
  final NodeDexDatabase _database;

  /// In-memory cache of entries for fast synchronous reads.
  Map<int, NodeDexEntry>? _cache;

  /// Whether sync outbox enqueuing is enabled.
  bool syncEnabled = false;

  /// Debounce timer for batched writes.
  Timer? _saveTimer;

  /// Pending entries to save in the next batch flush.
  final Map<int, NodeDexEntry> _pendingSaves = {};

  /// Debounce duration for batched saves.
  static const Duration _saveDebounceDuration = Duration(seconds: 2);

  /// Guard to prevent re-entrant flushes (which cause SQLite lock deadlock).
  bool _flushing = false;

  /// Tracks the active flush Future so dispose() can await it.
  Future<void>? _activeFlush;

  NodeDexSqliteStore(this._database);

  /// The underlying database instance.
  Database get _db => _database.database;

  /// Initialize the store by opening the database.
  Future<void> init() async {
    await _database.open();
    AppLogging.storage('NodeDexSqliteStore: Initialized');
  }

  /// Whether the database is open and ready.
  bool get isReady => _database.isOpen;

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// Load all non-deleted NodeDex entries from SQLite.
  Future<List<NodeDexEntry>> loadAll() async {
    if (_cache != null) return _cache!.values.toList();

    try {
      final rows = await _db.query(
        NodeDexTables.entries,
        where: '${NodeDexTables.colDeleted} = 0',
      );

      final entries = <int, NodeDexEntry>{};
      for (final row in rows) {
        final nodeNum = row[NodeDexTables.colNodeNum] as int;
        entries[nodeNum] = await _rowToEntry(row);
      }

      _cache = entries;
      AppLogging.storage(
        'NodeDexSqliteStore: Loaded ${entries.length} entries',
      );
      return entries.values.toList();
    } catch (e) {
      AppLogging.storage('NodeDexSqliteStore: Error loading entries: $e');
      _cache = {};
      return [];
    }
  }

  /// Load all entries as a map keyed by nodeNum.
  Future<Map<int, NodeDexEntry>> loadAllAsMap() async {
    if (_cache != null) return Map<int, NodeDexEntry>.from(_cache!);
    final entries = await loadAll();
    return {for (final e in entries) e.nodeNum: e};
  }

  /// Get a single entry by node number.
  Future<NodeDexEntry?> getEntry(int nodeNum) async {
    if (_cache != null) return _cache![nodeNum];
    await loadAll();
    return _cache?[nodeNum];
  }

  /// Check if a node exists in the NodeDex.
  Future<bool> hasEntry(int nodeNum) async {
    if (_cache != null) return _cache!.containsKey(nodeNum);
    await loadAll();
    return _cache?.containsKey(nodeNum) ?? false;
  }

  /// Get the total number of non-deleted entries.
  Future<int> get entryCount async {
    if (_cache != null) return _cache!.length;
    await loadAll();
    return _cache?.length ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Save a single entry (upsert) with debounced disk write.
  void saveEntry(NodeDexEntry entry) {
    _cache ??= {};
    _cache![entry.nodeNum] = entry;
    _pendingSaves[entry.nodeNum] = entry;
    _scheduleSave();
  }

  /// Save multiple entries at once (batch upsert).
  void saveEntries(List<NodeDexEntry> entries) {
    _cache ??= {};
    for (final entry in entries) {
      _cache![entry.nodeNum] = entry;
      _pendingSaves[entry.nodeNum] = entry;
    }
    _scheduleSave();
  }

  /// Save a single entry immediately without debouncing.
  Future<void> saveEntryImmediate(NodeDexEntry entry) async {
    _cache ??= {};
    _cache![entry.nodeNum] = entry;
    _pendingSaves[entry.nodeNum] = entry;
    await _flushPendingSaves();
  }

  /// Delete a single entry by node number.
  ///
  /// Uses a soft-delete (tombstone) for sync support.
  Future<void> deleteEntry(int nodeNum) async {
    _cache?.remove(nodeNum);
    _pendingSaves.remove(nodeNum);

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.update(
        NodeDexTables.entries,
        {NodeDexTables.colDeleted: 1, NodeDexTables.colUpdatedAtMs: now},
        where: '${NodeDexTables.colNodeNum} = ?',
        whereArgs: [nodeNum],
      );

      if (syncEnabled) {
        await _enqueueOutbox('entry', 'node:$nodeNum', 'delete', '{}');
      }

      AppLogging.storage('NodeDexSqliteStore: Soft-deleted node $nodeNum');
    } catch (e) {
      AppLogging.storage('NodeDexSqliteStore: Error deleting entry: $e');
    }
  }

  /// Clear all NodeDex entries (hard delete everything).
  Future<void> clearAll() async {
    _cache = {};
    _pendingSaves.clear();
    _cancelPendingSave();

    try {
      await _db.transaction((txn) async {
        await txn.delete(NodeDexTables.syncOutbox);
        await txn.delete(NodeDexTables.coSeenEdges);
        await txn.delete(NodeDexTables.seenRegions);
        await txn.delete(NodeDexTables.encounters);
        await txn.delete(NodeDexTables.entries);
      });
      AppLogging.storage('NodeDexSqliteStore: Cleared all entries');
    } catch (e) {
      AppLogging.storage('NodeDexSqliteStore: Error clearing: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Social tag and user note
  // ---------------------------------------------------------------------------

  /// Set the social tag for a node.
  Future<void> setSocialTag(int nodeNum, NodeSocialTag? tag) async {
    final entry = _cache?[nodeNum];
    if (entry == null) return;

    final updated = tag != null
        ? entry.copyWith(socialTag: tag)
        : entry.copyWith(clearSocialTag: true);
    saveEntry(updated);
  }

  /// Set the user note for a node.
  Future<void> setUserNote(int nodeNum, String? note) async {
    final entry = _cache?[nodeNum];
    if (entry == null) return;

    final trimmed = note?.trim();
    final updated = (trimmed == null || trimmed.isEmpty)
        ? entry.copyWith(clearUserNote: true)
        : entry.copyWith(
            userNote: trimmed.length > 280
                ? trimmed.substring(0, 280)
                : trimmed,
          );
    saveEntry(updated);
  }

  // ---------------------------------------------------------------------------
  // Batch / flush internals
  // ---------------------------------------------------------------------------

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, _flushPendingSaves);
  }

  void _cancelPendingSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Flush all pending saves to SQLite in a single transaction.
  Future<void> _flushPendingSaves() async {
    _cancelPendingSave();
    if (_pendingSaves.isEmpty) return;
    if (!_database.isOpen) {
      _pendingSaves.clear();
      return;
    }
    if (_flushing) {
      // Re-schedule so pending entries are not lost.
      _scheduleSave();
      return;
    }
    _flushing = true;

    _cache ??= {};
    for (final entry in _pendingSaves.entries) {
      _cache![entry.key] = entry.value;
    }

    final toWrite = Map<int, NodeDexEntry>.from(_pendingSaves);
    _pendingSaves.clear();

    final completer = Completer<void>();
    _activeFlush = completer.future;

    try {
      await _db.transaction((txn) async {
        for (final entry in toWrite.values) {
          await _upsertEntryInTxn(txn, entry);
        }
      });
      AppLogging.debug(
        'NodeDexSqliteStore: Flushed ${toWrite.length} pending saves',
      );
    } catch (e) {
      AppLogging.storage('NodeDexSqliteStore: Error flushing saves: $e');
    } finally {
      _flushing = false;
      completer.complete();
      _activeFlush = null;
    }
  }

  /// Force flush any pending saves.
  Future<void> flush() async {
    // Wait for any in-flight flush to complete first.
    await _activeFlush;
    await _flushPendingSaves();
  }

  /// Dispose the store.
  Future<void> dispose() async {
    _cancelPendingSave();
    // Wait for any in-flight flush (e.g. from an unawaited onDispose callback).
    await _activeFlush;
    // Flush remaining pending saves.
    await _flushPendingSaves();
    _cache = null;
    await _database.close();
  }

  // ---------------------------------------------------------------------------
  // Internal: Entry upsert in transaction
  // ---------------------------------------------------------------------------

  /// Upsert a full NodeDexEntry and all its child rows within a transaction.
  Future<void> _upsertEntryInTxn(Transaction txn, NodeDexEntry entry) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Upsert the main entry row.
    await txn.insert(
      NodeDexTables.entries,
      _entryToRow(entry, now),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Replace encounters: delete old, insert current list.
    await txn.delete(
      NodeDexTables.encounters,
      where: '${NodeDexTables.colNodeNum} = ?',
      whereArgs: [entry.nodeNum],
    );
    for (final enc in entry.encounters) {
      await txn.insert(NodeDexTables.encounters, {
        NodeDexTables.colNodeNum: entry.nodeNum,
        NodeDexTables.colEncTsMs: enc.timestamp.millisecondsSinceEpoch,
        NodeDexTables.colEncDistance: enc.distanceMeters,
        NodeDexTables.colEncSnr: enc.snr?.toDouble(),
        NodeDexTables.colEncRssi: enc.rssi?.toDouble(),
        NodeDexTables.colEncLat: enc.latitude,
        NodeDexTables.colEncLon: enc.longitude,
        NodeDexTables.colEncCreatedAtMs: now,
      });
    }

    // Replace regions: delete old, insert current list.
    await txn.delete(
      NodeDexTables.seenRegions,
      where: '${NodeDexTables.colNodeNum} = ?',
      whereArgs: [entry.nodeNum],
    );
    for (final region in entry.seenRegions) {
      await txn.insert(NodeDexTables.seenRegions, {
        NodeDexTables.colNodeNum: entry.nodeNum,
        NodeDexTables.colRegionKey: region.regionId,
        NodeDexTables.colRegionLabel: region.label,
        NodeDexTables.colRegionFirstSeenMs:
            region.firstSeen.millisecondsSinceEpoch,
        NodeDexTables.colRegionLastSeenMs:
            region.lastSeen.millisecondsSinceEpoch,
        NodeDexTables.colRegionCount: region.encounterCount,
      });
    }

    // Upsert co-seen edges (canonical ordering: a < b).
    for (final coSeenEntry in entry.coSeenNodes.entries) {
      final other = coSeenEntry.key;
      final rel = coSeenEntry.value;
      final a = entry.nodeNum < other ? entry.nodeNum : other;
      final b = entry.nodeNum < other ? other : entry.nodeNum;

      await txn.insert(NodeDexTables.coSeenEdges, {
        NodeDexTables.colEdgeA: a,
        NodeDexTables.colEdgeB: b,
        NodeDexTables.colEdgeFirstSeenMs: rel.firstSeen.millisecondsSinceEpoch,
        NodeDexTables.colEdgeLastSeenMs: rel.lastSeen.millisecondsSinceEpoch,
        NodeDexTables.colEdgeCount: rel.count,
        NodeDexTables.colEdgeMessageCount: rel.messageCount,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // Enqueue sync outbox if enabled.
    if (syncEnabled) {
      final payload = jsonEncode(entry.toJson());
      await _enqueueOutboxInTxn(
        txn,
        'entry',
        'node:${entry.nodeNum}',
        'upsert',
        payload,
      );
    }
  }

  /// Convert an entry to a flat row map for the entries table.
  Map<String, Object?> _entryToRow(NodeDexEntry entry, int updatedAtMs) {
    return {
      NodeDexTables.colNodeNum: entry.nodeNum,
      NodeDexTables.colFirstSeenMs: entry.firstSeen.millisecondsSinceEpoch,
      NodeDexTables.colLastSeenMs: entry.lastSeen.millisecondsSinceEpoch,
      NodeDexTables.colEncounterCount: entry.encounterCount,
      NodeDexTables.colMaxDistance: entry.maxDistanceSeen,
      NodeDexTables.colBestSnr: entry.bestSnr,
      NodeDexTables.colBestRssi: entry.bestRssi,
      NodeDexTables.colMessageCount: entry.messageCount,
      NodeDexTables.colSocialTag: entry.socialTag?.index,
      NodeDexTables.colUserNote: entry.userNote,
      NodeDexTables.colSigilJson: entry.sigil != null
          ? jsonEncode(entry.sigil!.toJson())
          : jsonEncode(SigilGenerator.generate(entry.nodeNum).toJson()),
      NodeDexTables.colSchemaVersion: 1,
      NodeDexTables.colUpdatedAtMs: updatedAtMs,
      NodeDexTables.colDeleted: 0,
    };
  }

  /// Reconstruct a [NodeDexEntry] from a database row and its child rows.
  Future<NodeDexEntry> _rowToEntry(Map<String, Object?> row) async {
    final nodeNum = row[NodeDexTables.colNodeNum] as int;

    // Load encounters.
    final encRows = await _db.query(
      NodeDexTables.encounters,
      where: '${NodeDexTables.colNodeNum} = ?',
      whereArgs: [nodeNum],
      orderBy: '${NodeDexTables.colEncTsMs} ASC',
    );
    final encounters = encRows.map(_rowToEncounter).toList();

    // Load regions.
    final regionRows = await _db.query(
      NodeDexTables.seenRegions,
      where: '${NodeDexTables.colNodeNum} = ?',
      whereArgs: [nodeNum],
    );
    final regions = regionRows.map(_rowToRegion).toList();

    // Load co-seen edges for this node.
    final edgeRows = await _db.query(
      NodeDexTables.coSeenEdges,
      where: '${NodeDexTables.colEdgeA} = ? OR ${NodeDexTables.colEdgeB} = ?',
      whereArgs: [nodeNum, nodeNum],
    );
    final coSeen = <int, CoSeenRelationship>{};
    for (final eRow in edgeRows) {
      final a = eRow[NodeDexTables.colEdgeA] as int;
      final b = eRow[NodeDexTables.colEdgeB] as int;
      final other = a == nodeNum ? b : a;
      coSeen[other] = CoSeenRelationship(
        count: eRow[NodeDexTables.colEdgeCount] as int,
        firstSeen: DateTime.fromMillisecondsSinceEpoch(
          eRow[NodeDexTables.colEdgeFirstSeenMs] as int,
        ),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(
          eRow[NodeDexTables.colEdgeLastSeenMs] as int,
        ),
        messageCount: eRow[NodeDexTables.colEdgeMessageCount] as int? ?? 0,
      );
    }

    // Parse sigil.
    SigilData? sigil;
    final sigilStr = row[NodeDexTables.colSigilJson] as String?;
    if (sigilStr != null && sigilStr.isNotEmpty) {
      try {
        sigil = SigilData.fromJson(
          jsonDecode(sigilStr) as Map<String, dynamic>,
        );
      } catch (_) {
        sigil = SigilGenerator.generate(nodeNum);
      }
    } else {
      sigil = SigilGenerator.generate(nodeNum);
    }

    // Parse social tag.
    final tagIndex = row[NodeDexTables.colSocialTag] as int?;
    NodeSocialTag? socialTag;
    if (tagIndex != null &&
        tagIndex >= 0 &&
        tagIndex < NodeSocialTag.values.length) {
      socialTag = NodeSocialTag.values[tagIndex];
    }

    return NodeDexEntry(
      nodeNum: nodeNum,
      firstSeen: DateTime.fromMillisecondsSinceEpoch(
        row[NodeDexTables.colFirstSeenMs] as int,
      ),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(
        row[NodeDexTables.colLastSeenMs] as int,
      ),
      encounterCount: row[NodeDexTables.colEncounterCount] as int? ?? 1,
      maxDistanceSeen: (row[NodeDexTables.colMaxDistance] as num?)?.toDouble(),
      bestSnr: row[NodeDexTables.colBestSnr] as int?,
      bestRssi: row[NodeDexTables.colBestRssi] as int?,
      messageCount: row[NodeDexTables.colMessageCount] as int? ?? 0,
      socialTag: socialTag,
      userNote: row[NodeDexTables.colUserNote] as String?,
      encounters: encounters,
      seenRegions: regions,
      coSeenNodes: coSeen,
      sigil: sigil,
    );
  }

  EncounterRecord _rowToEncounter(Map<String, Object?> row) {
    return EncounterRecord(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        row[NodeDexTables.colEncTsMs] as int,
      ),
      distanceMeters: (row[NodeDexTables.colEncDistance] as num?)?.toDouble(),
      snr: (row[NodeDexTables.colEncSnr] as num?)?.toInt(),
      rssi: (row[NodeDexTables.colEncRssi] as num?)?.toInt(),
      latitude: (row[NodeDexTables.colEncLat] as num?)?.toDouble(),
      longitude: (row[NodeDexTables.colEncLon] as num?)?.toDouble(),
    );
  }

  SeenRegion _rowToRegion(Map<String, Object?> row) {
    return SeenRegion(
      regionId: row[NodeDexTables.colRegionKey] as String,
      label: row[NodeDexTables.colRegionLabel] as String? ?? '',
      firstSeen: DateTime.fromMillisecondsSinceEpoch(
        row[NodeDexTables.colRegionFirstSeenMs] as int,
      ),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(
        row[NodeDexTables.colRegionLastSeenMs] as int,
      ),
      encounterCount: row[NodeDexTables.colRegionCount] as int? ?? 1,
    );
  }

  // ---------------------------------------------------------------------------
  // Sync outbox
  // ---------------------------------------------------------------------------

  Future<void> _enqueueOutbox(
    String entityType,
    String entityId,
    String op,
    String payloadJson,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(NodeDexTables.syncOutbox, {
      NodeDexTables.colOutboxEntityType: entityType,
      NodeDexTables.colOutboxEntityId: entityId,
      NodeDexTables.colOutboxOp: op,
      NodeDexTables.colOutboxPayloadJson: payloadJson,
      NodeDexTables.colOutboxUpdatedAtMs: now,
      NodeDexTables.colOutboxAttemptCount: 0,
    });
  }

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
      NodeDexTables.syncOutbox,
      where:
          '${NodeDexTables.colOutboxEntityType} = ? AND '
          '${NodeDexTables.colOutboxEntityId} = ?',
      whereArgs: [entityType, entityId],
    );
    await txn.insert(NodeDexTables.syncOutbox, {
      NodeDexTables.colOutboxEntityType: entityType,
      NodeDexTables.colOutboxEntityId: entityId,
      NodeDexTables.colOutboxOp: op,
      NodeDexTables.colOutboxPayloadJson: payloadJson,
      NodeDexTables.colOutboxUpdatedAtMs: now,
      NodeDexTables.colOutboxAttemptCount: 0,
    });
  }

  /// Read pending outbox entries for sync drain.
  Future<List<Map<String, Object?>>> readOutbox({int limit = 100}) async {
    return _db.query(
      NodeDexTables.syncOutbox,
      orderBy: '${NodeDexTables.colOutboxUpdatedAtMs} ASC',
      limit: limit,
    );
  }

  /// Mark an outbox entry as sent (delete it).
  Future<void> removeOutboxEntry(int id) async {
    await _db.delete(
      NodeDexTables.syncOutbox,
      where: '${NodeDexTables.colOutboxId} = ?',
      whereArgs: [id],
    );
  }

  /// Record a failed outbox attempt.
  Future<void> markOutboxAttemptFailed(int id, String error) async {
    await _db.rawUpdate(
      'UPDATE ${NodeDexTables.syncOutbox} SET '
      '${NodeDexTables.colOutboxAttemptCount} = '
      '${NodeDexTables.colOutboxAttemptCount} + 1, '
      '${NodeDexTables.colOutboxLastError} = ? '
      'WHERE ${NodeDexTables.colOutboxId} = ?',
      [error, id],
    );
  }

  /// Get the count of pending outbox entries.
  Future<int> get outboxCount async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${NodeDexTables.syncOutbox}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Sync state helpers
  // ---------------------------------------------------------------------------

  /// Get a sync state value by key.
  Future<String?> getSyncState(String key) async {
    final rows = await _db.query(
      NodeDexTables.syncState,
      where: '${NodeDexTables.colSyncKey} = ?',
      whereArgs: [key],
    );
    if (rows.isEmpty) return null;
    return rows.first[NodeDexTables.colSyncValue] as String?;
  }

  /// Set a sync state value.
  Future<void> setSyncState(String key, String value) async {
    await _db.insert(NodeDexTables.syncState, {
      NodeDexTables.colSyncKey: key,
      NodeDexTables.colSyncValue: value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------------------------
  // Export / import
  // ---------------------------------------------------------------------------

  /// Export all entries as a JSON string.
  ///
  /// Produces the same format as the legacy SharedPreferences store
  /// for backward compatibility.
  Future<String?> exportJson() async {
    final entries = await loadAll();
    if (entries.isEmpty) return null;
    return NodeDexEntry.encodeList(entries);
  }

  /// Import entries from a JSON string with smart merge.
  Future<int> importJson(String jsonString) async {
    try {
      final imported = NodeDexEntry.decodeList(jsonString);
      if (imported.isEmpty) return 0;

      _cache ??= {};
      int mergedCount = 0;

      for (final entry in imported) {
        final existing = _cache![entry.nodeNum];
        if (existing != null) {
          _cache![entry.nodeNum] = existing.mergeWith(entry);
        } else {
          _cache![entry.nodeNum] = entry;
        }
        mergedCount++;
      }

      // Write all merged entries in a single transaction.
      await _db.transaction((txn) async {
        for (final entry in _cache!.values) {
          await _upsertEntryInTxn(txn, entry);
        }
      });

      AppLogging.storage('NodeDexSqliteStore: Imported $mergedCount entries');
      return mergedCount;
    } catch (e) {
      AppLogging.storage('NodeDexSqliteStore: Error importing: $e');
      return 0;
    }
  }

  /// Parse import JSON without modifying state.
  List<NodeDexEntry> parseImportJson(String jsonString) {
    try {
      return NodeDexEntry.decodeList(jsonString);
    } catch (e) {
      AppLogging.storage('NodeDexSqliteStore: Error parsing import: $e');
      return [];
    }
  }

  /// Build an [ImportPreview] against current local cache.
  Future<ImportPreview> previewImport(
    List<NodeDexEntry> importedEntries, {
    String Function(int nodeNum)? displayNameResolver,
  }) async {
    final local = await loadAllAsMap();
    return ImportPreview.build(
      importedEntries: importedEntries,
      localEntries: local,
      displayNameResolver: displayNameResolver,
    );
  }

  /// Apply an import using a specific merge strategy.
  Future<int> importWithMerge({
    required ImportPreview preview,
    required MergeStrategy strategy,
    Map<int, ConflictResolution> resolutions = const {},
  }) async {
    if (preview.isEmpty) return 0;

    _cache ??= {};

    final merged = ImportPreview.applyMerge(
      preview: preview,
      localEntries: Map<int, NodeDexEntry>.from(_cache!),
      strategy: strategy,
      resolutions: resolutions,
    );

    // Write all in a single transaction.
    await _db.transaction((txn) async {
      for (final entry in merged) {
        _cache![entry.nodeNum] = entry;
        await _upsertEntryInTxn(txn, entry);
      }
    });

    AppLogging.storage(
      'NodeDexSqliteStore: Import-merged ${merged.length} entries '
      'with strategy ${strategy.name}',
    );
    return merged.length;
  }

  // ---------------------------------------------------------------------------
  // Sync pull: apply remote changes
  // ---------------------------------------------------------------------------

  /// Apply a batch of remote entries from Cloud Sync pull.
  ///
  /// Uses conflict resolution rules:
  /// - firstSeen: min
  /// - lastSeen: max
  /// - encounterCount: max
  /// - userNote/socialTag: last-write-wins by updatedAtMs,
  ///   but prefer non-empty over empty when timestamps are equal
  /// - encounters: append-only, deduplicate by timestamp
  /// - regions: merge counts and min/max times
  /// - edges: merge counts and max lastSeen
  Future<int> applySyncPull(List<NodeDexEntry> remoteEntries) async {
    if (remoteEntries.isEmpty) return 0;

    _cache ??= {};
    int appliedCount = 0;

    await _db.transaction((txn) async {
      for (final remote in remoteEntries) {
        final local = _cache![remote.nodeNum];
        final merged = local != null ? local.mergeWith(remote) : remote;

        _cache![merged.nodeNum] = merged;
        await _upsertEntryInTxn(txn, merged);
        appliedCount++;
      }
    });

    AppLogging.storage(
      'NodeDexSqliteStore: Sync pull applied $appliedCount entries',
    );
    return appliedCount;
  }

  // ---------------------------------------------------------------------------
  // Bulk insert for migration
  // ---------------------------------------------------------------------------

  /// Insert a list of entries in a single transaction.
  ///
  /// Used by the SharedPreferences -> SQLite migration.
  /// Skips outbox enqueuing since this is a local-only operation.
  Future<void> bulkInsert(List<NodeDexEntry> entries) async {
    final prevSync = syncEnabled;
    syncEnabled = false;

    try {
      await _db.transaction((txn) async {
        for (final entry in entries) {
          await _upsertEntryInTxn(txn, entry);
        }
      });

      _cache ??= {};
      for (final entry in entries) {
        _cache![entry.nodeNum] = entry;
      }

      AppLogging.storage(
        'NodeDexSqliteStore: Bulk inserted ${entries.length} entries',
      );
    } finally {
      syncEnabled = prevSync;
    }
  }
}
