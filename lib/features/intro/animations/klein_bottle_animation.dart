// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Klein Bottle - a 4D surface with no inside/outside distinction.
class KleinBottleAnimation extends StatefulWidget {
  const KleinBottleAnimation({super.key});

  @override
  State<KleinBottleAnimation> createState() => _KleinBottleAnimationState();
}

class _KleinBottleAnimationState extends State<KleinBottleAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 15000),
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
          painter: _KleinBottlePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _KleinBottlePainter extends CustomPainter {
  _KleinBottlePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;
    final scale = min(size.width, size.height) * 0.35;

    // Rotation angles for 4D projection
    final rotXY = time * 0.4;
    final rotXZ = time * 0.3;
    final rotXW = time * 0.2; // 4th dimension rotation

    // Background glow
    canvas.drawCircle(
      Offset(cx, cy),
      scale * 1.5,
      Paint()
        ..color = Colors.indigo.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50),
    );

    // Generate Klein bottle points
    final points = <_KleinPoint>[];
    const uSegments = 60;
    const vSegments = 30;

    for (var i = 0; i <= uSegments; i++) {
      final u = (i / uSegments) * 2 * pi;

      for (var j = 0; j <= vSegments; j++) {
        final v = (j / vSegments) * 2 * pi;

        // Klein bottle parametric equations (figure-8 immersion)
        final r = 4 * (1 - cos(u) / 2);

        double x, y, z;

        if (u < pi) {
          x = 6 * cos(u) * (1 + sin(u)) + r * cos(u) * cos(v);
          y = 16 * sin(u) + r * sin(u) * cos(v);
        } else {
          x = 6 * cos(u) * (1 + sin(u)) + r * cos(v + pi);
          y = 16 * sin(u);
        }
        z = r * sin(v);

        // Scale down
        x *= scale * 0.04;
        y *= scale * 0.04;
        z *= scale * 0.04;

        // Center
        y -= scale * 0.3;

        // Apply 3D rotations
        // Rotate XY
        var newX = x * cos(rotXY) - y * sin(rotXY);
        var newY = x * sin(rotXY) + y * cos(rotXY);
        x = newX;
        y = newY;

        // Rotate XZ
        newX = x * cos(rotXZ) - z * sin(rotXZ);
        var newZ = x * sin(rotXZ) + z * cos(rotXZ);
        x = newX;
        z = newZ;

        // Simulate 4D rotation effect
        final w = sin(u * 2 + time) * scale * 0.1;
        final w4d = w * cos(rotXW);
        x += w4d * 0.3;
        z += w4d * 0.2;

        // Project to 2D
        const fov = 500.0;
        final projScale = fov / (fov + z);
        final screenX = cx + x * projScale;
        final screenY = cy + y * projScale;

        points.add(
          _KleinPoint(
            x: screenX,
            y: screenY,
            z: z,
            u: u,
            v: v,
            scale: projScale,
          ),
        );
      }
    }

    // Sort by depth
    points.sort((a, b) => a.z.compareTo(b.z));

    // Draw points with color based on surface position
    for (final p in points) {
      // Color based on parametric position
      final hue =
          (p.u / (2 * pi) * 180 + p.v / (2 * pi) * 180 + time * 30) % 360;
      final brightness = ((p.z + scale) / (2 * scale)).clamp(0.3, 1.0);

      final color = HSVColor.fromAHSV(
        brightness,
        hue,
        0.7,
        brightness,
      ).toColor();

      final pointSize = 2.5 * p.scale;

      // Glow for brighter points
      if (brightness > 0.5) {
        canvas.drawCircle(
          Offset(p.x, p.y),
          pointSize * 2,
          Paint()
            ..color = color.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      canvas.drawCircle(Offset(p.x, p.y), pointSize, Paint()..color = color);
    }

    // Draw wireframe connections for structure
    _drawWireframe(canvas, points, uSegments, vSegments, time);
  }

  void _drawWireframe(
    Canvas canvas,
    List<_KleinPoint> points,
    int uSegments,
    int vSegments,
    double time,
  ) {
    // Draw every nth line for performance
    const skipU = 4;
    const skipV = 3;

    for (var i = 0; i < uSegments; i += skipU) {
      for (var j = 0; j < vSegments; j += skipV) {
        final idx = i * (vSegments + 1) + j;
        final idxNextU = ((i + skipU) % (uSegments + 1)) * (vSegments + 1) + j;
        final idxNextV = i * (vSegments + 1) + ((j + skipV) % (vSegments + 1));

        if (idx < points.length && idxNextU < points.length) {
          final p1 = points[idx];
          final p2 = points[idxNextU];

          final avgZ = (p1.z + p2.z) / 2;
          final alpha = ((avgZ + 100) / 200).clamp(0.05, 0.3);

          canvas.drawLine(
            Offset(p1.x, p1.y),
            Offset(p2.x, p2.y),
            Paint()
              ..color = Colors.cyan.withValues(alpha: alpha)
              ..strokeWidth = 0.5,
          );
        }

        if (idx < points.length && idxNextV < points.length) {
          final p1 = points[idx];
          final p2 = points[idxNextV];

          final avgZ = (p1.z + p2.z) / 2;
          final alpha = ((avgZ + 100) / 200).clamp(0.05, 0.3);

          canvas.drawLine(
            Offset(p1.x, p1.y),
            Offset(p2.x, p2.y),
            Paint()
              ..color = Colors.purple.withValues(alpha: alpha)
              ..strokeWidth = 0.5,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KleinBottlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _KleinPoint {
  _KleinPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.u,
    required this.v,
    required this.scale,
  });

  final double x;
  final double y;
  final double z;
  final double u;
  final double v;
  final double scale;
}
