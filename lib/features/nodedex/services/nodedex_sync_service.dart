// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Cloud Sync Service — syncs NodeDex data across devices.
//
// Uses an outbox pattern:
// - Local mutations write to SQLite and enqueue outbox records
// - This service drains the outbox when Cloud Sync is enabled
//   and network is available
// - Pull updates fetch remote changes since the last watermark
//   and apply them to SQLite
//
// If Cloud Sync is disabled, this service is a no-op.
// Everything remains fully offline-first.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/logging.dart';
import '../models/nodedex_entry.dart';
import 'nodedex_sqlite_store.dart';

/// Firestore collection for NodeDex sync data.
const String _firestoreCollection = 'nodedex_sync';

/// Sync state key for last pull watermark.
const String _lastPullWatermarkKey = 'nodedex_last_pull_ms';

/// Maximum outbox entries to drain per cycle.
const int _outboxDrainBatchSize = 50;

/// Maximum retries for a single outbox entry before skipping.
const int _maxOutboxRetries = 5;

/// Cloud Sync service for NodeDex data.
///
/// Manages the bidirectional sync between the local SQLite store
/// and Firestore. The service is designed to be:
/// - Optional: does nothing when Cloud Sync is disabled
/// - Offline-first: all data lives in SQLite first
/// - Conflict-safe: uses merge semantics consistent with local merge
/// - Non-blocking: sync runs in the background
class NodeDexSyncService {
  final NodeDexSqliteStore _store;

  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Whether cloud sync is currently enabled.
  bool _enabled = false;

  /// Sync interval for periodic drain and pull.
  static const Duration _syncInterval = Duration(minutes: 2);

  NodeDexSyncService(this._store);

  /// Enable or disable cloud sync.
  ///
  /// When enabled, starts periodic sync. When disabled,
  /// stops syncing and disables outbox enqueuing on the store.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    _store.syncEnabled = enabled;

    if (enabled) {
      _startPeriodicSync();
      AppLogging.nodeDex('NodeDexSync: Enabled');
    } else {
      _stopPeriodicSync();
      AppLogging.nodeDex('NodeDexSync: Disabled');
    }
  }

  /// Whether sync is currently enabled.
  bool get isEnabled => _enabled;

  /// Trigger a one-shot sync cycle (drain outbox + pull updates).
  Future<void> syncNow() async {
    if (!_enabled) return;
    await _runSyncCycle();
  }

  /// Start periodic sync.
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (_) {
      if (_enabled && !_isSyncing) {
        _runSyncCycle();
      }
    });
    // Also run immediately on enable.
    if (!_isSyncing) {
      _runSyncCycle();
    }
  }

  /// Stop periodic sync.
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Run a single sync cycle: drain outbox then pull.
  Future<void> _runSyncCycle() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        AppLogging.nodeDex('NodeDexSync: No authenticated user, skipping');
        return;
      }

      await _drainOutbox(user.uid);
      await _pullUpdates(user.uid);
    } catch (e) {
      AppLogging.nodeDex('NodeDexSync: Sync cycle error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Outbox drain (push local changes to Firestore)
  // ---------------------------------------------------------------------------

  /// Drain pending outbox entries to Firestore.
  Future<void> _drainOutbox(String userId) async {
    final outboxEntries = await _store.readOutbox(limit: _outboxDrainBatchSize);

    if (outboxEntries.isEmpty) return;

    AppLogging.nodeDex(
      'NodeDexSync: Draining ${outboxEntries.length} outbox entries',
    );

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(_firestoreCollection);

    for (final row in outboxEntries) {
      final id = row['id'] as int;
      final entityType = row['entity_type'] as String;
      final entityId = row['entity_id'] as String;
      final op = row['op'] as String;
      final payloadJson = row['payload_json'] as String;
      final attemptCount = row['attempt_count'] as int? ?? 0;

      if (attemptCount >= _maxOutboxRetries) {
        AppLogging.nodeDex(
          'NodeDexSync: Skipping outbox entry $id '
          '(max retries reached)',
        );
        await _store.removeOutboxEntry(id);
        continue;
      }

      try {
        final docId = _entityIdToDocId(entityType, entityId);

        if (op == 'delete') {
          await collection.doc(docId).set({
            'deleted': true,
            'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
            'entity_type': entityType,
            'entity_id': entityId,
          }, SetOptions(merge: true));
        } else {
          final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
          await collection.doc(docId).set({
            'data': payload,
            'deleted': false,
            'updated_at_ms': DateTime.now().millisecondsSinceEpoch,
            'entity_type': entityType,
            'entity_id': entityId,
          }, SetOptions(merge: true));
        }

        await _store.removeOutboxEntry(id);
      } catch (e) {
        AppLogging.nodeDex('NodeDexSync: Failed to push outbox entry $id: $e');
        await _store.markOutboxAttemptFailed(id, e.toString());
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Pull updates from Firestore
  // ---------------------------------------------------------------------------

  /// Pull remote changes since the last watermark.
  Future<void> _pullUpdates(String userId) async {
    try {
      final lastPullStr = await _store.getSyncState(_lastPullWatermarkKey);
      final lastPullMs = lastPullStr != null ? int.tryParse(lastPullStr) : null;

      final collection = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection(_firestoreCollection);

      Query<Map<String, dynamic>> query = collection.orderBy('updated_at_ms');

      if (lastPullMs != null) {
        query = query.where('updated_at_ms', isGreaterThan: lastPullMs);
      }

      final snapshot = await query.limit(200).get();

      if (snapshot.docs.isEmpty) {
        AppLogging.nodeDex('NodeDexSync: No remote updates');
        return;
      }

      AppLogging.nodeDex(
        'NodeDexSync: Pulled ${snapshot.docs.length} remote updates',
      );

      int maxPullMs = lastPullMs ?? 0;
      final remoteEntries = <NodeDexEntry>[];

      for (final doc in snapshot.docs) {
        final docData = doc.data();
        final entityType = docData['entity_type'] as String?;
        final updatedAtMs = docData['updated_at_ms'] as int? ?? 0;
        final deleted = docData['deleted'] as bool? ?? false;

        if (updatedAtMs > maxPullMs) {
          maxPullMs = updatedAtMs;
        }

        if (deleted) {
          // Handle remote deletions — not implemented for entries
          // since we use soft-delete locally. The merge will handle it.
          continue;
        }

        if (entityType == 'entry') {
          final data = docData['data'] as Map<String, dynamic>?;
          if (data != null) {
            try {
              remoteEntries.add(NodeDexEntry.fromJson(data));
            } catch (e) {
              AppLogging.nodeDex(
                'NodeDexSync: Failed to parse remote entry: $e',
              );
            }
          }
        }
      }

      if (remoteEntries.isNotEmpty) {
        await _store.applySyncPull(remoteEntries);
      }

      // Update watermark.
      await _store.setSyncState(_lastPullWatermarkKey, maxPullMs.toString());

      AppLogging.nodeDex(
        'NodeDexSync: Pull complete — ${remoteEntries.length} entries applied, '
        'watermark: $maxPullMs',
      );
    } catch (e) {
      AppLogging.nodeDex('NodeDexSync: Pull error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Convert an entity type and ID pair to a Firestore document ID.
  ///
  /// Firestore doc IDs cannot contain '/' so we use '-' as separator.
  String _entityIdToDocId(String entityType, String entityId) {
    return '${entityType}_${entityId.replaceAll(':', '-')}';
  }

  /// Dispose the sync service.
  void dispose() {
    _stopPeriodicSync();
    _store.syncEnabled = false;
  }
}
