// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Task Sync Service — syncs task transitions across devices.
//
// Uses the same outbox + drain pattern proven in AutomationSyncService
// and NodeDexSyncService:
// - Local transitions write to SQLite (append-only)
// - This service drains unsynced transitions when Cloud Sync is
//   enabled and network is available
// - Pull updates fetch remote transitions and reconcile via
//   TaskConflictResolver
//
// Firestore collection: orgs/{orgId}/task_transitions/{transitionId}
//
// The service integrates with the existing 2-minute drain cycle pattern.
// No parallel sync loops — each domain has its own independent timer.
//
// Logging gated behind TASK_SYNC_LOGGING_ENABLED.
//
// Spec: TASK_SYSTEM.md (Sprint 007/W3.1), Sprint 008/W4.2.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/logging.dart';
import '../../../services/sync/sync_diagnostics.dart';
import '../../../services/sync/sync_contract.dart';
import '../models/task.dart';
import '../models/task_transition.dart';
import 'task_conflict_resolver.dart';
import 'task_database.dart';

/// Maximum transitions to drain per cycle.
const int _taskOutboxDrainBatchSize = 50;

/// Maximum retries before skipping a transition push.
const int _taskMaxOutboxRetries = 5;

/// Cloud Sync service for task transition data.
///
/// Manages bidirectional sync between the local tasks SQLite database
/// and Firestore. Follows the existing outbox/drain pattern.
///
/// - Optional: does nothing when Cloud Sync is disabled.
/// - Offline-first: all data lives in SQLite first.
/// - Conflict-safe: uses [TaskConflictResolver] for reconciliation.
/// - Non-blocking: sync runs in the background.
///
/// Spec: TASK_SYSTEM.md — Offline Sync, Sprint 008/W4.2.
class TaskSyncService {
  final TaskDatabase _db;
  final TaskConflictResolver _resolver;

  Timer? _syncTimer;
  bool _isSyncing = false;
  bool _isDraining = false;
  bool _enabled = false;

  /// Current orgId for scoping Firestore reads/writes.
  String? _orgId;

  /// Callback invoked after a sync pull applies remote transitions.
  /// The argument is the number of transitions applied.
  void Function(int appliedCount)? onPullApplied;

  /// Sync interval for periodic drain and pull.
  static const Duration syncInterval = Duration(minutes: 2);

  /// Diagnostics tracker for sync observability.
  final SyncDiagnostics _diagnostics = SyncDiagnostics.instance;

  TaskSyncService({
    required this._db,
    this._resolver = const TaskConflictResolver(),
  });

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  /// Enable or disable cloud sync.
  ///
  /// [orgId] is required when enabling — all Firestore operations are
  /// scoped to `orgs/{orgId}/`.
  void setEnabled(bool enabled, {String? orgId}) {
    final wasEnabled = _enabled;
    _enabled = enabled;
    if (orgId != null) _orgId = orgId;

    _diagnostics.recordEntitlementState(enabled);

    _syncLog(
      'setEnabled: $wasEnabled -> $enabled '
      '(orgId=${_orgId ?? "null"})',
    );

    if (enabled) {
      _startPeriodicSync();
      _syncLog('Sync engine STARTED (interval: ${syncInterval.inSeconds}s)');
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
  /// Call this after user-initiated task transitions to push
  /// the change to Firestore promptly.
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

    final orgId = _orgId;
    if (orgId == null) {
      _syncLog('drainOutboxNow: skipped — no orgId');
      return;
    }

    _syncLog('drainOutboxNow: starting immediate drain');

    try {
      await _drainOutbox(orgId);
      _syncLog('drainOutboxNow: complete');
    } catch (e) {
      _syncLog('drainOutboxNow failed: $e');
    }
  }

  /// Dispose the service and cancel any periodic timer.
  void dispose() {
    _stopPeriodicSync();
  }

  // -------------------------------------------------------------------------
  // Periodic sync
  // -------------------------------------------------------------------------

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(syncInterval, (_) {
      if (_enabled && !_isSyncing) {
        _runSyncCycle();
      }
    });
    // Also run immediately on enable.
    if (!_isSyncing) {
      _runSyncCycle();
    }
  }

  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Run a single sync cycle: drain outbox then pull remote transitions.
  Future<void> _runSyncCycle() async {
    if (_isSyncing) return;
    _isSyncing = true;

    _syncLog('--- Sync cycle START ---');

    try {
      final user = FirebaseAuth.instance.currentUser;
      final orgId = _orgId;

      if (user == null || orgId == null) {
        _syncLog('Sync cycle skipped — no user or orgId');
        return;
      }

      await _drainOutbox(orgId);
      await _pullRemoteTransitions(orgId);

      _syncLog('--- Sync cycle COMPLETE ---');
    } catch (e) {
      _syncLog('Sync cycle ERROR: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // -------------------------------------------------------------------------
  // Push: drain unsynced transitions to Firestore
  // -------------------------------------------------------------------------

  Future<void> _drainOutbox(String orgId) async {
    if (_isDraining) {
      _syncLog('drain: skipped — already in progress');
      return;
    }
    _isDraining = true;

    try {
      final unsyncedTasks = await _db.getUnsyncedTasks();

      if (unsyncedTasks.isEmpty) {
        _syncLog('drain: no unsynced tasks');
        return;
      }

      _syncLog('drain: ${unsyncedTasks.length} unsynced task(s)');

      int successCount = 0;
      int failCount = 0;

      for (final task in unsyncedTasks) {
        final unsyncedTransitions = await _db.getUnsyncedTransitions(task.id);

        if (unsyncedTransitions.isEmpty) {
          // Task row changed but no unsynced transitions — just mark synced.
          await _db.markSynced(task.id, DateTime.now());
          continue;
        }

        if (unsyncedTransitions.length > _taskOutboxDrainBatchSize) {
          _syncLog(
            'drain: task ${task.id} has ${unsyncedTransitions.length} '
            'unsynced transitions, capping to $_taskOutboxDrainBatchSize',
          );
        }

        final batch = unsyncedTransitions.take(_taskOutboxDrainBatchSize);

        for (final transition in batch) {
          try {
            await _pushTransitionToFirestore(orgId, task, transition);
            _diagnostics.recordUploadSuccess(SyncType.taskTransition);
            successCount++;
          } catch (e) {
            _syncLog('drain: FAILED push transition ${transition.id}: $e');
            _diagnostics.recordError(
              SyncType.taskTransition,
              'Push failed for ${transition.id}: $e',
            );
            failCount++;

            if (failCount >= _taskMaxOutboxRetries) {
              _syncLog('drain: max failures reached, stopping drain');
              break;
            }
          }
        }

        // Mark the task as synced up to now.
        if (successCount > 0) {
          await _db.markSynced(task.id, DateTime.now());
        }
      }

      _syncLog('drain: complete (pushed=$successCount, failed=$failCount)');
    } finally {
      _isDraining = false;
    }
  }

  /// Pushes a single transition document to Firestore.
  Future<void> _pushTransitionToFirestore(
    String orgId,
    Task task,
    TaskTransition transition,
  ) async {
    final docRef = FirebaseFirestore.instance
        .collection('orgs')
        .doc(orgId)
        .collection('task_transitions')
        .doc(transition.id);

    await docRef.set({
      'id': transition.id,
      'taskId': transition.taskId,
      'fromState': transition.fromState.dbValue,
      'toState': transition.toState.dbValue,
      'actorId': transition.actorId,
      'note': transition.note,
      'timestamp': transition.timestamp.millisecondsSinceEpoch,
    });

    // Also upsert the task document.
    final taskDocRef = FirebaseFirestore.instance
        .collection('orgs')
        .doc(orgId)
        .collection('tasks')
        .doc(task.id);

    await taskDocRef.set(
      task.toMap()..remove('syncedAt'),
      SetOptions(merge: true),
    );
  }

  // -------------------------------------------------------------------------
  // Pull: fetch remote transitions and reconcile
  // -------------------------------------------------------------------------

  Future<void> _pullRemoteTransitions(String orgId) async {
    try {
      _syncLog('pull: fetching remote transitions for org=$orgId');

      // Query all remote transitions, ordered by timestamp.
      // In production, this would use a watermark to only fetch
      // transitions newer than the last pull.
      final snapshot = await FirebaseFirestore.instance
          .collection('orgs')
          .doc(orgId)
          .collection('task_transitions')
          .orderBy('timestamp')
          .get();

      if (snapshot.docs.isEmpty) {
        _syncLog('pull: no remote transitions');
        return;
      }

      _syncLog('pull: ${snapshot.docs.length} remote transition(s)');

      final remoteTransitions = <TaskTransition>[];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          remoteTransitions.add(
            TaskTransition(
              id: data['id'] as String,
              taskId: data['taskId'] as String,
              fromState: TaskState.fromDbValue(data['fromState'] as String),
              toState: TaskState.fromDbValue(data['toState'] as String),
              actorId: data['actorId'] as String,
              note: data['note'] as String?,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                data['timestamp'] as int,
              ),
            ),
          );
        } catch (e) {
          _syncLog('pull: failed to parse transition doc ${doc.id}: $e');
        }
      }

      if (remoteTransitions.isEmpty) {
        _syncLog('pull: no valid remote transitions after parsing');
        return;
      }

      // Apply remote transitions through the conflict resolver.
      await _db.applyRemoteTransitions(
        remoteTransitions: remoteTransitions,
        resolver: _resolver,
      );

      _syncLog('pull: reconciliation complete');

      onPullApplied?.call(remoteTransitions.length);
    } catch (e) {
      _syncLog('pull: ERROR: $e');
      _diagnostics.recordError(SyncType.taskTransition, 'Pull failed: $e');
    }
  }

  // -------------------------------------------------------------------------
  // Logging
  // -------------------------------------------------------------------------

  void _syncLog(String message) {
    AppLogging.taskSync(message);
  }
}
