// SPDX-License-Identifier: GPL-3.0-or-later
import '../logging.dart';
import 'permission.dart';
import 'permission_context.dart';
import 'permission_matrix.dart';
import 'role.dart';

/// Thrown when a permission or role requirement is not met.
class InsufficientPermissionException implements Exception {
  final String message;
  const InsufficientPermissionException(this.message);

  @override
  String toString() => 'InsufficientPermissionException: $message';
}

/// Centralised permission enforcement service.
///
/// Reads the current user's role from claims and resolves all 68 cells of the
/// RBAC permission matrix. All checks are synchronous from cached state.
///
/// Entitlement precedence: if [isEntitlementReadOnly] is true, all write-action
/// permissions return false regardless of role.
///
/// Consumer users (no role) have all enterprise permissions denied.
///
/// Spec: RBAC.md (Sprint 007/W2.2), Sprint 008/W2.1.
class PermissionService {
  final Role? _role;
  final String? _orgId;
  final bool _isEntitlementReadOnly;

  /// Creates a [PermissionService] from the current claims and entitlement
  /// state.
  ///
  /// [role] is null for consumer users (no org membership).
  /// [orgId] is the user's organisation ID; null for consumers.
  /// [isEntitlementReadOnly] gates all write permissions when true.
  PermissionService({
    required Role? role,
    required String? orgId,
    bool isEntitlementReadOnly = false,
  }) : _role = role,
       _orgId = orgId,
       _isEntitlementReadOnly = isEntitlementReadOnly;

  /// The current user's role, or null if not authenticated / no org.
  Role? get currentRole => _role;

  /// The current user's orgId, or null if not in an org.
  String? get currentOrgId => _orgId;

  /// Returns true if the current user has permission to perform [action].
  ///
  /// Uses cached claims. No network call. For conditional permissions (Y*),
  /// returns false without context -- use [canWith] instead.
  bool can(Permission action) {
    if (_role == null) {
      AppLogging.claims(
        'Permission: can(${action.name}) -> false (consumer user)',
      );
      return false;
    }

    // Entitlement precedence: write actions denied when readOnly.
    if (_isEntitlementReadOnly && PermissionMatrix.isWriteAction(action)) {
      AppLogging.claims(
        'Permission: can(${action.name}) -> false '
        '(entitlement=readOnly, write denied)',
      );
      return false;
    }

    final result = PermissionMatrix.evaluate(action, _role);

    AppLogging.claims(
      'Permission: can(${action.name}) -> $result (role=${_role.name})',
    );
    return result;
  }

  /// Returns true if the current user has permission to perform [action]
  /// given a specific [context] (e.g., incident ownership check).
  ///
  /// Evaluates Y* (owner exception) cells using [context].
  bool canWith(Permission action, PermissionContext context) {
    if (_role == null) {
      AppLogging.claims(
        'Permission: canWith(${action.name}) -> false (consumer user)',
      );
      return false;
    }

    // Entitlement precedence: write actions denied when readOnly.
    if (_isEntitlementReadOnly && PermissionMatrix.isWriteAction(action)) {
      AppLogging.claims(
        'Permission: canWith(${action.name}) -> false '
        '(entitlement=readOnly, write denied)',
      );
      return false;
    }

    final result = PermissionMatrix.evaluate(action, _role, context: context);

    // Build contextual log suffix for Y* cells.
    final cell = PermissionMatrix.lookup(action, _role);
    String suffix = '';
    if (cell == CellResult.ownerOnly) {
      if (action == Permission.resolveIncident) {
        suffix = ', assigneeId ${result ? "matches" : "mismatch"}';
      } else if (action == Permission.completeTask) {
        suffix = ', taskAssigneeId ${result ? "matches" : "mismatch"}';
      }
    }

    AppLogging.claims(
      'Permission: canWith(${action.name}) -> $result '
      '(role=${_role.name}$suffix)',
    );
    return result;
  }

  /// Throws [InsufficientPermissionException] if the current user does not
  /// have the required [minimumRole] or higher.
  void requireRole(Role minimumRole) {
    if (_role == null || !_role.hasAuthority(minimumRole)) {
      final roleName = _role?.name ?? 'none';
      AppLogging.claims(
        'Permission: requireRole(${minimumRole.name}) '
        'threw InsufficientPermissionException (role=$roleName)',
      );
      throw InsufficientPermissionException(
        'Requires ${minimumRole.name} role, current role: $roleName',
      );
    }
  }

  /// Throws [InsufficientPermissionException] if [can(action)] returns false.
  void require(Permission action) {
    if (!can(action)) {
      final roleName = _role?.name ?? 'none';
      AppLogging.claims(
        'Permission: require(${action.name}) '
        'threw InsufficientPermissionException (role=$roleName)',
      );
      throw InsufficientPermissionException(
        'Permission ${action.name} denied for role: $roleName',
      );
    }
  }
}
