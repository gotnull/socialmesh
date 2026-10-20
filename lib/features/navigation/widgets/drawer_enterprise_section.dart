// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/auth/permission.dart';
import '../../../core/auth/permission_provider.dart';
import '../../../core/auth/role.dart';
import '../../../core/widgets/permission_gate.dart';
import '../../../core/widgets/role_gate.dart';
import '../../../services/haptic_service.dart';
import '../../incidents/screens/incident_list_screen.dart';
import 'drawer_menu_tile.dart';

/// Enterprise (RBAC) section in the drawer - visible only to org members.
///
/// Consumer users (no orgId/role) see nothing. Org members see items gated
/// by their role using [PermissionGate] and [RoleGate].
///
/// Spec: RBAC.md (Sprint 007), Sprint 008/W2.2.
class DrawerEnterpriseSection extends ConsumerWidget {
  final void Function(Widget screen) onNavigate;

  const DrawerEnterpriseSection({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(permissionServiceProvider);

    // Consumer users see nothing - no orgId means no enterprise section.
    if (service.currentOrgId == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 8, top: 8),
          child: Row(
            children: [
              Icon(
                Icons.business,
                size: 14,
                color: AccentColors.teal.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                context.l10n.drawerEnterpriseSectionHeader,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AccentColors.teal.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              // View team incidents - all org roles (observer+)
              RoleGate(
                minRole: Role.observer,
                child: DrawerMenuTile(
                  icon: Icons.warning_amber_outlined,
                  label: context.l10n.drawerEnterpriseIncidents,
                  isSelected: false,
                  iconColor: AccentColors.red,
                  onTap: () {
                    ref.haptics.tabChange();
                    onNavigate(const IncidentListScreen());
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacing4),

              // View team tasks - all org roles (observer+)
              RoleGate(
                minRole: Role.observer,
                child: DrawerMenuTile(
                  icon: Icons.task_alt_outlined,
                  label: context.l10n.drawerEnterpriseTasks,
                  isSelected: false,
                  iconColor: AccentColors.blue,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Placeholder: enterprise screens not yet built (W4.3)
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacing4),

              // Create field report - operator+
              PermissionGate(
                permission: Permission.createFieldReport,
                child: DrawerMenuTile(
                  icon: Icons.description_outlined,
                  label: context.l10n.drawerEnterpriseFieldReports,
                  isSelected: false,
                  iconColor: AccentColors.green,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Placeholder: enterprise screens not yet built (W5.1)
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacing4),

              // Export reports - supervisor+
              PermissionGate(
                permission: Permission.exportReports,
                mode: PermissionGateMode.disabled,
                deniedTooltip: context.l10n.drawerEnterpriseExportDenied,
                child: DrawerMenuTile(
                  icon: Icons.summarize_outlined,
                  label: context.l10n.drawerEnterpriseReports,
                  isSelected: false,
                  iconColor: AccentColors.indigo,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Placeholder: enterprise screens not yet built (W5.3)
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacing4),

              // Manage users - admin only
              RoleGate(
                minRole: Role.admin,
                child: DrawerMenuTile(
                  icon: Icons.people_outline,
                  label: context.l10n.drawerEnterpriseUserManagement,
                  isSelected: false,
                  iconColor: AccentColors.orange,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Placeholder: enterprise screens not yet built (W6.3)
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacing4),

              // Manage devices - admin only
              RoleGate(
                minRole: Role.admin,
                child: DrawerMenuTile(
                  icon: Icons.devices_outlined,
                  label: context.l10n.drawerEnterpriseDeviceManagement,
                  isSelected: false,
                  iconColor: AccentColors.slate,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Placeholder: enterprise screens not yet built (W6.3)
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacing4),

              // Configure org settings - admin only
              RoleGate(
                minRole: Role.admin,
                child: DrawerMenuTile(
                  icon: Icons.settings_outlined,
                  label: context.l10n.drawerEnterpriseOrgSettings,
                  isSelected: false,
                  iconColor: AccentColors.purple,
                  onTap: () {
                    ref.haptics.tabChange();
                    // Placeholder: enterprise screens not yet built
                  },
                ),
              ),
            ],
          ),
        ),

        // Divider after enterprise section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Divider(
            color: theme.dividerColor.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.1 : 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
