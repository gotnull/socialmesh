// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Integration test: dual-device task reconciliation.
//
// Simulates two devices operating offline on the same task, then
// syncing their transitions. Validates that the TaskConflictResolver
// and TaskDatabase.applyRemoteTransitions produce deterministic
// results when applied from either device's perspective.
//
// Spec: TASK_SYSTEM.md - Reconciliation Rules, Sprint 008/W4.2.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/tasks/models/task.dart';
import 'package:socialmesh/features/tasks/models/task_transition.dart';
import 'package:socialmesh/features/tasks/services/task_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Task _createTask({
  String id = 'task-1',
  TaskState state = TaskState.assigned,
  int createdAtMs = 100,
  int updatedAtMs = 100,
}) {
  return Task(
    id: id,
    orgId: 'org-1',
    title: 'Field repair: valve station 7',
    description: 'Replace pressure relief valve and test',
    state: state,
    priority: TaskPriority.immediate,
    createdBy: 'uid-supervisor',
    assigneeId: 'uid-operator',
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtMs),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
  );
}

TaskTransition _tx({
  required String id,
  String taskId = 'task-1',
  required TaskState from,
  required TaskState to,
  String actorId = 'uid-operator',
  required int timestampMs,
  String? note,
}) {
  return TaskTransition(
    id: id,
    taskId: taskId,
    fromState: from,
    toState: to,
    actorId: actorId,
    note: note,
    timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
  );
}

/// Sets up a fresh in-memory TaskDatabase and inserts the given task
/// and transitions.
Future<TaskDatabase> _setupDevice({
  required Task task,
  required List<TaskTransition> transitions,
}) async {
  final db = TaskDatabase(dbPathOverride: inMemoryDatabasePath);
  await db.open();
  await db.insertTask(task);
  for (final t in transitions) {
    await db.insertTransition(t);
  }
  return db;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // =========================================================================
  // Scenario 1: Device A completes, Device B cancels
  //
  // Both devices start with the task in IN_PROGRESS state.
  // Device A: operator completes the task.
  // Device B: supervisor cancels the task.
  // After sync: COMPLETED wins on both devices.
  // =========================================================================

  group('Dual-device: COMPLETED vs CANCELLED', () {
    test('device A perspective: local completed, remote cancelled', () async {
      // --- Shared history ---
      final sharedTransitions = [
        _tx(
          id: 'tx-create',
          from: TaskState.created,
          to: TaskState.assigned,
          actorId: 'uid-supervisor',
          timestampMs: 100,
        ),
        _tx(
          id: 'tx-ack',
          from: TaskState.assigned,
          to: TaskState.acknowledged,
          timestampMs: 200,
        ),
        _tx(
          id: 'tx-start',
          from: TaskState.acknowledged,
          to: TaskState.inProgress,
          timestampMs: 300,
        ),
      ];

      // --- Device A: operator completes ---
      final deviceATask = _createTask(
        state: TaskState.completed,
        updatedAtMs: 1000,
      );
      final deviceATransitions = [
        ...sharedTransitions,
        _tx(
          id: 'tx-complete-a',
          from: TaskState.inProgress,
          to: TaskState.completed,
          timestampMs: 1000,
          note: 'Valve sealed and pressure tested at 150psi',
        ),
      ];

      final dbA = await _setupDevice(
        task: deviceATask,
        transitions: deviceATransitions,
      );

      // --- Receive Device B's cancellation ---
      final deviceBCancel = _tx(
        id: 'tx-cancel-b',
        from: TaskState.inProgress,
        to: TaskState.cancelled,
        actorId: 'uid-supervisor',
        timestampMs: 1002,
      );

      await dbA.applyRemoteTransitions(remoteTransitions: [deviceBCancel]);

      // COMPLETED wins.
      final taskA = await dbA.getTaskById('task-1');
      expect(taskA!.state, TaskState.completed);

      // Both transitions preserved (append-only).
      final transitionsA = await dbA.getTransitionsByTaskId('task-1');
      expect(transitionsA.length, 5);
      final statesA = transitionsA.map((t) => t.toState.name).toSet();
      expect(statesA, contains('completed'));
      expect(statesA, contains('cancelled'));

      await dbA.close();
    });

    test('device B perspective: local cancelled, remote completed', () async {
      // --- Shared history ---
      final sharedTransitions = [
        _tx(
          id: 'tx-create',
          from: TaskState.created,
          to: TaskState.assigned,
          actorId: 'uid-supervisor',
          timestampMs: 100,
        ),
        _tx(
          id: 'tx-ack',
          from: TaskState.assigned,
          to: TaskState.acknowledged,
          timestampMs: 200,
        ),
        _tx(
          id: 'tx-start',
          from: TaskState.acknowledged,
          to: TaskState.inProgress,
          timestampMs: 300,
        ),
      ];

      // --- Device B: supervisor cancels ---
      final deviceBTask = _createTask(
        state: TaskState.cancelled,
        updatedAtMs: 1002,
      );
      final deviceBTransitions = [
        ...sharedTransitions,
        _tx(
          id: 'tx-cancel-b',
          from: TaskState.inProgress,
          to: TaskState.cancelled,
          actorId: 'uid-supervisor',
          timestampMs: 1002,
        ),
      ];

      final dbB = await _setupDevice(
        task: deviceBTask,
        transitions: deviceBTransitions,
      );

      // --- Receive Device A's completion ---
      final deviceAComplete = _tx(
        id: 'tx-complete-a',
        from: TaskState.inProgress,
        to: TaskState.completed,
        timestampMs: 1000,
        note: 'Valve sealed and pressure tested at 150psi',
      );

      await dbB.applyRemoteTransitions(remoteTransitions: [deviceAComplete]);

      // COMPLETED wins.
      final taskB = await dbB.getTaskById('task-1');
      expect(taskB!.state, TaskState.completed);

      // Both transitions preserved.
      final transitionsB = await dbB.getTransitionsByTaskId('task-1');
      expect(transitionsB.length, 5);

      await dbB.close();
    });

    test('both devices converge to same state', () async {
      // Run both perspectives and verify they agree.
      final sharedTransitions = [
        _tx(
          id: 'tx-create',
          from: TaskState.created,
          to: TaskState.assigned,
          actorId: 'uid-supervisor',
          timestampMs: 100,
        ),
        _tx(
          id: 'tx-ack',
          from: TaskState.assigned,
          to: TaskState.acknowledged,
          timestampMs: 200,
        ),
        _tx(
          id: 'tx-start',
          from: TaskState.acknowledged,
          to: TaskState.inProgress,
          timestampMs: 300,
        ),
      ];

      final completeTransition = _tx(
        id: 'tx-complete',
        from: TaskState.inProgress,
        to: TaskState.completed,
        timestampMs: 1000,
        note: 'Done',
      );

      final cancelTransition = _tx(
        id: 'tx-cancel',
        from: TaskState.inProgress,
        to: TaskState.cancelled,
        actorId: 'uid-supervisor',
        timestampMs: 1002,
      );

      // Device A: local complete, remote cancel.
      final dbA = await _setupDevice(
        task: _createTask(state: TaskState.completed, updatedAtMs: 1000),
        transitions: [...sharedTransitions, completeTransition],
      );
      await dbA.applyRemoteTransitions(remoteTransitions: [cancelTransition]);

      // Device B: local cancel, remote complete.
      final dbB = await _setupDevice(
        task: _createTask(state: TaskState.cancelled, updatedAtMs: 1002),
        transitions: [...sharedTransitions, cancelTransition],
      );
      await dbB.applyRemoteTransitions(remoteTransitions: [completeTransition]);

      final taskA = await dbA.getTaskById('task-1');
      final taskB = await dbB.getTaskById('task-1');

      // Both converge to COMPLETED.
      expect(taskA!.state, TaskState.completed);
      expect(taskB!.state, TaskState.completed);

      await dbA.close();
      await dbB.close();
    });
  });

  // =========================================================================
  // Scenario 2: Dual acknowledgement
  //
  // Two devices both acknowledge the same task offline.
  // After sync: first timestamp wins, second is stored but no-op.
  // =========================================================================

  group('Dual-device: dual acknowledgement', () {
    test('first timestamp wins from device A perspective', () async {
      final sharedTransitions = [
        _tx(
          id: 'tx-create',
          from: TaskState.created,
          to: TaskState.assigned,
          actorId: 'uid-supervisor',
          timestampMs: 100,
        ),
      ];

      // Device A acks at t=1000.
      final dbA = await _setupDevice(
        task: _createTask(state: TaskState.acknowledged, updatedAtMs: 1000),
        transitions: [
          ...sharedTransitions,
          _tx(
            id: 'tx-ack-a',
            from: TaskState.assigned,
            to: TaskState.acknowledged,
            timestampMs: 1000,
          ),
        ],
      );

      // Remote ack from Device B at t=998 (earlier).
      await dbA.applyRemoteTransitions(
        remoteTransitions: [
          _tx(
            id: 'tx-ack-b',
            from: TaskState.assigned,
            to: TaskState.acknowledged,
            timestampMs: 998,
          ),
        ],
      );

      // Both transitions preserved.
      final transitions = await dbA.getTransitionsByTaskId('task-1');
      expect(transitions.length, 3);

      // State is still acknowledged (unchanged).
      final task = await dbA.getTaskById('task-1');
      expect(task!.state, TaskState.acknowledged);

      await dbA.close();
    });

    test('devices converge despite different ack timestamps', () async {
      final sharedTransitions = [
        _tx(
          id: 'tx-create',
          from: TaskState.created,
          to: TaskState.assigned,
          actorId: 'uid-supervisor',
          timestampMs: 100,
        ),
      ];

      // Device A acks at t=1000, receives B's ack at t=998.
      final dbA = await _setupDevice(
        task: _createTask(state: TaskState.acknowledged, updatedAtMs: 1000),
        transitions: [
          ...sharedTransitions,
          _tx(
            id: 'tx-ack-a',
            from: TaskState.assigned,
            to: TaskState.acknowledged,
            timestampMs: 1000,
          ),
        ],
      );
      await dbA.applyRemoteTransitions(
        remoteTransitions: [
          _tx(
            id: 'tx-ack-b',
            from: TaskState.assigned,
            to: TaskState.acknowledged,
            timestampMs: 998,
          ),
        ],
      );

      // Device B acks at t=998, receives A's ack at t=1000.
      final dbB = await _setupDevice(
        task: _createTask(state: TaskState.acknowledged, updatedAtMs: 998),
        transitions: [
          ...sharedTransitions,
          _tx(
            id: 'tx-ack-b',
            from: TaskState.assigned,
            to: TaskState.acknowledged,
            timestampMs: 998,
          ),
        ],
      );
      await dbB.applyRemoteTransitions(
        remoteTransitions: [
          _tx(
            id: 'tx-ack-a',
            from: TaskState.assigned,
            to: TaskState.acknowledged,
            timestampMs: 1000,
          ),
        ],
      );

      // Both devices in acknowledged state.
      final taskA = await dbA.getTaskById('task-1');
      final taskB = await dbB.getTaskById('task-1');
      expect(taskA!.state, TaskState.acknowledged);
      expect(taskB!.state, TaskState.acknowledged);

      // Both have 3 transitions (create + 2 acks).
      final txA = await dbA.getTransitionsByTaskId('task-1');
      final txB = await dbB.getTransitionsByTaskId('task-1');
      expect(txA.length, 3);
      expect(txB.length, 3);

      await dbA.close();
      await dbB.close();
    });
  });

  // =========================================================================
  // Scenario 3: Reassignment while operator completes
  //
  // Device A (operator): marks task in_progress -> completed.
  // Device B (supervisor): marks task failed -> reassigned.
  // Both records survive. COMPLETED stands.
  // =========================================================================

  group('Dual-device: reassignment during completion', () {
    test('completed stands, reassigned task independent', () async {
      final sharedTransitions = [
        _tx(
          id: 'tx-create',
          from: TaskState.created,
          to: TaskState.assigned,
          actorId: 'uid-supervisor',
          timestampMs: 100,
        ),
        _tx(
          id: 'tx-ack',
          from: TaskState.assigned,
          to: TaskState.acknowledged,
          timestampMs: 200,
        ),
        _tx(
          id: 'tx-start',
          from: TaskState.acknowledged,
          to: TaskState.inProgress,
          timestampMs: 300,
        ),
      ];

      // Device A: operator completes.
      final dbA = await _setupDevice(
        task: _createTask(state: TaskState.completed, updatedAtMs: 1000),
        transitions: [
          ...sharedTransitions,
          _tx(
            id: 'tx-complete',
            from: TaskState.inProgress,
            to: TaskState.completed,
            timestampMs: 1000,
            note: 'Equipment repaired',
          ),
        ],
      );

      // Remote: supervisor had previously failed and reassigned the task.
      await dbA.applyRemoteTransitions(
        remoteTransitions: [
          _tx(
            id: 'tx-fail',
            from: TaskState.inProgress,
            to: TaskState.failed,
            actorId: 'uid-supervisor',
            timestampMs: 900,
            note: 'Cannot reach site',
          ),
          _tx(
            id: 'tx-reassign',
            from: TaskState.failed,
            to: TaskState.reassigned,
            actorId: 'uid-supervisor',
            timestampMs: 950,
          ),
        ],
      );

      // COMPLETED stands on original task.
      final task = await dbA.getTaskById('task-1');
      expect(task!.state, TaskState.completed);

      // All transitions preserved.
      final transitions = await dbA.getTransitionsByTaskId('task-1');
      expect(transitions.length, 6);

      await dbA.close();
    });
  });

  // =========================================================================
  // Scenario 4: Idempotent re-application
  //
  // Applying the same remote transitions twice produces the same result.
  // =========================================================================

  group('Dual-device: idempotent re-application', () {
    test('applying same transitions twice yields same state', () async {
      final task = _createTask(state: TaskState.inProgress, updatedAtMs: 300);
      final sharedTransitions = [
        _tx(
          id: 'tx-create',
          from: TaskState.created,
          to: TaskState.assigned,
          actorId: 'uid-supervisor',
          timestampMs: 100,
        ),
        _tx(
          id: 'tx-ack',
          from: TaskState.assigned,
          to: TaskState.acknowledged,
          timestampMs: 200,
        ),
        _tx(
          id: 'tx-start',
          from: TaskState.acknowledged,
          to: TaskState.inProgress,
          timestampMs: 300,
        ),
      ];

      final db = await _setupDevice(task: task, transitions: sharedTransitions);

      final remoteComplete = _tx(
        id: 'tx-complete-remote',
        from: TaskState.inProgress,
        to: TaskState.completed,
        timestampMs: 1000,
        note: 'Done on remote device',
      );

      // Apply once.
      await db.applyRemoteTransitions(remoteTransitions: [remoteComplete]);
      final afterFirst = await db.getTaskById('task-1');
      final txAfterFirst = await db.getTransitionsByTaskId('task-1');

      // Apply again.
      await db.applyRemoteTransitions(remoteTransitions: [remoteComplete]);
      final afterSecond = await db.getTaskById('task-1');
      final txAfterSecond = await db.getTransitionsByTaskId('task-1');

      // Same state.
      expect(afterFirst!.state, afterSecond!.state);
      // Same number of transitions (no duplicates).
      expect(txAfterFirst.length, txAfterSecond.length);

      await db.close();
    });
  });
}
