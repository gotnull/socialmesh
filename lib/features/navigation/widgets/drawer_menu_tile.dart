// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../models/subscription_models.dart';

/// Drawer menu item data for quick access screens.
class DrawerMenuItem {
  final IconData icon;
  final String label;

  /// Screen to push when tapped. Null when [tabIndex] is used instead.
  final Widget? screen;

  /// When non-null, tapping this item switches the bottom-nav to this
  /// tab index instead of pushing a new screen.
  final int? tabIndex;

  final PremiumFeature? premiumFeature;
  final String? sectionHeader;
  final Color? iconColor;
  final bool requiresConnection;

  /// Provider key for badge count - use 'activity' for activity count.
  final String? badgeProviderKey;

  /// Key that links this item to a What's New payload badge.
  /// When a matching key is in the unseen badge keys set, a NEW chip
  /// is shown next to this drawer item.
  final String? whatsNewBadgeKey;

  /// When true and [tabIndex] is set, the map tab activates TAK layer.
  final bool requestsTakMode;

  const DrawerMenuItem({
    required this.icon,
    required this.label,
    this.screen,
    this.tabIndex,
    this.premiumFeature,
    this.sectionHeader,
    this.iconColor,
    this.requiresConnection = false,
    this.badgeProviderKey,
    this.whatsNewBadgeKey,
    this.requestsTakMode = false,
  });
}

/// Helper class for grouping drawer menu items into sections.
class DrawerMenuSection {
  final String title;
  final List<DrawerMenuItemWithIndex> items;

  DrawerMenuSection(this.title, this.items);
}

/// Helper class to track menu item with its original index.
class DrawerMenuItemWithIndex {
  final DrawerMenuItem item;
  final int index;

  DrawerMenuItemWithIndex(this.item, this.index);
}

/// Menu tile for the navigation drawer.
///
/// Displays an icon, label, optional badge, premium/locked state,
/// and NEW chip for What's New items.
class DrawerMenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isPremium;
  final bool isLocked;
  final bool showTryIt;
  final bool isDisabled;
  final VoidCallback? onTap;
  final int? badgeCount;
  final Color? iconColor;
  final bool showNewChip;

  const DrawerMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isPremium = false,
    this.isLocked = false,
    this.showTryIt = false,
    this.isDisabled = false,
    this.badgeCount,
    this.iconColor,
    this.showNewChip = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final lockedColor = AccentColors.slate;
    const disabledAlpha = 0.35;

    // When the NEW chip is visible, override locked styling so the item
    // looks inviting rather than dimmed/locked.
    final effectivelyLocked = isLocked && !showNewChip;

    return BouncyTap(
      onTap: onTap,
      enabled: !isDisabled,
      scaleFactor: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : effectivelyLocked
              ? lockedColor.withValues(alpha: 0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: isSelected
              ? Border.all(color: accentColor.withValues(alpha: 0.3))
              : effectivelyLocked
              ? Border.all(color: lockedColor.withValues(alpha: 0.15))
              : null,
        ),
        child: Opacity(
          opacity: isDisabled ? disabledAlpha : 1.0,
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(AppTheme.spacing10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.2)
                      : effectivelyLocked
                      ? lockedColor.withValues(alpha: 0.1)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isSelected
                          ? accentColor
                          : effectivelyLocked
                          ? lockedColor
                          : iconColor ??
                                theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                    ),
                    // Badge overlay on icon
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        right: -6,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacing4),
                          decoration: BoxDecoration(
                            color: AccentColors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 2,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              badgeCount! > 99 ? '99+' : '$badgeCount',
                              style: const TextStyle(
                                color: SemanticColors.onAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    // NEW dot indicator on icon (shown when no count badge)
                    if (showNewChip && (badgeCount == null || badgeCount! <= 0))
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AccentColors.gradientFor(accentColor).first,
                                AccentColors.gradientFor(accentColor).last,
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacing14),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontFamily: AppTheme.fontFamily,
                          color: isSelected
                              ? accentColor
                              : effectivelyLocked
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                )
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                        ),
                      ),
                    ),
                    if (showNewChip) ...[
                      const SizedBox(width: AppTheme.spacing8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AccentColors.gradientFor(accentColor).first,
                              AccentColors.gradientFor(accentColor).last,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppTheme.radius6),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          context.l10n.drawerBadgeNew,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppTheme.fontFamily,
                            color: SemanticColors.onAccent,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Show lock icon and PRO badge for locked premium features
              // Suppressed when NEW chip is visible to avoid squashing the label
              if (isLocked && !showNewChip) ...[
                const SizedBox(width: AppTheme.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [lockedColor, lockedColor.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                    boxShadow: [
                      BoxShadow(
                        color: lockedColor.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: SemanticColors.onAccent,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        context.l10n.drawerBadgePro,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontFamily,
                          color: SemanticColors.onAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (showTryIt && !showNewChip) ...[
                // Show "TRY IT" badge when upsell is enabled but not owned
                // Suppressed when NEW chip is visible to avoid badge clutter
                const SizedBox(width: AppTheme.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AccentColors.yellow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: AccentColors.yellow),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        context.l10n.drawerBadgeTryIt,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.fontFamily,
                          color: AccentColors.yellow,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isPremium) ...[
                // Show unlocked badge for purchased premium features
                Icon(
                  Icons.verified_rounded,
                  size: 18,
                  color: AccentColors.green,
                ),
              ] else if (isSelected) ...[
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: accentColor.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
