import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';

/// Signal strength content widget - just the content without header wrapper
/// Used by DashboardWidget for consistent styling
class SignalStrengthContent extends ConsumerStatefulWidget {
  const SignalStrengthContent({super.key});

  @override
  ConsumerState<SignalStrengthContent> createState() =>
      SignalStrengthContentState();
}

class SignalStrengthContentState extends ConsumerState<SignalStrengthContent>
    with SingleTickerProviderStateMixin {
  final List<MultiSignalData> _signalHistory = [];
  Timer? _updateTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Smoothed values for animation
  double _displayRssi = -90.0;
  double _displaySnr = 0.0;
  double _displayChannelUtil = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _addDataPoint();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _addDataPoint();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _addDataPoint() {
    final rssiAsync = ref.read(currentRssiProvider);
    final snrAsync = ref.read(currentSnrProvider);
    final channelUtilAsync = ref.read(currentChannelUtilProvider);
    final now = DateTime.now();

    final rssiValue = rssiAsync.valueOrNull?.toDouble() ?? -90.0;
    final snrValue = snrAsync.valueOrNull ?? 0.0;
    final channelUtilValue = channelUtilAsync.valueOrNull ?? 0.0;

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

  Color _getSignalColor(double rssi) {
    if (rssi >= -60) return AppTheme.primaryGreen;
    if (rssi >= -75) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
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
        const Divider(color: AppTheme.darkBorder, height: 1),
        // Legend
        _buildLegend(),
        // Chart
        SizedBox(
          height: 180,
          child: hasData
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 16, 8),
                  child: CustomPaint(
                    painter: MultiLineChartPainter(_signalHistory),
                    child: Container(),
                  ),
                )
              : const Center(
                  child: Text(
                    'Waiting for signal data...',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 14,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSignalHeader(double rssi, double snr, double channelUtil) {
    final signalColor = _getSignalColor(rssi);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Animated signal indicator with pulse
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: signalColor.withValues(
                    alpha: 0.15 * _pulseAnimation.value,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: signalColor.withValues(
                        alpha: 0.2 * _pulseAnimation.value,
                      ),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedSignalIcon(rssi: rssi, color: signalColor),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: rssi, end: rssi),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, value, child) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: signalColor,
                            fontFamily: 'Inter',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          // Signal stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: signalColor,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${rssi.toInt()} dBm',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _AnimatedStatChip(
                      label: 'SNR',
                      value: snr,
                      unit: 'dB',
                      color: AppTheme.graphBlue,
                    ),
                    const SizedBox(width: 8),
                    _AnimatedStatChip(
                      label: 'ChUtil',
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
          _LegendItem(color: AppTheme.primaryGreen, label: 'RSSI'),
          const SizedBox(width: 16),
          _LegendItem(color: AppTheme.graphBlue, label: 'SNR'),
          const SizedBox(width: 16),
          _LegendItem(color: AppTheme.accentOrange, label: 'Ch Util'),
        ],
      ),
    );
  }
}

/// Animated signal icon that changes based on RSSI value
class _AnimatedSignalIcon extends StatelessWidget {
  final double rssi;
  final Color color;

  const _AnimatedSignalIcon({required this.rssi, required this.color});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * scale),
          child: Icon(Icons.signal_cellular_alt, color: color, size: 24),
        );
      },
    );
  }
}

/// Animated stat chip with smooth value transitions
class _AnimatedStatChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _AnimatedStatChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                '$label: ${animatedValue.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        );
      },
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
            fontFamily: 'Inter',
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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppTheme.textTertiary,
            fontFamily: 'Inter',
          ),
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

  static const Color rssiColor = AppTheme.primaryGreen;
  static const Color snrColor = AppTheme.graphBlue;
  static const Color channelUtilColor = AppTheme.accentOrange;

  MultiLineChartPainter(this.data);

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
      ..color = AppTheme.darkBorder.withValues(alpha: 0.3)
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
        style: const TextStyle(
          color: AppTheme.textTertiary,
          fontSize: 9,
          fontFamily: 'Inter',
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
          fontFamily: 'Inter',
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
