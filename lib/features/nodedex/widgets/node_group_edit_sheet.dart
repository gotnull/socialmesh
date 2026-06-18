// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../models/node_group.dart';

/// Bottom sheet to create or edit a node group (name + colour + icon).
///
/// A simple prompt-style sheet (mirrors the Routes new-route sheet), so it uses
/// the BottomSheet* primitives. It only collects input and reports it through
/// [onSave]; persistence is the caller's responsibility (the groups provider).
class NodeGroupEditSheet extends StatefulWidget {
  /// The group being edited, or null when creating a new one.
  final NodeGroup? existing;

  /// Called with the chosen name (trimmed), colour value and icon key.
  final void Function(String name, int colorValue, String iconKey) onSave;

  const NodeGroupEditSheet({super.key, this.existing, required this.onSave});

  /// Present the sheet.
  static Future<void> show(
    BuildContext context, {
    NodeGroup? existing,
    required void Function(String name, int colorValue, String iconKey) onSave,
  }) {
    return AppBottomSheet.show<void>(
      context: context,
      child: NodeGroupEditSheet(existing: existing, onSave: onSave),
    );
  }

  @override
  State<NodeGroupEditSheet> createState() => _NodeGroupEditSheetState();
}

class _NodeGroupEditSheetState extends State<NodeGroupEditSheet> {
  late final TextEditingController _nameController;
  late int _colorValue;
  late String _iconKey;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _colorValue = existing?.colorValue ?? AccentColors.all.first.toARGB32();
    _iconKey = existing?.iconKey ?? kNodeGroupDefaultIconKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isEditing = widget.existing != null;
    final selectedColor = Color(_colorValue);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          icon: kNodeGroupIcons[_iconKey] ?? kNodeGroupFallbackIcon,
          iconColor: selectedColor,
          title: isEditing
              ? l10n.nodeGroupsEditTitle
              : l10n.nodeGroupsCreateTitle,
          subtitle: l10n.nodeGroupsEditSubtitle,
        ),
        const SizedBox(height: AppTheme.spacing24),
        BottomSheetTextField(
          controller: _nameController,
          label: l10n.nodeGroupsNameLabel,
          hint: l10n.nodeGroupsNameHint,
          maxLength: 40,
          autofocus: !isEditing,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppTheme.spacing20),
        _PickerLabel(text: l10n.nodeGroupsColorLabel),
        const SizedBox(height: AppTheme.spacing12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final color in AccentColors.all)
              _ColorSwatch(
                color: color,
                selected: color.toARGB32() == _colorValue,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _colorValue = color.toARGB32());
                },
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing20),
        _PickerLabel(text: l10n.nodeGroupsIconLabel),
        const SizedBox(height: AppTheme.spacing12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in kNodeGroupIcons.entries)
              _IconChoice(
                icon: entry.value,
                accent: selectedColor,
                selected: entry.key == _iconKey,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _iconKey = entry.key);
                },
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing24),
        BottomSheetButtons(
          cancelLabel: l10n.nodeGroupsCancel,
          confirmLabel: isEditing ? l10n.nodeGroupsSave : l10n.nodeGroupsCreate,
          isConfirmEnabled: _nameController.text.trim().isNotEmpty,
          onConfirm: () {
            widget.onSave(_nameController.text.trim(), _colorValue, _iconKey);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}

class _PickerLabel extends StatelessWidget {
  final String text;

  const _PickerLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.textSecondary,
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: context.textPrimary, width: 3)
              : null,
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(Icons.check, size: 20, color: context.textPrimary)
            : null,
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : context.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(
            color: selected ? accent : context.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: selected ? accent : context.textSecondary,
        ),
      ),
    );
  }
}
