// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../models/dashboard_widget_config.dart';
import '../../../core/widgets/loading_indicator.dart';

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
  final bool showHeader;

  /// Custom overrides for widget name (for custom schema widgets)
  final String? customName;

  /// Custom overrides for widget icon (for custom schema widgets)
  final IconData? customIcon;

  /// Index in the ReorderableListView for drag handling (only header is draggable)
  final int? reorderIndex;

  const DashboardWidget({
    super.key,
    required this.config,
    required this.child,
    this.isEditMode = false,
    this.onRemove,
    this.onFavorite,
    this.onTap,
    this.trailing,
    this.showHeader = true,
    this.customName,
    this.customIcon,
    this.reorderIndex,
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

  Future<void> _showRemoveConfirmation() async {
    final displayName =
        widget.customName ?? WidgetRegistry.getInfo(widget.config.type).name;

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text(
          'Remove Widget?',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "$displayName" from your dashboard?',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (shouldRemove == true) {
      widget.onRemove?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = WidgetRegistry.getInfo(widget.config.type);
    final isFavorite = widget.config.isFavorite;

    // Use custom overrides or fall back to registry info
    final displayName = widget.customName ?? info.name;
    final displayIcon = widget.customIcon ?? info.icon;

    // Use custom paint for dashed border in edit mode
    Widget content = widget.isEditMode
        ? CustomPaint(
            painter: DashedBorderPainter(
              color: context.accentColor.withValues(alpha: 0.6),
              strokeWidth: 2,
              dashWidth: 8,
              dashSpace: 4,
              borderRadius: 16,
            ),
            child: _buildCardContent(displayName, displayIcon, isFavorite),
          )
        : _buildCardContent(displayName, displayIcon, isFavorite);

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

  Widget _buildCardContent(
    String displayName,
    IconData displayIcon,
    bool isFavorite,
  ) {
    final cardChild = ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showHeader) _buildHeader(displayName, displayIcon),
            Flexible(child: widget.child),
          ],
        ),
      ),
    );

    if (isFavorite && !widget.isEditMode) {
      return GradientBorderContainer(
        borderRadius: 16,
        borderWidth: 2,
        accentOpacity: 1.0,
        backgroundColor: context.card,
        child: cardChild,
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isEditMode ? Colors.transparent : context.border,
          width: 1,
        ),
      ),
      child: cardChild,
    );
  }

  Widget _buildHeader(String displayName, IconData displayIcon) {
    Widget header = Container(
      padding: EdgeInsets.only(
        left: 16,
        right: widget.isEditMode ? 4 : 16,
        top: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: context.background.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: context.border.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          if (widget.isEditMode) ...[
            // Drag handle
            Icon(Icons.drag_indicator, color: context.textTertiary, size: 20),
            SizedBox(width: 8),
          ],
          // Icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(displayIcon, color: context.accentColor, size: 16),
          ),
          SizedBox(width: 10),
          // Title
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
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
                  : context.textTertiary,
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
                _showRemoveConfirmation();
              },
              tooltip: 'Remove widget',
            ),
          ],
        ],
      ),
    );

    // Wrap header with drag listener in edit mode (only header is draggable)
    if (widget.isEditMode && widget.reorderIndex != null) {
      header = ReorderableDragStartListener(
        index: widget.reorderIndex!,
        child: header,
      );
    }

    return header;
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 12),
              TextButton(
                onPressed: onAction,
                child: Text(
                  actionLabel!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.accentColor,
                  ),
                ),
              ),
            ],
          ],
        ),
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
          LoadingIndicator(size: 24),
          if (message != null) ...[
            SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom painter for dashed border in edit mode
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rrect);
    final dashPath = _createDashedPath(path);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(Path source) {
    final dashPath = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = dashWidth.clamp(0, metric.length - distance);
        dashPath.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    return dashPath;
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}
