import 'dart:math';

import 'package:flutter/material.dart';

/// Clean infinite tunnel with depth.
class CyberCorridorAnimation extends StatefulWidget {
  const CyberCorridorAnimation({super.key});

  @override
  State<CyberCorridorAnimation> createState() => _CyberCorridorAnimationState();
}

class _CyberCorridorAnimationState extends State<CyberCorridorAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
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
          painter: _CyberCorridorPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _CyberCorridorPainter extends CustomPainter {
  _CyberCorridorPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Void background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF030306),
    );

    // Tunnel segments
    const segmentCount = 24;

    for (var i = segmentCount - 1; i >= 0; i--) {
      var depth = (i / segmentCount + progress) % 1.0;
      depth = pow(depth, 0.6).toDouble();

      final scale = 0.02 + depth * 0.98;
      final w = size.width * 0.55 * scale;
      final h = size.height * 0.55 * scale;

      // Color shifts through cool spectrum
      final hue = (200 + depth * 60 + progress * 120) % 360;
      final sat = 0.5 + depth * 0.3;
      final val = 0.4 + depth * 0.5;
      final color = HSVColor.fromAHSV(1.0, hue, sat, val).toColor();
      final alpha = (depth * 0.7).clamp(0.05, 0.6);

      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: w * 2,
        height: h * 2,
      );

      // Frame
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + depth * 1.5,
      );

      // Corner details
      final cornerSize = 8 * scale;
      final corners = [
        Offset(cx - w, cy - h),
        Offset(cx + w, cy - h),
        Offset(cx - w, cy + h),
        Offset(cx + w, cy + h),
      ];

      for (final corner in corners) {
        canvas.drawCircle(
          corner,
          cornerSize,
          Paint()..color = color.withValues(alpha: alpha * 0.5),
        );
      }
    }

    // Central glow
    canvas.drawCircle(
      Offset(cx, cy),
      30,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.4),
            const Color(0xFF60a0ff).withValues(alpha: 0.2),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 30)),
    );

    // Floating particles
    final random = Random(42);
    for (var i = 0; i < 40; i++) {
      final pProgress = (progress + i / 40) % 1.0;
      final pDepth = pow(pProgress, 0.5);

      final angle = random.nextDouble() * 2 * pi;
      final dist = pDepth.toDouble() * min(size.width, size.height) * 0.4;

      final px = cx + cos(angle) * dist;
      final py = cy + sin(angle) * dist;
      final pAlpha = (pDepth * 0.6).clamp(0.0, 0.5);
      final pSize = 1 + pDepth.toDouble() * 2;

      canvas.drawCircle(
        Offset(px, py),
        pSize,
        Paint()..color = const Color(0xFF80c0ff).withValues(alpha: pAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CyberCorridorPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
