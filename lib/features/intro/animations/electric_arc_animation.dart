import 'dart:math';

import 'package:flutter/material.dart';

/// Electric arc / lightning effect animation.
class ElectricArcAnimation extends StatefulWidget {
  const ElectricArcAnimation({super.key});

  @override
  State<ElectricArcAnimation> createState() => _ElectricArcAnimationState();
}

class _ElectricArcAnimationState extends State<ElectricArcAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _random = Random();
  int _seed = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();

    _controller.addListener(() {
      if (_random.nextDouble() < 0.3) {
        _seed = _random.nextInt(10000);
      }
    });
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
          painter: _ElectricArcPainter(seed: _seed),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ElectricArcPainter extends CustomPainter {
  _ElectricArcPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);

    // Multiple arc sources
    final sources = [
      (x: size.width * 0.2, y: size.height * 0.2),
      (x: size.width * 0.8, y: size.height * 0.2),
      (x: size.width * 0.5, y: size.height * 0.1),
      (x: size.width * 0.2, y: size.height * 0.8),
      (x: size.width * 0.8, y: size.height * 0.8),
    ];

    final targets = [
      (x: size.width * 0.5, y: size.height * 0.5),
      (x: size.width * 0.3, y: size.height * 0.6),
      (x: size.width * 0.7, y: size.height * 0.6),
    ];

    // Draw arcs between random source-target pairs
    for (var i = 0; i < 6; i++) {
      final source = sources[random.nextInt(sources.length)];
      final target = targets[random.nextInt(targets.length)];

      _drawLightning(
        canvas,
        source.x,
        source.y,
        target.x,
        target.y,
        random,
        4,
        const Color(0xFF00CCFF),
      );
    }

    // Draw some arcs that go across the screen
    for (var i = 0; i < 3; i++) {
      final startY = random.nextDouble() * size.height;
      final endY = random.nextDouble() * size.height;

      _drawLightning(
        canvas,
        0,
        startY,
        size.width,
        endY,
        random,
        3,
        const Color(0xFFFF00FF),
      );
    }

    // Central energy orb
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Outer glow
    final outerGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF00FFFF).withValues(alpha: 0.3),
              const Color(0xFF0066FF).withValues(alpha: 0.1),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: 100),
          );
    canvas.drawCircle(Offset(centerX, centerY), 100, outerGlow);

    // Inner orb
    final innerOrb = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.9),
              const Color(0xFF00FFFF).withValues(alpha: 0.6),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(centerX, centerY), radius: 30),
          );
    canvas.drawCircle(Offset(centerX, centerY), 30, innerOrb);
  }

  void _drawLightning(
    Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    Random random,
    int depth,
    Color color,
  ) {
    if (depth <= 0) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
      return;
    }

    // Calculate midpoint with random offset
    final midX = (x1 + x2) / 2;
    final midY = (y1 + y2) / 2;

    final dx = x2 - x1;
    final dy = y2 - y1;
    final len = sqrt(dx * dx + dy * dy);

    // Perpendicular offset
    final offset = (random.nextDouble() - 0.5) * len * 0.4;
    final perpX = -dy / len;
    final perpY = dx / len;

    final newMidX = midX + perpX * offset;
    final newMidY = midY + perpY * offset;

    // Recurse
    _drawLightning(canvas, x1, y1, newMidX, newMidY, random, depth - 1, color);
    _drawLightning(canvas, newMidX, newMidY, x2, y2, random, depth - 1, color);

    // Draw glow at depth transitions
    if (depth == 2) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
    }

    // Random branching
    if (depth > 1 && random.nextDouble() < 0.3) {
      final branchAngle = (random.nextDouble() - 0.5) * pi;
      final branchLen = len * 0.3;
      final branchEndX = newMidX + cos(branchAngle) * branchLen;
      final branchEndY = newMidY + sin(branchAngle) * branchLen;

      _drawLightning(
        canvas,
        newMidX,
        newMidY,
        branchEndX,
        branchEndY,
        random,
        depth - 2,
        color.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ElectricArcPainter oldDelegate) =>
      oldDelegate.seed != seed;
}
