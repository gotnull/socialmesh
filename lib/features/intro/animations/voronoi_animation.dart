// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Voronoi diagram with moving seeds.
class VoronoiAnimation extends StatefulWidget {
  const VoronoiAnimation({super.key});

  @override
  State<VoronoiAnimation> createState() => _VoronoiAnimationState();
}

class _VoronoiAnimationState extends State<VoronoiAnimation>
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
      builder: (context, child) => CustomPaint(
        painter: _VoronoiPainter(_controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _VoronoiPainter extends CustomPainter {
  _VoronoiPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    final r = Random(42);

    final seeds = List.generate(20, (i) {
      final baseX = r.nextDouble() * size.width;
      final baseY = r.nextDouble() * size.height;
      return Offset(
        baseX + sin(time + i * 0.5) * 30,
        baseY + cos(time * 0.7 + i * 0.3) * 30,
      );
    });

    const step = 6.0;
    for (var y = 0.0; y < size.height; y += step) {
      for (var x = 0.0; x < size.width; x += step) {
        var minDist = double.infinity;
        var minDist2 = double.infinity;
        var closest = 0;

        for (var i = 0; i < seeds.length; i++) {
          final d = (Offset(x, y) - seeds[i]).distance;
          if (d < minDist) {
            minDist2 = minDist;
            minDist = d;
            closest = i;
          } else if (d < minDist2) {
            minDist2 = d;
          }
        }

        final edge = (minDist2 - minDist) < 4;
        final hue = (closest * 18.0) % 360;
        final color = edge
            ? const Color(0xFF202030)
            : HSVColor.fromAHSV(0.7, hue, 0.5, 0.3 + minDist * 0.002).toColor();

        canvas.drawRect(
          Rect.fromLTWH(x, y, step, step),
          Paint()..color = color,
        );
      }
    }

    for (final s in seeds) {
      canvas.drawCircle(
        s,
        3,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VoronoiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
