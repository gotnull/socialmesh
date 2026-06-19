// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:uuid/uuid.dart';

import '../../../core/auth/permission.dart';
import '../../../core/auth/permission_context.dart';
import '../../../core/auth/permission_service.dart';
import '../../../core/auth/role.dart';
import '../../../core/logging.dart';
import '../../../l10n/app_localizations.dart';
import '../models/task.dart';
import '../models/task_transition.dart';
import 'task_database.dart';

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Thrown when a requested state transition is not valid per the task
/// lifecycle spec.
class InvalidTransitionException implements Exception {
  final String message;
  const InvalidTransitionException(this.message);

  @override
  String toString() => 'InvalidTransitionException: $message';
}

// ---------------------------------------------------------------------------
// Transition rules
// ---------------------------------------------------------------------------

/// The set of all valid (fromState, toState) pairs.
///
/// Spec: TASK_SYSTEM.md — Valid Transitions table.
const _validTransitions = <(TaskState, TaskState)>{
  // created ->
  (TaskState.created, TaskState.assigned), // assign
  (TaskState.created, TaskState.cancelled), // cancel
  // assigned ->
  (TaskState.assigned, TaskState.acknowledged), // acknowledge
  (TaskState.assigned, TaskState.cancelled), // cancel
  // acknowledged ->
  (TaskState.acknowledged, TaskState.inProgress), // startWork
  (TaskState.acknowledged, TaskState.cancelled), // cancel
  // in_progress ->
  (TaskState.inProgress, TaskState.completed), // complete
  (TaskState.inProgress, TaskState.failed), // fail
  (TaskState.inProgress, TaskState.cancelled), // cancel
  // failed ->
  (TaskState.failed, TaskState.reassigned), // reassign
};

// ---------------------------------------------------------------------------
// State machine
// ---------------------------------------------------------------------------

/// Task lifecycle state machine.
///
/// Validates transitions, enforces RBAC via [PermissionService], and writes
/// to the append-only `task_transitions` table.
///
/// The `tasks.state` column is a projection — updated after each
/// transition for query convenience but never treated as authoritative.
///
/// Spec: TASK_SYSTEM.md (Sprint 007/W3.1), Sprint 008/W4.1.
class TaskStateMachine {
  final TaskDatabase _db;
  final PermissionService _permissions;
  static const _uuid = Uuid();

  TaskStateMachine({required this._db, required this._permissions});

  // -----------------------------------------------------------------------
  // Query helpers
  // -----------------------------------------------------------------------

  /// Returns true if the transition from [current] to [target] is valid.
  bool canTransition(TaskState current, TaskState target) {
    return _validTransitions.contains((current, target));
  }

  /// Returns the set of valid target states from [current].
  Set<TaskState> validTargets(TaskState current) {
    return {
      for (final (from, to) in _validTransitions)
        if (from == current) to,
    };
  }

  // -----------------------------------------------------------------------
  // Task creation
  // -----------------------------------------------------------------------

  /// Creates a new task in created state, then immediately transitions to
  /// assigned.
  ///
  /// Requires [Permission.createTask] (Admin or Supervisor only).
  ///
  /// Returns the created [Task] (in assigned state).
  Future<Task> createTask({
    required String orgId,
    required String title,
    String? description,
    required TaskPriority priority,
    required String assigneeId,
    required String actorId,
    String? incidentId,
    double? locationLat,
    double? locationLon,
    DateTime? dueAt,
    AppLocalizations? l10n,
  }) async {
    // --- RBAC check ---
    if (!_permissions.can(Permission.createTask)) {
      final roleName = _permissions.currentRole?.name ?? 'none';
      AppLogging.tasks(
        'create task rejected (permission denied, role=$roleName)',
      );
      throw InsufficientPermissionException(
        l10n?.taskErrorCreateDenied(roleName) ??
            'createTask denied for role $roleName',
      );
    }

    final taskId = _uuid.v4();
    final now = DateTime.now();

    final task = Task(
      id: taskId,
      orgId: orgId,
      incidentId: incidentId,
      title: title,
      description: description,
      state: TaskState.assigned,
      priority: priority,
      createdBy: actorId,
      assigneeId: assigneeId,
      locationLat: locationLat,
      locationLon: locationLon,
      dueAt: dueAt,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertTask(task);

    // Record creation transition (created -> created).
    final createTransitionId = _uuid.v4();
    final createRecord = TaskTransition(
      id: createTransitionId,
      taskId: taskId,
      fromState: TaskState.created,
      toState: TaskState.created,
      actorId: actorId,
      note: 'Task created',
      timestamp: now,
    );
    await _db.insertTransition(createRecord);

    // Record assignment transition (created -> assigned).
    final assignTransitionId = _uuid.v4();
    final assignRecord = TaskTransition(
      id: assignTransitionId,
      taskId: taskId,
      fromState: TaskState.created,
      toState: TaskState.assigned,
      actorId: actorId,
      note: 'Assigned to $assigneeId',
      timestamp: now,
    );
    await _db.insertTransition(assignRecord);

    AppLogging.tasks(
      'created task $taskId '
      '(assigned to $assigneeId, priority=${priority.name})',
    );
    AppLogging.tasks(
      'transition $taskId: created -> assigned '
      '(actor=$actorId, assignee=$assigneeId)',
    );

    return task;
  }

  // -----------------------------------------------------------------------
  // Transition execution
  // -----------------------------------------------------------------------

  /// Validates and executes the transition.
  ///
  /// 1. Validates the transition is in the valid-transitions table.
  /// 2. Checks RBAC and assignee constraints.
  /// 3. Validates completion note / failure reason as required.
  /// 4. Writes transition record to `task_transitions` (append-only).
  /// 5. Updates the `tasks` projection row.
  ///
  /// For reassignment: creates a new linked task with [newAssigneeId].
  ///
  /// Throws [InvalidTransitionException] if the transition is invalid.
  /// Throws [InsufficientPermissionException] if the actor lacks the
  /// required role.
  ///
  /// Returns the [TaskTransition] record (or the reassignment transition
  /// for the original task).
  Future<TaskTransition> transition({
    required Task task,
    required TaskState target,
    required String actorId,
    required Role actorRole,
    String? newAssigneeId,
    String? completionNote,
    String? failureReason,
    String? note,
    AppLocalizations? l10n,
  }) async {
    final current = task.state;

    // --- Terminal state guard ---
    if (current.isTerminal) {
      final reason = 'terminal state: ${current.name}';
      AppLogging.tasks(
        'transition rejected ${task.id}: '
        '${current.name} -> ${target.name} ($reason)',
      );
      throw InvalidTransitionException(
        l10n?.taskErrorTerminalState(current.name) ??
            'Cannot transition from ${current.name}: $reason',
      );
    }

    // --- Valid transition check ---
    if (!canTransition(current, target)) {
      final reason =
          '${current.name} -> ${target.name} is not a valid transition';
      AppLogging.tasks(
        'transition rejected ${task.id}: '
        '${current.name} -> ${target.name} ($reason)',
      );
      throw InvalidTransitionException(
        l10n?.taskErrorInvalidTransition(current.name, target.name) ?? reason,
      );
    }

    // --- Role and assignee validation ---
    _validatePermissions(
      task: task,
      target: target,
      actorId: actorId,
      actorRole: actorRole,
      l10n: l10n,
    );

    // --- Completion note validation ---
    if (target == TaskState.completed) {
      if (completionNote == null || completionNote.length < 10) {
        throw InvalidTransitionException(
          l10n?.taskErrorCompletionNoteRequired ??
              'Completion requires a note with at least 10 characters',
        );
      }
    }

    // --- Failure reason validation ---
    if (target == TaskState.failed) {
      if (failureReason == null || failureReason.length < 10) {
        throw InvalidTransitionException(
          l10n?.taskErrorFailureReasonRequired ??
              'Failure requires a reason with at least 10 characters',
        );
      }
    }

    // --- Reassignment validation ---
    if (target == TaskState.reassigned) {
      if (newAssigneeId == null) {
        throw InvalidTransitionException(
          l10n?.taskErrorReassignmentRequiresAssignee ??
              'Reassignment requires a newAssigneeId',
        );
      }
      return _handleReassignment(
        task: task,
        actorId: actorId,
        actorRole: actorRole,
        newAssigneeId: newAssigneeId,
        note: note,
      );
    }

    // --- Write transition (append-only) ---
    final transitionId = _uuid.v4();
    final now = DateTime.now();

    final record = TaskTransition(
      id: transitionId,
      taskId: task.id,
      fromState: current,
      toState: target,
      actorId: actorId,
      note: note ?? completionNote ?? failureReason,
      timestamp: now,
    );

    await _db.insertTransition(record);

    // --- Update projection ---
    final updates = <String, dynamic>{
      'state': target.dbValue,
      'updatedAt': now.millisecondsSinceEpoch,
    };

    if (target == TaskState.completed && completionNote != null) {
      updates['completionNote'] = completionNote;
    }
    if (target == TaskState.failed && failureReason != null) {
      updates['failureReason'] = failureReason;
    }

    await _db.updateTaskProjection(task.id, updates);

    // --- Log ---
    _logTransition(
      task.id,
      current,
      target,
      actorId,
      completionNote: completionNote,
      failureReason: failureReason,
    );

    return record;
  }

  // -----------------------------------------------------------------------
  // Reassignment
  // -----------------------------------------------------------------------

  /// Handles the reassignment flow:
  /// 1. Transitions original task to REASSIGNED (terminal).
  /// 2. Creates a new linked task with new assignee in ASSIGNED state.
  /// 3. Links both tasks via reassignedTo / reassignedFrom.
  Future<TaskTransition> _handleReassignment({
    required Task task,
    required String actorId,
    required Role actorRole,
    required String newAssigneeId,
    String? note,
  }) async {
    final now = DateTime.now();
    final newTaskId = _uuid.v4();

    // 1) Transition original task to reassigned.
    final transitionId = _uuid.v4();
    final record = TaskTransition(
      id: transitionId,
      taskId: task.id,
      fromState: task.state,
      toState: TaskState.reassigned,
      actorId: actorId,
      note: note ?? 'Reassigned to new task $newTaskId',
      timestamp: now,
    );
    await _db.insertTransition(record);

    await _db.updateTaskProjection(task.id, {
      'state': TaskState.reassigned.dbValue,
      'reassignedTo': newTaskId,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    // 2) Create new linked task (starts in assigned state).
    final newTask = Task(
      id: newTaskId,
      orgId: task.orgId,
      incidentId: task.incidentId,
      title: task.title,
      description: task.description,
      state: TaskState.assigned,
      priority: task.priority,
      createdBy: actorId,
      assigneeId: newAssigneeId,
      reassignedFrom: task.id,
      locationLat: task.locationLat,
      locationLon: task.locationLon,
      dueAt: task.dueAt,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insertTask(newTask);

    // Record creation + assignment transitions for new task.
    final newCreateId = _uuid.v4();
    await _db.insertTransition(
      TaskTransition(
        id: newCreateId,
        taskId: newTaskId,
        fromState: TaskState.created,
        toState: TaskState.created,
        actorId: actorId,
        note: 'Task created via reassignment from ${task.id}',
        timestamp: now,
      ),
    );

    final newAssignId = _uuid.v4();
    await _db.insertTransition(
      TaskTransition(
        id: newAssignId,
        taskId: newTaskId,
        fromState: TaskState.created,
        toState: TaskState.assigned,
        actorId: actorId,
        note: 'Assigned to $newAssigneeId',
        timestamp: now,
      ),
    );

    AppLogging.tasks(
      'reassignment: ${task.id} -> $newTaskId '
      '(new assignee=$newAssigneeId, by=$actorId)',
    );

    return record;
  }

  // -----------------------------------------------------------------------
  // Permission validation
  // -----------------------------------------------------------------------

  /// Validates role and assignee constraints for a transition.
  void _validatePermissions({
    required Task task,
    required TaskState target,
    required String actorId,
    required Role actorRole,
    AppLocalizations? l10n,
  }) {
    switch (target) {
      // Assignment and cancellation require Admin or Supervisor.
      case TaskState.assigned:
      case TaskState.cancelled:
        if (!actorRole.hasAuthority(Role.supervisor)) {
          throw InsufficientPermissionException(
            l10n?.taskErrorRequiresSupervisorOrAdmin(
                  target.name,
                  actorRole.name,
                ) ??
                '${target.name} requires supervisor or admin role, '
                    'current role: ${actorRole.name}',
          );
        }

      // Acknowledgement: assignee only.
      case TaskState.acknowledged:
        if (actorId != task.assigneeId) {
          throw InsufficientPermissionException(
            l10n?.taskErrorOnlyAssigneeCanAcknowledge ??
                'Only the assignee can acknowledge a task',
          );
        }

      // Start work: assignee only.
      case TaskState.inProgress:
        if (actorId != task.assigneeId) {
          throw InsufficientPermissionException(
            l10n?.taskErrorOnlyAssigneeCanStartWork ??
                'Only the assignee can start work on a task',
          );
        }

      // Completion: assignee only (operator with ownerOnly, or supervisor+).
      case TaskState.completed:
        final context = PermissionContext(
          taskAssigneeId: task.assigneeId,
          currentUserId: actorId,
        );
        if (!_permissions.canWith(Permission.completeTask, context)) {
          throw InsufficientPermissionException(
            l10n?.taskErrorCompleteTaskDenied(actorRole.name) ??
                'completeTask denied for role ${actorRole.name}',
          );
        }

      // Failure: assignee only.
      case TaskState.failed:
        if (actorId != task.assigneeId) {
          throw InsufficientPermissionException(
            l10n?.taskErrorOnlyAssigneeCanReportFailure ??
                'Only the assignee can report task failure',
          );
        }

      // Reassignment: Admin or Supervisor.
      case TaskState.reassigned:
        if (!actorRole.hasAuthority(Role.supervisor)) {
          throw InsufficientPermissionException(
            l10n?.taskErrorRequiresSupervisorOrAdmin(
                  target.name,
                  actorRole.name,
                ) ??
                'Reassignment requires supervisor or admin role, '
                    'current role: ${actorRole.name}',
          );
        }

      // No permissions needed for created state (internal).
      case TaskState.created:
        break;
    }
  }

  // -----------------------------------------------------------------------
  // Logging
  // -----------------------------------------------------------------------

  void _logTransition(
    String taskId,
    TaskState from,
    TaskState to,
    String actorId, {
    String? completionNote,
    String? failureReason,
  }) {
    switch (to) {
      case TaskState.acknowledged:
        AppLogging.tasks('acknowledgement received for $taskId by $actorId');
      case TaskState.completed:
        AppLogging.tasks(
          'transition $taskId: ${from.name} -> ${to.name} '
          '(actor=$actorId, note="$completionNote")',
        );
      case TaskState.failed:
        AppLogging.tasks(
          'transition $taskId: ${from.name} -> ${to.name} '
          '(actor=$actorId, reason="$failureReason")',
        );
      default:
        AppLogging.tasks(
          'transition $taskId: ${from.name} -> ${to.name} '
          '(actor=$actorId)',
        );
    }
  }
}
