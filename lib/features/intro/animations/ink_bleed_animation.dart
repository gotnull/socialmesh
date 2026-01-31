// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Fluid ink bleeding through paper effect.
class InkBleedAnimation extends StatefulWidget {
  const InkBleedAnimation({super.key});

  @override
  State<InkBleedAnimation> createState() => _InkBleedAnimationState();
}

class _InkBleedAnimationState extends State<InkBleedAnimation>
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
      builder: (context, child) {
        return CustomPaint(
          painter: _InkBleedPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _InkBleedPainter extends CustomPainter {
  _InkBleedPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Paper texture background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF5F0E8),
    );

    // Paper grain
    final grainRandom = Random(55);
    for (var i = 0; i < 200; i++) {
      final gx = grainRandom.nextDouble() * size.width;
      final gy = grainRandom.nextDouble() * size.height;
      canvas.drawCircle(
        Offset(gx, gy),
        0.5 + grainRandom.nextDouble(),
        Paint()..color = const Color(0xFFE8E0D0).withValues(alpha: 0.5),
      );
    }

    final time = progress * 2 * pi;
    final inkRandom = Random(77);

    // Ink drops that bleed
    for (var drop = 0; drop < 6; drop++) {
      final dropProgress = (progress * 2 + drop * 0.15) % 1.0;
      final dropX = (inkRandom.nextDouble() * 0.6 + 0.2) * size.width;
      final dropY = (inkRandom.nextDouble() * 0.6 + 0.2) * size.height;

      // Ink colors
      final colors = [
        const Color(0xFF1a1a2e),
        const Color(0xFF16213e),
        const Color(0xFF0f3460),
        const Color(0xFF533483),
      ];
      final inkColor = colors[drop % colors.length];

      // Main ink blob expanding
      final mainRadius = 20 + dropProgress * 80;
      final blobPath = Path();

      for (var angle = 0.0; angle < 2 * pi; angle += 0.1) {
        final noise = sin(angle * 8 + time + drop) * 15 * dropProgress;
        final noise2 = cos(angle * 5 - time * 0.5) * 10 * dropProgress;
        final r = mainRadius + noise + noise2;

        final x = dropX + cos(angle) * r;
        final y = dropY + sin(angle) * r;

        if (angle == 0) {
          blobPath.moveTo(x, y);
        } else {
          blobPath.lineTo(x, y);
        }
      }
      blobPath.close();

      // Soft ink edge
      canvas.drawPath(
        blobPath,
        Paint()
          ..color = inkColor.withValues(alpha: 0.2 * dropProgress)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );

      // Main ink body
      canvas.drawPath(
        blobPath,
        Paint()
          ..color = inkColor.withValues(
            alpha: 0.6 * min(1.0, dropProgress * 2),
          ),
      );

      // Feathered edges (bleeding)
      for (var feather = 0; feather < 12; feather++) {
        final featherAngle = feather * pi / 6 + drop;
        final featherLength = (30 + inkRandom.nextDouble() * 40) * dropProgress;
        final featherWidth = 3 + inkRandom.nextDouble() * 5;

        final startR = mainRadius * 0.8;
        final fx1 = dropX + cos(featherAngle) * startR;
        final fy1 = dropY + sin(featherAngle) * startR;
        final fx2 = dropX + cos(featherAngle) * (startR + featherLength);
        final fy2 = dropY + sin(featherAngle) * (startR + featherLength);

        // Gradient feather
        canvas.drawLine(
          Offset(fx1, fy1),
          Offset(fx2, fy2),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                inkColor.withValues(alpha: 0.5 * dropProgress),
                inkColor.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromPoints(Offset(fx1, fy1), Offset(fx2, fy2)))
            ..strokeWidth = featherWidth
            ..strokeCap = StrokeCap.round,
        );
      }

      // Capillary spread
      for (var cap = 0; cap < 20; cap++) {
        final capAngle = inkRandom.nextDouble() * 2 * pi;
        final capDist = mainRadius + inkRandom.nextDouble() * 50 * dropProgress;
        final capSize = 2 + inkRandom.nextDouble() * 4;

        canvas.drawCircle(
          Offset(
            dropX + cos(capAngle) * capDist,
            dropY + sin(capAngle) * capDist,
          ),
          capSize * dropProgress,
          Paint()..color = inkColor.withValues(alpha: 0.3 * dropProgress),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _InkBleedPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
