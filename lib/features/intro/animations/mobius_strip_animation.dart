// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math';

import 'package:flutter/material.dart';

/// Möbius Strip - a one-sided surface with a single boundary.
class MobiusStripAnimation extends StatefulWidget {
  const MobiusStripAnimation({super.key});

  @override
  State<MobiusStripAnimation> createState() => _MobiusStripAnimationState();
}

class _MobiusStripAnimationState extends State<MobiusStripAnimation>
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
          painter: _MobiusStripPainter(progress: _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MobiusStripPainter extends CustomPainter {
  _MobiusStripPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final time = progress * 2 * pi;
    final scale = min(size.width, size.height) * 0.3;

    // Rotation angles
    final rotX = time * 0.3 + sin(time * 0.5) * 0.2;
    final rotY = time * 0.5;
    final rotZ = time * 0.2;

    // Background glow
    canvas.drawCircle(
      Offset(cx, cy),
      scale * 1.5,
      Paint()
        ..color = Colors.teal.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40),
    );

    // Generate Möbius strip points
    final points = <_MobiusPoint>[];
    const uSegments = 80; // Around the strip
    const vSegments = 15; // Across the width

    final majorRadius = scale * 0.8;
    final minorRadius = scale * 0.25;

    for (var i = 0; i <= uSegments; i++) {
      final u = (i / uSegments) * 2 * pi;

      for (var j = 0; j <= vSegments; j++) {
        final v = (j / vSegments) * 2 - 1; // -1 to 1

        // Möbius strip parametric equations
        // The key: half-twist (u/2 instead of u for the v direction)
        var x = (majorRadius + v * minorRadius * cos(u / 2)) * cos(u);
        var y = (majorRadius + v * minorRadius * cos(u / 2)) * sin(u);
        var z = v * minorRadius * sin(u / 2);

        // Apply rotations
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
        const fov = 500.0;
        final projScale = fov / (fov + z);
        final screenX = cx + x * projScale;
        final screenY = cy + y * projScale;

        // Calculate normal for shading (simplified)
        final normalZ = cos(u / 2) * cos(rotX) - sin(u / 2) * sin(rotX);

        points.add(
          _MobiusPoint(
            x: screenX,
            y: screenY,
            z: z,
            u: u,
            v: v,
            scale: projScale,
            normalZ: normalZ,
          ),
        );
      }
    }

    // Draw the strip as quads/triangles
    _drawMobiusSurface(canvas, points, uSegments, vSegments, time);

    // Draw edge lines
    _drawMobiusEdges(canvas, points, uSegments, vSegments, time);

    // Draw traveling point to show one-sidedness
    _drawTravelingPoint(
      canvas,
      cx,
      cy,
      majorRadius,
      minorRadius,
      rotX,
      rotY,
      rotZ,
      time,
    );
  }

  void _drawMobiusSurface(
    Canvas canvas,
    List<_MobiusPoint> points,
    int uSegments,
    int vSegments,
    double time,
  ) {
    for (var i = 0; i < uSegments; i++) {
      for (var j = 0; j < vSegments; j++) {
        final idx00 = i * (vSegments + 1) + j;
        final idx01 = i * (vSegments + 1) + j + 1;
        final idx10 = (i + 1) * (vSegments + 1) + j;
        final idx11 = (i + 1) * (vSegments + 1) + j + 1;

        if (idx11 >= points.length) continue;

        final p00 = points[idx00];
        final p01 = points[idx01];
        final p10 = points[idx10];
        final p11 = points[idx11];

        // Average depth for sorting (we'll skip back-face culling for the impossible effect)
        final avgZ = (p00.z + p01.z + p10.z + p11.z) / 4;

        // Color based on position along the strip
        final hue = (p00.u / (2 * pi) * 360 + time * 20) % 360;

        // Two-tone coloring to show the "two sides" that are actually one
        final sideColor = p00.v > 0
            ? HSVColor.fromAHSV(1.0, hue, 0.7, 0.8).toColor()
            : HSVColor.fromAHSV(1.0, (hue + 180) % 360, 0.7, 0.8).toColor();

        // Depth-based alpha
        final alpha = ((avgZ + 100) / 200).clamp(0.2, 0.8);

        final path = Path();
        path.moveTo(p00.x, p00.y);
        path.lineTo(p01.x, p01.y);
        path.lineTo(p11.x, p11.y);
        path.lineTo(p10.x, p10.y);
        path.close();

        canvas.drawPath(
          path,
          Paint()
            ..color = sideColor.withValues(alpha: alpha)
            ..style = PaintingStyle.fill,
        );
      }
    }
  }

  void _drawMobiusEdges(
    Canvas canvas,
    List<_MobiusPoint> points,
    int uSegments,
    int vSegments,
    double time,
  ) {
    // Draw the single continuous edge (both "sides" are the same edge!)
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.4)
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..style = PaintingStyle.stroke;

    // Top edge (v = 1)
    final topEdge = Path();
    for (var i = 0; i <= uSegments; i++) {
      final idx = i * (vSegments + 1) + vSegments;
      if (idx >= points.length) continue;
      final p = points[idx];
      if (i == 0) {
        topEdge.moveTo(p.x, p.y);
      } else {
        topEdge.lineTo(p.x, p.y);
      }
    }

    // Bottom edge (v = -1) - continues the same edge!
    for (var i = uSegments; i >= 0; i--) {
      final idx = i * (vSegments + 1);
      if (idx >= points.length) continue;
      final p = points[idx];
      topEdge.lineTo(p.x, p.y);
    }
    topEdge.close();

    canvas.drawPath(topEdge, glowPaint);
    canvas.drawPath(topEdge, edgePaint);
  }

  void _drawTravelingPoint(
    Canvas canvas,
    double cx,
    double cy,
    double majorRadius,
    double minorRadius,
    double rotX,
    double rotY,
    double rotZ,
    double time,
  ) {
    // A point traveling along the surface, showing it visits "both sides"
    final travelU = time * 2; // Complete two loops
    final travelV = sin(time * 2) * 0.8; // Oscillate across width

    var x =
        (majorRadius + travelV * minorRadius * cos(travelU / 2)) * cos(travelU);
    var y =
        (majorRadius + travelV * minorRadius * cos(travelU / 2)) * sin(travelU);
    var z = travelV * minorRadius * sin(travelU / 2);

    // Apply same rotations
    var newY = y * cos(rotX) - z * sin(rotX);
    var newZ = y * sin(rotX) + z * cos(rotX);
    y = newY;
    z = newZ;

    var newX = x * cos(rotY) + z * sin(rotY);
    newZ = -x * sin(rotY) + z * cos(rotY);
    x = newX;
    z = newZ;

    newX = x * cos(rotZ) - y * sin(rotZ);
    newY = x * sin(rotZ) + y * cos(rotZ);
    x = newX;
    y = newY;

    const fov = 500.0;
    final projScale = fov / (fov + z);
    final screenX = cx + x * projScale;
    final screenY = cy + y * projScale;

    // Color changes as it travels to show surface continuity
    final hue = (travelU / (4 * pi) * 360) % 360;
    final color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    // Glowing traveling point
    canvas.drawCircle(
      Offset(screenX, screenY),
      12 * projScale,
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawCircle(
      Offset(screenX, screenY),
      6 * projScale,
      Paint()..color = color,
    );

    // Trail
    for (var t = 0; t < 20; t++) {
      final trailU = travelU - t * 0.1;
      final trailV = sin((time - t * 0.05) * 2) * 0.8;

      var tx =
          (majorRadius + trailV * minorRadius * cos(trailU / 2)) * cos(trailU);
      var ty =
          (majorRadius + trailV * minorRadius * cos(trailU / 2)) * sin(trailU);
      var tz = trailV * minorRadius * sin(trailU / 2);

      var tNewY = ty * cos(rotX) - tz * sin(rotX);
      var tNewZ = ty * sin(rotX) + tz * cos(rotX);
      ty = tNewY;
      tz = tNewZ;

      var tNewX = tx * cos(rotY) + tz * sin(rotY);
      tNewZ = -tx * sin(rotY) + tz * cos(rotY);
      tx = tNewX;
      tz = tNewZ;

      tNewX = tx * cos(rotZ) - ty * sin(rotZ);
      tNewY = tx * sin(rotZ) + ty * cos(rotZ);
      tx = tNewX;
      ty = tNewY;

      final tProjScale = fov / (fov + tz);
      final tsx = cx + tx * tProjScale;
      final tsy = cy + ty * tProjScale;

      final trailAlpha = (1 - t / 20.0) * 0.5;
      canvas.drawCircle(
        Offset(tsx, tsy),
        3 * tProjScale,
        Paint()..color = color.withValues(alpha: trailAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MobiusStripPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MobiusPoint {
  _MobiusPoint({
    required this.x,
    required this.y,
    required this.z,
    required this.u,
    required this.v,
    required this.scale,
    required this.normalZ,
  });

  final double x;
  final double y;
  final double z;
  final double u;
  final double v;
  final double scale;
  final double normalZ;
}
