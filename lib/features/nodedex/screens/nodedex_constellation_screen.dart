// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Constellation Screen — interactive mesh graph visualization.
//
// Renders the co-seen node relationships as a constellation-style graph.
// Uses force-directed layout computed by nodeDexConstellationProvider for
// meaningful spatial clustering. Key design principles:
//
// - Clean by default: only significant edges shown, labels only on top nodes
// - Focus mode: tap a node to see ALL its connections, everything else dims
// - Edge density control: slider lets users tune visible edge threshold
// - Tap edges to inspect co-seen relationships
//
// This screen is purely additive and Meshtastic-only.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/app_providers.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';
import '../widgets/edge_detail_sheet.dart';
import '../widgets/sigil_painter.dart';
import 'nodedex_detail_screen.dart';

// =============================================================================
// Edge density presets
// =============================================================================

/// Controls how many edges are visible in the constellation.
///
/// The percentile value determines the minimum weight threshold:
/// edges below this percentile are hidden.
enum EdgeDensity {
  sparse(0.80, 'Sparse'),
  normal(0.60, 'Normal'),
  dense(0.30, 'Dense'),
  all(0.0, 'All');

  final double percentile;
  final String label;
  const EdgeDensity(this.percentile, this.label);
}

// =============================================================================
// Constellation Screen
// =============================================================================

/// Interactive constellation visualization of the mesh field journal.
///
/// Shows all discovered nodes as a graph where edges represent
/// co-seen relationships. Layout is force-directed — strongly connected
/// nodes cluster together naturally.
class NodeDexConstellationScreen extends ConsumerStatefulWidget {
  const NodeDexConstellationScreen({super.key});

  @override
  ConsumerState<NodeDexConstellationScreen> createState() =>
      _NodeDexConstellationScreenState();
}

class _NodeDexConstellationScreenState
    extends ConsumerState<NodeDexConstellationScreen>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformController =
      TransformationController();

  /// Currently selected node for the info overlay.
  int? _selectedNodeNum;

  /// Currently selected edge for the edge info overlay.
  ConstellationEdge? _selectedEdge;

  /// Edge density level controlling visible edge threshold.
  EdgeDensity _edgeDensity = EdgeDensity.normal;

  /// Animation controller for the pulse effect on selected node.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    AppLogging.nodeDex('Constellation screen opened');
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    AppLogging.nodeDex('Constellation screen disposed');
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final constellation = ref.watch(nodeDexConstellationProvider);
    final isDark = context.isDarkMode;

    // Compute the weight threshold from the current density level.
    final weightThreshold = constellation.edges.isEmpty
        ? 0
        : constellation.weightAtPercentile(_edgeDensity.percentile);

    // Count visible edges for the stats bar.
    final visibleEdgeCount = _selectedNodeNum != null
        ? constellation.edges
              .where(
                (e) => e.from == _selectedNodeNum || e.to == _selectedNodeNum,
              )
              .length
        : constellation.edges.where((e) => e.weight >= weightThreshold).length;

    AppLogging.nodeDex(
      'Constellation build — ${constellation.nodeCount} nodes, '
      '$visibleEdgeCount/${constellation.edgeCount} edges visible '
      '(density: ${_edgeDensity.label})',
    );

    return GlassScaffold.body(
      title: 'Constellation',
      actions: [
        if (constellation.nodeCount > 0)
          IconButton(
            icon: const Icon(Icons.center_focus_strong_outlined),
            tooltip: 'Reset view',
            onPressed: _resetView,
          ),
      ],
      body: constellation.isEmpty
          ? _buildEmptyState(context)
          : Stack(
              children: [
                // Background gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.2,
                        colors: isDark
                            ? [const Color(0xFF0F1320), const Color(0xFF060810)]
                            : [context.background, const Color(0xFFF0F2F8)],
                      ),
                    ),
                  ),
                ),

                // Interactive constellation graph
                Positioned.fill(
                  child: InteractiveViewer(
                    transformationController: _transformController,
                    minScale: 0.3,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(300),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          math.max(constraints.maxWidth, 300),
                          math.max(constraints.maxHeight, 300),
                        );
                        return GestureDetector(
                          onTapUp: (details) =>
                              _handleTap(details, size, constellation),
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, _) {
                              return CustomPaint(
                                size: size,
                                painter: _ConstellationPainter(
                                  data: constellation,
                                  isDark: isDark,
                                  selectedNodeNum: _selectedNodeNum,
                                  selectedEdge: _selectedEdge,
                                  pulseValue: _pulseAnimation.value,
                                  accentColor: context.accentColor,
                                  weightThreshold: weightThreshold,
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Top controls: stats + density
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _ControlBar(
                    nodeCount: constellation.nodeCount,
                    visibleEdgeCount: visibleEdgeCount,
                    totalEdgeCount: constellation.edgeCount,
                    density: _edgeDensity,
                    hasSelection: _selectedNodeNum != null,
                    onDensityChanged: (d) {
                      HapticFeedback.selectionClick();
                      setState(() => _edgeDensity = d);
                    },
                    onClearSelection: _selectedNodeNum != null
                        ? () => setState(() {
                            _selectedNodeNum = null;
                            _selectedEdge = null;
                          })
                        : null,
                  ),
                ),

                // Hint text when nothing selected
                if (_selectedNodeNum == null && _selectedEdge == null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white)
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.border.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          'Tap a node to explore its connections',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Selected node info card
                if (_selectedNodeNum != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    child: _NodeInfoCard(
                      nodeNum: _selectedNodeNum!,
                      onClose: () => setState(() {
                        _selectedNodeNum = null;
                        _selectedEdge = null;
                      }),
                      onOpenDetail: () => _openDetail(_selectedNodeNum!),
                    ),
                  ),

                // Selected edge info card
                if (_selectedEdge != null && _selectedNodeNum == null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    child: _EdgeInfoCard(
                      edge: _selectedEdge!,
                      onClose: () => setState(() => _selectedEdge = null),
                      onOpenNodeDetail: (nodeNum) {
                        setState(() {
                          _selectedEdge = null;
                          _selectedNodeNum = nodeNum;
                        });
                      },
                      onViewDetails: () {
                        final edge = _selectedEdge!;
                        setState(() => _selectedEdge = null);
                        EdgeDetailSheet.show(
                          context: context,
                          fromNodeNum: edge.from,
                          toNodeNum: edge.to,
                          onOpenNodeDetail: _openDetail,
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tap handling
  // ---------------------------------------------------------------------------

  void _handleTap(
    TapUpDetails details,
    Size canvasSize,
    ConstellationData data,
  ) {
    // Transform tap position back through the InteractiveViewer matrix.
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.tryInvert(matrix);
    if (inverseMatrix == null) return;

    final localPoint = MatrixUtils.transformPoint(
      inverseMatrix,
      details.localPosition,
    );

    // Priority 1: Find the nearest node within tap radius.
    const nodeTapRadius = 28.0;
    int? nearestNode;
    double nearestNodeDist = double.infinity;

    for (final node in data.nodes) {
      final nodeX = node.x * canvasSize.width;
      final nodeY = node.y * canvasSize.height;
      final dx = localPoint.dx - nodeX;
      final dy = localPoint.dy - nodeY;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist < nodeTapRadius && dist < nearestNodeDist) {
        nearestNodeDist = dist;
        nearestNode = node.nodeNum;
      }
    }

    if (nearestNode != null) {
      AppLogging.nodeDex(
        'Constellation node tapped: '
        '!${nearestNode.toRadixString(16).toUpperCase().padLeft(4, '0')} '
        '(distance: ${nearestNodeDist.toStringAsFixed(1)}px)',
      );
      HapticFeedback.selectionClick();
      setState(() {
        // Toggle selection if tapping the same node.
        if (_selectedNodeNum == nearestNode) {
          _selectedNodeNum = null;
        } else {
          _selectedNodeNum = nearestNode;
        }
        _selectedEdge = null;
      });
      return;
    }

    // Priority 2: Find the nearest edge within tap tolerance.
    const edgeTapTolerance = 18.0;
    ConstellationEdge? nearestEdge;
    double nearestEdgeDist = double.infinity;

    // Build position lookup for edge hit testing.
    final positions = <int, Offset>{};
    for (final node in data.nodes) {
      positions[node.nodeNum] = Offset(
        node.x * canvasSize.width,
        node.y * canvasSize.height,
      );
    }

    for (final edge in data.edges) {
      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;

      final dist = _pointToSegmentDistance(localPoint, from, to);
      if (dist < edgeTapTolerance && dist < nearestEdgeDist) {
        nearestEdgeDist = dist;
        nearestEdge = edge;
      }
    }

    HapticFeedback.selectionClick();
    if (nearestEdge != null) {
      AppLogging.nodeDex(
        'Constellation edge tapped: '
        '!${nearestEdge.from.toRadixString(16).toUpperCase().padLeft(4, '0')} ↔ '
        '!${nearestEdge.to.toRadixString(16).toUpperCase().padLeft(4, '0')} '
        '(weight: ${nearestEdge.weight})',
      );
    } else {
      AppLogging.nodeDex('Constellation background tapped — deselecting');
    }
    setState(() {
      if (nearestEdge != null) {
        _selectedEdge = nearestEdge;
        _selectedNodeNum = null;
      } else {
        // Tapped empty space — deselect everything.
        _selectedNodeNum = null;
        _selectedEdge = null;
      }
    });
  }

  /// Compute the shortest distance from a point to a line segment.
  double _pointToSegmentDistance(Offset point, Offset segA, Offset segB) {
    final dx = segB.dx - segA.dx;
    final dy = segB.dy - segA.dy;
    final lengthSq = dx * dx + dy * dy;

    if (lengthSq < 1e-10) {
      final px = point.dx - segA.dx;
      final py = point.dy - segA.dy;
      return math.sqrt(px * px + py * py);
    }

    final t =
        ((point.dx - segA.dx) * dx + (point.dy - segA.dy) * dy) / lengthSq;
    final clamped = t.clamp(0.0, 1.0);
    final closestX = segA.dx + clamped * dx;
    final closestY = segA.dy + clamped * dy;
    final px = point.dx - closestX;
    final py = point.dy - closestY;
    return math.sqrt(px * px + py * py);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _resetView() {
    AppLogging.nodeDex('Constellation view reset to identity');
    HapticFeedback.lightImpact();
    _transformController.value = Matrix4.identity();
    setState(() {
      _selectedNodeNum = null;
      _selectedEdge = null;
    });
  }

  void _openDetail(int nodeNum) {
    AppLogging.nodeDex(
      'Constellation → opening detail for '
      '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}',
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NodeDexDetailScreen(nodeNum: nodeNum),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.scatter_plot_outlined,
              size: 72,
              color: context.textTertiary,
            ),
            const SizedBox(height: 24),
            Text(
              'No Constellation Yet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              'Discover more nodes to see how they connect. '
              'Nodes that appear together in the same session '
              'form constellation links.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Constellation Painter
// =============================================================================

class _ConstellationPainter extends CustomPainter {
  final ConstellationData data;
  final bool isDark;
  final int? selectedNodeNum;
  final ConstellationEdge? selectedEdge;
  final double pulseValue;
  final Color accentColor;
  final int weightThreshold;

  _ConstellationPainter({
    required this.data,
    required this.isDark,
    this.selectedNodeNum,
    this.selectedEdge,
    required this.pulseValue,
    required this.accentColor,
    required this.weightThreshold,
  });

  /// Set of node numbers directly connected to the selected node.
  Set<int> get _selectedNeighbors {
    if (selectedNodeNum == null) return const {};
    final neighbors = <int>{};
    for (final edge in data.edges) {
      if (edge.from == selectedNodeNum) neighbors.add(edge.to);
      if (edge.to == selectedNodeNum) neighbors.add(edge.from);
    }
    return neighbors;
  }

  /// Top N nodes by connection count for default label display.
  Set<int> get _topNodes {
    if (data.nodes.isEmpty) return const {};
    // Show labels for top 5 nodes only when nothing is selected.
    final sorted = [...data.nodes]
      ..sort((a, b) => b.connectionCount.compareTo(a.connectionCount));
    final count = math.min(5, sorted.length);
    return sorted.take(count).map((n) => n.nodeNum).toSet();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final positions = <int, Offset>{};
    for (final node in data.nodes) {
      positions[node.nodeNum] = Offset(
        node.x * size.width,
        node.y * size.height,
      );
    }

    final neighbors = _selectedNeighbors;
    final topNodes = selectedNodeNum == null ? _topNodes : const <int>{};

    // Draw edges first (underneath nodes).
    _drawEdges(canvas, positions, neighbors);

    // Draw nodes on top.
    _drawNodes(canvas, size, positions, neighbors, topNodes);
  }

  // ---------------------------------------------------------------------------
  // Edge drawing
  // ---------------------------------------------------------------------------

  void _drawEdges(
    Canvas canvas,
    Map<int, Offset> positions,
    Set<int> neighbors,
  ) {
    final hasFocus = selectedNodeNum != null;

    for (final edge in data.edges) {
      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;

      final isConnectedToSelected =
          hasFocus &&
          (edge.from == selectedNodeNum || edge.to == selectedNodeNum);

      final isSelectedEdge =
          selectedEdge != null &&
          edge.from == selectedEdge!.from &&
          edge.to == selectedEdge!.to;

      // --- Visibility rules ---
      // Focus mode: only draw edges connected to the selected node.
      // Default mode: only draw edges above the weight threshold.
      if (hasFocus && !isConnectedToSelected && !isSelectedEdge) continue;
      if (!hasFocus && edge.weight < weightThreshold && !isSelectedEdge) {
        continue;
      }

      // Normalize weight for visual mapping.
      final normalizedWeight = data.maxWeight > 1
          ? edge.weight / data.maxWeight.toDouble()
          : 0.5;

      if (isSelectedEdge) {
        // Selected edge: bright glow + thick line.
        _drawSelectedEdge(canvas, from, to, normalizedWeight);
      } else if (isConnectedToSelected) {
        // Focus mode: connected edge — visible and colored.
        _drawFocusEdge(canvas, from, to, edge, normalizedWeight);
      } else {
        // Default mode: subtle, thin line.
        _drawDefaultEdge(canvas, from, to, edge, normalizedWeight);
      }
    }
  }

  void _drawSelectedEdge(
    Canvas canvas,
    Offset from,
    Offset to,
    double normalizedWeight,
  ) {
    final strokeWidth = 1.5 + normalizedWeight * 2.5;

    // Glow layer.
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.2 * pulseValue)
      ..strokeWidth = strokeWidth + 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawLine(from, to, glowPaint);

    // Core line.
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.6 + 0.3 * pulseValue)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
  }

  void _drawFocusEdge(
    Canvas canvas,
    Offset from,
    Offset to,
    ConstellationEdge edge,
    double normalizedWeight,
  ) {
    // Blend the two endpoint colors.
    final color = _edgeColor(edge) ?? accentColor;
    final alpha = 0.2 + normalizedWeight * 0.5;
    final strokeWidth = 0.8 + normalizedWeight * 2.0;

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
  }

  void _drawDefaultEdge(
    Canvas canvas,
    Offset from,
    Offset to,
    ConstellationEdge edge,
    double normalizedWeight,
  ) {
    // Very subtle — just enough to hint at structure.
    final color = _edgeColor(edge) ?? (isDark ? Colors.white : Colors.black);
    final baseAlpha = isDark ? 0.04 : 0.03;
    final alpha = baseAlpha + normalizedWeight * (isDark ? 0.12 : 0.08);
    final strokeWidth = 0.3 + normalizedWeight * 1.0;

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, to, paint);
  }

  Color? _edgeColor(ConstellationEdge edge) {
    final fromNode = data.nodes.cast<ConstellationNode?>().firstWhere(
      (n) => n!.nodeNum == edge.from,
      orElse: () => null,
    );
    final toNode = data.nodes.cast<ConstellationNode?>().firstWhere(
      (n) => n!.nodeNum == edge.to,
      orElse: () => null,
    );
    if (fromNode?.sigil != null && toNode?.sigil != null) {
      return Color.lerp(
        fromNode!.sigil!.primaryColor,
        toNode!.sigil!.primaryColor,
        0.5,
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Node drawing
  // ---------------------------------------------------------------------------

  void _drawNodes(
    Canvas canvas,
    Size size,
    Map<int, Offset> positions,
    Set<int> neighbors,
    Set<int> topNodes,
  ) {
    final hasFocus = selectedNodeNum != null;

    for (final node in data.nodes) {
      final pos = positions[node.nodeNum];
      if (pos == null) continue;

      final isSelected = node.nodeNum == selectedNodeNum;
      final isNeighbor = neighbors.contains(node.nodeNum);
      final isEdgeEndpoint =
          selectedEdge != null &&
          (node.nodeNum == selectedEdge!.from ||
              node.nodeNum == selectedEdge!.to);

      final sigil = node.sigil ?? SigilGenerator.generate(node.nodeNum);
      final primaryColor = sigil.primaryColor;

      // Dim non-relevant nodes in focus mode.
      final isDimmed = hasFocus && !isSelected && !isNeighbor;

      // Node radius scales with connection count (subtly).
      const baseRadius = 5.0;
      final connectionBonus =
          math.min(node.connectionCount.toDouble(), 15.0) * 0.3;
      final radius = baseRadius + connectionBonus;

      // --- Selection halo ---
      if (isSelected) {
        final haloRadius = radius + 10.0 + (pulseValue * 5.0);
        final haloPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.12 * pulseValue)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, haloRadius, haloPaint);

        final haloRingPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.4 * pulseValue)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, haloRadius, haloRingPaint);
      }

      // --- Edge endpoint halo ---
      if (isEdgeEndpoint && !isSelected) {
        final haloRadius = radius + 6.0 + (pulseValue * 3.0);
        final haloPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.1 * pulseValue)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, haloRadius, haloPaint);
      }

      // --- Trait ring (only for non-dimmed nodes) ---
      if (!isDimmed && node.trait != NodeTrait.unknown) {
        final traitAlpha = isSelected || isNeighbor || isEdgeEndpoint
            ? 0.7
            : 0.25;
        final ringPaint = Paint()
          ..color = node.trait.color.withValues(alpha: traitAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, radius + 2.5, ringPaint);
      }

      // --- Outer glow ---
      if (!isDimmed) {
        final glowAlpha = isSelected || isNeighbor ? 0.2 : 0.06;
        final glowPaint = Paint()
          ..color = primaryColor.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawCircle(pos, radius + 1.5, glowPaint);
      }

      // --- Node fill ---
      final fillAlpha = isDimmed
          ? 0.15
          : (isSelected || isNeighbor ? 1.0 : 0.7);
      final fillPaint = Paint()
        ..color = primaryColor.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, isDimmed ? radius * 0.7 : radius, fillPaint);

      // --- Center highlight ---
      if (!isDimmed) {
        final highlightAlpha = isSelected ? 0.5 : 0.2;
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: highlightAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, radius * 0.35, highlightPaint);
      }

      // --- Label ---
      final showLabel =
          isSelected ||
          isNeighbor ||
          isEdgeEndpoint ||
          (!hasFocus && topNodes.contains(node.nodeNum));

      if (showLabel && !isDimmed) {
        final labelAlpha = isSelected || isNeighbor || isEdgeEndpoint
            ? 0.9
            : 0.6;
        _drawLabel(
          canvas,
          pos,
          radius,
          node.displayName,
          primaryColor,
          labelAlpha,
        );
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset position,
    double nodeRadius,
    String label,
    Color color,
    double alpha,
  ) {
    final displayLabel = label.length > 16
        ? '${label.substring(0, 14)}\u2026'
        : label;

    final textStyle = ui.TextStyle(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: alpha),
      fontSize: 10,
      fontWeight: FontWeight.w500,
    );

    final paragraphBuilder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              maxLines: 1,
              ellipsis: '\u2026',
            ),
          )
          ..pushStyle(textStyle)
          ..addText(displayLabel);

    final paragraph = paragraphBuilder.build()
      ..layout(const ui.ParagraphConstraints(width: 120));

    final textOffset = Offset(
      position.dx - paragraph.width / 2,
      position.dy + nodeRadius + 6,
    );

    // Subtle background pill behind the text.
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          textOffset.dx + paragraph.width / 2,
          textOffset.dy + paragraph.height / 2,
        ),
        width: paragraph.width + 10,
        height: paragraph.height + 5,
      ),
      const Radius.circular(5),
    );

    final bgPaint = Paint()
      ..color = (isDark ? const Color(0xFF0F1320) : Colors.white).withValues(
        alpha: 0.7,
      );
    canvas.drawRRect(bgRect, bgPaint);

    canvas.drawParagraph(paragraph, textOffset);
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.selectedNodeNum != selectedNodeNum ||
        oldDelegate.selectedEdge != selectedEdge ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isDark != isDark ||
        oldDelegate.weightThreshold != weightThreshold;
  }
}

// =============================================================================
// Control Bar
// =============================================================================

class _ControlBar extends StatelessWidget {
  final int nodeCount;
  final int visibleEdgeCount;
  final int totalEdgeCount;
  final EdgeDensity density;
  final bool hasSelection;
  final ValueChanged<EdgeDensity> onDensityChanged;
  final VoidCallback? onClearSelection;

  const _ControlBar({
    required this.nodeCount,
    required this.visibleEdgeCount,
    required this.totalEdgeCount,
    required this.density,
    required this.hasSelection,
    required this.onDensityChanged,
    this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F1320) : Colors.white).withValues(
          alpha: 0.8,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats row
          Row(
            children: [
              Icon(
                Icons.scatter_plot_outlined,
                size: 14,
                color: context.textTertiary,
              ),
              const SizedBox(width: 5),
              Text(
                '$nodeCount nodes',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              Container(
                width: 1,
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: context.border.withValues(alpha: 0.2),
              ),
              Icon(Icons.link, size: 14, color: context.textTertiary),
              const SizedBox(width: 5),
              Text(
                hasSelection
                    ? '$visibleEdgeCount links'
                    : '$visibleEdgeCount / $totalEdgeCount links',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              const Spacer(),
              if (hasSelection && onClearSelection != null)
                GestureDetector(
                  onTap: onClearSelection,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.close, size: 10, color: context.accentColor),
                        const SizedBox(width: 3),
                        Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: context.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Density selector (hidden when a node is focused)
          if (!hasSelection) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'DENSITY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.textTertiary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: EdgeDensity.values.map((d) {
                      final isActive = d == density;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onDensityChanged(d),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? context.accentColor.withValues(alpha: 0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isActive
                                    ? context.accentColor.withValues(alpha: 0.3)
                                    : context.border.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                d.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? context.accentColor
                                      : context.textTertiary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Node Info Card
// =============================================================================

class _NodeInfoCard extends ConsumerWidget {
  final int nodeNum;
  final VoidCallback onClose;
  final VoidCallback onOpenDetail;

  const _NodeInfoCard({
    required this.nodeNum,
    required this.onClose,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(nodeDexEntryProvider(nodeNum));
    final trait = ref.watch(nodeDexTraitProvider(nodeNum));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[nodeNum];
    final isDark = context.isDarkMode;

    if (entry == null) return const SizedBox.shrink();

    final sigil = entry.sigil ?? SigilGenerator.generate(nodeNum);
    final displayName = node?.displayName ?? 'Node $nodeNum';
    final hexId = '!${nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0')}';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xE6121724) : const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sigil.primaryColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: sigil.primaryColor.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Sigil avatar
                SigilAvatar(sigil: sigil, nodeNum: nodeNum, size: 40),
                const SizedBox(width: 10),

                // Name and metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hexId,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.textTertiary,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trait badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: trait.primary.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trait.primary.displayLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: trait.primary.color,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Close button
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Quick stats row
            Row(
              children: [
                _QuickStat(
                  icon: Icons.visibility_outlined,
                  value: '${entry.encounterCount}',
                  label: 'encounters',
                ),
                _QuickStat(
                  icon: Icons.hub_outlined,
                  value: '${entry.coSeenCount}',
                  label: 'links',
                ),
                if (entry.maxDistanceSeen != null)
                  _QuickStat(
                    icon: Icons.straighten_outlined,
                    value: _formatDistance(entry.maxDistanceSeen!),
                    label: 'max range',
                  ),
                const Spacer(),

                // Open detail button
                TextButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('Profile'),
                  style: TextButton.styleFrom(
                    foregroundColor: sigil.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }
}

// =============================================================================
// Edge Info Card
// =============================================================================

class _EdgeInfoCard extends ConsumerWidget {
  final ConstellationEdge edge;
  final VoidCallback onClose;
  final ValueChanged<int> onOpenNodeDetail;
  final VoidCallback? onViewDetails;

  const _EdgeInfoCard({
    required this.edge,
    required this.onClose,
    required this.onOpenNodeDetail,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final fromEntry = ref.watch(nodeDexEntryProvider(edge.from));
    final toEntry = ref.watch(nodeDexEntryProvider(edge.to));
    final fromNode = nodes[edge.from];
    final toNode = nodes[edge.to];
    final isDark = context.isDarkMode;
    final dateFormat = DateFormat('d MMM yyyy');

    final fromSigil = fromEntry?.sigil ?? SigilGenerator.generate(edge.from);
    final toSigil = toEntry?.sigil ?? SigilGenerator.generate(edge.to);
    final fromName = fromNode?.displayName ?? 'Node ${edge.from}';
    final toName = toNode?.displayName ?? 'Node ${edge.to}';

    final blendedColor =
        Color.lerp(fromSigil.primaryColor, toSigil.primaryColor, 0.5) ??
        context.accentColor;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xE6121724) : const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: blendedColor.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: blendedColor.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        fromSigil.primaryColor.withValues(alpha: 0.15),
                        toSigil.primaryColor.withValues(alpha: 0.15),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: blendedColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(Icons.link, size: 16, color: blendedColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Constellation Link',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Endpoint nodes row
            Row(
              children: [
                Expanded(
                  child: _EdgeEndpoint(
                    sigil: fromSigil,
                    nodeNum: edge.from,
                    name: fromName,
                    onTap: () => onOpenNodeDetail(edge.from),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Icon(
                        Icons.sync_alt,
                        size: 14,
                        color: blendedColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: blendedColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '${edge.weight}x',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: blendedColor,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _EdgeEndpoint(
                    sigil: toSigil,
                    nodeNum: edge.to,
                    name: toName,
                    onTap: () => onOpenNodeDetail(edge.to),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.03,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.border.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _QuickStat(
                    icon: Icons.visibility_outlined,
                    value: '${edge.weight}',
                    label: 'co-seen',
                  ),
                  if (edge.firstSeen != null)
                    _QuickStat(
                      icon: Icons.calendar_today_outlined,
                      value: dateFormat.format(edge.firstSeen!),
                      label: 'first link',
                    ),
                  if (edge.lastSeen != null)
                    _QuickStat(
                      icon: Icons.schedule_outlined,
                      value: _formatRelativeTime(edge.timeSinceLastSeen),
                      label: 'last seen',
                    ),
                ],
              ),
            ),

            // View Details button
            if (onViewDetails != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: Icon(
                      Icons.open_in_new_outlined,
                      size: 12,
                      color: blendedColor,
                    ),
                    label: Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: blendedColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: blendedColor.withValues(alpha: 0.2),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(Duration? duration) {
    if (duration == null) return '--';
    if (duration.inMinutes < 1) return 'now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    if (duration.inDays < 30) return '${duration.inDays}d ago';
    return '${(duration.inDays / 30).floor()}mo ago';
  }
}

// =============================================================================
// Edge Endpoint Widget
// =============================================================================

class _EdgeEndpoint extends StatelessWidget {
  final SigilData sigil;
  final int nodeNum;
  final String name;
  final VoidCallback onTap;

  const _EdgeEndpoint({
    required this.sigil,
    required this.nodeNum,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          SigilAvatar(sigil: sigil, nodeNum: nodeNum, size: 32),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Quick Stat
// =============================================================================

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _QuickStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.textTertiary),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
