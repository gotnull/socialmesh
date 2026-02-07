// SPDX-License-Identifier: GPL-3.0-or-later

// Sigil Painter — CustomPainter that renders deterministic geometric node identity.
//
// The sigil is a constellation-style geometric pattern built from:
// - An outer polygon (3-8 vertices)
// - Optional inner rings with scaled polygons
// - Optional radial lines from center to vertices
// - A center dot or void
// - Node-specific color palette
//
// The painter is stateless and lightweight. All geometry is computed
// from the SigilData parameters, which are themselves derived
// deterministically from the node number.
//
// Usage:
// ```dart
// SigilWidget(
//   sigil: entry.sigil,
//   size: 64,
// )
// ```

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/nodedex_entry.dart';
import '../models/sigil_evolution.dart';
import '../services/sigil_generator.dart';

/// Widget that renders a node's sigil at the specified size.
///
/// The sigil is rendered using CustomPaint for high performance.
/// It scales to any size while maintaining crisp vector rendering.
class SigilWidget extends StatelessWidget {
  /// The sigil data to render.
  final SigilData? sigil;

  /// The node number (used to generate sigil if [sigil] is null).
  final int? nodeNum;

  /// The rendered size (width and height are equal).
  final double size;

  /// Optional background color. If null, the background is transparent.
  final Color? backgroundColor;

  /// Whether to draw a subtle glow effect around the sigil.
  final bool showGlow;

  /// Opacity of the sigil lines and dots (0.0 to 1.0).
  final double opacity;

  /// Whether to render a circular border around the sigil.
  final bool showBorder;

  /// Border color override. Uses sigil primary color if null.
  final Color? borderColor;

  /// Optional evolution state for visual maturity effects.
  /// If null, the sigil renders with default (seed-level) appearance.
  final SigilEvolution? evolution;

  const SigilWidget({
    super.key,
    this.sigil,
    this.nodeNum,
    this.size = 56,
    this.backgroundColor,
    this.showGlow = false,
    this.opacity = 1.0,
    this.showBorder = false,
    this.borderColor,
    this.evolution,
  }) : assert(
         sigil != null || nodeNum != null,
         'Either sigil or nodeNum must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final effectiveSigil = sigil ?? SigilGenerator.generate(nodeNum!);

    Widget child = CustomPaint(
      size: Size(size, size),
      painter: _SigilPainter(
        sigil: effectiveSigil,
        showGlow: showGlow,
        opacity: opacity,
        showBorder: showBorder,
        borderColor: borderColor,
        evolution: evolution,
      ),
    );

    if (backgroundColor != null) {
      child = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: child,
      );
    } else {
      child = SizedBox(width: size, height: size, child: child);
    }

    return child;
  }
}

/// Compact sigil widget for use in list items.
///
/// Renders the sigil with a subtle background circle and appropriate
/// sizing for inline display in lists, chips, and badges.
class SigilAvatar extends StatelessWidget {
  /// The sigil data to render.
  final SigilData? sigil;

  /// The node number (used to generate sigil if [sigil] is null).
  final int? nodeNum;

  /// The rendered size (width and height are equal).
  final double size;

  /// Optional badge widget to overlay on the avatar.
  final Widget? badge;

  /// Optional evolution state for visual maturity effects.
  final SigilEvolution? evolution;

  const SigilAvatar({
    super.key,
    this.sigil,
    this.nodeNum,
    this.size = 44,
    this.badge,
    this.evolution,
  }) : assert(
         sigil != null || nodeNum != null,
         'Either sigil or nodeNum must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final effectiveSigil = sigil ?? SigilGenerator.generate(nodeNum!);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? effectiveSigil.primaryColor.withValues(alpha: 0.12)
        : effectiveSigil.primaryColor.withValues(alpha: 0.08);

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: effectiveSigil.primaryColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.15),
        child: CustomPaint(
          size: Size(size * 0.7, size * 0.7),
          painter: _SigilPainter(
            sigil: effectiveSigil,
            showGlow: false,
            opacity: 0.9,
            showBorder: false,
            evolution: evolution,
          ),
        ),
      ),
    );

    if (badge != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(bottom: -2, right: -2, child: badge!),
        ],
      );
    }

    return avatar;
  }
}

/// Large sigil display for detail screens and constellation nodes.
///
/// Renders the sigil with glow effect and optional animation support.
class SigilDisplay extends StatelessWidget {
  /// The sigil data to render.
  final SigilData? sigil;

  /// The node number (used to generate sigil if [sigil] is null).
  final int? nodeNum;

  /// The rendered size.
  final double size;

  /// Whether to show the glow effect.
  final bool showGlow;

  /// Whether to show the node trait color ring.
  final NodeTrait? trait;

  const SigilDisplay({
    super.key,
    this.sigil,
    this.nodeNum,
    this.size = 120,
    this.showGlow = true,
    this.trait,
  }) : assert(
         sigil != null || nodeNum != null,
         'Either sigil or nodeNum must be provided',
       );

  @override
  Widget build(BuildContext context) {
    final effectiveSigil = sigil ?? SigilGenerator.generate(nodeNum!);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark
        ? effectiveSigil.primaryColor.withValues(alpha: 0.08)
        : effectiveSigil.primaryColor.withValues(alpha: 0.05);

    final traitColor = trait?.color;

    Widget display = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: traitColor != null
            ? Border.all(color: traitColor.withValues(alpha: 0.5), width: 2.0)
            : Border.all(
                color: effectiveSigil.primaryColor.withValues(alpha: 0.2),
                width: 1.5,
              ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: effectiveSigil.primaryColor.withValues(alpha: 0.2),
                  blurRadius: size * 0.25,
                  spreadRadius: size * 0.05,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.18),
        child: CustomPaint(
          size: Size(size * 0.64, size * 0.64),
          painter: _SigilPainter(
            sigil: effectiveSigil,
            showGlow: showGlow,
            opacity: 1.0,
            showBorder: false,
          ),
        ),
      ),
    );

    return display;
  }
}

// =============================================================================
// Core Painter
// =============================================================================

/// CustomPainter that renders a sigil's geometric pattern.
///
/// The painting process:
/// 1. Compute all vertex positions for outer polygon and inner rings
/// 2. Draw edges (polygon sides, ring connections, radials)
/// 3. Draw vertex dots
/// 4. Draw center dot if enabled
/// 5. Optionally draw glow effects
///
/// The painter is efficient — it avoids allocations during paint()
/// by computing geometry from the immutable SigilData parameters.
class _SigilPainter extends CustomPainter {
  final SigilData sigil;
  final bool showGlow;
  final double opacity;
  final bool showBorder;
  final Color? borderColor;
  final SigilEvolution? evolution;

  _SigilPainter({
    required this.sigil,
    this.showGlow = false,
    this.opacity = 1.0,
    this.showBorder = false,
    this.borderColor,
    this.evolution,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.0 * 0.85;

    // Draw border circle if enabled.
    if (showBorder) {
      final borderPaint = Paint()
        ..color = (borderColor ?? sigil.primaryColor).withValues(
          alpha: 0.3 * opacity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(center, radius * 1.12, borderPaint);
    }

    // Compute vertex positions.
    final outerVertices = _computePolygonVertices(
      center: center,
      radius: radius,
      count: sigil.vertices,
      rotation: sigil.rotation,
    );

    // Inner ring vertices.
    final innerRingVertices = <List<Offset>>[];
    for (int ring = 1; ring <= sigil.innerRings; ring++) {
      final scale = 1.0 - (ring * 0.28);
      final ringRotation = sigil.rotation + (ring * 0.3);
      innerRingVertices.add(
        _computePolygonVertices(
          center: center,
          radius: radius * scale,
          count: sigil.vertices,
          rotation: ringRotation,
        ),
      );
    }

    // === Draw glow layer (behind everything) ===
    if (showGlow) {
      _drawGlow(canvas, center, radius, outerVertices);
    }

    // === Draw edges ===
    _drawEdges(canvas, outerVertices, innerRingVertices, center, radius);

    // === Draw micro-etch marks (evolution detail) ===
    if (evolution != null && evolution!.detailTier >= 1) {
      _drawMicroEtch(canvas, center, radius, outerVertices);
    }

    // === Draw vertex dots ===
    _drawVertexDots(canvas, outerVertices, innerRingVertices, center);

    // === Draw augment marks (evolution) ===
    if (evolution != null && evolution!.augments.isNotEmpty) {
      _drawAugments(canvas, center, radius, outerVertices);
    }
  }

  /// Compute polygon vertex positions.
  List<Offset> _computePolygonVertices({
    required Offset center,
    required double radius,
    required int count,
    required double rotation,
  }) {
    final vertices = <Offset>[];
    for (int i = 0; i < count; i++) {
      final angle = rotation + (i * math.pi * 2.0 / count) - math.pi / 2.0;
      vertices.add(
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
      );
    }
    return vertices;
  }

  /// Draw the glow effect behind the sigil.
  void _drawGlow(
    Canvas canvas,
    Offset center,
    double radius,
    List<Offset> outerVertices,
  ) {
    final glowPaint = Paint()
      ..color = sigil.primaryColor.withValues(alpha: 0.08 * opacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.3);

    // Draw glow as a series of lines between outer vertices.
    for (int i = 0; i < outerVertices.length; i++) {
      final next = (i + 1) % outerVertices.length;
      canvas.drawLine(
        outerVertices[i],
        outerVertices[next],
        glowPaint..strokeWidth = radius * 0.15,
      );
    }

    // Center glow dot.
    canvas.drawCircle(
      center,
      radius * 0.15,
      Paint()
        ..color = sigil.primaryColor.withValues(alpha: 0.06 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.2),
    );
  }

  /// Draw all edges: polygon sides, ring connections, and radials.
  void _drawEdges(
    Canvas canvas,
    List<Offset> outerVertices,
    List<List<Offset>> innerRingVertices,
    Offset center,
    double radius,
  ) {
    // Evolution scaling factors.
    final weightScale = evolution?.lineWeightScale ?? 1.0;
    final toneScale = evolution?.toneScale ?? 1.0;

    // Primary edge paint.
    final primaryPaint = Paint()
      ..color = sigil.primaryColor.withValues(
        alpha: (0.7 * toneScale).clamp(0.0, 1.0) * opacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edgeWidth(radius) * weightScale
      ..strokeCap = StrokeCap.round;

    // Secondary edge paint (for inner rings and connections).
    final secondaryPaint = Paint()
      ..color = sigil.secondaryColor.withValues(
        alpha: (0.5 * toneScale).clamp(0.0, 1.0) * opacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edgeWidth(radius) * 0.75 * weightScale
      ..strokeCap = StrokeCap.round;

    // Tertiary edge paint (for radials).
    final tertiaryPaint = Paint()
      ..color = sigil.tertiaryColor.withValues(
        alpha: (0.35 * toneScale).clamp(0.0, 1.0) * opacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edgeWidth(radius) * 0.5 * weightScale
      ..strokeCap = StrokeCap.round;

    // Draw outer polygon.
    for (int i = 0; i < outerVertices.length; i++) {
      final next = (i + 1) % outerVertices.length;
      canvas.drawLine(outerVertices[i], outerVertices[next], primaryPaint);
    }

    // Draw inner ring polygons and connections to outer ring.
    for (int ring = 0; ring < innerRingVertices.length; ring++) {
      final ringVerts = innerRingVertices[ring];
      final connectTo = ring == 0 ? outerVertices : innerRingVertices[ring - 1];

      // Inner polygon edges.
      for (int i = 0; i < ringVerts.length; i++) {
        final next = (i + 1) % ringVerts.length;
        canvas.drawLine(ringVerts[i], ringVerts[next], secondaryPaint);
      }

      // Connection lines to the previous ring.
      for (int i = 0; i < ringVerts.length; i++) {
        canvas.drawLine(connectTo[i], ringVerts[i], tertiaryPaint);
      }
    }

    // Draw radial lines if enabled.
    if (sigil.drawRadials) {
      final innermost = innerRingVertices.isNotEmpty
          ? innerRingVertices.last
          : null;

      if (sigil.centerDot) {
        // Draw radials from center to innermost ring (or outer if no rings).
        final targets = innermost ?? outerVertices;
        for (int i = 0; i < targets.length; i++) {
          // Use symmetry fold to skip some radials for visual variety.
          if (i % _radialSkip(sigil.symmetryFold, targets.length) == 0) {
            canvas.drawLine(center, targets[i], tertiaryPaint);
          }
        }
      } else if (innermost != null) {
        // Draw cross-connections within innermost ring based on symmetry.
        for (int i = 0; i < innermost.length; i++) {
          final target = (i + sigil.symmetryFold) % innermost.length;
          if (target != i) {
            canvas.drawLine(innermost[i], innermost[target], tertiaryPaint);
          }
        }
      } else {
        // No inner rings, no center dot — draw star pattern on outer vertices.
        for (int i = 0; i < outerVertices.length; i++) {
          final target = (i + sigil.symmetryFold) % outerVertices.length;
          if (target != i) {
            canvas.drawLine(
              outerVertices[i],
              outerVertices[target],
              tertiaryPaint,
            );
          }
        }
      }
    }
  }

  /// Draw dots at all vertex positions and optionally at center.
  void _drawVertexDots(
    Canvas canvas,
    List<Offset> outerVertices,
    List<List<Offset>> innerRingVertices,
    Offset center,
  ) {
    final dotRadius = _dotRadius(
      math.min(outerVertices.first.dx, outerVertices.first.dy).abs(),
    );

    // Outer vertex dots.
    final primaryDotPaint = Paint()
      ..color = sigil.primaryColor.withValues(alpha: 0.9 * opacity);

    for (final vertex in outerVertices) {
      canvas.drawCircle(vertex, dotRadius, primaryDotPaint);
    }

    // Inner ring vertex dots.
    final secondaryDotPaint = Paint()
      ..color = sigil.secondaryColor.withValues(alpha: 0.7 * opacity);

    for (final ringVerts in innerRingVertices) {
      for (final vertex in ringVerts) {
        canvas.drawCircle(vertex, dotRadius * 0.8, secondaryDotPaint);
      }
    }

    // Center dot.
    if (sigil.centerDot) {
      final centerDotPaint = Paint()
        ..color = sigil.tertiaryColor.withValues(alpha: 0.8 * opacity);

      canvas.drawCircle(center, dotRadius * 1.3, centerDotPaint);

      // Inner highlight.
      final highlightPaint = Paint()
        ..color = sigil.primaryColor.withValues(alpha: 0.3 * opacity);
      canvas.drawCircle(center, dotRadius * 0.6, highlightPaint);
    }
  }

  /// Calculate appropriate edge line width based on render size.
  double _edgeWidth(double radius) {
    // Scale line width with size but cap for readability.
    return (radius * 0.04).clamp(0.5, 3.0);
  }

  /// Calculate appropriate dot radius based on render size.
  double _dotRadius(double reference) {
    return (reference * 0.06).clamp(1.5, 5.0);
  }

  /// Calculate radial skip interval for symmetry-based drawing.
  int _radialSkip(int symmetryFold, int vertexCount) {
    if (symmetryFold >= vertexCount) return 1;
    final skip = vertexCount ~/ symmetryFold;
    return skip.clamp(1, vertexCount);
  }

  // ---------------------------------------------------------------------------
  // Evolution rendering
  // ---------------------------------------------------------------------------

  /// Draw subtle micro-etch marks inside the sigil based on detailTier.
  ///
  /// Tier 1: sparse inner dots along midpoints of outer edges.
  /// Tier 2: + faint bisecting lines between alternate vertices.
  /// Tier 3: + secondary midpoint dots at inner ring scale.
  /// Tier 4: + fine concentric arc fragments near center.
  void _drawMicroEtch(
    Canvas canvas,
    Offset center,
    double radius,
    List<Offset> outerVertices,
  ) {
    final tier = evolution!.detailTier;
    final etchAlpha = (0.12 * (evolution!.toneScale)).clamp(0.0, 1.0) * opacity;

    final etchPaint = Paint()
      ..color = sigil.tertiaryColor.withValues(alpha: etchAlpha)
      ..style = PaintingStyle.fill;

    final etchStrokePaint = Paint()
      ..color = sigil.tertiaryColor.withValues(alpha: etchAlpha * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edgeWidth(radius) * 0.35
      ..strokeCap = StrokeCap.round;

    final dotR = _dotRadius(radius) * 0.4;

    // Tier 1+: dots at midpoints of outer edges.
    for (int i = 0; i < outerVertices.length; i++) {
      final next = (i + 1) % outerVertices.length;
      final mid = Offset(
        (outerVertices[i].dx + outerVertices[next].dx) / 2.0,
        (outerVertices[i].dy + outerVertices[next].dy) / 2.0,
      );
      canvas.drawCircle(mid, dotR, etchPaint);
    }

    // Tier 2+: faint bisecting lines from alternate vertex midpoints
    // toward center, stopping at 40% radius.
    if (tier >= 2) {
      for (int i = 0; i < outerVertices.length; i += 2) {
        final next = (i + 1) % outerVertices.length;
        final mid = Offset(
          (outerVertices[i].dx + outerVertices[next].dx) / 2.0,
          (outerVertices[i].dy + outerVertices[next].dy) / 2.0,
        );
        // Direction from center to midpoint, scaled to 40%.
        final dx = mid.dx - center.dx;
        final dy = mid.dy - center.dy;
        final innerPoint = Offset(center.dx + dx * 0.4, center.dy + dy * 0.4);
        canvas.drawLine(mid, innerPoint, etchStrokePaint);
      }
    }

    // Tier 3+: secondary dots at 55% radius, offset from vertices.
    if (tier >= 3) {
      for (int i = 0; i < outerVertices.length; i++) {
        final dx = outerVertices[i].dx - center.dx;
        final dy = outerVertices[i].dy - center.dy;
        final innerDot = Offset(center.dx + dx * 0.55, center.dy + dy * 0.55);
        canvas.drawCircle(innerDot, dotR * 0.8, etchPaint);
      }
    }

    // Tier 4: fine arc fragments near center (20% radius).
    if (tier >= 4) {
      final arcRadius = radius * 0.2;
      final arcPaint = Paint()
        ..color = sigil.secondaryColor.withValues(alpha: etchAlpha * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _edgeWidth(radius) * 0.3
        ..strokeCap = StrokeCap.round;

      // Draw small arc segments between each pair of vertices.
      for (int i = 0; i < sigil.vertices; i++) {
        final startAngle =
            sigil.rotation +
            (i * math.pi * 2.0 / sigil.vertices) -
            math.pi / 2.0;
        final sweepAngle = math.pi * 2.0 / sigil.vertices * 0.4;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: arcRadius),
          startAngle,
          sweepAngle,
          false,
          arcPaint,
        );
      }
    }
  }

  /// Draw tiny augment marks near the outer ring.
  ///
  /// Each augment type has a distinct micro-mark:
  /// - relayMark: small directional tick at the top vertex.
  /// - wandererMark: tiny arc segment at the bottom.
  /// - ghostMark: faint hollow circle near top-right.
  void _drawAugments(
    Canvas canvas,
    Offset center,
    double radius,
    List<Offset> outerVertices,
  ) {
    final augAlpha = (0.25 * (evolution!.toneScale)).clamp(0.0, 1.0) * opacity;
    final markSize = radius * 0.08;

    for (final augment in evolution!.augments) {
      switch (augment) {
        case SigilAugment.relayMark:
          // Small directional tick at the first vertex.
          if (outerVertices.isNotEmpty) {
            final v = outerVertices[0];
            final dx = v.dx - center.dx;
            final dy = v.dy - center.dy;
            final len = math.sqrt(dx * dx + dy * dy);
            if (len > 0) {
              final nx = dx / len;
              final ny = dy / len;
              // Perpendicular.
              final px = -ny * markSize;
              final py = nx * markSize;
              final tip = Offset(
                v.dx + nx * markSize * 1.5,
                v.dy + ny * markSize * 1.5,
              );
              final paint = Paint()
                ..color = sigil.primaryColor.withValues(alpha: augAlpha)
                ..style = PaintingStyle.stroke
                ..strokeWidth = _edgeWidth(radius) * 0.5
                ..strokeCap = StrokeCap.round;
              canvas.drawLine(Offset(tip.dx - px, tip.dy - py), tip, paint);
              canvas.drawLine(Offset(tip.dx + px, tip.dy + py), tip, paint);
            }
          }

        case SigilAugment.wandererMark:
          // Tiny arc at the bottom of the sigil.
          final arcPaint = Paint()
            ..color = sigil.secondaryColor.withValues(alpha: augAlpha)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _edgeWidth(radius) * 0.5
            ..strokeCap = StrokeCap.round;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius * 1.05),
            math.pi * 0.35, // bottom-right arc
            math.pi * 0.3,
            false,
            arcPaint,
          );

        case SigilAugment.ghostMark:
          // Faint hollow circle near top-right.
          final ghostCenter = Offset(
            center.dx + radius * 0.7,
            center.dy - radius * 0.7,
          );
          final ghostPaint = Paint()
            ..color = sigil.tertiaryColor.withValues(alpha: augAlpha * 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = _edgeWidth(radius) * 0.4;
          canvas.drawCircle(ghostCenter, markSize * 0.6, ghostPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_SigilPainter oldDelegate) {
    return oldDelegate.sigil != sigil ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.opacity != opacity ||
        oldDelegate.showBorder != showBorder ||
        oldDelegate.evolution != evolution;
  }
}

/// Animated sigil widget that pulses gently to indicate activity.
///
/// Used for nodes that are currently online or actively transmitting.
class AnimatedSigilWidget extends StatefulWidget {
  final SigilData? sigil;
  final int? nodeNum;
  final double size;
  final bool animate;

  const AnimatedSigilWidget({
    super.key,
    this.sigil,
    this.nodeNum,
    this.size = 56,
    this.animate = true,
  }) : assert(
         sigil != null || nodeNum != null,
         'Either sigil or nodeNum must be provided',
       );

  @override
  State<AnimatedSigilWidget> createState() => _AnimatedSigilWidgetState();
}

class _AnimatedSigilWidgetState extends State<AnimatedSigilWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _opacityAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.animate) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedSigilWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return SigilWidget(
        sigil: widget.sigil,
        nodeNum: widget.nodeNum,
        size: widget.size,
      );
    }

    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return SigilWidget(
          sigil: widget.sigil,
          nodeNum: widget.nodeNum,
          size: widget.size,
          opacity: _opacityAnimation.value,
          showGlow: true,
        );
      },
    );
  }
}
