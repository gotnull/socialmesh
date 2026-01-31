// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Freemish Crate - impossible wooden crate with paradoxical bars.
class FreemishCrateAnimation extends StatefulWidget {
  const FreemishCrateAnimation({super.key});

  @override
  State<FreemishCrateAnimation> createState() => _FreemishCrateAnimationState();
}

class _FreemishCrateAnimationState extends State<FreemishCrateAnimation>
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
          painter: _FreemishCratePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FreemishCratePainter extends CustomPainter {
  _FreemishCratePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;
    final scale = min(size.width, size.height) * 0.35;

    // Slow rotation
    final rotY = time * 0.3;
    final rotX = sin(time * 0.2) * 0.15;

    // Background glow
    canvas.drawCircle(
      Offset(cx, cy),
      scale * 1.2,
      Paint()
        ..color = Colors.amber.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );

    // Draw the impossible crate
    _drawFreemishCrate(canvas, cx, cy, scale, rotX, rotY, time);
  }

  void _drawFreemishCrate(
    Canvas canvas,
    double cx,
    double cy,
    double scale,
    double rotX,
    double rotY,
    double time,
  ) {
    final barThickness = scale * 0.08;
    final crateSize = scale * 0.8;

    // Wood colors
    final baseHue = 30.0; // Wood brown
    final lightWood = HSVColor.fromAHSV(1.0, baseHue, 0.6, 0.8).toColor();
    final midWood = HSVColor.fromAHSV(1.0, baseHue, 0.7, 0.6).toColor();
    final darkWood = HSVColor.fromAHSV(1.0, baseHue, 0.8, 0.4).toColor();

    // Isometric offsets
    final isoX = cos(rotY) * 0.5;
    final isoY = sin(rotY) * 0.3 + rotX;

    // The crate has horizontal bars on two opposite faces
    // and vertical bars on the other two - but they connect impossibly

    // Draw back vertical bars first
    for (var i = 0; i < 3; i++) {
      final barX = cx - crateSize * 0.35 + i * crateSize * 0.35;
      final offsetX = barX + isoX * crateSize * 0.3;

      _drawBar(
        canvas,
        offsetX,
        cy - crateSize * 0.4,
        offsetX,
        cy + crateSize * 0.4,
        barThickness,
        darkWood,
        midWood,
        true,
      );
    }

    // Draw horizontal bars on sides (creating the impossibility)
    for (var i = 0; i < 3; i++) {
      final barY = cy - crateSize * 0.35 + i * crateSize * 0.35;

      // Left side horizontal bar
      _drawBar(
        canvas,
        cx - crateSize * 0.4 + isoX * crateSize * 0.2,
        barY + isoY * crateSize * 0.2,
        cx - crateSize * 0.1,
        barY,
        barThickness,
        midWood,
        lightWood,
        false,
      );

      // Right side horizontal bar
      _drawBar(
        canvas,
        cx + crateSize * 0.1,
        barY,
        cx + crateSize * 0.4 + isoX * crateSize * 0.2,
        barY + isoY * crateSize * 0.2,
        barThickness,
        lightWood,
        midWood,
        false,
      );
    }

    // Draw front vertical bars (these create the impossible intersection)
    for (var i = 0; i < 3; i++) {
      final barX = cx - crateSize * 0.35 + i * crateSize * 0.35;

      // Draw with impossible crossings
      _drawImpossibleVerticalBar(
        canvas,
        barX,
        cy - crateSize * 0.4,
        cy + crateSize * 0.4,
        barThickness,
        lightWood,
        midWood,
        i,
        time,
        crateSize,
        cy,
      );
    }

    // Add wood grain texture effect
    _drawWoodGrain(canvas, cx, cy, crateSize, time);

    // Corner joints with nails
    _drawCornerJoints(canvas, cx, cy, crateSize, barThickness, time);
  }

  void _drawBar(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    double thickness,
    Color color1,
    Color color2,
    bool isVertical,
  ) {
    final path = Path();

    if (isVertical) {
      path.addRect(Rect.fromLTWH(x1 - thickness / 2, y1, thickness, y2 - y1));
    } else {
      // Parallelogram for perspective
      path.moveTo(x1 - thickness / 2, y1 - thickness / 2);
      path.lineTo(x2 - thickness / 2, y2 - thickness / 2);
      path.lineTo(x2 + thickness / 2, y2 + thickness / 2);
      path.lineTo(x1 + thickness / 2, y1 + thickness / 2);
      path.close();
    }

    // Gradient for 3D effect
    final gradient = LinearGradient(
      begin: isVertical ? Alignment.centerLeft : Alignment.topCenter,
      end: isVertical ? Alignment.centerRight : Alignment.bottomCenter,
      colors: [color1, color2, color1],
    );

    final rect = Rect.fromPoints(Offset(x1, y1), Offset(x2, y2));
    canvas.drawPath(path, Paint()..shader = gradient.createShader(rect));

    // Edge highlight
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawImpossibleVerticalBar(
    Canvas canvas,
    double x,
    double topY,
    double bottomY,
    double thickness,
    Color lightColor,
    Color darkColor,
    int barIndex,
    double time,
    double crateSize,
    double cy,
  ) {
    // The impossible part: bar appears to go behind horizontal bars
    // at the top but in front at the bottom (or vice versa)

    final segments = 5;
    final segmentHeight = (bottomY - topY) / segments;

    for (var s = 0; s < segments; s++) {
      final segTop = topY + s * segmentHeight;

      // Alternate which layer the bar appears on
      final isInFront = (s + barIndex) % 2 == 0;
      final alpha = isInFront ? 1.0 : 0.7;

      final color = isInFront ? lightColor : darkColor;

      final path = Path();
      path.addRect(
        Rect.fromLTWH(x - thickness / 2, segTop, thickness, segmentHeight),
      );

      canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));

      // Add a slight offset for the "behind" segments to enhance the illusion
      if (!isInFront) {
        canvas.drawRect(
          Rect.fromLTWH(
            x - thickness / 2 + 2,
            segTop,
            thickness,
            segmentHeight,
          ),
          Paint()..color = darkColor.withValues(alpha: 0.3),
        );
      }
    }
  }

  void _drawWoodGrain(
    Canvas canvas,
    double cx,
    double cy,
    double crateSize,
    double time,
  ) {
    final grainPaint = Paint()
      ..color = Colors.brown.withValues(alpha: 0.1)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final random = Random(42); // Fixed seed for consistent grain

    for (var i = 0; i < 30; i++) {
      final x = cx + (random.nextDouble() - 0.5) * crateSize * 0.8;
      final y = cy + (random.nextDouble() - 0.5) * crateSize * 0.8;
      final length = random.nextDouble() * 20 + 10;
      final curve = random.nextDouble() * 0.3;

      final path = Path();
      path.moveTo(x, y);
      path.quadraticBezierTo(x + curve * 10, y + length / 2, x, y + length);

      canvas.drawPath(path, grainPaint);
    }
  }

  void _drawCornerJoints(
    Canvas canvas,
    double cx,
    double cy,
    double crateSize,
    double barThickness,
    double time,
  ) {
    // Add nail heads at corners
    final corners = [
      Offset(cx - crateSize * 0.35, cy - crateSize * 0.35),
      Offset(cx + crateSize * 0.35, cy - crateSize * 0.35),
      Offset(cx - crateSize * 0.35, cy + crateSize * 0.35),
      Offset(cx + crateSize * 0.35, cy + crateSize * 0.35),
    ];

    for (final corner in corners) {
      // Nail head
      canvas.drawCircle(
        corner,
        barThickness * 0.3,
        Paint()..color = Colors.grey.shade600,
      );

      // Nail highlight
      canvas.drawCircle(
        Offset(corner.dx - 1, corner.dy - 1),
        barThickness * 0.15,
        Paint()..color = Colors.grey.shade400,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FreemishCratePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
