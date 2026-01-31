// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Blivet / Devil's Fork - three prongs merging into two.
class BlivetAnimation extends StatefulWidget {
  const BlivetAnimation({super.key});

  @override
  State<BlivetAnimation> createState() => _BlivetAnimationState();
}

class _BlivetAnimationState extends State<BlivetAnimation>
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
          painter: _BlivetPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _BlivetPainter extends CustomPainter {
  _BlivetPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;
    final scale = min(size.width, size.height) * 0.4;

    // Gentle rotation
    final rotY = sin(time * 0.3) * 0.2;
    final rotX = cos(time * 0.2) * 0.1;

    // Draw background glow
    canvas.drawCircle(
      Offset(cx, cy),
      scale,
      Paint()
        ..color = Colors.purple.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    // The blivet: 3 cylindrical prongs at top, 2 rectangular bars at bottom
    _drawBlivet(canvas, cx, cy, scale, rotX, rotY, time);
  }

  void _drawBlivet(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    double rotX,
    double rotY,
    double time,
  ) {
    final prongSpacing = scale * 0.25;
    final prongRadius = scale * 0.06;
    final prongLength = scale * 0.8;
    final barWidth = scale * 0.08;

    // Colors
    final baseHue = (time * 20) % 360;

    // Draw three prongs at the top (cylindrical appearance)
    for (var i = -1; i <= 1; i++) {
      final prongX = cx + i * prongSpacing;
      final topY = cy - prongLength * 0.4;
      final bottomY = cy + prongLength * 0.1;

      // Prong hue
      final hue = (baseHue + i * 40 + 180) % 360;
      final prongColor = HSVColor.fromAHSV(1.0, hue, 0.7, 0.9).toColor();
      final shadowColor = HSVColor.fromAHSV(1.0, hue, 0.7, 0.5).toColor();

      // Draw cylindrical prong
      _drawCylinder(
        canvas,
        prongX,
        topY,
        prongX,
        bottomY,
        prongRadius,
        prongColor,
        shadowColor,
        rotY,
      );

      // Top cap
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(prongX + rotY * 5, topY),
          width: prongRadius * 2,
          height: prongRadius * 0.8,
        ),
        Paint()..color = prongColor,
      );

      // Cap highlight
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(prongX + rotY * 5 - prongRadius * 0.3, topY),
          width: prongRadius * 0.6,
          height: prongRadius * 0.3,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
    }

    // The impossible part: transition zone where 3 becomes 2
    final transitionTop = cy + prongLength * 0.1;
    final transitionBottom = cy + prongLength * 0.3;

    // Draw the transition zone with impossible geometry
    _drawImpossibleTransition(
      canvas,
      cx,
      transitionTop,
      transitionBottom,
      prongSpacing,
      prongRadius,
      barWidth,
      baseHue,
      time,
    );

    // Draw two rectangular bars at the bottom
    for (var i = -1; i <= 1; i += 2) {
      final barX = cx + i * prongSpacing * 0.5;
      final topY = transitionBottom;
      final bottomY = cy + prongLength * 0.5;

      final hue = (baseHue + i * 60 + 220) % 360;
      final barColor = HSVColor.fromAHSV(1.0, hue, 0.6, 0.85).toColor();
      final sideColor = HSVColor.fromAHSV(1.0, hue, 0.6, 0.6).toColor();

      // Main bar face
      final barPath = Path();
      barPath.addRect(
        Rect.fromLTWH(barX - barWidth, topY, barWidth * 2, bottomY - topY),
      );
      canvas.drawPath(barPath, Paint()..color = barColor);

      // Side face (3D effect)
      final sidePath = Path();
      final sideOffset = barWidth * 0.4;
      sidePath.moveTo(barX + barWidth, topY);
      sidePath.lineTo(barX + barWidth + sideOffset, topY - sideOffset * 0.5);
      sidePath.lineTo(barX + barWidth + sideOffset, bottomY - sideOffset * 0.5);
      sidePath.lineTo(barX + barWidth, bottomY);
      sidePath.close();
      canvas.drawPath(sidePath, Paint()..color = sideColor);

      // Bottom face
      final bottomPath = Path();
      bottomPath.moveTo(barX - barWidth, bottomY);
      bottomPath.lineTo(barX + barWidth, bottomY);
      bottomPath.lineTo(
        barX + barWidth + sideOffset,
        bottomY - sideOffset * 0.5,
      );
      bottomPath.lineTo(
        barX - barWidth + sideOffset,
        bottomY - sideOffset * 0.5,
      );
      bottomPath.close();
      canvas.drawPath(
        bottomPath,
        Paint()..color = HSVColor.fromAHSV(1.0, hue, 0.6, 0.4).toColor(),
      );

      // Edge highlights
      canvas.drawLine(
        Offset(barX - barWidth, topY),
        Offset(barX - barWidth, bottomY),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawCylinder(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    double radius,
    Color color,
    Color shadowColor,
    double rotY,
  ) {
    final offset = rotY * 10;

    // Cylinder body gradient effect
    final rect = Rect.fromPoints(
      Offset(x1 - radius + offset, y1),
      Offset(x2 + radius + offset, y2),
    );

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [shadowColor, color, color, shadowColor],
      stops: const [0.0, 0.3, 0.7, 1.0],
    );

    final paint = Paint()..shader = gradient.createShader(rect);

    canvas.drawRect(
      Rect.fromLTRB(x1 - radius + offset, y1, x1 + radius + offset, y2),
      paint,
    );

    // Highlight
    canvas.drawLine(
      Offset(x1 - radius * 0.5 + offset, y1),
      Offset(x1 - radius * 0.5 + offset, y2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 2,
    );
  }

  void _drawImpossibleTransition(
    Canvas canvas,
    double cx,
    double topY,
    double bottomY,
    double prongSpacing,
    double prongRadius,
    double barWidth,
    double baseHue,
    double time,
  ) {
    // This is where the magic happens - 3 prongs impossibly become 2 bars
    final transitionHeight = bottomY - topY;

    // Draw the impossible connecting geometry
    for (var i = -1; i <= 1; i++) {
      final prongX = cx + i * prongSpacing;

      // Determine which bar this prong connects to
      double targetX;
      if (i == 0) {
        // Middle prong - this is the impossible one
        // It appears to connect to BOTH bars depending on where you look
        final pulse = sin(time * 2) * 0.5 + 0.5;

        // Draw ambiguous connection
        final hue = (baseHue + 200) % 360;
        final color = HSVColor.fromAHSV(1.0, hue, 0.65, 0.75).toColor();

        // Left connection (fades based on pulse)
        final leftPath = Path();
        leftPath.moveTo(prongX - prongRadius, topY);
        leftPath.lineTo(cx - prongSpacing * 0.5 - barWidth, bottomY);
        leftPath.lineTo(cx - prongSpacing * 0.5 + barWidth, bottomY);
        leftPath.lineTo(prongX + prongRadius, topY);
        leftPath.close();

        canvas.drawPath(
          leftPath,
          Paint()..color = color.withValues(alpha: 0.5 + pulse * 0.3),
        );

        // Right connection (inverse fade)
        final rightPath = Path();
        rightPath.moveTo(prongX - prongRadius, topY);
        rightPath.lineTo(cx + prongSpacing * 0.5 - barWidth, bottomY);
        rightPath.lineTo(cx + prongSpacing * 0.5 + barWidth, bottomY);
        rightPath.lineTo(prongX + prongRadius, topY);
        rightPath.close();

        canvas.drawPath(
          rightPath,
          Paint()..color = color.withValues(alpha: 0.8 - pulse * 0.3),
        );
      } else {
        // Outer prongs connect to their respective bars
        targetX = cx + i * prongSpacing * 0.5;

        final hue = (baseHue + i * 40 + 180) % 360;
        final color = HSVColor.fromAHSV(1.0, hue, 0.65, 0.8).toColor();

        final path = Path();
        path.moveTo(prongX - prongRadius, topY);
        path.lineTo(targetX - barWidth, bottomY);
        path.lineTo(targetX + barWidth, bottomY);
        path.lineTo(prongX + prongRadius, topY);
        path.close();

        canvas.drawPath(path, Paint()..color = color);

        // Add depth shading
        final shadePath = Path();
        shadePath.moveTo(prongX + prongRadius, topY);
        shadePath.lineTo(targetX + barWidth, bottomY);
        shadePath.lineTo(
          targetX + barWidth * 1.3,
          bottomY - transitionHeight * 0.1,
        );
        shadePath.lineTo(prongX + prongRadius * 1.2, topY);
        shadePath.close();

        canvas.drawPath(
          shadePath,
          Paint()..color = HSVColor.fromAHSV(1.0, hue, 0.6, 0.5).toColor(),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BlivetPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
