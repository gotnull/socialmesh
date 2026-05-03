// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Edit board metadata. Sysop-only. Invoked from the board screen's
// overflow menu. Visually identical to the canonical inner Settings
// screen (see mqtt_config_screen.dart): uppercase _SectionHeader +
// grouped TextField cards with OutlineInputBorder + prefix icons +
// _SettingsTile rows with ThemedSwitch trailing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/nodeboard.dart';
import '../models/nodeboard_enums.dart';
import '../providers/nodeboard_providers.dart';

Future<bool?> showNodeBoardEditSheet({
  required BuildContext context,
  required NodeBoard board,
}) {
  return AppBottomSheet.showScrollable<bool>(
    context: context,
    title: 'Edit board', // lint-allow: hardcoded-string
    initialChildSize: 0.9,
    maxChildSize: 0.95,
    builder: (scrollController) =>
        _NodeBoardEditSheet(board: board, scrollController: scrollController),
  );
}

class _NodeBoardEditSheet extends ConsumerStatefulWidget {
  final NodeBoard board;
  final ScrollController scrollController;

  const _NodeBoardEditSheet({
    required this.board,
    required this.scrollController,
  });

  @override
  ConsumerState<_NodeBoardEditSheet> createState() =>
      _NodeBoardEditSheetState();
}

class _NodeBoardEditSheetState extends ConsumerState<_NodeBoardEditSheet>
    with LifecycleSafeMixin<_NodeBoardEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _sysopCtrl;
  late final TextEditingController _taglineCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _welcomeCtrl;
  late final TextEditingController _splashCtrl;
  late BoardVisibility _visibility;
  late String? _themeId;
  late bool _listed;
  late bool _guestPosting;
  late bool _readOnly;
  late String? _ownerNodeId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.board;
    _titleCtrl = TextEditingController(text: b.title);
    _sysopCtrl = TextEditingController(text: b.sysopName);
    _taglineCtrl = TextEditingController(text: b.tagline ?? '');
    _descCtrl = TextEditingController(text: b.description ?? '');
    _welcomeCtrl = TextEditingController(text: b.welcomeText ?? '');
    _splashCtrl = TextEditingController(text: b.ansiSplash ?? '');
    _visibility = b.visibility;
    _themeId = b.themeId;
    _listed = b.isListedInNodeDex;
    _guestPosting = b.isGuestPostingAllowed;
    _readOnly = b.isReadOnly;
    _ownerNodeId = b.ownerNodeId;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _sysopCtrl.dispose();
    _taglineCtrl.dispose();
    _descCtrl.dispose();
    _welcomeCtrl.dispose();
    _splashCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    AppLogging.nodeBoard('Edit: save boardId=${widget.board.id}');
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(nodeBoardModNotifierProvider.notifier)
          .updateBoard(
            widget.board.id,
            widget.board.slug,
            {
              'title': _titleCtrl.text.trim(),
              'sysopName': _sysopCtrl.text.trim(),
              'tagline': _taglineCtrl.text.trim(),
              'description': _descCtrl.text.trim(),
              'welcomeText': _welcomeCtrl.text.trim(),
              'ansiSplash': _splashCtrl.text.trim(),
              'visibility': _visibility.toJson(),
              if (_themeId != null) 'themeId': _themeId,
              'isListedInNodeDex': _listed,
              'isGuestPostingAllowed': _guestPosting,
              'isReadOnly': _readOnly,
              'ownerNodeId': _ownerNodeId,
            },
            ownerNodeId: _ownerNodeId,
            previousOwnerNodeId: widget.board.ownerNodeId,
          );
      if (!mounted) return;
      AppLogging.nodeBoard('Edit: ✅ saved');
      HapticFeedback.lightImpact();
      // lint-allow: hardcoded-string
      showSuccessSnackBar(context, 'Board updated');
      Navigator.of(context).pop(true);
    } catch (e) {
      AppLogging.nodeBoard('Edit: ❌ failed: $e');
      if (!mounted) return;
      // lint-allow: hardcoded-string
      showErrorSnackBar(context, 'Failed to save: $e');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myNodeNum = ref.watch(myNodeNumProvider);
    final myHexId = myNodeNum != null
        ? '!${myNodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}'
        : null;
    final nodeLinked = _ownerNodeId != null;
    final linkedToThisNode = _ownerNodeId == myHexId;

    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(
              top: AppTheme.spacing8,
              bottom: AppTheme.spacing16,
            ),
            children: [
              // lint-allow: hardcoded-string
              const SettingsSectionHeader(title: 'IDENTITY'),
              FieldGroupCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledField(
                      controller: _titleCtrl,
                      // lint-allow: hardcoded-string
                      label: 'Title',
                      prefixIcon: Icons.title,
                      maxLength: 100,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    _LabeledField(
                      controller: _sysopCtrl,
                      // lint-allow: hardcoded-string
                      label: 'Sysop name',
                      prefixIcon: Icons.badge_outlined,
                      maxLength: 60,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    _LabeledField(
                      controller: _taglineCtrl,
                      // lint-allow: hardcoded-string
                      label: 'Tagline',
                      prefixIcon: Icons.short_text,
                      maxLength: 140,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    _LabeledField(
                      controller: _descCtrl,
                      // lint-allow: hardcoded-string
                      label: 'Description',
                      prefixIcon: Icons.notes,
                      maxLength: 5000,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spacing16),
              // lint-allow: hardcoded-string
              const SettingsSectionHeader(title: 'NODE LINKING'),
              _NodeLinkTile(
                myHexId: myHexId,
                linked: nodeLinked,
                linkedToThisNode: linkedToThisNode,
                currentLinkedId: _ownerNodeId,
                onLinkThisNode: myHexId == null
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        setState(() => _ownerNodeId = myHexId);
                      },
                onUnlink: nodeLinked
                    ? () {
                        HapticFeedback.lightImpact();
                        setState(() => _ownerNodeId = null);
                      }
                    : null,
              ),

              const SizedBox(height: AppTheme.spacing16),
              // lint-allow: hardcoded-string
              const SettingsSectionHeader(title: 'VISIBILITY'),
              _VisibilityRadioGroup(
                selected: _visibility,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  setState(() => _visibility = v);
                },
              ),

              SettingsTile(
                icon: Icons.public,
                iconColor: _listed ? context.accentColor : null,
                // lint-allow: hardcoded-string
                title: 'Listed in NodeDex',
                // lint-allow: hardcoded-string
                subtitle: 'Appear in public board discovery',
                trailing: ThemedSwitch(
                  value: _listed,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _listed = v);
                  },
                ),
              ),
              SettingsTile(
                icon: Icons.group_outlined,
                iconColor: _guestPosting ? context.accentColor : null,
                // lint-allow: hardcoded-string
                title: 'Allow guest posting',
                // lint-allow: hardcoded-string
                subtitle: 'Unauthenticated users can post in guestbook',
                trailing: ThemedSwitch(
                  value: _guestPosting,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _guestPosting = v);
                  },
                ),
              ),
              SettingsTile(
                icon: Icons.lock_outline,
                iconColor: _readOnly ? context.accentColor : null,
                // lint-allow: hardcoded-string
                title: 'Read-only',
                // lint-allow: hardcoded-string
                subtitle: 'Lock all posting while preserving content',
                trailing: ThemedSwitch(
                  value: _readOnly,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    setState(() => _readOnly = v);
                  },
                ),
              ),

              const SizedBox(height: AppTheme.spacing16),
              // lint-allow: hardcoded-string
              const SettingsSectionHeader(title: 'THEME'),
              _ThemeListTile(
                selectedId: _themeId,
                onSelected: (id) {
                  HapticFeedback.lightImpact();
                  setState(() => _themeId = id);
                },
              ),

              const SizedBox(height: AppTheme.spacing16),
              // lint-allow: hardcoded-string
              const SettingsSectionHeader(title: 'WELCOME & SPLASH'),
              FieldGroupCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledField(
                      controller: _welcomeCtrl,
                      // lint-allow: hardcoded-string
                      label: 'Welcome text',
                      prefixIcon: Icons.waving_hand_outlined,
                      maxLength: 2000,
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    _LabeledField(
                      controller: _splashCtrl,
                      // lint-allow: hardcoded-string
                      label: 'ANSI / ASCII splash',
                      prefixIcon: Icons.terminal,
                      maxLength: 4000,
                      maxLines: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Fixed save button — pinned to the bottom of the sheet, never
        // scrolls with the form content.
        Container(
          decoration: BoxDecoration(
            color: context.card,
            border: Border(
              top: BorderSide(color: context.border.withValues(alpha: 0.4)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing12,
                AppTheme.spacing16,
                AppTheme.spacing12,
              ),
              child: _GradientSubmitButton(
                enabled: !_saving,
                saving: _saving,
                icon: Icons.save_outlined,
                // lint-allow: hardcoded-string
                label: 'Save',
                onTap: _save,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Canonical TextField with OutlineInputBorder, prefix icon, floating
/// label, and muted hint — matches mqtt_config_screen.dart exactly.
class _LabeledField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData prefixIcon;
  final int maxLength;
  final int maxLines;

  const _LabeledField({
    required this.controller,
    required this.label,
    required this.prefixIcon,
    required this.maxLength,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isMultiline = maxLines > 1;
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: isMultiline
          ? TextInputAction.newline
          : TextInputAction.next,
      // Keep the caret + first line at the top of a multi-line field so
      // long bodies fill downward, not from the middle.
      textAlignVertical: isMultiline
          ? TextAlignVertical.top
          : TextAlignVertical.center,
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textSecondary),
        hintStyle: TextStyle(color: SemanticColors.muted),
        alignLabelWithHint: isMultiline,
        filled: true,
        fillColor: context.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          borderSide: BorderSide(color: context.accentColor),
        ),
        // Top-align the prefix icon on multi-line fields so it sits with
        // the first line of text, not centered vertically in the taller
        // input box.
        prefixIcon: isMultiline
            ? Padding(
                padding: const EdgeInsets.only(
                  left: AppTheme.spacing12,
                  right: AppTheme.spacing12,
                  top: AppTheme.spacing14,
                ),
                child: Icon(prefixIcon, color: context.textSecondary),
              )
            : Icon(prefixIcon, color: context.textSecondary),
        prefixIconConstraints: isMultiline
            ? const BoxConstraints(minWidth: 0, minHeight: 0)
            : null,
        counterText: '',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visibility radio group — mirrors appearance_accessibility FontModeSelector
// pattern: stacked InkWell rows inside a card with radio on the right.
// ---------------------------------------------------------------------------

class _VisibilityRadioGroup extends StatelessWidget {
  final BoardVisibility selected;
  final ValueChanged<BoardVisibility> onChanged;

  const _VisibilityRadioGroup({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = BoardVisibility.values;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _VisibilityRow(
              visibility: options[i],
              selected: selected == options[i],
              isFirst: i == 0,
              isLast: i == options.length - 1,
              onTap: () => onChanged(options[i]),
            ),
            if (i < options.length - 1)
              Divider(
                height: 1,
                color: context.border.withValues(alpha: 0.5),
                indent: AppTheme.spacing16,
                endIndent: AppTheme.spacing16,
              ),
          ],
        ],
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  final BoardVisibility visibility;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _VisibilityRow({
    required this.visibility,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (label, subtitle, icon) = switch (visibility) {
      BoardVisibility.public_ => (
        // lint-allow: hardcoded-string
        'Public',
        // lint-allow: hardcoded-string
        'Anyone can find and read this board',
        Icons.public,
      ),
      BoardVisibility.unlisted => (
        // lint-allow: hardcoded-string
        'Unlisted',
        // lint-allow: hardcoded-string
        'Only reachable via direct link',
        Icons.link,
      ),
      BoardVisibility.private_ => (
        // lint-allow: hardcoded-string
        'Private',
        // lint-allow: hardcoded-string
        'Only the sysop can access',
        Icons.lock_outline,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(AppTheme.radius12) : Radius.zero,
          bottom: isLast
              ? const Radius.circular(AppTheme.radius12)
              : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? context.accentColor : context.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      subtitle,
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<bool>(
                value: true,
                groupValue: selected ? true : null,
                onChanged: (_) => onTap(),
                activeColor: context.accentColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme picker as a settings tile that opens a bottom-sheet theme picker.
// Consistent with how other settings screens delegate to bottom sheets.
// ---------------------------------------------------------------------------

class _ThemeListTile extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const _ThemeListTile({required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themesAsync = ref.watch(nodeBoardThemesProvider);
    return themesAsync.when(
      data: (themes) {
        final selected = themes.where((t) => t.id == selectedId).firstOrNull;
        final currentName =
            selected?.name ??
            // lint-allow: hardcoded-string
            'Default';
        return SettingsTile(
          icon: Icons.palette_outlined,
          // lint-allow: hardcoded-string
          title: 'Preset',
          subtitle: currentName,
          trailing: Icon(Icons.chevron_right, color: context.textTertiary),
          onTap: () => _pickTheme(context, themes),
        );
      },
      loading: () => SettingsTile(
        icon: Icons.palette_outlined,
        // lint-allow: hardcoded-string
        title: 'Preset',
        // lint-allow: hardcoded-string
        subtitle: 'Loading themes…',
        trailing: const SizedBox(
          width: AppTheme.spacing16,
          height: AppTheme.spacing16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => SettingsTile(
        icon: Icons.palette_outlined,
        // lint-allow: hardcoded-string
        title: 'Preset',
        // lint-allow: hardcoded-string
        subtitle: 'Could not load themes',
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, List themes) async {
    HapticFeedback.lightImpact();
    await AppBottomSheet.showScrollable<void>(
      context: context,
      // lint-allow: hardcoded-string
      title: 'Theme preset',
      initialChildSize: 0.6,
      maxChildSize: 0.85,
      builder: (controller) => ListView.separated(
        controller: controller,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing8,
        ),
        itemCount: themes.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppTheme.spacing8),
        itemBuilder: (ctx, i) {
          final theme = themes[i];
          final isSelected = theme.id == selectedId;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(theme.id);
                Navigator.of(ctx).pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ctx.accentColor.withValues(alpha: 0.12)
                      : ctx.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: isSelected
                        ? ctx.accentColor.withValues(alpha: 0.5)
                        : ctx.border.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 20,
                      color: isSelected ? ctx.accentColor : ctx.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        theme.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? ctx.accentColor : ctx.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        size: 20,
                        color: ctx.accentColor,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node linking — rendered as a _SettingsTile to match the inner settings
// aesthetic. Action button lives below the tile as a trailing row.
// ---------------------------------------------------------------------------

class _NodeLinkTile extends StatelessWidget {
  final String? myHexId;
  final bool linked;
  final bool linkedToThisNode;
  final String? currentLinkedId;
  final VoidCallback? onLinkThisNode;
  final VoidCallback? onUnlink;

  const _NodeLinkTile({
    required this.myHexId,
    required this.linked,
    required this.linkedToThisNode,
    required this.currentLinkedId,
    required this.onLinkThisNode,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    // lint-allow: hardcoded-string
    final title = linked ? 'Linked to $currentLinkedId' : 'Not linked';
    final subtitle = linked
        // lint-allow: hardcoded-string
        ? 'Your board shows up in NodeDex for this node'
        // lint-allow: hardcoded-string
        : 'Link a node to make this board discoverable from NodeDex';

    return Column(
      children: [
        SettingsTile(
          icon: linked ? Icons.link : Icons.link_off,
          iconColor: linked ? context.accentColor : null,
          title: title,
          subtitle: subtitle,
        ),
        if (myHexId == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              AppTheme.spacing4,
              AppTheme.spacing20,
              AppTheme.spacing4,
            ),
            child: Text(
              // lint-allow: hardcoded-string
              'Connect a node to link it.',
              style: context.bodySmallStyle?.copyWith(
                color: context.textTertiary,
              ),
            ),
          )
        else if (!linkedToThisNode)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing4,
              AppTheme.spacing16,
              AppTheme.spacing4,
            ),
            child: FilledButton.tonalIcon(
              onPressed: onLinkThisNode,
              icon: const Icon(Icons.link, size: 18),
              label: Text(
                // lint-allow: hardcoded-string
                'Link this node ($myHexId)',
              ),
            ),
          ),
        if (linked)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing4,
              AppTheme.spacing16,
              AppTheme.spacing4,
            ),
            child: TextButton.icon(
              onPressed: onUnlink,
              icon: const Icon(Icons.link_off, size: 18),
              label: const Text(
                // lint-allow: hardcoded-string
                'Unlink',
              ),
              style: TextButton.styleFrom(
                foregroundColor: context.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Full-width gradient submit button — matches Create Signal pattern.
// ---------------------------------------------------------------------------

class _GradientSubmitButton extends StatelessWidget {
  final bool enabled;
  final bool saving;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _GradientSubmitButton({
    required this.enabled,
    required this.saving,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [accent, accent.withValues(alpha: 0.75)],
                )
              : null,
          color: enabled ? null : context.border.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (saving)
              const SizedBox(
                width: AppTheme.spacing20,
                height: AppTheme.spacing20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    SemanticColors.onAccent,
                  ),
                ),
              )
            else ...[
              Icon(
                icon,
                size: 18,
                color: enabled ? SemanticColors.onAccent : context.textTertiary,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: enabled
                      ? SemanticColors.onAccent
                      : context.textTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
