// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Impossible geometry / Escher style.
class EscherAnimation extends StatefulWidget {
  const EscherAnimation({super.key});

  @override
  State<EscherAnimation> createState() => _EscherAnimationState();
}

class _EscherAnimationState extends State<EscherAnimation>
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
      builder: (context, child) => CustomPaint(
        painter: _EscherPainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _EscherPainter extends CustomPainter {
  _EscherPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF0EDE5),
    );

    // Penrose triangle
    final triSize = min(size.width, size.height) * 0.35;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(time * 0.2);

    final colors = [
      const Color(0xFF404050),
      const Color(0xFF606070),
      const Color(0xFF505060),
    ];
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.rotate(i * 2 * pi / 3);

      final path = Path()
        ..moveTo(0, -triSize)
        ..lineTo(triSize * 0.3, -triSize * 0.5)
        ..lineTo(triSize * 0.3, triSize * 0.2)
        ..lineTo(0, triSize * 0.4)
        ..lineTo(-triSize * 0.15, triSize * 0.1)
        ..lineTo(-triSize * 0.15, -triSize * 0.6)
        ..close();

      canvas.drawPath(path, Paint()..color = colors[i]);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF303040)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.restore();
    }
    canvas.restore();

    // Impossible stairs hint
    for (var step = 0; step < 8; step++) {
      final angle = step * pi / 4 + time * 0.3;
      final r = 30 + step * 10.0;
      final x = cx + cos(angle) * r * 2;
      final y = cy + 120 + sin(angle) * r * 0.3;
      final w = 25.0;
      final h = 15 - step * 0.5;

      canvas.drawRect(
        Rect.fromLTWH(x - w / 2, y - h / 2, w, h),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF505060),
            const Color(0xFF808090),
            step / 8,
          )!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EscherPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
