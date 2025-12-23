import 'dart:math';

import 'package:flutter/material.dart';

/// Spiraling tunnel effect with neon rings.
class SpiralTunnelAnimation extends StatefulWidget {
  const SpiralTunnelAnimation({super.key});

  @override
  State<SpiralTunnelAnimation> createState() => _SpiralTunnelAnimationState();
}

class _SpiralTunnelAnimationState extends State<SpiralTunnelAnimation>
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
          painter: _SpiralTunnelPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SpiralTunnelPainter extends CustomPainter {
  _SpiralTunnelPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = sqrt(centerX * centerX + centerY * centerY);
    final time = progress * 2 * pi;

    // Background gradient
    final bgPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF110022),
              const Color(0xFF000011),
              Colors.black,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(centerX, centerY),
              radius: maxRadius,
            ),
          );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw spiraling rings from back to front
    const ringCount = 30;

    for (var i = ringCount; i >= 0; i--) {
      final depth = (i + progress * 5) % ringCount;
      final z = depth / ringCount;

      // Size decreases with depth (perspective)
      final radius = maxRadius * (1 - z * 0.8) * 0.9;
      if (radius < 5) continue;

      // Rotation increases with depth
      final rotation = time + z * 4;

      // Color cycling
      final hue = (i * 12 + progress * 360) % 360;
      final alpha = (1 - z).clamp(0.1, 0.8);
      final color = HSVColor.fromAHSV(alpha, hue, 0.9, 0.9).toColor();

      // Draw segmented ring
      const segments = 12;
      final segmentAngle = 2 * pi / segments;

      for (var s = 0; s < segments; s++) {
        if (s % 2 == 0) continue; // Skip every other segment

        final startAngle = s * segmentAngle + rotation;

        final paint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = (3 * (1 - z)).clamp(1.0, 4.0)
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
          startAngle,
          segmentAngle * 0.8,
          false,
          paint,
        );

        // Glow effect
        final glowPaint = Paint()
          ..color = color.withValues(alpha: alpha * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (8 * (1 - z)).clamp(2.0, 10.0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

        canvas.drawArc(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
          startAngle,
          segmentAngle * 0.8,
          false,
          glowPaint,
        );
      }
    }

    // Center bright spot
    final centerPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.8),
              const Color(0xFF00FFFF).withValues(alpha: 0.3),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: 50),
          );
    canvas.drawCircle(Offset(centerX, centerY), 50, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _SpiralTunnelPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
