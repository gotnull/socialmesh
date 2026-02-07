// SPDX-License-Identifier: GPL-3.0-or-later

// Automation Cloud Sync Service — syncs automations across devices.
//
// Uses the same outbox + watermark pattern proven in NodeDexSyncService:
// - Local mutations write to SQLite and enqueue outbox records
// - This service drains the outbox when Cloud Sync is enabled
//   and network is available
// - Pull updates fetch remote changes since the last watermark
//   and apply them to SQLite
//
// Firestore collection: users/{uid}/automations_sync/{docId}

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/logging.dart';
import '../../../services/sync/sync_contract.dart';
import '../../../services/sync/sync_diagnostics.dart';
import '../../../services/sync/sync_probe_result.dart';
import '../models/automation.dart';
import 'automation_sqlite_store.dart';

/// Firestore collection for Automation sync data.
const String _firestoreCollection = 'automations_sync';

/// Sync state key prefix for last pull watermark.
///
/// The actual key is per-uid: `automations_last_pull_ms_<uid>` to prevent
/// watermark leaking between users on the same device.
const String _lastPullWatermarkPrefix = 'automations_last_pull_ms';

/// Build the per-uid watermark key.
String _watermarkKey(String uid) => '${_lastPullWatermarkPrefix}_$uid';

/// Maximum outbox entries to drain per cycle.
const int _outboxDrainBatchSize = 50;

/// Maximum retries for a single outbox entry before skipping.
const int _maxOutboxRetries = 5;

/// Log a sync message with `[SYNC]` prefix.
void _syncLog(String message, {bool verbose = false}) {
  if (verbose) return; // Verbose logging controlled by caller
  AppLogging.automations('[SYNC] $message');
}

/// Log a sync error with `[SYNC]` prefix.
void _syncLogError(String message, [Object? error, StackTrace? stack]) {
  AppLogging.automations(
    '[SYNC] ERROR: $message${error != null ? ' — $error' : ''}',
  );
}

/// Cloud Sync service for Automation data.
///
/// Manages the bidirectional sync between the local SQLite store
/// and Firestore. The service is designed to be:
/// - Optional: does nothing when Cloud Sync is disabled
/// - Offline-first: all data lives in SQLite first
/// - Conflict-safe: uses last-write-wins at the item level
/// - Non-blocking: sync runs in the background
class AutomationSyncService {
  final AutomationSqliteStore _store;

  Timer? _syncTimer;
  bool _isSyncing = false;

  /// Whether an outbox drain is currently in progress.
  ///
  /// Prevents concurrent drains from reading overlapping outbox entries
  /// and uploading them to Firestore multiple times.
  bool _isDraining = false;

  /// Whether cloud sync is currently enabled.
  bool _enabled = false;

  /// Callback invoked after a sync pull applies remote entries to the
  /// local store. The argument is the number of entries applied.
  ///
  /// The Automations notifier sets this so it can reload its in-memory
  /// state after remote data arrives.
  void Function(int appliedCount)? onPullApplied;

  /// Sync interval for periodic drain and pull.
  static const Duration _syncInterval = Duration(minutes: 2);

  AutomationSyncService(this._store);

  /// Diagnostics tracker for sync observability.
  final SyncDiagnostics _diagnostics = SyncDiagnostics.instance;

  /// Enable or disable cloud sync.
  ///
  /// When enabled, starts periodic sync. When disabled,
  /// stops syncing and disables outbox enqueuing on the store.
  void setEnabled(bool enabled) {
    final wasEnabled = _enabled;
    _enabled = enabled;
    _store.syncEnabled = enabled;
    _diagnostics.recordEntitlementState(enabled);

    _syncLog(
      'setEnabled: $wasEnabled → $enabled '
      '(store.syncEnabled=${_store.syncEnabled})',
    );

    if (enabled) {
      _startPeriodicSync();
      _syncLog('Sync engine STARTED (interval: ${_syncInterval.inSeconds}s)');
    } else {
      _stopPeriodicSync();
      _syncLog('Sync engine STOPPED');
    }
  }

  /// Whether sync is currently enabled.
  bool get isEnabled => _enabled;

  /// Trigger a one-shot sync cycle (drain outbox + pull updates).
  Future<void> syncNow() async {
    if (!_enabled) {
      _syncLog('syncNow: skipped — sync not enabled');
      return;
    }
    _syncLog('syncNow: triggering manual sync cycle');
    await _runSyncCycle();
  }

  /// Drain the outbox immediately without pulling.
  ///
  /// Call this after user-initiated mutations (add, edit, delete automation)
  /// to ensure the change reaches Firestore promptly rather than
  /// waiting for the next periodic cycle.
  ///
  /// If a drain is already in progress (from a sync cycle or another
  /// drainOutboxNow call), this is a no-op to avoid reading overlapping
  /// outbox entries and uploading them to Firestore multiple times.
  Future<void> drainOutboxNow() async {
    if (!_enabled) {
      _syncLog('drainOutboxNow: skipped — sync not enabled');
      return;
    }

    if (_isDraining) {
      _syncLog('drainOutboxNow: skipped — drain already in progress');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _syncLog('drainOutboxNow: skipped — no authenticated user');
      return;
    }

    _syncLog(
      'drainOutboxNow: starting immediate drain for '
      'uid=${user.uid.substring(0, 8)}...',
    );

    try {
      await _drainOutbox(user.uid);
      _syncLog('drainOutboxNow: complete');
    } catch (e, stack) {
      _syncLogError('drainOutboxNow failed', e, stack);
    }
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

    final cycleStart = DateTime.now();
    _syncLog('--- Sync cycle START ---');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _syncLog('Sync cycle: no authenticated user — aborting');
        return;
      }

      _syncLog(
        'Sync cycle: uid=${user.uid.substring(0, 8)}... '
        'enabled=$_enabled store.syncEnabled=${_store.syncEnabled}',
      );

      // Initial push: if this is the first sync for this user (no watermark),
      // enqueue any local automations that exist in SQLite but were never
      // outboxed. This handles the case where automations were saved before
      // Cloud Sync was activated (syncEnabled was false at save time).
      await _ensureInitialPushIfNeeded(user.uid);

      await _drainOutbox(user.uid);
      await _pullUpdates(user.uid);
      _diagnostics.recordSyncCycleComplete();

      final elapsed = DateTime.now().difference(cycleStart).inMilliseconds;
      _syncLog('--- Sync cycle COMPLETE (${elapsed}ms) ---');
    } catch (e, stack) {
      final elapsed = DateTime.now().difference(cycleStart).inMilliseconds;
      _syncLogError('Sync cycle FAILED after ${elapsed}ms', e, stack);
    } finally {
      _isSyncing = false;
    }
  }

  /// Ensure all local automations are enqueued for sync on the very first cycle.
  ///
  /// When the sync service starts for the first time (no watermark for this
  /// user), any automations already in SQLite were saved before sync was active.
  /// Those saves had [syncEnabled] = false, so no outbox entries were created.
  /// This method detects that situation and enqueues everything once.
  Future<void> _ensureInitialPushIfNeeded(String userId) async {
    final wmKey = _watermarkKey(userId);
    final existingWatermark = await _store.getSyncState(wmKey);
    if (existingWatermark != null) return; // not the first sync

    final localCount = _store.count;
    if (localCount == 0) return; // nothing local to push

    final outboxCount = await _store.outboxCount;
    if (outboxCount > 0) return; // outbox already has entries (e.g. migration)

    _syncLog(
      'Initial push: first sync for uid=${userId.substring(0, 8)}... '
      '— enqueuing $localCount local automations to outbox',
    );

    final enqueued = await _store.enqueueAllForSync();
    _syncLog('Initial push: enqueued $enqueued automations');
  }

  // ---------------------------------------------------------------------------
  // Outbox drain (push local changes to Firestore)
  // ---------------------------------------------------------------------------

  /// Drain pending outbox entries to Firestore.
  Future<void> _drainOutbox(String userId) async {
    if (_isDraining) {
      _syncLog('Drain: skipped — another drain already in progress');
      return;
    }
    _isDraining = true;

    try {
      await _drainOutboxInner(userId);
    } finally {
      _isDraining = false;
    }
  }

  /// Inner drain implementation, called only when [_isDraining] is held.
  Future<void> _drainOutboxInner(String userId) async {
    final outboxEntries = await _store.readOutbox(limit: _outboxDrainBatchSize);

    if (outboxEntries.isEmpty) return;

    final collectionPath = 'users/$userId/$_firestoreCollection';
    _syncLog(
      'Drain: ${outboxEntries.length} outbox entries to push '
      '→ $collectionPath',
    );

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection(_firestoreCollection);

    int successCount = 0;
    int failCount = 0;
    int skippedCount = 0;

    for (final row in outboxEntries) {
      final id = row['id'] as int;
      final entityType = row['entity_type'] as String;
      final entityId = row['entity_id'] as String;
      final op = row['op'] as String;
      final payloadJson = row['payload_json'] as String;
      final attemptCount = row['attempt_count'] as int? ?? 0;

      if (attemptCount >= _maxOutboxRetries) {
        _syncLog(
          'Drain: SKIPPING outbox[$id] $entityType/$entityId '
          '— max retries ($attemptCount) reached',
        );
        await _store.removeOutboxEntry(id);
        skippedCount++;
        continue;
      }

      // Firestore doc ID: automation_<uuid>
      final docId = '${entityType}_$entityId';

      try {
        final nowMs = DateTime.now().millisecondsSinceEpoch;

        if (op == 'delete') {
          await collection.doc(docId).set({
            'deleted': true,
            'updated_at_ms': nowMs,
            'entity_type': entityType,
            'entity_id': entityId,
          }, SetOptions(merge: true));
        } else {
          final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
          await collection.doc(docId).set({
            'data': payload,
            'deleted': false,
            'updated_at_ms': nowMs,
            'entity_type': entityType,
            'entity_id': entityId,
          }, SetOptions(merge: true));
        }

        await _store.removeOutboxEntry(id);
        _diagnostics.recordUploadSuccess(SyncType.automations);
        successCount++;
      } catch (e, stack) {
        _syncLogError(
          'Drain: FAILED outbox[$id] $entityType/$entityId '
          'doc=$docId attempt=${attemptCount + 1}: $e',
          null,
          stack,
        );
        await _store.markOutboxAttemptFailed(id, e.toString());
        _diagnostics.recordError(
          SyncType.automations,
          'Outbox push failed for $entityType/$entityId: $e',
        );
        failCount++;
      }
    }

    _syncLog(
      'Drain: complete — '
      'success=$successCount fail=$failCount skipped=$skippedCount',
    );
  }

  // ---------------------------------------------------------------------------
  // Pull updates from Firestore
  // ---------------------------------------------------------------------------

  /// Pull remote changes since the last watermark.
  Future<void> _pullUpdates(String userId) async {
    final collectionPath = 'users/$userId/$_firestoreCollection';

    final wmKey = _watermarkKey(userId);

    try {
      final lastPullStr = await _store.getSyncState(wmKey);
      final lastPullMs = lastPullStr != null ? int.tryParse(lastPullStr) : null;

      _syncLog(
        'Pull: querying $collectionPath '
        'since watermark=${lastPullMs ?? "NONE (first pull)"}',
      );

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
        return;
      }

      _syncLog('Pull: fetched ${snapshot.docs.length} remote documents');

      int maxPullMs = lastPullMs ?? 0;
      final remoteAutomations = <Automation>[];
      final remoteDeletedIds = <String>[];
      int parseErrors = 0;

      for (final doc in snapshot.docs) {
        final docData = doc.data();
        final entityType = docData['entity_type'] as String?;
        final entityId = docData['entity_id'] as String?;
        final updatedAtMs = docData['updated_at_ms'] as int? ?? 0;
        final deleted = docData['deleted'] as bool? ?? false;

        if (updatedAtMs > maxPullMs) {
          maxPullMs = updatedAtMs;
        }

        if (deleted) {
          if (entityId != null) {
            remoteDeletedIds.add(entityId);
          }
          continue;
        }

        if (entityType == 'automation') {
          final data = docData['data'] as Map<String, dynamic>?;
          if (data != null) {
            try {
              final automation = Automation.fromJson(data);
              remoteAutomations.add(automation);
            } catch (e) {
              parseErrors++;
              _syncLogError(
                'Pull: failed to parse automation from doc=${doc.id}',
                e,
              );
            }
          }
        }
      }

      _syncLog(
        'Pull: parsed ${remoteAutomations.length} automations, '
        '${remoteDeletedIds.length} deleted, $parseErrors parse errors',
      );

      // Apply deletions
      for (final deletedId in remoteDeletedIds) {
        await _store.applySyncDeletion(deletedId);
      }

      // Apply upserts
      if (remoteAutomations.isNotEmpty) {
        _syncLog(
          'Pull: applying ${remoteAutomations.length} automations '
          'via applySyncPull',
        );
        final applied = await _store.applySyncPull(remoteAutomations);
        _diagnostics.recordPullApplied(SyncType.automations, count: applied);
        _syncLog('Pull: applied $applied automations to local store');

        // Notify the notifier so it can reload its in-memory state.
        onPullApplied?.call(applied + remoteDeletedIds.length);
      } else if (remoteDeletedIds.isNotEmpty) {
        // Notify even if only deletions were applied
        onPullApplied?.call(remoteDeletedIds.length);
      }

      // Update watermark (per-uid so user switches don't leak).
      await _store.setSyncState(wmKey, maxPullMs.toString());

      _syncLog(
        'Pull: complete — ${remoteAutomations.length} upserts, '
        '${remoteDeletedIds.length} deletions, '
        'new watermark=$maxPullMs',
      );
    } catch (e, stack) {
      _syncLogError('Pull FAILED from $collectionPath', e, stack);
      _diagnostics.recordError(SyncType.automations, 'Pull error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Sync Probe — deterministic end-to-end sync validation
  // ---------------------------------------------------------------------------

  /// Run a deterministic end-to-end sync probe for Automations.
  ///
  /// This creates a test automation, enqueues it, drains to Firestore,
  /// pulls it back, and verifies the round-trip. The result is logged with
  /// a `[SYNC] PROBE_RESULT` line for easy grepping.
  ///
  /// Use this to diagnose sync failures without guessing.
  Future<SyncProbeResult> runSyncProbe() async {
    const probeId = 'sync_probe_automation_00000000';
    const probeName = 'Sync Probe Test Automation';
    const probeDescription = 'sync_probe_verify';
    final stages = <String, String>{};
    final logs = <String>[];

    void probeLog(String msg) {
      logs.add(msg);
      _syncLog('PROBE: $msg');
    }

    probeLog('=== AUTOMATION SYNC PROBE START ===');

    // Stage A: Check entitlement
    probeLog('Stage A: Checking entitlement...');
    if (!_enabled) {
      probeLog('Stage A: FAIL — sync not enabled (entitlement=$_enabled)');
      stages['A'] = 'FAIL: sync not enabled';
      return SyncProbeResult.failed(
        stage: 'A',
        reason: 'sync not enabled',
        stages: stages,
        logs: logs,
        domain: 'Automations',
      );
    }
    stages['A'] =
        'OK: enabled=$_enabled store.syncEnabled=${_store.syncEnabled}';
    probeLog('Stage A: OK');

    // Stage B: Check auth
    probeLog('Stage B: Checking Firebase auth...');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      probeLog('Stage B: FAIL — no authenticated user');
      stages['B'] = 'FAIL: no authenticated user';
      return SyncProbeResult.failed(
        stage: 'B',
        reason: 'no authenticated user',
        stages: stages,
        logs: logs,
        domain: 'Automations',
      );
    }
    final uid = user.uid;
    stages['B'] = 'OK: uid=${uid.substring(0, 8)}...';
    probeLog('Stage B: OK — uid=${uid.substring(0, 8)}...');

    // Stage C: Create test automation locally
    probeLog('Stage C: Creating test automation id=$probeId...');
    try {
      final probeAutomation = Automation(
        id: probeId,
        name: probeName,
        description: probeDescription,
        enabled: false,
        trigger: const AutomationTrigger(type: TriggerType.manual),
        actions: const [AutomationAction(type: ActionType.logEvent)],
      );
      await _store.save(probeAutomation);
      stages['C'] = 'OK: automation saved to SQLite';
      probeLog('Stage C: OK — automation saved');
    } catch (e) {
      probeLog('Stage C: FAIL — $e');
      stages['C'] = 'FAIL: $e';
      return SyncProbeResult.failed(
        stage: 'C',
        reason: '$e',
        stages: stages,
        logs: logs,
        domain: 'Automations',
      );
    }

    // Stage D: Check outbox
    probeLog('Stage D: Checking outbox...');
    try {
      final outboxCount = await _store.outboxCount;
      if (outboxCount == 0) {
        probeLog(
          'Stage D: WARN — outbox empty after save. '
          'syncEnabled=${_store.syncEnabled}',
        );
        stages['D'] = 'WARN: outbox empty (syncEnabled=${_store.syncEnabled})';
      } else {
        stages['D'] = 'OK: outbox has $outboxCount entries';
        probeLog('Stage D: OK — $outboxCount entries in outbox');
      }
    } catch (e) {
      probeLog('Stage D: FAIL — $e');
      stages['D'] = 'FAIL: $e';
    }

    // Stage E: Drain outbox (upload)
    probeLog('Stage E: Draining outbox to Firestore...');
    try {
      await _drainOutbox(uid);
      final remainingOutbox = await _store.outboxCount;
      stages['E'] = 'OK: drain complete, remaining=$remainingOutbox';
      probeLog('Stage E: OK — remaining outbox=$remainingOutbox');
    } catch (e) {
      probeLog('Stage E: FAIL — $e');
      stages['E'] = 'FAIL: $e';
      return SyncProbeResult.failed(
        stage: 'E',
        reason: '$e',
        stages: stages,
        logs: logs,
        domain: 'Automations',
      );
    }

    // Stage F: Verify document exists in Firestore
    probeLog('Stage F: Verifying document in Firestore...');
    final docId = 'automation_$probeId';
    final docPath = 'users/$uid/$_firestoreCollection/$docId';
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(_firestoreCollection)
          .doc(docId);
      final docSnapshot = await docRef.get();

      if (!docSnapshot.exists) {
        probeLog('Stage F: FAIL — doc not found at $docPath');
        stages['F'] = 'FAIL: doc not found at $docPath';
        return SyncProbeResult.failed(
          stage: 'F',
          reason: 'doc not found at $docPath',
          stages: stages,
          logs: logs,
          domain: 'Automations',
        );
      }

      final docData = docSnapshot.data()!;
      final remoteData = docData['data'] as Map<String, dynamic>?;
      probeLog(
        'Stage F: OK — doc exists at $docPath '
        'updated_at_ms=${docData['updated_at_ms']} '
        'has_data=${remoteData != null}',
      );
      stages['F'] = 'OK: doc exists at $docPath';
    } catch (e) {
      probeLog('Stage F: FAIL — $e');
      stages['F'] = 'FAIL: $e';
      return SyncProbeResult.failed(
        stage: 'F',
        reason: '$e',
        stages: stages,
        logs: logs,
        domain: 'Automations',
      );
    }

    // Stage G: Reset watermark and pull
    probeLog('Stage G: Pulling from Firestore...');
    try {
      await _store.setSyncState(_watermarkKey(uid), '0');
      await _pullUpdates(uid);
      stages['G'] = 'OK: pull complete';
      probeLog('Stage G: OK');
    } catch (e) {
      probeLog('Stage G: FAIL — $e');
      stages['G'] = 'FAIL: $e';
      return SyncProbeResult.failed(
        stage: 'G',
        reason: '$e',
        stages: stages,
        logs: logs,
        domain: 'Automations',
      );
    }

    // Stage H: Verify automation exists locally after pull
    probeLog('Stage H: Verifying local automation after pull...');
    try {
      final localAutomation = _store.getById(probeId);
      if (localAutomation == null) {
        probeLog('Stage H: FAIL — automation not found in local store');
        stages['H'] = 'FAIL: automation not in local store after pull';
        return SyncProbeResult.failed(
          stage: 'H',
          reason: 'automation not in local store after pull',
          stages: stages,
          logs: logs,
          domain: 'Automations',
        );
      }

      final nameMatch = localAutomation.name == probeName;
      final descMatch = localAutomation.description == probeDescription;
      probeLog(
        'Stage H: local automation found — '
        'name=${localAutomation.name} (match=$nameMatch) '
        'description=${localAutomation.description} (match=$descMatch)',
      );

      if (!nameMatch || !descMatch) {
        stages['H'] = 'FAIL: data mismatch name=$nameMatch desc=$descMatch';
        return SyncProbeResult.failed(
          stage: 'H',
          reason: 'data mismatch name=$nameMatch desc=$descMatch',
          stages: stages,
          logs: logs,
          domain: 'Automations',
        );
      }

      stages['H'] = 'OK: automation verified locally';
    } catch (e) {
      probeLog('Stage H: FAIL — $e');
      stages['H'] = 'FAIL: $e';
      return SyncProbeResult.failed(
        stage: 'H',
        reason: '$e',
        stages: stages,
        logs: logs,
        domain: 'Automations',
      );
    }

    // Stage I: Clean up probe data
    probeLog('Stage I: Cleaning up probe data...');
    try {
      await _store.delete(probeId);
      final cleanupDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(_firestoreCollection)
          .doc(docId);
      await cleanupDocRef.delete();
      stages['I'] = 'OK: cleaned up';
      probeLog('Stage I: OK — probe data cleaned up');
    } catch (e) {
      stages['I'] = 'WARN: cleanup failed: $e';
      probeLog('Stage I: WARN — cleanup failed: $e');
    }

    probeLog('=== AUTOMATION SYNC PROBE COMPLETE: ALL STAGES PASSED ===');
    _syncLog(
      'PROBE_RESULT ok=true stages=${stages.entries.map((e) => "${e.key}=${e.value}").join(", ")}',
    );

    return SyncProbeResult.success(
      stages: stages,
      logs: logs,
      domain: 'Automations',
    );
  }

  /// Dispose the sync service.
  ///
  /// Drains any remaining outbox entries before shutting down so that
  /// user mutations are not silently lost when the user signs out
  /// or the provider is disposed.
  Future<void> dispose() async {
    _syncLog('Disposing sync service...');
    _stopPeriodicSync();

    // Best-effort drain before shutdown
    if (_enabled) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final pendingCount = await _store.outboxCount;
          if (pendingCount > 0) {
            _syncLog(
              'Dispose: draining $pendingCount outbox entries before shutdown',
            );
            await _drainOutbox(user.uid);
          }
        }
      } catch (e) {
        _syncLogError('Dispose drain failed', e);
      }
    }

    _store.syncEnabled = false;
    onPullApplied = null;
    _syncLog('Sync service disposed');
  }
}
