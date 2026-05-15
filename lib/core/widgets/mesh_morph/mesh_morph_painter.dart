// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// CustomPainter that renders one frame of a MeshMorphWidget. Owns the
// "blend two shape buffers and project the result" step. Visual style
// (gradient nodes, soft glow, optional triangle faces) is borrowed from
// the existing _IcosahedronPainter so a morph that ends on the icosahedron
// looks visually consistent with the splash logo.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'mesh_shape.dart';

class MeshMorphPainter extends CustomPainter {
  /// Pre-resolved positions for the current frame. Length == pointCount.
  final List<Point3D> blended;

  /// Optional edges to draw between point indices in `blended`. Null when
  /// the current shape doesn't have a meaningful wireframe.
  final List<ShapeEdge>? edges;

  /// Euler angles (radians) applied before projection. Mirrors the
  /// AnimatedMeshNode rotation pipeline.
  final double rotationX;
  final double rotationY;
  final double rotationZ;

  /// Brand gradient — same colours the existing icosahedron painter uses.
  final List<Color> gradientColors;

  /// Optional second gradient that mixes in based on morph progress. When
  /// non-null the painter linearly interpolates each balls' gradient sample
  /// toward this so transitions can drift through brand variants.
  final List<Color>? secondaryGradient;

  /// 0..1 weight that mixes secondaryGradient into the base. Set by the
  /// widget from the timeline sample's easedT.
  final double secondaryWeight;

  /// Glow / line / node size multipliers — same names as the existing
  /// icosahedron painter so callers can pass through whatever they already
  /// tuned for the splash screen.
  final double glowIntensity;
  final double lineThickness;
  final double nodeSize;

  /// Whether to draw the connecting edges (when [edges] is non-null).
  /// Lets the timeline tell the painter to hide lines during morph.
  final bool drawEdges;

  MeshMorphPainter({
    required this.blended,
    required this.edges,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.gradientColors,
    this.secondaryGradient,
    this.secondaryWeight = 0.0,
    this.glowIntensity = 0.85,
    this.lineThickness = 0.75,
    this.nodeSize = 0.85,
    this.drawEdges = true,
  });

  // Projected 2D positions reused across the three drawing passes (faces
  // disabled in the morph painter — keep the pipeline simple; the user's
  // hero icosahedron face fill belongs to the static _IcosahedronPainter).
  final List<Offset> _projected = <Offset>[];
  final List<double> _depth = <double>[];

  @override
  void paint(Canvas canvas, Size size) {
    const perspective = 3.0;
    final w = size.width;
    final cx = w / 2;
    final cy = size.height / 2;

    _projected
      ..clear()
      ..length = blended.length;
    _depth
      ..clear()
      ..length = blended.length;

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final cosZ = math.cos(rotationZ);
    final sinZ = math.sin(rotationZ);

    for (int i = 0; i < blended.length; i++) {
      final p = blended[i];

      // Rotate Z then Y then X (matches the AnimatedMeshNode order).
      final x1 = p.x * cosZ - p.y * sinZ;
      final y1 = p.x * sinZ + p.y * cosZ;
      final z1 = p.z;

      final x2 = x1 * cosY + z1 * sinY;
      final y2 = y1;
      final z2 = -x1 * sinY + z1 * cosY;

      final x3 = x2;
      final y3 = y2 * cosX - z2 * sinX;
      final z3 = y2 * sinX + z2 * cosX;

      // Perspective project to screen.
      final scale = perspective / (perspective + z3);
      _projected[i] = Offset(x3 * scale * w / 2 + cx, y3 * scale * w / 2 + cy);
      _depth[i] = z3;
    }

    // ---------- Pass 1: connecting edges (back-to-front) ----------
    if (drawEdges && edges != null && edges!.isNotEmpty) {
      // Sort edges by midpoint depth so back edges paint first and front
      // edges win the z-order.
      final order = List<int>.generate(edges!.length, (i) => i);
      order.sort((a, b) {
        final ea = edges![a];
        final eb = edges![b];
        final za = (_safeDepth(ea.$1) + _safeDepth(ea.$2)) * 0.5;
        final zb = (_safeDepth(eb.$1) + _safeDepth(eb.$2)) * 0.5;
        return zb.compareTo(za);
      });
      for (final i in order) {
        final e = edges![i];
        final a = _safeOffset(e.$1);
        final b = _safeOffset(e.$2);
        if (a == null || b == null) continue;
        final depth = (_safeDepth(e.$1) + _safeDepth(e.$2)) * 0.5;
        final depthAlpha = _depthToAlpha(depth);
        final color = _sampleColor(
          (e.$1 + e.$2) * 0.5 / blended.length,
        ).withValues(alpha: 0.55 * depthAlpha * glowIntensity);
        final paint = Paint()
          ..color = color
          ..strokeWidth = lineThickness * (w / 200)
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
        canvas.drawLine(a, b, paint);
      }
    }

    // ---------- Pass 2: ball glow halo (back-to-front) ----------
    final order = List<int>.generate(blended.length, (i) => i);
    order.sort((a, b) => _depth[b].compareTo(_depth[a]));

    for (final i in order) {
      final p = _projected[i];
      final depthAlpha = _depthToAlpha(_depth[i]);
      final scale = math.max(
        0.3,
        1.0 - (_depth[i] - (-0.5)) / 1.6,
      ); // bigger near camera
      final radius = (w / 28) * nodeSize * scale;
      final color = _sampleColor(i / blended.length);

      // Soft outer glow.
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35 * depthAlpha * glowIntensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.4);
      canvas.drawCircle(p, radius * 2.0, glowPaint);

      // Bright core.
      final corePaint = Paint()
        ..color = color.withValues(alpha: 0.95 * depthAlpha);
      canvas.drawCircle(p, radius, corePaint);

      // Specular highlight to give the ball a 3D feel — matches the
      // icosahedron painter's style.
      final hiPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.55 * depthAlpha);
      canvas.drawCircle(
        p.translate(-radius * 0.3, -radius * 0.3),
        radius * 0.35,
        hiPaint,
      );
    }
  }

  // ---- helpers ----

  Offset? _safeOffset(int i) =>
      (i < 0 || i >= _projected.length) ? null : _projected[i];
  double _safeDepth(int i) => (i < 0 || i >= _depth.length) ? 0.0 : _depth[i];

  /// Fake z-fog: dots / lines further from camera lose alpha.
  double _depthToAlpha(double z) {
    // z roughly in [-1.5 .. 1.5]; near camera ≈ -1, far ≈ +1.
    final t = ((z + 1.0) / 2.0).clamp(0.0, 1.0);
    return 1.0 - t * 0.55;
  }

  /// Sample the gradient by `t` (0..1). Lerps the primary gradient first,
  /// then blends with the secondary gradient by [secondaryWeight].
  Color _sampleColor(double t) {
    final primary = _sampleGradient(gradientColors, t);
    if (secondaryGradient == null || secondaryWeight <= 0) return primary;
    final secondary = _sampleGradient(secondaryGradient!, t);
    return Color.lerp(primary, secondary, secondaryWeight.clamp(0.0, 1.0))!;
  }

  Color _sampleGradient(List<Color> colors, double t) {
    if (colors.isEmpty) return Colors.white;
    if (colors.length == 1) return colors.first;
    final clamped = t.clamp(0.0, 1.0);
    final scaled = clamped * (colors.length - 1);
    final idx = scaled.floor();
    final frac = scaled - idx;
    if (idx >= colors.length - 1) return colors.last;
    return Color.lerp(colors[idx], colors[idx + 1], frac)!;
  }

  @override
  bool shouldRepaint(covariant MeshMorphPainter old) =>
      // The blended list is reused (mutated in place) so we can't compare
      // by identity; the widget repaints on every animation tick anyway.
      true;
}
