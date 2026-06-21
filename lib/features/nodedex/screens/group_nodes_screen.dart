// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/splash_mesh_provider.dart';
import '../../../services/haptic_service.dart';
import '../../nodes/node_display_name_resolver.dart';
import '../models/node_group.dart';
import '../providers/node_groups_provider.dart';

/// Lists the nodes assigned to a single group, with tap-to-select multi-select
/// and a destructive bottom action to remove the selected nodes from the group.
/// Removing only clears membership; the nodes stay in the user's node list.
class GroupNodesScreen extends ConsumerStatefulWidget {
  final NodeGroup group;

  const GroupNodesScreen({super.key, required this.group});

  @override
  ConsumerState<GroupNodesScreen> createState() => _GroupNodesScreenState();
}

class _GroupNodesScreenState extends ConsumerState<GroupNodesScreen>
    with LifecycleSafeMixin<GroupNodesScreen> {
  final Set<int> _selected = <int>{};

  void _toggle(int nodeNum) {
    ref.haptics.itemSelect();
    safeSetState(() {
      if (!_selected.add(nodeNum)) _selected.remove(nodeNum);
    });
  }

  Future<void> _confirmRemove(NodeGroup group) async {
    final l10n = context.l10n;
    final notifier = ref.read(nodeGroupsProvider.notifier);
    final haptics = ref.haptics;
    final toRemove = {..._selected};
    if (toRemove.isEmpty) return;

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.nodeGroupsRemoveTitle,
      message: l10n.nodeGroupsRemoveMessage(toRemove.length, group.name),
      confirmLabel: l10n.nodeGroupsRemoveAction,
      isDestructive: true,
    );
    if (!mounted) return;
    if (confirmed != true) return;

    await haptics.destructive();
    await notifier.removeNodesFromGroup(toRemove, group.id);
    if (!mounted) return;
    safeSetState(() => _selected.clear());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(nodeGroupsProvider);
    final nodes = ref.watch(nodesProvider);

    // Resolve the live group so an edit (rename / recolour) made elsewhere is
    // reflected here; fall back to the pushed snapshot if it was just deleted.
    final state = groupsAsync.value;
    final group =
        state?.groups.firstWhere(
          (g) => g.id == widget.group.id,
          orElse: () => widget.group,
        ) ??
        widget.group;

    final selectedCount = _selected.length;

    return GlassScaffold(
      title: group.name,
      bottomNavigationBar: selectedCount == 0
          ? null
          : BottomActionBar(
              child: PrimaryGradientButton(
                label: l10n.nodeGroupsRemoveButton(selectedCount),
                icon: Icons.remove_circle_outline,
                accentColor: AppTheme.errorRed,
                onPressed: () => _confirmRemove(group),
              ),
            ),
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
          String nameFor(int n) =>
              nodes[n]?.displayName ??
              NodeDisplayNameResolver.resolve(nodeNum: n);

          final memberNums = state.nodesInGroup(group.id)
            ..sort(
              (a, b) =>
                  nameFor(a).toLowerCase().compareTo(nameFor(b).toLowerCase()),
            );

          if (memberNums.isEmpty) {
            return [
              SliverFillRemaining(
                hasScrollBody: false,
                child: AnimatedEmptyState(
                  config: AnimatedEmptyStateConfig(
                    icons: const [
                      Icons.router,
                      Icons.hub,
                      Icons.group,
                      Icons.lan,
                      Icons.cell_tower,
                    ],
                    taglines: [l10n.nodeGroupsMembersEmptyTagline],
                    titlePrefix: l10n.nodeGroupsEmptyTitlePrefix,
                    titleKeyword: l10n.nodeGroupsMembersEmptyKeyword,
                    titleSuffix: l10n.nodeGroupsEmptyTitleSuffix,
                    accentColor: group.color,
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
                  final nodeNum = memberNums[index];
                  final node = nodes[nodeNum];
                  return _MemberRow(
                    name: node?.displayName ?? nameFor(nodeNum),
                    color: group.color,
                    selected: _selected.contains(nodeNum),
                    onTap: () => _toggle(nodeNum),
                  );
                }, childCount: memberNums.length),
              ),
            ),
          ];
        },
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MemberRow({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: selected
            ? Border.all(color: color.withValues(alpha: 0.5))
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.router, size: 18, color: color),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppTheme.spacing8),
                  child: Text(
                    name,
                    style: TextStyle(fontSize: 15, color: context.textPrimary),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? color : context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
