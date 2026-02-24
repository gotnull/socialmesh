// SPDX-License-Identifier: GPL-3.0-or-later
import 'permission.dart';
import 'permission_context.dart';
import 'role.dart';

/// Outcome of a single permission matrix cell.
///
/// - [granted]: unconditionally permitted (Y).
/// - [denied]: unconditionally denied (N).
/// - [ownerOnly]: conditionally permitted when actorId == ownerId (Y*).
enum CellResult { granted, denied, ownerOnly }

/// The 17x4 permission matrix as an explicit data structure.
///
/// Each cell is a [CellResult]. The matrix is the single source of truth
/// for all RBAC lookups. No if/else chains.
///
/// Spec: RBAC.md (Sprint 007/W2.2), Sprint 008/W2.1.
class PermissionMatrix {
  PermissionMatrix._();

  /// Lookup map: permission -> role -> cell result.
  ///
  /// Rows are the 17 [Permission] values; columns are the 4 [Role] values.
  static const Map<Permission, Map<Role, CellResult>> matrix = {
    // 1. Create incident (DRAFT)
    Permission.createIncident: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.granted,
      Role.observer: CellResult.denied,
    },
    // 2. Submit incident (DRAFT -> OPEN)
    Permission.submitIncident: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.granted,
      Role.observer: CellResult.denied,
    },
    // 3. Assign incident
    Permission.assignIncident: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
    // 4. Escalate incident
    Permission.escalateIncident: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.granted,
      Role.observer: CellResult.denied,
    },
    // 5. Resolve incident (Y* for Operator)
    Permission.resolveIncident: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.ownerOnly,
      Role.observer: CellResult.denied,
    },
    // 6. Close incident
    Permission.closeIncident: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
    // 7. Cancel incident
    Permission.cancelIncident: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
    // 8. Create field report
    Permission.createFieldReport: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.granted,
      Role.observer: CellResult.denied,
    },
    // 9. Create task
    Permission.createTask: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
    // 10. Assign task
    Permission.assignTask: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
    // 11. Complete task (Y* for Operator)
    Permission.completeTask: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.ownerOnly,
      Role.observer: CellResult.denied,
    },
    // 12. View team incidents
    Permission.viewTeamIncidents: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.granted,
      Role.observer: CellResult.granted,
    },
    // 13. View team tasks
    Permission.viewTeamTasks: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.granted,
      Role.observer: CellResult.granted,
    },
    // 14. Export reports
    Permission.exportReports: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.granted,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
    // 15. Manage users
    Permission.manageUsers: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.denied,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
    // 16. Manage devices
    Permission.manageDevices: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.denied,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
    // 17. Configure org settings
    Permission.configureOrgSettings: {
      Role.admin: CellResult.granted,
      Role.supervisor: CellResult.denied,
      Role.operator: CellResult.denied,
      Role.observer: CellResult.denied,
    },
  };

  /// Read-only permissions that are allowed even when entitlement is readOnly.
  static const Set<Permission> readOnlyPermissions = {
    Permission.viewTeamIncidents,
    Permission.viewTeamTasks,
  };

  /// Whether [action] is a write action (denied when entitlement <= readOnly).
  static bool isWriteAction(Permission action) =>
      !readOnlyPermissions.contains(action);

  /// Resolves the raw [CellResult] for a given [action] and [role].
  ///
  /// Returns null if [role] is null (consumer user -- no enterprise access).
  static CellResult? lookup(Permission action, Role? role) {
    if (role == null) return null;
    return matrix[action]?[role];
  }

  /// Evaluates a cell, resolving [CellResult.ownerOnly] using [context].
  ///
  /// Returns true if the cell is [CellResult.granted], or if it is
  /// [CellResult.ownerOnly] and the ownership check passes.
  static bool evaluate(
    Permission action,
    Role? role, {
    PermissionContext? context,
  }) {
    final cell = lookup(action, role);
    if (cell == null) return false; // consumer user
    switch (cell) {
      case CellResult.granted:
        return true;
      case CellResult.denied:
        return false;
      case CellResult.ownerOnly:
        if (context == null) return false;
        return _evaluateOwnership(action, context);
    }
  }

  static bool _evaluateOwnership(Permission action, PermissionContext context) {
    switch (action) {
      case Permission.resolveIncident:
        return context.isIncidentOwner;
      case Permission.completeTask:
        return context.isTaskOwner;
      default:
        return false;
    }
  }
}
