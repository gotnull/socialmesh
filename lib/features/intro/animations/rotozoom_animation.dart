import 'dart:math';

import 'package:flutter/material.dart';

/// Classic rotozoom effect - rotating and zooming textured plane.
class RotozoomAnimation extends StatefulWidget {
  const RotozoomAnimation({super.key});

  @override
  State<RotozoomAnimation> createState() => _RotozoomAnimationState();
}

class _RotozoomAnimationState extends State<RotozoomAnimation>
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
          painter: _RotozoomPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RotozoomPainter extends CustomPainter {
  _RotozoomPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Rotation and zoom parameters
    final angle = time;
    final zoom = 0.5 + sin(time * 2) * 0.3 + 0.5;

    final cosA = cos(angle) / zoom;
    final sinA = sin(angle) / zoom;

    const tileSize = 32;
    const pixelSize = 4.0;

    for (var sy = 0.0; sy < size.height; sy += pixelSize) {
      for (var sx = 0.0; sx < size.width; sx += pixelSize) {
        // Transform screen coordinates to texture coordinates
        final dx = sx - centerX;
        final dy = sy - centerY;

        final tx = (dx * cosA - dy * sinA + time * 50).toInt();
        final ty = (dx * sinA + dy * cosA + time * 30).toInt();

        // XOR texture - classic demoscene pattern
        final tileX = (tx ~/ tileSize) & 7;
        final tileY = (ty ~/ tileSize) & 7;
        final pattern = (tileX ^ tileY) & 7;

        // Color based on pattern and time
        final hue = ((pattern * 45 + progress * 360) % 360);
        final brightness = 0.3 + pattern / 7 * 0.7;

        final color = HSVColor.fromAHSV(1.0, hue, 0.8, brightness).toColor();

        final paint = Paint()..color = color;
        canvas.drawRect(Rect.fromLTWH(sx, sy, pixelSize, pixelSize), paint);
      }
    }

    // Add vignette effect
    final vignette =
        RadialGradient(
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.5)],
          stops: const [0.5, 1.0],
        ).createShader(
          Rect.fromCircle(center: Offset(centerX, centerY), radius: size.width),
        );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = vignette,
    );
  }

  @override
  bool shouldRepaint(covariant _RotozoomPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
