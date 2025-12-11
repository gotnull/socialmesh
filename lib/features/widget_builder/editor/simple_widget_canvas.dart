import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../models/widget_schema.dart';
import '../renderer/widget_renderer.dart';

/// Simplified visual canvas for widget building with tap-to-place zones
class SimpleWidgetCanvas extends StatelessWidget {
  final WidgetSchema schema;
  final String? selectedElementId;
  final bool isPreview;
  final void Function(String elementId) onElementTap;
  final void Function(String? parentId, int index) onDropZoneTap;
  final void Function(String elementId) onDeleteElement;

  const SimpleWidgetCanvas({
    super.key,
    required this.schema,
    this.selectedElementId,
    this.isPreview = false,
    required this.onElementTap,
    required this.onDropZoneTap,
    required this.onDeleteElement,
  });

  @override
  Widget build(BuildContext context) {
    if (isPreview) {
      return WidgetRenderer(
        schema: schema,
        accentColor: context.accentColor,
        usePlaceholderData: true,
        enableActions: false,
      );
    }

    return _buildEditableElement(context, schema.root, null, 0);
  }

  Widget _buildEditableElement(
    BuildContext context,
    ElementSchema element,
    String? parentId,
    int indexInParent,
  ) {
    final isSelected = selectedElementId == element.id;
    final accentColor = context.accentColor;

    // For layout elements, show children with drop zones
    if (_isLayoutElement(element.type)) {
      return _buildLayoutElement(context, element, isSelected, accentColor);
    }

    // For content elements, show as tappable items
    return _buildContentElement(context, element, isSelected, accentColor);
  }

  bool _isLayoutElement(ElementType type) {
    return type == ElementType.row ||
        type == ElementType.column ||
        type == ElementType.container ||
        type == ElementType.stack;
  }

  Widget _buildLayoutElement(
    BuildContext context,
    ElementSchema element,
    bool isSelected,
    Color accentColor,
  ) {
    final isRow = element.type == ElementType.row;
    final isColumn =
        element.type == ElementType.column ||
        element.type == ElementType.container;

    List<Widget> children = [];

    // Add drop zone at start
    children.add(_buildDropZone(context, element.id, 0, isRow, accentColor));

    // Add each child with drop zones after
    for (var i = 0; i < element.children.length; i++) {
      final child = element.children[i];
      children.add(_buildEditableElement(context, child, element.id, i));
      children.add(
        _buildDropZone(context, element.id, i + 1, isRow, accentColor),
      );
    }

    Widget content;
    if (isRow) {
      content = Row(mainAxisSize: MainAxisSize.min, children: children);
    } else if (isColumn) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    } else {
      // Stack
      content = Stack(
        children: [
          if (element.children.isEmpty)
            _buildDropZone(context, element.id, 0, false, accentColor),
          ...element.children.asMap().entries.map(
            (e) => _buildEditableElement(context, e.value, element.id, e.key),
          ),
        ],
      );
    }

    // Wrap in tappable container
    return GestureDetector(
      onTap: () => onElementTap(element.id),
      child: Container(
        padding: element.style.paddingInsets ?? const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: element.style.backgroundColorValue,
          borderRadius: BorderRadius.circular(element.style.borderRadius ?? 0),
          border: isSelected
              ? Border.all(color: accentColor, width: 2)
              : Border.all(
                  color: AppTheme.darkBorder.withValues(alpha: 0.5),
                  width: 1,
                  strokeAlign: BorderSide.strokeAlignOutside,
                ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildContentElement(
    BuildContext context,
    ElementSchema element,
    bool isSelected,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: () => onElementTap(element.id),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? Border.all(color: accentColor, width: 2) : null,
        ),
        child: _buildElementPreview(context, element, accentColor),
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
        return Text(
          element.binding != null
              ? '{\$${element.binding!.path.split('.').last}}'
              : text,
          style: TextStyle(
            color: element.style.textColorValue ?? Colors.white,
            fontSize: element.style.fontSize ?? 14,
          ),
        );

      case ElementType.icon:
        return Icon(
          _getIconData(element.iconName ?? 'help_outline'),
          size: element.iconSize ?? 24,
          color: element.style.textColorValue ?? accentColor,
        );

      case ElementType.gauge:
        return Container(
          width: element.style.width ?? 60,
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
          width: element.style.width ?? 80,
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

      case ElementType.image:
        return Container(
          width: element.style.width ?? 48,
          height: element.style.height ?? 48,
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.image, color: AppTheme.textSecondary, size: 24),
        );

      case ElementType.map:
        return Container(
          width: element.style.width ?? 80,
          height: element.style.height ?? 60,
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(Icons.map, color: AppTheme.textSecondary, size: 24),
        );

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

  Widget _buildDropZone(
    BuildContext context,
    String parentId,
    int index,
    bool isHorizontal,
    Color accentColor,
  ) {
    return GestureDetector(
      onTap: () => onDropZoneTap(parentId, index),
      child: Container(
        width: isHorizontal ? 32 : double.infinity,
        height: isHorizontal ? double.infinity : 32,
        constraints: BoxConstraints(minWidth: 32, minHeight: 32),
        margin: EdgeInsets.symmetric(
          horizontal: isHorizontal ? 2 : 0,
          vertical: isHorizontal ? 0 : 2,
        ),
        child: CustomPaint(
          painter: _DropZonePainter(
            color: accentColor.withValues(alpha: 0.3),
            isHorizontal: isHorizontal,
          ),
          child: Center(
            child: Icon(
              Icons.add,
              size: 16,
              color: accentColor.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    const iconMap = {
      'battery_full': Icons.battery_full,
      'battery_alert': Icons.battery_alert,
      'signal_cellular_alt': Icons.signal_cellular_alt,
      'wifi': Icons.wifi,
      'bluetooth': Icons.bluetooth,
      'gps_fixed': Icons.gps_fixed,
      'thermostat': Icons.thermostat,
      'water_drop': Icons.water_drop,
      'air': Icons.air,
      'cloud': Icons.cloud,
      'wb_sunny': Icons.wb_sunny,
      'hub': Icons.hub,
      'router': Icons.router,
      'devices': Icons.devices,
      'message': Icons.message,
      'chat': Icons.chat,
      'send': Icons.send,
      'map': Icons.map,
      'navigation': Icons.navigation,
      'explore': Icons.explore,
      'near_me': Icons.near_me,
      'location_on': Icons.location_on,
      'route': Icons.route,
      'settings': Icons.settings,
      'info': Icons.info,
      'warning': Icons.warning,
      'error': Icons.error,
      'check_circle': Icons.check_circle,
      'speed': Icons.speed,
      'timeline': Icons.timeline,
      'trending_up': Icons.trending_up,
      'trending_down': Icons.trending_down,
      'show_chart': Icons.show_chart,
      'favorite': Icons.favorite,
      'star': Icons.star,
      'flash_on': Icons.flash_on,
      'refresh': Icons.refresh,
      'help_outline': Icons.help_outline,
    };
    return iconMap[iconName] ?? Icons.help_outline;
  }
}

/// Painter for drop zone dotted border
class _DropZonePainter extends CustomPainter {
  final Color color;
  final bool isHorizontal;

  _DropZonePainter({required this.color, required this.isHorizontal});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;

    final path = Path();
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    path.addRRect(rect);

    // Draw dashed path
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashWidth).clamp(0, metric.length);
        final extractPath = metric.extractPath(start, end.toDouble());
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
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
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
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

        // Quick actions - most common elements
        Text(
          'CONTENT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textTertiary,
            letterSpacing: 1,
          ),
        ),
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
        Text(
          'LAYOUT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textTertiary,
            letterSpacing: 1,
          ),
        ),
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
