// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/permission_provider.dart';
import '../auth/role.dart';
import '../logging.dart';

/// A widget that gates its [child] behind a minimum [Role] threshold.
///
/// Uses [permissionServiceProvider] to read the current role. If the user's
/// role is null (consumer user) or below [minRole], the child is hidden.
///
/// Reacts to live claims changes via provider rebuilds.
///
/// Spec: RBAC.md (Sprint 007), Sprint 008/W2.2.
class RoleGate extends ConsumerWidget {
  /// The minimum role required to see [child].
  final Role minRole;

  /// The widget to show when the role requirement is met.
  final Widget child;

  const RoleGate({super.key, required this.minRole, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(permissionServiceProvider);
    final currentRole = service.currentRole;
    final roleName = currentRole?.name ?? 'none';

    if (currentRole != null && currentRole.hasAuthority(minRole)) {
      AppLogging.uiGates(
        'RoleGate(minRole=${minRole.name}) -> visible (role=$roleName)',
      );
      return child;
    }

    AppLogging.uiGates(
      'RoleGate(minRole=${minRole.name}) -> hidden (role=$roleName)',
    );
    return const SizedBox.shrink();
  }
}
