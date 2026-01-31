// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Looping hexagonal grid animation with pulsing cells.
class HexGridAnimation extends StatefulWidget {
  const HexGridAnimation({super.key});

  @override
  State<HexGridAnimation> createState() => _HexGridAnimationState();
}

class _HexGridAnimationState extends State<HexGridAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
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
          painter: _HexGridPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _HexGridPainter extends CustomPainter {
  _HexGridPainter({required this.progress});

  final double progress;

  Path _createHexPath(Offset center, double radius) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final angle = i * pi / 3 - pi / 6;
      final point = center + Offset(cos(angle) * radius, sin(angle) * radius);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    const accentColor = Color(0xFF00E5FF);
    const secondaryColor = Color(0xFF7C4DFF);
    const hexRadius = 35.0;

    final hexWidth = hexRadius * 2 * cos(pi / 6);
    final hexHeight = hexRadius * 1.5;

    final cols = (size.width / hexWidth + 2).ceil();
    final rows = (size.height / hexHeight + 2).ceil();

    for (var row = -1; row < rows; row++) {
      for (var col = -1; col < cols; col++) {
        final offsetX = row.isOdd ? hexWidth / 2 : 0.0;
        final center = Offset(col * hexWidth + offsetX, row * hexHeight);

        // Calculate distance from center for wave effect
        final screenCenter = Offset(size.width / 2, size.height / 2);
        final distance = (center - screenCenter).distance;
        final maxDistance = (screenCenter - Offset.zero).distance;
        final normalizedDistance = distance / maxDistance;

        // Wave pulse
        final wavePhase = (progress * 2 - normalizedDistance + 1) % 1.0;
        final pulse = sin(wavePhase * pi);
        final alpha = 0.1 + pulse.clamp(0.0, 1.0) * 0.25;

        final hexPath = _createHexPath(center, hexRadius - 2);

        // Fill with gradient alpha
        final isAccent = (row + col) % 3 == 0;
        final color = isAccent ? accentColor : secondaryColor;
        final fillPaint = Paint()
          ..color = color.withValues(alpha: alpha * 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawPath(hexPath, fillPaint);

        // Border
        final borderPaint = Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawPath(hexPath, borderPaint);

        // Highlight active hexes
        if (pulse > 0.8) {
          final glowPaint = Paint()
            ..color = color.withValues(alpha: 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
          canvas.drawPath(hexPath, glowPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HexGridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
