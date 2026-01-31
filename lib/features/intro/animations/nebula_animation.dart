// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Nebula / space gas cloud animation.
class NebulaAnimation extends StatefulWidget {
  const NebulaAnimation({super.key});

  @override
  State<NebulaAnimation> createState() => _NebulaAnimationState();
}

class _NebulaAnimationState extends State<NebulaAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
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
          painter: _NebulaPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _NebulaPainter extends CustomPainter {
  _NebulaPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    // Dark space background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF030308),
    );

    // Draw stars in background
    final starRandom = Random(42);
    for (var i = 0; i < 100; i++) {
      final x = starRandom.nextDouble() * size.width;
      final y = starRandom.nextDouble() * size.height;
      final twinkle = sin(time * 2 + i) * 0.3 + 0.7;

      canvas.drawCircle(
        Offset(x, y),
        1 + starRandom.nextDouble(),
        Paint()..color = Colors.white.withValues(alpha: twinkle * 0.8),
      );
    }

    // Nebula clouds - multiple layers
    final clouds = [
      (
        cx: size.width * 0.3,
        cy: size.height * 0.4,
        color: const Color(0xFFFF0066),
        size: size.width * 0.5,
      ),
      (
        cx: size.width * 0.7,
        cy: size.height * 0.3,
        color: const Color(0xFF6600FF),
        size: size.width * 0.4,
      ),
      (
        cx: size.width * 0.5,
        cy: size.height * 0.6,
        color: const Color(0xFF00AAFF),
        size: size.width * 0.45,
      ),
      (
        cx: size.width * 0.2,
        cy: size.height * 0.7,
        color: const Color(0xFFFF6600),
        size: size.width * 0.3,
      ),
      (
        cx: size.width * 0.8,
        cy: size.height * 0.65,
        color: const Color(0xFF00FF88),
        size: size.width * 0.35,
      ),
    ];

    for (var i = 0; i < clouds.length; i++) {
      final cloud = clouds[i];
      final offsetX = sin(time + i * 1.5) * 30;
      final offsetY = cos(time * 0.7 + i * 1.2) * 20;

      _drawNebulaCloud(
        canvas,
        cloud.cx + offsetX,
        cloud.cy + offsetY,
        cloud.size,
        cloud.color,
        time + i,
      );
    }

    // Bright stars scattered
    for (var i = 0; i < 20; i++) {
      final x = starRandom.nextDouble() * size.width;
      final y = starRandom.nextDouble() * size.height;
      final brightness = sin(time * 3 + i * 0.5) * 0.5 + 0.5;

      final starPaint = Paint()
        ..color = Colors.white.withValues(alpha: brightness)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(x, y), 3, starPaint);

      // Star rays
      if (brightness > 0.7) {
        final rayPaint = Paint()
          ..color = Colors.white.withValues(alpha: brightness * 0.3)
          ..strokeWidth = 1;
        canvas.drawLine(Offset(x - 10, y), Offset(x + 10, y), rayPaint);
        canvas.drawLine(Offset(x, y - 10), Offset(x, y + 10), rayPaint);
      }
    }
  }

  void _drawNebulaCloud(
    Canvas canvas,
    double cx,
    double cy,
    double cloudSize,
    Color color,
    double time,
  ) {
    // Multiple overlapping circles with blur for cloud effect
    final random = Random(
      color.r.hashCode ^ color.g.hashCode ^ color.b.hashCode,
    );

    for (var i = 0; i < 15; i++) {
      final offsetX = (random.nextDouble() - 0.5) * cloudSize * 0.6;
      final offsetY = (random.nextDouble() - 0.5) * cloudSize * 0.6;
      final blobSize = cloudSize * (0.3 + random.nextDouble() * 0.4);

      // Animate blob positions slightly
      final animOffsetX = sin(time * 0.5 + i) * 10;
      final animOffsetY = cos(time * 0.3 + i * 0.7) * 10;

      final blobX = cx + offsetX + animOffsetX;
      final blobY = cy + offsetY + animOffsetY;

      // Vary alpha for depth
      final alpha = 0.05 + random.nextDouble() * 0.1;

      final paint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blobSize * 0.5);

      canvas.drawCircle(Offset(blobX, blobY), blobSize, paint);
    }

    // Brighter core
    final corePaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.05),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: cloudSize * 0.4),
          );
    canvas.drawCircle(Offset(cx, cy), cloudSize * 0.4, corePaint);
  }

  @override
  bool shouldRepaint(covariant _NebulaPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
