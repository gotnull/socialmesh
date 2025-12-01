import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../models/dashboard_widget_config.dart';

/// Base wrapper for all dashboard widgets
/// Provides consistent styling, header with title, and edit mode controls
class DashboardWidget extends StatelessWidget {
  final DashboardWidgetConfig config;
  final Widget child;
  final bool isEditMode;
  final VoidCallback? onRemove;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onSizeChange;

  const DashboardWidget({
    super.key,
    required this.config,
    required this.child,
    this.isEditMode = false,
    this.onRemove,
    this.onFavorite,
    this.onTap,
    this.onSizeChange,
  });

  @override
  Widget build(BuildContext context) {
    final info = WidgetRegistry.getInfo(config.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditMode
              ? AppTheme.primaryGreen.withValues(alpha: 0.5)
              : AppTheme.darkBorder,
          width: isEditMode ? 2 : 1,
        ),
        boxShadow: isEditMode
            ? [
                BoxShadow(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(info),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(WidgetTypeInfo info) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: isEditMode ? 4 : 16,
        top: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          if (isEditMode) ...[
            // Drag handle
            const Icon(
              Icons.drag_indicator,
              color: AppTheme.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
          // Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(info.icon, color: AppTheme.primaryGreen, size: 16),
          ),
          const SizedBox(width: 10),
          // Title
          Expanded(
            child: Text(
              info.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontFamily: 'Inter',
              ),
            ),
          ),
          // Favorite indicator (non-edit mode)
          if (!isEditMode && config.isFavorite)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.star, color: AppTheme.warningYellow, size: 16),
            ),
          // Edit mode actions
          if (isEditMode) ...[
            // Favorite button
            _EditButton(
              icon: config.isFavorite ? Icons.star : Icons.star_border,
              color: config.isFavorite
                  ? AppTheme.warningYellow
                  : AppTheme.textTertiary,
              onTap: () {
                HapticFeedback.lightImpact();
                onFavorite?.call();
              },
              tooltip: config.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
            ),
            // Size button (if multiple sizes supported)
            if (info.supportedSizes.length > 1)
              _EditButton(
                icon: Icons.aspect_ratio,
                color: AppTheme.textTertiary,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSizeChange?.call();
                },
                tooltip: 'Change size',
              ),
            // Remove button
            _EditButton(
              icon: Icons.close,
              color: AppTheme.errorRed,
              onTap: () {
                HapticFeedback.mediumImpact();
                onRemove?.call();
              },
              tooltip: 'Remove widget',
            ),
          ],
        ],
      ),
    );
  }
}

class _EditButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _EditButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Empty state for widgets with no data
class WidgetEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const WidgetEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textTertiary,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading state for widgets
class WidgetLoadingState extends StatelessWidget {
  final String? message;

  const WidgetLoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryGreen,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiary,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
