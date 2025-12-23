import 'dart:math';

import 'package:flutter/material.dart';

/// Clean synthwave grid - modern vaporwave aesthetic.
class Mode7RacingAnimation extends StatefulWidget {
  const Mode7RacingAnimation({super.key});

  @override
  State<Mode7RacingAnimation> createState() => _Mode7RacingAnimationState();
}

class _Mode7RacingAnimationState extends State<Mode7RacingAnimation>
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
          painter: _Mode7Painter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Mode7Painter extends CustomPainter {
  _Mode7Painter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final horizon = size.height * 0.45;

    // Sky gradient - rich purples to warm pink
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0d0221),
          Color(0xFF1a0533),
          Color(0xFF3d1a4d),
          Color(0xFFc94b7c),
        ],
        stops: [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, horizon));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, horizon), skyPaint);

    // Retro sun with horizontal lines
    final sunCenter = Offset(size.width / 2, horizon);
    final sunRadius = min(size.width, size.height) * 0.18;

    // Sun gradient
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFffd54f),
          const Color(0xFFff8a65),
          const Color(0xFFc94b7c),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));

    // Clip sun to above horizon
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, horizon));
    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Sun stripes
    for (var i = 0; i < 8; i++) {
      final stripeY =
          sunCenter.dy - sunRadius + sunRadius * 0.3 + i * sunRadius * 0.12;
      final stripeWidth =
          sqrt(pow(sunRadius, 2) - pow(stripeY - sunCenter.dy, 2).abs()) * 2;
      if (stripeWidth > 0 && stripeY < horizon) {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(sunCenter.dx, stripeY),
            width: stripeWidth,
            height: 4,
          ),
          Paint()..color = const Color(0xFF0d0221),
        );
      }
    }
    canvas.restore();

    // Ground
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      Paint()..color = const Color(0xFF0d0221),
    );

    // Perspective grid
    final centerX = size.width / 2;
    final gridColor = const Color(0xFFc94b7c);

    // Horizontal lines
    final scrollOffset = progress * 200;
    for (var i = 0; i < 25; i++) {
      final t = i / 25;
      final y = horizon + pow(t, 1.8) * (size.height - horizon);
      final adjustedY = y + (scrollOffset % ((size.height - horizon) / 15));

      if (adjustedY > horizon && adjustedY < size.height) {
        final alpha = (t * 0.6).clamp(0.05, 0.5);
        canvas.drawLine(
          Offset(0, adjustedY),
          Offset(size.width, adjustedY),
          Paint()
            ..color = gridColor.withValues(alpha: alpha)
            ..strokeWidth = 1,
        );
      }
    }

    // Vertical lines converging to horizon
    for (var i = -12; i <= 12; i++) {
      final bottomX = centerX + i * (size.width / 12);
      final alpha = (1 - i.abs() / 12 * 0.7).clamp(0.1, 0.4);

      canvas.drawLine(
        Offset(bottomX, size.height),
        Offset(centerX, horizon),
        Paint()
          ..color = gridColor.withValues(alpha: alpha)
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Mode7Painter oldDelegate) =>
      oldDelegate.progress != progress;
}
