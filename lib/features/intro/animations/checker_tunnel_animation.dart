import 'dart:math';

import 'package:flutter/material.dart';

/// Classic checkered tunnel / infinite corridor effect.
class CheckerTunnelAnimation extends StatefulWidget {
  const CheckerTunnelAnimation({super.key});

  @override
  State<CheckerTunnelAnimation> createState() => _CheckerTunnelAnimationState();
}

class _CheckerTunnelAnimationState extends State<CheckerTunnelAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
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
          painter: _CheckerTunnelPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _CheckerTunnelPainter extends CustomPainter {
  _CheckerTunnelPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    const pixelSize = 4.0;

    for (var sy = 0.0; sy < size.height; sy += pixelSize) {
      for (var sx = 0.0; sx < size.width; sx += pixelSize) {
        // Distance from center
        final dx = sx - centerX;
        final dy = sy - centerY;

        // Convert to polar coordinates
        var angle = atan2(dy, dx);
        final distance = sqrt(dx * dx + dy * dy);

        if (distance < 5) continue;

        // Tunnel depth
        final depth = 200 / distance;

        // Add rotation over time
        angle += time * 0.5;

        // Texture coordinates
        final u = (angle / pi * 4 + depth * 8 + time * 3).floor();
        final v = (depth * 8 + progress * 20).floor();

        // Checkerboard pattern
        final checker = ((u + v) % 2 == 0);

        // Color with depth shading
        final brightness = (1.0 - distance / (size.width * 0.7)).clamp(
          0.0,
          1.0,
        );
        final hue = (angle / pi * 180 + 180 + progress * 180) % 360;

        Color color;
        if (checker) {
          color = HSVColor.fromAHSV(1.0, hue, 0.8, brightness).toColor();
        } else {
          color = HSVColor.fromAHSV(
            1.0,
            (hue + 180) % 360,
            0.6,
            brightness * 0.3,
          ).toColor();
        }

        final paint = Paint()..color = color;
        canvas.drawRect(Rect.fromLTWH(sx, sy, pixelSize, pixelSize), paint);
      }
    }

    // Center glow
    final centerGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.8),
              const Color(0xFF00E5FF).withValues(alpha: 0.3),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: 80),
          );
    canvas.drawCircle(Offset(centerX, centerY), 60, centerGlow);
  }

  @override
  bool shouldRepaint(covariant _CheckerTunnelPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
