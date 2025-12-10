import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/widget_schema.dart';
import '../models/data_binding.dart';
import '../../../core/theme.dart';

/// Renders a text element with optional data binding
class TextRenderer extends StatelessWidget {
  final ElementSchema element;
  final DataBindingEngine bindingEngine;
  final Color accentColor;

  const TextRenderer({
    super.key,
    required this.element,
    required this.bindingEngine,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    String text = element.text ?? '';

    // Resolve binding if present
    if (element.binding != null) {
      text = bindingEngine.resolveAndFormat(element.binding!);
    }

    return Text(
      text,
      style: TextStyle(
        color: element.style.textColorValue ?? Colors.white,
        fontSize: element.style.fontSize ?? 14,
        fontWeight: element.style.fontWeightValue ?? FontWeight.normal,
      ),
      textAlign: element.style.textAlignValue ?? TextAlign.left,
    );
  }
}

/// Renders a Material icon
class IconRenderer extends StatelessWidget {
  final ElementSchema element;
  final DataBindingEngine bindingEngine;
  final Color accentColor;

  const IconRenderer({
    super.key,
    required this.element,
    required this.bindingEngine,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconName = element.iconName ?? 'help_outline';
    final iconData = _getIconData(iconName);
    final size = element.iconSize ?? element.style.fontSize ?? 24.0;
    final color = element.style.textColorValue ?? accentColor;

    return Icon(iconData, size: size, color: color);
  }

  IconData _getIconData(String name) {
    // Map of common icon names to IconData
    const iconMap = <String, IconData>{
      // Status
      'battery_full': Icons.battery_full,
      'battery_alert': Icons.battery_alert,
      'battery_charging_full': Icons.battery_charging_full,
      'battery_0_bar': Icons.battery_0_bar,
      'battery_1_bar': Icons.battery_1_bar,
      'battery_2_bar': Icons.battery_2_bar,
      'battery_3_bar': Icons.battery_3_bar,
      'battery_4_bar': Icons.battery_4_bar,
      'battery_5_bar': Icons.battery_5_bar,
      'battery_6_bar': Icons.battery_6_bar,
      'signal_cellular_alt': Icons.signal_cellular_alt,
      'signal_cellular_4_bar': Icons.signal_cellular_4_bar,
      'wifi': Icons.wifi,
      'wifi_off': Icons.wifi_off,
      'bluetooth': Icons.bluetooth,
      'bluetooth_connected': Icons.bluetooth_connected,
      'gps_fixed': Icons.gps_fixed,
      'gps_not_fixed': Icons.gps_not_fixed,
      'location_on': Icons.location_on,
      'location_off': Icons.location_off,

      // Weather/Environment
      'thermostat': Icons.thermostat,
      'water_drop': Icons.water_drop,
      'air': Icons.air,
      'cloud': Icons.cloud,
      'wb_sunny': Icons.wb_sunny,
      'nights_stay': Icons.nights_stay,
      'storm': Icons.storm,
      'grain': Icons.grain,
      'eco': Icons.eco,

      // Network
      'hub': Icons.hub,
      'router': Icons.router,
      'devices': Icons.devices,
      'device_hub': Icons.device_hub,
      'cell_tower': Icons.cell_tower,
      'broadcast_on_personal': Icons.broadcast_on_personal,

      // Communication
      'message': Icons.message,
      'chat': Icons.chat,
      'chat_bubble': Icons.chat_bubble,
      'chat_bubble_outline': Icons.chat_bubble_outline,
      'send': Icons.send,
      'mail': Icons.mail,
      'notifications': Icons.notifications,
      'notifications_active': Icons.notifications_active,

      // People
      'person': Icons.person,
      'person_outline': Icons.person_outline,
      'people': Icons.people,
      'people_outline': Icons.people_outline,
      'group': Icons.group,
      'groups': Icons.groups,

      // Navigation
      'map': Icons.map,
      'navigation': Icons.navigation,
      'explore': Icons.explore,
      'near_me': Icons.near_me,
      'directions': Icons.directions,
      'terrain': Icons.terrain,
      'route': Icons.route,
      'alt_route': Icons.alt_route,

      // Actions
      'settings': Icons.settings,
      'info': Icons.info,
      'warning': Icons.warning,
      'error': Icons.error,
      'check_circle': Icons.check_circle,
      'check_circle_outline': Icons.check_circle_outline,
      'cancel': Icons.cancel,
      'refresh': Icons.refresh,
      'sync': Icons.sync,
      'power': Icons.power,
      'power_settings_new': Icons.power_settings_new,
      'flash_on': Icons.flash_on,
      'flash_off': Icons.flash_off,
      'bolt': Icons.bolt,

      // Time
      'schedule': Icons.schedule,
      'access_time': Icons.access_time,
      'history': Icons.history,
      'update': Icons.update,

      // Misc
      'speed': Icons.speed,
      'timeline': Icons.timeline,
      'trending_up': Icons.trending_up,
      'trending_down': Icons.trending_down,
      'show_chart': Icons.show_chart,
      'bar_chart': Icons.bar_chart,
      'pie_chart': Icons.pie_chart,
      'analytics': Icons.analytics,
      'favorite': Icons.favorite,
      'star': Icons.star,
      'help_outline': Icons.help_outline,
    };

    return iconMap[name] ?? Icons.help_outline;
  }
}

/// Renders a linear or radial gauge
class GaugeRenderer extends StatelessWidget {
  final ElementSchema element;
  final DataBindingEngine bindingEngine;
  final Color accentColor;

  const GaugeRenderer({
    super.key,
    required this.element,
    required this.bindingEngine,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    double value = 0;
    final min = element.gaugeMin ?? 0;
    final max = element.gaugeMax ?? 100;

    if (element.binding != null) {
      final rawValue = bindingEngine.resolveBinding(element.binding!);
      if (rawValue is num) {
        value = rawValue.toDouble();
      }
    }

    // Normalize value to 0-1 range
    final normalizedValue = ((value - min) / (max - min)).clamp(0.0, 1.0);

    final gaugeColor = element.gaugeColor != null
        ? StyleSchema.parseColor(element.gaugeColor!)
        : accentColor;
    final backgroundColor = element.gaugeBackgroundColor != null
        ? StyleSchema.parseColor(element.gaugeBackgroundColor!)
        : AppTheme.darkBorder;

    switch (element.gaugeType ?? GaugeType.linear) {
      case GaugeType.linear:
        return _buildLinearGauge(normalizedValue, gaugeColor, backgroundColor);
      case GaugeType.radial:
        return _buildRadialGauge(normalizedValue, gaugeColor, backgroundColor);
      case GaugeType.arc:
        return _buildArcGauge(normalizedValue, gaugeColor, backgroundColor);
      case GaugeType.battery:
        return _buildBatteryGauge(
          normalizedValue,
          value,
          gaugeColor,
          backgroundColor,
        );
      case GaugeType.signal:
        return _buildSignalGauge(
          normalizedValue,
          value,
          gaugeColor,
          backgroundColor,
        );
    }
  }

  Widget _buildLinearGauge(
    double value,
    Color gaugeColor,
    Color backgroundColor,
  ) {
    final height = element.style.height ?? 8.0;
    final borderRadius = element.style.borderRadius ?? 4.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation(gaugeColor),
        minHeight: height,
      ),
    );
  }

  Widget _buildRadialGauge(
    double value,
    Color gaugeColor,
    Color backgroundColor,
  ) {
    final size = element.style.width ?? element.style.height ?? 60.0;

    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        value: value,
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation(gaugeColor),
        strokeWidth: size / 8,
      ),
    );
  }

  Widget _buildArcGauge(double value, Color gaugeColor, Color backgroundColor) {
    final size = element.style.width ?? element.style.height ?? 80.0;

    return SizedBox(
      width: size,
      height: size / 2 + 10,
      child: CustomPaint(
        painter: _ArcGaugePainter(
          value: value,
          gaugeColor: gaugeColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }

  Widget _buildBatteryGauge(
    double normalizedValue,
    double actualValue,
    Color gaugeColor,
    Color backgroundColor,
  ) {
    // Color based on battery level
    Color effectiveColor;
    if (actualValue <= 20) {
      effectiveColor = AppTheme.errorRed;
    } else if (actualValue <= 40) {
      effectiveColor = AppTheme.warningYellow;
    } else {
      effectiveColor = gaugeColor;
    }

    final width = element.style.width ?? 24.0;
    final height = element.style.height ?? 12.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(color: effectiveColor, width: 1.5),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: FractionallySizedBox(
              widthFactor: normalizedValue,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: effectiveColor,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
        ),
        Container(
          width: 2,
          height: height * 0.5,
          decoration: BoxDecoration(
            color: effectiveColor,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(1),
              bottomRight: Radius.circular(1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignalGauge(
    double normalizedValue,
    double actualValue,
    Color gaugeColor,
    Color backgroundColor,
  ) {
    final barCount = 4;
    final activeCount = (normalizedValue * barCount).ceil();
    final barWidth = (element.style.width ?? 20.0) / barCount - 2;
    final maxHeight = element.style.height ?? 16.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(barCount, (index) {
        final isActive = index < activeCount;
        final barHeight = maxHeight * (index + 1) / barCount;

        return Container(
          width: barWidth,
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: isActive ? gaugeColor : backgroundColor,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

/// Custom painter for arc gauge
class _ArcGaugePainter extends CustomPainter {
  final double value;
  final Color gaugeColor;
  final Color backgroundColor;

  _ArcGaugePainter({
    required this.value,
    required this.gaugeColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width / 10;
    final center = Offset(size.width / 2, size.height - 5);
    final radius = size.width / 2 - strokeWidth;

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final gaugePaint = Paint()
      ..color = gaugeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw background arc (180 degrees)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159, // PI - start from left
      3.14159, // PI - half circle
      false,
      backgroundPaint,
    );

    // Draw value arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14159,
      3.14159 * value,
      false,
      gaugePaint,
    );
  }

  @override
  bool shouldRepaint(_ArcGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.gaugeColor != gaugeColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// Renders a sparkline or bar chart
class ChartRenderer extends StatelessWidget {
  final ElementSchema element;
  final DataBindingEngine bindingEngine;
  final Color accentColor;
  final List<double>? historyData;

  const ChartRenderer({
    super.key,
    required this.element,
    required this.bindingEngine,
    required this.accentColor,
    this.historyData,
  });

  @override
  Widget build(BuildContext context) {
    // Use provided history data or generate sample data
    final data = historyData ?? _generateSampleData();
    final chartColor = element.style.textColorValue ?? accentColor;

    switch (element.chartType ?? ChartType.sparkline) {
      case ChartType.sparkline:
        return _buildSparkline(data, chartColor);
      case ChartType.bar:
        return _buildBarChart(data, chartColor);
      case ChartType.line:
        return _buildLineChart(data, chartColor);
      case ChartType.area:
        return _buildAreaChart(data, chartColor);
    }
  }

  List<double> _generateSampleData() {
    // Generate sample data points for preview
    final count = element.chartMaxPoints ?? 20;
    return List.generate(
      count,
      (i) => (50 + 30 * (i % 5 - 2) / 2 + 10 * (i % 3 - 1)).toDouble(),
    );
  }

  Widget _buildSparkline(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        minY: data.reduce((a, b) => a < b ? a : b) - 5,
        maxY: data.reduce((a, b) => a > b ? a : b) + 5,
      ),
    );
  }

  Widget _buildBarChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        barGroups: data.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value,
                color: color,
                width: 4,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(2),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildAreaChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a basic shape (rectangle, circle, divider)
/// Supports optional child rendering for shapes that contain other elements
class ShapeRenderer extends StatelessWidget {
  final ElementSchema element;
  final Color accentColor;
  final Color borderColor;
  final Widget? child;

  const ShapeRenderer({
    super.key,
    required this.element,
    required this.accentColor,
    required this.borderColor,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final color = element.shapeColor != null
        ? StyleSchema.parseColor(element.shapeColor!)
        : accentColor;

    switch (element.shapeType ?? ShapeType.rectangle) {
      case ShapeType.rectangle:
        return Container(
          width: element.style.width,
          height: element.style.height ?? 40,
          decoration: BoxDecoration(
            color: element.style.backgroundColorValue ?? color,
            borderRadius: BorderRadius.circular(
              element.style.borderRadius ?? 0,
            ),
            border: element.style.borderWidth != null
                ? Border.all(
                    color: element.style.borderColorValue ?? color,
                    width: element.style.borderWidth!,
                  )
                : null,
          ),
          child: child != null ? Center(child: child) : null,
        );

      case ShapeType.circle:
        final size = element.style.width ?? element.style.height ?? 40;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: element.style.backgroundColorValue ?? color,
            shape: BoxShape.circle,
            border: element.style.borderWidth != null
                ? Border.all(
                    color: element.style.borderColorValue ?? color,
                    width: element.style.borderWidth!,
                  )
                : null,
          ),
          child: child != null ? Center(child: child) : null,
        );

      case ShapeType.roundedRect:
        return Container(
          width: element.style.width,
          height: element.style.height ?? 40,
          decoration: BoxDecoration(
            color: element.style.backgroundColorValue ?? color,
            borderRadius: BorderRadius.circular(
              element.style.borderRadius ?? 8,
            ),
            border: element.style.borderWidth != null
                ? Border.all(
                    color: element.style.borderColorValue ?? color,
                    width: element.style.borderWidth!,
                  )
                : null,
          ),
          child: child != null ? Center(child: child) : null,
        );

      case ShapeType.dividerHorizontal:
        return Container(
          width: element.style.width,
          height: element.style.height ?? 1,
          color: element.style.backgroundColorValue ?? borderColor,
        );

      case ShapeType.dividerVertical:
        return Container(
          width: element.style.width ?? 1,
          height: element.style.height,
          color: element.style.backgroundColorValue ?? borderColor,
        );
    }
  }
}

/// Renders a spacer element
class SpacerRenderer extends StatelessWidget {
  final ElementSchema element;

  const SpacerRenderer({super.key, required this.element});

  @override
  Widget build(BuildContext context) {
    if (element.style.expanded == true) {
      return Expanded(
        flex: element.style.flex ?? 1,
        child: const SizedBox.shrink(),
      );
    }

    return SizedBox(
      width: element.style.width,
      height: element.style.height ?? 8,
    );
  }
}
