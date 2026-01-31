// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Rotating 3D cube wireframe animation.
class CubeFieldAnimation extends StatefulWidget {
  const CubeFieldAnimation({super.key});

  @override
  State<CubeFieldAnimation> createState() => _CubeFieldAnimationState();
}

class _CubeFieldAnimationState extends State<CubeFieldAnimation>
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
          painter: _CubeFieldPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Vector3D {
  _Vector3D(this.x, this.y, this.z);
  double x;
  double y;
  double z;

  _Vector3D rotateX(double a) {
    final c = cos(a);
    final s = sin(a);
    return _Vector3D(x, y * c - z * s, y * s + z * c);
  }

  _Vector3D rotateY(double a) {
    final c = cos(a);
    final s = sin(a);
    return _Vector3D(x * c + z * s, y, -x * s + z * c);
  }

  _Vector3D rotateZ(double a) {
    final c = cos(a);
    final s = sin(a);
    return _Vector3D(x * c - y * s, x * s + y * c, z);
  }
}

class _CubeFieldPainter extends CustomPainter {
  _CubeFieldPainter({required this.progress});

  final double progress;

  static final List<_Vector3D> _cubeVertices = [
    _Vector3D(-1, -1, -1),
    _Vector3D(1, -1, -1),
    _Vector3D(1, 1, -1),
    _Vector3D(-1, 1, -1),
    _Vector3D(-1, -1, 1),
    _Vector3D(1, -1, 1),
    _Vector3D(1, 1, 1),
    _Vector3D(-1, 1, 1),
  ];

  static const List<List<int>> _cubeEdges = [
    [0, 1], [1, 2], [2, 3], [3, 0], // front
    [4, 5], [5, 6], [6, 7], [7, 4], // back
    [0, 4], [1, 5], [2, 6], [3, 7], // connections
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final time = progress * 2 * pi;
    final cubeSize = min(size.width, size.height) * 0.15;

    // Draw a grid of cubes
    const gridSize = 3;
    final spacing = min(size.width, size.height) * 0.35;

    for (var gx = -gridSize ~/ 2; gx <= gridSize ~/ 2; gx++) {
      for (var gy = -gridSize ~/ 2; gy <= gridSize ~/ 2; gy++) {
        final offsetX = gx * spacing;
        final offsetY = gy * spacing;

        // Each cube rotates slightly differently
        final phase = (gx + gy) * 0.3;
        final rotX = time + phase;
        final rotY = time * 0.7 + phase;
        final rotZ = time * 0.5;

        // Transform and project vertices
        final projected = <Offset>[];
        final depths = <double>[];

        for (final v in _cubeVertices) {
          var rotated = v.rotateX(rotX).rotateY(rotY).rotateZ(rotZ);

          // Add some z movement
          final zOffset = sin(time + phase) * 50;
          rotated = _Vector3D(rotated.x, rotated.y, rotated.z + zOffset);

          // Project
          const fov = 300.0;
          final scale = fov / (fov + rotated.z * cubeSize + 200);
          projected.add(
            Offset(
              centerX + offsetX + rotated.x * cubeSize * scale,
              centerY + offsetY + rotated.y * cubeSize * scale,
            ),
          );
          depths.add(rotated.z);
        }

        // Color based on position
        final hue =
            ((gx + gridSize) * 40 + (gy + gridSize) * 40 + progress * 360) %
            360;
        final color = HSVColor.fromAHSV(1.0, hue, 0.8, 0.9).toColor();

        // Draw edges
        for (final edge in _cubeEdges) {
          final avgDepth = (depths[edge[0]] + depths[edge[1]]) / 2;
          final brightness = ((avgDepth + 2) / 4).clamp(0.3, 1.0);

          final paint = Paint()
            ..color = color.withValues(alpha: brightness * 0.8)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke;

          canvas.drawLine(projected[edge[0]], projected[edge[1]], paint);
        }

        // Draw vertices as glowing dots
        for (var i = 0; i < projected.length; i++) {
          final brightness = ((depths[i] + 2) / 4).clamp(0.3, 1.0);
          final dotPaint = Paint()
            ..color = color.withValues(alpha: brightness)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
          canvas.drawCircle(projected[i], 4, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CubeFieldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
