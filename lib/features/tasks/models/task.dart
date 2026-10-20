// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:socialmesh/l10n/app_localizations.dart';

/// Task lifecycle states.
///
/// 8 states forming the task state machine.
/// [completed], [cancelled], and [reassigned] are terminal - no further
/// transitions allowed.
///
/// Spec: TASK_SYSTEM.md (Sprint 007/W3.1).
enum TaskState {
  created,
  assigned,
  acknowledged,
  inProgress,
  completed,
  failed,
  cancelled,
  reassigned;

  /// Whether this state is terminal (no further transitions allowed).
  bool get isTerminal =>
      this == completed || this == cancelled || this == reassigned;

  /// Database column value (snake_case for in_progress).
  String get dbValue => switch (this) {
    TaskState.inProgress => 'in_progress',
    _ => name,
  };

  /// Parse from database column value.
  static TaskState fromDbValue(String value) => switch (value) {
    'in_progress' => TaskState.inProgress,
    _ => TaskState.values.byName(value),
  };

  /// Localised display label for this state.
  String displayLabel(AppLocalizations l10n) {
    return switch (this) {
      TaskState.created => l10n.taskStateCreated,
      TaskState.assigned => l10n.taskStateAssigned,
      TaskState.acknowledged => l10n.taskStateAcknowledged,
      TaskState.inProgress => l10n.taskStateInProgress,
      TaskState.completed => l10n.taskStateCompleted,
      TaskState.failed => l10n.taskStateFailed,
      TaskState.cancelled => l10n.taskStateCancelled,
      TaskState.reassigned => l10n.taskStateReassigned,
    };
  }
}

/// Task priority levels.
///
/// 3 levels: routine (lowest) to immediate (highest).
/// Flash is reserved for incidents only.
enum TaskPriority {
  routine,
  priority,
  immediate;

  /// Localised display label for this priority.
  String displayLabel(AppLocalizations l10n) {
    return switch (this) {
      TaskPriority.routine => l10n.taskPriorityRoutine,
      TaskPriority.priority => l10n.taskPriorityPriority,
      TaskPriority.immediate => l10n.taskPriorityImmediate,
    };
  }
}

/// A task tracked by the task system.
///
/// The [state] field is a projection derived from replaying
/// [TaskTransition] records. It is stored for query convenience
/// but the transition log is the source of truth.
///
/// Spec: TASK_SYSTEM.md (Sprint 007/W3.1).
class Task {
  final String id;
  final String orgId;
  final String? incidentId;
  final String title;
  final String? description;
  final TaskState state;
  final TaskPriority priority;
  final String createdBy;
  final String assigneeId;
  final String? completionNote;
  final String? failureReason;
  final String? reassignedTo;
  final String? reassignedFrom;
  final double? locationLat;
  final double? locationLon;
  final DateTime? dueAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;

  const Task({
    required this.id,
    required this.orgId,
    this.incidentId,
    required this.title,
    this.description,
    required this.state,
    required this.priority,
    required this.createdBy,
    required this.assigneeId,
    this.completionNote,
    this.failureReason,
    this.reassignedTo,
    this.reassignedFrom,
    this.locationLat,
    this.locationLon,
    this.dueAt,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
  });

  /// Creates a copy with the given fields replaced.
  Task copyWith({
    String? id,
    String? orgId,
    String? incidentId,
    String? title,
    String? description,
    TaskState? state,
    TaskPriority? priority,
    String? createdBy,
    String? assigneeId,
    String? completionNote,
    String? failureReason,
    String? reassignedTo,
    String? reassignedFrom,
    double? locationLat,
    double? locationLon,
    DateTime? dueAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? syncedAt,
  }) {
    return Task(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      incidentId: incidentId ?? this.incidentId,
      title: title ?? this.title,
      description: description ?? this.description,
      state: state ?? this.state,
      priority: priority ?? this.priority,
      createdBy: createdBy ?? this.createdBy,
      assigneeId: assigneeId ?? this.assigneeId,
      completionNote: completionNote ?? this.completionNote,
      failureReason: failureReason ?? this.failureReason,
      reassignedTo: reassignedTo ?? this.reassignedTo,
      reassignedFrom: reassignedFrom ?? this.reassignedFrom,
      locationLat: locationLat ?? this.locationLat,
      locationLon: locationLon ?? this.locationLon,
      dueAt: dueAt ?? this.dueAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  /// Deserialise from a SQLite row map.
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      orgId: map['orgId'] as String,
      incidentId: map['incidentId'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      state: TaskState.fromDbValue(map['state'] as String),
      priority: TaskPriority.values.byName(map['priority'] as String),
      createdBy: map['createdBy'] as String,
      assigneeId: map['assigneeId'] as String,
      completionNote: map['completionNote'] as String?,
      failureReason: map['failureReason'] as String?,
      reassignedTo: map['reassignedTo'] as String?,
      reassignedFrom: map['reassignedFrom'] as String?,
      locationLat: map['locationLat'] as double?,
      locationLon: map['locationLon'] as double?,
      dueAt: map['dueAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dueAt'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
      syncedAt: map['syncedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['syncedAt'] as int)
          : null,
    );
  }

  /// Serialise to a SQLite row map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orgId': orgId,
      'incidentId': incidentId,
      'title': title,
      'description': description,
      'state': state.dbValue,
      'priority': priority.name,
      'createdBy': createdBy,
      'assigneeId': assigneeId,
      'completionNote': completionNote,
      'failureReason': failureReason,
      'reassignedTo': reassignedTo,
      'reassignedFrom': reassignedFrom,
      'locationLat': locationLat,
      'locationLon': locationLon,
      'dueAt': dueAt?.millisecondsSinceEpoch,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'syncedAt': syncedAt?.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() =>
      'Task(id=$id, state=${state.name}, priority=${priority.name})';
}
