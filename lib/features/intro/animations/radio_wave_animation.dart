// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Looping radio wave animation with concentric expanding circles.
class RadioWaveAnimation extends StatefulWidget {
  const RadioWaveAnimation({super.key});

  @override
  State<RadioWaveAnimation> createState() => _RadioWaveAnimationState();
}

class _RadioWaveAnimationState extends State<RadioWaveAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
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
          painter: _RadioWavePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RadioWavePainter extends CustomPainter {
  _RadioWavePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.4);
    final maxRadius = size.width * 0.8;
    const accentColor = Color(0xFF00E5FF);
    const waveCount = 5;

    for (var i = 0; i < waveCount; i++) {
      final waveProgress = (progress + i / waveCount) % 1.0;
      final radius = waveProgress * maxRadius;
      final alpha = (1.0 - waveProgress) * 0.4;

      if (alpha > 0.01) {
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: alpha * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawCircle(center, radius, glowPaint);

        final wavePaint = Paint()
          ..color = accentColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(center, radius, wavePaint);
      }
    }

    // Center antenna dot
    final antennaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.9),
          accentColor,
          accentColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 20));
    canvas.drawCircle(center, 12, antennaPaint);

    // Antenna glow pulse
    final pulseAlpha = 0.3 + sin(progress * 2 * pi) * 0.2;
    final pulsePaint = Paint()
      ..color = accentColor.withValues(alpha: pulseAlpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, 20, pulsePaint);
  }

  @override
  bool shouldRepaint(covariant _RadioWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
