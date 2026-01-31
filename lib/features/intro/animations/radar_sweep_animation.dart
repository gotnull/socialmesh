// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Looping radar sweep animation with rotating beam and blips.
class RadarSweepAnimation extends StatefulWidget {
  const RadarSweepAnimation({super.key});

  @override
  State<RadarSweepAnimation> createState() => _RadarSweepAnimationState();
}

class _RadarSweepAnimationState extends State<RadarSweepAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_RadarBlip> _blips = [];
  final Random _random = Random();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  void _generateBlips(Size size) {
    if (_initialized) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;

    const blipCount = 8;
    for (var i = 0; i < blipCount; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = 0.3 + _random.nextDouble() * 0.7;
      _blips.add(
        _RadarBlip(
          position:
              center +
              Offset(
                cos(angle) * maxRadius * distance,
                sin(angle) * maxRadius * distance,
              ),
          angle: angle,
          size: 3.0 + _random.nextDouble() * 4.0,
        ),
      );
    }

    _initialized = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _generateBlips(size);

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _RadarSweepPainter(
                progress: _controller.value,
                blips: _blips,
              ),
              size: size,
            );
          },
        );
      },
    );
  }
}

class _RadarBlip {
  _RadarBlip({required this.position, required this.angle, required this.size});

  final Offset position;
  final double angle;
  final double size;
}

class _RadarSweepPainter extends CustomPainter {
  _RadarSweepPainter({required this.progress, required this.blips});

  final double progress;
  final List<_RadarBlip> blips;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;
    const accentColor = Color(0xFF00E5FF);
    const gridColor = Color(0xFF1A3A4A);

    // Grid circles
    for (var i = 1; i <= 4; i++) {
      final radius = maxRadius * i / 4;
      final gridPaint = Paint()
        ..color = gridColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius, gridPaint);
    }

    // Grid lines
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final linePaint = Paint()
        ..color = gridColor.withValues(alpha: 0.2)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        center,
        center + Offset(cos(angle) * maxRadius, sin(angle) * maxRadius),
        linePaint,
      );
    }

    // Sweep beam
    final sweepAngle = progress * 2 * pi;
    final sweepPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: maxRadius),
        sweepAngle - 0.5,
        0.5,
        false,
      )
      ..close();

    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: sweepAngle - 0.5,
      endAngle: sweepAngle,
      colors: [
        accentColor.withValues(alpha: 0.0),
        accentColor.withValues(alpha: 0.3),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    final sweepPaint = Paint()..shader = sweepGradient;
    canvas.drawPath(sweepPath, sweepPaint);

    // Sweep line
    final lineEnd =
        center + Offset(cos(sweepAngle), sin(sweepAngle)) * maxRadius;
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.6)
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawLine(center, lineEnd, linePaint);

    // Blips
    for (final blip in blips) {
      var angleDiff = (sweepAngle - blip.angle) % (2 * pi);
      if (angleDiff < 0) angleDiff += 2 * pi;

      final blipAlpha = angleDiff < pi ? (1.0 - angleDiff / pi) * 0.8 : 0.0;

      if (blipAlpha > 0.05) {
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: blipAlpha * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(blip.position, blip.size + 4, glowPaint);

        final blipPaint = Paint()
          ..color = accentColor.withValues(alpha: blipAlpha);
        canvas.drawCircle(blip.position, blip.size, blipPaint);
      }
    }

    // Center dot
    final centerPaint = Paint()..color = accentColor.withValues(alpha: 0.8);
    canvas.drawCircle(center, 4, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
