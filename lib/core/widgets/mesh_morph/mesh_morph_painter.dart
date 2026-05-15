// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// CustomPainter for MeshMorphWidget. Rotates + projects the blended shape
// buffer, then draws each point as a soft-glow ball using the SocialMesh
// brand gradient. Intentionally omits two things the earlier version had:
//
//   - Wireframe edge lines connecting points (removed: visually noisy,
//     z-order issues during morph).
//   - Per-ball white specular highlight + depth-modulated alpha (removed:
//     the moving highlight + alpha pulse together read as "flashing").
//
// Result: a calm point cloud with subtle depth-scale, no visual jitter.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:socialmesh/core/theme.dart';

import 'mesh_shape.dart';

class MeshMorphPainter extends CustomPainter {
  /// Pre-resolved positions for the current frame. Length == pointCount.
  final List<Point3D> blended;

  /// Euler angles (radians) applied before projection. Mirrors the
  /// AnimatedMeshNode rotation pipeline.
  final double rotationX;
  final double rotationY;
  final double rotationZ;

  MeshMorphPainter({
    required this.blended,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
  });

  // Brand triple, same one AnimatedMeshNode and the splash logo use.
  static const List<Color> _brandGradient = [
    AppTheme.accentOrange,
    AppTheme.primaryMagenta,
    AppTheme.primaryBlue,
  ];

  // Projection scratch buffers — kept across frames so the math output
  // doesn't re-allocate per paint.
  final List<Offset> _projected = <Offset>[];
  final List<double> _depth = <double>[];

  @override
  void paint(Canvas canvas, Size size) {
    const perspective = 3.0;
    final w = size.width;
    final cx = w / 2;
    final cy = size.height / 2;

    if (_projected.length != blended.length) {
      _projected
        ..clear()
        ..addAll(List<Offset>.filled(blended.length, Offset.zero));
      _depth
        ..clear()
        ..addAll(List<double>.filled(blended.length, 0));
    }

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final cosZ = math.cos(rotationZ);
    final sinZ = math.sin(rotationZ);

    for (int i = 0; i < blended.length; i++) {
      final p = blended[i];

      final x1 = p.x * cosZ - p.y * sinZ;
      final y1 = p.x * sinZ + p.y * cosZ;
      final z1 = p.z;

      final x2 = x1 * cosY + z1 * sinY;
      final y2 = y1;
      final z2 = -x1 * sinY + z1 * cosY;

      final x3 = x2;
      final y3 = y2 * cosX - z2 * sinX;
      final z3 = y2 * sinX + z2 * cosX;

      final scale = perspective / (perspective + z3);
      _projected[i] = Offset(x3 * scale * w / 2 + cx, y3 * scale * w / 2 + cy);
      _depth[i] = z3;
    }

    // Back-to-front so closer balls overwrite farther ones cleanly.
    final order = List<int>.generate(blended.length, (i) => i);
    order.sort((a, b) => _depth[b].compareTo(_depth[a]));

    for (final i in order) {
      final p = _projected[i];
      // Smoothly map depth (-1 near .. +1 far) to a size factor in
      // [0.55, 1.0]. Single curve — no random per-point variation, so
      // the visual stays calm as balls rotate.
      final sizeFactor = (1.0 - (_depth[i] + 1.0) / 4.0).clamp(0.55, 1.0);
      final radius = (w / 36) * sizeFactor;
      final color = _sampleGradient(i / blended.length);

      // Soft outer glow at a fixed alpha — no per-frame pulsing.
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.28)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 1.2);
      canvas.drawCircle(p, radius * 1.8, glowPaint);

      // Solid core, fixed alpha.
      final corePaint = Paint()..color = color.withValues(alpha: 0.92);
      canvas.drawCircle(p, radius, corePaint);
    }
  }

  Color _sampleGradient(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final scaled = clamped * (_brandGradient.length - 1);
    final idx = scaled.floor();
    final frac = scaled - idx;
    if (idx >= _brandGradient.length - 1) return _brandGradient.last;
    return Color.lerp(_brandGradient[idx], _brandGradient[idx + 1], frac)!;
  }

  @override
  bool shouldRepaint(covariant MeshMorphPainter old) => true;
}
