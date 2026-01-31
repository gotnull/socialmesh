// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Bioluminescent deep sea creatures.
class BioluminescentAnimation extends StatefulWidget {
  const BioluminescentAnimation({super.key});

  @override
  State<BioluminescentAnimation> createState() =>
      _BioluminescentAnimationState();
}

class _BioluminescentAnimationState extends State<BioluminescentAnimation>
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
      builder: (context, child) {
        return CustomPaint(
          painter: _BioluminescentPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _BioluminescentPainter extends CustomPainter {
  _BioluminescentPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF000508), Color(0xFF001015), Color(0xFF000810)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final r = Random(42);
    for (var i = 0; i < 15; i++) {
      final cx = r.nextDouble() * size.width;
      final cy = r.nextDouble() * size.height;
      final pulse = (sin(time * 2 + i * 0.5) + 1) / 2;
      final hue = 180 + r.nextDouble() * 60;
      final color = HSVColor.fromAHSV(1, hue, 0.8, 0.9).toColor();

      canvas.drawCircle(
        Offset(cx + sin(time + i) * 20, cy + cos(time * 0.7 + i) * 15),
        15 + pulse * 10,
        Paint()
          ..color = color.withValues(alpha: pulse * 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );
      canvas.drawCircle(
        Offset(cx + sin(time + i) * 20, cy + cos(time * 0.7 + i) * 15),
        3 + pulse * 3,
        Paint()..color = color.withValues(alpha: pulse * 0.8),
      );
    }

    for (var i = 0; i < 50; i++) {
      final px = r.nextDouble() * size.width;
      final py =
          (r.nextDouble() + progress * 0.5 + i * 0.02) % 1.0 * size.height;
      canvas.drawCircle(
        Offset(px, py),
        1 + r.nextDouble(),
        Paint()..color = const Color(0xFF40c0c0).withValues(alpha: 0.3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BioluminescentPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
