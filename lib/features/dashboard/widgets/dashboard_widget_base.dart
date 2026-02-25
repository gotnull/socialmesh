// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

/// Base wrapper for all dashboard widgets providing consistent styling
/// and optional edit mode actions (remove, favorite, reorder handle)
class DashboardWidgetBase extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final bool isFavorite;
  final bool isEditMode;
  final VoidCallback? onRemove;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;

  const DashboardWidgetBase({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.isFavorite = false,
    this.isEditMode = false,
    this.onRemove,
    this.onFavorite,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: isEditMode
              ? context.accentColor.withValues(alpha: 0.5)
              : context.border,
          width: isEditMode ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [if (isEditMode) _buildEditHeader(context), child],
          ),
        ),
      ),
    );
  }

  Widget _buildEditHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      child: Row(
        children: [
          // Drag handle
          Icon(Icons.drag_indicator, color: context.textTertiary, size: 20),
          SizedBox(width: AppTheme.spacing8),
          Icon(icon, color: context.accentColor, size: 18),
          SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          // Favorite button
          if (onFavorite != null)
            IconButton(
              icon: Icon(
                isFavorite ? Icons.star : Icons.star_border,
                color: isFavorite
                    ? AppTheme.warningYellow
                    : context.textTertiary,
                size: 20,
              ),
              onPressed: onFavorite,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
            ),
          // Remove button
          if (onRemove != null)
            IconButton(
              icon: const Icon(
                Icons.remove_circle_outline,
                color: AppTheme.errorRed,
                size: 20,
              ),
              onPressed: () => _showRemoveConfirmation(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: 'Remove widget',
            ),
        ],
      ),
    );
  }

  Future<void> _showRemoveConfirmation(BuildContext context) async {
    final shouldRemove = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Remove Widget?',
      message: 'Are you sure you want to remove "$title" from your dashboard?',
      confirmLabel: 'Remove',
      isDestructive: true,
    );

    if (shouldRemove == true) {
      onRemove?.call();
    }
  }
}

/// Simple stat card widget (nodes, messages, etc.)
class StatCardWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const StatCardWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Column(
              children: [
                Icon(icon, size: 40, color: context.textPrimary),
                SizedBox(height: AppTheme.spacing16),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? context.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Action card for quick actions
class ActionCardWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const ActionCardWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.background,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Icon(icon, color: context.accentColor, size: 24),
                ),
                SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ??
                    Icon(Icons.chevron_right, color: context.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
