import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../models/widget_schema.dart';

/// Simplified visual canvas for widget building with tap-to-place zones
class SimpleWidgetCanvas extends StatelessWidget {
  final WidgetSchema schema;
  final String? selectedElementId;
  final void Function(String elementId)? onElementTap;
  final void Function(String parentId, int index) onDropZoneTap;
  final VoidCallback? onTapOutside;

  const SimpleWidgetCanvas({
    super.key,
    required this.schema,
    this.selectedElementId,
    this.onElementTap,
    required this.onDropZoneTap,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    // Wrap entire canvas in gesture detector to handle tap outside
    return GestureDetector(
      onTap: onTapOutside,
      behavior: HitTestBehavior.opaque,
      child: _buildRootElement(context, schema.root),
    );
  }

  Widget _buildRootElement(BuildContext context, ElementSchema root) {
    final accentColor = context.accentColor;
    final hasChildren = root.children.isNotEmpty;

    // Root container - always shows drop zone if empty
    return Container(
      padding: root.style.paddingInsets ?? const EdgeInsets.all(12),
      child: hasChildren
          ? _buildLayoutChildren(context, root, accentColor)
          : _buildEmptyDropZone(context, root.id, 0, accentColor),
    );
  }

  Widget _buildLayoutChildren(
    BuildContext context,
    ElementSchema parent,
    Color accentColor,
  ) {
    final isRow = parent.type == ElementType.row;
    final spacing = parent.style.spacing ?? 8;

    // Build child elements without visible drop zones between them
    final children = parent.children
        .asMap()
        .entries
        .map(
          (entry) => _buildElement(
            context,
            entry.value,
            parent.id,
            entry.key,
            accentColor,
          ),
        )
        .toList();

    if (isRow) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: children.expand((w) => [w, SizedBox(width: spacing)]).toList()
          ..removeLast(),
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            children.expand((w) => [w, SizedBox(height: spacing)]).toList()
              ..removeLast(),
      );
    }
  }

  Widget _buildElement(
    BuildContext context,
    ElementSchema element,
    String parentId,
    int index,
    Color accentColor,
  ) {
    final isSelected = selectedElementId == element.id;
    final isLayout = _isLayoutElement(element.type);

    // Don't allow selecting the root column - that's the container
    final canSelect = element.id != schema.root.id;

    Widget content;

    if (isLayout && element.children.isNotEmpty) {
      // Nested layout with children
      content = _buildLayoutChildren(context, element, accentColor);
    } else if (isLayout && element.children.isEmpty) {
      // Empty layout - show drop zone inside
      content = _buildEmptyDropZone(context, element.id, 0, accentColor);
    } else {
      // Content element
      content = _buildElementPreview(context, element, accentColor);
    }

    // Wrap with selection handling
    return GestureDetector(
      onTap: canSelect && onElementTap != null
          ? () => onElementTap!(element.id)
          : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: isLayout
            ? (element.style.paddingInsets ?? const EdgeInsets.all(4))
            : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: isSelected && canSelect
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: accentColor.withValues(alpha: 0.1),
                border: Border.all(color: accentColor, width: 2),
              )
            : null,
        child: content,
      ),
    );
  }

  Widget _buildElementPreview(
    BuildContext context,
    ElementSchema element,
    Color accentColor,
  ) {
    switch (element.type) {
      case ElementType.text:
        final text = element.text ?? element.binding?.path ?? 'Text';
        final displayText = element.binding != null
            ? '{${element.binding!.path.split('.').last}}'
            : text;
        return Text(
          displayText,
          style: TextStyle(
            color: element.style.textColorValue ?? Colors.white,
            fontSize: element.style.fontSize ?? 14,
            fontWeight: element.style.fontWeightValue,
          ),
          overflow: TextOverflow.ellipsis,
        );

      case ElementType.icon:
        return Icon(
          _getIconData(element.iconName ?? 'help_outline'),
          size: element.iconSize ?? 24,
          color: element.style.textColorValue ?? accentColor,
        );

      case ElementType.gauge:
        return Container(
          height: element.style.height ?? 8,
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.6,
            child: Container(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );

      case ElementType.chart:
        return Container(
          height: element.style.height ?? 40,
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: CustomPaint(painter: _SparklinePainter(accentColor)),
        );

      case ElementType.shape:
        return Container(
          width: element.style.width ?? 40,
          height: element.style.height ?? 40,
          decoration: BoxDecoration(
            color:
                element.style.backgroundColorValue ??
                accentColor.withValues(alpha: 0.2),
            shape: element.shapeType == ShapeType.circle
                ? BoxShape.circle
                : BoxShape.rectangle,
            borderRadius: element.shapeType != ShapeType.circle
                ? BorderRadius.circular(element.style.borderRadius ?? 8)
                : null,
          ),
        );

      case ElementType.spacer:
        return SizedBox(
          width: element.style.width ?? 8,
          height: element.style.height ?? 8,
        );

      case ElementType.button:
        final hasAction =
            element.action != null && element.action!.type != ActionType.none;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: element.style.padding ?? 10,
            vertical: (element.style.padding ?? 10) / 2,
          ),
          decoration: BoxDecoration(
            color: element.style.backgroundColorValue ?? accentColor,
            borderRadius: BorderRadius.circular(
              element.style.borderRadius ?? 8,
            ),
            border: !hasAction
                ? Border.all(color: AppTheme.errorRed, width: 2)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (element.iconName != null) ...[
                Icon(
                  _getIconData(element.iconName!),
                  size: element.iconSize ?? 16,
                  color: element.style.textColorValue ?? Colors.white,
                ),
                if (element.text != null && element.text!.isNotEmpty)
                  const SizedBox(width: 4),
              ],
              if (element.text != null && element.text!.isNotEmpty)
                Flexible(
                  child: Text(
                    element.text!,
                    style: TextStyle(
                      color: element.style.textColorValue ?? Colors.white,
                      fontSize: element.style.fontSize ?? 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              if (!hasAction) ...[
                const SizedBox(width: 4),
                Icon(Icons.warning, size: 12, color: AppTheme.errorRed),
              ],
            ],
          ),
        );

      case ElementType.row:
      case ElementType.column:
      case ElementType.container:
        // Layout elements - render children
        if (element.children.isNotEmpty) {
          final isRow = element.type == ElementType.row;
          final children = element.children
              .map((c) => _buildElementPreview(context, c, accentColor))
              .toList();

          if (isRow) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children:
                  children
                      .expand(
                        (w) => [w, SizedBox(width: element.style.spacing ?? 8)],
                      )
                      .toList()
                    ..removeLast(),
            );
          } else {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  children
                      .expand(
                        (w) => [
                          w,
                          SizedBox(height: element.style.spacing ?? 8),
                        ],
                      )
                      .toList()
                    ..removeLast(),
            );
          }
        }
        return const SizedBox.shrink();

      default:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            element.type.name,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
          ),
        );
    }
  }

  Widget _buildEmptyDropZone(
    BuildContext context,
    String parentId,
    int index,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: () => onDropZoneTap(parentId, index),
      child: Container(
        constraints: const BoxConstraints(minHeight: 100),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: CustomPaint(
          painter: _DashedBorderPainter(accentColor.withValues(alpha: 0.4)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add,
                    color: accentColor.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to add element',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isLayoutElement(ElementType type) {
    return type == ElementType.row ||
        type == ElementType.column ||
        type == ElementType.container ||
        type == ElementType.stack;
  }

  IconData _getIconData(String name) {
    const iconMap = {
      'star': Icons.star,
      'favorite': Icons.favorite,
      'battery_full': Icons.battery_full,
      'signal_cellular_alt': Icons.signal_cellular_alt,
      'wifi': Icons.wifi,
      'gps_fixed': Icons.gps_fixed,
      'thermostat': Icons.thermostat,
      'water_drop': Icons.water_drop,
      'check_circle': Icons.check_circle,
      'warning': Icons.warning,
      'error': Icons.error,
      'info': Icons.info,
      'send': Icons.send,
      'message': Icons.message,
      'flash_on': Icons.flash_on,
      'speed': Icons.speed,
      'hub': Icons.hub,
      'router': Icons.router,
      'touch_app': Icons.touch_app,
      'location_on': Icons.location_on,
      'timeline': Icons.timeline,
      'refresh': Icons.refresh,
      'warning_amber': Icons.warning_amber,
    };
    return iconMap[name] ?? Icons.help_outline;
  }
}

/// Dashed border painter for empty drop zones
class _DashedBorderPainter extends CustomPainter {
  final Color color;

  _DashedBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    const radius = 8.0;

    // Approximate with dashed lines on each edge
    // Top edge
    double x = radius;
    while (x < size.width - radius) {
      canvas.drawLine(
        Offset(x, 1),
        Offset((x + dashWidth).clamp(0, size.width - radius), 1),
        paint,
      );
      x += dashWidth + dashSpace;
    }

    // Right edge
    double y = radius;
    while (y < size.height - radius) {
      canvas.drawLine(
        Offset(size.width - 1, y),
        Offset(size.width - 1, (y + dashWidth).clamp(0, size.height - radius)),
        paint,
      );
      y += dashWidth + dashSpace;
    }

    // Bottom edge
    x = radius;
    while (x < size.width - radius) {
      canvas.drawLine(
        Offset(x, size.height - 1),
        Offset((x + dashWidth).clamp(0, size.width - radius), size.height - 1),
        paint,
      );
      x += dashWidth + dashSpace;
    }

    // Left edge
    y = radius;
    while (y < size.height - radius) {
      canvas.drawLine(
        Offset(1, y),
        Offset(1, (y + dashWidth).clamp(0, size.height - radius)),
        paint,
      );
      y += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple sparkline painter for chart preview
class _SparklinePainter extends CustomPainter {
  final Color color;

  _SparklinePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final points = [0.3, 0.5, 0.4, 0.7, 0.6, 0.8, 0.5];

    for (var i = 0; i < points.length; i++) {
      final x = (i / (points.length - 1)) * size.width;
      final y =
          size.height - (points[i] * size.height * 0.8) - size.height * 0.1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple element type picker shown when tapping drop zones
class QuickElementPicker extends StatelessWidget {
  final void Function(ElementType type) onSelect;

  const QuickElementPicker({super.key, required this.onSelect});

  static Future<ElementType?> show(BuildContext context) {
    return AppBottomSheet.show<ElementType>(
      context: context,
      child: QuickElementPicker(
        onSelect: (type) => Navigator.pop(context, type),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Add Element',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        // Action button - prominent
        _buildActionButton(context, accentColor),

        const SizedBox(height: 16),
        _buildSectionLabel('CONTENT'),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildQuickOption(
              context,
              ElementType.text,
              Icons.text_fields,
              'Text',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildQuickOption(
              context,
              ElementType.icon,
              Icons.emoji_emotions,
              'Icon',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildQuickOption(
              context,
              ElementType.gauge,
              Icons.speed,
              'Gauge',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildQuickOption(
              context,
              ElementType.chart,
              Icons.show_chart,
              'Chart',
              accentColor,
            ),
          ],
        ),

        const SizedBox(height: 16),
        _buildSectionLabel('LAYOUT'),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildQuickOption(
              context,
              ElementType.row,
              Icons.view_column,
              'Row',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildQuickOption(
              context,
              ElementType.column,
              Icons.view_agenda,
              'Column',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildQuickOption(
              context,
              ElementType.spacer,
              Icons.space_bar,
              'Spacer',
              accentColor,
            ),
            const SizedBox(width: 8),
            _buildQuickOption(
              context,
              ElementType.shape,
              Icons.square,
              'Shape',
              accentColor,
            ),
          ],
        ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppTheme.textTertiary,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, Color accentColor) {
    return InkWell(
      onTap: () => onSelect(ElementType.button),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: 0.2),
              accentColor.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.touch_app, color: accentColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Action Button',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Tap to send message, share location, and more',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_circle, color: accentColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickOption(
    BuildContext context,
    ElementType type,
    IconData icon,
    String label,
    Color accentColor,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(type),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
