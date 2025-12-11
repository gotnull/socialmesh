import '../../../core/logging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/grid_widget_schema.dart';
import '../models/data_binding.dart';
import '../models/widget_schema.dart' show BindingSchema;
import '../../../core/theme.dart';
import '../../../models/mesh_models.dart';

/// Renderer for grid-based widget schemas
/// Displays elements positioned on a grid layout
class GridWidgetRenderer extends ConsumerWidget {
  final GridWidgetSchema schema;
  final MeshNode? node;
  final Map<int, MeshNode>? allNodes;
  final Color accentColor;
  final bool isPreview;
  final bool usePlaceholderData;

  /// Whether to enable action handling
  final bool enableActions;

  /// Device-level signal data
  final int? deviceRssi;
  final double? deviceSnr;
  final double? deviceChannelUtil;

  const GridWidgetRenderer({
    super.key,
    required this.schema,
    this.node,
    this.allNodes,
    required this.accentColor,
    this.isPreview = false,
    this.usePlaceholderData = false,
    this.enableActions = true,
    this.deviceRssi,
    this.deviceSnr,
    this.deviceChannelUtil,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bindingEngine = DataBindingEngine();
    bindingEngine.setUsePlaceholderData(usePlaceholderData);
    bindingEngine.setCurrentNode(node);
    bindingEngine.setAllNodes(allNodes);
    bindingEngine.setDeviceSignal(
      rssi: deviceRssi,
      snr: deviceSnr,
      channelUtil: deviceChannelUtil,
    );

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return _buildGrid(context, ref, bindingEngine, constraints);
        },
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    DataBindingEngine bindingEngine,
    BoxConstraints constraints,
  ) {
    final rows = schema.gridRows;
    final cols = schema.gridColumns;
    final padding = 8.0;
    final spacing = 6.0;

    final availableWidth = constraints.maxWidth - padding * 2;
    final availableHeight = constraints.maxHeight - padding * 2;
    final cellWidth = (availableWidth - (cols - 1) * spacing) / cols;
    final cellHeight = (availableHeight - (rows - 1) * spacing) / rows;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Stack(
        children: schema.elements.map((element) {
          final left = element.column * (cellWidth + spacing);
          final top = element.row * (cellHeight + spacing);
          final width =
              element.columnSpan * cellWidth +
              (element.columnSpan - 1) * spacing;
          final height =
              element.rowSpan * cellHeight + (element.rowSpan - 1) * spacing;

          Widget child = _buildElement(
            context,
            ref,
            element,
            bindingEngine,
            Size(width, height),
          );

          // Add action handling
          if (enableActions &&
              element.action != null &&
              element.action!.type != GridActionType.none) {
            child = GestureDetector(
              onTap: () => _handleAction(context, ref, element.action!),
              child: child,
            );
          }

          return Positioned(
            left: left,
            top: top,
            width: width,
            height: height,
            child: child,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildElement(
    BuildContext context,
    WidgetRef ref,
    GridElement element,
    DataBindingEngine bindingEngine,
    Size size,
  ) {
    switch (element.type) {
      case GridElementType.text:
        return _buildText(element, bindingEngine);
      case GridElementType.icon:
        return _buildIcon(element, bindingEngine);
      case GridElementType.iconText:
        return _buildIconText(element, bindingEngine);
      case GridElementType.gauge:
        return _buildGauge(element, bindingEngine, size);
      case GridElementType.chart:
        return _buildChart(element, bindingEngine, size);
      case GridElementType.button:
        return _buildButton(context, ref, element, bindingEngine);
    }
  }

  Widget _buildText(GridElement element, DataBindingEngine bindingEngine) {
    String text;
    if (element.binding != null) {
      final binding = BindingSchema(
        path: element.binding!.path,
        format: element.binding!.format,
        defaultValue: element.binding!.fallback,
      );
      final value = bindingEngine.resolveBinding(binding);
      if (value != null) {
        text = bindingEngine.formatValue(binding, value);
      } else {
        text = element.text ?? '--';
      }
    } else {
      text = element.text ?? 'Text';
    }

    final alignment = element.alignment ?? ElementAlignment.center;
    TextAlign textAlign;
    switch (alignment) {
      case ElementAlignment.left:
        textAlign = TextAlign.left;
      case ElementAlignment.center:
        textAlign = TextAlign.center;
      case ElementAlignment.right:
        textAlign = TextAlign.right;
    }

    return Align(
      alignment: Alignment(
        alignment == ElementAlignment.left
            ? -1.0
            : alignment == ElementAlignment.right
            ? 1.0
            : 0.0,
        0.0,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Text(
          text,
          style: TextStyle(
            color: element.textColor ?? Colors.white,
            fontSize: element.fontSize ?? 14,
            fontWeight: element.fontWeight ?? FontWeight.normal,
          ),
          textAlign: textAlign,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
        ),
      ),
    );
  }

  Widget _buildIcon(GridElement element, DataBindingEngine bindingEngine) {
    return Center(
      child: Icon(
        _getIconData(element.iconName ?? 'help_outline'),
        size: element.iconSize ?? 24,
        color: element.iconColor ?? accentColor,
      ),
    );
  }

  Widget _buildIconText(GridElement element, DataBindingEngine bindingEngine) {
    // Resolve text from binding or static text
    String text;
    if (element.binding != null) {
      final binding = BindingSchema(
        path: element.binding!.path,
        format: element.binding!.format,
        defaultValue: element.binding!.fallback,
      );
      final value = bindingEngine.resolveBinding(binding);
      if (value != null) {
        text = bindingEngine.formatValue(binding, value);
      } else {
        text = element.text ?? '--';
      }
    } else {
      text = element.text ?? 'Text';
    }

    final alignment = element.alignment ?? ElementAlignment.left;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment.mainAxisAlignment,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            _getIconData(element.iconName ?? 'info'),
            size: element.iconSize ?? 18,
            color: element.iconColor ?? accentColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                color: element.textColor ?? Colors.white,
                fontSize: element.fontSize ?? 14,
                fontWeight: element.fontWeight ?? FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGauge(
    GridElement element,
    DataBindingEngine bindingEngine,
    Size size,
  ) {
    // Get value from binding or use placeholder
    double value = 0.5;
    if (element.binding != null) {
      final binding = BindingSchema(path: element.binding!.path);
      final rawValue = bindingEngine.resolveBinding(binding);
      if (rawValue is num) {
        final min = element.gaugeMin ?? 0;
        final max = element.gaugeMax ?? 100;
        value = ((rawValue - min) / (max - min)).clamp(0.0, 1.0);
      }
    }

    final color = element.gaugeColor ?? accentColor;
    final style = element.gaugeStyle ?? GaugeStyle.linear;

    switch (style) {
      case GaugeStyle.circular:
        return _buildCircularGauge(value, color, size);
      case GaugeStyle.arc:
        return _buildArcGauge(value, color, size);
      case GaugeStyle.battery:
        return _buildBatteryGauge(value, color);
      case GaugeStyle.signal:
        return _buildSignalGauge(value, color);
      case GaugeStyle.linear:
        return _buildLinearGauge(value, color);
    }
  }

  Widget _buildLinearGauge(double value, Color color) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircularGauge(double value, Color color, Size size) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(painter: _CircularGaugePainter(color, value)),
        ),
      ),
    );
  }

  Widget _buildArcGauge(double value, Color color, Size size) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: Center(
        child: CustomPaint(
          painter: _ArcGaugePainter(color, value),
          size: Size(size.width - 8, (size.height - 8) / 2),
        ),
      ),
    );
  }

  Widget _buildBatteryGauge(double value, Color color) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 16,
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.all(2),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          Container(
            width: 2,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalGauge(double value, Color color) {
    const bars = 4;
    final activeBars = (value * bars).ceil();

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars, (i) {
          final isActive = i < activeBars;
          final height = 6.0 + (i * 4);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Container(
              width: 4,
              height: height,
              decoration: BoxDecoration(
                color: isActive ? color : color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChart(
    GridElement element,
    DataBindingEngine bindingEngine,
    Size size,
  ) {
    // Get data from binding or use placeholder
    List<double> data = [0.3, 0.5, 0.4, 0.7, 0.6, 0.8, 0.5, 0.6];
    if (element.binding != null) {
      final binding = BindingSchema(path: element.binding!.path);
      final rawValue = bindingEngine.resolveBinding(binding);
      if (rawValue is List) {
        data = rawValue.whereType<num>().map((n) => n.toDouble()).toList();
        // Normalize data
        if (data.isNotEmpty) {
          final max = data.reduce((a, b) => a > b ? a : b);
          if (max > 0) {
            data = data.map((v) => v / max).toList();
          }
        }
      }
    }

    final color = element.chartColor ?? accentColor;
    final style = element.chartStyle ?? ChartStyle.sparkline;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: CustomPaint(
        painter: switch (style) {
          ChartStyle.sparkline => _SparklinePainter(color, data),
          ChartStyle.bar => _BarChartPainter(color, data),
          ChartStyle.area => _AreaChartPainter(color, data),
        },
        size: Size(size.width - 8, size.height - 8),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    WidgetRef ref,
    GridElement element,
    DataBindingEngine bindingEngine,
  ) {
    final iconName = element.iconName ?? 'touch_app';
    final iconData = _getIconData(iconName);
    final text = element.text ?? 'Action';
    final iconColor = element.iconColor ?? Colors.white;
    final textColor = element.textColor ?? Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: element.action != null
            ? () => _handleAction(context, ref, element.action!)
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: iconColor, size: 24),
              const SizedBox(height: 4),
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, GridAction action) {
    // Import and use WidgetActionHandler for actual implementation
    // For now, just log
    AppLogging.widgetBuilder('Action triggered: ${action.type}');
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

// === Custom Painters ===

class _CircularGaugePainter extends CustomPainter {
  final Color color;
  final double value;

  _CircularGaugePainter(this.color, this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final strokeWidth = 4.0;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -3.14159 / 2;
    final sweepAngle = 2 * 3.14159 * value;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcGaugePainter extends CustomPainter {
  final Color color;
  final double value;

  _ArcGaugePainter(this.color, this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2 - 4;
    final strokeWidth = 6.0;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159,
      false,
      bgPaint,
    );

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159 * value,
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SparklinePainter extends CustomPainter {
  final Color color;
  final List<double> data;

  _SparklinePainter(this.color, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path();

    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - (data[i] * size.height * 0.8) - size.height * 0.1;
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

class _BarChartPainter extends CustomPainter {
  final Color color;
  final List<double> data;

  _BarChartPainter(this.color, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final barWidth = size.width / (data.length * 2 - 1);

    for (var i = 0; i < data.length; i++) {
      final left = i * barWidth * 2;
      final height = data[i] * size.height * 0.85;
      final top = size.height - height;

      final paint = Paint()..color = color;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barWidth, height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AreaChartPainter extends CustomPainter {
  final Color color;
  final List<double> data;

  _AreaChartPainter(this.color, this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final linePath = Path();
    for (var i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - (data[i] * size.height * 0.8) - size.height * 0.1;
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final areaPath = Path.from(linePath);
    areaPath.lineTo(size.width, size.height);
    areaPath.lineTo(0, size.height);
    areaPath.close();

    final areaPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
