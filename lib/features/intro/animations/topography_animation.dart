// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Topographic map with elevation contours.
class TopographyAnimation extends StatefulWidget {
  const TopographyAnimation({super.key});

  @override
  State<TopographyAnimation> createState() => _TopographyAnimationState();
}

class _TopographyAnimationState extends State<TopographyAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
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
          painter: _TopographyPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _TopographyPainter extends CustomPainter {
  _TopographyPainter(this.progress);

  final double progress;

  double _noise(double x, double y, double time) {
    return sin(x * 0.02 + time) * cos(y * 0.015 - time * 0.5) +
        sin(x * 0.01 - y * 0.01 + time * 0.3) * 0.5 +
        cos(x * 0.03 + y * 0.02 + time * 0.2) * 0.3;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;

    // Paper background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFF5F2E8),
    );

    // Draw contour lines
    const contourLevels = 20;
    const step = 8.0;

    for (var level = 0; level < contourLevels; level++) {
      final threshold = -1.5 + level * 0.2;
      final isMainContour = level % 5 == 0;

      // Determine color based on elevation
      final elevation = level / contourLevels;
      Color lineColor;
      if (elevation < 0.3) {
        lineColor = Color.lerp(
          const Color(0xFF2a6d4f),
          const Color(0xFF4a8f6f),
          elevation / 0.3,
        )!;
      } else if (elevation < 0.7) {
        lineColor = Color.lerp(
          const Color(0xFF8b7355),
          const Color(0xFFa08060),
          (elevation - 0.3) / 0.4,
        )!;
      } else {
        lineColor = Color.lerp(
          const Color(0xFF806050),
          const Color(0xFF604030),
          (elevation - 0.7) / 0.3,
        )!;
      }

      // March squares to find contour
      for (var y = 0.0; y < size.height; y += step) {
        for (var x = 0.0; x < size.width; x += step) {
          final v00 = _noise(x, y, time);
          final v10 = _noise(x + step, y, time);
          final v01 = _noise(x, y + step, time);
          final v11 = _noise(x + step, y + step, time);

          // Check if contour crosses this cell
          final above00 = v00 > threshold;
          final above10 = v10 > threshold;
          final above01 = v01 > threshold;
          final above11 = v11 > threshold;

          if (above00 == above10 && above10 == above01 && above01 == above11) {
            continue;
          }

          // Find crossing points
          final crossings = <Offset>[];

          if (above00 != above10) {
            final t = (threshold - v00) / (v10 - v00);
            crossings.add(Offset(x + t * step, y));
          }
          if (above10 != above11) {
            final t = (threshold - v10) / (v11 - v10);
            crossings.add(Offset(x + step, y + t * step));
          }
          if (above01 != above11) {
            final t = (threshold - v01) / (v11 - v01);
            crossings.add(Offset(x + t * step, y + step));
          }
          if (above00 != above01) {
            final t = (threshold - v00) / (v01 - v00);
            crossings.add(Offset(x, y + t * step));
          }

          if (crossings.length >= 2) {
            canvas.drawLine(
              crossings[0],
              crossings[1],
              Paint()
                ..color = lineColor.withValues(
                  alpha: isMainContour ? 0.7 : 0.35,
                )
                ..strokeWidth = isMainContour ? 1.5 : 0.8,
            );
          }
        }
      }
    }

    // Grid lines (light)
    for (var x = 0.0; x < size.width; x += 50) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        Paint()
          ..color = const Color(0xFFc0b8a0).withValues(alpha: 0.3)
          ..strokeWidth = 0.5,
      );
    }
    for (var y = 0.0; y < size.height; y += 50) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFFc0b8a0).withValues(alpha: 0.3)
          ..strokeWidth = 0.5,
      );
    }

    // Peak markers
    final peaks = [
      Offset(size.width * 0.3, size.height * 0.4),
      Offset(size.width * 0.7, size.height * 0.6),
      Offset(size.width * 0.5, size.height * 0.3),
    ];

    for (final peak in peaks) {
      // Triangle marker
      final path = Path()
        ..moveTo(peak.dx, peak.dy - 8)
        ..lineTo(peak.dx - 5, peak.dy + 4)
        ..lineTo(peak.dx + 5, peak.dy + 4)
        ..close();

      canvas.drawPath(path, Paint()..color = const Color(0xFF604030));
    }

    // Compass rose hint
    final compassX = size.width - 50.0;
    final compassY = size.height - 50.0;
    canvas.drawLine(
      Offset(compassX, compassY - 20),
      Offset(compassX, compassY + 20),
      Paint()
        ..color = const Color(0xFF604030).withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(compassX - 20, compassY),
      Offset(compassX + 20, compassY),
      Paint()
        ..color = const Color(0xFF604030).withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'N',
        style: TextStyle(
          color: const Color(0xFF604030).withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(compassX - 4, compassY - 35));
  }

  @override
  bool shouldRepaint(covariant _TopographyPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
