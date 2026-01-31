// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Metaball / blob effect animation.
class MetaballsAnimation extends StatefulWidget {
  const MetaballsAnimation({super.key});

  @override
  State<MetaballsAnimation> createState() => _MetaballsAnimationState();
}

class _MetaballsAnimationState extends State<MetaballsAnimation>
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
          painter: _MetaballsPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MetaballsPainter extends CustomPainter {
  _MetaballsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final time = progress * 2 * pi;

    // Define metaball centers
    final balls = <_Metaball>[
      _Metaball(
        centerX + sin(time) * size.width * 0.25,
        centerY + cos(time * 1.3) * size.height * 0.2,
        80,
      ),
      _Metaball(
        centerX + sin(time * 0.7 + 2) * size.width * 0.3,
        centerY + cos(time * 0.9) * size.height * 0.25,
        60,
      ),
      _Metaball(
        centerX + sin(time * 1.2 + 4) * size.width * 0.2,
        centerY + cos(time * 0.6 + 1) * size.height * 0.3,
        70,
      ),
      _Metaball(
        centerX + cos(time * 0.8) * size.width * 0.15,
        centerY + sin(time * 1.1 + 3) * size.height * 0.15,
        50,
      ),
      _Metaball(
        centerX + sin(time * 0.5 + 1) * size.width * 0.35,
        centerY + cos(time * 0.7 + 2) * size.height * 0.2,
        55,
      ),
    ];

    // Draw using marching squares approximation with circles
    // For each ball, draw with blur to create metaball effect
    for (final ball in balls) {
      // Inner glow
      final innerPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFF00FFFF).withValues(alpha: 0.8),
                const Color(0xFF0088FF).withValues(alpha: 0.4),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
              Rect.fromCircle(
                center: Offset(ball.x, ball.y),
                radius: ball.radius,
              ),
            );
      canvas.drawCircle(Offset(ball.x, ball.y), ball.radius, innerPaint);
    }

    // Second pass with blur for merging effect
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final ball in balls) {
      final blobPaint = Paint()
        ..color = const Color(0xFF00FFFF).withValues(alpha: 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, ball.radius * 0.4);
      canvas.drawCircle(Offset(ball.x, ball.y), ball.radius * 0.8, blobPaint);
    }

    canvas.restore();

    // Highlights on each ball
    for (final ball in balls) {
      final highlightPaint = Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-0.3, -0.3),
              colors: [Colors.white.withValues(alpha: 0.4), Colors.transparent],
            ).createShader(
              Rect.fromCircle(
                center: Offset(ball.x, ball.y),
                radius: ball.radius * 0.6,
              ),
            );
      canvas.drawCircle(
        Offset(ball.x - ball.radius * 0.2, ball.y - ball.radius * 0.2),
        ball.radius * 0.4,
        highlightPaint,
      );
    }

    // Draw connecting tendrils between nearby balls
    for (var i = 0; i < balls.length; i++) {
      for (var j = i + 1; j < balls.length; j++) {
        final dx = balls[j].x - balls[i].x;
        final dy = balls[j].y - balls[i].y;
        final dist = sqrt(dx * dx + dy * dy);
        final threshold = balls[i].radius + balls[j].radius + 50;

        if (dist < threshold) {
          final alpha = (1 - dist / threshold) * 0.4;
          final tendrilPaint = Paint()
            ..color = const Color(0xFF00FFFF).withValues(alpha: alpha)
            ..strokeWidth = 20
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

          // Draw curved tendril
          final midX = (balls[i].x + balls[j].x) / 2;
          final midY = (balls[i].y + balls[j].y) / 2;
          final perpX = -dy / dist * 20 * sin(time * 3);
          final perpY = dx / dist * 20 * sin(time * 3);

          final path = Path()
            ..moveTo(balls[i].x, balls[i].y)
            ..quadraticBezierTo(
              midX + perpX,
              midY + perpY,
              balls[j].x,
              balls[j].y,
            );

          canvas.drawPath(path, tendrilPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MetaballsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _Metaball {
  _Metaball(this.x, this.y, this.radius);
  final double x;
  final double y;
  final double radius;
}
