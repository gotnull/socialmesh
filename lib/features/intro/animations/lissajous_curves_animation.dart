// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Classic sine wave interference pattern - Lissajous curves.
class LissajousCurvesAnimation extends StatefulWidget {
  const LissajousCurvesAnimation({super.key});

  @override
  State<LissajousCurvesAnimation> createState() =>
      _LissajousCurvesAnimationState();
}

class _LissajousCurvesAnimationState extends State<LissajousCurvesAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _LissajousCurvesPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _LissajousCurvesPainter extends CustomPainter {
  _LissajousCurvesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final amplitude = min(size.width, size.height) * 0.4;
    final time = progress * 2 * pi;

    // Draw multiple Lissajous curves with different parameters
    final curves = [
      (a: 3.0, b: 2.0, delta: time, color: const Color(0xFF00FFFF)),
      (
        a: 5.0,
        b: 4.0,
        delta: time * 0.7 + pi / 4,
        color: const Color(0xFFFF00FF),
      ),
      (
        a: 3.0,
        b: 4.0,
        delta: time * 0.5 + pi / 2,
        color: const Color(0xFFFFFF00),
      ),
      (a: 5.0, b: 6.0, delta: time * 0.3, color: const Color(0xFF00FF88)),
    ];

    for (final curve in curves) {
      final path = Path();
      const steps = 500;

      for (var i = 0; i <= steps; i++) {
        final t = (i / steps) * 2 * pi;
        final x = centerX + sin(curve.a * t + curve.delta) * amplitude;
        final y = centerY + sin(curve.b * t) * amplitude;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Glow effect
      final glowPaint = Paint()
        ..color = curve.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawPath(path, glowPaint);

      // Main line
      final paint = Paint()
        ..color = curve.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);
    }

    // Animated dot following one curve
    final dotT = progress * 2 * pi;
    final dotX = centerX + sin(3 * dotT + time) * amplitude;
    final dotY = centerY + sin(2 * dotT) * amplitude;

    final dotGlow = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(dotX, dotY), 15, dotGlow);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(dotX, dotY), 6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LissajousCurvesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
