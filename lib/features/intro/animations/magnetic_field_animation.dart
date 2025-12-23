import 'dart:math';

import 'package:flutter/material.dart';

/// Magnetic field lines visualization.
class MagneticFieldAnimation extends StatefulWidget {
  const MagneticFieldAnimation({super.key});

  @override
  State<MagneticFieldAnimation> createState() => _MagneticFieldAnimationState();
}

class _MagneticFieldAnimationState extends State<MagneticFieldAnimation>
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
        painter: _MagneticFieldPainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _MagneticFieldPainter extends CustomPainter {
  _MagneticFieldPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF080810),
    );

    final pole1 = Offset(size.width * 0.3, size.height / 2);
    final pole2 = Offset(size.width * 0.7, size.height / 2);

    for (final pole in [pole1, pole2]) {
      canvas.drawCircle(pole, 15, Paint()..color = const Color(0xFF4060a0));
      canvas.drawCircle(pole, 10, Paint()..color = const Color(0xFF6080c0));
    }

    for (var line = 0; line < 16; line++) {
      final startAngle = line * pi / 8;
      final path = Path();
      var px = pole1.dx + cos(startAngle) * 20;
      var py = pole1.dy + sin(startAngle) * 20;
      path.moveTo(px, py);

      for (var step = 0; step < 200; step++) {
        final d1 = Offset(px - pole1.dx, py - pole1.dy);
        final d2 = Offset(px - pole2.dx, py - pole2.dy);
        final r1 = d1.distance + 1;
        final r2 = d2.distance + 1;

        var bx = d1.dx / (r1 * r1 * r1) - d2.dx / (r2 * r2 * r2);
        var by = d1.dy / (r1 * r1 * r1) - d2.dy / (r2 * r2 * r2);
        final bMag = sqrt(bx * bx + by * by) + 0.001;
        bx /= bMag;
        by /= bMag;

        px += bx * 5;
        py += by * 5;
        path.lineTo(px, py);

        if (r2 < 25) break;
        if (px < 0 || px > size.width || py < 0 || py > size.height) break;
      }

      final alpha = 0.3 + sin(time + line * 0.3) * 0.2;
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF60a0ff).withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MagneticFieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
