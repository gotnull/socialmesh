import 'dart:math';

import 'package:flutter/material.dart';

/// Fractal tree growing animation.
class FractalTreeAnimation extends StatefulWidget {
  const FractalTreeAnimation({super.key});

  @override
  State<FractalTreeAnimation> createState() => _FractalTreeAnimationState();
}

class _FractalTreeAnimationState extends State<FractalTreeAnimation>
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
          painter: _FractalTreePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _FractalTreePainter extends CustomPainter {
  _FractalTreePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final startX = size.width / 2;
    final startY = size.height * 0.9;
    final time = progress * 2 * pi;

    // Animated branch angle
    final branchAngle = 0.4 + sin(time) * 0.15;

    // Draw multiple trees with different colors
    _drawTree(
      canvas,
      startX - size.width * 0.2,
      startY,
      -pi / 2,
      size.height * 0.15,
      8,
      branchAngle,
      const Color(0xFF00FFFF),
      time,
    );

    _drawTree(
      canvas,
      startX + size.width * 0.2,
      startY,
      -pi / 2,
      size.height * 0.15,
      8,
      branchAngle + 0.1,
      const Color(0xFFFF00FF),
      time + pi / 3,
    );

    _drawTree(
      canvas,
      startX,
      startY,
      -pi / 2,
      size.height * 0.18,
      9,
      branchAngle - 0.05,
      const Color(0xFFFFFF00),
      time + 2 * pi / 3,
    );
  }

  void _drawTree(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double length,
    int depth,
    double branchAngle,
    Color color,
    double time,
  ) {
    if (depth <= 0 || length < 2) return;

    // Calculate end point
    final endX = x + cos(angle) * length;
    final endY = y + sin(angle) * length;

    // Branch sway
    final sway = sin(time * 2 + depth * 0.5) * 0.05;

    // Draw branch
    final alpha = (depth / 9).clamp(0.3, 1.0);
    final thickness = (depth * 0.8).clamp(1.0, 6.0);

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(x, y), Offset(endX, endY), paint);

    // Glow for tips
    if (depth <= 3) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(Offset(endX, endY), 4, glowPaint);
    }

    // Recursive branches
    final newLength = length * 0.72;
    final leftAngle = angle - branchAngle + sway;
    final rightAngle = angle + branchAngle + sway;

    _drawTree(
      canvas,
      endX,
      endY,
      leftAngle,
      newLength,
      depth - 1,
      branchAngle,
      color,
      time,
    );
    _drawTree(
      canvas,
      endX,
      endY,
      rightAngle,
      newLength,
      depth - 1,
      branchAngle,
      color,
      time,
    );

    // Sometimes add a middle branch
    if (depth > 4 && depth % 2 == 0) {
      _drawTree(
        canvas,
        endX,
        endY,
        angle + sway,
        newLength * 0.8,
        depth - 2,
        branchAngle,
        color,
        time,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FractalTreePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
