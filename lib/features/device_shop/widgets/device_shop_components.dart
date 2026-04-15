// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animated_gradient_background.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../models/shop_models.dart';

export 'package:socialmesh/core/widgets/animations.dart' show BouncyTap;

IconData deviceShopCategoryIcon(DeviceCategory category) {
  switch (category) {
    case DeviceCategory.node:
      return Icons.router;
    case DeviceCategory.module:
      return Icons.memory;
    case DeviceCategory.antenna:
      return Icons.cell_tower;
    case DeviceCategory.enclosure:
      return Icons.inventory_2;
    case DeviceCategory.accessory:
      return Icons.cable;
    case DeviceCategory.kit:
      return Icons.build;
    case DeviceCategory.solar:
      return Icons.solar_power;
  }
}

Color deviceShopCategoryColor(DeviceCategory category) {
  switch (category) {
    case DeviceCategory.node:
      return AccentColors.cyan;
    case DeviceCategory.module:
      return AccentColors.purple;
    case DeviceCategory.antenna:
      return AccentColors.orange;
    case DeviceCategory.enclosure:
      return AccentColors.blue;
    case DeviceCategory.accessory:
      return AccentColors.teal;
    case DeviceCategory.kit:
      return AccentColors.yellow;
    case DeviceCategory.solar:
      return AccentColors.emerald;
  }
}

class DeviceShopChoiceChip extends StatelessWidget {
  const DeviceShopChoiceChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.isSelected = false,
    this.color,
    this.onTrailingTap,
    this.trailingIcon,
  });

  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;
  final VoidCallback? onTrailingTap;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.accentColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? accent.withValues(alpha: 0.16)
            : context.card.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(
          color: isSelected
              ? accent.withValues(alpha: 0.72)
              : context.border.withValues(alpha: 0.35),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: BouncyTap(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing10,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? accent : context.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacing8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? context.textPrimary
                      : context.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (onTrailingTap != null && trailingIcon != null) ...[
                const SizedBox(width: AppTheme.spacing8),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTrailingTap?.call();
                  },
                  child: Icon(
                    trailingIcon,
                    size: 16,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceShopPrimaryButton extends StatelessWidget {
  const DeviceShopPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.animate = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool enabled;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final gradientColors = AccentColors.gradientFor(context.accentColor);

    return BouncyTap(
      enabled: enabled,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onTap?.call();
            }
          : null,
      child: AnimatedGradientBackground(
        animate: animate && enabled,
        enabled: enabled,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientColors[0], gradientColors[2], gradientColors[4]],
        ),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: enabled ? null : context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(
              color: enabled
                  ? Colors.white.withValues(alpha: 0.12)
                  : context.border.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? Colors.white : context.textTertiary,
                ),
                const SizedBox(width: AppTheme.spacing8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: enabled ? Colors.white : context.textTertiary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DeviceShopSecondaryButton extends StatelessWidget {
  const DeviceShopSecondaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius16,
        borderWidth: 1,
        accentOpacity: 0.28,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing14,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing8),
            ],
            Text(
              label,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceShopStatePanel extends StatelessWidget {
  const DeviceShopStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.accentColor,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color? accentColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? context.accentColor;

    return GradientBorderContainer(
      borderRadius: compact ? AppTheme.radius16 : AppTheme.radius20,
      borderWidth: 1.2,
      accentOpacity: 0.36,
      enableDepthBlend: true,
      depthBlendOpacity: 0.08,
      padding: EdgeInsets.all(
        compact ? AppTheme.spacing20 : AppTheme.spacing24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 52 : 64,
            height: compact ? 52 : 64,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withValues(alpha: 0.24),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radius16),
              border: Border.all(color: accent.withValues(alpha: 0.28)),
            ),
            child: Icon(icon, color: accent, size: compact ? 24 : 28),
          ),
          SizedBox(height: compact ? AppTheme.spacing16 : AppTheme.spacing20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: compact ? 17 : 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppTheme.spacing20),
            DeviceShopPrimaryButton(
              label: actionLabel!,
              icon: actionIcon,
              onTap: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Solid-color pill badge with icon — used for image overlays (Featured, Sale, Out of Stock).
class DeviceShopBadgePill extends StatelessWidget {
  const DeviceShopBadgePill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.fillOpacity = 0.98,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final double fillOpacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: fillOpacity),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: AppTheme.spacing4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tinted pill for metadata (category, chipset, frequency band).
class DeviceShopInfoPill extends StatelessWidget {
  const DeviceShopInfoPill({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Floating icon orb for image overlays (favorite, share, back).
class DeviceShopIconOrb extends StatelessWidget {
  const DeviceShopIconOrb({
    super.key,
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 34,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(AppTheme.radius14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, size: size * 0.53, color: color),
      ),
    );
  }
}
