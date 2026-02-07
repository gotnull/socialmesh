// SPDX-License-Identifier: GPL-3.0-or-later

// Constellation CustomPainter — star-map rendering engine.
//
// Philosophy: "Show stars, not wires."
//
// The constellation is a STAR MAP, not a network diagram. By default,
// nodes appear as calm luminous dots scattered across dark space with
// ZERO edges visible. Edges appear only on demand:
//   - Tap a node → top-6 connections appear as elegant arcs
//   - Cycle density → progressively reveal more edges
//   - Zoom in → local edges fade in
//
// Rendering layers (back to front):
//   1. Background ambient glow (selected node spotlight)
//   2. Default edges (if density > none)
//   3. Selected node connection arcs (highlighted)
//   4. Dim edges to non-top neighbors of selected node
//   5. Node glows (soft halos)
//   6. Node fills (solid cores)
//   7. Center highlight dots (at high LOD)
//   8. Selection ring
//   9. Labels (collision-detected, hard-capped)
//  10. Clusters (when zoomed out)
//  11. Search pulse
//
// Performance:
//   - Viewport culling via quadtree (only draws visible nodes)
//   - LOD: minimal/standard/full based on zoom
//   - Cached Paint objects (zero per-frame allocation)
//   - Straight lines at low LOD, curves at high LOD
//   - Edge skip when density is "none" (draws zero edges)

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';
import 'cluster_engine.dart';
import 'quadtree.dart';

// =============================================================================
// Rendering constants — calibrated for calm star-map aesthetic
// =============================================================================

class _K {
  // -- Node sizing ----------------------------------------------------------
  // Nodes are tiny luminous dots. Even the most connected node is small.
  // Base 2.0dp + up to 2.5dp bonus = max 4.5dp radius.
  static const double nodeBaseRadius = 2.0;
  static const double nodeMaxBonusRadius = 2.5;
  static const double nodeMaxBonusConnections = 20.0;

  // -- Glow -----------------------------------------------------------------
  // Soft halo around each node. Very subtle by default — produces a faint
  // nebula effect when many nodes overlap, rather than neon blobs.
  static const double glowRadiusMultiplier = 2.0;
  static const double glowBlurSigma = 3.0;
  static const double glowAlphaDefault = 0.04;
  static const double glowAlphaSelected = 0.20;
  static const double glowAlphaNeighbor = 0.10;

  // -- Selection ring -------------------------------------------------------
  static const double selectionRingOffset = 5.0;
  static const double selectionRingStroke = 1.0;
  static const double selectionRingFillAlpha = 0.06;
  static const double selectionRingStrokeAlpha = 0.40;
  static const double spotlightRadius = 60.0;
  static const double spotlightAlpha = 0.03;
  static const double spotlightBlurSigma = 30.0;

  // -- Node fill ------------------------------------------------------------
  // Default alpha 0.45 keeps unselected nodes visible as dim stars.
  // Dimmed nodes (when another is selected) shrink and fade.
  static const double fillAlphaDefault = 0.45;
  static const double fillAlphaSelected = 0.95;
  static const double fillAlphaNeighbor = 0.70;
  static const double fillAlphaDimmed = 0.08;
  static const double dimmedRadiusScale = 0.5;

  // -- Center highlight dot -------------------------------------------------
  static const double centerDotScale = 0.3;
  static const double centerDotAlphaDefault = 0.12;
  static const double centerDotAlphaSelected = 0.50;
  static const double centerDotAlphaNeighbor = 0.25;

  // -- Edges ----------------------------------------------------------------
  // Default edges are gossamer-thin and nearly invisible.
  // Only become apparent on selection or high density settings.
  static const double edgeDefaultAlphaDark = 0.015;
  static const double edgeDefaultAlphaLight = 0.012;
  static const double edgeWeightAlphaMultDark = 0.025;
  static const double edgeWeightAlphaMultLight = 0.020;
  static const double edgeDefaultStrokeMin = 0.15;
  static const double edgeDefaultStrokeWeightMult = 0.3;

  // Selected edges (top-N connections from the selected node)
  static const double edgeSelectedAlphaBase = 0.25;
  static const double edgeSelectedAlphaWeightMult = 0.45;
  static const double edgeSelectedStrokeMin = 0.6;
  static const double edgeSelectedStrokeWeightMult = 1.8;

  // Dim edges (selected node's non-top connections)
  static const double edgeDimAlphaBase = 0.02;
  static const double edgeDimAlphaWeightMult = 0.015;
  static const double edgeDimStrokeMin = 0.1;
  static const double edgeDimStrokeWeightMult = 0.15;

  // Curve control
  static const double edgeCurveControlOffset = 0.05;
  static const double edgeCurveMinDistance = 20.0;

  // -- Labels ---------------------------------------------------------------
  static const double labelFontSize = 8.5;
  static const double labelMaxWidth = 100.0;
  static const int labelMaxChars = 12;
  static const double labelOffsetY = 6.0;
  static const double labelPillPadH = 6.0;
  static const double labelPillPadV = 2.5;
  static const double labelPillRadius = 4.0;
  static const double labelBgAlpha = 0.70;
  static const double labelAlphaSelected = 0.90;
  static const double labelAlphaNeighbor = 0.60;
  static const double labelAlphaZoomed = 0.45;
  static const int maxVisibleLabels = 8;
  static const double labelCollisionPadding = 4.0;

  // -- Clusters -------------------------------------------------------------
  static const double clusterBaseRadius = 7.0;
  static const double clusterGlowSigma = 10.0;
  static const double clusterGlowAlpha = 0.08;
  static const double clusterFillAlpha = 0.22;
  static const double clusterRingAlpha = 0.16;
  static const double clusterRingStroke = 0.7;
  static const double clusterBadgeFontSize = 8.0;
  static const double clusterBadgePadH = 5.0;
  static const double clusterBadgePadV = 2.0;
  static const double clusterBadgeRadius = 5.0;
  static const double clusterBadgeOffsetY = 4.0;
  static const double clusterBadgeBgAlpha = 0.75;

  // -- LOD thresholds (zoom levels) -----------------------------------------
  static const double lodMinimalThreshold = 0.50;
  static const double lodFullDetailThreshold = 1.6;
  static const double labelZoomThreshold = 2.8;

  // -- Edge visibility by zoom ----------------------------------------------
  // Even when density allows edges, they fade in based on zoom level.
  // At overview zoom, you see stars only. Edges appear as you zoom in.
  static const double edgeZoomFadeStart = 0.6;
  static const double edgeZoomFadeEnd = 1.2;

  // -- Viewport culling margin ----------------------------------------------
  static const double cullingMargin = 50.0;

  _K._();
}

// =============================================================================
// Level of detail
// =============================================================================

enum _LOD {
  /// Zoom < 0.50: single pixel dots, no glow, no labels, no edges.
  minimal,

  /// Zoom 0.50–1.6: standard circles with subtle glow and faint edges.
  standard,

  /// Zoom > 1.6: full detail — glow, center dot, labels, curved edges.
  full,
}

_LOD _lodForZoom(double zoom) {
  if (zoom < _K.lodMinimalThreshold) return _LOD.minimal;
  if (zoom > _K.lodFullDetailThreshold) return _LOD.full;
  return _LOD.standard;
}

// =============================================================================
// Edge visibility mode — controls which edges are drawn
// =============================================================================

/// Controls how aggressively edges are drawn.
///
/// This replaces the old boolean approach. The painter receives this
/// as the [showEdges] flag combined with [weightThreshold].
enum EdgeVisibility {
  /// Zero edges drawn in the background. Only selection edges appear.
  none,

  /// Top ~20% of edges drawn very faintly in the background.
  sparse,

  /// Top ~40% of edges drawn.
  normal,

  /// Top ~70% of edges drawn.
  dense,

  /// All edges drawn.
  all,
}

// =============================================================================
// Constellation Painter
// =============================================================================

/// The core rendering engine for the constellation graph.
///
/// This painter implements a "stars first, connections on demand" philosophy.
/// By default, the canvas shows luminous dots on dark space — like a real
/// night sky. Connections are revealed progressively through:
/// - Node selection (shows top-6 connections as elegant arcs)
/// - Edge density control (cycles none → sparse → normal → dense → all)
/// - Zooming in (edges fade in at higher zoom levels)
///
/// All interaction state is passed in from the parent widget.
/// The painter does NOT own any state.
class ConstellationPainter extends CustomPainter {
  /// The graph data (nodes + edges + layout positions).
  final ConstellationData data;

  /// Whether the current theme is dark mode.
  final bool isDark;

  /// Currently selected node (null = nothing selected).
  final int? selectedNodeNum;

  /// Set of node numbers that are "top" neighbors of the selected node.
  /// Capped upstream to prevent lighting up the entire graph.
  final Set<int> neighbors;

  /// The accent color from the app theme.
  final Color accentColor;

  /// Edge weight threshold — edges below this weight are hidden.
  final int weightThreshold;

  /// Whether to draw background edges at all (independent of selection edges).
  final bool showBackgroundEdges;

  /// Current zoom level (from the transformation matrix).
  final double zoomLevel;

  /// Visible viewport in canvas coordinates (for culling).
  final Rect viewportRect;

  /// Cluster result (may be disabled if zoom is high enough).
  final ClusterResult clusterResult;

  /// Nodes that should show labels (selected, top neighbors, search results).
  final Set<int> labelNodes;

  /// The search-highlighted node (gets a pulse ring).
  final int? searchHighlightNode;

  /// Animation value for the search pulse (0.0 to 1.0, looping).
  final double searchPulsePhase;

  // -- Cached paint objects (avoid per-frame allocation) --------------------

  late final Paint _glowPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _dotPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _ringFillPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _ringStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _K.selectionRingStroke;
  late final Paint _edgePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  late final Paint _clusterGlowPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _clusterFillPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _clusterRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _K.clusterRingStroke;
  late final Paint _spotlightPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _labelBgPaint = Paint()..style = PaintingStyle.fill;
  late final Paint _searchPulsePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  ConstellationPainter({
    required this.data,
    required this.isDark,
    this.selectedNodeNum,
    required this.neighbors,
    required this.accentColor,
    required this.weightThreshold,
    this.showBackgroundEdges = false,
    required this.zoomLevel,
    required this.viewportRect,
    required this.clusterResult,
    required this.labelNodes,
    this.searchHighlightNode,
    this.searchPulsePhase = 0.0,
  });

  // -- Pre-computed position lookup -----------------------------------------

  Map<int, Offset>? _positions;

  Map<int, Offset> _getPositions(Size size) {
    if (_positions != null) return _positions!;
    final map = <int, Offset>{};
    for (final node in data.nodes) {
      map[node.nodeNum] = Offset(node.x * size.width, node.y * size.height);
    }
    _positions = map;
    return map;
  }

  Quadtree<ConstellationNode>? _quadtree;

  Quadtree<ConstellationNode> _getQuadtree(Size size) {
    if (_quadtree != null) return _quadtree!;
    final items = <QuadtreeItem<ConstellationNode>>[];
    for (final node in data.nodes) {
      final r = _nodeRadius(node);
      items.add(
        QuadtreeItem(
          position: Offset(node.x * size.width, node.y * size.height),
          radius: r,
          data: node,
        ),
      );
    }
    _quadtree = Quadtree.fromItems(items);
    return _quadtree!;
  }

  // =========================================================================
  // Main paint method
  // =========================================================================

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final positions = _getPositions(size);
    final lod = _lodForZoom(zoomLevel);
    final hasFocus = selectedNodeNum != null;

    // Build the culling rect from viewport with margin.
    final cullRect = QRect.fromRect(viewportRect).expand(_K.cullingMargin);

    // Determine visible nodes via quadtree query.
    final quadtree = _getQuadtree(size);
    final visibleItems = quadtree.queryRect(cullRect);
    final visibleNodeNums = <int>{};
    for (final item in visibleItems) {
      visibleNodeNums.add(item.data.nodeNum);
    }

    // If clustering is active, render clusters instead of individual nodes.
    if (clusterResult.isActive) {
      _paintClusters(canvas, size, cullRect);
      return;
    }

    // Compute zoom-based edge opacity factor.
    // Even when edges are "enabled", they fade in with zoom.
    final edgeZoomFactor =
        ((zoomLevel - _K.edgeZoomFadeStart) /
                (_K.edgeZoomFadeEnd - _K.edgeZoomFadeStart))
            .clamp(0.0, 1.0);

    // 1) Background spotlight for selected node.
    if (hasFocus) {
      _paintSpotlight(canvas, positions);
    }

    // 2) Background edges (only if density > none AND zoom is high enough).
    if (showBackgroundEdges && lod != _LOD.minimal && edgeZoomFactor > 0.01) {
      _paintBackgroundEdges(
        canvas,
        positions,
        visibleNodeNums,
        hasFocus,
        lod,
        edgeZoomFactor,
      );
    }

    // 3) Selection edges — always drawn when a node is selected,
    //    regardless of density setting.
    if (hasFocus) {
      _paintSelectionEdges(canvas, positions, visibleNodeNums, lod);
    }

    // 4) Node glows — soft halos behind the solid cores.
    if (lod != _LOD.minimal) {
      _paintNodeGlows(canvas, visibleItems, hasFocus);
    }

    // 5) Node fills — solid cores.
    _paintNodeFills(canvas, visibleItems, hasFocus, lod);

    // 6) Selection ring (on top of the node fill).
    if (hasFocus) {
      _paintSelectionRing(canvas, positions);
    }

    // 7) Labels — collision-detected, hard-capped.
    if (lod != _LOD.minimal) {
      _paintLabels(canvas, positions, visibleItems, hasFocus, lod);
    }

    // 8) Search pulse highlight.
    if (searchHighlightNode != null) {
      _paintSearchPulse(canvas, positions);
    }
  }

  // =========================================================================
  // Spotlight — soft ambient glow behind the selected node
  // =========================================================================

  void _paintSpotlight(Canvas canvas, Map<int, Offset> positions) {
    final pos = positions[selectedNodeNum];
    if (pos == null) return;

    _spotlightPaint
      ..color = accentColor.withValues(alpha: _K.spotlightAlpha)
      ..maskFilter = const MaskFilter.blur(
        BlurStyle.normal,
        _K.spotlightBlurSigma,
      );
    canvas.drawCircle(pos, _K.spotlightRadius, _spotlightPaint);
    _spotlightPaint.maskFilter = null;
  }

  // =========================================================================
  // Background edges — faint structural lines (density-controlled)
  // =========================================================================

  void _paintBackgroundEdges(
    Canvas canvas,
    Map<int, Offset> positions,
    Set<int> visibleNodeNums,
    bool hasFocus,
    _LOD lod,
    double zoomFadeFactor,
  ) {
    for (final edge in data.edges) {
      // Weight threshold filtering.
      if (edge.weight < weightThreshold) continue;

      // Culling: skip if neither endpoint is visible.
      if (!visibleNodeNums.contains(edge.from) &&
          !visibleNodeNums.contains(edge.to)) {
        continue;
      }

      // In focus mode, don't draw background edges at all — only selection
      // edges are shown. This keeps the focus clean.
      if (hasFocus) continue;

      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;

      final nw = data.maxWeight > 1
          ? edge.weight / data.maxWeight.toDouble()
          : 0.5;

      _paintDefaultEdge(canvas, from, to, nw, lod, zoomFadeFactor);
    }
  }

  void _paintDefaultEdge(
    Canvas canvas,
    Offset from,
    Offset to,
    double nw,
    _LOD lod,
    double zoomFadeFactor,
  ) {
    final baseAlpha = isDark
        ? _K.edgeDefaultAlphaDark
        : _K.edgeDefaultAlphaLight;
    final weightAlpha = isDark
        ? _K.edgeWeightAlphaMultDark
        : _K.edgeWeightAlphaMultLight;
    final alpha = (baseAlpha + nw * weightAlpha) * zoomFadeFactor;
    final stroke =
        _K.edgeDefaultStrokeMin + nw * _K.edgeDefaultStrokeWeightMult;

    if (alpha < 0.003) return; // Skip invisible edges.

    final edgeColor = isDark ? Colors.white : Colors.black;

    _edgePaint
      ..color = edgeColor.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..strokeWidth = stroke;

    // At standard LOD or below, use straight lines for performance.
    if (lod != _LOD.full) {
      canvas.drawLine(from, to, _edgePaint);
    } else {
      final path = _curvedEdgePath(from, to);
      canvas.drawPath(path, _edgePaint);
    }
  }

  // =========================================================================
  // Selection edges — elegant arcs from selected node to top neighbors
  // =========================================================================

  void _paintSelectionEdges(
    Canvas canvas,
    Map<int, Offset> positions,
    Set<int> visibleNodeNums,
    _LOD lod,
  ) {
    final selectedPos = positions[selectedNodeNum];
    if (selectedPos == null) return;

    for (final edge in data.edges) {
      final touchesSelected =
          edge.from == selectedNodeNum || edge.to == selectedNodeNum;
      if (!touchesSelected) continue;

      // Culling: skip if the OTHER endpoint is not visible.
      final otherEnd = edge.from == selectedNodeNum ? edge.to : edge.from;
      if (!visibleNodeNums.contains(otherEnd) &&
          !visibleNodeNums.contains(selectedNodeNum!)) {
        continue;
      }

      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;

      final nw = data.maxWeight > 1
          ? edge.weight / data.maxWeight.toDouble()
          : 0.5;

      final isTopNeighbor = neighbors.contains(otherEnd);

      if (isTopNeighbor) {
        _paintHighlightedEdge(canvas, from, to, edge, nw, lod);
      } else {
        _paintDimEdge(canvas, from, to, nw);
      }
    }
  }

  /// Paint a prominent edge from the selected node to a top neighbor.
  /// Uses the blended sigil colors of both endpoints for a beautiful arc.
  void _paintHighlightedEdge(
    Canvas canvas,
    Offset from,
    Offset to,
    ConstellationEdge edge,
    double nw,
    _LOD lod,
  ) {
    final color = _blendedEdgeColor(edge);
    final alpha =
        _K.edgeSelectedAlphaBase + nw * _K.edgeSelectedAlphaWeightMult;
    final stroke =
        _K.edgeSelectedStrokeMin + nw * _K.edgeSelectedStrokeWeightMult;

    _edgePaint
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..strokeWidth = stroke;

    // Always use curves for highlighted edges — they look much better.
    final path = _curvedEdgePath(from, to);
    canvas.drawPath(path, _edgePaint);
  }

  /// Paint an edge connected to the selected node but NOT to a top neighbor.
  /// Barely visible — just a whisper of structure.
  void _paintDimEdge(Canvas canvas, Offset from, Offset to, double nw) {
    final alpha = _K.edgeDimAlphaBase + nw * _K.edgeDimAlphaWeightMult;
    final stroke = _K.edgeDimStrokeMin + nw * _K.edgeDimStrokeWeightMult;

    if (alpha < 0.003) return;

    final edgeColor = isDark ? Colors.white : Colors.black;

    _edgePaint
      ..color = edgeColor.withValues(alpha: alpha.clamp(0.0, 1.0))
      ..strokeWidth = stroke;

    canvas.drawLine(from, to, _edgePaint);
  }

  /// Create a subtle curved path between two points.
  Path _curvedEdgePath(Offset from, Offset to) {
    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Only curve if distance is significant.
    if (dist < _K.edgeCurveMinDistance) {
      return Path()
        ..moveTo(from.dx, from.dy)
        ..lineTo(to.dx, to.dy);
    }

    // Perpendicular offset for the control point.
    final perpX = -dy * _K.edgeCurveControlOffset;
    final perpY = dx * _K.edgeCurveControlOffset;

    final midX = (from.dx + to.dx) * 0.5 + perpX;
    final midY = (from.dy + to.dy) * 0.5 + perpY;

    return Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(midX, midY, to.dx, to.dy);
  }

  // =========================================================================
  // Node glows — soft halos behind the solid cores
  // =========================================================================

  void _paintNodeGlows(
    Canvas canvas,
    List<QuadtreeItem<ConstellationNode>> visibleItems,
    bool hasFocus,
  ) {
    for (final item in visibleItems) {
      final node = item.data;
      final pos = item.position;

      final isSelected = node.nodeNum == selectedNodeNum;
      final isNeighbor = neighbors.contains(node.nodeNum);
      final isDimmed = hasFocus && !isSelected && !isNeighbor;

      // No glow for dimmed nodes — they become invisible background dots.
      if (isDimmed) continue;

      final sigil = node.sigil ?? SigilGenerator.generate(node.nodeNum);
      final color = sigil.primaryColor;
      final r = _nodeRadius(node);

      final glowAlpha = isSelected
          ? _K.glowAlphaSelected
          : (isNeighbor ? _K.glowAlphaNeighbor : _K.glowAlphaDefault);

      _glowPaint
        ..color = color.withValues(alpha: glowAlpha)
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          _K.glowBlurSigma,
        );
      canvas.drawCircle(pos, r * _K.glowRadiusMultiplier, _glowPaint);
    }
    // Reset mask filter after the glow pass.
    _glowPaint.maskFilter = null;
  }

  // =========================================================================
  // Node fills — solid cores
  // =========================================================================

  void _paintNodeFills(
    Canvas canvas,
    List<QuadtreeItem<ConstellationNode>> visibleItems,
    bool hasFocus,
    _LOD lod,
  ) {
    for (final item in visibleItems) {
      final node = item.data;
      final pos = item.position;

      final isSelected = node.nodeNum == selectedNodeNum;
      final isNeighbor = neighbors.contains(node.nodeNum);
      final isDimmed = hasFocus && !isSelected && !isNeighbor;

      final sigil = node.sigil ?? SigilGenerator.generate(node.nodeNum);
      final color = sigil.primaryColor;
      final r = _nodeRadius(node);

      if (lod == _LOD.minimal) {
        // Minimal LOD: single pixel-ish dot, no glow, no extras.
        final alpha = isDimmed ? _K.fillAlphaDimmed : _K.fillAlphaDefault;
        final dotR = isDimmed ? r * _K.dimmedRadiusScale : r * 0.5;
        _fillPaint.color = color.withValues(alpha: alpha);
        canvas.drawCircle(pos, dotR, _fillPaint);
        continue;
      }

      // -- Fill --
      final fillAlpha = isDimmed
          ? _K.fillAlphaDimmed
          : (isSelected
                ? _K.fillAlphaSelected
                : (isNeighbor ? _K.fillAlphaNeighbor : _K.fillAlphaDefault));
      final fillR = isDimmed ? r * _K.dimmedRadiusScale : r;

      _fillPaint.color = color.withValues(alpha: fillAlpha);
      canvas.drawCircle(pos, fillR, _fillPaint);

      // -- Center highlight dot (standard+ LOD, not dimmed) --
      if (!isDimmed) {
        final dotAlpha = isSelected
            ? _K.centerDotAlphaSelected
            : (isNeighbor
                  ? _K.centerDotAlphaNeighbor
                  : _K.centerDotAlphaDefault);
        _dotPaint.color = Colors.white.withValues(alpha: dotAlpha);
        canvas.drawCircle(pos, r * _K.centerDotScale, _dotPaint);
      }
    }
  }

  // =========================================================================
  // Selection ring — steady accent ring around the selected node
  // =========================================================================

  void _paintSelectionRing(Canvas canvas, Map<int, Offset> positions) {
    final pos = positions[selectedNodeNum];
    if (pos == null) return;

    // Find the selected node to get its radius.
    ConstellationNode? selectedNode;
    for (final node in data.nodes) {
      if (node.nodeNum == selectedNodeNum) {
        selectedNode = node;
        break;
      }
    }
    if (selectedNode == null) return;

    final r = _nodeRadius(selectedNode);
    final ringR = r + _K.selectionRingOffset;

    _ringFillPaint.color = accentColor.withValues(
      alpha: _K.selectionRingFillAlpha,
    );
    canvas.drawCircle(pos, ringR, _ringFillPaint);

    _ringStrokePaint.color = accentColor.withValues(
      alpha: _K.selectionRingStrokeAlpha,
    );
    canvas.drawCircle(pos, ringR, _ringStrokePaint);
  }

  // =========================================================================
  // Labels — collision-detected, hard-capped at 8
  // =========================================================================

  void _paintLabels(
    Canvas canvas,
    Map<int, Offset> positions,
    List<QuadtreeItem<ConstellationNode>> visibleItems,
    bool hasFocus,
    _LOD lod,
  ) {
    final candidates = <(ConstellationNode, Offset, double)>[];

    for (final item in visibleItems) {
      final node = item.data;
      final pos = item.position;
      final isDimmed =
          hasFocus &&
          node.nodeNum != selectedNodeNum &&
          !neighbors.contains(node.nodeNum);

      if (isDimmed) continue;

      // Determine label alpha and priority.
      if (node.nodeNum == selectedNodeNum) {
        candidates.add((node, pos, _K.labelAlphaSelected));
      } else if (neighbors.contains(node.nodeNum) &&
          labelNodes.contains(node.nodeNum)) {
        candidates.add((node, pos, _K.labelAlphaNeighbor));
      } else if (labelNodes.contains(node.nodeNum)) {
        candidates.add((node, pos, _K.labelAlphaZoomed));
      } else if (zoomLevel >= _K.labelZoomThreshold && lod == _LOD.full) {
        candidates.add((node, pos, _K.labelAlphaZoomed));
      }
    }

    // Sort by alpha descending (most important first for collision priority).
    candidates.sort((a, b) => b.$3.compareTo(a.$3));

    final maxLabels = math.min(candidates.length, _K.maxVisibleLabels);
    final occupiedRects = <Rect>[];

    for (int i = 0; i < maxLabels; i++) {
      final (node, pos, alpha) = candidates[i];
      final r = _nodeRadius(node);

      final displayName = node.displayName.length > _K.labelMaxChars
          ? '${node.displayName.substring(0, _K.labelMaxChars)}\u2026'
          : node.displayName;

      final textColor = (isDark ? Colors.white : Colors.black).withValues(
        alpha: alpha,
      );

      final style = ui.TextStyle(
        color: textColor,
        fontSize: _K.labelFontSize,
        fontWeight: FontWeight.w500,
      );

      final builder =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: TextAlign.center,
                maxLines: 1,
                ellipsis: '\u2026',
              ),
            )
            ..pushStyle(style)
            ..addText(displayName);

      final paragraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: _K.labelMaxWidth));

      final labelX = pos.dx - paragraph.width * 0.5;
      final labelY = pos.dy + r + _K.labelOffsetY;

      final labelRect = Rect.fromLTWH(
        labelX - _K.labelPillPadH,
        labelY - _K.labelPillPadV,
        paragraph.width + _K.labelPillPadH * 2,
        paragraph.height + _K.labelPillPadV * 2,
      );

      // Collision detection.
      bool collides = false;
      for (final occupied in occupiedRects) {
        if (labelRect.inflate(_K.labelCollisionPadding).overlaps(occupied)) {
          collides = true;
          break;
        }
      }

      // Skip if colliding — but always show the selected node's label.
      if (collides && node.nodeNum != selectedNodeNum) continue;

      occupiedRects.add(labelRect);

      // Draw background pill.
      final bgColor = isDark ? const Color(0xFF0A0E18) : Colors.white;
      _labelBgPaint.color = bgColor.withValues(alpha: _K.labelBgAlpha);

      final pillRect = RRect.fromRectAndRadius(
        labelRect,
        const Radius.circular(_K.labelPillRadius),
      );
      canvas.drawRRect(pillRect, _labelBgPaint);

      // Draw text.
      canvas.drawParagraph(paragraph, Offset(labelX, labelY));
    }
  }

  // =========================================================================
  // Clusters
  // =========================================================================

  void _paintClusters(Canvas canvas, Size size, QRect cullRect) {
    for (final cluster in clusterResult.clusters) {
      final cx = cluster.cx * size.width;
      final cy = cluster.cy * size.height;
      final pos = Offset(cx, cy);

      if (!cullRect.containsPoint(pos)) continue;

      final r = _K.clusterBaseRadius * cluster.radiusScale;
      final color = cluster.dominantColor;

      // Soft glow.
      _clusterGlowPaint
        ..color = color.withValues(alpha: _K.clusterGlowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _K.clusterGlowSigma);
      canvas.drawCircle(pos, r * 1.8, _clusterGlowPaint);
      _clusterGlowPaint.maskFilter = null;

      // Fill circle.
      _clusterFillPaint.color = color.withValues(alpha: _K.clusterFillAlpha);
      canvas.drawCircle(pos, r, _clusterFillPaint);

      // Outer ring.
      _clusterRingPaint.color = color.withValues(alpha: _K.clusterRingAlpha);
      canvas.drawCircle(pos, r, _clusterRingPaint);

      // Count badge (only for multi-node clusters).
      if (!cluster.isSingleton) {
        _paintClusterBadge(canvas, pos, r, cluster);
      }
    }
  }

  void _paintClusterBadge(
    Canvas canvas,
    Offset pos,
    double radius,
    NodeCluster cluster,
  ) {
    final label = cluster.countLabel;

    final style = ui.TextStyle(
      color: Colors.white.withValues(alpha: 0.80),
      fontSize: _K.clusterBadgeFontSize,
      fontWeight: FontWeight.w600,
    );

    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, maxLines: 1),
          )
          ..pushStyle(style)
          ..addText(label);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: _K.labelMaxWidth));

    final badgeX = pos.dx - paragraph.width * 0.5;
    final badgeY = pos.dy + radius + _K.clusterBadgeOffsetY;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        badgeX - _K.clusterBadgePadH,
        badgeY - _K.clusterBadgePadV,
        paragraph.width + _K.clusterBadgePadH * 2,
        paragraph.height + _K.clusterBadgePadV * 2,
      ),
      const Radius.circular(_K.clusterBadgeRadius),
    );

    final bgColor = isDark ? const Color(0xFF0A0E18) : const Color(0xFFF0F2F8);
    _labelBgPaint.color = bgColor.withValues(alpha: _K.clusterBadgeBgAlpha);
    canvas.drawRRect(badgeRect, _labelBgPaint);

    canvas.drawParagraph(paragraph, Offset(badgeX, badgeY));
  }

  // =========================================================================
  // Search pulse
  // =========================================================================

  void _paintSearchPulse(Canvas canvas, Map<int, Offset> positions) {
    final pos = positions[searchHighlightNode];
    if (pos == null) return;

    // Expanding ring that fades out.
    const baseR = 10.0;
    const maxR = 45.0;
    final r = baseR + (maxR - baseR) * searchPulsePhase;
    final alpha = 0.45 * (1.0 - searchPulsePhase);

    _searchPulsePaint.color = accentColor.withValues(alpha: alpha);
    _searchPulsePaint.strokeWidth = 1.5 * (1.0 - searchPulsePhase * 0.5);
    canvas.drawCircle(pos, r, _searchPulsePaint);

    // Second ring, delayed phase.
    final phase2 = (searchPulsePhase + 0.35) % 1.0;
    final r2 = baseR + (maxR - baseR) * phase2;
    final alpha2 = 0.25 * (1.0 - phase2);
    _searchPulsePaint.color = accentColor.withValues(alpha: alpha2);
    _searchPulsePaint.strokeWidth = 0.9 * (1.0 - phase2 * 0.5);
    canvas.drawCircle(pos, r2, _searchPulsePaint);
  }

  // =========================================================================
  // Helpers
  // =========================================================================

  /// Compute the visual radius for a node based on its connection count.
  double _nodeRadius(ConstellationNode node) {
    final bonus =
        math.min(node.connectionCount.toDouble(), _K.nodeMaxBonusConnections) /
        _K.nodeMaxBonusConnections *
        _K.nodeMaxBonusRadius;
    return _K.nodeBaseRadius + bonus;
  }

  /// Blend the colors of two edge endpoints for a colored edge.
  Color _blendedEdgeColor(ConstellationEdge edge) {
    ConstellationNode? fromNode;
    ConstellationNode? toNode;

    for (final node in data.nodes) {
      if (node.nodeNum == edge.from) fromNode = node;
      if (node.nodeNum == edge.to) toNode = node;
      if (fromNode != null && toNode != null) break;
    }

    final fromSigil =
        fromNode?.sigil ??
        (fromNode != null ? SigilGenerator.generate(fromNode.nodeNum) : null);
    final toSigil =
        toNode?.sigil ??
        (toNode != null ? SigilGenerator.generate(toNode.nodeNum) : null);

    if (fromSigil != null && toSigil != null) {
      return Color.lerp(fromSigil.primaryColor, toSigil.primaryColor, 0.5) ??
          accentColor;
    }
    return accentColor;
  }

  // =========================================================================
  // Repaint check
  // =========================================================================

  @override
  bool shouldRepaint(ConstellationPainter old) {
    return old.data != data ||
        old.selectedNodeNum != selectedNodeNum ||
        old.isDark != isDark ||
        old.weightThreshold != weightThreshold ||
        old.showBackgroundEdges != showBackgroundEdges ||
        old.zoomLevel != zoomLevel ||
        old.viewportRect != viewportRect ||
        old.clusterResult != clusterResult ||
        old.searchHighlightNode != searchHighlightNode ||
        old.searchPulsePhase != searchPulsePhase ||
        !_setsEqual(old.labelNodes, labelNodes) ||
        !_setsEqual(old.neighbors, neighbors);
  }

  static bool _setsEqual(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    for (final item in a) {
      if (!b.contains(item)) return false;
    }
    return true;
  }
}
