// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Reaction diffusion / Turing patterns.
class ReactionDiffusionAnimation extends StatefulWidget {
  const ReactionDiffusionAnimation({super.key});

  @override
  State<ReactionDiffusionAnimation> createState() =>
      _ReactionDiffusionAnimationState();
}

class _ReactionDiffusionAnimationState extends State<ReactionDiffusionAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
        painter: _ReactionDiffusionPainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _ReactionDiffusionPainter extends CustomPainter {
  _ReactionDiffusionPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0f1015),
    );

    const cellSize = 8.0;
    for (var y = 0.0; y < size.height; y += cellSize) {
      for (var x = 0.0; x < size.width; x += cellSize) {
        final nx = x / size.width;
        final ny = y / size.height;

        final v1 = sin(nx * 15 + time) * cos(ny * 12 - time * 0.5);
        final v2 = sin((nx + ny) * 10 + time * 0.7);
        final v3 = cos(nx * 8 - ny * 6 + time * 0.3);
        final value = (v1 + v2 + v3) / 3;

        if (value > 0.2) {
          final alpha = ((value - 0.2) / 0.8).clamp(0.0, 1.0);
          canvas.drawRect(
            Rect.fromLTWH(x, y, cellSize - 1, cellSize - 1),
            Paint()
              ..color = const Color(0xFF40a080).withValues(alpha: alpha * 0.8),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReactionDiffusionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
