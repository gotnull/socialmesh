import 'dart:math';

import 'package:flutter/material.dart';

/// Lichtenberg figure / electrical treeing.
class LichtenbergAnimation extends StatefulWidget {
  const LichtenbergAnimation({super.key});

  @override
  State<LichtenbergAnimation> createState() => _LichtenbergAnimationState();
}

class _LichtenbergAnimationState extends State<LichtenbergAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
        painter: _LichtenbergPainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _LichtenbergPainter extends CustomPainter {
  _LichtenbergPainter(this.progress);
  final double progress;

  void _drawBranch(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double len,
    int depth,
    Random r,
    double alpha,
  ) {
    if (depth <= 0 || len < 3) return;

    final endX = x + cos(angle) * len;
    final endY = y + sin(angle) * len;

    canvas.drawLine(
      Offset(x, y),
      Offset(endX, endY),
      Paint()
        ..color = const Color(0xFF80c0ff).withValues(alpha: alpha)
        ..strokeWidth = depth * 0.5,
    );

    final branches = 2 + r.nextInt(2);
    for (var i = 0; i < branches; i++) {
      final newAngle = angle + (r.nextDouble() - 0.5) * 1.2;
      final newLen = len * (0.6 + r.nextDouble() * 0.3);
      _drawBranch(
        canvas,
        endX,
        endY,
        newAngle,
        newLen,
        depth - 1,
        r,
        alpha * 0.85,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0a0810),
    );

    final phase = (progress * 3) % 1.0;
    final r = Random((progress * 5).floor());
    final alpha = phase < 0.1
        ? phase * 10
        : (phase < 0.3 ? 1.0 : max(0.0, 1 - (phase - 0.3) / 0.7));

    if (alpha > 0.05) {
      _drawBranch(
        canvas,
        size.width / 2,
        size.height * 0.1,
        pi / 2,
        60,
        8,
        r,
        alpha,
      );

      canvas.drawCircle(
        Offset(size.width / 2, size.height * 0.1),
        20 * alpha,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LichtenbergPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
