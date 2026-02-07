// SPDX-License-Identifier: GPL-3.0-or-later

// Cluster engine for constellation visualization.
//
// When the user zooms out beyond a threshold, nearby nodes are aggregated
// into clusters to prevent visual noise. Clusters smoothly expand into
// individual nodes as the user zooms in.
//
// Algorithm: grid-based spatial hashing. Fast, deterministic, and stable
// across frames (no jitter). The grid cell size scales with zoom level
// so clusters naturally merge/split as the user zooms.

import 'dart:math' as math;
import 'dart:ui';

import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';

/// A cluster of nearby constellation nodes.
///
/// When zoomed out, multiple [ConstellationNode]s collapse into a single
/// visual element showing a count badge and aggregate glow.
class NodeCluster {
  /// The centroid position in normalized coordinates (0.0 to 1.0).
  final double cx;
  final double cy;

  /// The nodes contained in this cluster.
  final List<ConstellationNode> nodes;

  /// The dominant color — derived from the highest-connection node's sigil.
  final Color dominantColor;

  /// The secondary color — blended average of all node colors.
  final Color blendedColor;

  /// Total connection count across all nodes in the cluster.
  final int totalConnections;

  /// Visual radius multiplier based on node count.
  double get radiusScale {
    if (nodes.length <= 1) return 1.0;
    // Logarithmic scaling: grows slowly for large clusters.
    return 1.0 + math.log(nodes.length) * 0.6;
  }

  /// Whether this cluster is a single node (no aggregation needed).
  bool get isSingleton => nodes.length == 1;

  /// Display label for the cluster count badge.
  String get countLabel {
    if (nodes.length >= 1000) {
      return '${(nodes.length / 1000).toStringAsFixed(1)}k';
    }
    return nodes.length.toString();
  }

  const NodeCluster({
    required this.cx,
    required this.cy,
    required this.nodes,
    required this.dominantColor,
    required this.blendedColor,
    required this.totalConnections,
  });
}

/// Result of a clustering pass.
class ClusterResult {
  /// The clusters produced.
  final List<NodeCluster> clusters;

  /// The zoom level at which this clustering was computed.
  final double zoomLevel;

  /// The grid cell size used (in normalized 0-1 coordinates).
  final double cellSize;

  /// Whether clustering is active (zoom below threshold).
  final bool isActive;

  const ClusterResult({
    required this.clusters,
    required this.zoomLevel,
    required this.cellSize,
    required this.isActive,
  });

  /// Empty result for when clustering is disabled.
  static const disabled = ClusterResult(
    clusters: [],
    zoomLevel: 1.0,
    cellSize: 0.0,
    isActive: false,
  );
}

/// Engine that computes node clusters for the constellation view.
///
/// Clustering uses grid-based spatial hashing for O(n) performance.
/// The grid cell size is derived from zoom level — smaller cells at
/// higher zoom, larger cells when zoomed out.
///
/// Usage:
/// ```dart
/// final engine = ClusterEngine();
/// final result = engine.compute(
///   nodes: constellationData.nodes,
///   zoomLevel: currentZoom,
/// );
/// if (result.isActive) {
///   // Render clusters instead of individual nodes
/// }
/// ```
class ClusterEngine {
  /// Zoom level at or above which clustering is disabled.
  /// Below this threshold, nodes begin to aggregate.
  static const double clusterZoomThreshold = 0.65;

  /// Minimum zoom level — maximum clustering at this point.
  static const double minZoom = 0.1;

  /// Minimum number of nodes to trigger clustering.
  /// Below this count, always show individual nodes.
  static const int minNodesForClustering = 20;

  /// Maximum cell size in normalized coordinates (most zoomed out).
  static const double maxCellSize = 0.15;

  /// Minimum cell size in normalized coordinates (near threshold).
  static const double minCellSize = 0.04;

  /// Cached previous result for change detection.
  ClusterResult? _cached;
  double _cachedZoom = -1;
  int _cachedNodeCount = -1;

  /// Compute clusters for the given nodes at the current zoom level.
  ///
  /// Returns [ClusterResult.disabled] if zoom is above threshold or
  /// node count is below [minNodesForClustering].
  ///
  /// The result is cached — repeated calls with the same zoom level
  /// and node count return the cached result instantly.
  ClusterResult compute({
    required List<ConstellationNode> nodes,
    required double zoomLevel,
  }) {
    // Short-circuit: no clustering needed.
    if (zoomLevel >= clusterZoomThreshold ||
        nodes.length < minNodesForClustering) {
      return ClusterResult.disabled;
    }

    // Cache hit check — same zoom band and same node count.
    final quantizedZoom = (zoomLevel * 20).roundToDouble() / 20;
    if (_cached != null &&
        _cachedZoom == quantizedZoom &&
        _cachedNodeCount == nodes.length) {
      return _cached!;
    }

    // Compute cell size based on zoom level.
    // Lower zoom = larger cells = more aggressive clustering.
    final zoomNormalized =
        ((zoomLevel - minZoom) / (clusterZoomThreshold - minZoom)).clamp(
          0.0,
          1.0,
        );
    final cellSize = maxCellSize - (maxCellSize - minCellSize) * zoomNormalized;

    // Grid-based spatial hashing.
    final grid = <int, List<ConstellationNode>>{};

    for (final node in nodes) {
      final col = (node.x / cellSize).floor();
      final row = (node.y / cellSize).floor();
      final key = col * 10000 + row; // Unique cell key.
      (grid[key] ??= []).add(node);
    }

    // Build clusters from grid cells.
    final clusters = <NodeCluster>[];

    for (final cellNodes in grid.values) {
      if (cellNodes.isEmpty) continue;

      // Compute centroid.
      double sumX = 0;
      double sumY = 0;
      int totalConn = 0;
      int maxConn = 0;
      ConstellationNode? dominantNode;

      for (final node in cellNodes) {
        sumX += node.x;
        sumY += node.y;
        totalConn += node.connectionCount;
        if (node.connectionCount > maxConn) {
          maxConn = node.connectionCount;
          dominantNode = node;
        }
      }

      final cx = sumX / cellNodes.length;
      final cy = sumY / cellNodes.length;

      // Dominant color from highest-connection node.
      final dominant = dominantNode ?? cellNodes.first;
      final dominantSigil =
          dominant.sigil ?? SigilGenerator.generate(dominant.nodeNum);
      final dominantColor = dominantSigil.primaryColor;

      // Blended color from all nodes.
      final blended = _blendColors(cellNodes);

      clusters.add(
        NodeCluster(
          cx: cx,
          cy: cy,
          nodes: cellNodes,
          dominantColor: dominantColor,
          blendedColor: blended,
          totalConnections: totalConn,
        ),
      );
    }

    // Sort clusters by total connections so important ones render on top.
    clusters.sort((a, b) => a.totalConnections.compareTo(b.totalConnections));

    final result = ClusterResult(
      clusters: clusters,
      zoomLevel: zoomLevel,
      cellSize: cellSize,
      isActive: true,
    );

    _cached = result;
    _cachedZoom = quantizedZoom;
    _cachedNodeCount = nodes.length;

    return result;
  }

  /// Invalidate the cache (e.g., when data changes).
  void invalidate() {
    _cached = null;
    _cachedZoom = -1;
    _cachedNodeCount = -1;
  }

  /// Compute a blended average color from all nodes in a cluster.
  static Color _blendColors(List<ConstellationNode> nodes) {
    if (nodes.isEmpty) return const Color(0xFF9CA3AF);
    if (nodes.length == 1) {
      final sigil =
          nodes.first.sigil ?? SigilGenerator.generate(nodes.first.nodeNum);
      return sigil.primaryColor;
    }

    double r = 0, g = 0, b = 0;
    for (final node in nodes) {
      final sigil = node.sigil ?? SigilGenerator.generate(node.nodeNum);
      final color = sigil.primaryColor;
      r += color.red;
      g += color.green;
      b += color.blue;
    }

    final count = nodes.length.toDouble();
    return Color.fromARGB(
      255,
      (r / count).round().clamp(0, 255),
      (g / count).round().clamp(0, 255),
      (b / count).round().clamp(0, 255),
    );
  }

  /// Compute the interpolation factor for cluster-to-node transition.
  ///
  /// Returns 0.0 when fully clustered, 1.0 when fully expanded to nodes.
  /// Used for smooth animated transitions as zoom crosses the threshold.
  static double expansionFactor(double zoomLevel) {
    if (zoomLevel >= clusterZoomThreshold) return 1.0;
    if (zoomLevel <= minZoom) return 0.0;

    // Ease-in-out near the threshold for a smooth visual transition.
    final t = ((zoomLevel - minZoom) / (clusterZoomThreshold - minZoom)).clamp(
      0.0,
      1.0,
    );
    // Smooth-step for pleasant visual interpolation.
    return t * t * (3.0 - 2.0 * t);
  }
}
