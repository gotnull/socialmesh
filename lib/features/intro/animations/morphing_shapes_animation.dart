// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Geometric morphing shapes animation.
class MorphingShapesAnimation extends StatefulWidget {
  const MorphingShapesAnimation({super.key});

  @override
  State<MorphingShapesAnimation> createState() =>
      _MorphingShapesAnimationState();
}

class _MorphingShapesAnimationState extends State<MorphingShapesAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6000),
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
          painter: _MorphingShapesPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MorphingShapesPainter extends CustomPainter {
  _MorphingShapesPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final baseSize = min(size.width, size.height) * 0.35;
    final time = progress * 2 * pi;

    // Draw multiple morphing shapes
    for (var layer = 0; layer < 5; layer++) {
      final layerProgress = (progress + layer * 0.2) % 1.0;
      final layerSize = baseSize * (1 - layer * 0.15);

      // Morph between different polygon vertex counts
      final morphPhase = layerProgress * 3;
      final fromSides = 3 + (morphPhase.floor() % 5);
      final toSides = 3 + ((morphPhase.floor() + 1) % 5);
      final morphT = morphPhase - morphPhase.floor();

      // Rotation
      final rotation = time * (layer % 2 == 0 ? 1 : -1) * 0.5;

      // Color
      final hue = (layer * 72 + progress * 360) % 360;
      final color = HSVColor.fromAHSV(0.8, hue, 0.8, 0.9).toColor();

      // Generate morphed polygon path
      final path = _createMorphedPolygon(
        centerX,
        centerY,
        layerSize,
        fromSides,
        toSides,
        morphT,
        rotation,
      );

      // Glow
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, glowPaint);

      // Main stroke
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);

      // Vertices
      final vertices = _getPolygonVertices(
        centerX,
        centerY,
        layerSize,
        max(fromSides, toSides),
        rotation,
      );
      for (final v in vertices) {
        final vertexPaint = Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(v, 5, vertexPaint);
      }
    }

    // Center pulsing circle
    final pulseSize = 20 + sin(time * 3) * 10;
    final centerPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.white, const Color(0xFF00FFFF), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(centerX, centerY),
              radius: pulseSize,
            ),
          );
    canvas.drawCircle(Offset(centerX, centerY), pulseSize, centerPaint);
  }

  Path _createMorphedPolygon(
    double cx,
    double cy,
    double radius,
    int fromSides,
    int toSides,
    double t,
    double rotation,
  ) {
    final path = Path();
    final maxSides = max(fromSides, toSides);

    for (var i = 0; i <= maxSides; i++) {
      // Angle for this vertex
      final fromAngle = (i / fromSides) * 2 * pi + rotation;
      final toAngle = (i / toSides) * 2 * pi + rotation;
      final angle = _lerpAngle(fromAngle, toAngle, t);

      // Radius with some pulsing
      final r = radius * (0.9 + sin(angle * 3) * 0.1);

      final x = cx + cos(angle) * r;
      final y = cy + sin(angle) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  List<Offset> _getPolygonVertices(
    double cx,
    double cy,
    double radius,
    int sides,
    double rotation,
  ) {
    final vertices = <Offset>[];
    for (var i = 0; i < sides; i++) {
      final angle = (i / sides) * 2 * pi + rotation;
      vertices.add(Offset(cx + cos(angle) * radius, cy + sin(angle) * radius));
    }
    return vertices;
  }

  double _lerpAngle(double from, double to, double t) {
    var diff = to - from;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    return from + diff * t;
  }

  @override
  bool shouldRepaint(covariant _MorphingShapesPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
