// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Spinning torus / donut 3D effect.
class TorusAnimation extends StatefulWidget {
  const TorusAnimation({super.key});

  @override
  State<TorusAnimation> createState() => _TorusAnimationState();
}

class _TorusAnimationState extends State<TorusAnimation>
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
          painter: _TorusPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _TorusPainter extends CustomPainter {
  _TorusPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final time = progress * 2 * pi;

    // Torus parameters scaled to screen
    final majorRadius = min(size.width, size.height) * 0.25;
    final minorRadius = majorRadius * 0.35;

    // Rotation angles
    final rotX = time * 0.7;
    final rotY = time;
    final rotZ = time * 0.3;

    // Generate torus points
    final points = <_TorusPoint>[];
    const majorSegments = 40;
    const minorSegments = 20;

    for (var i = 0; i < majorSegments; i++) {
      final theta = (i / majorSegments) * 2 * pi;

      for (var j = 0; j < minorSegments; j++) {
        final phi = (j / minorSegments) * 2 * pi;

        // Torus parametric equation
        var x = (majorRadius + minorRadius * cos(phi)) * cos(theta);
        var y = (majorRadius + minorRadius * cos(phi)) * sin(theta);
        var z = minorRadius * sin(phi);

        // Apply rotations
        // Rotate around X
        var newY = y * cos(rotX) - z * sin(rotX);
        var newZ = y * sin(rotX) + z * cos(rotX);
        y = newY;
        z = newZ;

        // Rotate around Y
        var newX = x * cos(rotY) + z * sin(rotY);
        newZ = -x * sin(rotY) + z * cos(rotY);
        x = newX;
        z = newZ;

        // Rotate around Z
        newX = x * cos(rotZ) - y * sin(rotZ);
        newY = x * sin(rotZ) + y * cos(rotZ);
        x = newX;
        y = newY;

        // Project to 2D
        const fov = 500.0;
        final scale = fov / (fov + z);
        final screenX = centerX + x * scale;
        final screenY = centerY + y * scale;

        points.add(
          _TorusPoint(
            x: screenX,
            y: screenY,
            z: z,
            scale: scale,
            theta: theta,
            phi: phi,
          ),
        );
      }
    }

    // Sort by Z for proper rendering
    points.sort((a, b) => a.z.compareTo(b.z));

    // Draw points
    for (final p in points) {
      final brightness =
          ((p.z + majorRadius + minorRadius) /
                  (2 * (majorRadius + minorRadius)))
              .clamp(0.2, 1.0);

      // Color based on position on torus
      final hue = ((p.theta / (2 * pi)) * 360 + progress * 180) % 360;
      final color = HSVColor.fromAHSV(
        brightness,
        hue,
        0.8,
        brightness,
      ).toColor();

      final pointSize = 3 * p.scale;

      // Glow
      if (brightness > 0.5) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, pointSize);
        canvas.drawCircle(Offset(p.x, p.y), pointSize * 1.5, glowPaint);
      }

      // Point
      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(p.x, p.y), pointSize, paint);
    }

    // Center glow
    final centerGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF00FFFF).withValues(alpha: 0.2),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(centerX, centerY),
              radius: majorRadius,
            ),
          );
    canvas.drawCircle(Offset(centerX, centerY), majorRadius, centerGlow);
  }

  @override
  bool shouldRepaint(covariant _TorusPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _TorusPoint {
  _TorusPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.scale,
    required this.theta,
    required this.phi,
  });

  final double x;
  final double y;
  final double z;
  final double scale;
  final double theta;
  final double phi;
}
