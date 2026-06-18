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
        // Auto-select the freshly created group.
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

    return groupsAsync.when(
      loading: () => _Frame(
        title: l10n.nodeGroupsAssignTitle,
        subtitle: widget.nodeName,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: AppTheme.spacing32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => _Frame(
        title: l10n.nodeGroupsAssignTitle,
        subtitle: widget.nodeName,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
          child: Text(
            l10n.nodeGroupsLoadError,
            style: TextStyle(color: context.textSecondary),
          ),
        ),
      ),
      data: (state) {
        _selected ??= {...state.groupsForNode(widget.nodeNum)};

        if (state.groups.isEmpty) {
          return _Frame(
            title: l10n.nodeGroupsAssignTitle,
            subtitle: widget.nodeName,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing16,
                  ),
                  child: Text(
                    l10n.nodeGroupsAssignEmptyPrompt,
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
                _NewGroupRow(onTap: _createGroup),
              ],
            ),
          );
        }

        return _Frame(
          title: l10n.nodeGroupsAssignTitle,
          subtitle: widget.nodeName,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final group in state.groups)
                      _GroupToggleRow(
                        group: group,
                        selected: _selected!.contains(group.id),
                        onTap: () => _toggle(group.id),
                      ),
                    _NewGroupRow(onTap: _createGroup),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              BottomSheetButtons(
                cancelLabel: l10n.nodeGroupsCancel,
                confirmLabel: l10n.nodeGroupsDone,
                onConfirm: _apply,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shared header + body wrapper for the assign sheet states.
class _Frame extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _Frame({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          icon: Icons.category_outlined,
          iconColor: context.accentColor,
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: AppTheme.spacing16),
        child,
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

class _NewGroupRow extends StatelessWidget {
  final VoidCallback onTap;

  const _NewGroupRow({required this.onTap});

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
                color: context.accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, size: 20, color: context.accentColor),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Text(
              context.l10n.nodeGroupsNewGroup,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
