// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/permission.dart';
import '../auth/permission_provider.dart';
import '../logging.dart';

/// Display mode when permission is denied.
enum PermissionGateMode {
  /// Hides the child completely (returns [SizedBox.shrink]).
  hidden,

  /// Renders the child greyed-out and non-interactive with a tooltip.
  disabled,
}

/// A widget that gates its [child] behind an RBAC [Permission] check.
///
/// Uses [permissionServiceProvider] to evaluate [PermissionService.can].
/// Reacts to live claims/entitlement changes via provider rebuilds.
///
/// In [PermissionGateMode.hidden] (default), the child is replaced with
/// [SizedBox.shrink] when the permission is denied.
///
/// In [PermissionGateMode.disabled], the child is rendered at reduced opacity,
/// wrapped in [IgnorePointer], and given a [Tooltip] explaining the required
/// permission.
///
/// Consumer users (no role) are always denied.
///
/// Spec: RBAC.md (Sprint 007), Sprint 008/W2.2.
class PermissionGate extends ConsumerWidget {
  /// The permission action to check.
  final Permission permission;

  /// The widget to show when the permission is granted.
  final Widget child;

  /// How to handle denial. Defaults to [PermissionGateMode.hidden].
  final PermissionGateMode mode;

  /// Optional custom tooltip text when [mode] is [PermissionGateMode.disabled].
  /// Defaults to `"Requires {permission}"` if not provided.
  final String? deniedTooltip;

  /// Opacity for the disabled state. Defaults to 0.38 (Material disabled).
  final double disabledOpacity;

  const PermissionGate({
    super.key,
    required this.permission,
    required this.child,
    this.mode = PermissionGateMode.hidden,
    this.deniedTooltip,
    this.disabledOpacity = 0.38,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(permissionServiceProvider);
    final allowed = service.can(permission);
    final roleName = service.currentRole?.name ?? 'none';

    if (allowed) {
      AppLogging.uiGates(
        'PermissionGate(${permission.name}) -> visible (role=$roleName)',
      );
      return child;
    }

    if (mode == PermissionGateMode.disabled) {
      final tooltip =
          deniedTooltip ?? 'Requires ${_humanReadable(permission.name)}';
      AppLogging.uiGates(
        'disabled button: ${permission.name} '
        '(role=$roleName, requires ${_requiredRoleHint(permission)})',
      );
      return Tooltip(
        message: tooltip,
        child: IgnorePointer(
          child: Opacity(opacity: disabledOpacity, child: child),
        ),
      );
    }

    // Hidden mode
    AppLogging.uiGates(
      'PermissionGate(${permission.name}) -> hidden (role=$roleName)',
    );
    return const SizedBox.shrink();
  }

  /// Converts camelCase permission name to a human-readable label.
  static String _humanReadable(String name) {
    return name
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => ' ${m.group(1)!.toLowerCase()}',
        )
        .trim();
  }

  /// Provides a best-effort hint about the minimum role required for a
  /// permission, based on the matrix structure.
  static String _requiredRoleHint(Permission permission) {
    // Admin-only actions
    const adminOnly = {
      Permission.manageUsers,
      Permission.manageDevices,
      Permission.configureOrgSettings,
    };
    // Supervisor+ actions
    const supervisorPlus = {
      Permission.assignIncident,
      Permission.closeIncident,
      Permission.cancelIncident,
      Permission.createTask,
      Permission.assignTask,
      Permission.exportReports,
    };

    if (adminOnly.contains(permission)) return 'admin';
    if (supervisorPlus.contains(permission)) return 'supervisor';
    return 'operator';
  }
}
