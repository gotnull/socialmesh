// SPDX-License-Identifier: GPL-3.0-or-later

// Animated Sigil Painter — rich CustomPainter with animation parameters.
//
// This painter extends the static sigil rendering concept with animation
// parameters that are driven externally by AnimationControllers. The
// painter itself is stateless — it receives animation values and renders
// a single frame. This keeps the painting pure and efficient.
//
// Animation layers (all optional, composable):
//
// 1. REVEAL (revealProgress 0.0 → 1.0)
//    Edges draw on sequentially, vertex dots fade in as their edges
//    complete, center dot appears last. Creates a "constellation
//    materializing" effect.
//
// 2. ROTATION (rotationDelta, radians)
//    Additional rotation applied to the sigil layers. Outer polygon
//    rotates forward, inner rings counter-rotate at different speeds,
//    creating a mesmerizing orbital effect.
//
// 3. PULSE (pulsePhase 0.0 → 1.0, cyclic)
//    Vertex dots scale and brighten independently with staggered
//    timing, producing a constellation twinkle effect. Each dot's
//    phase is offset by its index for visual variety.
//
// 4. GLOW (glowIntensity 0.0 → 1.0)
//    Outer glow blur radius and alpha breathe with this value.
//    At 0 the glow is minimal; at 1 it's fully saturated.
//
// 5. TRACE (tracePosition 0.0 → 1.0, cyclic)
//    A bright signal dot travels along all edges in sequence,
//    leaving a short luminous trail. Evokes data traversing the
//    mesh network.
//
// The painter works with ANY SigilData — the animation is orthogonal
// to the identity. Same animations, different geometry and colors.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/nodedex_entry.dart';

/// CustomPainter that renders animated sigil geometry.
///
/// All animation parameters default to their "fully visible, no animation"
/// state so the painter can also serve as a static renderer when no
/// animation controllers are connected.
class AnimatedSigilPainter extends CustomPainter {
  /// The sigil identity data (geometry + colors).
  final SigilData sigil;

  /// Draw-on reveal progress (0.0 = nothing visible, 1.0 = fully drawn).
  final double revealProgress;

  /// Additional rotation in radians applied to the geometry layers.
  /// Outer polygon rotates by this value; inner rings counter-rotate.
  final double rotationDelta;

  /// Cyclic pulse phase (0.0 → 1.0) for vertex dot twinkle.
  final double pulsePhase;

  /// Glow intensity multiplier (0.0 = dim, 1.0 = full glow).
  final double glowIntensity;

  /// Edge tracer position (0.0 → 1.0) along the total edge path.
  /// Set to a negative value to disable the tracer.
  final double tracePosition;

  /// Base opacity for all elements (0.0 → 1.0).
  final double opacity;

  /// Whether to render the outer glow layer.
  final bool showGlow;

  /// Whether to render the circular border.
  final bool showBorder;

  /// Border color override. Uses sigil primary color if null.
  final Color? borderColor;

  AnimatedSigilPainter({
    required this.sigil,
    this.revealProgress = 1.0,
    this.rotationDelta = 0.0,
    this.pulsePhase = 0.0,
    this.glowIntensity = 0.5,
    this.tracePosition = -1.0,
    this.opacity = 1.0,
    this.showGlow = false,
    this.showBorder = false,
    this.borderColor,
  });

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  /// How many segments the tracer trail spans (as a fraction of total edges).
  static const double _traceTrailLength = 0.08;

  /// Maximum dot scale factor during pulse.
  static const double _pulseScaleAmplitude = 0.35;

  /// Maximum dot brightness boost during pulse.
  static const double _pulseBrightnessAmplitude = 0.25;

  /// Counter-rotation multipliers for inner rings.
  /// Ring 1 rotates opposite at 70% speed, ring 2 same dir at 50%, etc.
  static const List<double> _ringRotationFactors = [-0.7, 0.5, -0.3];

  // ---------------------------------------------------------------------------
  // Paint
  // ---------------------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2.0 * 0.85;

    // Effective opacity combines base opacity with reveal fade-in.
    final effectiveOpacity = opacity * _revealOpacity();

    if (effectiveOpacity <= 0.0) return;

    // --- Compute geometry with animated rotation ---

    final outerRotation = sigil.rotation + rotationDelta;
    final outerVertices = _computePolygonVertices(
      center: center,
      radius: radius,
      count: sigil.vertices,
      rotation: outerRotation,
    );

    final innerRingVertices = <List<Offset>>[];
    for (int ring = 1; ring <= sigil.innerRings; ring++) {
      final baseScale = 1.0 - (ring * 0.28);
      final baseRingRotation = sigil.rotation + (ring * 0.3);
      final ringRotFactor = ring <= _ringRotationFactors.length
          ? _ringRotationFactors[ring - 1]
          : 0.0;
      final animatedRingRotation =
          baseRingRotation + (rotationDelta * ringRotFactor);

      innerRingVertices.add(
        _computePolygonVertices(
          center: center,
          radius: radius * baseScale,
          count: sigil.vertices,
          rotation: animatedRingRotation,
        ),
      );
    }

    // --- Build the ordered edge list for reveal and tracing ---

    final allEdges = _buildEdgeList(outerVertices, innerRingVertices, center);
    final totalEdges = allEdges.length;

    // --- Draw border ---

    if (showBorder) {
      _drawBorder(canvas, center, radius, effectiveOpacity);
    }

    // --- Draw glow (behind everything) ---

    if (showGlow && glowIntensity > 0.0) {
      _drawAnimatedGlow(
        canvas,
        center,
        radius,
        outerVertices,
        effectiveOpacity,
      );
    }

    // --- Draw edges with reveal ---

    final revealEdgeCount = (revealProgress * totalEdges).clamp(0, totalEdges);

    for (int i = 0; i < totalEdges; i++) {
      final edge = allEdges[i];
      if (i.toDouble() >= revealEdgeCount) break;

      // Partial draw for the last revealing edge.
      final edgeFraction = i < revealEdgeCount.floor()
          ? 1.0
          : (revealEdgeCount - revealEdgeCount.floor()).toDouble();

      _drawEdge(canvas, edge, edgeFraction, effectiveOpacity, radius);
    }

    // --- Draw vertex dots with reveal and pulse ---

    _drawAnimatedVertexDots(
      canvas,
      outerVertices,
      innerRingVertices,
      center,
      radius,
      effectiveOpacity,
      allEdges,
      revealEdgeCount.toDouble(),
    );

    // --- Draw edge tracer ---

    if (tracePosition >= 0.0 && revealProgress >= 1.0 && totalEdges > 0) {
      _drawTracer(canvas, allEdges, radius, effectiveOpacity);
    }
  }

  // ---------------------------------------------------------------------------
  // Reveal helpers
  // ---------------------------------------------------------------------------

  /// Overall opacity ramp during the first 20% of reveal.
  double _revealOpacity() {
    if (revealProgress >= 0.2) return 1.0;
    return (revealProgress / 0.2).clamp(0.0, 1.0);
  }

  /// Whether a vertex index has been "revealed" based on edge progress.
  /// A vertex is visible once any edge touching it has begun drawing.
  bool _isVertexRevealed(
    _EdgeLayer vertexLayer,
    int vertexIndex,
    List<_AnimEdge> allEdges,
    double revealEdgeCount,
  ) {
    if (revealProgress >= 1.0) return true;

    for (int i = 0; i < revealEdgeCount.ceil() && i < allEdges.length; i++) {
      final edge = allEdges[i];
      if (edge.layer == vertexLayer) {
        if (edge.fromIndex == vertexIndex || edge.toIndex == vertexIndex) {
          return true;
        }
      }
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Geometry
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Edge list construction
  // ---------------------------------------------------------------------------

  /// Build an ordered list of all edges for sequential reveal and tracing.
  ///
  /// Order: outer polygon → ring connections → inner polygons → radials.
  /// This creates a satisfying draw-on sequence: frame appears first,
  /// then connections web inward, then internal structure materializes.
  List<_AnimEdge> _buildEdgeList(
    List<Offset> outerVertices,
    List<List<Offset>> innerRingVertices,
    Offset center,
  ) {
    final edges = <_AnimEdge>[];
    final v = sigil.vertices;

    // Phase 1: Outer polygon edges.
    for (int i = 0; i < v; i++) {
      final next = (i + 1) % v;
      edges.add(
        _AnimEdge(
          from: outerVertices[i],
          to: outerVertices[next],
          layer: _EdgeLayer.outer,
          colorTier: _ColorTier.primary,
          fromIndex: i,
          toIndex: next,
        ),
      );
    }

    // Phase 2: Ring connections and inner polygon edges.
    for (int ring = 0; ring < innerRingVertices.length; ring++) {
      final ringVerts = innerRingVertices[ring];
      final connectTo = ring == 0 ? outerVertices : innerRingVertices[ring - 1];

      // Connection lines first (web outward to inward).
      for (int i = 0; i < v; i++) {
        edges.add(
          _AnimEdge(
            from: connectTo[i],
            to: ringVerts[i],
            layer: _EdgeLayer.connection,
            colorTier: _ColorTier.tertiary,
            fromIndex: i,
            toIndex: i,
          ),
        );
      }

      // Then inner polygon edges.
      for (int i = 0; i < v; i++) {
        final next = (i + 1) % v;
        edges.add(
          _AnimEdge(
            from: ringVerts[i],
            to: ringVerts[next],
            layer: _EdgeLayer.inner,
            colorTier: _ColorTier.secondary,
            fromIndex: i,
            toIndex: next,
          ),
        );
      }
    }

    // Phase 3: Radial lines.
    if (sigil.drawRadials) {
      final innermost = innerRingVertices.isNotEmpty
          ? innerRingVertices.last
          : null;

      if (sigil.centerDot) {
        final targets = innermost ?? outerVertices;
        for (int i = 0; i < targets.length; i++) {
          if (i % _radialSkip(sigil.symmetryFold, targets.length) == 0) {
            edges.add(
              _AnimEdge(
                from: center,
                to: targets[i],
                layer: _EdgeLayer.radial,
                colorTier: _ColorTier.tertiary,
                fromIndex: -1,
                toIndex: i,
              ),
            );
          }
        }
      } else if (innermost != null) {
        for (int i = 0; i < innermost.length; i++) {
          final target = (i + sigil.symmetryFold) % innermost.length;
          if (target != i) {
            edges.add(
              _AnimEdge(
                from: innermost[i],
                to: innermost[target],
                layer: _EdgeLayer.radial,
                colorTier: _ColorTier.tertiary,
                fromIndex: i,
                toIndex: target,
              ),
            );
          }
        }
      } else {
        for (int i = 0; i < outerVertices.length; i++) {
          final target = (i + sigil.symmetryFold) % outerVertices.length;
          if (target != i) {
            edges.add(
              _AnimEdge(
                from: outerVertices[i],
                to: outerVertices[target],
                layer: _EdgeLayer.radial,
                colorTier: _ColorTier.tertiary,
                fromIndex: i,
                toIndex: target,
              ),
            );
          }
        }
      }
    }

    return edges;
  }

  int _radialSkip(int symmetryFold, int vertexCount) {
    if (symmetryFold >= vertexCount) return 1;
    final skip = vertexCount ~/ symmetryFold;
    return skip.clamp(1, vertexCount);
  }

  // ---------------------------------------------------------------------------
  // Drawing: border
  // ---------------------------------------------------------------------------

  void _drawBorder(
    Canvas canvas,
    Offset center,
    double radius,
    double effectiveOpacity,
  ) {
    final borderPaint = Paint()
      ..color = (borderColor ?? sigil.primaryColor).withValues(
        alpha: 0.3 * effectiveOpacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius * 1.12, borderPaint);
  }

  // ---------------------------------------------------------------------------
  // Drawing: glow
  // ---------------------------------------------------------------------------

  void _drawAnimatedGlow(
    Canvas canvas,
    Offset center,
    double radius,
    List<Offset> outerVertices,
    double effectiveOpacity,
  ) {
    // Glow intensity modulates both alpha and blur radius.
    final glowAlpha = 0.04 + (0.08 * glowIntensity);
    final blurSigma = radius * (0.2 + 0.15 * glowIntensity);

    final glowPaint = Paint()
      ..color = sigil.primaryColor.withValues(
        alpha: glowAlpha * effectiveOpacity,
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);

    // Draw glow along outer polygon edges.
    for (int i = 0; i < outerVertices.length; i++) {
      final next = (i + 1) % outerVertices.length;
      canvas.drawLine(
        outerVertices[i],
        outerVertices[next],
        glowPaint..strokeWidth = radius * (0.1 + 0.08 * glowIntensity),
      );
    }

    // Center glow orb.
    final centerGlowAlpha = 0.03 + (0.06 * glowIntensity);
    canvas.drawCircle(
      center,
      radius * (0.12 + 0.06 * glowIntensity),
      Paint()
        ..color = sigil.primaryColor.withValues(
          alpha: centerGlowAlpha * effectiveOpacity,
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          radius * (0.15 + 0.1 * glowIntensity),
        ),
    );
  }

  // ---------------------------------------------------------------------------
  // Drawing: edges
  // ---------------------------------------------------------------------------

  void _drawEdge(
    Canvas canvas,
    _AnimEdge edge,
    double fraction,
    double effectiveOpacity,
    double radius,
  ) {
    if (fraction <= 0.0) return;

    final color = _colorForTier(edge.colorTier);
    final alphaBase = _alphaForTier(edge.colorTier);
    final widthFactor = _widthFactorForTier(edge.colorTier);

    final paint = Paint()
      ..color = color.withValues(alpha: alphaBase * effectiveOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = _edgeWidth(radius) * widthFactor
      ..strokeCap = StrokeCap.round;

    if (fraction >= 1.0) {
      canvas.drawLine(edge.from, edge.to, paint);
    } else {
      // Partial edge: interpolate the endpoint.
      final partialTo = Offset(
        edge.from.dx + (edge.to.dx - edge.from.dx) * fraction,
        edge.from.dy + (edge.to.dy - edge.from.dy) * fraction,
      );
      canvas.drawLine(edge.from, partialTo, paint);
    }
  }

  Color _colorForTier(_ColorTier tier) {
    return switch (tier) {
      _ColorTier.primary => sigil.primaryColor,
      _ColorTier.secondary => sigil.secondaryColor,
      _ColorTier.tertiary => sigil.tertiaryColor,
    };
  }

  double _alphaForTier(_ColorTier tier) {
    return switch (tier) {
      _ColorTier.primary => 0.7,
      _ColorTier.secondary => 0.5,
      _ColorTier.tertiary => 0.35,
    };
  }

  double _widthFactorForTier(_ColorTier tier) {
    return switch (tier) {
      _ColorTier.primary => 1.0,
      _ColorTier.secondary => 0.75,
      _ColorTier.tertiary => 0.5,
    };
  }

  double _edgeWidth(double radius) {
    return (radius * 0.04).clamp(0.5, 3.0);
  }

  // ---------------------------------------------------------------------------
  // Drawing: vertex dots with pulse
  // ---------------------------------------------------------------------------

  void _drawAnimatedVertexDots(
    Canvas canvas,
    List<Offset> outerVertices,
    List<List<Offset>> innerRingVertices,
    Offset center,
    double radius,
    double effectiveOpacity,
    List<_AnimEdge> allEdges,
    double revealEdgeCount,
  ) {
    final baseDotRadius = _dotRadius(radius);

    // Outer vertex dots.
    for (int i = 0; i < outerVertices.length; i++) {
      if (!_isVertexRevealed(_EdgeLayer.outer, i, allEdges, revealEdgeCount)) {
        continue;
      }

      final pulseFactor = _vertexPulseFactor(i, outerVertices.length);
      final dotR = baseDotRadius * (1.0 + _pulseScaleAmplitude * pulseFactor);
      final brightnessBoost = _pulseBrightnessAmplitude * pulseFactor;
      final alpha = (0.9 + brightnessBoost).clamp(0.0, 1.0) * effectiveOpacity;

      canvas.drawCircle(
        outerVertices[i],
        dotR,
        Paint()..color = sigil.primaryColor.withValues(alpha: alpha),
      );
    }

    // Inner ring vertex dots.
    for (int ring = 0; ring < innerRingVertices.length; ring++) {
      final ringVerts = innerRingVertices[ring];
      for (int i = 0; i < ringVerts.length; i++) {
        // Inner ring vertices are revealed by connection edges.
        if (!_isVertexRevealed(
          _EdgeLayer.connection,
          i,
          allEdges,
          revealEdgeCount,
        )) {
          // Also check inner layer edges.
          if (!_isVertexRevealed(
            _EdgeLayer.inner,
            i,
            allEdges,
            revealEdgeCount,
          )) {
            continue;
          }
        }

        // Stagger pulse across rings — offset by ring index.
        final globalIndex = (ring + 1) * sigil.vertices + i;
        final pulseFactor = _vertexPulseFactor(
          globalIndex,
          outerVertices.length + innerRingVertices.length * sigil.vertices,
        );
        final dotR =
            baseDotRadius * 0.8 * (1.0 + _pulseScaleAmplitude * pulseFactor);
        final brightnessBoost = _pulseBrightnessAmplitude * pulseFactor;
        final alpha =
            (0.7 + brightnessBoost).clamp(0.0, 1.0) * effectiveOpacity;

        canvas.drawCircle(
          ringVerts[i],
          dotR,
          Paint()..color = sigil.secondaryColor.withValues(alpha: alpha),
        );
      }
    }

    // Center dot — appears last in reveal sequence.
    if (sigil.centerDot) {
      final centerRevealThreshold = 0.85;
      final centerVisible = revealProgress >= centerRevealThreshold;

      if (centerVisible) {
        final centerFadeIn =
            ((revealProgress - centerRevealThreshold) /
                    (1.0 - centerRevealThreshold))
                .clamp(0.0, 1.0);

        final pulseFactor = _centerPulseFactor();
        final dotR =
            baseDotRadius *
            1.3 *
            (1.0 + _pulseScaleAmplitude * 0.6 * pulseFactor);
        final alpha =
            (0.8 * centerFadeIn + _pulseBrightnessAmplitude * pulseFactor)
                .clamp(0.0, 1.0) *
            effectiveOpacity;

        // Outer glow ring on center dot.
        if (showGlow && glowIntensity > 0.3) {
          canvas.drawCircle(
            center,
            dotR * 2.0,
            Paint()
              ..color = sigil.tertiaryColor.withValues(
                alpha: 0.08 * glowIntensity * centerFadeIn * effectiveOpacity,
              )
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotR * 1.5),
          );
        }

        // Main center dot.
        canvas.drawCircle(
          center,
          dotR,
          Paint()..color = sigil.tertiaryColor.withValues(alpha: alpha),
        );

        // Inner highlight.
        canvas.drawCircle(
          center,
          dotR * 0.45,
          Paint()
            ..color = sigil.primaryColor.withValues(
              alpha: 0.3 * centerFadeIn * effectiveOpacity,
            ),
        );
      }
    }
  }

  double _dotRadius(double radius) {
    return (radius * 0.06).clamp(1.5, 5.0);
  }

  /// Compute a per-vertex pulse factor in [-1, 1] based on pulse phase
  /// and staggered vertex index.
  double _vertexPulseFactor(int index, int totalVertices) {
    if (totalVertices <= 0) return 0.0;
    final stagger = index / totalVertices;
    return math.sin((pulsePhase + stagger) * math.pi * 2.0);
  }

  /// Compute center dot pulse — uses a slightly different frequency.
  double _centerPulseFactor() {
    return math.sin(pulsePhase * math.pi * 2.0 * 1.3 + 0.5);
  }

  // ---------------------------------------------------------------------------
  // Drawing: edge tracer
  // ---------------------------------------------------------------------------

  void _drawTracer(
    Canvas canvas,
    List<_AnimEdge> allEdges,
    double radius,
    double effectiveOpacity,
  ) {
    final totalEdges = allEdges.length;
    if (totalEdges == 0) return;

    // Compute total path length for uniform-speed traversal.
    final edgeLengths = <double>[];
    double totalLength = 0.0;
    for (final edge in allEdges) {
      final len = (edge.to - edge.from).distance;
      edgeLengths.add(len);
      totalLength += len;
    }

    if (totalLength <= 0.0) return;

    // Find the tracer position along the total path.
    final traceDist = tracePosition * totalLength;

    // Also compute trail start position.
    final trailDist = (tracePosition - _traceTrailLength) * totalLength;

    // Draw tracer trail as a gradient line.
    _drawTracerSegment(
      canvas,
      allEdges,
      edgeLengths,
      totalLength,
      trailDist,
      traceDist,
      radius,
      effectiveOpacity,
    );

    // Draw the bright tracer head dot.
    final headPos = _positionOnPath(allEdges, edgeLengths, traceDist);
    if (headPos != null) {
      final headRadius = _edgeWidth(radius) * 2.5;

      // Outer glow.
      canvas.drawCircle(
        headPos,
        headRadius * 3.0,
        Paint()
          ..color = sigil.primaryColor.withValues(
            alpha: 0.15 * effectiveOpacity,
          )
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, headRadius * 2.0),
      );

      // Bright core.
      canvas.drawCircle(
        headPos,
        headRadius,
        Paint()
          ..color = sigil.primaryColor.withValues(
            alpha: 0.9 * effectiveOpacity,
          ),
      );

      // White-hot center.
      canvas.drawCircle(
        headPos,
        headRadius * 0.4,
        Paint()..color = Colors.white.withValues(alpha: 0.7 * effectiveOpacity),
      );
    }
  }

  void _drawTracerSegment(
    Canvas canvas,
    List<_AnimEdge> allEdges,
    List<double> edgeLengths,
    double totalLength,
    double startDist,
    double endDist,
    double radius,
    double effectiveOpacity,
  ) {
    // Walk the edge list and draw the trail portion with fading alpha.
    double cumulative = 0.0;
    final trailLength = endDist - startDist;
    if (trailLength <= 0.0) return;

    for (int i = 0; i < allEdges.length; i++) {
      final edgeStart = cumulative;
      final edgeEnd = cumulative + edgeLengths[i];
      cumulative = edgeEnd;

      // Skip edges entirely before or after the trail range.
      if (edgeEnd < startDist || edgeStart > endDist) continue;

      final edge = allEdges[i];
      final edgeLen = edgeLengths[i];
      if (edgeLen <= 0.0) continue;

      // Compute the visible portion of this edge within the trail.
      final segStart = ((startDist - edgeStart) / edgeLen).clamp(0.0, 1.0);
      final segEnd = ((endDist - edgeStart) / edgeLen).clamp(0.0, 1.0);

      if (segEnd <= segStart) continue;

      final p1 = Offset(
        edge.from.dx + (edge.to.dx - edge.from.dx) * segStart,
        edge.from.dy + (edge.to.dy - edge.from.dy) * segStart,
      );
      final p2 = Offset(
        edge.from.dx + (edge.to.dx - edge.from.dx) * segEnd,
        edge.from.dy + (edge.to.dy - edge.from.dy) * segEnd,
      );

      // Alpha fades from 0 at trail start to full at trail end.
      final midDist = edgeStart + edgeLen * (segStart + segEnd) / 2.0;
      final trailFraction = ((midDist - startDist) / trailLength).clamp(
        0.0,
        1.0,
      );
      final trailAlpha = trailFraction * 0.6;

      final trailPaint = Paint()
        ..color = sigil.primaryColor.withValues(
          alpha: trailAlpha * effectiveOpacity,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = _edgeWidth(radius) * 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1, p2, trailPaint);
    }
  }

  /// Find the (x, y) position at a given distance along the edge path.
  Offset? _positionOnPath(
    List<_AnimEdge> edges,
    List<double> edgeLengths,
    double distance,
  ) {
    // Handle wrapping for looped traversal.
    double totalLength = 0.0;
    for (final len in edgeLengths) {
      totalLength += len;
    }
    if (totalLength <= 0.0) return null;

    double wrappedDist = distance % totalLength;
    if (wrappedDist < 0) wrappedDist += totalLength;

    double cumulative = 0.0;
    for (int i = 0; i < edges.length; i++) {
      final edgeEnd = cumulative + edgeLengths[i];
      if (wrappedDist <= edgeEnd || i == edges.length - 1) {
        final edgeLen = edgeLengths[i];
        if (edgeLen <= 0.0) return edges[i].from;
        final t = ((wrappedDist - cumulative) / edgeLen).clamp(0.0, 1.0);
        return Offset(
          edges[i].from.dx + (edges[i].to.dx - edges[i].from.dx) * t,
          edges[i].from.dy + (edges[i].to.dy - edges[i].from.dy) * t,
        );
      }
      cumulative = edgeEnd;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Repaint
  // ---------------------------------------------------------------------------

  @override
  bool shouldRepaint(AnimatedSigilPainter oldDelegate) {
    return oldDelegate.sigil != sigil ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.rotationDelta != rotationDelta ||
        oldDelegate.pulsePhase != pulsePhase ||
        oldDelegate.glowIntensity != glowIntensity ||
        oldDelegate.tracePosition != tracePosition ||
        oldDelegate.opacity != opacity ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.showBorder != showBorder;
  }
}

// =============================================================================
// Internal data types
// =============================================================================

/// Which layer an edge belongs to (for reveal ordering and color selection).
enum _EdgeLayer {
  /// Outer polygon sides.
  outer,

  /// Connections between rings.
  connection,

  /// Inner polygon sides.
  inner,

  /// Radial lines (center-to-vertex or cross-connections).
  radial,
}

/// Color tier for edge rendering.
enum _ColorTier { primary, secondary, tertiary }

/// A single edge in the ordered draw list.
class _AnimEdge {
  /// Start point.
  final Offset from;

  /// End point.
  final Offset to;

  /// Which structural layer this edge belongs to.
  final _EdgeLayer layer;

  /// Which color tier to use.
  final _ColorTier colorTier;

  /// Index of the source vertex within its layer (-1 for center).
  final int fromIndex;

  /// Index of the destination vertex within its layer.
  final int toIndex;

  const _AnimEdge({
    required this.from,
    required this.to,
    required this.layer,
    required this.colorTier,
    required this.fromIndex,
    required this.toIndex,
  });
}
