// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/flip_3d_text.dart';
import '../../../providers/app_providers.dart';

/// Signal strength content widget - just the content without header wrapper
/// Used by DashboardWidget for consistent styling
class SignalStrengthContent extends ConsumerStatefulWidget {
  const SignalStrengthContent({super.key});

  @override
  ConsumerState<SignalStrengthContent> createState() =>
      SignalStrengthContentState();
}

class SignalStrengthContentState extends ConsumerState<SignalStrengthContent> {
  final List<MultiSignalData> _signalHistory = [];
  Timer? _updateTimer;

  // Smoothed values for animation
  double _displayRssi = -90.0;
  double _displaySnr = 0.0;
  double _displayChannelUtil = 0.0;

  @override
  void initState() {
    super.initState();
    _addDataPoint();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _addDataPoint();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _addDataPoint() {
    // Use watch-like behavior by listening to provider values
    // Note: We use read here since this is called from a Timer, but the providers
    // are also watched in build() to trigger rebuilds when values change
    final rssiAsync = ref.read(currentRssiProvider);
    final snrAsync = ref.read(currentSnrProvider);
    final channelUtilAsync = ref.read(currentChannelUtilProvider);
    final now = DateTime.now();

    final rssiValue = rssiAsync.value?.toDouble() ?? -90.0;
    final snrValue = snrAsync.value ?? 0.0;
    final channelUtilValue = channelUtilAsync.value ?? 0.0;

    _signalHistory.add(
      MultiSignalData(
        time: now,
        rssi: rssiValue,
        snr: snrValue,
        channelUtil: channelUtilValue,
      ),
    );
    if (_signalHistory.length > 30) _signalHistory.removeAt(0);

    // Update display values for smooth animation
    setState(() {
      _displayRssi = rssiValue;
      _displaySnr = snrValue;
      _displayChannelUtil = channelUtilValue;
    });
  }

  String _getSignalQuality(double rssi) {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Very Good';
    if (rssi >= -70) return 'Good';
    if (rssi >= -80) return 'Fair';
    if (rssi >= -90) return 'Weak';
    return 'Poor';
  }

  /// Convert RSSI to a percentage (0-100%)
  /// -30 dBm = 100% (excellent)
  /// -90 dBm = 0% (very weak)
  double _getSignalPercentage(double rssi) {
    // Clamp RSSI between -90 and -30
    final clampedRssi = rssi.clamp(-90.0, -30.0);
    // Convert to percentage (linear interpolation)
    return ((clampedRssi + 90) / 60 * 100).clamp(0.0, 100.0);
  }

  Color _getSignalColor(double rssi) {
    if (rssi >= -60) return context.accentColor;
    if (rssi >= -75) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    // Watch providers to trigger rebuilds when data changes
    final rssiAsync = ref.watch(currentRssiProvider);
    final snrAsync = ref.watch(currentSnrProvider);
    final channelUtilAsync = ref.watch(currentChannelUtilProvider);

    // Update display values when provider data changes
    final rssiValue = rssiAsync.value?.toDouble() ?? -90.0;
    final snrValue = snrAsync.value ?? 0.0;
    final channelUtilValue = channelUtilAsync.value ?? 0.0;

    // Update smoothed values if they've changed significantly
    if ((rssiValue - _displayRssi).abs() > 0.5 ||
        (snrValue - _displaySnr).abs() > 0.5 ||
        (channelUtilValue - _displayChannelUtil).abs() > 0.5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _displayRssi = rssiValue;
            _displaySnr = snrValue;
            _displayChannelUtil = channelUtilValue;
          });
        }
      });
    }

    final hasData = _signalHistory.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with current signal info - animated
        TweenAnimationBuilder<double>(
          tween: Tween(begin: _displayRssi, end: _displayRssi),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, rssi, child) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: _displaySnr, end: _displaySnr),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, snr, child) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: _displayChannelUtil,
                    end: _displayChannelUtil,
                  ),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  builder: (context, channelUtil, child) {
                    return _buildSignalHeader(rssi, snr, channelUtil);
                  },
                );
              },
            );
          },
        ),
        Divider(color: context.border, height: 1),
        // Legend
        _buildLegend(),
        // Chart
        SizedBox(
          height: 180,
          child: hasData
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                  child: CustomPaint(
                    painter: MultiLineChartPainter(
                      _signalHistory,
                      rssiColor: context.accentColor,
                      borderColor: context.border,
                      textTertiaryColor: context.textTertiary,
                    ),
                    child: Container(),
                  ),
                )
              : Center(
                  child: Text(
                    'Waiting for signal data...',
                    style: TextStyle(color: context.textTertiary, fontSize: 14),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSignalHeader(double rssi, double snr, double channelUtil) {
    final signalColor = _getSignalColor(rssi);
    final signalPercentage = _getSignalPercentage(rssi);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          // 3D Percentage display - minimalistic version
          Flip3DPercentageMinimal(
            value: signalPercentage,
            label: 'SIGNAL',
            color: signalColor,
            size: Flip3DSize.medium,
          ),
          const SizedBox(width: 12),
          // Signal stats column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.2),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _getSignalQuality(rssi),
                    key: ValueKey(_getSignalQuality(rssi)),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: signalColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${rssi.toInt()} dBm',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _CompactStatChip(
                      label: 'SNR',
                      value: snr,
                      unit: 'dB',
                      color: AppTheme.graphBlue,
                    ),
                    const SizedBox(width: 6),
                    _CompactStatChip(
                      label: 'Ch',
                      value: channelUtil,
                      unit: '%',
                      color: AppTheme.accentOrange,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _LegendItem(color: context.accentColor, label: 'RSSI'),
          const SizedBox(width: 16),
          _LegendItem(color: AppTheme.graphBlue, label: 'SNR'),
          const SizedBox(width: 16),
          _LegendItem(color: AppTheme.accentOrange, label: 'Ch Util'),
        ],
      ),
    );
  }
}

/// Compact stat chip - no dot indicator, tighter spacing
class _CompactStatChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _CompactStatChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(1)}$unit',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

/// Static LIVE indicator builder for use with DashboardWidget trailing
Widget buildLiveIndicator() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppTheme.errorRed.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppTheme.errorRed,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.errorRed.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          'LIVE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.errorRed,

            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.textTertiary),
        ),
      ],
    );
  }
}

/// Data point for multi-line signal chart
class MultiSignalData {
  final DateTime time;
  final double rssi;
  final double snr;
  final double channelUtil;

  MultiSignalData({
    required this.time,
    required this.rssi,
    required this.snr,
    required this.channelUtil,
  });
}

/// Custom painter for multi-line chart
class MultiLineChartPainter extends CustomPainter {
  final List<MultiSignalData> data;
  final Color rssiColor;
  final Color borderColor;
  final Color textTertiaryColor;

  static const Color snrColor = AppTheme.graphBlue;
  static const Color channelUtilColor = AppTheme.accentOrange;

  MultiLineChartPainter(
    this.data, {
    required this.rssiColor,
    required this.borderColor,
    required this.textTertiaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftInset = 42.0;
    const bottomInset = 20.0;
    const topInset = 4.0;
    const rightInset = 40.0;

    final chartWidth = size.width - leftInset - rightInset;
    final chartHeight = size.height - topInset - bottomInset;

    const double minRssi = -100;
    const double maxRssi = -30;
    const double minSnr = -20;
    const double maxSnr = 20;
    const double minChannelUtil = 0;
    const double maxChannelUtil = 100;

    final Paint gridPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw grid
    for (int i = 0; i <= 4; i++) {
      final y = topInset + (chartHeight * (i / 4));
      canvas.drawLine(
        Offset(leftInset, y),
        Offset(leftInset + chartWidth, y),
        gridPaint,
      );

      final rssiValue = maxRssi - (i * (maxRssi - minRssi) / 4);
      textPainter.text = TextSpan(
        text: '${rssiValue.toInt()}',
        style: TextStyle(
          color: textTertiaryColor,
          fontSize: 9,

          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftInset - textPainter.width - 6, y - 5),
      );

      final utilValue =
          maxChannelUtil - (i * (maxChannelUtil - minChannelUtil) / 4);
      textPainter.text = TextSpan(
        text: '${utilValue.toInt()}%',
        style: const TextStyle(
          color: channelUtilColor,
          fontSize: 9,

          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(leftInset + chartWidth + 6, y - 5));
    }

    if (data.length < 2) return;

    final stepX = chartWidth / (data.length - 1);

    // Draw lines
    _drawLine(
      canvas,
      data.map((d) => d.rssi).toList(),
      minRssi,
      maxRssi,
      rssiColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      showFill: true,
    );

    _drawLine(
      canvas,
      data
          .map(
            (d) => _normalizeToScale(d.snr, minSnr, maxSnr, minRssi, maxRssi),
          )
          .toList(),
      minRssi,
      maxRssi,
      snrColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      showFill: false,
    );

    _drawLine(
      canvas,
      data
          .map(
            (d) => _normalizeToScale(
              d.channelUtil,
              minChannelUtil,
              maxChannelUtil,
              minRssi,
              maxRssi,
            ),
          )
          .toList(),
      minRssi,
      maxRssi,
      channelUtilColor,
      leftInset,
      topInset,
      chartWidth,
      chartHeight,
      stepX,
      showFill: false,
      dashed: true,
    );

    // Draw dots
    _drawDot(
      canvas,
      data.last.rssi,
      minRssi,
      maxRssi,
      rssiColor,
      leftInset,
      topInset,
      chartHeight,
      stepX,
      data.length - 1,
    );
    _drawDot(
      canvas,
      _normalizeToScale(data.last.snr, minSnr, maxSnr, minRssi, maxRssi),
      minRssi,
      maxRssi,
      snrColor,
      leftInset,
      topInset,
      chartHeight,
      stepX,
      data.length - 1,
    );
    _drawDot(
      canvas,
      _normalizeToScale(
        data.last.channelUtil,
        minChannelUtil,
        maxChannelUtil,
        minRssi,
        maxRssi,
      ),
      minRssi,
      maxRssi,
      channelUtilColor,
      leftInset,
      topInset,
      chartHeight,
      stepX,
      data.length - 1,
    );
  }

  double _normalizeToScale(
    double value,
    double minValue,
    double maxValue,
    double targetMin,
    double targetMax,
  ) {
    final normalized = (value - minValue) / (maxValue - minValue);
    return targetMin + normalized * (targetMax - targetMin);
  }

  void _drawLine(
    Canvas canvas,
    List<double> values,
    double minValue,
    double maxValue,
    Color color,
    double leftInset,
    double topInset,
    double chartWidth,
    double chartHeight,
    double stepX, {
    bool showFill = false,
    bool dashed = false,
  }) {
    Path path = Path();
    Path fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = leftInset + (i * stepX);
      final value = values[i].clamp(minValue, maxValue);
      final y =
          topInset +
          chartHeight -
          ((value - minValue) / (maxValue - minValue)) * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
        if (showFill) {
          fillPath.moveTo(x, topInset + chartHeight);
          fillPath.lineTo(x, y);
        }
      } else {
        final prevX = leftInset + ((i - 1) * stepX);
        final prevValue = values[i - 1].clamp(minValue, maxValue);
        final prevY =
            topInset +
            chartHeight -
            ((prevValue - minValue) / (maxValue - minValue)) * chartHeight;

        final controlX1 = prevX + (x - prevX) / 2;
        final controlX2 = prevX + (x - prevX) / 2;

        path.cubicTo(controlX1, prevY, controlX2, y, x, y);
        if (showFill) {
          fillPath.cubicTo(controlX1, prevY, controlX2, y, x, y);
        }
      }
    }

    if (showFill) {
      fillPath.lineTo(leftInset + chartWidth, topInset + chartHeight);
      fillPath.close();

      final Paint fillPaint = Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.2),
                color.withValues(alpha: 0.05),
                color.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromLTWH(leftInset, topInset, chartWidth, chartHeight),
            );

      canvas.drawPath(fillPath, fillPaint);
    }

    // Glow
    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(path, glowPaint);

    // Line
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (dashed) {
      _drawDashedPath(canvas, path, linePaint);
    } else {
      canvas.drawPath(path, linePaint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      bool draw = true;
      const dashLength = 6.0;
      const gapLength = 4.0;

      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        if (draw) {
          final extractedPath = metric.extractPath(distance, distance + length);
          canvas.drawPath(extractedPath, paint);
        }
        distance += length;
        draw = !draw;
      }
    }
  }

  void _drawDot(
    Canvas canvas,
    double value,
    double minValue,
    double maxValue,
    Color color,
    double leftInset,
    double topInset,
    double chartHeight,
    double stepX,
    int index,
  ) {
    final x = leftInset + (index * stepX);
    final clampedValue = value.clamp(minValue, maxValue);
    final y =
        topInset +
        chartHeight -
        ((clampedValue - minValue) / (maxValue - minValue)) * chartHeight;

    canvas.drawCircle(
      Offset(x, y),
      6,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    canvas.drawCircle(
      Offset(x, y),
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(x, y),
      2.5,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
