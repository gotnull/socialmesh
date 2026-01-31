// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Impossible Penrose stairs - endlessly ascending/descending staircase.
class PenroseStairsAnimation extends StatefulWidget {
  const PenroseStairsAnimation({super.key});

  @override
  State<PenroseStairsAnimation> createState() => _PenroseStairsAnimationState();
}

class _PenroseStairsAnimationState extends State<PenroseStairsAnimation>
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
          painter: _PenroseStairsPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _PenroseStairsPainter extends CustomPainter {
  _PenroseStairsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;
    final scale = min(size.width, size.height) * 0.35;

    // Slow rotation for the structure
    final rotAngle = time * 0.3;

    // Draw the impossible staircase
    _drawPenroseStairs(canvas, cx, cy, scale, rotAngle, time);

    // Draw walking figures on the stairs
    _drawWalkers(canvas, cx, cy, scale, rotAngle, time);
  }

  void _drawPenroseStairs(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    double rot,
    double time,
  ) {
    const stepsPerSide = 6;
    const sides = 4;
    final stepHeight = scale * 0.08;
    final stepDepth = scale * 0.12;
    final stepWidth = scale * 0.25;

    // Each side of the square staircase
    for (var side = 0; side < sides; side++) {
      final sideAngle = (side / sides) * 2 * pi + rot;

      for (var step = 0; step < stepsPerSide; step++) {
        final stepProgress = step / stepsPerSide;

        // Calculate step position in isometric-like projection
        final baseAngle = sideAngle + stepProgress * (2 * pi / sides);

        // Position along the side
        final radius = scale * 0.6;
        final x = cx + cos(baseAngle) * radius;
        final y = cy + sin(baseAngle) * radius * 0.5; // Isometric compression

        // Height progression (the impossible part - always going up but connecting)
        final totalStep = side * stepsPerSide + step;
        final height = (totalStep % (sides * stepsPerSide)) * stepHeight * 0.3;

        // Color based on side and step
        final hue = ((side / sides) * 120 + 180 + time * 20) % 360;
        final brightness = 0.5 + stepProgress * 0.3;

        _drawStep(
          canvas,
          x,
          y - height,
          stepWidth,
          stepHeight,
          stepDepth,
          baseAngle,
          HSVColor.fromAHSV(1.0, hue, 0.6, brightness).toColor(),
        );
      }
    }

    // Draw the connecting impossible corners
    for (var corner = 0; corner < sides; corner++) {
      final cornerAngle = (corner / sides) * 2 * pi + rot + pi / sides;
      final radius = scale * 0.6;
      final x = cx + cos(cornerAngle) * radius * 1.1;
      final y = cy + sin(cornerAngle) * radius * 0.55;

      final cornerHue = (corner * 90 + 200 + time * 20) % 360;
      final cornerColor = HSVColor.fromAHSV(1.0, cornerHue, 0.5, 0.7).toColor();

      // Corner pillar
      final pillarPaint = Paint()
        ..color = cornerColor
        ..style = PaintingStyle.fill;

      final pillarPath = Path();
      final pillarWidth = stepWidth * 0.3;
      final pillarHeight = scale * 0.4;

      pillarPath.moveTo(x - pillarWidth / 2, y);
      pillarPath.lineTo(x + pillarWidth / 2, y);
      pillarPath.lineTo(x + pillarWidth / 2, y - pillarHeight);
      pillarPath.lineTo(x - pillarWidth / 2, y - pillarHeight);
      pillarPath.close();

      canvas.drawPath(pillarPath, pillarPaint);

      // Pillar outline
      canvas.drawPath(
        pillarPath,
        Paint()
          ..color = cornerColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawStep(
    Canvas canvas,
    double x,
    double y,
    double width,
    double height,
    double depth,
    double angle,
    Color color,
  ) {
    // Top surface
    final topPath = Path();
    final dx = cos(angle + pi / 2) * width / 2;
    final dy = sin(angle + pi / 2) * width / 4;
    final ddx = cos(angle) * depth;
    final ddy = sin(angle) * depth / 2;

    topPath.moveTo(x - dx, y - dy);
    topPath.lineTo(x + dx, y + dy);
    topPath.lineTo(x + dx + ddx, y + dy - ddy);
    topPath.lineTo(x - dx + ddx, y - dy - ddy);
    topPath.close();

    final topPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(topPath, topPaint);

    // Front face
    final frontPath = Path();
    frontPath.moveTo(x - dx, y - dy);
    frontPath.lineTo(x + dx, y + dy);
    frontPath.lineTo(x + dx, y + dy + height);
    frontPath.lineTo(x - dx, y - dy + height);
    frontPath.close();

    final frontPaint = Paint()
      ..color = HSVColor.fromColor(color).withValue(0.6).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawPath(frontPath, frontPaint);

    // Side face
    final sidePath = Path();
    sidePath.moveTo(x + dx, y + dy);
    sidePath.lineTo(x + dx + ddx, y + dy - ddy);
    sidePath.lineTo(x + dx + ddx, y + dy - ddy + height);
    sidePath.lineTo(x + dx, y + dy + height);
    sidePath.close();

    final sidePaint = Paint()
      ..color = HSVColor.fromColor(color).withValue(0.4).toColor()
      ..style = PaintingStyle.fill;
    canvas.drawPath(sidePath, sidePaint);

    // Outlines
    final outlinePaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(topPath, outlinePaint);
    canvas.drawPath(frontPath, outlinePaint);
    canvas.drawPath(sidePath, outlinePaint);
  }

  void _drawWalkers(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    double rot,
    double time,
  ) {
    const walkerCount = 3;
    final radius = scale * 0.6;

    for (var i = 0; i < walkerCount; i++) {
      final walkerProgress = (time * 0.5 + i / walkerCount) % 1.0;
      final angle = walkerProgress * 2 * pi + rot;

      final x = cx + cos(angle) * radius;
      final baseY = cy + sin(angle) * radius * 0.5;

      // Bobbing motion for walking
      final bob = sin(time * 8 + i * 2) * 2;
      final y = baseY - scale * 0.15 + bob;

      // Walker color
      final hue = (i * 120 + time * 30) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.9, 0.9).toColor();

      // Simple stick figure
      final headRadius = scale * 0.02;

      // Head with glow
      canvas.drawCircle(
        Offset(x, y - scale * 0.06),
        headRadius * 2,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        Offset(x, y - scale * 0.06),
        headRadius,
        Paint()..color = color,
      );

      // Body
      canvas.drawLine(
        Offset(x, y - scale * 0.04),
        Offset(x, y + scale * 0.02),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );

      // Legs with walking animation
      final legSwing = sin(time * 10 + i * 2) * scale * 0.02;
      canvas.drawLine(
        Offset(x, y + scale * 0.02),
        Offset(x - legSwing, y + scale * 0.05),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        Offset(x, y + scale * 0.02),
        Offset(x + legSwing, y + scale * 0.05),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PenroseStairsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
