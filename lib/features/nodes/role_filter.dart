// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/theme.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../models/mesh_models.dart';

/// Single-select role filter shared between the Nodes tab and Messages
/// > Contacts. The filter is non-destructive (UI-only) and orthogonal
/// to the existing presence-based filters (active / favorites / etc.) —
/// callers apply both in series.
///
/// Roles are stored on [MeshNode.role] as the protobuf enum's `name`
/// string (e.g. `"CLIENT"`, `"ROUTER"`). We render only roles actually
/// present in the visible dataset so 1000+ node meshes don't see a
/// 13-chip wall of empty buckets.

/// Sentinel that represents "no role filter applied". Stored in
/// state alongside concrete role strings to keep the type uniform.
const String roleFilterAll = '__all__';

/// Returns the set of distinct role values present in [nodes], plus
/// the `roleFilterAll` sentinel.
///
/// Nodes with a null/empty role contribute the literal empty string
/// `''` — callers can decide whether to render an "Unknown" chip for
/// it. We do not render that bucket today because Meshtastic nodes
/// almost always advertise a role; flipping it on later is a one-line
/// change in [buildRoleFilterChips].
Set<String> distinctRolesIn(Iterable<MeshNode> nodes) {
  final result = <String>{roleFilterAll};
  for (final node in nodes) {
    final role = node.role;
    if (role != null && role.isNotEmpty) {
      result.add(role);
    }
  }
  return result;
}

/// Counts nodes per role, including a `roleFilterAll` bucket for the
/// total visible count.
Map<String, int> countNodesByRole(Iterable<MeshNode> nodes) {
  final counts = <String, int>{roleFilterAll: 0};
  for (final node in nodes) {
    counts[roleFilterAll] = (counts[roleFilterAll] ?? 0) + 1;
    final role = node.role;
    if (role == null || role.isEmpty) continue;
    counts[role] = (counts[role] ?? 0) + 1;
  }
  return counts;
}

/// Filters [nodes] by [role]. The `roleFilterAll` sentinel is a
/// pass-through. Null or empty roles never match a concrete filter
/// (use [roleFilterAll] to surface them).
Iterable<MeshNode> applyRoleFilter(Iterable<MeshNode> nodes, String role) {
  if (role == roleFilterAll) return nodes;
  return nodes.where((n) => n.role == role);
}

/// Localized label for a protobuf role enum name.
///
/// Falls back to a title-cased version of the raw name when no ARB
/// key is wired (e.g. a future Meshtastic role lands before we ship
/// a translation).
String roleDisplayLabel(BuildContext context, String role) {
  switch (role) {
    case roleFilterAll:
      return context.l10n.roleFilterAll;
    case 'CLIENT':
      return context.l10n.roleClient;
    case 'CLIENT_MUTE':
      return context.l10n.roleClientMute;
    case 'ROUTER':
      return context.l10n.roleRouter;
    case 'ROUTER_CLIENT':
      return context.l10n.roleRouterClient;
    case 'REPEATER':
      return context.l10n.roleRepeater;
    case 'TRACKER':
      return context.l10n.roleTracker;
    case 'SENSOR':
      return context.l10n.roleSensor;
    case 'TAK':
      return context.l10n.roleTak;
    case 'CLIENT_HIDDEN':
      return context.l10n.roleClientHidden;
    case 'LOST_AND_FOUND':
      return context.l10n.roleLostAndFound;
    case 'TAK_TRACKER':
      return context.l10n.roleTakTracker;
    case 'ROUTER_LATE':
      return context.l10n.roleRouterLate;
    case 'CLIENT_BASE':
      return context.l10n.roleClientBase;
    default:
      // Future-proofing: a brand-new Meshtastic role enum will fall
      // through to this branch. Render the raw name in title case
      // until we add a translation.
      return _titleCaseEnumName(role);
  }
}

String _titleCaseEnumName(String raw) {
  return raw
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}

/// Accent color for the role chip. We use SocialMesh's existing
/// AccentColors so the role row visually echoes the rest of the
/// status-chip family.
Color _roleColor(BuildContext context, String role) {
  switch (role) {
    case roleFilterAll:
      return context.accentColor;
    case 'CLIENT':
    case 'CLIENT_BASE':
      return AccentColors.sky;
    case 'CLIENT_MUTE':
    case 'CLIENT_HIDDEN':
      return context.textTertiary;
    case 'ROUTER':
    case 'ROUTER_CLIENT':
    case 'ROUTER_LATE':
      return AccentColors.emerald;
    case 'REPEATER':
      return AccentColors.purple;
    case 'TRACKER':
    case 'TAK_TRACKER':
      return AccentColors.orange;
    case 'SENSOR':
      return AccentColors.cyan;
    case 'TAK':
      return AccentColors.red;
    case 'LOST_AND_FOUND':
      return AppTheme.warningYellow;
    default:
      return context.accentColor;
  }
}

IconData? _roleIcon(String role) {
  switch (role) {
    case roleFilterAll:
      return null;
    case 'CLIENT':
    case 'CLIENT_BASE':
    case 'CLIENT_HIDDEN':
      return Icons.person_outline;
    case 'CLIENT_MUTE':
      return Icons.notifications_off_outlined;
    case 'ROUTER':
    case 'ROUTER_CLIENT':
    case 'ROUTER_LATE':
      return Icons.router_outlined;
    case 'REPEATER':
      return Icons.cell_tower;
    case 'TRACKER':
    case 'TAK_TRACKER':
      return Icons.my_location;
    case 'SENSOR':
      return Icons.sensors;
    case 'TAK':
      return Icons.security;
    case 'LOST_AND_FOUND':
      return Icons.help_outline;
    default:
      return null;
  }
}

/// Wraps a horizontal-scroll role chip row.
///
/// Used by both the Nodes tab and Messages > Contacts as a sliver/box
/// adapter above the list. Hides itself entirely when only the
/// `roleFilterAll` bucket would render — there's no signal in a
/// single-chip filter row.
///
/// [source] is the marker logged when the user picks a chip — pass
/// `'nodes_tab'` or `'contacts'` so triage can tell which surface
/// drove the change.
class RoleFilterChipRow extends StatelessWidget {
  final Iterable<MeshNode> nodes;
  final String selectedRole;
  final ValueChanged<String> onRoleSelected;
  final String source;

  const RoleFilterChipRow({
    super.key,
    required this.nodes,
    required this.selectedRole,
    required this.onRoleSelected,
    required this.source,
  });

  @override
  Widget build(BuildContext context) {
    final counts = countNodesByRole(nodes);
    // Anything > 1 means we have at least one concrete role to filter
    // on (we always include `roleFilterAll`).
    if (counts.length <= 1) return const SizedBox.shrink();

    final roles = counts.keys.toList()
      ..sort((a, b) {
        if (a == roleFilterAll) return -1;
        if (b == roleFilterAll) return 1;
        return a.compareTo(b);
      });

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: EdgeFade.end(
        fadeSize: 32,
        fadeColor: context.background,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Row(
            children: [
              for (final role in roles) ...[
                StatusFilterChip(
                  label: roleDisplayLabel(context, role),
                  count: counts[role] ?? 0,
                  isSelected: selectedRole == role,
                  color: _roleColor(context, role),
                  icon: _roleIcon(role),
                  onTap: () {
                    if (selectedRole == role) return;
                    AppLogging.nodes(
                      '[RoleFilter] picked source=$source role=$role '
                      'count=${counts[role]}',
                    );
                    onRoleSelected(role);
                  },
                ),
                const SizedBox(width: AppTheme.spacing8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
