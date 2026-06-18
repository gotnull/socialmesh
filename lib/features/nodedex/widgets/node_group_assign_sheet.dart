// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../models/node_group.dart';
import '../providers/node_groups_provider.dart';
import 'node_group_edit_sheet.dart';

/// Bottom sheet to choose which groups a node belongs to (multi-select),
/// with a shortcut to create a new group inline. Applies on "Done".
///
/// Sizes to its content (via [AppBottomSheet.show]) so a short or empty list
/// doesn't leave a dead zone; the group list is capped and scrolls internally
/// only when it is genuinely long.
class NodeGroupAssignSheet extends ConsumerStatefulWidget {
  final int nodeNum;
  final String? nodeName;

  const NodeGroupAssignSheet({super.key, required this.nodeNum, this.nodeName});

  static Future<void> show(
    BuildContext context, {
    required int nodeNum,
    String? nodeName,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      child: NodeGroupAssignSheet(nodeNum: nodeNum, nodeName: nodeName),
    );
  }

  @override
  ConsumerState<NodeGroupAssignSheet> createState() =>
      _NodeGroupAssignSheetState();
}

class _NodeGroupAssignSheetState extends ConsumerState<NodeGroupAssignSheet>
    with LifecycleSafeMixin<NodeGroupAssignSheet> {
  // Local working selection, seeded once from current membership.
  Set<String>? _selected;

  void _toggle(String groupId) {
    HapticFeedback.selectionClick();
    safeSetState(() {
      if (_selected!.contains(groupId)) {
        _selected!.remove(groupId);
      } else {
        _selected!.add(groupId);
      }
    });
  }

  void _createGroup() {
    NodeGroupEditSheet.show(
      context,
      onSave: (name, colorValue, iconKey) async {
        final group = await ref
            .read(nodeGroupsProvider.notifier)
            .createGroup(name: name, colorValue: colorValue, iconKey: iconKey);
        safeSetState(() => _selected?.add(group.id));
      },
    );
  }

  void _apply() {
    ref.read(nodeGroupsProvider.notifier).setNodeGroups(widget.nodeNum, {
      ...?_selected,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupsAsync = ref.watch(nodeGroupsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          icon: Icons.category_outlined,
          iconColor: context.accentColor,
          title: l10n.nodeGroupsAssignTitle,
          subtitle: widget.nodeName,
        ),
        const SizedBox(height: AppTheme.spacing20),
        groupsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
            child: Text(
              l10n.nodeGroupsLoadError,
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          data: (state) {
            _selected ??= {...state.groupsForNode(widget.nodeNum)};
            if (state.groups.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
                child: Text(
                  l10n.nodeGroupsAssignEmptyPrompt,
                  style: TextStyle(color: context.textSecondary),
                ),
              );
            }
            // Cap the list height so a long list scrolls internally instead of
            // pushing the sheet off-screen; short lists shrink-wrap (no gap).
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: state.groups.length,
                itemBuilder: (context, index) {
                  final group = state.groups[index];
                  return _GroupToggleRow(
                    group: group,
                    selected: _selected!.contains(group.id),
                    onTap: () => _toggle(group.id),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: AppTheme.spacing16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _createGroup,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.nodeGroupsNewGroup),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: SemanticColors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        BottomSheetButtons(
          cancelLabel: l10n.nodeGroupsCancel,
          confirmLabel: l10n.nodeGroupsDone,
          onConfirm: _apply,
        ),
      ],
    );
  }
}

class _GroupToggleRow extends StatelessWidget {
  final NodeGroup group;
  final bool selected;
  final VoidCallback onTap;

  const _GroupToggleRow({
    required this.group,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing8,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: group.color.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(group.icon, size: 18, color: group.color),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Text(
                group.name,
                style: TextStyle(fontSize: 15, color: context.textPrimary),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? group.color : context.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
