// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Elegant gravitational lens / black hole effect.
class WormholeAnimation extends StatefulWidget {
  const WormholeAnimation({super.key});

  @override
  State<WormholeAnimation> createState() => _WormholeAnimationState();
}

class _WormholeAnimationState extends State<WormholeAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
          painter: _WormholePainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _WormholePainter extends CustomPainter {
  _WormholePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxR = min(size.width, size.height) * 0.45;
    final time = progress * 2 * pi;

    // Deep space
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF020208),
    );

    // Distant stars
    final starRandom = Random(99);
    for (var i = 0; i < 80; i++) {
      final sx = starRandom.nextDouble() * size.width;
      final sy = starRandom.nextDouble() * size.height;
      final brightness = starRandom.nextDouble();
      final twinkle = sin(time * 2 + i) * 0.2 + 0.8;

      canvas.drawCircle(
        Offset(sx, sy),
        0.5 + brightness * 0.5,
        Paint()
          ..color = Colors.white.withValues(alpha: brightness * twinkle * 0.4),
      );
    }

    // Accretion disk - elegant rings
    for (var ring = 0; ring < 20; ring++) {
      final ringRadius = 35 + ring * 8.0;
      final ringSpeed = 2.5 - ring * 0.08;
      final angle = time * ringSpeed;

      // Ring color gradient from hot to cool
      final t = ring / 20;
      final color = Color.lerp(
        const Color(0xFFffa040),
        const Color(0xFF6040a0),
        t,
      )!;

      final alpha = (0.5 - t * 0.3).clamp(0.1, 0.5);

      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.scale(1.0, 0.25);

      canvas.drawCircle(
        Offset.zero,
        ringRadius,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      canvas.restore();
    }

    // Event horizon
    canvas.drawCircle(
      Offset(cx, cy),
      30,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black,
            Colors.black,
            const Color(0xFF301050).withValues(alpha: 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 0.85, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 35)),
    );

    // Photon ring - thin bright line
    canvas.drawCircle(
      Offset(cx, cy),
      28,
      Paint()
        ..color = const Color(0xFFffc080).withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Gravitationally lensed light arcs
    for (var i = 0; i < 8; i++) {
      final arcAngle = i * pi / 4 + time * 0.3;
      final arcRadius = 45 + sin(time + i) * 5;

      final startAngle = arcAngle - 0.3;
      final sweepAngle = 0.6;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: arcRadius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = const Color(0xFFffd090).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Subtle outer glow
    canvas.drawCircle(
      Offset(cx, cy),
      maxR * 0.6,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.transparent,
                const Color(0xFF604080).withValues(alpha: 0.1),
                Colors.transparent,
              ],
              stops: const [0.3, 0.6, 1.0],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: maxR * 0.6),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant _WormholePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
