// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Constellation Screen — minimal mesh graph visualization.
//
// Renders co-seen node relationships as a calm, star-chart-style graph.
// Force-directed layout computed by nodeDexConstellationProvider.
//
// Design principles:
// - Calm and minimal: no overlays, no floating cards, no pulsing
// - Stable layout: nothing shifts when you interact
// - Tap a node to focus its connections, tap again to deselect
// - Long-press a node to open its profile
// - Edge density cycles via app bar icon
// - Selected node info in a fixed-height bar at the bottom

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/app_providers.dart';

import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';
import '../widgets/sigil_painter.dart';
import 'nodedex_detail_screen.dart';

// =============================================================================
// Edge density presets
// =============================================================================

enum _EdgeDensity {
  sparse(0.80, 'Sparse', Icons.grain),
  normal(0.60, 'Normal', Icons.blur_on),
  dense(0.30, 'Dense', Icons.blur_circular),
  all(0.0, 'All', Icons.all_inclusive);

  final double percentile;
  final String label;
  final IconData icon;
  const _EdgeDensity(this.percentile, this.label, this.icon);

  _EdgeDensity get next {
    final values = _EdgeDensity.values;
    return values[(index + 1) % values.length];
  }
}

// =============================================================================
// Constellation Screen
// =============================================================================

class NodeDexConstellationScreen extends ConsumerStatefulWidget {
  const NodeDexConstellationScreen({super.key});

  @override
  ConsumerState<NodeDexConstellationScreen> createState() =>
      _NodeDexConstellationScreenState();
}

class _NodeDexConstellationScreenState
    extends ConsumerState<NodeDexConstellationScreen> {
  final TransformationController _transformController =
      TransformationController();

  int? _selectedNodeNum;
  _EdgeDensity _edgeDensity = _EdgeDensity.normal;

  @override
  void initState() {
    super.initState();
    AppLogging.nodeDex('Constellation screen opened');
  }

  @override
  void dispose() {
    AppLogging.nodeDex('Constellation screen disposed');
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final constellation = ref.watch(nodeDexConstellationProvider);
    final isDark = context.isDarkMode;

    final weightThreshold = constellation.edges.isEmpty
        ? 0
        : constellation.weightAtPercentile(_edgeDensity.percentile);

    return GlassScaffold.body(
      title: 'Constellation',
      actions: [
        if (constellation.nodeCount > 0) ...[
          // Density cycle button
          IconButton(
            icon: Icon(_edgeDensity.icon, size: 20),
            tooltip: 'Edge density: ${_edgeDensity.label}',
            onPressed: _cycleDensity,
          ),
          // Reset view
          IconButton(
            icon: const Icon(Icons.center_focus_strong_outlined, size: 20),
            tooltip: 'Reset view',
            onPressed: _resetView,
          ),
        ],
      ],
      body: constellation.isEmpty
          ? _buildEmptyState(context)
          : Column(
              children: [
                // Main canvas — takes all available space
                Expanded(
                  child: Stack(
                    children: [
                      // Background
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 1.2,
                              colors: isDark
                                  ? const [Color(0xFF0F1320), Color(0xFF060810)]
                                  : [
                                      context.background,
                                      const Color(0xFFF0F2F8),
                                    ],
                            ),
                          ),
                        ),
                      ),

                      // Interactive graph
                      Positioned.fill(
                        child: InteractiveViewer(
                          transformationController: _transformController,
                          minScale: 0.3,
                          maxScale: 5.0,
                          boundaryMargin: const EdgeInsets.all(200),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final size = Size(
                                math.max(constraints.maxWidth, 300),
                                math.max(constraints.maxHeight, 300),
                              );
                              return GestureDetector(
                                onTapUp: (d) =>
                                    _handleTap(d, size, constellation),
                                onLongPressStart: (d) =>
                                    _handleLongPress(d, size, constellation),
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    size: size,
                                    painter: _ConstellationPainter(
                                      data: constellation,
                                      isDark: isDark,
                                      selectedNodeNum: _selectedNodeNum,
                                      accentColor: context.accentColor,
                                      weightThreshold: weightThreshold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Fixed bottom bar — always present, content changes
                _BottomInfoBar(
                  selectedNodeNum: _selectedNodeNum,
                  nodeCount: constellation.nodeCount,
                  edgeCount: constellation.edgeCount,
                  density: _edgeDensity,
                  onClear: _selectedNodeNum != null
                      ? () => setState(() => _selectedNodeNum = null)
                      : null,
                  onOpenDetail: _selectedNodeNum != null
                      ? () => _openDetail(_selectedNodeNum!)
                      : null,
                ),
              ],
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interactions
  // ---------------------------------------------------------------------------

  void _handleTap(
    TapUpDetails details,
    Size canvasSize,
    ConstellationData data,
  ) {
    final matrix = _transformController.value;
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return;

    final local = MatrixUtils.transformPoint(inverse, details.localPosition);

    // Find nearest node within tap radius
    const tapRadius = 30.0;
    int? nearest;
    var nearestDist = double.infinity;

    for (final node in data.nodes) {
      final nx = node.x * canvasSize.width;
      final ny = node.y * canvasSize.height;
      final dist = math.sqrt(
        (local.dx - nx) * (local.dx - nx) + (local.dy - ny) * (local.dy - ny),
      );
      if (dist < tapRadius && dist < nearestDist) {
        nearestDist = dist;
        nearest = node.nodeNum;
      }
    }

    HapticFeedback.selectionClick();

    if (nearest != null) {
      setState(() {
        _selectedNodeNum = _selectedNodeNum == nearest ? null : nearest;
      });
    } else {
      // Tapped empty space — deselect
      if (_selectedNodeNum != null) {
        setState(() => _selectedNodeNum = null);
      }
    }
  }

  void _handleLongPress(
    LongPressStartDetails details,
    Size canvasSize,
    ConstellationData data,
  ) {
    final matrix = _transformController.value;
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return;

    final local = MatrixUtils.transformPoint(inverse, details.localPosition);

    const tapRadius = 30.0;
    int? nearest;
    var nearestDist = double.infinity;

    for (final node in data.nodes) {
      final nx = node.x * canvasSize.width;
      final ny = node.y * canvasSize.height;
      final dist = math.sqrt(
        (local.dx - nx) * (local.dx - nx) + (local.dy - ny) * (local.dy - ny),
      );
      if (dist < tapRadius && dist < nearestDist) {
        nearestDist = dist;
        nearest = node.nodeNum;
      }
    }

    if (nearest != null) {
      HapticFeedback.mediumImpact();
      _openDetail(nearest);
    }
  }

  void _cycleDensity() {
    HapticFeedback.selectionClick();
    setState(() => _edgeDensity = _edgeDensity.next);
  }

  void _resetView() {
    HapticFeedback.lightImpact();
    _transformController.value = Matrix4.identity();
    setState(() => _selectedNodeNum = null);
  }

  void _openDetail(int nodeNum) {
    AppLogging.nodeDex(
      'Constellation → detail for '
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
              size: 64,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Constellation Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Discover more nodes to see how they connect.\n'
              'Nodes seen together form constellation links.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Constellation Painter — clean, no pulsing, no trait rings
// =============================================================================

class _ConstellationPainter extends CustomPainter {
  final ConstellationData data;
  final bool isDark;
  final int? selectedNodeNum;
  final Color accentColor;
  final int weightThreshold;

  _ConstellationPainter({
    required this.data,
    required this.isDark,
    this.selectedNodeNum,
    required this.accentColor,
    required this.weightThreshold,
  });

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

    final neighbors = _neighborsOf(selectedNodeNum);
    final hasFocus = selectedNodeNum != null;

    // Labels: show on top-5 by connections when nothing selected,
    // or on selected + neighbors when focused.
    final labelNodes = hasFocus
        ? {selectedNodeNum!, ...neighbors}
        : _topNodes(5);

    // 1) Edges
    _paintEdges(canvas, positions, neighbors, hasFocus);

    // 2) Nodes
    _paintNodes(canvas, positions, neighbors, hasFocus, labelNodes);
  }

  // ---------------------------------------------------------------------------
  // Edges
  // ---------------------------------------------------------------------------

  void _paintEdges(
    Canvas canvas,
    Map<int, Offset> positions,
    Set<int> neighbors,
    bool hasFocus,
  ) {
    for (final edge in data.edges) {
      final from = positions[edge.from];
      final to = positions[edge.to];
      if (from == null || to == null) continue;

      final touchesSelected =
          hasFocus &&
          (edge.from == selectedNodeNum || edge.to == selectedNodeNum);

      // Visibility: in focus mode only show connected edges.
      // In default mode, apply weight threshold.
      if (hasFocus && !touchesSelected) continue;
      if (!hasFocus && edge.weight < weightThreshold) continue;

      final nw = data.maxWeight > 1
          ? edge.weight / data.maxWeight.toDouble()
          : 0.5;

      if (touchesSelected) {
        // Connected to selection: colored, visible
        final color = _blendedEdgeColor(edge);
        final alpha = 0.25 + nw * 0.45;
        final stroke = 0.8 + nw * 2.0;
        final paint = Paint()
          ..color = color.withValues(alpha: alpha)
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, paint);
      } else {
        // Default: very subtle
        final baseAlpha = isDark ? 0.04 : 0.03;
        final alpha = baseAlpha + nw * (isDark ? 0.10 : 0.07);
        final stroke = 0.3 + nw * 0.8;
        final paint = Paint()
          ..color = (isDark ? Colors.white : Colors.black).withValues(
            alpha: alpha,
          )
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, paint);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Nodes
  // ---------------------------------------------------------------------------

  void _paintNodes(
    Canvas canvas,
    Map<int, Offset> positions,
    Set<int> neighbors,
    bool hasFocus,
    Set<int> labelNodes,
  ) {
    for (final node in data.nodes) {
      final pos = positions[node.nodeNum];
      if (pos == null) continue;

      final isSelected = node.nodeNum == selectedNodeNum;
      final isNeighbor = neighbors.contains(node.nodeNum);
      final isDimmed = hasFocus && !isSelected && !isNeighbor;

      final sigil = node.sigil ?? SigilGenerator.generate(node.nodeNum);
      final color = sigil.primaryColor;

      // Radius: subtle scale with connections
      const baseR = 4.5;
      final bonus = math.min(node.connectionCount.toDouble(), 12.0) * 0.25;
      final r = baseR + bonus;

      // -- Selection ring (steady, no pulsing) --
      if (isSelected) {
        final ringPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, r + 10, ringPaint);

        final strokePaint = Paint()
          ..color = accentColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(pos, r + 10, strokePaint);
      }

      // -- Soft glow --
      if (!isDimmed) {
        final glowAlpha = isSelected || isNeighbor ? 0.15 : 0.05;
        final glowPaint = Paint()
          ..color = color.withValues(alpha: glowAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(pos, r + 1, glowPaint);
      }

      // -- Fill --
      final fillAlpha = isDimmed
          ? 0.12
          : (isSelected || isNeighbor ? 1.0 : 0.65);
      final fillR = isDimmed ? r * 0.6 : r;
      final fill = Paint()
        ..color = color.withValues(alpha: fillAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, fillR, fill);

      // -- Center dot --
      if (!isDimmed) {
        final dotAlpha = isSelected ? 0.45 : 0.18;
        final dot = Paint()
          ..color = Colors.white.withValues(alpha: dotAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, r * 0.3, dot);
      }

      // -- Label --
      if (!isDimmed && labelNodes.contains(node.nodeNum)) {
        final labelAlpha = isSelected || isNeighbor ? 0.85 : 0.55;
        _paintLabel(canvas, pos, r, node.displayName, labelAlpha);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  void _paintLabel(
    Canvas canvas,
    Offset pos,
    double nodeRadius,
    String text,
    double alpha,
  ) {
    final display = text.length > 14 ? '${text.substring(0, 12)}\u2026' : text;

    final style = ui.TextStyle(
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: alpha),
      fontSize: 9.5,
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
          ..addText(display);

    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: 110));

    final offset = Offset(
      pos.dx - paragraph.width / 2,
      pos.dy + nodeRadius + 5,
    );

    // Background pill
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(
          offset.dx + paragraph.width / 2,
          offset.dy + paragraph.height / 2,
        ),
        width: paragraph.width + 8,
        height: paragraph.height + 4,
      ),
      const Radius.circular(4),
    );

    final bgPaint = Paint()
      ..color = (isDark ? const Color(0xFF0F1320) : Colors.white).withValues(
        alpha: 0.65,
      );
    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawParagraph(paragraph, offset);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Set<int> _neighborsOf(int? nodeNum) {
    if (nodeNum == null) return const {};
    final result = <int>{};
    for (final e in data.edges) {
      if (e.from == nodeNum) result.add(e.to);
      if (e.to == nodeNum) result.add(e.from);
    }
    return result;
  }

  Set<int> _topNodes(int count) {
    if (data.nodes.isEmpty) return const {};
    final sorted = [...data.nodes]
      ..sort((a, b) => b.connectionCount.compareTo(a.connectionCount));
    return sorted
        .take(math.min(count, sorted.length))
        .map((n) => n.nodeNum)
        .toSet();
  }

  Color _blendedEdgeColor(ConstellationEdge edge) {
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
          ) ??
          accentColor;
    }
    return accentColor;
  }

  @override
  bool shouldRepaint(_ConstellationPainter old) {
    return old.data != data ||
        old.selectedNodeNum != selectedNodeNum ||
        old.isDark != isDark ||
        old.weightThreshold != weightThreshold;
  }
}

// =============================================================================
// Bottom Info Bar — fixed height, stable layout
// =============================================================================

class _BottomInfoBar extends ConsumerWidget {
  final int? selectedNodeNum;
  final int nodeCount;
  final int edgeCount;
  final _EdgeDensity density;
  final VoidCallback? onClear;
  final VoidCallback? onOpenDetail;

  const _BottomInfoBar({
    this.selectedNodeNum,
    required this.nodeCount,
    required this.edgeCount,
    required this.density,
    this.onClear,
    this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1017) : const Color(0xFFF5F6FA),
        border: Border(
          top: BorderSide(color: context.border.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: selectedNodeNum != null
                ? _buildSelectedContent(context, ref)
                : _buildDefaultContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultContent(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.scatter_plot_outlined,
          size: 14,
          color: context.textTertiary,
        ),
        const SizedBox(width: 6),
        Text(
          '$nodeCount nodes',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: AppTheme.fontFamily,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.link, size: 14, color: context.textTertiary),
        const SizedBox(width: 6),
        Text(
          '$edgeCount links',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: AppTheme.fontFamily,
            color: context.textSecondary,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            density.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: AppTheme.fontFamily,
              color: context.accentColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedContent(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(nodeDexEntryProvider(selectedNodeNum!));
    final trait = ref.watch(nodeDexTraitProvider(selectedNodeNum!));
    final nodes = ref.watch(nodesProvider);
    final node = nodes[selectedNodeNum!];

    if (entry == null) return _buildDefaultContent(context);

    final sigil = entry.sigil ?? SigilGenerator.generate(selectedNodeNum!);
    final name = node?.displayName ?? 'Node $selectedNodeNum';

    return Row(
      children: [
        // Sigil avatar
        SigilAvatar(sigil: sigil, nodeNum: selectedNodeNum!, size: 32),
        const SizedBox(width: 10),

        // Name + trait
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTheme.fontFamily,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: trait.primary.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trait.primary.displayLabel,
                    style: TextStyle(fontSize: 11, color: context.textTertiary),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${entry.coSeenCount} links',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Profile button
        GestureDetector(
          onTap: onOpenDetail,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sigil.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sigil.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              'Profile',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
                color: sigil.primaryColor,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Clear selection
        GestureDetector(
          onTap: onClear,
          child: Icon(Icons.close, size: 18, color: context.textTertiary),
        ),
      ],
    );
  }
}
