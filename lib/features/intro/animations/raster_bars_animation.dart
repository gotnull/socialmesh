// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Classic Amiga-style horizontal raster bars effect.
class RasterBarsAnimation extends StatefulWidget {
  const RasterBarsAnimation({super.key});

  @override
  State<RasterBarsAnimation> createState() => _RasterBarsAnimationState();
}

class _RasterBarsAnimationState extends State<RasterBarsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
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
          painter: _RasterBarsPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _RasterBarsPainter extends CustomPainter {
  _RasterBarsPainter({required this.progress});

  final double progress;

  // Classic Amiga palette
  static const List<Color> _barColors = [
    Color(0xFFFF0000),
    Color(0xFFFF4400),
    Color(0xFFFF8800),
    Color(0xFFFFCC00),
    Color(0xFFFFFF00),
    Color(0xFFCCFF00),
    Color(0xFF88FF00),
    Color(0xFF44FF00),
    Color(0xFF00FF00),
    Color(0xFF00FF44),
    Color(0xFF00FF88),
    Color(0xFF00FFCC),
    Color(0xFF00FFFF),
    Color(0xFF00CCFF),
    Color(0xFF0088FF),
    Color(0xFF0044FF),
    Color(0xFF0000FF),
    Color(0xFF4400FF),
    Color(0xFF8800FF),
    Color(0xFFCC00FF),
    Color(0xFFFF00FF),
    Color(0xFFFF00CC),
    Color(0xFFFF0088),
    Color(0xFFFF0044),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    const barHeight = 12.0;
    const barCount = 8;

    // Draw multiple bars with sine wave movement
    for (var b = 0; b < barCount; b++) {
      final phase = b * 0.3;
      final baseY = size.height / 2 + sin(time + phase) * (size.height * 0.35);

      // Each bar has a gradient of colors
      for (var i = 0; i < _barColors.length; i++) {
        final offset = (i - _barColors.length / 2) * 2;
        final y = baseY + offset;

        // Intensity falloff from center
        final centerDist =
            (i - _barColors.length / 2).abs() / (_barColors.length / 2);
        final alpha = (1.0 - centerDist * 0.5).clamp(0.3, 1.0);

        final paint = Paint()
          ..color =
              _barColors[(i + (progress * 50).floor()) % _barColors.length]
                  .withValues(alpha: alpha * 0.8);

        canvas.drawRect(Rect.fromLTWH(0, y, size.width, 2), paint);
      }

      // Add glow effect
      final glowPaint = Paint()
        ..color =
            _barColors[(b * 3 + (progress * 30).floor()) % _barColors.length]
                .withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRect(
        Rect.fromLTWH(0, baseY - barHeight, size.width, barHeight * 2),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RasterBarsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
