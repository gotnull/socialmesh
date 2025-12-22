import 'dart:async';
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

    // Resolve text color with accent support
    final textColor = element.style.textColor != null
        ? StyleSchema.resolveColor(element.style.textColor!, accentColor)
        : Colors.white;

    return Text(
      text,
      style: TextStyle(
        color: textColor,
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

    // Resolve icon color with accent support
    final color = element.style.textColor != null
        ? StyleSchema.resolveColor(element.style.textColor!, accentColor)
        : accentColor;

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
      'radar': Icons.radar,

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

      // Emergency
      'emergency': Icons.emergency,
      'sos': Icons.sos,
      'local_hospital': Icons.local_hospital,
      'medical_services': Icons.medical_services,

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
    final size = element.style.width ?? element.style.height ?? 100.0;
    final strokeWidth = size / 12;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: strokeWidth,
              backgroundColor: backgroundColor,
              valueColor: AlwaysStoppedAnimation(
                backgroundColor.withValues(alpha: 0.3),
              ),
            ),
          ),
          // Progress circle
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(gaugeColor),
              strokeCap: StrokeCap.round,
            ),
          ),
        ],
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

/// Renders a sparkline or bar chart with live history tracking
class ChartRenderer extends StatefulWidget {
  final ElementSchema element;
  final DataBindingEngine bindingEngine;
  final Color accentColor;
  final List<double>? historyData;
  final bool isPreview;

  const ChartRenderer({
    super.key,
    required this.element,
    required this.bindingEngine,
    required this.accentColor,
    this.historyData,
    this.isPreview = false,
  });

  @override
  State<ChartRenderer> createState() => _ChartRendererState();
}

class _ChartRendererState extends State<ChartRenderer> {
  // Single history for single binding
  final List<double> _history = [];
  // Multiple histories for multi-line charts
  final Map<String, List<double>> _multiHistory = {};
  Timer? _updateTimer;

  // Accessor helpers for chart properties
  bool get _showGrid => widget.element.chartShowGrid ?? false;
  bool get _showDots => widget.element.chartShowDots ?? false;
  bool get _isCurved => widget.element.chartCurved ?? true;
  int get _maxPoints => widget.element.chartMaxPoints ?? 30;

  // Advanced options
  ChartMergeMode get _mergeMode =>
      widget.element.chartMergeMode ?? ChartMergeMode.overlay;
  ChartNormalization get _normalization =>
      widget.element.chartNormalization ?? ChartNormalization.raw;
  ChartBaseline get _baseline =>
      widget.element.chartBaseline ?? ChartBaseline.none;
  bool get _showMinMax => widget.element.chartShowMinMax ?? false;

  bool get _gradientFill => widget.element.chartGradientFill ?? false;

  Color get _gradientLowColor => widget.element.chartGradientLowColor != null
      ? StyleSchema.parseColor(widget.element.chartGradientLowColor!)
      : const Color(0xFF4CAF50);
  Color get _gradientHighColor => widget.element.chartGradientHighColor != null
      ? StyleSchema.parseColor(widget.element.chartGradientHighColor!)
      : const Color(0xFFFF5252);
  List<double> get _thresholds => widget.element.chartThresholds ?? [];
  List<Color> get _thresholdColors =>
      (widget.element.chartThresholdColors ?? [])
          .map((c) => StyleSchema.parseColor(c))
          .toList();
  List<String> get _thresholdLabels =>
      widget.element.chartThresholdLabels ?? [];

  // Check if this is a multi-line chart
  bool get _isMultiLine {
    final value =
        widget.element.chartType == ChartType.multiLine &&
        widget.element.chartBindingPaths != null &&
        widget.element.chartBindingPaths!.isNotEmpty;
    debugPrint(
      '[RENDERER] _isMultiLine: chartType=${widget.element.chartType}, paths=${widget.element.chartBindingPaths}, result=$value',
    );
    return value;
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[RENDERER] initState: chartType=${widget.element.chartType}');
    debugPrint(
      '[RENDERER] initState: chartLegendColors=${widget.element.chartLegendColors}',
    );
    debugPrint(
      '[RENDERER] initState: chartShowMinMax=${widget.element.chartShowMinMax}',
    );
    debugPrint(
      '[RENDERER] initState: chartGradientFill=${widget.element.chartGradientFill}',
    );

    // Initialize multi-line histories
    if (_isMultiLine) {
      debugPrint(
        '[RENDERER] initState: initializing _multiHistory for multiLine',
      );
      for (final path in widget.element.chartBindingPaths!) {
        _multiHistory[path] = [];
      }
    }

    // For preview mode, generate sample data so the chart isn't empty
    debugPrint('[RENDERER] initState: isPreview=${widget.isPreview}');
    if (widget.isPreview) {
      _initPreviewData();
      debugPrint(
        '[RENDERER] initState: after _initPreviewData, _multiHistory.keys=${_multiHistory.keys}',
      );
      for (final path in _multiHistory.keys) {
        debugPrint(
          '[RENDERER] initState: _multiHistory[$path].length=${_multiHistory[path]?.length}',
        );
      }
    } else {
      // Add initial data point
      _addDataPoint();
      // Start timer to collect history (every 2 seconds like signal strength)
      _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (mounted) _addDataPoint();
      });
    }
  }

  /// Initialize sample data for preview mode
  /// Uses deterministic data so toggling visual options doesn't change the chart shape
  void _initPreviewData() {
    if (_isMultiLine) {
      // Generate deterministic sample data for each series using _maxPoints
      // Each series gets a different but consistent pattern based on its index
      for (int i = 0; i < widget.element.chartBindingPaths!.length; i++) {
        final path = widget.element.chartBindingPaths![i];
        // Deterministic base value and pattern for each series
        final baseValue = (i + 1) * 25.0;
        final phaseOffset = i * 2; // Different phase for visual separation
        _multiHistory[path] = List.generate(
          _maxPoints,
          (index) =>
              baseValue +
              15 * ((index + phaseOffset) % 5 - 2) / 2 +
              8 * ((index + phaseOffset) % 3 - 1),
        );
      }
    } else {
      // Use existing deterministic sample data generator for single series
      _history.addAll(_generateSampleData());
    }
  }

  @override
  void didUpdateWidget(ChartRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Check if chart configuration changed significantly
    final oldPaths = oldWidget.element.chartBindingPaths;
    final newPaths = widget.element.chartBindingPaths;
    final oldType = oldWidget.element.chartType;
    final newType = widget.element.chartType;
    final oldMaxPoints = oldWidget.element.chartMaxPoints;
    final newMaxPoints = widget.element.chartMaxPoints;

    // Detect if we switched to/from multiLine or paths changed
    final pathsChanged = !_listEquals(oldPaths, newPaths);
    final typeChanged = oldType != newType;
    final maxPointsChanged = oldMaxPoints != newMaxPoints;

    if (pathsChanged || typeChanged || maxPointsChanged) {
      debugPrint('[RENDERER] didUpdateWidget: config changed, reinitializing');
      debugPrint('[RENDERER] oldPaths=$oldPaths, newPaths=$newPaths');
      debugPrint('[RENDERER] oldType=$oldType, newType=$newType');
      debugPrint(
        '[RENDERER] oldMaxPoints=$oldMaxPoints, newMaxPoints=$newMaxPoints',
      );

      // Clear old data
      _multiHistory.clear();
      _history.clear();

      // Re-initialize for new configuration
      if (_isMultiLine) {
        for (final path in widget.element.chartBindingPaths!) {
          _multiHistory[path] = [];
        }
      }

      // Re-generate preview data if in preview mode
      if (widget.isPreview) {
        _initPreviewData();
      }
    }
  }

  /// Helper to compare two lists for equality
  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _addDataPoint() {
    if (_isMultiLine) {
      // Multi-line: get value for each binding path
      setState(() {
        for (final path in widget.element.chartBindingPaths!) {
          final value = widget.bindingEngine.resolveBinding(
            BindingSchema(path: path),
          );

          double? numValue;
          if (value is int) {
            numValue = value.toDouble();
          } else if (value is double) {
            numValue = value;
          }

          if (numValue != null) {
            _multiHistory[path]!.add(numValue);
            // Keep only last N points
            while (_multiHistory[path]!.length > _maxPoints) {
              _multiHistory[path]!.removeAt(0);
            }
          }
        }
      });
    } else {
      // Single binding
      final value = widget.bindingEngine.resolveBinding(
        widget.element.binding ?? BindingSchema(path: 'node.rssi'),
      );

      double? numValue;
      if (value is int) {
        numValue = value.toDouble();
      } else if (value is double) {
        numValue = value;
      }

      if (numValue != null) {
        setState(() {
          _history.add(numValue!);
          // Keep only last N points
          while (_history.length > _maxPoints) {
            _history.removeAt(0);
          }
        });
      }
    }
  }

  // Normalize data based on normalization mode
  List<double> _normalizeData(List<double> data) {
    if (data.isEmpty) return data;

    switch (_normalization) {
      case ChartNormalization.raw:
        return data;

      case ChartNormalization.percentChange:
        // Calculate percent change from first value
        final firstValue = data.first;
        if (firstValue == 0) return data;
        return data
            .map((v) => ((v - firstValue) / firstValue.abs()) * 100)
            .toList();

      case ChartNormalization.normalized:
        // Normalize to 0-100 range
        final minVal = data.reduce((a, b) => a < b ? a : b);
        final maxVal = data.reduce((a, b) => a > b ? a : b);
        final range = maxVal - minVal;
        if (range == 0) return data.map((_) => 50.0).toList();
        return data.map((v) => ((v - minVal) / range) * 100).toList();
    }
  }

  // Get baseline value for comparison line
  double? _getBaselineValue(List<double> data) {
    if (data.isEmpty) return null;

    switch (_baseline) {
      case ChartBaseline.none:
        return null;
      case ChartBaseline.firstValue:
        return data.first;
      case ChartBaseline.average:
        return data.reduce((a, b) => a + b) / data.length;
    }
  }

  // Get min/max indices and values
  (int minIdx, int maxIdx, double minVal, double maxVal)? _getMinMax(
    List<double> data,
  ) {
    if (data.isEmpty) return null;

    int minIdx = 0;
    int maxIdx = 0;
    double minVal = data.first;
    double maxVal = data.first;

    for (int i = 1; i < data.length; i++) {
      if (data[i] < minVal) {
        minVal = data[i];
        minIdx = i;
      }
      if (data[i] > maxVal) {
        maxVal = data[i];
        maxIdx = i;
      }
    }

    return (minIdx, maxIdx, minVal, maxVal);
  }

  // Get gradient color based on value position between min and max
  Color _getGradientColor(double value, double minVal, double maxVal) {
    if (maxVal == minVal) return _gradientLowColor;
    final t = (value - minVal) / (maxVal - minVal);
    return Color.lerp(_gradientLowColor, _gradientHighColor, t) ??
        _gradientLowColor;
  }

  // Build threshold horizontal lines for fl_chart
  List<HorizontalLine> _buildThresholdLines() {
    final lines = <HorizontalLine>[];
    for (int i = 0; i < _thresholds.length; i++) {
      final color = i < _thresholdColors.length
          ? _thresholdColors[i]
          : const Color(0xFFFF5252);
      final label = i < _thresholdLabels.length ? _thresholdLabels[i] : '';

      lines.add(
        HorizontalLine(
          y: _thresholds[i],
          color: color.withValues(alpha: 0.7),
          strokeWidth: 1.5,
          dashArray: [5, 5],
          // Use spikyLine to create a label effect at the end
          label: label.isNotEmpty
              ? HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 6, bottom: 4),
                  labelResolver: (_) => label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    background: Paint()
                      ..color = color.withValues(alpha: 0.9)
                      ..style = PaintingStyle.fill,
                  ),
                )
              : null,
        ),
      );
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[RENDERER] === ChartRenderer.build() START ===');
    debugPrint('[RENDERER] chartType=${widget.element.chartType}');
    debugPrint(
      '[RENDERER] chartBindingPaths=${widget.element.chartBindingPaths}',
    );
    debugPrint(
      '[RENDERER] chartLegendColors=${widget.element.chartLegendColors}',
    );
    debugPrint('[RENDERER] isPreview=${widget.isPreview}');
    debugPrint('[RENDERER] style.height=${widget.element.style.height}');
    debugPrint('[RENDERER] style.width=${widget.element.style.width}');

    // Handle multi-line chart separately
    if (_isMultiLine) {
      debugPrint('[RENDERER] Taking multiLine path');
      return _buildMultiLineChart();
    }

    debugPrint('[RENDERER] Taking single-line path');
    debugPrint('[RENDERER] _history.length=${_history.length}');
    debugPrint('[RENDERER] widget.historyData=${widget.historyData}');
    // Use provided history, built-up history, or sample data for preview
    List<double> rawData;
    if (widget.historyData != null) {
      rawData = widget.historyData!;
      debugPrint('[RENDERER] Using widget.historyData');
    } else if (_history.isNotEmpty) {
      rawData = _history;
      debugPrint('[RENDERER] Using _history');
    } else {
      rawData = _generateSampleData();
      debugPrint('[RENDERER] Using _generateSampleData');
    }
    debugPrint('[RENDERER] rawData.length=${rawData.length}');

    // Apply normalization
    final data = _normalizeData(rawData);

    final chartColor =
        widget.element.style.textColorValue ?? widget.accentColor;

    // Get chart dimensions from style
    final chartHeight = widget.element.style.height ?? 120.0;
    final chartWidth = widget.element.style.width;

    Widget chartWidget;
    switch (widget.element.chartType ?? ChartType.sparkline) {
      case ChartType.sparkline:
        chartWidget = _buildSparkline(data, chartColor);
      case ChartType.bar:
        chartWidget = _buildBarChart(data, chartColor);
      case ChartType.line:
        chartWidget = _buildLineChart(data, chartColor);
      case ChartType.area:
        chartWidget = _buildAreaChart(data, chartColor);
      case ChartType.stepped:
        chartWidget = _buildSteppedChart(data, chartColor);
      case ChartType.scatter:
        chartWidget = _buildScatterChart(data, chartColor);
      case ChartType.multiLine:
      case ChartType.stackedArea:
      case ChartType.stackedBar:
        // These are handled by _buildMultiLineChart above
        chartWidget = _buildLineChart(data, chartColor);
    }

    // Wrap in SizedBox to ensure chart has bounded constraints
    return SizedBox(height: chartHeight, width: chartWidth, child: chartWidget);
  }

  List<double> _generateSampleData() {
    // Generate sample data points for preview
    return List.generate(
      _maxPoints,
      (i) => (50 + 30 * (i % 5 - 2) / 2 + 10 * (i % 3 - 1)).toDouble(),
    );
  }

  Widget _buildMultiLineChart() {
    debugPrint('[RENDERER] _buildMultiLineChart() called');
    final paths = widget.element.chartBindingPaths!;
    final colors = widget.element.chartLegendColors ?? [];
    debugPrint('[RENDERER] paths=$paths, colors=$colors');
    debugPrint('[RENDERER] _multiHistory.keys=${_multiHistory.keys}');
    debugPrint('[RENDERER] _mergeMode=$_mergeMode');

    // Collect raw data for each series
    final seriesData = <String, List<double>>{};
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final history = _multiHistory[path] ?? [];
      debugPrint('[RENDERER] path=$path, history.length=${history.length}');

      List<double> data;
      if (history.isNotEmpty) {
        data = _normalizeData(history);
      } else {
        // Generate slightly different sample data for each line
        debugPrint('[RENDERER] Generating sample data for $path');
        data = _normalizeData(
          List.generate(
            _maxPoints,
            (j) =>
                (50 +
                        30 * ((j + i * 7) % 5 - 2) / 2 +
                        10 * ((j + i * 3) % 3 - 1))
                    .toDouble(),
          ),
        );
      }
      seriesData[path] = data;
      debugPrint('[RENDERER] seriesData[$path].length=${data.length}');
    }

    debugPrint('[RENDERER] seriesData complete, keys=${seriesData.keys}');

    // Handle stacked modes
    if (_mergeMode == ChartMergeMode.stackedArea ||
        _mergeMode == ChartMergeMode.stackedBar) {
      debugPrint('[RENDERER] Using stacked mode: $_mergeMode');
      return _buildStackedChart(paths, seriesData, colors);
    }

    debugPrint('[RENDERER] Using overlay mode');
    // Default overlay mode - build line data for each series
    final lineBarsData = <LineChartBarData>[];
    double globalMinY = double.infinity;
    double globalMaxY = double.negativeInfinity;

    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final data = seriesData[path] ?? [];
      debugPrint(
        '[RENDERER] Building line for $path, data.length=${data.length}',
      );

      // Use provided color or default
      Color lineColor;
      if (i < colors.length) {
        lineColor = StyleSchema.parseColor(colors[i]);
        debugPrint(
          '[RENDERER] Series $i ($path): using provided color ${colors[i]} -> $lineColor',
        );
      } else {
        final defaultColors = [
          widget.accentColor,
          const Color(0xFF00BCD4),
          const Color(0xFFFF9800),
          const Color(0xFF4CAF50),
          const Color(0xFFE91E63),
          const Color(0xFF9C27B0),
        ];
        lineColor = defaultColors[i % defaultColors.length];
      }

      if (data.isEmpty) continue;

      // Update global min/max
      final minVal = data.reduce((a, b) => a < b ? a : b);
      final maxVal = data.reduce((a, b) => a > b ? a : b);
      if (minVal < globalMinY) globalMinY = minVal;
      if (maxVal > globalMaxY) globalMaxY = maxVal;

      final spots = data
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList();

      debugPrint(
        '[RENDERER] Line $i: spots.length=${spots.length}, '
        'first=${spots.isNotEmpty ? spots.first : "N/A"}, '
        'last=${spots.isNotEmpty ? spots.last : "N/A"}',
      );
      debugPrint('[RENDERER] Line $i: minY=$minVal, maxY=$maxVal');
      debugPrint(
        '[RENDERER] Line $i: gradientFill=$_gradientFill, color=$lineColor',
      );

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: _isCurved,
          // Support gradient fill for merged charts
          color: _gradientFill ? null : lineColor,
          gradient: _gradientFill
              ? LinearGradient(
                  colors: [_gradientLowColor, _gradientHighColor],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                )
              : null,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: _showDots,
            getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
              radius: 2,
              color: _gradientFill
                  ? _gradientHighColor // Use high color for dots when gradient
                  : lineColor,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: _gradientFill
                ? LinearGradient(
                    colors: [
                      _gradientLowColor.withValues(alpha: 0.3),
                      _gradientHighColor.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                : null,
            color: _gradientFill ? null : lineColor.withValues(alpha: 0.15),
          ),
        ),
      );
    }

    debugPrint('[RENDERER] lineBarsData.length=${lineBarsData.length}');
    if (lineBarsData.isEmpty) {
      debugPrint('[RENDERER] WARNING: lineBarsData is EMPTY!');
      return const SizedBox.shrink();
    }

    // Log each line's spot count for debugging
    for (int i = 0; i < lineBarsData.length; i++) {
      debugPrint(
        '[RENDERER] lineBarsData[$i].spots.length=${lineBarsData[i].spots.length}',
      );
    }

    debugPrint(
      '[RENDERER] Building LineChart with ${lineBarsData.length} lines',
    );
    // Add padding to min/max
    if (globalMinY == double.infinity) globalMinY = 0;
    if (globalMaxY == double.negativeInfinity) globalMaxY = 100;
    final range = globalMaxY - globalMinY;
    final padding = range * 0.1;
    debugPrint(
      '[RENDERER] Y range before padding: min=$globalMinY, max=$globalMaxY, range=$range',
    );
    globalMinY -= padding;
    globalMaxY += padding;

    debugPrint('[RENDERER] Chart Y range: minY=$globalMinY, maxY=$globalMaxY');

    final interval = (globalMaxY - globalMinY) / 4;

    // Build extra horizontal lines (thresholds)
    final extraLines = _buildThresholdLines();

    final chart = LineChart(
      LineChartData(
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        lineBarsData: lineBarsData,
        minY: globalMinY,
        maxY: globalMaxY,
      ),
    );

    // Debug wrapper to see actual size constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint(
          '[RENDERER] LineChart constraints: w=${constraints.maxWidth}, h=${constraints.maxHeight}',
        );
        return chart;
      },
    );
  }

  Widget _buildStackedChart(
    List<String> paths,
    Map<String, List<double>> seriesData,
    List<String> colors,
  ) {
    if (_mergeMode == ChartMergeMode.stackedBar) {
      return _buildStackedBarChart(paths, seriesData, colors);
    }

    // Stacked area chart - compute cumulative values
    final int maxLen = seriesData.values.fold<int>(
      0,
      (a, b) => b.length > a ? b.length : a,
    );
    if (maxLen == 0) return const SizedBox.shrink();

    // Build cumulative data
    final cumulativeData = <List<double>>[];
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final data = seriesData[path] ?? [];
      final cumulative = List<double>.filled(maxLen, 0);

      for (int j = 0; j < maxLen; j++) {
        final baseValue = i > 0 ? cumulativeData[i - 1][j] : 0.0;
        final thisValue = j < data.length ? data[j] : 0.0;
        cumulative[j] = baseValue + thisValue;
      }
      cumulativeData.add(cumulative);
    }

    double globalMaxY = 0;
    for (final cum in cumulativeData) {
      final maxVal = cum.reduce((a, b) => a > b ? a : b);
      if (maxVal > globalMaxY) globalMaxY = maxVal;
    }

    // Build stacked area lines (bottom to top, so reverse order)
    final lineBarsData = <LineChartBarData>[];
    for (int i = paths.length - 1; i >= 0; i--) {
      Color lineColor;
      if (i < colors.length) {
        lineColor = StyleSchema.parseColor(colors[i]);
      } else {
        final defaultColors = [
          widget.accentColor,
          const Color(0xFF00BCD4),
          const Color(0xFFFF9800),
          const Color(0xFF4CAF50),
          const Color(0xFFE91E63),
          const Color(0xFF9C27B0),
        ];
        lineColor = defaultColors[i % defaultColors.length];
      }

      final spots = cumulativeData[i]
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList();

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: _isCurved,
          color: _gradientFill ? null : lineColor,
          gradient: _gradientFill
              ? LinearGradient(
                  colors: [_gradientLowColor, _gradientHighColor],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                )
              : null,
          barWidth: 1.5,
          isStrokeCapRound: true,
          dotData: FlDotData(show: _showDots),
          belowBarData: BarAreaData(
            show: true,
            gradient: _gradientFill
                ? LinearGradient(
                    colors: [
                      _gradientLowColor.withValues(alpha: 0.4),
                      _gradientHighColor.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                : null,
            color: _gradientFill ? null : lineColor.withValues(alpha: 0.6),
            cutOffY: 0,
            applyCutOffY: true,
          ),
        ),
      );
    }

    final extraLines = _buildThresholdLines();
    final interval = globalMaxY / 4;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        lineBarsData: lineBarsData,
        minY: 0,
        maxY: globalMaxY * 1.1,
      ),
    );
  }

  Widget _buildStackedBarChart(
    List<String> paths,
    Map<String, List<double>> seriesData,
    List<String> colors,
  ) {
    final int maxLen = seriesData.values.fold<int>(
      0,
      (a, b) => b.length > a ? b.length : a,
    );
    if (maxLen == 0) return const SizedBox.shrink();

    // Find max stacked value
    double globalMaxY = 0;
    for (int j = 0; j < maxLen; j++) {
      double stackTotal = 0;
      for (final path in paths) {
        final data = seriesData[path] ?? [];
        if (j < data.length) stackTotal += data[j].abs();
      }
      if (stackTotal > globalMaxY) globalMaxY = stackTotal;
    }

    final barGroups = <BarChartGroupData>[];
    for (int j = 0; j < maxLen; j++) {
      final rods = <BarChartRodStackItem>[];
      double fromY = 0;

      for (int i = 0; i < paths.length; i++) {
        final path = paths[i];
        final data = seriesData[path] ?? [];
        final value = j < data.length ? data[j].abs() : 0.0;

        Color barColor;
        if (i < colors.length) {
          barColor = StyleSchema.parseColor(colors[i]);
        } else {
          final defaultColors = [
            widget.accentColor,
            const Color(0xFF00BCD4),
            const Color(0xFFFF9800),
            const Color(0xFF4CAF50),
            const Color(0xFFE91E63),
            const Color(0xFF9C27B0),
          ];
          barColor = defaultColors[i % defaultColors.length];
        }

        rods.add(BarChartRodStackItem(fromY, fromY + value, barColor));
        fromY += value;
      }

      barGroups.add(
        BarChartGroupData(
          x: j,
          barRods: [
            BarChartRodData(
              toY: fromY,
              rodStackItems: rods,
              width: 6,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ],
        ),
      );
    }

    final interval = globalMaxY / 4;

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        barGroups: barGroups,
        maxY: globalMaxY * 1.1,
      ),
    );
  }

  Widget _buildSparkline(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: _isCurved,
            color: _gradientFill ? null : color,
            gradient: _gradientFill
                ? LinearGradient(
                    colors: [_gradientLowColor, _gradientHighColor],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                : null,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: _showDots,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 3,
                color: _gradientFill
                    ? _getGradientColor(spot.y, minY, maxY)
                    : color,
              ),
            ),
            belowBarData: _gradientFill
                ? BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        _gradientLowColor.withValues(alpha: 0.3),
                        _gradientHighColor.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  )
                : BarAreaData(show: false),
          ),
        ],
        minY: minY - 5,
        maxY: maxY + 5,
      ),
    );
  }

  Widget _buildBarChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final interval = (maxY - minY) / 4;

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
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
    debugPrint(
      '[RENDERER] _buildLineChart: data.length=${data.length}, color=$color',
    );
    if (data.isEmpty) {
      debugPrint(
        '[RENDERER] _buildLineChart: data is empty, returning SizedBox.shrink',
      );
      return const SizedBox.shrink();
    }

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final interval = (maxY - minY) / 4;
    final minMax = _showMinMax ? _getMinMax(data) : null;
    final baselineValue = _getBaselineValue(data);

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    // Build extra horizontal lines (thresholds + baseline)
    final extraLines = _buildThresholdLines();
    if (baselineValue != null) {
      extraLines.add(
        HorizontalLine(
          y: baselineValue,
          color: color.withValues(alpha: 0.5),
          strokeWidth: 1,
          dashArray: [3, 3],
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: _isCurved,
            color: _gradientFill ? null : color,
            gradient: _gradientFill
                ? LinearGradient(
                    colors: [_gradientLowColor, _gradientHighColor],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                : null,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: _showDots || _showMinMax,
              getDotPainter: (spot, percent, bar, index) {
                // Highlight min/max points
                if (_showMinMax && minMax != null) {
                  if (index == minMax.$1) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: _gradientLowColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                  if (index == minMax.$2) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: _gradientHighColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                }
                return FlDotCirclePainter(
                  radius: _showDots ? 3 : 0,
                  color: _gradientFill
                      ? _getGradientColor(spot.y, minY, maxY)
                      : color,
                );
              },
            ),
          ),
        ],
        minY: minY - (maxY - minY) * 0.1,
        maxY: maxY + (maxY - minY) * 0.1,
      ),
    );
  }

  Widget _buildAreaChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final interval = (maxY - minY) / 4;
    final minMax = _showMinMax ? _getMinMax(data) : null;
    final baselineValue = _getBaselineValue(data);

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    // Build extra horizontal lines (thresholds + baseline)
    final extraLines = _buildThresholdLines();
    if (baselineValue != null) {
      extraLines.add(
        HorizontalLine(
          y: baselineValue,
          color: color.withValues(alpha: 0.5),
          strokeWidth: 1,
          dashArray: [3, 3],
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: _isCurved,
            color: _gradientFill ? null : color,
            gradient: _gradientFill
                ? LinearGradient(
                    colors: [_gradientLowColor, _gradientHighColor],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  )
                : null,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: _showDots || _showMinMax,
              getDotPainter: (spot, percent, bar, index) {
                // Highlight min/max points
                if (_showMinMax && minMax != null) {
                  if (index == minMax.$1) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: _gradientLowColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                  if (index == minMax.$2) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: _gradientHighColor,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  }
                }
                return FlDotCirclePainter(
                  radius: _showDots ? 3 : 0,
                  color: _gradientFill
                      ? _getGradientColor(spot.y, minY, maxY)
                      : color,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: _gradientFill
                  ? LinearGradient(
                      colors: [
                        _gradientLowColor.withValues(alpha: 0.3),
                        _gradientHighColor.withValues(alpha: 0.3),
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    )
                  : null,
              color: _gradientFill ? null : color.withValues(alpha: 0.2),
            ),
          ),
        ],
        minY: minY - (maxY - minY) * 0.1,
        maxY: maxY + (maxY - minY) * 0.1,
      ),
    );
  }

  Widget _buildSteppedChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final interval = (maxY - minY) / 4;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: false,
          horizontalInterval: interval > 0 ? interval : 20,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false, // Stepped requires no curve
            color: color,
            barWidth: 2,
            isStrokeCapRound: false,
            lineChartStepData: const LineChartStepData(stepDirection: 0.5),
            dotData: FlDotData(
              show: _showDots,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(radius: 3, color: color),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.15),
            ),
          ),
        ],
        minY: minY - 5,
        maxY: maxY + 5,
      ),
    );
  }

  Widget _buildScatterChart(List<double> data, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();

    final spots = data.asMap().entries.map((e) {
      return ScatterSpot(
        e.key.toDouble(),
        e.value,
        dotPainter: FlDotCirclePainter(
          radius: 4,
          color: color,
          strokeWidth: 1,
          strokeColor: color.withValues(alpha: 0.5),
        ),
      );
    }).toList();

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);

    return ScatterChart(
      ScatterChartData(
        gridData: FlGridData(
          show: _showGrid,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppTheme.darkBorder, strokeWidth: 1),
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        scatterTouchData: ScatterTouchData(enabled: false),
        scatterSpots: spots,
        minY: minY - 5,
        maxY: maxY + 5,
        minX: 0,
        maxX: data.length.toDouble(),
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
