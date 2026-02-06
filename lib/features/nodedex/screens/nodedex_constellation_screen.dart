// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Constellation Screen — interactive mesh graph visualization.
//
// Renders the co-seen node relationships as a constellation-style graph.
// Each node is drawn as a colored dot using its sigil palette, with
// edges connecting nodes that have been observed together. Edge thickness
// reflects co-seen frequency.
//
// Layout is deterministic — positions are derived from node number hashes
// via nodeDexConstellationProvider. The view supports:
// - Pan and zoom via InteractiveViewer
// - Tap a node to inspect it (shows info card, navigates to detail screen)
// - Tap an edge to inspect the co-seen relationship (shows edge info card)
// - Visual encoding of trait via halo color
// - Edge weight visualization via opacity and width
//
// This screen is purely additive and Meshtastic-only.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/app_providers.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';
import '../widgets/sigil_painter.dart';
import 'nodedex_detail_screen.dart';

/// Interactive constellation visualization of the mesh field journal.
///
/// Shows all discovered nodes as a graph where edges represent
/// co-seen relationships. The graph uses deterministic positioning
/// so the layout is stable across rebuilds.
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
  final GlobalKey _repaintBoundaryKey = GlobalKey();

  /// Currently selected node for the info overlay.
  int? _selectedNodeNum;

  /// Currently selected edge for the edge info overlay.
  ConstellationEdge? _selectedEdge;

  /// Animation controller for the pulse effect on selected node.
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final constellation = ref.watch(nodeDexConstellationProvider);
    final isDark = context.isDarkMode;

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
                            ? [context.background, const Color(0xFF0A0E1A)]
                            : [context.background, const Color(0xFFF0F2F8)],
                      ),
                    ),
                  ),
                ),

                // Interactive constellation graph
                Positioned.fill(
                  child: RepaintBoundary(
                    key: _repaintBoundaryKey,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.3,
                      maxScale: 4.0,
                      boundaryMargin: const EdgeInsets.all(200),
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
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Stats bar at top
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _StatsBar(
                    nodeCount: constellation.nodeCount,
                    edgeCount: constellation.edgeCount,
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
                      onClose: () => setState(() => _selectedNodeNum = null),
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
                    ),
                  ),
              ],
            ),
    );
  }

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
      HapticFeedback.selectionClick();
      setState(() {
        _selectedNodeNum = nearestNode;
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
  ///
  /// Uses the standard projection formula:
  /// - Project point P onto the line defined by A–B
  /// - Clamp the projection parameter t to [0, 1]
  /// - Return the distance from P to the clamped projection point
  double _pointToSegmentDistance(Offset point, Offset segA, Offset segB) {
    final dx = segB.dx - segA.dx;
    final dy = segB.dy - segA.dy;
    final lengthSq = dx * dx + dy * dy;

    if (lengthSq < 1e-10) {
      // Degenerate segment (A == B).
      final px = point.dx - segA.dx;
      final py = point.dy - segA.dy;
      return math.sqrt(px * px + py * py);
    }

    // Parameter t of the projection of point onto segment [0, 1].
    final t =
        ((point.dx - segA.dx) * dx + (point.dy - segA.dy) * dy) / lengthSq;
    final clamped = t.clamp(0.0, 1.0);

    // Closest point on segment.
    final closestX = segA.dx + clamped * dx;
    final closestY = segA.dy + clamped * dy;

    final px = point.dx - closestX;
    final py = point.dy - closestY;
    return math.sqrt(px * px + py * py);
  }

  void _resetView() {
    HapticFeedback.lightImpact();
    _transformController.value = Matrix4.identity();
  }

  void _openDetail(int nodeNum) {
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

  _ConstellationPainter({
    required this.data,
    required this.isDark,
    this.selectedNodeNum,
    this.selectedEdge,
    required this.pulseValue,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Build a position lookup for edge drawing.
    final positions = <int, Offset>{};
    for (final node in data.nodes) {
      positions[node.nodeNum] = Offset(
        node.x * size.width,
        node.y * size.height,
      );
    }

    // Draw edges first (underneath nodes).
    _drawEdges(canvas, positions);

    // Draw nodes on top.
    _drawNodes(canvas, size, positions);
  }

  void _drawEdges(Canvas canvas, Map<int, Offset> positions) {
    for (final edge in data.edges) {
      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;

      // Normalize edge weight for visual mapping.
      final normalizedWeight = data.maxWeight > 1
          ? edge.weight / data.maxWeight.toDouble()
          : 0.5;

      // Edge opacity and width scale with weight.
      final baseAlpha = isDark ? 0.15 : 0.12;
      final alpha = baseAlpha + normalizedWeight * (isDark ? 0.35 : 0.28);
      final strokeWidth = 0.5 + normalizedWeight * 2.0;

      // Determine edge color: blend the two endpoint node colors.
      final fromNode = data.nodes.cast<ConstellationNode?>().firstWhere(
        (n) => n!.nodeNum == edge.from,
        orElse: () => null,
      );
      final toNode = data.nodes.cast<ConstellationNode?>().firstWhere(
        (n) => n!.nodeNum == edge.to,
        orElse: () => null,
      );

      Color edgeColor;
      if (fromNode?.sigil != null && toNode?.sigil != null) {
        edgeColor =
            Color.lerp(
              fromNode!.sigil!.primaryColor,
              toNode!.sigil!.primaryColor,
              0.5,
            ) ??
            (isDark ? Colors.white : Colors.black);
      } else {
        edgeColor = isDark ? Colors.white : Colors.black;
      }

      // Highlight edges connected to the selected node or the selected edge.
      final isNodeHighlighted =
          selectedNodeNum != null &&
          (edge.from == selectedNodeNum || edge.to == selectedNodeNum);

      final isEdgeSelected =
          selectedEdge != null &&
          edge.from == selectedEdge!.from &&
          edge.to == selectedEdge!.to;

      double effectiveAlpha = alpha;
      double effectiveStrokeWidth = strokeWidth;

      if (isEdgeSelected) {
        // Selected edge gets a strong glow and pulse effect.
        effectiveAlpha = (alpha + 0.4 + pulseValue * 0.1).clamp(0.0, 1.0);
        effectiveStrokeWidth = strokeWidth + 2.0;

        // Draw glow behind selected edge.
        final glowPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.15 * pulseValue)
          ..strokeWidth = effectiveStrokeWidth + 6.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
        canvas.drawLine(from, to, glowPaint);
      } else if (isNodeHighlighted) {
        effectiveAlpha = (alpha + 0.3).clamp(0.0, 1.0);
        effectiveStrokeWidth = strokeWidth + 1.0;
      }

      final paint = Paint()
        ..color = edgeColor.withValues(alpha: effectiveAlpha)
        ..strokeWidth = effectiveStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(from, to, paint);
    }
  }

  void _drawNodes(Canvas canvas, Size size, Map<int, Offset> positions) {
    for (final node in data.nodes) {
      final pos = positions[node.nodeNum];
      if (pos == null) continue;

      final isSelected = node.nodeNum == selectedNodeNum;
      final isEdgeEndpoint =
          selectedEdge != null &&
          (node.nodeNum == selectedEdge!.from ||
              node.nodeNum == selectedEdge!.to);
      final sigil = node.sigil ?? SigilGenerator.generate(node.nodeNum);
      final primaryColor = sigil.primaryColor;
      final traitColor = node.trait.color;

      // Node radius scales with connection count.
      const baseRadius = 6.0;
      final connectionBonus =
          math.min(node.connectionCount.toDouble(), 10.0) * 0.5;
      final radius = baseRadius + connectionBonus;

      // Draw selection halo.
      if (isSelected) {
        final haloRadius = radius + 8.0 + (pulseValue * 4.0);
        final haloPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.2 * pulseValue)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, haloRadius, haloPaint);

        final haloRingPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.5 * pulseValue)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, haloRadius, haloRingPaint);
      }

      // Draw edge-endpoint halo (softer than full selection).
      if (isEdgeEndpoint && !isSelected) {
        final haloRadius = radius + 5.0 + (pulseValue * 2.0);
        final haloPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.15 * pulseValue)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, haloRadius, haloPaint);

        final haloRingPaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.35 * pulseValue)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(pos, haloRadius, haloRingPaint);
      }

      // Draw trait color ring.
      if (node.trait != NodeTrait.unknown) {
        final ringPaint = Paint()
          ..color = traitColor.withValues(
            alpha: isSelected || isEdgeEndpoint ? 0.8 : 0.4,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(pos, radius + 3.0, ringPaint);
      }

      // Draw outer glow.
      final glowPaint = Paint()
        ..color = primaryColor.withValues(
          alpha: isSelected || isEdgeEndpoint ? 0.25 : 0.1,
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawCircle(pos, radius + 2.0, glowPaint);

      // Draw node fill.
      final fillPaint = Paint()
        ..color = primaryColor.withValues(
          alpha: isSelected || isEdgeEndpoint ? 1.0 : 0.85,
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius, fillPaint);

      // Draw a lighter center highlight.
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: isSelected || isEdgeEndpoint ? 0.5 : 0.25,
        )
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, radius * 0.4, highlightPaint);

      // Draw node label for selected, edge-endpoint, or well-connected nodes.
      if (isSelected || isEdgeEndpoint || node.connectionCount >= 3) {
        _drawLabel(canvas, pos, radius, node.displayName, primaryColor);
      }
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset position,
    double nodeRadius,
    String label,
    Color color,
  ) {
    // Truncate long labels.
    final displayLabel = label.length > 14
        ? '${label.substring(0, 12)}\u2026'
        : label;

    final textStyle = ui.TextStyle(
      color: isDark
          ? Colors.white.withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.85),
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
      ..layout(const ui.ParagraphConstraints(width: 100));

    final textOffset = Offset(
      position.dx - paragraph.width / 2,
      position.dy + nodeRadius + 6,
    );

    // Draw a subtle background behind the text for readability.
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          textOffset.dx + paragraph.width / 2,
          textOffset.dy + paragraph.height / 2,
        ),
        width: paragraph.width + 8,
        height: paragraph.height + 4,
      ),
      const Radius.circular(4),
    );

    final bgPaint = Paint()
      ..color = (isDark ? Colors.black : Colors.white).withValues(alpha: 0.6);
    canvas.drawRRect(bgRect, bgPaint);

    canvas.drawParagraph(paragraph, textOffset);
  }

  @override
  bool shouldRepaint(_ConstellationPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.selectedNodeNum != selectedNodeNum ||
        oldDelegate.selectedEdge != selectedEdge ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.isDark != isDark;
  }
}

// =============================================================================
// Stats Bar
// =============================================================================

class _StatsBar extends StatelessWidget {
  final int nodeCount;
  final int edgeCount;

  const _StatsBar({required this.nodeCount, required this.edgeCount});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.scatter_plot_outlined,
            size: 16,
            color: context.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            '$nodeCount nodes',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: context.border.withValues(alpha: 0.3),
          ),
          Icon(Icons.link, size: 16, color: context.textSecondary),
          const SizedBox(width: 6),
          Text(
            '$edgeCount links',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
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
    final hexId = '!${nodeNum.toRadixString(16).padLeft(8, '0')}';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xE6181C28) : const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sigil.primaryColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: sigil.primaryColor.withValues(alpha: 0.15),
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
                SigilAvatar(sigil: sigil, nodeNum: nodeNum, size: 44),
                const SizedBox(width: 12),

                // Name and metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hexId,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.textTertiary,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trait badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: trait.primary.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trait.primary.displayLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: trait.primary.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Close button
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

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
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Profile'),
                  style: TextButton.styleFrom(
                    foregroundColor: sigil.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
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

  const _EdgeInfoCard({
    required this.edge,
    required this.onClose,
    required this.onOpenNodeDetail,
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

    // Blend the two endpoint colors for the card accent.
    final blendedColor =
        Color.lerp(fromSigil.primaryColor, toSigil.primaryColor, 0.5) ??
        context.accentColor;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xE6181C28) : const Color(0xE6FFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: blendedColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: blendedColor.withValues(alpha: 0.12),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: edge icon + title + close
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        fromSigil.primaryColor.withValues(alpha: 0.2),
                        toSigil.primaryColor.withValues(alpha: 0.2),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: blendedColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(Icons.link, size: 18, color: blendedColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Constellation Link',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    size: 20,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Endpoint nodes row
            Row(
              children: [
                // From node
                Expanded(
                  child: _EdgeEndpoint(
                    sigil: fromSigil,
                    nodeNum: edge.from,
                    name: fromName,
                    onTap: () => onOpenNodeDetail(edge.from),
                  ),
                ),

                // Connection indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Icon(
                        Icons.sync_alt,
                        size: 16,
                        color: blendedColor.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: blendedColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${edge.weight}x',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: blendedColor,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // To node
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

            const SizedBox(height: 12),

            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.04,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.border.withValues(alpha: 0.15),
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
                  if (edge.messageCount > 0)
                    _QuickStat(
                      icon: Icons.chat_bubble_outline,
                      value: '${edge.messageCount}',
                      label: 'messages',
                    ),
                ],
              ),
            ),

            // Relationship age line
            if (edge.relationshipAge != null &&
                edge.relationshipAge!.inHours >= 1)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Linked for ${_formatDuration(edge.relationshipAge!)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiary,
                    fontStyle: FontStyle.italic,
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

  String _formatDuration(Duration duration) {
    if (duration.inDays >= 365) {
      final years = duration.inDays ~/ 365;
      final months = (duration.inDays % 365) ~/ 30;
      if (months > 0) return '$years yr $months mo';
      return '$years yr';
    }
    if (duration.inDays >= 30) {
      final months = duration.inDays ~/ 30;
      final days = duration.inDays % 30;
      if (days > 0) return '$months mo $days d';
      return '$months mo';
    }
    if (duration.inDays >= 1) return '${duration.inDays} d';
    if (duration.inHours >= 1) return '${duration.inHours} hr';
    return '${duration.inMinutes} min';
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
          SigilAvatar(sigil: sigil, nodeNum: nodeNum, size: 36),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            '!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            style: TextStyle(
              fontSize: 9,
              color: context.textTertiary,
              fontFamily: 'monospace',
            ),
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
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textTertiary),
          const SizedBox(width: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
