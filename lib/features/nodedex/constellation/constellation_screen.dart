// SPDX-License-Identifier: GPL-3.0-or-later

// Constellation Screen — redesigned mesh network graph visualization.
//
// A calm, interactive star-map-style view of the user's mesh network.
// Nodes are rendered as soft-glow circles, edges are near-invisible by
// default, and labels appear only on demand (tap, search, or zoom).
//
// Architecture:
// - CustomPainter-based rendering (no widget-per-node)
// - Quadtree spatial indexing for O(log n) hit testing and viewport culling
// - Grid-based clustering when zoomed out (>20 nodes)
// - Animated camera with inertial pan/zoom
// - Collision-detected labels with hard cap (8 max)
// - Search overlay with jump-and-zoom-to-node
// - Level-of-detail rendering (minimal/standard/full)
//
// Design: dark space aesthetic, zero labels by default, reveal on demand.
// "If everything is visible, nothing is meaningful."
//
// Key fix: neighbor set is CAPPED at 6 (top by edge weight). Without this,
// selecting a high-degree node like HIVE (54 links) lights up every node
// in the graph and turns the calm star map into neon vomit.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';

import '../providers/nodedex_providers.dart';
import '../screens/nodedex_detail_screen.dart';
import 'cluster_engine.dart';
import 'constellation_painter.dart';
import 'detail_panel.dart';
import 'quadtree.dart';

// =============================================================================
// Constants
// =============================================================================

/// Durations and thresholds for the constellation screen.
class _Durations {
  static const cameraAnimate = Duration(milliseconds: 400);
  static const searchPulseCycle = Duration(milliseconds: 1200);
  static const searchPulseTotal = Duration(milliseconds: 3600);
  static const doubleTapWindow = Duration(milliseconds: 300);

  _Durations._();
}

/// Zoom / scale constants.
class _Zoom {
  static const double min = 0.5;
  static const double max = 6.0;
  static const double focusLevel = 2.5;
  static const double searchFocusLevel = 3.0;

  _Zoom._();
}

/// Tap / hit-test constants.
class _Hit {
  static const double tapRadius = 28.0;
  static const double tapRadiusZoomAdjustMin = 18.0;
  static const double tapRadiusZoomAdjustMax = 40.0;

  _Hit._();
}

/// Neighbor display cap — prevents high-degree nodes from lighting up
/// the entire graph on selection. Only the top N connections (by edge
/// weight) are highlighted; the rest stay dimmed.
const int _maxHighlightedNeighbors = 8;

/// Maximum number of neighbor labels shown (may be lower than the
/// highlighted neighbor count to keep labels from crowding).
const int _maxNeighborLabels = 6;

// =============================================================================
// Constellation Screen
// =============================================================================

/// The main constellation visualization screen.
///
/// Renders a graph of co-seen mesh nodes as an interactive star map.
/// Supports pan, zoom, tap to select, double-tap to focus, long-press
/// to open profile, and search to jump to a specific node.
///
/// Uses [LifecycleSafeMixin] for safe async operations and
/// [TickerProviderStateMixin] for animation controllers.
class ConstellationScreen extends ConsumerStatefulWidget {
  const ConstellationScreen({super.key});

  @override
  ConsumerState<ConstellationScreen> createState() =>
      _ConstellationScreenState();
}

class _ConstellationScreenState extends ConsumerState<ConstellationScreen>
    with LifecycleSafeMixin, TickerProviderStateMixin {
  // -- Controllers ----------------------------------------------------------

  final TransformationController _transformController =
      TransformationController();

  late final AnimationController _cameraAnimController;
  late final AnimationController _searchPulseController;

  // -- Pinch-to-zoom state (no single-finger pan) ---------------------------

  /// Number of pointers currently touching the canvas.
  int _pointerCount = 0;

  /// Focal point at the start of a scale gesture (in canvas coords).
  Offset? _scaleStartFocal;

  /// Transform matrix at the start of a scale gesture.
  Matrix4? _scaleStartMatrix;

  /// Scale value at the start of the gesture.
  double _scaleStartZoom = 1.0;

  // -- State ----------------------------------------------------------------

  int? _selectedNodeNum;
  EdgeDensity _edgeDensity = EdgeDensity.none;
  bool _searchOpen = false;
  String _searchQuery = '';
  int? _searchHighlightNode;
  DateTime? _lastTapTime;
  int? _lastTapNode;

  // -- Engines --------------------------------------------------------------

  final ClusterEngine _clusterEngine = ClusterEngine();

  // -- Cached quadtree for hit testing (rebuilt when data changes) ----------

  Quadtree<ConstellationNode>? _hitTestTree;
  int _hitTestTreeDataHash = 0;
  Size _lastCanvasSize = Size.zero;

  // -- Camera animation state -----------------------------------------------

  Matrix4? _cameraAnimStart;
  Matrix4? _cameraAnimEnd;

  // =========================================================================
  // Lifecycle
  // =========================================================================

  @override
  void initState() {
    super.initState();
    AppLogging.nodeDex('Constellation screen opened (redesigned)');

    _cameraAnimController = AnimationController(
      vsync: this,
      duration: _Durations.cameraAnimate,
    )..addListener(_onCameraAnimTick);

    _searchPulseController = AnimationController(
      vsync: this,
      duration: _Durations.searchPulseCycle,
    );

    // Auto-fit the view after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoFitView();
    });
  }

  @override
  void dispose() {
    AppLogging.nodeDex('Constellation screen disposed');
    _cameraAnimController.dispose();
    _searchPulseController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final constellation = ref.watch(nodeDexConstellationProvider);
    final isDark = context.isDarkMode;

    final weightThreshold = constellation.edges.isEmpty
        ? 0
        : constellation.weightAtPercentile(_edgeDensity.percentile);

    return GlassScaffold.body(
      physics: const NeverScrollableScrollPhysics(),
      title: 'Constellation',
      actions: [
        if (constellation.nodeCount > 0) ...[
          // Search
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search, size: 20),
            tooltip: _searchOpen ? 'Close search' : 'Search nodes',
            onPressed: _toggleSearch,
          ),
          // Density cycle
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
                // Search bar (animated slide-down)
                _buildSearchBar(context, constellation),

                // Main canvas
                Expanded(
                  child: _buildCanvas(
                    context,
                    constellation,
                    isDark,
                    weightThreshold,
                  ),
                ),

                // Bottom info panel
                ConstellationDetailPanel(
                  selectedNodeNum: _selectedNodeNum,
                  nodeCount: constellation.nodeCount,
                  edgeCount: constellation.edgeCount,
                  density: _edgeDensity,
                  onClear: _selectedNodeNum != null
                      ? () => safeSetState(() => _selectedNodeNum = null)
                      : null,
                  onOpenDetail: _selectedNodeNum != null
                      ? () => _openDetail(_selectedNodeNum!)
                      : null,
                ),
              ],
            ),
    );
  }

  // =========================================================================
  // Canvas — GestureDetector INSIDE InteractiveViewer (critical!)
  //
  // The GestureDetector must be a child of InteractiveViewer so that:
  // 1. InteractiveViewer handles pan/zoom first
  // 2. Taps pass through to the child for node hit-testing
  // 3. Coordinate transforms are applied correctly
  //
  // Having GestureDetector OUTSIDE InteractiveViewer causes gesture arena
  // conflicts and incorrect coordinate mapping.
  // =========================================================================

  Widget _buildCanvas(
    BuildContext context,
    ConstellationData constellation,
    bool isDark,
    int weightThreshold,
  ) {
    return Stack(
      children: [
        // Deep space background
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.4,
                colors: isDark
                    ? const [Color(0xFF0D1120), Color(0xFF060810)]
                    : [context.background, const Color(0xFFF0F2F8)],
              ),
            ),
          ),
        ),

        // Fixed canvas — NO InteractiveViewer.
        // Pinch-to-zoom is handled manually via onScale* with a
        // pointer-count guard: single finger = tap only, two fingers = zoom.
        // The view NEVER pans or bounces from touch.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                math.max(constraints.maxWidth, 300),
                math.max(constraints.maxHeight, 300),
              );
              _lastCanvasSize = size;

              return Listener(
                onPointerDown: (_) => _pointerCount++,
                onPointerUp: (_) =>
                    _pointerCount = math.max(0, _pointerCount - 1),
                onPointerCancel: (_) =>
                    _pointerCount = math.max(0, _pointerCount - 1),
                child: GestureDetector(
                  // Tap and long-press for node interaction.
                  onTapUp: (d) => _handleTap(d, size, constellation),
                  onLongPressStart: (d) =>
                      _handleLongPress(d, size, constellation),
                  // Scale gestures for pinch-to-zoom only (2+ fingers).
                  onScaleStart: (d) => _onPinchStart(d, size),
                  onScaleUpdate: (d) => _onPinchUpdate(d, size),
                  onScaleEnd: (_) => _onPinchEnd(),
                  child: RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: Listenable.merge([
                        _transformController,
                        _searchPulseController,
                      ]),
                      builder: (context, _) {
                        final matrix = _transformController.value;
                        final zoom = _extractZoom(matrix);
                        final viewport = _computeViewport(matrix, size);

                        // Compute clusters at current zoom.
                        final clusterResult = _clusterEngine.compute(
                          nodes: constellation.nodes,
                          zoomLevel: zoom,
                        );

                        // Compute CAPPED neighbor set for the selected node.
                        final neighbors = _topNeighborsOf(
                          _selectedNodeNum,
                          constellation,
                          _maxHighlightedNeighbors,
                        );

                        // Compute which nodes should show labels.
                        final labels = _computeLabelNodes(
                          constellation,
                          neighbors,
                          zoom,
                        );

                        return CustomPaint(
                          size: size,
                          painter: ConstellationPainter(
                            data: constellation,
                            isDark: isDark,
                            selectedNodeNum: _selectedNodeNum,
                            neighbors: neighbors,
                            accentColor: context.accentColor,
                            weightThreshold: weightThreshold,
                            showBackgroundEdges:
                                _edgeDensity.showBackgroundEdges,
                            zoomLevel: zoom,
                            viewportRect: viewport,
                            clusterResult: clusterResult,
                            labelNodes: labels,
                            searchHighlightNode: _searchHighlightNode,
                            searchPulsePhase: _searchPulseController.value,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // Pinch-to-zoom — two-finger only, no single-finger pan
  //
  // Single touches pass through to onTapUp / onLongPressStart.
  // Only when 2+ pointers are down do we apply zoom transforms.
  // The canvas NEVER pans or bounces.
  // =========================================================================

  void _onPinchStart(ScaleStartDetails details, Size canvasSize) {
    // Only engage zoom when two or more fingers are down.
    if (_pointerCount < 2) return;

    _scaleStartFocal = details.localFocalPoint;
    _scaleStartMatrix = _transformController.value.clone();
    _scaleStartZoom = _extractZoom(_transformController.value);
  }

  void _onPinchUpdate(ScaleUpdateDetails details, Size canvasSize) {
    // Ignore single-finger drags — they must not move the view.
    if (_pointerCount < 2 || _scaleStartMatrix == null) return;

    final newScale = (_scaleStartZoom * details.scale).clamp(
      _Zoom.min,
      _Zoom.max,
    );

    // Compute the zoom-centered-on-focal-point transform.
    // 1. Translate so the focal point is at the origin.
    // 2. Apply the new scale.
    // 3. Translate back.
    final focal = _scaleStartFocal!;
    final result = Matrix4.identity()
      ..translate(focal.dx, focal.dy)
      ..scale(newScale / _scaleStartZoom)
      ..translate(-focal.dx, -focal.dy);

    // Multiply with the starting matrix to preserve prior transforms.
    _transformController.value = result * _scaleStartMatrix!;
  }

  void _onPinchEnd() {
    _scaleStartFocal = null;
    _scaleStartMatrix = null;
  }

  // =========================================================================
  // Search bar
  // =========================================================================

  Widget _buildSearchBar(
    BuildContext context,
    ConstellationData constellation,
  ) {
    return AnimatedCrossFade(
      firstChild: const SizedBox(width: double.infinity),
      secondChild: _ConstellationSearchBar(
        query: _searchQuery,
        onChanged: (q) => _onSearchChanged(q, constellation),
        onClear: _clearSearch,
      ),
      crossFadeState: _searchOpen
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
      sizeCurve: Curves.easeOutCubic,
    );
  }

  // =========================================================================
  // Empty state
  // =========================================================================

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

  // =========================================================================
  // Interactions
  // =========================================================================

  void _handleTap(
    TapUpDetails details,
    Size canvasSize,
    ConstellationData data,
  ) {
    // If a pinch gesture was in progress, ignore the tap.
    if (_pointerCount > 1) return;

    final matrix = _transformController.value;
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return;

    final local = MatrixUtils.transformPoint(inverse, details.localPosition);
    final zoom = _extractZoom(matrix);

    // When clustering is active, tapping should zoom into the tapped area
    // to expand the cluster rather than selecting an invisible individual node.
    final clusterResult = _clusterEngine.compute(
      nodes: data.nodes,
      zoomLevel: zoom,
    );

    if (clusterResult.isActive) {
      HapticFeedback.selectionClick();
      _zoomIntoClusterArea(local, canvasSize);
      _lastTapNode = null;
      _lastTapTime = null;
      return;
    }

    final nearest = _hitTest(local, canvasSize, data);

    HapticFeedback.selectionClick();

    final now = DateTime.now();

    if (nearest != null) {
      // Check for double-tap on same node.
      final isDoubleTap =
          _lastTapNode == nearest &&
          _lastTapTime != null &&
          now.difference(_lastTapTime!) < _Durations.doubleTapWindow;

      if (isDoubleTap) {
        // Double-tap: focus camera on this node.
        _focusOnNode(nearest, canvasSize, data);
        _lastTapNode = null;
        _lastTapTime = null;
      } else {
        // Single tap: toggle selection.
        safeSetState(() {
          _selectedNodeNum = _selectedNodeNum == nearest ? null : nearest;
          _searchHighlightNode = null;
        });
        _lastTapNode = nearest;
        _lastTapTime = now;
      }
    } else {
      // Tapped empty space — deselect.
      if (_selectedNodeNum != null) {
        safeSetState(() {
          _selectedNodeNum = null;
          _searchHighlightNode = null;
        });
      }
      _lastTapNode = null;
      _lastTapTime = null;
    }
  }

  void _handleLongPress(
    LongPressStartDetails details,
    Size canvasSize,
    ConstellationData data,
  ) {
    // If a pinch gesture was in progress, ignore the long press.
    if (_pointerCount > 1) return;

    final matrix = _transformController.value;
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) return;

    final local = MatrixUtils.transformPoint(inverse, details.localPosition);
    final nearest = _hitTest(local, canvasSize, data);

    if (nearest != null) {
      HapticFeedback.mediumImpact();
      _openDetail(nearest);
    }
  }

  // =========================================================================
  // Cluster zoom-in
  // =========================================================================

  /// When clustering is active and the user taps, zoom into the tapped area
  /// so clusters expand into individual nodes. Targets a zoom level just
  /// above [ClusterEngine.clusterZoomThreshold] to guarantee expansion.
  void _zoomIntoClusterArea(Offset canvasPoint, Size canvasSize) {
    final centerX = canvasSize.width * 0.5;
    final centerY = canvasSize.height * 0.5;

    // Target zoom just above the clustering threshold so nodes appear.
    const targetZoom = ClusterEngine.clusterZoomThreshold + 0.15;
    const scale = targetZoom;

    final targetMatrix = Matrix4.identity()
      ..translate(
        centerX - canvasPoint.dx * scale,
        centerY - canvasPoint.dy * scale,
      )
      ..scale(scale);

    _animateCamera(targetMatrix);
  }

  // =========================================================================
  // Hit testing via quadtree
  // =========================================================================

  /// Find the nearest node to [point] within tap radius, using the quadtree.
  int? _hitTest(Offset point, Size canvasSize, ConstellationData data) {
    // Rebuild quadtree if data changed or canvas size changed.
    final dataHash = data.nodeCount ^ data.edgeCount;
    if (_hitTestTree == null ||
        _hitTestTreeDataHash != dataHash ||
        _lastCanvasSize != canvasSize) {
      _hitTestTree = _buildHitTestTree(data, canvasSize);
      _hitTestTreeDataHash = dataHash;
    }

    // Adjust tap radius for zoom level.
    final zoom = _extractZoom(_transformController.value);
    final adjustedRadius = (_Hit.tapRadius / zoom).clamp(
      _Hit.tapRadiusZoomAdjustMin,
      _Hit.tapRadiusZoomAdjustMax,
    );

    final result = _hitTestTree!.findNearest(
      point,
      maxDistance: adjustedRadius,
    );

    return result?.$1.data.nodeNum;
  }

  Quadtree<ConstellationNode> _buildHitTestTree(
    ConstellationData data,
    Size canvasSize,
  ) {
    final items = <QuadtreeItem<ConstellationNode>>[];
    for (final node in data.nodes) {
      // Use a generous hit radius (larger than visual) for better tap targeting.
      final r =
          1.8 + math.min(node.connectionCount.toDouble(), 15.0) / 15.0 * 1.7;
      items.add(
        QuadtreeItem(
          position: Offset(
            node.x * canvasSize.width,
            node.y * canvasSize.height,
          ),
          radius: r + 4.0, // Extra padding for finger taps.
          data: node,
        ),
      );
    }
    return Quadtree.fromItems(items);
  }

  // =========================================================================
  // Camera animations
  // =========================================================================

  /// Smoothly animate the camera to focus on a specific node.
  void _focusOnNode(int nodeNum, Size canvasSize, ConstellationData data) {
    ConstellationNode? target;
    for (final node in data.nodes) {
      if (node.nodeNum == nodeNum) {
        target = node;
        break;
      }
    }
    if (target == null) return;

    // Select the node.
    safeSetState(() {
      _selectedNodeNum = nodeNum;
      _searchHighlightNode = null;
    });

    // Compute target transform: center on the node at focus zoom level.
    final nodeX = target.x * canvasSize.width;
    final nodeY = target.y * canvasSize.height;
    final centerX = canvasSize.width * 0.5;
    final centerY = canvasSize.height * 0.5;

    const scale = _Zoom.focusLevel;
    final targetMatrix = Matrix4.identity()
      ..translate(centerX - nodeX * scale, centerY - nodeY * scale)
      ..scale(scale);

    _animateCamera(targetMatrix);
  }

  /// Animate the camera to focus on a searched node.
  void _focusOnSearchResult(
    int nodeNum,
    Size canvasSize,
    ConstellationData data,
  ) {
    ConstellationNode? target;
    for (final node in data.nodes) {
      if (node.nodeNum == nodeNum) {
        target = node;
        break;
      }
    }
    if (target == null) return;

    safeSetState(() {
      _selectedNodeNum = nodeNum;
      _searchHighlightNode = nodeNum;
    });

    // Start search pulse animation.
    _searchPulseController.repeat();
    Future.delayed(_Durations.searchPulseTotal, () {
      if (!mounted) return;
      _searchPulseController.stop();
      _searchPulseController.reset();
      safeSetState(() => _searchHighlightNode = null);
    });

    // Compute target transform.
    final nodeX = target.x * canvasSize.width;
    final nodeY = target.y * canvasSize.height;
    final centerX = canvasSize.width * 0.5;
    final centerY = canvasSize.height * 0.5;

    const scale = _Zoom.searchFocusLevel;
    final targetMatrix = Matrix4.identity()
      ..translate(centerX - nodeX * scale, centerY - nodeY * scale)
      ..scale(scale);

    _animateCamera(targetMatrix);
  }

  /// Animate camera from current transform to [target].
  void _animateCamera(Matrix4 target) {
    _cameraAnimStart = _transformController.value.clone();
    _cameraAnimEnd = target;
    _cameraAnimController
      ..reset()
      ..forward();
  }

  void _onCameraAnimTick() {
    if (_cameraAnimStart == null || _cameraAnimEnd == null) return;

    final t = Curves.easeInOutCubic.transform(_cameraAnimController.value);

    // Interpolate each element of the 4x4 matrix.
    final result = Matrix4.zero();
    for (int i = 0; i < 16; i++) {
      result.storage[i] =
          _cameraAnimStart!.storage[i] +
          (_cameraAnimEnd!.storage[i] - _cameraAnimStart!.storage[i]) * t;
    }

    _transformController.value = result;
  }

  void _autoFitView() {
    // Reset to identity — the provider already normalizes to 0..1,
    // so the default transform shows the full constellation.
    _transformController.value = Matrix4.identity();
  }

  // =========================================================================
  // Search
  // =========================================================================

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    safeSetState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchQuery = '';
        _searchHighlightNode = null;
        _searchPulseController.stop();
        _searchPulseController.reset();
      }
    });
  }

  void _onSearchChanged(String query, ConstellationData data) {
    safeSetState(() => _searchQuery = query);

    if (query.isEmpty) {
      safeSetState(() => _searchHighlightNode = null);
      return;
    }

    final lowerQuery = query.toLowerCase();

    // Find the best matching node.
    ConstellationNode? bestMatch;
    int bestScore = -1;

    for (final node in data.nodes) {
      final name = node.displayName.toLowerCase();
      final hexId = node.nodeNum.toRadixString(16).toLowerCase();

      int score = 0;
      if (name == lowerQuery || hexId == lowerQuery) {
        score = 100; // Exact match.
      } else if (name.startsWith(lowerQuery) || hexId.startsWith(lowerQuery)) {
        score = 50; // Prefix match.
      } else if (name.contains(lowerQuery) || hexId.contains(lowerQuery)) {
        score = 10; // Substring match.
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = node;
      }
    }

    if (bestMatch != null && bestScore > 0 && _lastCanvasSize != Size.zero) {
      _focusOnSearchResult(bestMatch.nodeNum, _lastCanvasSize, data);
    }
  }

  void _clearSearch() {
    safeSetState(() {
      _searchQuery = '';
      _searchHighlightNode = null;
      _searchOpen = false;
    });
    _searchPulseController.stop();
    _searchPulseController.reset();
  }

  // =========================================================================
  // Actions
  // =========================================================================

  void _cycleDensity() {
    HapticFeedback.selectionClick();
    safeSetState(() => _edgeDensity = _edgeDensity.next);
  }

  void _resetView() {
    HapticFeedback.lightImpact();
    final target = Matrix4.identity();
    _animateCamera(target);
    safeSetState(() {
      _selectedNodeNum = null;
      _searchHighlightNode = null;
    });
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

  // =========================================================================
  // Utility — neighbor computation with cap
  // =========================================================================

  /// Extract the zoom/scale factor from a transformation matrix.
  double _extractZoom(Matrix4 matrix) {
    // Scale is encoded in the diagonal elements.
    final scaleX = math.sqrt(
      matrix.storage[0] * matrix.storage[0] +
          matrix.storage[1] * matrix.storage[1],
    );
    return scaleX;
  }

  /// Compute the visible viewport rectangle in canvas coordinates.
  Rect _computeViewport(Matrix4 matrix, Size canvasSize) {
    final inverse = Matrix4.tryInvert(matrix);
    if (inverse == null) {
      return Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height);
    }

    final topLeft = MatrixUtils.transformPoint(inverse, Offset.zero);
    final bottomRight = MatrixUtils.transformPoint(
      inverse,
      Offset(canvasSize.width, canvasSize.height),
    );

    return Rect.fromPoints(topLeft, bottomRight);
  }

  /// Get the TOP-N neighbors of [nodeNum], sorted by edge weight descending.
  ///
  /// This is the critical fix for high-degree nodes like HIVE (54 links).
  /// Without capping, selecting HIVE would highlight 54 of the 59 total nodes,
  /// making the entire graph light up and destroying all visual hierarchy.
  ///
  /// Only the [maxCount] strongest connections are returned. The painter
  /// dims all other edges connected to the selected node.
  Set<int> _topNeighborsOf(int? nodeNum, ConstellationData data, int maxCount) {
    if (nodeNum == null) return const {};

    // Collect all edges touching this node with their weights.
    final edgesWithWeight = <(int neighborNum, int weight)>[];
    for (final e in data.edges) {
      if (e.from == nodeNum) {
        edgesWithWeight.add((e.to, e.weight));
      } else if (e.to == nodeNum) {
        edgesWithWeight.add((e.from, e.weight));
      }
    }

    if (edgesWithWeight.length <= maxCount) {
      return edgesWithWeight.map((e) => e.$1).toSet();
    }

    // Sort by weight descending, take top N.
    edgesWithWeight.sort((a, b) => b.$2.compareTo(a.$2));
    return edgesWithWeight.take(maxCount).map((e) => e.$1).toSet();
  }

  /// Compute the set of node numbers that should show labels.
  ///
  /// Rules:
  /// - If a node is selected: show label for selected + top-N neighbors.
  /// - If search highlight is active: show label for the highlighted node.
  /// - Otherwise: ZERO labels. Labels are earned, not given.
  ///
  /// The painter applies collision detection and a hard cap (8) on top of this.
  Set<int> _computeLabelNodes(
    ConstellationData data,
    Set<int> neighbors,
    double zoom,
  ) {
    final labels = <int>{};

    // Selected node always gets a label.
    if (_selectedNodeNum != null) {
      labels.add(_selectedNodeNum!);

      // Add top-N neighbor labels (fewer than the highlight count
      // to keep the canvas from getting crowded with text).
      if (neighbors.length <= _maxNeighborLabels) {
        labels.addAll(neighbors);
      } else {
        // Take the first N from the already-sorted neighbor set.
        int count = 0;
        for (final n in neighbors) {
          labels.add(n);
          count++;
          if (count >= _maxNeighborLabels) break;
        }
      }
    }

    // Search highlight node always gets a label.
    if (_searchHighlightNode != null) {
      labels.add(_searchHighlightNode!);
    }

    return labels;
  }
}

// =============================================================================
// Search bar widget
// =============================================================================

class _ConstellationSearchBar extends StatefulWidget {
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _ConstellationSearchBar({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_ConstellationSearchBar> createState() =>
      _ConstellationSearchBarState();
}

class _ConstellationSearchBarState extends State<_ConstellationSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(_ConstellationSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _controller.text != widget.query) {
      _controller.text = widget.query;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0E18) : const Color(0xFFF5F6FA),
        border: Border(
          bottom: BorderSide(color: context.border.withValues(alpha: 0.08)),
        ),
      ),
      child: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(
          fontSize: 14,
          fontFamily: AppTheme.fontFamily,
          color: context.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Search by name or node ID\u2026',
          hintStyle: TextStyle(
            fontSize: 14,
            fontFamily: AppTheme.fontFamily,
            color: context.textTertiary,
          ),
          prefixIcon: Icon(Icons.search, size: 18, color: context.textTertiary),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    size: 18,
                    color: context.textTertiary,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onClear();
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF151B2B) : const Color(0xFFE8EAF0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: context.accentColor.withValues(alpha: 0.30),
              width: 1.0,
            ),
          ),
        ),
        onChanged: widget.onChanged,
        textInputAction: TextInputAction.search,
      ),
    );
  }
}
