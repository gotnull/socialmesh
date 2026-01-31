// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Hypnotic swirling vortex animation.
class VortexAnimation extends StatefulWidget {
  const VortexAnimation({super.key});

  @override
  State<VortexAnimation> createState() => _VortexAnimationState();
}

class _VortexAnimationState extends State<VortexAnimation>
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
          painter: _VortexPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _VortexPainter extends CustomPainter {
  _VortexPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = sqrt(centerX * centerX + centerY * centerY);
    final time = progress * 2 * pi;

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF050510),
    );

    // Draw spiral arms
    const armCount = 6;
    const spiralTurns = 3.0;

    for (var arm = 0; arm < armCount; arm++) {
      final armOffset = (arm / armCount) * 2 * pi;
      final armColor = HSVColor.fromAHSV(
        1.0,
        (arm * 60 + progress * 360) % 360,
        0.8,
        0.9,
      ).toColor();

      // Draw spiral as series of points/segments
      final path = Path();
      const steps = 200;

      for (var i = 0; i < steps; i++) {
        final t = i / steps;
        final angle = t * spiralTurns * 2 * pi + armOffset + time;
        final radius = t * maxRadius * 0.9;

        // Add some waviness
        final waveRadius = radius + sin(angle * 5 + time * 2) * 10;

        final x = centerX + cos(angle) * waveRadius;
        final y = centerY + sin(angle) * waveRadius;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      // Glow
      final glowPaint = Paint()
        ..color = armColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawPath(path, glowPaint);

      // Main line
      final paint = Paint()
        ..color = armColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(path, paint);
    }

    // Particles being sucked in
    final random = Random(42);
    for (var i = 0; i < 60; i++) {
      final particleProgress = (progress + i * 0.017) % 1.0;
      final startAngle = random.nextDouble() * 2 * pi;
      final spiralSpeed = 0.5 + random.nextDouble() * 0.5;

      final angle = startAngle + particleProgress * spiralSpeed * 4 * pi;
      final radius = (1 - particleProgress) * maxRadius * 0.8;

      final x = centerX + cos(angle) * radius;
      final y = centerY + sin(angle) * radius;

      final alpha = (1 - particleProgress).clamp(0.0, 0.8);
      final particleSize = 2 + (1 - particleProgress) * 4;

      final hue = (i * 6 + progress * 360) % 360;
      final color = HSVColor.fromAHSV(alpha, hue, 0.7, 1.0).toColor();

      final particlePaint = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(x, y), particleSize, particlePaint);
    }

    // Center bright core
    final corePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white,
              const Color(0xFF00FFFF).withValues(alpha: 0.8),
              const Color(0xFFFF00FF).withValues(alpha: 0.4),
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: 60),
          );
    canvas.drawCircle(Offset(centerX, centerY), 60, corePaint);
  }

  @override
  bool shouldRepaint(covariant _VortexPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
