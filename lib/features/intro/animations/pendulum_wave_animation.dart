// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Pendulum wave synchronization.
class PendulumWaveAnimation extends StatefulWidget {
  const PendulumWaveAnimation({super.key});

  @override
  State<PendulumWaveAnimation> createState() => _PendulumWaveAnimationState();
}

class _PendulumWaveAnimationState extends State<PendulumWaveAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
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
        painter: _PendulumWavePainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _PendulumWavePainter extends CustomPainter {
  _PendulumWavePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi * 3;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0a0a10),
    );

    const pendulumCount = 20;
    final spacing = size.width / (pendulumCount + 1);
    final anchorY = size.height * 0.1;

    for (var i = 0; i < pendulumCount; i++) {
      final freq = 0.8 + i * 0.04;
      final angle = sin(time * freq) * 0.8;
      final length = size.height * 0.35 + i * 5;

      final anchorX = spacing * (i + 1);
      final bobX = anchorX + sin(angle) * length;
      final bobY = anchorY + cos(angle) * length;

      canvas.drawLine(
        Offset(anchorX, anchorY),
        Offset(bobX, bobY),
        Paint()
          ..color = const Color(0xFF404050)
          ..strokeWidth = 1,
      );

      final hue = i * 360 / pendulumCount;
      canvas.drawCircle(
        Offset(bobX, bobY),
        12,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  HSVColor.fromAHSV(1, hue, 0.7, 0.9).toColor(),
                  HSVColor.fromAHSV(1, hue, 0.8, 0.5).toColor(),
                ],
              ).createShader(
                Rect.fromCircle(center: Offset(bobX, bobY), radius: 12),
              ),
      );
    }

    canvas.drawLine(
      Offset(0, anchorY),
      Offset(size.width, anchorY),
      Paint()
        ..color = const Color(0xFF303040)
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _PendulumWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
