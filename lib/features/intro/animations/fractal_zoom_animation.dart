// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Mandelbrot-inspired fractal zoom animation.
class FractalZoomAnimation extends StatefulWidget {
  const FractalZoomAnimation({super.key});

  @override
  State<FractalZoomAnimation> createState() => _FractalZoomAnimationState();
}

class _FractalZoomAnimationState extends State<FractalZoomAnimation>
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
          painter: _FractalZoomPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FractalZoomPainter extends CustomPainter {
  _FractalZoomPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final time = progress * 2 * pi;

    // Fake fractal with layered spirals and patterns
    // Real Mandelbrot would be too slow for 60fps

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000011),
    );

    // Multiple spiral layers creating fractal-like zoom effect
    for (var layer = 0; layer < 8; layer++) {
      final layerScale = pow(1.5, layer).toDouble();
      final layerRotation = time * (layer % 2 == 0 ? 1 : -1) * 0.5;
      final layerAlpha = (1 - layer / 8) * 0.6;

      canvas.save();
      canvas.translate(centerX, centerY);
      canvas.rotate(layerRotation);
      canvas.scale(1 / layerScale);

      _drawFractalLayer(canvas, size, layer, layerAlpha, time);

      canvas.restore();
    }

    // Central bright point
    final corePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white,
              const Color(0xFFFFFF00).withValues(alpha: 0.8),
              const Color(0xFFFF0088).withValues(alpha: 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.1, 0.3, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: 50),
          );
    canvas.drawCircle(Offset(centerX, centerY), 50, corePaint);
  }

  void _drawFractalLayer(
    Canvas canvas,
    Size size,
    int layer,
    double alpha,
    double time,
  ) {
    final maxRadius = max(size.width, size.height);
    final hueOffset = layer * 45;

    // Draw spiral arms
    const arms = 5;
    for (var arm = 0; arm < arms; arm++) {
      final armOffset = (arm / arms) * 2 * pi;
      final path = Path();

      for (var i = 0; i < 100; i++) {
        final t = i / 100;
        final angle = t * 4 * pi + armOffset + time;
        final radius = t * maxRadius * 0.5;

        // Add fractal-like wobble
        final wobble = sin(t * 20 + layer) * radius * 0.1;
        final r = radius + wobble;

        final x = cos(angle) * r;
        final y = sin(angle) * r;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Color varies along the spiral
      final hue = (hueOffset + progress * 360 + arm * 72) % 360;
      final color = HSVColor.fromAHSV(alpha, hue, 0.9, 0.9).toColor();

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, paint);

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);
    }

    // Add some dots along the spirals
    final random = Random(layer);
    for (var i = 0; i < 30; i++) {
      final angle = random.nextDouble() * 2 * pi + time;
      final radius = random.nextDouble() * maxRadius * 0.4;
      final x = cos(angle) * radius;
      final y = sin(angle) * radius;

      final hue = (hueOffset + i * 12 + progress * 360) % 360;
      final dotColor = HSVColor.fromAHSV(alpha, hue, 0.8, 1.0).toColor();

      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()
          ..color = dotColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FractalZoomPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
