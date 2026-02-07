// SPDX-License-Identifier: GPL-3.0-or-later

// Identity Overlay Painter — subtle constellation-like background pattern.
//
// Renders a low-opacity geometric pattern behind NodeDex UI elements,
// derived deterministically from the node's identity seed. The overlay
// is never full-screen — it is used only inside list tiles and detail
// headers as a subtle visual fingerprint.
//
// The pattern is built from the same murmur3-style hash as the sigil,
// ensuring visual consistency: the overlay "rhymes" with the sigil
// without duplicating it.
//
// Design constraints:
//   - Opacity must be very low (controlled by `density` parameter)
//   - Must not reduce text readability
//   - Fully deterministic from nodeNum alone
//   - Lightweight: no allocations per frame after initial compute
//   - Works on both light and dark backgrounds

import 'package:flutter/material.dart';

import '../services/sigil_generator.dart';

/// A point in the identity overlay pattern.
///
/// Precomputed from the node's identity seed. Positions are normalized
/// to 0.0–1.0 and scaled to the render size at paint time.
class OverlayPoint {
  /// Normalized x position (0.0 to 1.0).
  final double x;

  /// Normalized y position (0.0 to 1.0).
  final double y;

  /// Radius multiplier (0.5 to 1.5) for visual variety.
  final double radiusScale;

  /// Whether this point connects to the next point in the list.
  final bool connectNext;

  const OverlayPoint({
    required this.x,
    required this.y,
    required this.radiusScale,
    required this.connectNext,
  });
}

/// Precomputed overlay data for a single node identity.
///
/// Created once per node and reused across frames. The data is
/// fully deterministic from the nodeNum.
class IdentityOverlayData {
  /// The node number this overlay was generated for.
  final int nodeNum;

  /// The computed points in the overlay pattern.
  final List<OverlayPoint> points;

  /// Primary color from the node's sigil.
  final Color color;

  /// Number of connection lines to draw.
  final int connectionCount;

  const IdentityOverlayData({
    required this.nodeNum,
    required this.points,
    required this.color,
    required this.connectionCount,
  });

  /// Generate overlay data from a node number.
  ///
  /// The result is always the same for the same [nodeNum].
  /// This is a pure function with no side effects.
  ///
  /// [pointCount] controls the number of dots in the pattern.
  /// Default is 12, which produces a subtle effect. Higher values
  /// create denser patterns suitable for larger render areas.
  factory IdentityOverlayData.generate(int nodeNum, {int pointCount = 12}) {
    final sigil = SigilGenerator.generate(nodeNum);
    final color = sigil.primaryColor;

    // Generate deterministic points using cascading hash rounds.
    // Each point uses two hash rounds: one for position, one for properties.
    final points = <OverlayPoint>[];
    int hash = SigilGenerator.mix(nodeNum);

    // Secondary hash seed for point properties.
    int propHash = SigilGenerator.mix(hash ^ 0xA5A5A5A5);

    for (int i = 0; i < pointCount; i++) {
      hash = SigilGenerator.mix(hash);
      propHash = SigilGenerator.mix(propHash);

      // Extract x, y from hash bits (normalized to 0.0–1.0).
      // Use golden-ratio-based distribution for visual spread.
      final xRaw = ((hash & 0xFFFF) / 65535.0);
      final yRaw = (((hash >> 16) & 0xFFFF) / 65535.0);

      // Apply a subtle golden-ratio-based offset per point to avoid
      // clustering. The golden ratio (φ ≈ 0.618) produces a
      // quasi-random low-discrepancy sequence.
      const phi = 0.6180339887498949;
      final x = (xRaw + i * phi) % 1.0;
      final y = (yRaw + i * phi * 0.7) % 1.0;

      // Radius scale from property hash (0.5 to 1.5).
      final radiusBits = (propHash & 0xFF) / 255.0;
      final radiusScale = 0.5 + radiusBits;

      // Connection probability from property hash (roughly 40% connect).
      final connectBit = ((propHash >> 8) & 0xFF) < 102;

      points.add(
        OverlayPoint(
          x: x,
          y: y,
          radiusScale: radiusScale,
          connectNext: connectBit,
        ),
      );
    }

    // Connection count derived from sigil symmetry.
    final connectionCount = sigil.symmetryFold + sigil.innerRings;

    return IdentityOverlayData(
      nodeNum: nodeNum,
      points: points,
      color: color,
      connectionCount: connectionCount.clamp(2, 8),
    );
  }
}

/// CustomPainter that renders the identity overlay pattern.
///
/// This painter draws:
/// 1. Small luminous dots at precomputed positions
/// 2. Faint connecting lines between selected dot pairs
/// 3. Optional radial arcs for visual interest
///
/// The overall opacity is controlled by [density], which should be
/// kept very low (0.05–0.40) to avoid reducing readability of
/// overlaid text and UI elements.
class IdentityOverlayPainter extends CustomPainter {
  /// The precomputed overlay data.
  final IdentityOverlayData data;

  /// Overall opacity multiplier (0.0 to 1.0).
  ///
  /// This controls how visible the overlay is. Values above 0.4
  /// risk reducing readability. Typical range: 0.05 to 0.25.
  final double density;

  /// Whether the current theme is dark mode.
  ///
  /// Affects how the overlay blends with the background.
  final bool isDark;

  /// Base radius for overlay dots in logical pixels.
  static const double _baseDotRadius = 1.5;

  /// Width of connection lines in logical pixels.
  static const double _lineWidth = 0.5;

  IdentityOverlayPainter({
    required this.data,
    required this.density,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (density <= 0.0 || data.points.isEmpty) return;

    final effectiveDensity = density.clamp(0.0, 0.5);

    // Compute pixel positions.
    final positions = <Offset>[];
    for (final point in data.points) {
      positions.add(Offset(point.x * size.width, point.y * size.height));
    }

    // Draw connection lines first (behind dots).
    _paintConnections(canvas, positions, effectiveDensity);

    // Draw dots.
    _paintDots(canvas, size, positions, effectiveDensity);
  }

  void _paintConnections(
    Canvas canvas,
    List<Offset> positions,
    double effectiveDensity,
  ) {
    if (positions.length < 2) return;

    final linePaint = Paint()
      ..color = data.color.withValues(alpha: effectiveDensity * 0.4)
      ..strokeWidth = _lineWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw connections based on precomputed flags.
    int connectionsDrawn = 0;
    for (
      int i = 0;
      i < data.points.length && connectionsDrawn < data.connectionCount;
      i++
    ) {
      if (data.points[i].connectNext && i + 1 < positions.length) {
        canvas.drawLine(positions[i], positions[i + 1], linePaint);
        connectionsDrawn++;
      }
    }

    // If we still have connection budget, draw a few cross-links
    // based on point indices modulo the list length.
    if (connectionsDrawn < data.connectionCount && positions.length >= 4) {
      final crossPaint = Paint()
        ..color = data.color.withValues(alpha: effectiveDensity * 0.2)
        ..strokeWidth = _lineWidth * 0.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Deterministic cross-links using index arithmetic.
      final step = positions.length ~/ 3;
      if (step > 0) {
        for (
          int i = 0;
          i < positions.length && connectionsDrawn < data.connectionCount;
          i += step
        ) {
          final j = (i + step) % positions.length;
          if (i != j) {
            canvas.drawLine(positions[i], positions[j], crossPaint);
            connectionsDrawn++;
          }
        }
      }
    }
  }

  void _paintDots(
    Canvas canvas,
    Size size,
    List<Offset> positions,
    double effectiveDensity,
  ) {
    // Glow paint — soft halo behind each dot.
    final glowPaint = Paint()
      ..color = data.color.withValues(alpha: effectiveDensity * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // Dot paint — crisp center point.
    final dotPaint = Paint()
      ..color = data.color.withValues(alpha: effectiveDensity * 0.7);

    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final radius = _baseDotRadius * data.points[i].radiusScale;

      // Skip points too close to edges (2% margin) to avoid clipping.
      if (pos.dx < size.width * 0.02 ||
          pos.dx > size.width * 0.98 ||
          pos.dy < size.height * 0.02 ||
          pos.dy > size.height * 0.98) {
        continue;
      }

      // Glow
      canvas.drawCircle(pos, radius * 3.0, glowPaint);

      // Dot
      canvas.drawCircle(pos, radius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(IdentityOverlayPainter oldDelegate) {
    return oldDelegate.data.nodeNum != data.nodeNum ||
        oldDelegate.density != density ||
        oldDelegate.isDark != isDark;
  }
}

/// Widget wrapper for the identity overlay.
///
/// Renders the overlay as a background layer behind [child].
/// The overlay is clipped to the widget bounds and never exceeds
/// the specified [density] opacity.
///
/// Usage:
/// ```dart
/// IdentityOverlay(
///   nodeNum: entry.nodeNum,
///   density: disclosure.overlayDensity,
///   child: YourContent(),
/// )
/// ```
class IdentityOverlay extends StatelessWidget {
  /// The node number to generate the overlay for.
  final int nodeNum;

  /// Overlay density (0.0 to 1.0). Keep below 0.4 for readability.
  final double density;

  /// Number of dots in the pattern. Default 12 for list tiles,
  /// use 18–24 for larger areas like detail headers.
  final int pointCount;

  /// The content to render on top of the overlay.
  final Widget child;

  /// Precomputed overlay data. If null, computed from [nodeNum].
  final IdentityOverlayData? overlayData;

  const IdentityOverlay({
    super.key,
    required this.nodeNum,
    required this.density,
    this.pointCount = 12,
    required this.child,
    this.overlayData,
  });

  @override
  Widget build(BuildContext context) {
    if (density <= 0.0) return child;

    final data =
        overlayData ??
        IdentityOverlayData.generate(nodeNum, pointCount: pointCount);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: IdentityOverlayPainter(
                data: data,
                density: density,
                isDark: isDark,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Compact overlay for list tiles.
///
/// A convenience wrapper that uses lower point count and density
/// appropriate for small UI elements like list tile backgrounds.
class IdentityOverlayTile extends StatelessWidget {
  /// The node number to generate the overlay for.
  final int nodeNum;

  /// Overlay density. Defaults to a subtle 0.08.
  final double density;

  /// The content to render on top of the overlay.
  final Widget child;

  const IdentityOverlayTile({
    super.key,
    required this.nodeNum,
    this.density = 0.08,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (density <= 0.0) return child;

    return IdentityOverlay(
      nodeNum: nodeNum,
      density: density,
      pointCount: 8,
      child: child,
    );
  }
}
