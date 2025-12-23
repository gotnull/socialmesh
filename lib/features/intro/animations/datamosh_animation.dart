import 'dart:math';

import 'package:flutter/material.dart';

/// Glitch art with datamosh effect.
class DatamoshAnimation extends StatefulWidget {
  const DatamoshAnimation({super.key});

  @override
  State<DatamoshAnimation> createState() => _DatamoshAnimationState();
}

class _DatamoshAnimationState extends State<DatamoshAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
          painter: _DatamoshPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _DatamoshPainter extends CustomPainter {
  _DatamoshPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    final r = Random((progress * 10).floor());

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF101015),
    );

    for (var i = 0; i < 20; i++) {
      final y = r.nextDouble() * size.height;
      final h = 5 + r.nextDouble() * 30;
      final shift = sin(time + i) * 50 * r.nextDouble();
      final hue = r.nextDouble() * 360;

      canvas.drawRect(
        Rect.fromLTWH(shift, y, size.width, h),
        Paint()..color = HSVColor.fromAHSV(0.6, hue, 0.8, 0.7).toColor(),
      );
    }

    for (var i = 0; i < 8; i++) {
      final bx = r.nextDouble() * size.width;
      final by = r.nextDouble() * size.height;
      final bw = 30 + r.nextDouble() * 100;
      final bh = 20 + r.nextDouble() * 60;

      canvas.drawRect(
        Rect.fromLTWH(bx, by, bw, bh),
        Paint()
          ..color = Color.fromRGBO(
            r.nextInt(255),
            r.nextInt(255),
            r.nextInt(255),
            0.7,
          )
          ..blendMode = BlendMode.difference,
      );
    }

    for (var y = 0.0; y < size.height; y += 2) {
      if (r.nextDouble() > 0.95) {
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          Paint()..color = Colors.white.withValues(alpha: 0.1),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DatamoshPainter oldDelegate) => true;
}
