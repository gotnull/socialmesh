import 'dart:math';

import 'package:flutter/material.dart';

/// Smooth 3D cubes with soft lighting.
class PolygonCubesAnimation extends StatefulWidget {
  const PolygonCubesAnimation({super.key});

  @override
  State<PolygonCubesAnimation> createState() => _PolygonCubesAnimationState();
}

class _PolygonCubesAnimationState extends State<PolygonCubesAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
          painter: _PolygonCubesPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _PolygonCubesPainter extends CustomPainter {
  _PolygonCubesPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;

    // Gradient background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0a0a15), Color(0xFF151525), Color(0xFF0a0a15)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw cubes
    final cubes = [
      (x: cx, y: cy, size: 60.0, rotSpeed: 1.0, color: const Color(0xFF4080c0)),
      (
        x: cx - 120,
        y: cy - 60,
        size: 40.0,
        rotSpeed: -0.7,
        color: const Color(0xFFc06080),
      ),
      (
        x: cx + 110,
        y: cy + 50,
        size: 45.0,
        rotSpeed: 0.8,
        color: const Color(0xFF60c080),
      ),
    ];

    for (final cube in cubes) {
      _drawCube(
        canvas,
        cube.x,
        cube.y,
        cube.size,
        time * cube.rotSpeed,
        time * cube.rotSpeed * 0.7,
        cube.color,
      );
    }

    // Floating orbs
    for (var i = 0; i < 5; i++) {
      final orbitAngle = time * 0.5 + i * pi * 2 / 5;
      final orbitRadius = 150 + sin(time * 0.3 + i) * 30;
      final ox = cx + cos(orbitAngle) * orbitRadius;
      final oy = cy + sin(orbitAngle) * orbitRadius * 0.4;
      final oz = sin(orbitAngle);

      final orbSize = 8 + oz * 4;
      final orbAlpha = (0.4 + oz * 0.3).clamp(0.2, 0.7);

      final orbColor = HSVColor.fromAHSV(
        1.0,
        (i * 60 + progress * 180) % 360,
        0.5,
        0.8,
      ).toColor();

      // Soft glow
      canvas.drawCircle(
        Offset(ox, oy),
        orbSize * 2,
        Paint()..color = orbColor.withValues(alpha: orbAlpha * 0.2),
      );
      canvas.drawCircle(
        Offset(ox, oy),
        orbSize,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: orbAlpha * 0.8),
                  orbColor.withValues(alpha: orbAlpha),
                  orbColor.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.3, 1.0],
              ).createShader(
                Rect.fromCircle(center: Offset(ox, oy), radius: orbSize),
              ),
      );
    }
  }

  void _drawCube(
    Canvas canvas,
    double cx,
    double cy,
    double cubeSize,
    double rotY,
    double rotX,
    Color baseColor,
  ) {
    final half = cubeSize / 2;

    // Cube vertices
    final vertices = <List<double>>[
      [-half, -half, -half],
      [half, -half, -half],
      [half, half, -half],
      [-half, half, -half],
      [-half, -half, half],
      [half, -half, half],
      [half, half, half],
      [-half, half, half],
    ];

    // Rotate vertices
    final rotated = vertices.map((v) {
      var x = v[0], y = v[1], z = v[2];

      // Rotate Y
      final cosY = cos(rotY), sinY = sin(rotY);
      final x1 = x * cosY + z * sinY;
      final z1 = -x * sinY + z * cosY;
      x = x1;
      z = z1;

      // Rotate X
      final cosX = cos(rotX), sinX = sin(rotX);
      final y1 = y * cosX - z * sinX;
      final z2 = y * sinX + z * cosX;
      y = y1;
      z = z2;

      // Project
      final scale = 300 / (300 + z);
      return [cx + x * scale, cy + y * scale, z];
    }).toList();

    // Faces
    final faces = [
      (indices: [0, 1, 2, 3], brightness: 0.6), // Front
      (indices: [5, 4, 7, 6], brightness: 0.4), // Back
      (indices: [4, 0, 3, 7], brightness: 0.5), // Left
      (indices: [1, 5, 6, 2], brightness: 0.7), // Right
      (indices: [4, 5, 1, 0], brightness: 0.8), // Top
      (indices: [3, 2, 6, 7], brightness: 0.3), // Bottom
    ];

    // Sort by Z
    final sortedFaces = List.generate(faces.length, (i) => i);
    sortedFaces.sort((a, b) {
      final avgZa =
          faces[a].indices.map((i) => rotated[i][2]).reduce((a, b) => a + b) /
          4;
      final avgZb =
          faces[b].indices.map((i) => rotated[i][2]).reduce((a, b) => a + b) /
          4;
      return avgZb.compareTo(avgZa);
    });

    for (final fi in sortedFaces) {
      final face = faces[fi];
      final path = Path();

      path.moveTo(rotated[face.indices[0]][0], rotated[face.indices[0]][1]);
      for (var i = 1; i < face.indices.length; i++) {
        path.lineTo(rotated[face.indices[i]][0], rotated[face.indices[i]][1]);
      }
      path.close();

      final faceColor = Color.lerp(Colors.black, baseColor, face.brightness)!;

      // Fill
      canvas.drawPath(path, Paint()..color = faceColor.withValues(alpha: 0.85));

      // Edge
      canvas.drawPath(
        path,
        Paint()
          ..color = baseColor.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PolygonCubesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
