// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Soap bubble iridescence.
class SoapBubbleAnimation extends StatefulWidget {
  const SoapBubbleAnimation({super.key});

  @override
  State<SoapBubbleAnimation> createState() => _SoapBubbleAnimationState();
}

class _SoapBubbleAnimationState extends State<SoapBubbleAnimation>
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
      builder: (context, child) => CustomPaint(
        painter: _SoapBubblePainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _SoapBubblePainter extends CustomPainter {
  _SoapBubblePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1a1a25), Color(0xFF252535)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final bubbles = [
      (x: size.width * 0.5, y: size.height * 0.5, r: 100.0),
      (x: size.width * 0.25, y: size.height * 0.35, r: 50.0),
      (x: size.width * 0.75, y: size.height * 0.65, r: 60.0),
      (x: size.width * 0.3, y: size.height * 0.7, r: 35.0),
    ];

    for (final b in bubbles) {
      final cx = b.x + sin(time + b.r) * 10;
      final cy = b.y + cos(time * 0.7 + b.r) * 8;

      for (var ring = 0; ring < 8; ring++) {
        final ringR = b.r * (0.5 + ring * 0.07);
        final hue = (ring * 45 + time * 30) % 360;
        canvas.drawCircle(
          Offset(cx, cy),
          ringR,
          Paint()
            ..color = HSVColor.fromAHSV(0.15, hue, 0.6, 0.9).toColor()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }

      canvas.drawCircle(
        Offset(cx, cy),
        b.r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.05)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );

      canvas.drawCircle(
        Offset(cx - b.r * 0.3, cy - b.r * 0.3),
        b.r * 0.15,
        Paint()..color = Colors.white.withValues(alpha: 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SoapBubblePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
