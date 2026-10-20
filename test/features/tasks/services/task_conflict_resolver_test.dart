// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/tasks/models/task.dart';
import 'package:socialmesh/features/tasks/models/task_transition.dart';
import 'package:socialmesh/features/tasks/services/task_conflict_resolver.dart';
import 'package:socialmesh/features/tasks/services/task_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Task _task({
  String id = 'task-1',
  TaskState state = TaskState.inProgress,
  String orgId = 'org-1',
  String createdBy = 'uid-sup',
  String assigneeId = 'uid-op',
  int createdAtMs = 500,
  int updatedAtMs = 1000,
}) {
  return Task(
    id: id,
    orgId: orgId,
    title: 'Test task',
    state: state,
    priority: TaskPriority.routine,
    createdBy: createdBy,
    assigneeId: assigneeId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
  );
}

TaskTransition _transition({
  required String id,
  String taskId = 'task-1',
  TaskState fromState = TaskState.assigned,
  TaskState toState = TaskState.acknowledged,
  String actorId = 'uid-op',
  int timestampMs = 1000,
  String? note,
}) {
  return TaskTransition(
    id: id,
    taskId: taskId,
    fromState: fromState,
    toState: toState,
    actorId: actorId,
    note: note,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const resolver = TaskConflictResolver();

  // =========================================================================
  // Rule 1: Dual acknowledgement - first timestamp wins
  // =========================================================================

  group('Rule 1: Dual acknowledgement', () {
    test('remote ack with earlier timestamp wins over local ack', () {
      final localTask = _task(state: TaskState.acknowledged);
      final localAck = _transition(
        id: 'tx-local-ack',
        toState: TaskState.acknowledged,
        fromState: TaskState.assigned,
        timestampMs: 1000,
      );
      final remoteAck = _transition(
        id: 'tx-remote-ack',
        toState: TaskState.acknowledged,
        fromState: TaskState.assigned,
        timestampMs: 998,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [localAck],
        remoteTransition: remoteAck,
      );

      expect(result.outcome, TaskConflictOutcome.applied);
      expect(result.resolvedState, TaskState.acknowledged);
      expect(result.winningTransition, remoteAck);
    });

    test('local ack with earlier timestamp wins, remote is no-op', () {
      final localTask = _task(state: TaskState.acknowledged);
      final localAck = _transition(
        id: 'tx-local-ack',
        toState: TaskState.acknowledged,
        fromState: TaskState.assigned,
        timestampMs: 998,
      );
      final remoteAck = _transition(
        id: 'tx-remote-ack',
        toState: TaskState.acknowledged,
        fromState: TaskState.assigned,
        timestampMs: 1000,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [localAck],
        remoteTransition: remoteAck,
      );

      expect(result.outcome, TaskConflictOutcome.noOp);
      expect(result.reason, contains('local timestamp'));
    });

    test('equal timestamps - local wins (no-op)', () {
      final localTask = _task(state: TaskState.acknowledged);
      final localAck = _transition(
        id: 'tx-local-ack',
        toState: TaskState.acknowledged,
        fromState: TaskState.assigned,
        timestampMs: 1000,
      );
      final remoteAck = _transition(
        id: 'tx-remote-ack',
        toState: TaskState.acknowledged,
        fromState: TaskState.assigned,
        timestampMs: 1000,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [localAck],
        remoteTransition: remoteAck,
      );

      expect(result.outcome, TaskConflictOutcome.noOp);
    });
  });

  // =========================================================================
  // Rule 2: COMPLETED vs CANCELLED - COMPLETED wins
  // =========================================================================

  group('Rule 2: COMPLETED vs CANCELLED', () {
    test('local COMPLETED wins over remote CANCELLED', () {
      final localTask = _task(state: TaskState.completed);
      final localComplete = _transition(
        id: 'tx-local-complete',
        fromState: TaskState.inProgress,
        toState: TaskState.completed,
        timestampMs: 1000,
        note: 'Valve sealed and pressure tested at 150psi',
      );
      final remoteCancel = _transition(
        id: 'tx-remote-cancel',
        fromState: TaskState.inProgress,
        toState: TaskState.cancelled,
        actorId: 'uid-sup',
        timestampMs: 1002,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [localComplete],
        remoteTransition: remoteCancel,
      );

      expect(result.outcome, TaskConflictOutcome.completedWins);
      expect(result.resolvedState, TaskState.completed);
      expect(result.reason, contains('COMPLETED (local)'));
    });

    test('remote COMPLETED wins over local CANCELLED', () {
      final localTask = _task(state: TaskState.cancelled);
      final localCancel = _transition(
        id: 'tx-local-cancel',
        fromState: TaskState.inProgress,
        toState: TaskState.cancelled,
        actorId: 'uid-sup',
        timestampMs: 1000,
      );
      final remoteComplete = _transition(
        id: 'tx-remote-complete',
        fromState: TaskState.inProgress,
        toState: TaskState.completed,
        timestampMs: 1002,
        note: 'Perimeter secured and tagged',
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [localCancel],
        remoteTransition: remoteComplete,
      );

      expect(result.outcome, TaskConflictOutcome.completedWins);
      expect(result.resolvedState, TaskState.completed);
      expect(result.winningTransition, remoteComplete);
      expect(result.reason, contains('COMPLETED (remote)'));
    });

    test('COMPLETED wins regardless of which timestamp is earlier', () {
      // Remote CANCELLED has earlier timestamp but COMPLETED still wins.
      final localTask = _task(state: TaskState.completed);
      final localComplete = _transition(
        id: 'tx-local-complete',
        fromState: TaskState.inProgress,
        toState: TaskState.completed,
        timestampMs: 1500,
        note: 'Task done properly',
      );
      final remoteCancel = _transition(
        id: 'tx-remote-cancel',
        fromState: TaskState.inProgress,
        toState: TaskState.cancelled,
        timestampMs: 500,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [localComplete],
        remoteTransition: remoteCancel,
      );

      expect(result.outcome, TaskConflictOutcome.completedWins);
      expect(result.resolvedState, TaskState.completed);
    });
  });

  // =========================================================================
  // Rule 3: Reassignment during completion - both survive
  // =========================================================================

  group('Rule 3: Reassignment during completion', () {
    test('local COMPLETED stands when remote reassigns', () {
      final localTask = _task(state: TaskState.completed);
      final localComplete = _transition(
        id: 'tx-local-complete',
        fromState: TaskState.inProgress,
        toState: TaskState.completed,
        timestampMs: 1000,
        note: 'Equipment repaired',
      );
      final remoteReassign = _transition(
        id: 'tx-remote-reassign',
        fromState: TaskState.failed,
        toState: TaskState.reassigned,
        actorId: 'uid-sup',
        timestampMs: 1100,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [localComplete],
        remoteTransition: remoteReassign,
      );

      expect(result.outcome, TaskConflictOutcome.coexist);
      expect(result.resolvedState, TaskState.completed);
      expect(result.reason, contains('Completed task stands'));
    });

    test('remote COMPLETED stands when local reassigned', () {
      final localTask = _task(state: TaskState.reassigned);
      final localReassign = _transition(
        id: 'tx-local-reassign',
        fromState: TaskState.failed,
        toState: TaskState.reassigned,
        actorId: 'uid-sup',
        timestampMs: 1000,
      );
      final remoteComplete = _transition(
        id: 'tx-remote-complete',
        fromState: TaskState.inProgress,
        toState: TaskState.completed,
        timestampMs: 1050,
        note: 'Job completed before reassign propagated',
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [localReassign],
        remoteTransition: remoteComplete,
      );

      expect(result.outcome, TaskConflictOutcome.coexist);
      expect(result.resolvedState, TaskState.completed);
      expect(result.winningTransition, remoteComplete);
    });
  });

  // =========================================================================
  // Rule 4: Duplicate creation - both survive (different UUIDs)
  // =========================================================================

  group('Rule 4: Duplicate creation', () {
    test('new task (no local record) is applied', () {
      final remoteTransition = _transition(
        id: 'tx-remote-create',
        taskId: 'task-new',
        fromState: TaskState.created,
        toState: TaskState.assigned,
        actorId: 'uid-sup',
        timestampMs: 1000,
      );

      final result = resolver.resolve(
        localTask: null,
        localTransitions: [],
        remoteTransition: remoteTransition,
      );

      expect(result.outcome, TaskConflictOutcome.applied);
      expect(result.resolvedState, TaskState.assigned);
    });

    test('two tasks with same content but different UUIDs both survive', () {
      // Task A created locally.
      final localTask = _task(id: 'task-a', state: TaskState.assigned);

      // Task B created remotely with different UUID.
      final remoteCreate = _transition(
        id: 'tx-remote-create',
        taskId: 'task-b',
        fromState: TaskState.created,
        toState: TaskState.assigned,
        timestampMs: 1000,
      );

      // Resolve for task-b (which doesn't exist locally).
      final result = resolver.resolve(
        localTask: null,
        localTransitions: [],
        remoteTransition: remoteCreate,
      );

      expect(result.outcome, TaskConflictOutcome.applied);

      // Task A still exists (not affected by this resolution).
      // Both survive because they have different UUIDs.
      expect(localTask.state, TaskState.assigned);
    });
  });

  // =========================================================================
  // Idempotency
  // =========================================================================

  group('Idempotency', () {
    test('duplicate transition ID is a no-op', () {
      final localTask = _task(state: TaskState.acknowledged);
      final existingTransition = _transition(
        id: 'tx-ack',
        fromState: TaskState.assigned,
        toState: TaskState.acknowledged,
        timestampMs: 1000,
      );

      // Remote sends the same transition ID.
      final remoteTransition = _transition(
        id: 'tx-ack',
        fromState: TaskState.assigned,
        toState: TaskState.acknowledged,
        timestampMs: 1000,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: [existingTransition],
        remoteTransition: remoteTransition,
      );

      expect(result.outcome, TaskConflictOutcome.noOp);
      expect(result.reason, contains('already exists'));
    });
  });

  // =========================================================================
  // Forward progression (no conflict)
  // =========================================================================

  group('Forward progression', () {
    test('remote transition matching current state is applied', () {
      final localTask = _task(state: TaskState.acknowledged);
      final localTransitions = [
        _transition(
          id: 'tx-ack',
          fromState: TaskState.assigned,
          toState: TaskState.acknowledged,
          timestampMs: 1000,
        ),
      ];

      final remoteTransition = _transition(
        id: 'tx-start',
        fromState: TaskState.acknowledged,
        toState: TaskState.inProgress,
        timestampMs: 2000,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: localTransitions,
        remoteTransition: remoteTransition,
      );

      expect(result.outcome, TaskConflictOutcome.applied);
      expect(result.resolvedState, TaskState.inProgress);
    });

    test('stale remote transition stored but no state change', () {
      // Task has moved to inProgress, remote sends ack transition.
      final localTask = _task(state: TaskState.inProgress);
      final localTransitions = [
        _transition(
          id: 'tx-ack',
          fromState: TaskState.assigned,
          toState: TaskState.acknowledged,
          timestampMs: 1000,
        ),
        _transition(
          id: 'tx-start',
          fromState: TaskState.acknowledged,
          toState: TaskState.inProgress,
          timestampMs: 2000,
        ),
      ];

      final remoteTransition = _transition(
        id: 'tx-remote-assign',
        fromState: TaskState.created,
        toState: TaskState.assigned,
        timestampMs: 1500,
      );

      final result = resolver.resolve(
        localTask: localTask,
        localTransitions: localTransitions,
        remoteTransition: remoteTransition,
      );

      expect(result.outcome, TaskConflictOutcome.noOp);
      expect(result.reason, contains('Stale transition'));
    });
  });

  // =========================================================================
  // Batch resolver
  // =========================================================================

  group('resolveBatch', () {
    test('resolves multiple tasks independently', () {
      final tasks = <String, Task?>{
        'task-1': _task(id: 'task-1', state: TaskState.acknowledged),
        'task-2': null,
      };
      final transitions = <String, List<TaskTransition>>{
        'task-1': [
          _transition(
            id: 'tx-ack-1',
            taskId: 'task-1',
            fromState: TaskState.assigned,
            toState: TaskState.acknowledged,
            timestampMs: 1000,
          ),
        ],
      };
      final remoteTransitions = [
        _transition(
          id: 'tx-start-1',
          taskId: 'task-1',
          fromState: TaskState.acknowledged,
          toState: TaskState.inProgress,
          timestampMs: 2000,
        ),
        _transition(
          id: 'tx-create-2',
          taskId: 'task-2',
          fromState: TaskState.created,
          toState: TaskState.assigned,
          timestampMs: 1500,
        ),
      ];

      final results = resolver.resolveBatch(
        localTasks: tasks,
        localTransitionsByTask: transitions,
        remoteTransitions: remoteTransitions,
      );

      expect(results.length, 2);
      expect(results['task-1']!.first.outcome, TaskConflictOutcome.applied);
      expect(results['task-2']!.first.outcome, TaskConflictOutcome.applied);
    });
  });

  // =========================================================================
  // Integration: TaskDatabase.applyRemoteTransitions
  // =========================================================================

  group('TaskDatabase.applyRemoteTransitions', () {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    late TaskDatabase db;

    setUp(() async {
      db = TaskDatabase(dbPathOverride: inMemoryDatabasePath);
      await db.open();
    });

    tearDown(() async {
      await db.close();
    });

    Task createTestTask({
      String id = 'task-1',
      TaskState state = TaskState.assigned,
      int createdAtMs = 500,
      int updatedAtMs = 500,
    }) {
      return Task(
        id: id,
        orgId: 'org-1',
        title: 'Test task',
        state: state,
        priority: TaskPriority.routine,
        createdBy: 'uid-sup',
        assigneeId: 'uid-op',
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
      );
    }

    test('applies remote transition and updates projection', () async {
      // Insert a task in assigned state.
      final task = createTestTask();
      await db.insertTask(task);

      // Insert local transition: created -> assigned.
      await db.insertTransition(
        _transition(
          id: 'tx-assign',
          fromState: TaskState.created,
          toState: TaskState.assigned,
          timestampMs: 500,
        ),
      );

      // Apply remote transition: assigned -> acknowledged.
      await db.applyRemoteTransitions(
        remoteTransitions: [
          _transition(
            id: 'tx-ack-remote',
            fromState: TaskState.assigned,
            toState: TaskState.acknowledged,
            timestampMs: 1000,
          ),
        ],
      );

      // Verify task state updated.
      final updated = await db.getTaskById('task-1');
      expect(updated!.state, TaskState.acknowledged);

      // Verify both transitions stored.
      final transitions = await db.getTransitionsByTaskId('task-1');
      expect(transitions.length, 2);
    });

    test('COMPLETED wins over CANCELLED in remote reconciliation', () async {
      // Insert a task that was completed locally.
      final task = createTestTask(
        state: TaskState.completed,
        updatedAtMs: 1000,
      );
      await db.insertTask(task);

      await db.insertTransition(
        _transition(
          id: 'tx-assign',
          fromState: TaskState.created,
          toState: TaskState.assigned,
          timestampMs: 500,
        ),
      );
      await db.insertTransition(
        _transition(
          id: 'tx-ack',
          fromState: TaskState.assigned,
          toState: TaskState.acknowledged,
          timestampMs: 600,
        ),
      );
      await db.insertTransition(
        _transition(
          id: 'tx-start',
          fromState: TaskState.acknowledged,
          toState: TaskState.inProgress,
          timestampMs: 700,
        ),
      );
      await db.insertTransition(
        _transition(
          id: 'tx-complete',
          fromState: TaskState.inProgress,
          toState: TaskState.completed,
          timestampMs: 1000,
          note: 'Valve sealed at 150psi',
        ),
      );

      // Remote cancellation arrives after local completion.
      await db.applyRemoteTransitions(
        remoteTransitions: [
          _transition(
            id: 'tx-cancel-remote',
            fromState: TaskState.inProgress,
            toState: TaskState.cancelled,
            actorId: 'uid-sup',
            timestampMs: 1002,
          ),
        ],
      );

      // COMPLETED should still stand.
      final updated = await db.getTaskById('task-1');
      expect(updated!.state, TaskState.completed);

      // Both transitions stored (append-only).
      final transitions = await db.getTransitionsByTaskId('task-1');
      expect(transitions.length, 5);
      final states = transitions.map((t) => t.toState.name).toList();
      expect(states, contains('completed'));
      expect(states, contains('cancelled'));
    });

    test('duplicate transition ignored idempotently', () async {
      final task = createTestTask();
      await db.insertTask(task);

      final transition = _transition(
        id: 'tx-ack',
        fromState: TaskState.assigned,
        toState: TaskState.acknowledged,
        timestampMs: 1000,
      );

      // Insert locally.
      await db.insertTransition(transition);

      // Apply same transition as remote.
      await db.applyRemoteTransitions(remoteTransitions: [transition]);

      // Should still have exactly one transition (no duplicate).
      final transitions = await db.getTransitionsByTaskId('task-1');
      expect(transitions.length, 1);
    });

    test('dual ack: earlier remote timestamp wins', () async {
      final task = createTestTask(state: TaskState.acknowledged);
      await db.insertTask(task);

      // Local ack at t=1000.
      await db.insertTransition(
        _transition(
          id: 'tx-local-ack',
          fromState: TaskState.assigned,
          toState: TaskState.acknowledged,
          timestampMs: 1000,
        ),
      );

      // Remote ack at t=998 (earlier).
      await db.applyRemoteTransitions(
        remoteTransitions: [
          _transition(
            id: 'tx-remote-ack',
            fromState: TaskState.assigned,
            toState: TaskState.acknowledged,
            timestampMs: 998,
          ),
        ],
      );

      // Both transitions stored.
      final transitions = await db.getTransitionsByTaskId('task-1');
      expect(transitions.length, 2);

      // Task state still acknowledged (unchanged).
      final updated = await db.getTaskById('task-1');
      expect(updated!.state, TaskState.acknowledged);
    });

    test('all transitions preserved (append-only, no deletions)', () async {
      final task = createTestTask(state: TaskState.completed);
      await db.insertTask(task);

      // Build a full local history.
      await db.insertTransition(
        _transition(
          id: 'tx-1',
          fromState: TaskState.created,
          toState: TaskState.assigned,
          timestampMs: 100,
        ),
      );
      await db.insertTransition(
        _transition(
          id: 'tx-2',
          fromState: TaskState.assigned,
          toState: TaskState.acknowledged,
          timestampMs: 200,
        ),
      );
      await db.insertTransition(
        _transition(
          id: 'tx-3',
          fromState: TaskState.acknowledged,
          toState: TaskState.inProgress,
          timestampMs: 300,
        ),
      );
      await db.insertTransition(
        _transition(
          id: 'tx-4',
          fromState: TaskState.inProgress,
          toState: TaskState.completed,
          timestampMs: 400,
          note: 'Done properly',
        ),
      );

      // Apply a conflicting remote cancellation.
      await db.applyRemoteTransitions(
        remoteTransitions: [
          _transition(
            id: 'tx-remote-cancel',
            fromState: TaskState.inProgress,
            toState: TaskState.cancelled,
            timestampMs: 450,
          ),
        ],
      );

      // All 5 transitions preserved.
      final transitions = await db.getTransitionsByTaskId('task-1');
      expect(transitions.length, 5);

      // No rows deleted.
      final allRows = await db.database.query('task_transitions');
      expect(allRows.length, 5);
    });
  });
}
