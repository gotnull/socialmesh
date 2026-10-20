// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'task.dart';

/// An immutable record of a state transition on a task.
///
/// The `task_transitions` table is append-only - rows are never deleted.
/// This table is the source of truth for task state. The `tasks.state`
/// column is a derived projection rebuilt by replaying transitions.
///
/// Spec: TASK_SYSTEM.md (Sprint 007/W3.1).
class TaskTransition {
  /// UUID v4 generated at creation time.
  final String id;

  final String taskId;
  final TaskState fromState;
  final TaskState toState;

  /// Firebase UID of the actor who triggered the transition.
  final String actorId;

  /// Optional free-text note (maxLength: 500).
  final String? note;

  /// Epoch-millisecond timestamp of when the transition occurred.
  final DateTime timestamp;

  const TaskTransition({
    required this.id,
    required this.taskId,
    required this.fromState,
    required this.toState,
    required this.actorId,
    this.note,
    required this.timestamp,
  });

  /// Deserialise from a SQLite row map.
  factory TaskTransition.fromMap(Map<String, dynamic> map) {
    return TaskTransition(
      id: map['id'] as String,
      taskId: map['taskId'] as String,
      fromState: TaskState.fromDbValue(map['fromState'] as String),
      toState: TaskState.fromDbValue(map['toState'] as String),
      actorId: map['actorId'] as String,
      note: map['note'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  /// Serialise to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taskId': taskId,
      'fromState': fromState.dbValue,
      'toState': toState.dbValue,
      'actorId': actorId,
      'note': note,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'TaskTransition(id=$id, ${fromState.name} -> ${toState.name})';
}
