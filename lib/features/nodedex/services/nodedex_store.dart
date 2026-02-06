// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Store — persistent local storage for NodeDex entries.
//
// Uses SharedPreferences with JSON serialization, matching the existing
// storage pattern used by NodeStorageService and MessageStorageService.
// All operations are async and safe to call from any isolate context.
//
// Storage key: 'nodedex_entries'
// Format: JSON-encoded list of NodeDexEntry objects.
//
// The store handles:
// - Loading all entries on init
// - Saving individual entries (upsert)
// - Batch saving for performance
// - Deleting entries
// - Clearing all data
// - Atomic read-modify-write to prevent data races

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../models/nodedex_entry.dart';

/// Persistent storage for NodeDex entries.
///
/// Follows the same SharedPreferences + JSON pattern as
/// NodeStorageService and MessageStorageService. All writes
/// are debounced to avoid excessive disk I/O during rapid
/// node discovery events.
class NodeDexStore {
  SharedPreferences? _prefs;

  /// Storage key for all NodeDex entries.
  static const String _entriesKey = 'nodedex_entries';

  /// Storage key for NodeDex metadata (stats cache, version, etc.).
  static const String _metaKey = 'nodedex_meta';

  /// Current schema version for migration support.
  ///
  /// v1: Initial schema — coSeenNodes stored as `Map<int, int>`.
  /// v2: CoSeenRelationship model — coSeenNodes stored as `Map<int, object>`.
  ///     Migration is handled transparently by CoSeenRelationship.fromJson
  ///     which accepts both int (v1) and object (v2) values.
  static const int _schemaVersion = 2;

  /// Debounce timer for batched writes.
  Timer? _saveTimer;

  /// Pending entries to save in the next batch flush.
  final Map<int, NodeDexEntry> _pendingSaves = {};

  /// Debounce duration for batched saves.
  static const Duration _saveDebounceDuration = Duration(seconds: 2);

  /// In-memory cache of all entries for fast reads.
  Map<int, NodeDexEntry>? _cache;

  NodeDexStore();

  /// Initialize the store. Must be called before any other method.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> init() async {
    if (_prefs != null) return;
    _prefs = await SharedPreferences.getInstance();
    _ensureSchema();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError(
        'NodeDexStore not initialized. Call init() before accessing storage.',
      );
    }
    return _prefs!;
  }

  /// Ensure the schema version is current.
  ///
  /// If the stored version is older, migration logic runs here.
  /// Currently v1, so no migration is needed.
  void _ensureSchema() {
    final storedVersion = _preferences.getInt(_metaKey);
    if (storedVersion == null || storedVersion < _schemaVersion) {
      _preferences.setInt(_metaKey, _schemaVersion);
      AppLogging.storage('NodeDexStore: Schema set to v$_schemaVersion');
    }
  }

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// Load all NodeDex entries from storage.
  ///
  /// Returns an empty list if no entries exist or if deserialization
  /// fails. Errors are logged but never thrown to callers.
  Future<List<NodeDexEntry>> loadAll() async {
    // Return from cache if available.
    if (_cache != null) {
      return _cache!.values.toList();
    }

    try {
      final jsonString = _preferences.getString(_entriesKey);
      if (jsonString == null || jsonString.isEmpty) {
        _cache = {};
        return [];
      }

      final entries = NodeDexEntry.decodeList(jsonString);
      _cache = {for (final e in entries) e.nodeNum: e};

      AppLogging.storage(
        'NodeDexStore: Loaded ${entries.length} entries from storage',
      );
      return entries;
    } catch (e) {
      AppLogging.storage('NodeDexStore: Error loading entries: $e');
      _cache = {};
      return [];
    }
  }

  /// Load all entries as a map keyed by nodeNum.
  ///
  /// More efficient than loadAll() when you need lookup by node number.
  Future<Map<int, NodeDexEntry>> loadAllAsMap() async {
    if (_cache != null) {
      return Map<int, NodeDexEntry>.from(_cache!);
    }

    final entries = await loadAll();
    return {for (final e in entries) e.nodeNum: e};
  }

  /// Get a single entry by node number.
  ///
  /// Returns null if the node has not been recorded in NodeDex.
  Future<NodeDexEntry?> getEntry(int nodeNum) async {
    if (_cache != null) {
      return _cache![nodeNum];
    }

    await loadAll();
    return _cache?[nodeNum];
  }

  /// Check if a node exists in the NodeDex.
  Future<bool> hasEntry(int nodeNum) async {
    if (_cache != null) {
      return _cache!.containsKey(nodeNum);
    }

    await loadAll();
    return _cache?.containsKey(nodeNum) ?? false;
  }

  /// Get the total number of entries.
  Future<int> get entryCount async {
    if (_cache != null) {
      return _cache!.length;
    }

    await loadAll();
    return _cache?.length ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Save a single entry (upsert).
  ///
  /// The save is debounced — the entry is queued and flushed to disk
  /// after a short delay. Multiple rapid saves are batched together.
  void saveEntry(NodeDexEntry entry) {
    // Update in-memory cache immediately.
    _cache ??= {};
    _cache![entry.nodeNum] = entry;

    // Queue for debounced disk write.
    _pendingSaves[entry.nodeNum] = entry;
    _scheduleSave();
  }

  /// Save multiple entries at once (batch upsert).
  ///
  /// More efficient than calling saveEntry() in a loop because
  /// it batches all entries into a single disk write.
  void saveEntries(List<NodeDexEntry> entries) {
    _cache ??= {};
    for (final entry in entries) {
      _cache![entry.nodeNum] = entry;
      _pendingSaves[entry.nodeNum] = entry;
    }
    _scheduleSave();
  }

  /// Save a single entry immediately without debouncing.
  ///
  /// Use this only when you need the write to be durable before
  /// proceeding (e.g., before app shutdown). Prefer [saveEntry]
  /// for normal operations.
  Future<void> saveEntryImmediate(NodeDexEntry entry) async {
    _cache ??= {};
    _cache![entry.nodeNum] = entry;
    _pendingSaves[entry.nodeNum] = entry;
    await _flushPendingSaves();
  }

  /// Delete a single entry by node number.
  Future<void> deleteEntry(int nodeNum) async {
    _cache?.remove(nodeNum);
    _pendingSaves.remove(nodeNum);

    try {
      await _writeAllToStorage();
      AppLogging.storage('NodeDexStore: Deleted entry for node $nodeNum');
    } catch (e) {
      AppLogging.storage('NodeDexStore: Error deleting entry: $e');
    }
  }

  /// Clear all NodeDex entries.
  ///
  /// This is destructive and cannot be undone. The in-memory cache
  /// and disk storage are both cleared.
  Future<void> clearAll() async {
    _cache = {};
    _pendingSaves.clear();
    _cancelPendingSave();

    try {
      await _preferences.remove(_entriesKey);
      AppLogging.storage('NodeDexStore: Cleared all entries');
    } catch (e) {
      AppLogging.storage('NodeDexStore: Error clearing entries: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Social tag operations
  // ---------------------------------------------------------------------------

  /// Set the social tag for a node.
  ///
  /// Pass null to clear the tag.
  Future<void> setSocialTag(int nodeNum, NodeSocialTag? tag) async {
    final entry = _cache?[nodeNum];
    if (entry == null) return;

    final updated = tag != null
        ? entry.copyWith(socialTag: tag)
        : entry.copyWith(clearSocialTag: true);

    saveEntry(updated);
  }

  /// Set the user note for a node.
  ///
  /// Pass null to clear the note.
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

  /// Schedule a debounced save.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, _flushPendingSaves);
  }

  /// Cancel any pending debounced save.
  void _cancelPendingSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Flush all pending saves to disk.
  ///
  /// Merges pending entries into the cache and writes the full
  /// cache to SharedPreferences as a single JSON string.
  Future<void> _flushPendingSaves() async {
    _cancelPendingSave();
    if (_pendingSaves.isEmpty) return;

    // Merge pending into cache (should already be there, but ensure).
    _cache ??= {};
    for (final entry in _pendingSaves.entries) {
      _cache![entry.key] = entry.value;
    }

    final count = _pendingSaves.length;
    _pendingSaves.clear();

    try {
      await _writeAllToStorage();
      AppLogging.debug('NodeDexStore: Flushed $count pending saves');
    } catch (e) {
      AppLogging.storage('NodeDexStore: Error flushing saves: $e');
    }
  }

  /// Write the entire cache to SharedPreferences.
  Future<void> _writeAllToStorage() async {
    if (_cache == null || _cache!.isEmpty) {
      await _preferences.remove(_entriesKey);
      return;
    }

    final jsonList = _cache!.values.map((e) => e.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _preferences.setString(_entriesKey, jsonString);
  }

  /// Force flush any pending saves.
  ///
  /// Call this before dispose or app shutdown to ensure all
  /// queued writes are persisted.
  Future<void> flush() async {
    await _flushPendingSaves();
  }

  /// Dispose the store, flushing any pending writes.
  ///
  /// After dispose, the store should not be used again without
  /// calling init().
  Future<void> dispose() async {
    await _flushPendingSaves();
    _cancelPendingSave();
    _cache = null;
    _prefs = null;
  }

  // ---------------------------------------------------------------------------
  // Export / import
  // ---------------------------------------------------------------------------

  /// Export all entries as a JSON string.
  ///
  /// Useful for backup, sharing, or cloud sync.
  Future<String?> exportJson() async {
    final entries = await loadAll();
    if (entries.isEmpty) return null;
    return NodeDexEntry.encodeList(entries);
  }

  /// Import entries from a JSON string.
  ///
  /// Merges with existing entries using [NodeDexEntry.mergeWith], which
  /// intelligently combines per-edge CoSeenRelationship histories,
  /// encounter logs, region records, and scalar metrics. New entries
  /// (not yet in the local store) are added directly.
  ///
  /// Returns the number of entries that were added or updated.
  Future<int> importJson(String jsonString) async {
    try {
      final imported = NodeDexEntry.decodeList(jsonString);
      if (imported.isEmpty) return 0;

      _cache ??= {};
      int mergedCount = 0;

      for (final entry in imported) {
        final existing = _cache![entry.nodeNum];
        if (existing != null) {
          // Smart merge: combines time ranges, metrics, co-seen
          // relationships, encounters, and regions intelligently.
          _cache![entry.nodeNum] = existing.mergeWith(entry);
        } else {
          _cache![entry.nodeNum] = entry;
        }
        mergedCount++;
      }

      await _writeAllToStorage();
      AppLogging.storage(
        'NodeDexStore: Imported $mergedCount entries '
        '(${imported.length} total in file)',
      );
      return mergedCount;
    } catch (e) {
      AppLogging.storage('NodeDexStore: Error importing entries: $e');
      return 0;
    }
  }
}
