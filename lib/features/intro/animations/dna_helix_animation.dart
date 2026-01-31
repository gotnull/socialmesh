// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Rotating DNA helix double strand animation.
class DnaHelixAnimation extends StatefulWidget {
  const DnaHelixAnimation({super.key});

  @override
  State<DnaHelixAnimation> createState() => _DnaHelixAnimationState();
}

class _DnaHelixAnimationState extends State<DnaHelixAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
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
          painter: _DnaHelixPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _DnaHelixPainter extends CustomPainter {
  _DnaHelixPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final amplitude = size.width * 0.3;
    final time = progress * 2 * pi;

    // Draw connecting bars first (behind strands)
    const nodeCount = 30;
    const verticalSpacing = 35.0;

    for (var i = 0; i < nodeCount; i++) {
      final y = (i * verticalSpacing - time * 100) % (size.height + 100) - 50;
      final phase = i * 0.4 + time * 2;

      final x1 = centerX + cos(phase) * amplitude;
      final x2 = centerX + cos(phase + pi) * amplitude;

      // Z-depth based on sine
      final z1 = sin(phase);
      final z2 = sin(phase + pi);

      // Only draw bar if both ends visible
      if (z1 > -0.3 && z2 > -0.3) {
        final barAlpha = ((z1 + z2) / 2 + 1) / 2 * 0.5;

        // Colored bars like base pairs
        final colors = [
          const Color(0xFFFF0066),
          const Color(0xFF00FF66),
          const Color(0xFF6600FF),
          const Color(0xFFFFFF00),
        ];
        final barColor = colors[i % colors.length].withValues(alpha: barAlpha);

        final barPaint = Paint()
          ..color = barColor
          ..strokeWidth = 3;
        canvas.drawLine(Offset(x1, y), Offset(x2, y), barPaint);

        // Glow
        final glowPaint = Paint()
          ..color = barColor.withValues(alpha: barAlpha * 0.3)
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawLine(Offset(x1, y), Offset(x2, y), glowPaint);
      }
    }

    // Draw both strands
    _drawStrand(canvas, size, centerX, amplitude, time, 0);
    _drawStrand(canvas, size, centerX, amplitude, time, pi);
  }

  void _drawStrand(
    Canvas canvas,
    Size size,
    double centerX,
    double amplitude,
    double time,
    double phaseOffset,
  ) {
    final path = Path();
    const steps = 200;

    final points = <_HelixPoint>[];

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final y = t * (size.height + 100) - 50;
      final phase = t * 12 + time * 2 + phaseOffset;

      final x = centerX + cos(phase) * amplitude;
      final z = sin(phase);

      points.add(_HelixPoint(x, y, z));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw glow based on average depth
    final glowColor = phaseOffset == 0
        ? const Color(0xFF00FFFF)
        : const Color(0xFFFF00FF);

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // Draw main strand
    final paint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);

    // Draw nodes at intervals
    for (var i = 0; i < points.length; i += 10) {
      final p = points[i];
      final brightness = (p.z + 1) / 2;
      final nodeRadius = 6 + brightness * 4;

      final nodePaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white,
                glowColor,
                glowColor.withValues(alpha: 0.5),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(p.x, p.y), radius: nodeRadius),
            );
      canvas.drawCircle(Offset(p.x, p.y), nodeRadius, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DnaHelixPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _HelixPoint {
  _HelixPoint(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;
}
