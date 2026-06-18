// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/splash_mesh_provider.dart';
import '../models/node_group.dart';
import '../providers/node_groups_provider.dart';
import '../widgets/node_group_edit_sheet.dart';

/// Manage screen for user-defined node groups: create, edit, recolor, delete.
class ManageNodeGroupsScreen extends ConsumerStatefulWidget {
  const ManageNodeGroupsScreen({super.key});

  @override
  ConsumerState<ManageNodeGroupsScreen> createState() =>
      _ManageNodeGroupsScreenState();
}

class _ManageNodeGroupsScreenState extends ConsumerState<ManageNodeGroupsScreen>
    with LifecycleSafeMixin<ManageNodeGroupsScreen> {
  void _openCreate() {
    HapticFeedback.lightImpact();
    NodeGroupEditSheet.show(
      context,
      onSave: (name, colorValue, iconKey) {
        ref
            .read(nodeGroupsProvider.notifier)
            .createGroup(name: name, colorValue: colorValue, iconKey: iconKey);
      },
    );
  }

  void _openEdit(NodeGroup group) {
    HapticFeedback.lightImpact();
    NodeGroupEditSheet.show(
      context,
      existing: group,
      onSave: (name, colorValue, iconKey) {
        ref
            .read(nodeGroupsProvider.notifier)
            .updateGroup(
              group.copyWith(
                name: name,
                colorValue: colorValue,
                iconKey: iconKey,
              ),
            );
      },
    );
  }

  Future<void> _confirmDelete(NodeGroup group) async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.nodeGroupsDeleteTitle,
      message: l10n.nodeGroupsDeleteMessage(group.name),
      confirmLabel: l10n.nodeGroupsDeleteAction,
      isDestructive: true,
    );
    if (!mounted) return;
    if (confirmed == true) {
      ref.read(nodeGroupsProvider.notifier).deleteGroup(group.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(nodeGroupsProvider);

    return GlassScaffold(
      title: l10n.nodeGroupsManageTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.nodeGroupsCreateTooltip,
          onPressed: _openCreate,
        ),
      ],
      slivers: groupsAsync.when(
        loading: () => [
          const SliverFillRemaining(child: ScreenLoadingIndicator()),
        ],
        error: (e, _) => [
          SliverFillRemaining(
            child: Center(
              child: Text(
                l10n.nodeGroupsLoadError,
                style: TextStyle(color: context.textSecondary),
              ),
            ),
          ),
        ],
        data: (state) {
          if (state.groups.isEmpty) {
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: AnimatedEmptyState(
                  config: AnimatedEmptyStateConfig(
                    icons: const [
                      Icons.group,
                      Icons.label,
                      Icons.router,
                      Icons.star,
                      Icons.hub,
                    ],
                    taglines: [l10n.nodeGroupsEmptyDescription],
                    titlePrefix: l10n.nodeGroupsEmptyTitlePrefix,
                    titleKeyword: l10n.nodeGroupsEmptyTitleKeyword,
                    titleSuffix: l10n.nodeGroupsEmptyTitleSuffix,
                    actionLabel: l10n.nodeGroupsCreateFirst,
                    actionIcon: Icons.add,
                    onAction: _openCreate,
                  ),
                ),
              ),
            ];
          }
          return [
            SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final group = state.groups[index];
                  return _GroupCard(
                    group: group,
                    nodeCount: state.nodeCount(group.id),
                    onEdit: () => _openEdit(group),
                    onDelete: () => _confirmDelete(group),
                  );
                }, childCount: state.groups.length),
              ),
            ),
          ];
        },
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final NodeGroup group;
  final int nodeCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroupCard({
    required this.group,
    required this.nodeCount,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: group.color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(group.icon, size: 20, color: group.color),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.nodeGroupsNodeCount(nodeCount),
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: context.l10n.nodeGroupsEditTooltip,
                color: context.textSecondary,
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: context.l10n.nodeGroupsDeleteAction,
                color: AppTheme.errorRed,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
