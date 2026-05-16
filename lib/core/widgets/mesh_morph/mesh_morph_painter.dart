// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// CustomPainter for MeshMorphWidget. Renders each ball as a vector-shaded
// 3D sphere using a RadialGradient — no rasterized sprites, no pixelation
// at any size.
//
// The 6 brightness levels and the lit-sphere look match the Equinox
// Vectorball original, but instead of blitting a 15×15 pre-baked PNG (which
// looks chunky when scaled up to 30+ px), we extract the highlight / mid /
// rim colours from each sprite and rebuild the sphere shading at the ball's
// actual paint radius. Same colour palette, infinitely sharp.
//
// Pipeline per frame:
//   1) Rotate all blended points through ZYX Tait-Bryan matrix.
//   2) Project to screen with perspective.
//   3) Sort indices back-to-front so closer balls paint over farther.
//   4) For each ball, compute its depth bucket (0..5) and draw a circle
//      shaded with a 3-stop RadialGradient pulled from that bucket's
//      palette samples. Highlight always sits upper-left, matching the
//      original sprite art's fixed light direction.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'mesh_shape.dart';
import 'vectorball_sprite_data.dart';

/// Number of brightness buckets. Matches the original Equinox sprite count.
const int kVectorballBrightnessLevels = 6;

class MeshMorphPainter extends CustomPainter {
  final List<Point3D> blended;
  final double rotationX;
  final double rotationY;
  final double rotationZ;

  /// Per-ball draw diameter as a fraction of widget width. 0.06 = 6 % of
  /// canvas width, so a 372 px canvas draws ~22 px balls. The cluster's
  /// physical extent is controlled by [clusterScale] not this.
  final double ballSizeFraction;

  /// Multiplier applied to the rotated model coords before perspective.
  /// Bigger = balls spread further across the canvas.
  final double clusterScale;

  MeshMorphPainter({
    required this.blended,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    this.ballSizeFraction = 0.07,
    this.clusterScale = 0.85,
  });

  // Pre-computed bucket palettes — extracted once from kVectorballSprite +
  // kVectorballPaletteRGB. Index = brightness bucket (0 dimmest .. 5 brightest).
  static final List<_BucketColors> _buckets = _buildBucketColors();

  // Reused scratch — survives across frames, never re-allocated.
  final List<double> _sx = <double>[];
  final List<double> _sy = <double>[];
  final List<double> _sz = <double>[];

  @override
  void paint(Canvas canvas, Size size) {
    // Tight perspective so near balls sit clearly in front of far ones.
    const perspective = 2.0;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final canvasScale = math.min(w, h) / 2 * clusterScale;
    final ballRadius = w * ballSizeFraction * 0.5;

    final n = blended.length;
    if (_sx.length != n) {
      _sx
        ..clear()
        ..addAll(List<double>.filled(n, 0));
      _sy
        ..clear()
        ..addAll(List<double>.filled(n, 0));
      _sz
        ..clear()
        ..addAll(List<double>.filled(n, 0));
    }

    final cosX = math.cos(rotationX);
    final sinX = math.sin(rotationX);
    final cosY = math.cos(rotationY);
    final sinY = math.sin(rotationY);
    final cosZ = math.cos(rotationZ);
    final sinZ = math.sin(rotationZ);

    double zMin = double.infinity;
    double zMax = -double.infinity;

    for (int i = 0; i < n; i++) {
      final p = blended[i];

      // Rotate Z → Y → X (same order as the rsvpnano firmware).
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
      _sx[i] = x3 * scale * canvasScale + cx;
      _sy[i] = y3 * scale * canvasScale + cy;
      _sz[i] = z3;
      if (z3 < zMin) zMin = z3;
      if (z3 > zMax) zMax = z3;
    }

    // Back-to-front painter's order — sort indices, not balls.
    final order = List<int>.generate(n, (i) => i);
    order.sort((a, b) => _sz[b].compareTo(_sz[a]));

    // Use the actual observed [zMin..zMax] range so the cluster always
    // exercises the full bucket brightness range regardless of shape.
    final zSpan = (zMax - zMin).abs() < 1e-4 ? 1.0 : (zMax - zMin);
    const lastBucket = kVectorballBrightnessLevels - 1;

    // Highlight position in upper-left, matching the original sprite art.
    // Alignment is relative to the ball's bounding rect — same offset for
    // every ball so the cluster reads as lit from a single source.
    const highlightAlign = Alignment(-0.45, -0.45);

    for (final i in order) {
      // Nearest ball = brightest bucket (5), farthest = bucket 0.
      final t = (_sz[i] - zMin) / zSpan; // 0 near, 1 far
      var bucketIdx = (lastBucket - (t * lastBucket).round()).toInt();
      if (bucketIdx < 0) bucketIdx = 0;
      if (bucketIdx > lastBucket) bucketIdx = lastBucket;

      final bucket = _buckets[bucketIdx];
      final centre = Offset(_sx[i], _sy[i]);
      final ballRect = Rect.fromCircle(center: centre, radius: ballRadius);

      // Fresh shader per ball — RadialGradient.createShader is cheap
      // (no rasterization happens until canvas.drawCircle below).
      final shader = RadialGradient(
        center: highlightAlign,
        radius: 0.85,
        colors: [bucket.highlight, bucket.mid, bucket.rim],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(ballRect);

      canvas.drawCircle(centre, ballRadius, Paint()..shader = shader);
    }
  }

  @override
  bool shouldRepaint(covariant MeshMorphPainter old) =>
      old.blended != blended ||
      old.rotationX != rotationX ||
      old.rotationY != rotationY ||
      old.rotationZ != rotationZ ||
      old.ballSizeFraction != ballSizeFraction ||
      old.clusterScale != clusterScale;

  // -------------------------------------------------------------------------
  // Bucket palette extraction. Each of the 6 sprite stamps in
  // kVectorballSprite uses a range of palette indices to fake a 3D-lit
  // sphere. We sample three points from each sprite — brightest pixel,
  // median pixel, and dimmest visible pixel — to build a 3-stop gradient
  // that reproduces the sprite's overall colour ramp.
  // -------------------------------------------------------------------------

  static List<_BucketColors> _buildBucketColors() {
    final out = <_BucketColors>[];
    for (int b = 0; b < kVectorballBrightnessLevels; b++) {
      final sprite = kVectorballSprite[b];
      // Collect every non-zero (i.e. non-transparent) pixel's palette
      // index. Lower index = brighter colour in the Equinox palette.
      final values = <int>[];
      for (final row in sprite) {
        for (final v in row) {
          if (v != 0) values.add(v);
        }
      }
      values.sort(); // ascending = bright → dim
      final highlightIdx = values.first;
      final midIdx = values[values.length ~/ 2];
      final rimIdx = values.last;
      out.add(
        _BucketColors(
          highlight: _palColor(highlightIdx),
          mid: _palColor(midIdx),
          rim: _palColor(rimIdx),
        ),
      );
    }
    return out;
  }

  static Color _palColor(int idx) {
    final off = idx * 3;
    return Color.fromARGB(
      255,
      kVectorballPaletteRGB[off],
      kVectorballPaletteRGB[off + 1],
      kVectorballPaletteRGB[off + 2],
    );
  }
}

class _BucketColors {
  final Color highlight;
  final Color mid;
  final Color rim;
  const _BucketColors({
    required this.highlight,
    required this.mid,
    required this.rim,
  });
}
