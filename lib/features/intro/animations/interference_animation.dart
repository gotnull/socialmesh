// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Interference patterns from multiple wave sources.
class InterferenceAnimation extends StatefulWidget {
  const InterferenceAnimation({super.key});

  @override
  State<InterferenceAnimation> createState() => _InterferenceAnimationState();
}

class _InterferenceAnimationState extends State<InterferenceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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
      builder: (context, child) => CustomPaint(
        painter: _InterferencePainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _InterferencePainter extends CustomPainter {
  _InterferencePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    final sources = [
      Offset(size.width * 0.3, size.height * 0.5),
      Offset(size.width * 0.7, size.height * 0.5),
    ];

    const step = 4.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        var totalWave = 0.0;
        for (final s in sources) {
          final d = (Offset(x, y) - s).distance;
          totalWave += sin(d * 0.1 - time * 3);
        }
        totalWave /= sources.length;

        final bright = (totalWave + 1) / 2;
        final color = Color.lerp(
          const Color(0xFF000510),
          const Color(0xFF4080c0),
          bright,
        )!;
        canvas.drawRect(
          Rect.fromLTWH(x, y, step, step),
          Paint()..color = color,
        );
      }
    }

    for (final s in sources) {
      canvas.drawCircle(
        s,
        5,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _InterferencePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
