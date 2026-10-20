// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Task Conflict Resolver - deterministic offline reconciliation.
//
// Implements the 4 reconciliation rules from TASK_SYSTEM.md:
//   1. Dual acknowledgement: first timestamp wins, second is no-op.
//   2. COMPLETED vs CANCELLED: COMPLETED wins (completion outcome precedence).
//   3. Reassignment during completion: COMPLETED stands, reassigned task
//      exists independently.
//   4. Duplicate creation: both survive (different UUIDs, manual dedup).
//
// All transitions are append-only. No deletions, no mutations of history.
// Logging gated behind TASK_SYNC_LOGGING_ENABLED.
//
// Spec: TASK_SYSTEM.md (Sprint 007/W3.1), Sprint 008/W4.2.

import '../../../core/logging.dart';
import '../models/task.dart';
import '../models/task_transition.dart';

// ---------------------------------------------------------------------------
// Resolution result
// ---------------------------------------------------------------------------

/// Outcome of applying a remote transition against local state.
enum TaskConflictOutcome {
  /// Remote transition applied cleanly (no conflict).
  applied,

  /// Remote transition is a no-op (duplicate or superseded).
  noOp,

  /// COMPLETED wins over CANCELLED - local or remote COMPLETED preserved.
  completedWins,

  /// Reassignment coexists with completion - both records survive.
  coexist,

  /// Duplicate task creation - both survive with different UUIDs.
  duplicateCreation,
}

/// Result of resolving a single remote transition against local state.
class TaskConflictResult {
  /// The outcome of conflict resolution.
  final TaskConflictOutcome outcome;

  /// Human-readable explanation for logging and diagnostics.
  final String reason;

  /// The winning transition (null if no-op or coexist with no action needed).
  final TaskTransition? winningTransition;

  /// Updated task state after resolution (null if no state change).
  final TaskState? resolvedState;

  const TaskConflictResult({
    required this.outcome,
    required this.reason,
    this.winningTransition,
    this.resolvedState,
  });
}

// ---------------------------------------------------------------------------
// Resolver
// ---------------------------------------------------------------------------

/// Deterministic conflict resolver for the task system.
///
/// Applies the 4 reconciliation rules defined in TASK_SYSTEM.md.
/// All decisions are deterministic - given the same inputs, the same
/// output is produced regardless of device or ordering.
///
/// This resolver is stateless. It receives the current local task state
/// and transitions, plus a remote transition, and determines the outcome.
///
/// Spec: TASK_SYSTEM.md - Reconciliation Rules, Sprint 008/W4.2.
class TaskConflictResolver {
  const TaskConflictResolver();

  /// Resolves a remote transition against local task state.
  ///
  /// [localTask] is the current local task row (may be null if the task
  /// doesn't exist locally yet).
  /// [localTransitions] are all local transitions for this task.
  /// [remoteTransition] is the incoming remote transition to reconcile.
  ///
  /// Returns a [TaskConflictResult] describing what action to take.
  TaskConflictResult resolve({
    required Task? localTask,
    required List<TaskTransition> localTransitions,
    required TaskTransition remoteTransition,
  }) {
    // -----------------------------------------------------------------------
    // Rule 4: Duplicate creation - both tasks survive (different UUIDs).
    //
    // If the task doesn't exist locally and the remote transition is a
    // creation (fromState == created), this is either a new task or a
    // duplicate creation. Since tasks have unique UUIDs, both survive.
    // Dedup is manual per spec.
    // -----------------------------------------------------------------------
    if (localTask == null) {
      AppLogging.taskSync(
        'new task ${remoteTransition.taskId}: '
        '${remoteTransition.fromState.name} -> '
        '${remoteTransition.toState.name} '
        '(no local record, applying)',
      );
      return TaskConflictResult(
        outcome: TaskConflictOutcome.applied,
        reason: 'Task not found locally, applying remote transition.',
        winningTransition: remoteTransition,
        resolvedState: remoteTransition.toState,
      );
    }

    // -----------------------------------------------------------------------
    // Idempotency: skip duplicate transitions already stored locally.
    // -----------------------------------------------------------------------
    final isDuplicate = localTransitions.any(
      (t) => t.id == remoteTransition.id,
    );
    if (isDuplicate) {
      AppLogging.taskSync(
        'duplicate transition ${remoteTransition.id} on '
        '${remoteTransition.taskId}: already stored, skipping',
      );
      return TaskConflictResult(
        outcome: TaskConflictOutcome.noOp,
        reason: 'Transition ${remoteTransition.id} already exists locally.',
      );
    }

    // -----------------------------------------------------------------------
    // Rule 1: Dual acknowledgement - first timestamp wins.
    //
    // If both local and remote have an acknowledge transition for the same
    // task, the one with the earlier timestamp wins. The other is a no-op.
    // -----------------------------------------------------------------------
    if (remoteTransition.toState == TaskState.acknowledged) {
      final localAck = _findTransitionToState(
        localTransitions,
        TaskState.acknowledged,
      );
      if (localAck != null) {
        final localTs = localAck.timestamp.millisecondsSinceEpoch;
        final remoteTs = remoteTransition.timestamp.millisecondsSinceEpoch;

        if (remoteTs < localTs) {
          // Remote is earlier - remote wins.
          AppLogging.taskSync(
            'conflict detected on ${remoteTransition.taskId}: '
            'local=acknowledged@$localTs, '
            'remote=acknowledged@$remoteTs',
          );
          AppLogging.taskSync(
            'resolution: remote wins '
            '(earlier timestamp: $remoteTs < $localTs)',
          );
          return TaskConflictResult(
            outcome: TaskConflictOutcome.applied,
            reason:
                'Dual ack: remote timestamp ($remoteTs) '
                'earlier than local ($localTs).',
            winningTransition: remoteTransition,
            resolvedState: TaskState.acknowledged,
          );
        } else {
          // Local is earlier or equal - local wins, remote is no-op.
          AppLogging.taskSync(
            'conflict detected on ${remoteTransition.taskId}: '
            'local=acknowledged@$localTs, '
            'remote=acknowledged@$remoteTs',
          );
          AppLogging.taskSync(
            'resolution: local wins '
            '(earlier timestamp: $localTs <= $remoteTs)',
          );
          return TaskConflictResult(
            outcome: TaskConflictOutcome.noOp,
            reason:
                'Dual ack: local timestamp ($localTs) '
                'wins over remote ($remoteTs).',
          );
        }
      }
    }

    // -----------------------------------------------------------------------
    // Rule 2: COMPLETED vs CANCELLED - COMPLETED wins.
    //
    // If one device completed and the other cancelled, COMPLETED always wins.
    // Completion outcome takes precedence over admin action.
    // -----------------------------------------------------------------------
    if (_isCompletedVsCancelledConflict(localTask.state, remoteTransition)) {
      final localState = localTask.state;
      final remoteState = remoteTransition.toState;

      if (localState == TaskState.completed &&
          remoteState == TaskState.cancelled) {
        // Local COMPLETED wins over remote CANCELLED.
        AppLogging.taskSync(
          'conflict detected on ${remoteTransition.taskId}: '
          'local=${localState.name}'
          '@${localTask.updatedAt.millisecondsSinceEpoch}, '
          'remote=${remoteState.name}'
          '@${remoteTransition.timestamp.millisecondsSinceEpoch}',
        );
        AppLogging.taskSync(
          'resolution: COMPLETED wins over CANCELLED '
          '(completion outcome precedence)',
        );
        return TaskConflictResult(
          outcome: TaskConflictOutcome.completedWins,
          reason: 'COMPLETED (local) wins over CANCELLED (remote).',
          resolvedState: TaskState.completed,
        );
      }

      if (localState == TaskState.cancelled &&
          remoteState == TaskState.completed) {
        // Remote COMPLETED wins over local CANCELLED.
        AppLogging.taskSync(
          'conflict detected on ${remoteTransition.taskId}: '
          'local=${localState.name}'
          '@${localTask.updatedAt.millisecondsSinceEpoch}, '
          'remote=${remoteState.name}'
          '@${remoteTransition.timestamp.millisecondsSinceEpoch}',
        );
        AppLogging.taskSync(
          'resolution: COMPLETED wins over CANCELLED '
          '(completion outcome precedence)',
        );
        return TaskConflictResult(
          outcome: TaskConflictOutcome.completedWins,
          reason: 'COMPLETED (remote) wins over CANCELLED (local).',
          winningTransition: remoteTransition,
          resolvedState: TaskState.completed,
        );
      }
    }

    // -----------------------------------------------------------------------
    // Rule 3: Reassignment during completion.
    //
    // If the original operator completes the task while a supervisor
    // reassigns it, COMPLETED on the original task stands. The reassigned
    // task exists independently. Both records survive.
    // -----------------------------------------------------------------------
    if (_isReassignmentDuringCompletion(localTask.state, remoteTransition)) {
      if (localTask.state == TaskState.completed &&
          remoteTransition.toState == TaskState.reassigned) {
        AppLogging.taskSync(
          'conflict detected on ${remoteTransition.taskId}: '
          'local=completed, remote=reassigned',
        );
        AppLogging.taskSync(
          'resolution: COMPLETED stands, '
          'reassigned task exists independently',
        );
        return TaskConflictResult(
          outcome: TaskConflictOutcome.coexist,
          reason:
              'Completed task stands. '
              'Reassigned task exists independently.',
          resolvedState: TaskState.completed,
        );
      }

      if (localTask.state == TaskState.reassigned &&
          remoteTransition.toState == TaskState.completed) {
        AppLogging.taskSync(
          'conflict detected on ${remoteTransition.taskId}: '
          'local=reassigned, remote=completed',
        );
        AppLogging.taskSync(
          'resolution: COMPLETED stands, '
          'reassigned task exists independently',
        );
        return TaskConflictResult(
          outcome: TaskConflictOutcome.coexist,
          reason:
              'Completed (remote) stands. '
              'Reassigned task exists independently.',
          winningTransition: remoteTransition,
          resolvedState: TaskState.completed,
        );
      }
    }

    // -----------------------------------------------------------------------
    // No conflict: apply remote transition normally.
    //
    // If the remote transition's fromState matches the local task's current
    // state, it is a valid forward progression.
    // If it doesn't match, the transition is stale (task has moved past
    // the expected state) - store it but don't change projection.
    // -----------------------------------------------------------------------
    if (remoteTransition.fromState == localTask.state) {
      AppLogging.taskSync(
        'applying remote transition on ${remoteTransition.taskId}: '
        '${remoteTransition.fromState.name} -> '
        '${remoteTransition.toState.name}',
      );
      return TaskConflictResult(
        outcome: TaskConflictOutcome.applied,
        reason: 'Remote transition matches current state. Applied.',
        winningTransition: remoteTransition,
        resolvedState: remoteTransition.toState,
      );
    }

    // Remote transition references a past state - stale but still stored
    // for audit trail completeness.
    AppLogging.taskSync(
      'stale remote transition on ${remoteTransition.taskId}: '
      'expected fromState=${remoteTransition.fromState.name} '
      'but local state=${localTask.state.name}. '
      'Storing for audit, no state change.',
    );
    return TaskConflictResult(
      outcome: TaskConflictOutcome.noOp,
      reason:
          'Stale transition: expected ${remoteTransition.fromState.name} '
          'but task is ${localTask.state.name}.',
    );
  }

  /// Resolves a batch of remote transitions for multiple tasks.
  ///
  /// Groups transitions by taskId and resolves each in order.
  /// Returns a map of taskId -> list of results.
  Map<String, List<TaskConflictResult>> resolveBatch({
    required Map<String, Task?> localTasks,
    required Map<String, List<TaskTransition>> localTransitionsByTask,
    required List<TaskTransition> remoteTransitions,
  }) {
    final results = <String, List<TaskConflictResult>>{};

    // Group remote transitions by taskId, preserving timestamp order.
    final groupedRemote = <String, List<TaskTransition>>{};
    for (final rt in remoteTransitions) {
      groupedRemote.putIfAbsent(rt.taskId, () => []).add(rt);
    }

    for (final entry in groupedRemote.entries) {
      final taskId = entry.key;
      final transitions = entry.value
        ..sort(
          (a, b) => a.timestamp.millisecondsSinceEpoch.compareTo(
            b.timestamp.millisecondsSinceEpoch,
          ),
        );

      final taskResults = <TaskConflictResult>[];
      for (final rt in transitions) {
        final result = resolve(
          localTask: localTasks[taskId],
          localTransitions: localTransitionsByTask[taskId] ?? [],
          remoteTransition: rt,
        );
        taskResults.add(result);
      }
      results[taskId] = taskResults;
    }

    return results;
  }

  // -----------------------------------------------------------------------
  // Private helpers
  // -----------------------------------------------------------------------

  /// Finds the first transition to [targetState] in a list of transitions.
  TaskTransition? _findTransitionToState(
    List<TaskTransition> transitions,
    TaskState targetState,
  ) {
    for (final t in transitions) {
      if (t.toState == targetState) return t;
    }
    return null;
  }

  /// Returns true if this is a COMPLETED vs CANCELLED conflict.
  bool _isCompletedVsCancelledConflict(
    TaskState localState,
    TaskTransition remoteTransition,
  ) {
    return (localState == TaskState.completed &&
            remoteTransition.toState == TaskState.cancelled) ||
        (localState == TaskState.cancelled &&
            remoteTransition.toState == TaskState.completed);
  }

  /// Returns true if this is a reassignment-during-completion conflict.
  bool _isReassignmentDuringCompletion(
    TaskState localState,
    TaskTransition remoteTransition,
  ) {
    return (localState == TaskState.completed &&
            remoteTransition.toState == TaskState.reassigned) ||
        (localState == TaskState.reassigned &&
            remoteTransition.toState == TaskState.completed);
  }
}
