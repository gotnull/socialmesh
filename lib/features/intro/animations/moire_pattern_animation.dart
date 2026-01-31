// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Classic moire pattern interference effect.
class MoirePatternAnimation extends StatefulWidget {
  const MoirePatternAnimation({super.key});

  @override
  State<MoirePatternAnimation> createState() => _MoirePatternAnimationState();
}

class _MoirePatternAnimationState extends State<MoirePatternAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10000),
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
          painter: _MoirePatternPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MoirePatternPainter extends CustomPainter {
  _MoirePatternPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final time = progress * 2 * pi;
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);

    // First set of concentric circles
    final center1 = Offset(
      centerX + sin(time) * size.width * 0.2,
      centerY + cos(time) * size.height * 0.2,
    );

    // Second set of concentric circles (offset and moving opposite)
    final center2 = Offset(
      centerX + sin(time + pi) * size.width * 0.15,
      centerY + cos(time * 1.3) * size.height * 0.15,
    );

    // Draw concentric circles for moire effect
    const spacing = 8.0;
    final paint1 = Paint()
      ..color = const Color(0xFF00FFFF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paint2 = Paint()
      ..color = const Color(0xFFFF00FF).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (var r = spacing; r < maxRadius; r += spacing) {
      canvas.drawCircle(center1, r, paint1);
      canvas.drawCircle(center2, r, paint2);
    }

    // Third pattern - rotating lines
    final paint3 = Paint()
      ..color = const Color(0xFFFFFF00).withValues(alpha: 0.3)
      ..strokeWidth = 2;

    final lineAngle = time * 0.5;
    const lineSpacing = 12.0;

    for (var i = -maxRadius; i < maxRadius; i += lineSpacing) {
      final dx = cos(lineAngle);
      final dy = sin(lineAngle);
      final perpX = -dy;
      final perpY = dx;

      final startX = centerX + perpX * i - dx * maxRadius;
      final startY = centerY + perpY * i - dy * maxRadius;
      final endX = centerX + perpX * i + dx * maxRadius;
      final endY = centerY + perpY * i + dy * maxRadius;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint3);
    }
  }

  @override
  bool shouldRepaint(covariant _MoirePatternPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
