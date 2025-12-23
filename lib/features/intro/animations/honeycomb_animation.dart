import 'dart:math';

import 'package:flutter/material.dart';

/// Hexagonal honeycomb pattern animation.
class HoneycombAnimation extends StatefulWidget {
  const HoneycombAnimation({super.key});

  @override
  State<HoneycombAnimation> createState() => _HoneycombAnimationState();
}

class _HoneycombAnimationState extends State<HoneycombAnimation>
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
          painter: _HoneycombPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _HoneycombPainter extends CustomPainter {
  _HoneycombPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    const hexSize = 40.0;
    final hexHeight = hexSize * sqrt(3);
    final hexWidth = hexSize * 2;

    // Calculate grid
    final cols = (size.width / (hexWidth * 0.75)).ceil() + 2;
    final rows = (size.height / hexHeight).ceil() + 2;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    for (var row = -1; row < rows; row++) {
      for (var col = -1; col < cols; col++) {
        final offsetX = col * hexWidth * 0.75;
        final offsetY = row * hexHeight + (col % 2 == 1 ? hexHeight / 2 : 0);

        final hexCenterX = offsetX + hexSize;
        final hexCenterY = offsetY + hexHeight / 2;

        // Distance from screen center for wave effect
        final dx = hexCenterX - centerX;
        final dy = hexCenterY - centerY;
        final dist = sqrt(dx * dx + dy * dy);

        // Wave animation
        final wave = sin(dist * 0.02 - time * 2) * 0.5 + 0.5;
        final pulse = sin(time * 3 + dist * 0.01) * 0.3 + 0.7;

        // Color based on position and time
        final hue = (dist * 0.3 + progress * 360) % 360;
        final brightness = wave * pulse;
        final color = HSVColor.fromAHSV(
          brightness.clamp(0.3, 0.9),
          hue,
          0.7,
          brightness.clamp(0.4, 1.0),
        ).toColor();

        // Scale hexagon based on wave
        final scale = 0.8 + wave * 0.2;

        // Draw hexagon
        _drawHexagon(
          canvas,
          hexCenterX,
          hexCenterY,
          hexSize * scale * 0.9,
          color,
          brightness,
        );
      }
    }

    // Overlay glow from center
    final maxDist = sqrt(centerX * centerX + centerY * centerY);
    final centerGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF00FFFF).withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(centerX, centerY),
              radius: maxDist * 0.5,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), centerGlow);
  }

  void _drawHexagon(
    Canvas canvas,
    double cx,
    double cy,
    double size,
    Color color,
    double brightness,
  ) {
    final path = Path();

    for (var i = 0; i < 6; i++) {
      final angle = (i * 60 - 30) * pi / 180;
      final x = cx + cos(angle) * size;
      final y = cy + sin(angle) * size;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Fill
    final fillPaint = Paint()
      ..color = color.withValues(alpha: brightness * 0.3);
    canvas.drawPath(path, fillPaint);

    // Glow stroke
    if (brightness > 0.5) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: brightness * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);
    }

    // Stroke
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Center dot for bright cells
    if (brightness > 0.7) {
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: brightness * 0.6);
      canvas.drawCircle(Offset(cx, cy), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HoneycombPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
