import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/reconnect_compass_providers.dart';

class ReconnectCompassBadge extends StatelessWidget {
  const ReconnectCompassBadge({
    super.key,
    required this.state,
    required this.color,
    this.size = 34,
  });

  final ReconnectCompassState state;
  final Color color;
  final double size;

  bool get _hasDirection =>
      state.headingAvailable &&
      state.currentHeadingDeg != null &&
      state.bestHeadingDeg != null;

  double get _relativeHeading => _normalizeDegrees(
    (state.bestHeadingDeg ?? 0) - (state.currentHeadingDeg ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    final needleTurns = _relativeHeading / 360;
    final signalStrength = (0.35 + 0.65 * (state.confidence.clamp(0.0, 1.0)))
        .clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: CompassRingPainter(color),
          ),
          if (_hasDirection)
            AnimatedRotation(
              duration: const Duration(milliseconds: 450),
              turns: needleTurns,
              child: _Needle(color: color.withOpacity(0.9), length: size * 0.5),
            )
          else
            Icon(
              Icons.explore_off_rounded,
              color: color.withOpacity(0.65),
              size: size * 0.42,
            ),
          if (_hasDirection) _CurrentHeadingMarker(state: state, color: color),
          Container(
            width: size * 0.2,
            height: size * 0.2,
            decoration: BoxDecoration(
              color: color.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
          ),
          Positioned(
            bottom: size * 0.08,
            child: _SignalBars(
              strength: signalStrength,
              level: _signalLevel(state.lastRssi),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static double _normalizeDegrees(double degrees) {
    return (degrees % 360 + 360) % 360;
  }

  static int _signalLevel(int? rssi) {
    if (rssi == null) return 0;
    if (rssi >= -60) return 3;
    if (rssi >= -70) return 2;
    if (rssi >= -80) return 1;
    return 0;
  }
}

class _Needle extends StatelessWidget {
  const _Needle({required this.color, required this.length});

  final Color color;
  final double length;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: length * 0.1,
        height: length,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}

class _CurrentHeadingMarker extends StatelessWidget {
  const _CurrentHeadingMarker({required this.state, required this.color});

  final ReconnectCompassState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final turns = ((state.currentHeadingDeg ?? 0) % 360) / 360;
    return Transform.rotate(
      angle: turns * 2 * math.pi,
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  const _SignalBars({
    required this.level,
    required this.color,
    required this.strength,
  });

  final int level;
  final Color color;
  final double strength;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        final barHeight = 4.0 + index * 3;
        final filled = index < level;
        return Container(
          width: 3,
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(filled ? strength : 0.25),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}

class CompassRingPainter extends CustomPainter {
  CompassRingPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 1;
    final fillPaint = Paint()..color = color.withOpacity(0.08);
    final strokePaint = Paint()
      ..color = color.withOpacity(0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final tickPaint = Paint()
      ..color = color.withOpacity(0.35)
      ..strokeWidth = 1;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    for (var angle = 0; angle < 360; angle += 30) {
      final rad = angle * math.pi / 180;
      final outer = center + Offset(math.cos(rad), math.sin(rad)) * radius;
      final inner =
          center +
          Offset(math.cos(rad), math.sin(rad)) *
              (radius - (angle % 90 == 0 ? 4 : 2.5));
      canvas.drawLine(inner, outer, tickPaint);
    }

    _paintCardinals(canvas, center, radius);
  }

  void _paintCardinals(Canvas canvas, Offset center, double radius) {
    const labels = ['N', 'E', 'S', 'W'];
    const alignments = [
      Alignment.topCenter,
      Alignment.centerRight,
      Alignment.bottomCenter,
      Alignment.centerLeft,
    ];
    final textStyle = TextStyle(
      color: color.withOpacity(0.8),
      fontSize: 7,
      fontWeight: FontWeight.w600,
    );

    for (var i = 0; i < labels.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final alignment = alignments[i];
      final offset = Offset(
        center.dx + alignment.x * (radius - 8) - painter.width / 2,
        center.dy + alignment.y * (radius - 8) - painter.height / 2,
      );
      painter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CompassRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
