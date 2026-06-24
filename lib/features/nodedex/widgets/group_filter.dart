// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../models/node_group.dart';
import '../providers/node_groups_provider.dart';

// Single-select node-group filter shared by the Nodes tab and the NodeDex
// list. Lives under nodedex/ (groups are NodeDex-native, and the nodes
// feature already imports nodedex). Non-destructive (UI-only) and orthogonal
// to the presence / role filters — callers apply each in series. Membership
// lives in nodedex.db (see nodeGroupsProvider).

/// Sentinel that represents "no group filter applied".
const String groupFilterAll = '__all__';

/// Whether [nodeNum] passes the [groupId] filter given [membership]
/// (nodeNum -> set of groupIds). The [groupFilterAll] sentinel passes through.
bool matchesGroupFilter(
  Map<int, Set<String>> membership,
  int nodeNum,
  String groupId,
) {
  if (groupId == groupFilterAll) return true;
  return membership[nodeNum]?.contains(groupId) ?? false;
}

/// Resolves a stored filter selection against the live [groups] list, falling
/// back to [groupFilterAll] when the selection no longer exists.
///
/// A screen keeps its active group id in local State, but the group can be
/// deleted from the Manage Groups screen while that id is still held. Without
/// this guard the stale id matches no node and the list reads as empty (and the
/// chip row hides when the last group is removed, leaving no way to clear it)
/// until the screen is rebuilt. Callers feed the result into both the filter
/// and the chip row so deletion self-heals on the same frame.
String resolveGroupFilter(String groupId, Iterable<NodeGroup> groups) {
  if (groupId == groupFilterAll) return groupFilterAll;
  for (final group in groups) {
    if (group.id == groupId) return groupId;
  }
  return groupFilterAll;
}

/// Horizontal chip row for filtering a node list by user-defined group.
///
/// Mirrors RoleFilterChipRow: an "All" sentinel chip, one chip per group
/// (colour + icon from the group), and a trailing "Manage" chip that opens
/// the group management screen via [onManage]. Hides entirely when no groups
/// exist, so users who never created a group see no extra chrome.
///
/// [nodeNums] is the visible node-number set used for per-group counts;
/// decoupled from MeshNode / NodeDexEntry so both lists can reuse this.
class GroupFilterChipRow extends ConsumerWidget {
  final Iterable<int> nodeNums;
  final String selectedGroupId;
  final ValueChanged<String> onGroupSelected;
  final VoidCallback onManage;
  final String source;

  const GroupFilterChipRow({
    super.key,
    required this.nodeNums,
    required this.selectedGroupId,
    required this.onGroupSelected,
    required this.onManage,
    required this.source,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(nodeGroupsProvider).value;
    if (state == null || state.groups.isEmpty) return const SizedBox.shrink();

    final ids = nodeNums.toList(growable: false);
    final membership = state.membership;
    int countFor(String groupId) =>
        ids.where((n) => membership[n]?.contains(groupId) ?? false).length;

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
              StatusFilterChip(
                label: context.l10n.nodeGroupsFilterAll,
                count: ids.length,
                isSelected: selectedGroupId == groupFilterAll,
                color: context.accentColor,
                onTap: () {
                  if (selectedGroupId == groupFilterAll) return;
                  AppLogging.nodes(
                    '[GroupFilter] picked source=$source group=all',
                  );
                  onGroupSelected(groupFilterAll);
                },
              ),
              const SizedBox(width: AppTheme.spacing8),
              for (final group in state.groups) ...[
                StatusFilterChip(
                  label: group.name,
                  count: countFor(group.id),
                  isSelected: selectedGroupId == group.id,
                  color: group.color,
                  icon: group.icon,
                  onTap: () {
                    if (selectedGroupId == group.id) return;
                    AppLogging.nodes(
                      '[GroupFilter] picked source=$source group=${group.id}',
                    );
                    onGroupSelected(group.id);
                  },
                ),
                const SizedBox(width: AppTheme.spacing8),
              ],
              StatusFilterChip(
                label: context.l10n.nodeGroupsManageChip,
                isSelected: false,
                color: context.textTertiary,
                icon: Icons.tune,
                onTap: onManage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
