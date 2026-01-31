// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Impossible Necker cube with paradoxical edge crossings.
class ImpossibleCubeAnimation extends StatefulWidget {
  const ImpossibleCubeAnimation({super.key});

  @override
  State<ImpossibleCubeAnimation> createState() =>
      _ImpossibleCubeAnimationState();
}

class _ImpossibleCubeAnimationState extends State<ImpossibleCubeAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 12000),
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
          painter: _ImpossibleCubePainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ImpossibleCubePainter extends CustomPainter {
  _ImpossibleCubePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;
    final cubeSize = min(size.width, size.height) * 0.3;

    // Rotation angles
    final rotX = time * 0.4;
    final rotY = time * 0.6;
    final rotZ = time * 0.2;

    // Define cube vertices
    final vertices = <List<double>>[
      [-1, -1, -1],
      [1, -1, -1],
      [1, 1, -1],
      [-1, 1, -1],
      [-1, -1, 1],
      [1, -1, 1],
      [1, 1, 1],
      [-1, 1, 1],
    ];

    // Transform vertices
    final transformed = vertices.map((v) {
      var x = v[0] * cubeSize;
      var y = v[1] * cubeSize;
      var z = v[2] * cubeSize;

      // Rotate X
      var newY = y * cos(rotX) - z * sin(rotX);
      var newZ = y * sin(rotX) + z * cos(rotX);
      y = newY;
      z = newZ;

      // Rotate Y
      var newX = x * cos(rotY) + z * sin(rotY);
      newZ = -x * sin(rotY) + z * cos(rotY);
      x = newX;
      z = newZ;

      // Rotate Z
      newX = x * cos(rotZ) - y * sin(rotZ);
      newY = x * sin(rotZ) + y * cos(rotZ);
      x = newX;
      y = newY;

      // Project to 2D
      const fov = 400.0;
      final scale = fov / (fov + z);
      return [cx + x * scale, cy + y * scale, z, scale];
    }).toList();

    // Define edges with their "impossible" crossing behavior
    // Format: [start, end, drawOrder, isImpossible]
    final edges = <List<int>>[
      // Back face
      [0, 1, 0, 0],
      [1, 2, 0, 0],
      [2, 3, 0, 0],
      [3, 0, 0, 0],
      // Front face
      [4, 5, 2, 0],
      [5, 6, 2, 0],
      [6, 7, 2, 0],
      [7, 4, 2, 0],
      // Connecting edges - these create the impossible effect
      [0, 4, 1, 1], // Impossible crossing
      [1, 5, 1, 0],
      [2, 6, 1, 1], // Impossible crossing
      [3, 7, 1, 0],
    ];

    // Sort edges by draw order
    edges.sort((a, b) => a[2].compareTo(b[2]));

    // Draw glow background
    final glowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    canvas.drawCircle(Offset(cx, cy), cubeSize * 1.5, glowPaint);

    // Draw edges
    for (final edge in edges) {
      final p1 = transformed[edge[0]];
      final p2 = transformed[edge[1]];
      final isImpossible = edge[3] == 1;

      // Calculate edge depth for coloring
      final avgZ = (p1[2] + p2[2]) / 2;
      final brightness = ((avgZ + cubeSize) / (2 * cubeSize)).clamp(0.3, 1.0);

      // Color with hue shift over time
      final hue = (edge[0] * 30 + time * 30) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.8, brightness).toColor();

      // Edge thickness based on depth
      final avgScale = (p1[3] + p2[3]) / 2;
      final thickness = 3.0 * avgScale;

      if (isImpossible) {
        // Draw impossible edge with special effect
        _drawImpossibleEdge(
          canvas,
          Offset(p1[0], p1[1]),
          Offset(p2[0], p2[1]),
          color,
          thickness,
          time,
        );
      } else {
        // Normal edge with glow
        canvas.drawLine(
          Offset(p1[0], p1[1]),
          Offset(p2[0], p2[1]),
          Paint()
            ..color = color.withValues(alpha: 0.4)
            ..strokeWidth = thickness * 3
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );

        canvas.drawLine(
          Offset(p1[0], p1[1]),
          Offset(p2[0], p2[1]),
          Paint()
            ..color = color
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // Draw vertices as glowing points
    for (var i = 0; i < transformed.length; i++) {
      final p = transformed[i];
      final hue = (i * 45 + time * 40) % 360;
      final color = HSVColor.fromAHSV(1.0, hue, 0.9, 1.0).toColor();
      final pointSize = 4.0 * p[3];

      // Glow
      canvas.drawCircle(
        Offset(p[0], p[1]),
        pointSize * 2,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Point
      canvas.drawCircle(Offset(p[0], p[1]), pointSize, Paint()..color = color);
    }
  }

  void _drawImpossibleEdge(
    Canvas canvas,
    Offset start,
    Offset end,
    Color color,
    double thickness,
    double time,
  ) {
    // Split the edge into segments that appear to weave impossibly
    final midPoint = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    // Calculate perpendicular offset for the "impossible" crossing
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = sqrt(dx * dx + dy * dy);
    final perpX = -dy / len * thickness * 2;
    final perpY = dx / len * thickness * 2;

    // Pulsing offset for dynamic effect
    final pulse = sin(time * 3) * 0.5 + 0.5;
    final offsetMid = Offset(
      midPoint.dx + perpX * pulse,
      midPoint.dy + perpY * pulse,
    );

    // Draw the impossible crossing segments
    // First half
    canvas.drawLine(
      start,
      offsetMid,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..strokeWidth = thickness * 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      start,
      offsetMid,
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );

    // Second half with different color to show the paradox
    final altColor = HSVColor.fromColor(
      color,
    ).withHue((HSVColor.fromColor(color).hue + 180) % 360).toColor();

    canvas.drawLine(
      offsetMid,
      end,
      Paint()
        ..color = altColor.withValues(alpha: 0.4)
        ..strokeWidth = thickness * 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawLine(
      offsetMid,
      end,
      Paint()
        ..color = altColor
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round,
    );

    // Glowing junction point
    canvas.drawCircle(
      offsetMid,
      thickness * 1.5,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _ImpossibleCubePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
