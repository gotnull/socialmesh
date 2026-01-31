// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Kaleidoscope pattern animation with symmetry.
class KaleidoscopeAnimation extends StatefulWidget {
  const KaleidoscopeAnimation({super.key});

  @override
  State<KaleidoscopeAnimation> createState() => _KaleidoscopeAnimationState();
}

class _KaleidoscopeAnimationState extends State<KaleidoscopeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
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
          painter: _KaleidoscopePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _KaleidoscopePainter extends CustomPainter {
  _KaleidoscopePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = sqrt(centerX * centerX + centerY * centerY);
    final time = progress * 2 * pi;

    // Number of mirror segments
    const segments = 12;
    final segmentAngle = 2 * pi / segments;

    // Draw mirrored pattern
    for (var seg = 0; seg < segments; seg++) {
      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(seg * segmentAngle);

      // Mirror every other segment
      if (seg % 2 == 1) {
        canvas.scale(1, -1);
      }

      // Clip to segment
      final clipPath = Path()
        ..moveTo(0, 0)
        ..lineTo(maxRadius * cos(0), maxRadius * sin(0))
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: maxRadius),
          0,
          segmentAngle,
          false,
        )
        ..close();
      canvas.clipPath(clipPath);

      // Draw shapes within segment
      _drawPatternShapes(canvas, maxRadius, time, seg);

      canvas.restore();
    }

    // Center mandala
    for (var ring = 0; ring < 5; ring++) {
      final ringRadius = 20.0 + ring * 25;
      final petals = 6 + ring * 2;

      for (var p = 0; p < petals; p++) {
        final angle = (p / petals) * 2 * pi + time * (ring % 2 == 0 ? 1 : -1);
        final petalX = centerX + cos(angle) * ringRadius;
        final petalY = centerY + sin(angle) * ringRadius;

        final hue = (ring * 60 + p * 30 + progress * 360) % 360;
        final color = HSVColor.fromAHSV(0.8, hue, 0.8, 0.9).toColor();

        final petalPaint = Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawCircle(Offset(petalX, petalY), 8.0 - ring, petalPaint);
      }
    }
  }

  void _drawPatternShapes(
    Canvas canvas,
    double maxRadius,
    double time,
    int segment,
  ) {
    final random = Random(42); // Fixed seed for consistent pattern

    // Flowing curves
    for (var i = 0; i < 5; i++) {
      final baseAngle = random.nextDouble() * 0.4;
      final baseRadius = random.nextDouble() * maxRadius * 0.8 + 50;
      final hue = (segment * 30 + i * 60 + progress * 360) % 360;
      final color = HSVColor.fromAHSV(0.7, hue, 0.8, 0.9).toColor();

      final path = Path();
      for (var t = 0.0; t <= 1.0; t += 0.02) {
        final angle = baseAngle + sin(t * 4 + time * 2) * 0.2;
        final radius = baseRadius + sin(t * 6 + time * 3 + i) * 30;
        final x = cos(angle) * radius * t;
        final y = sin(angle) * radius * t;

        if (t == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawPath(path, glowPaint);
    }

    // Floating dots
    for (var i = 0; i < 8; i++) {
      final angle = random.nextDouble() * 0.5;
      final radius = random.nextDouble() * maxRadius * 0.7 + 30;
      final pulseOffset = random.nextDouble() * 2 * pi;

      final x = cos(angle) * (radius + sin(time * 2 + pulseOffset) * 20);
      final y = sin(angle) * (radius + sin(time * 2 + pulseOffset) * 20);

      final hue = (i * 45 + progress * 360) % 360;
      final dotColor = HSVColor.fromAHSV(0.9, hue, 0.7, 1.0).toColor();

      final dotPaint = Paint()
        ..color = dotColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _KaleidoscopePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
