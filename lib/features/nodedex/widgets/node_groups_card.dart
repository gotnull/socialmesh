// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../models/node_group.dart';
import '../providers/node_groups_provider.dart';
import 'node_group_assign_sheet.dart';
import 'nodedex_card.dart';

/// Detail-screen card showing which groups a node belongs to, with an edit
/// affordance that opens the assignment sheet. Reusable across the NodeDex
/// detail screen and the Nodes detail screen (both key on nodeNum).
class NodeGroupsCard extends ConsumerWidget {
  final int nodeNum;
  final String? nodeName;

  const NodeGroupsCard({super.key, required this.nodeNum, this.nodeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(nodeGroupsProvider).value;
    final ids = state?.groupsForNode(nodeNum) ?? const <String>{};
    final groups = state == null
        ? const <NodeGroup>[]
        : [
            for (final group in state.groups)
              if (ids.contains(group.id)) group,
          ];

    return NodeDexCard(
      title: l10n.nodeGroupsSectionTitle,
      icon: Icons.category_outlined,
      headingTrailing: IconButton(
        icon: const Icon(Icons.edit_outlined, size: 18),
        tooltip: l10n.nodeGroupsEditTooltip,
        color: context.textSecondary,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: () => NodeGroupAssignSheet.show(
          context,
          nodeNum: nodeNum,
          nodeName: nodeName,
        ),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: groups.isEmpty
            ? Text(
                l10n.nodeGroupsNone,
                style: TextStyle(fontSize: 13, color: context.textTertiary),
              )
            : Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: [
                  for (final group in groups) _GroupChip(group: group),
                ],
              ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final NodeGroup group;

  const _GroupChip({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: group.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(color: group.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(group.icon, size: 14, color: group.color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            group.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: group.color,
            ),
          ),
        ],
      ),
    );
  }
}
