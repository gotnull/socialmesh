import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../models/dashboard_widget_config.dart';

/// Base wrapper for all dashboard widgets
/// Provides consistent styling, header with title, and edit mode controls
class DashboardWidget extends StatefulWidget {
  final DashboardWidgetConfig config;
  final Widget child;
  final bool isEditMode;
  final VoidCallback? onRemove;
  final VoidCallback? onFavorite;
  final VoidCallback? onTap;
  final Widget? trailing;

  const DashboardWidget({
    super.key,
    required this.config,
    required this.child,
    this.isEditMode = false,
    this.onRemove,
    this.onFavorite,
    this.onTap,
    this.trailing,
  });

  @override
  State<DashboardWidget> createState() => _DashboardWidgetState();
}

class _DashboardWidgetState extends State<DashboardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _wobbleController;
  late Animation<double> _wobbleAnimation;

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _wobbleAnimation = Tween<double>(begin: -0.01, end: 0.01).animate(
      CurvedAnimation(parent: _wobbleController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(DashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditMode && !oldWidget.isEditMode) {
      _wobbleController.repeat(reverse: true);
    } else if (!widget.isEditMode && oldWidget.isEditMode) {
      _wobbleController.stop();
      _wobbleController.reset();
    }
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = WidgetRegistry.getInfo(widget.config.type);

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isEditMode
              ? AppTheme.primaryGreen.withValues(alpha: 0.5)
              : AppTheme.darkBorder,
          width: widget.isEditMode ? 2 : 1,
        ),
        boxShadow: widget.isEditMode
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
              Flexible(child: widget.child),
            ],
          ),
        ),
      ),
    );

    // Apply wobble animation in edit mode
    if (widget.isEditMode) {
      return AnimatedBuilder(
        animation: _wobbleAnimation,
        builder: (context, child) {
          return Transform.rotate(angle: _wobbleAnimation.value, child: child);
        },
        child: content,
      );
    }

    return content;
  }

  Widget _buildHeader(WidgetTypeInfo info) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: widget.isEditMode ? 4 : 16,
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
          if (widget.isEditMode) ...[
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
          // Custom trailing widget (e.g., LIVE indicator)
          if (widget.trailing != null && !widget.isEditMode) ...[
            widget.trailing!,
            const SizedBox(width: 8),
          ],
          // Favorite indicator (non-edit mode)
          if (!widget.isEditMode && widget.config.isFavorite)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(Icons.star, color: AppTheme.warningYellow, size: 16),
            ),
          // Edit mode actions
          if (widget.isEditMode) ...[
            // Favorite button
            _EditButton(
              icon: widget.config.isFavorite ? Icons.star : Icons.star_border,
              color: widget.config.isFavorite
                  ? AppTheme.warningYellow
                  : AppTheme.textTertiary,
              onTap: () {
                HapticFeedback.lightImpact();
                widget.onFavorite?.call();
              },
              tooltip: widget.config.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
            ),
            // Remove button
            _EditButton(
              icon: Icons.close,
              color: AppTheme.errorRed,
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onRemove?.call();
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
