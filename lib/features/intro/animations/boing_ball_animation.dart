import 'dart:math';

import 'package:flutter/material.dart';

/// Classic Amiga-style boing ball bouncing animation.
class BoingBallAnimation extends StatefulWidget {
  const BoingBallAnimation({super.key});

  @override
  State<BoingBallAnimation> createState() => _BoingBallAnimationState();
}

class _BoingBallAnimationState extends State<BoingBallAnimation>
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
          painter: _BoingBallPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _BoingBallPainter extends CustomPainter {
  _BoingBallPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final time = progress * 2 * pi;

    // Ball bouncing motion
    final bounceY = size.height * 0.5 - sin(time * 2).abs() * size.height * 0.3;
    final ballRadius = min(size.width, size.height) * 0.2;

    // Ball rotation for stripe effect
    final rotation = progress * 4 * pi;

    // Draw grid background
    final gridPaint = Paint()
      ..color = const Color(0xFF333366)
      ..strokeWidth = 2;

    for (var x = 0.0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = 0.0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Ball X position oscillation
    final ballX = centerX + sin(time) * size.width * 0.25;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    final shadowY = size.height * 0.85;
    final shadowScale = 1 - (shadowY - bounceY) / (size.height * 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(ballX, shadowY),
        width: ballRadius * 2 * shadowScale,
        height: ballRadius * 0.4 * shadowScale,
      ),
      shadowPaint,
    );

    // Draw ball with red/white stripes
    canvas.save();
    canvas.translate(ballX, bounceY);

    // Clip to circle
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: ballRadius));
    canvas.clipPath(clipPath);

    // Draw stripes
    const stripeCount = 8;
    for (var i = 0; i < stripeCount * 2; i++) {
      final stripeAngle = (i / stripeCount) * pi + rotation;
      final stripeX = cos(stripeAngle) * ballRadius * 2;

      final stripePaint = Paint()
        ..color = i % 2 == 0 ? const Color(0xFFFF0000) : Colors.white;

      canvas.drawRect(
        Rect.fromLTWH(
          stripeX - ballRadius * 0.3,
          -ballRadius,
          ballRadius * 0.6,
          ballRadius * 2,
        ),
        stripePaint,
      );
    }

    canvas.restore();

    // Ball outline and highlight
    final outlinePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(ballX, bounceY), ballRadius, outlinePaint);

    // Specular highlight
    final highlightPaint = Paint()
      ..shader =
          RadialGradient(
            center: const Alignment(-0.3, -0.3),
            colors: [Colors.white.withValues(alpha: 0.6), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: Offset(ballX, bounceY), radius: ballRadius),
          );
    canvas.drawCircle(Offset(ballX, bounceY), ballRadius, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BoingBallPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
