// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';

/// Context for conditional permission checks (Y* owner-exception).
///
/// Passed to [PermissionService.canWith] when the permission is conditional
/// on ownership (e.g., Operator resolving their own incident).
///
/// Spec: RBAC.md (Sprint 007/W2.2).
@immutable
class PermissionContext {
  /// The incident's current assignee ID (for resolve checks).
  final String? incidentAssigneeId;

  /// The task's current assignee ID (for complete checks).
  final String? taskAssigneeId;

  /// The current actor's user ID.
  final String currentUserId;

  const PermissionContext({
    this.incidentAssigneeId,
    this.taskAssigneeId,
    required this.currentUserId,
  });

  /// Whether [currentUserId] matches [incidentAssigneeId].
  bool get isIncidentOwner =>
      incidentAssigneeId != null && incidentAssigneeId == currentUserId;

  /// Whether [currentUserId] matches [taskAssigneeId].
  bool get isTaskOwner =>
      taskAssigneeId != null && taskAssigneeId == currentUserId;
}
