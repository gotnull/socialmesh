// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../providers/drawer_customization_providers.dart';
import 'drawer_hidden_item_descriptor.dart';

/// Bottom-of-drawer button that sits next to Settings.
///
/// When idle: hint icon + tooltip prompting the user to long-press any
/// drawer item to enter edit mode.
/// When in edit mode: rendered as a "Done" pill that exits edit mode.
/// When modifications exist (some items hidden / custom order): the
/// icon shows an accent dot to signal there are changes to review.
///
/// Tapping the button opens [_showDrawerCustomizationSheet] — a brief
/// summary of what's modified plus a "Reset to defaults" CTA.
class DrawerCustomizeButton extends ConsumerWidget {
  const DrawerCustomizeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final editMode = ref.watch(drawerEditModeProvider);
    final customization = ref.watch(drawerCustomizationProvider).value;
    final isModified = customization?.isModified ?? false;

    if (editMode) {
      return _DonePill(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(drawerEditModeProvider.notifier).exit();
        },
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: context.l10n.drawerCustomizeTooltip,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showDrawerCustomizationSheet(context, ref);
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              ref.read(drawerEditModeProvider.notifier).enter();
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.tune,
                size: 22,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
        if (isModified)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DonePill extends StatelessWidget {
  final VoidCallback onTap;

  const _DonePill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.radius24),
        ),
        alignment: Alignment.center,
        child: Text(
          context.l10n.drawerCustomizeDone,
          style: TextStyle(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

Future<void> _showDrawerCustomizationSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.55,
    minChildSize: 0.4,
    maxChildSize: 0.9,
    builder: (controller) =>
        _DrawerCustomizationSheet(scrollController: controller),
  );
}

class _DrawerCustomizationSheet extends ConsumerWidget {
  final ScrollController scrollController;

  const _DrawerCustomizationSheet({required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customization = ref.watch(drawerCustomizationProvider).value;
    final hiddenIds = customization?.hiddenIds ?? const <String>{};
    final hasCustomOrder = customization?.customOrder != null;
    final isModified = customization?.isModified ?? false;
    final l10n = context.l10n;

    final orderedHiddenIds = hiddenIds.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing24,
            0,
            AppTheme.spacing24,
            AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Icon(Icons.tune, size: 28, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  l10n.drawerCustomizeSheetTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
            children: [
              Text(
                l10n.drawerCustomizeSheetExplainer,
                style: TextStyle(
                  fontSize: 14,
                  color: context.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              if (isModified) ...[
                _SummaryRow(
                  icon: Icons.visibility_off_outlined,
                  label: l10n.drawerCustomizeSummaryHidden(hiddenIds.length),
                  iconColor: AccentColors.red,
                ),
                if (hasCustomOrder)
                  _SummaryRow(
                    icon: Icons.swap_vert,
                    label: l10n.drawerCustomizeSummaryReordered,
                    iconColor: AccentColors.purple,
                  ),
              ] else
                _SummaryRow(
                  icon: Icons.check_circle_outline,
                  label: l10n.drawerCustomizeSummaryDefault,
                  iconColor: AccentColors.green,
                ),
              if (orderedHiddenIds.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing16),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                  child: Text(
                    l10n.drawerCustomizeHiddenSectionTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                for (final id in orderedHiddenIds) _HiddenItemTile(id: id),
              ],
              const SizedBox(height: AppTheme.spacing16),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing24,
            AppTheme.spacing8,
            AppTheme.spacing24,
            AppTheme.spacing16,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(drawerEditModeProvider.notifier).enter();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l10n.drawerCustomizeEnterEdit),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isModified
                      ? () async {
                          HapticFeedback.mediumImpact();
                          await ref
                              .read(drawerCustomizationProvider.notifier)
                              .resetToDefaults();
                          if (context.mounted) Navigator.of(context).pop();
                        }
                      : null,
                  icon: const Icon(Icons.restore, size: 18),
                  label: Text(l10n.drawerCustomizeReset),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.background,
                    disabledForegroundColor: context.textTertiary.withValues(
                      alpha: 0.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Single row for an unhide-able drawer item. Tapping the trailing
/// Show button restores the item to its default position in the
/// drawer (the per-section reorder model decides which section it
/// re-emerges in, so it always lands back where the user expects).
class _HiddenItemTile extends ConsumerWidget {
  final String id;

  const _HiddenItemTile({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final descriptor = drawerHiddenItemDescriptor(id, l10n);

    // Fallback when an id exists in persisted state but no descriptor
    // ships in this build (e.g. a feature-flag-gated item the user
    // hid before disabling the flag). Render a neutral tile so the
    // user can still unhide it instead of being stuck on Reset.
    final icon = descriptor?.icon ?? Icons.help_outline;
    final label = descriptor?.label ?? id;
    final iconColor = descriptor?.iconColor ?? context.textTertiary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              AppLogging.settings('[Drawer] sheet restored id=$id');
              ref.read(drawerCustomizationProvider.notifier).show(id);
            },
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: Text(l10n.drawerCustomizeRestoreItem),
            style: TextButton.styleFrom(
              foregroundColor: context.accentColor,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing12,
                vertical: AppTheme.spacing4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
