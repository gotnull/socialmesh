// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Neon grid floor with perspective - Tron style.
class NeonGridAnimation extends StatefulWidget {
  const NeonGridAnimation({super.key});

  @override
  State<NeonGridAnimation> createState() => _NeonGridAnimationState();
}

class _NeonGridAnimationState extends State<NeonGridAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
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
          painter: _NeonGridPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _NeonGridPainter extends CustomPainter {
  _NeonGridPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final horizon = size.height * 0.4;
    final vanishY = horizon;

    // Sky gradient
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF000022),
          const Color(0xFF110033),
          const Color(0xFF220044),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizon), skyPaint);

    // Sun/moon at horizon
    final sunY = horizon - 60 + sin(progress * 2 * pi) * 20;
    final sunPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFF0088),
              const Color(0xFFFF0044).withValues(alpha: 0.5),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, sunY), radius: 80),
          );
    canvas.drawCircle(Offset(centerX, sunY), 80, sunPaint);

    // Horizontal stripes through sun (synthwave style)
    for (var i = 0; i < 8; i++) {
      final stripeY = sunY - 30 + i * 10;
      if (stripeY > horizon - 80 && stripeY < horizon) {
        canvas.drawRect(
          Rect.fromLTWH(centerX - 80, stripeY, 160, 4),
          Paint()..color = const Color(0xFF000022),
        );
      }
    }

    // Ground gradient
    final groundPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF110022), const Color(0xFF000011)],
          ).createShader(
            Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
          );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      groundPaint,
    );

    // Grid lines - horizontal (going into distance)
    const gridSpacing = 40.0;
    final scrollOffset = (progress * gridSpacing * 2) % gridSpacing;

    for (var i = 0; i < 30; i++) {
      final worldZ = i * gridSpacing + scrollOffset;
      if (worldZ < 10) continue;

      // Perspective projection
      final screenY =
          horizon + (size.height - horizon) * (100 / (worldZ + 100));
      if (screenY > size.height) continue;

      final alpha = (1 - i / 30).clamp(0.1, 0.8);
      final lineWidth = (3 - i * 0.1).clamp(0.5, 3.0);

      // Glow
      final glowPaint = Paint()
        ..color = const Color(0xFF00FFFF).withValues(alpha: alpha * 0.3)
        ..strokeWidth = lineWidth + 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(
        Offset(0, screenY),
        Offset(size.width, screenY),
        glowPaint,
      );

      // Line
      final linePaint = Paint()
        ..color = const Color(0xFF00FFFF).withValues(alpha: alpha)
        ..strokeWidth = lineWidth;
      canvas.drawLine(
        Offset(0, screenY),
        Offset(size.width, screenY),
        linePaint,
      );
    }

    // Grid lines - vertical (converging to vanishing point)
    const verticalLines = 20;
    for (var i = -verticalLines ~/ 2; i <= verticalLines ~/ 2; i++) {
      final worldX = i * gridSpacing;

      // Start point at bottom
      final bottomX = centerX + worldX * 3;

      // End point at horizon (all converge)
      final horizonX = centerX + worldX * 0.1;

      final alpha = (1 - i.abs() / (verticalLines / 2)).clamp(0.2, 0.8);

      // Glow
      final glowPaint = Paint()
        ..color = const Color(0xFFFF00FF).withValues(alpha: alpha * 0.3)
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(
        Offset(bottomX, size.height),
        Offset(horizonX, vanishY),
        glowPaint,
      );

      // Line
      final linePaint = Paint()
        ..color = const Color(0xFFFF00FF).withValues(alpha: alpha)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(bottomX, size.height),
        Offset(horizonX, vanishY),
        linePaint,
      );
    }

    // Stars in sky
    final random = Random(42);
    for (var i = 0; i < 50; i++) {
      final starX = random.nextDouble() * size.width;
      final starY = random.nextDouble() * (horizon - 20);
      final twinkle = sin(progress * 2 * pi * 2 + i) * 0.5 + 0.5;

      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: twinkle * 0.8);
      canvas.drawCircle(Offset(starX, starY), 1.5, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeonGridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
