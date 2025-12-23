import 'dart:math';

import 'package:flutter/material.dart';

/// Classic demoscene plasma wave effect with color cycling.
class PlasmaWaveAnimation extends StatefulWidget {
  const PlasmaWaveAnimation({super.key});

  @override
  State<PlasmaWaveAnimation> createState() => _PlasmaWaveAnimationState();
}

class _PlasmaWaveAnimationState extends State<PlasmaWaveAnimation>
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
          painter: _PlasmaWavePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _PlasmaWavePainter extends CustomPainter {
  _PlasmaWavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    const cellSize = 8.0;

    final cols = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();

    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final px = x * cellSize;
        final py = y * cellSize;

        // Classic plasma formula
        final v1 = sin(x * 0.1 + time);
        final v2 = sin((y * 0.1 + time) * 0.5);
        final v3 = sin((x * 0.1 + y * 0.1 + time) * 0.5);
        final cx = x + 0.5 * sin(time * 0.3) * cols;
        final cy = y + 0.5 * cos(time * 0.5) * rows;
        final v4 = sin(sqrt(cx * cx + cy * cy) * 0.1);

        final value = (v1 + v2 + v3 + v4) / 4.0;

        // Color cycling - classic demoscene palette
        final hue = (value + 1.0) / 2.0 * 360 + progress * 360;
        final color = HSVColor.fromAHSV(1.0, hue % 360, 0.8, 0.7).toColor();

        final paint = Paint()..color = color;
        canvas.drawRect(Rect.fromLTWH(px, py, cellSize, cellSize), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlasmaWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
