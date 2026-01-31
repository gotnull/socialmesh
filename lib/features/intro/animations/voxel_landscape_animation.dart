// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Classic voxel landscape / heightmap terrain effect.
class VoxelLandscapeAnimation extends StatefulWidget {
  const VoxelLandscapeAnimation({super.key});

  @override
  State<VoxelLandscapeAnimation> createState() =>
      _VoxelLandscapeAnimationState();
}

class _VoxelLandscapeAnimationState extends State<VoxelLandscapeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
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
          painter: _VoxelLandscapePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _VoxelLandscapePainter extends CustomPainter {
  _VoxelLandscapePainter({required this.progress});

  final double progress;

  double _heightAt(double x, double z, double time) {
    // Perlin-like noise simulation
    return sin(x * 0.1 + time) * cos(z * 0.1 + time * 0.7) * 40 +
        sin(x * 0.05 + z * 0.05 + time * 0.5) * 20;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final time = progress * 2 * pi;
    final centerX = size.width / 2;
    final horizon = size.height * 0.35;

    // Sky gradient
    final skyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF000033),
        const Color(0xFF000066),
        const Color(0xFF330066),
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, horizon));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, horizon),
      Paint()..shader = skyGradient,
    );

    // Draw terrain from back to front
    const gridSize = 8.0;
    const depth = 40;
    final scrollZ = progress * 200;

    for (var z = depth; z >= 1; z--) {
      final zPos = z * gridSize + scrollZ;
      final perspective = 200 / (z * gridSize);

      for (var x = -30; x <= 30; x++) {
        final xPos = x * gridSize;
        final height = _heightAt(xPos, zPos, time);

        // Project to screen
        final screenX = centerX + xPos * perspective;
        final screenY = horizon + z * 8 - height * perspective;

        if (screenX < -20 || screenX > size.width + 20) continue;
        if (screenY > size.height) continue;

        // Color based on height and distance
        final heightNorm = (height + 60) / 120;
        final distFade = 1 - z / depth;
        final hue = 120 + heightNorm * 60 + progress * 60;

        final color = HSVColor.fromAHSV(
          1.0,
          hue % 360,
          0.7,
          (0.3 + heightNorm * 0.5) * distFade,
        ).toColor();

        // Draw column
        final columnHeight = max(2.0, (60 - height) * perspective * 0.5);
        final columnWidth = gridSize * perspective * 0.8;

        final paint = Paint()..color = color;
        canvas.drawRect(
          Rect.fromLTWH(
            screenX - columnWidth / 2,
            screenY,
            columnWidth,
            columnHeight,
          ),
          paint,
        );

        // Top highlight
        final topPaint = Paint()
          ..color = color.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawRect(
          Rect.fromLTWH(screenX - columnWidth / 2, screenY, columnWidth, 2),
          topPaint,
        );
      }
    }

    // Sun/moon
    final sunX = centerX + sin(time * 0.3) * size.width * 0.3;
    final sunY = 60 + cos(time * 0.3) * 30;
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, const Color(0xFFFFCC00), Colors.transparent],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(sunX, sunY), radius: 50));
    canvas.drawCircle(Offset(sunX, sunY), 40, sunPaint);
  }

  @override
  bool shouldRepaint(covariant _VoxelLandscapePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
