// SPDX-License-Identifier: GPL-3.0-or-later

// Mesh 3D Figure Builders
//
// All 3D geometry construction for the mesh visualization lives here.
// This includes position calculators, shape primitives (octahedra, bars,
// energy rings, holograms), and the four view-mode figure builders
// (topology, signal strength, activity, terrain).
//
// Extracted from mesh_3d_screen.dart for maintainability. Every method
// is stateless — it takes data in and returns Model3D lists out.

import 'dart:math' as math;

import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/presence_providers.dart';
import 'mesh_3d_models.dart';

// ---------------------------------------------------------------------------
// Mesh3DFigureBuilder — pure-function figure construction
// ---------------------------------------------------------------------------

/// Builds all 3D figures for the mesh visualization.
///
/// This class is intentionally stateless. Callers pass in the current node
/// map, presence map, view settings, and receive back a list of [Model3D]
/// primitives ready to hand to [DiTreDi].
class Mesh3DFigureBuilder {
  const Mesh3DFigureBuilder._();

  // =========================================================================
  // Public API — one method per view mode, plus the dispatcher
  // =========================================================================

  /// Build figures for the given [mode], dispatching to the correct builder.
  static List<Model3D<Model3D>> buildFigures({
    required Mesh3DViewMode mode,
    required Map<int, MeshNode> nodes,
    required int? myNodeNum,
    required Map<int, NodePresence> presenceMap,
    required bool showConnections,
    required double connectionQualityThreshold,
    required Color surfaceColor,
  }) {
    switch (mode) {
      case Mesh3DViewMode.topology:
        return _buildTopologyFigures(
          nodes: nodes,
          myNodeNum: myNodeNum,
          presenceMap: presenceMap,
          showConnections: showConnections,
          connectionQualityThreshold: connectionQualityThreshold,
        );
      case Mesh3DViewMode.signalStrength:
        return _buildSignalStrengthFigures(
          nodes: nodes,
          myNodeNum: myNodeNum,
          presenceMap: presenceMap,
          surfaceColor: surfaceColor,
        );
      case Mesh3DViewMode.activity:
        return _buildActivityFigures(
          nodes: nodes,
          presenceMap: presenceMap,
          surfaceColor: surfaceColor,
        );
      case Mesh3DViewMode.terrain:
        return _buildTerrainFigures(
          nodes: nodes,
          myNodeNum: myNodeNum,
          presenceMap: presenceMap,
          surfaceColor: surfaceColor,
        );
    }
  }

  /// Calculate node positions for tap-hit-testing. Returns a map of
  /// nodeNum -> 3D position for the given view mode.
  static Map<int, vector.Vector3> calculatePositions({
    required Mesh3DViewMode mode,
    required Map<int, MeshNode> nodes,
    required int? myNodeNum,
    required Map<int, NodePresence> presenceMap,
  }) {
    switch (mode) {
      case Mesh3DViewMode.topology:
        return calculateRadialPositions(
          nodes: nodes,
          myNodeNum: myNodeNum,
          presenceMap: presenceMap,
        );
      case Mesh3DViewMode.terrain:
        return calculateGpsPositions(nodes);
      case Mesh3DViewMode.signalStrength:
      case Mesh3DViewMode.activity:
        return _calculateGridPositions(nodes);
    }
  }

  // =========================================================================
  // Position calculators
  // =========================================================================

  /// GPS-based positions centred around the node centroid.
  /// Only returns entries for nodes with valid GPS coordinates.
  static Map<int, vector.Vector3> calculateGpsPositions(
    Map<int, MeshNode> nodes,
  ) {
    final nodePositions = <int, vector.Vector3>{};

    double sumLat = 0, sumLon = 0, sumAlt = 0;
    int gpsCount = 0;

    for (final node in nodes.values) {
      if (node.latitude != null &&
          node.longitude != null &&
          node.latitude != 0 &&
          node.longitude != 0) {
        sumLat += node.latitude!;
        sumLon += node.longitude!;
        sumAlt += (node.altitude ?? 0).toDouble();
        gpsCount++;
      }
    }

    if (gpsCount == 0) return nodePositions;

    final centerLat = sumLat / gpsCount;
    final centerLon = sumLon / gpsCount;
    final centerAlt = sumAlt / gpsCount;

    for (final node in nodes.values) {
      if (node.latitude == null ||
          node.longitude == null ||
          node.latitude == 0 ||
          node.longitude == 0) {
        continue;
      }

      final lat = node.latitude! - centerLat;
      final lon = node.longitude! - centerLon;
      final alt = ((node.altitude ?? 0) - centerAlt) / 50;

      var position = vector.Vector3(
        lon * 1000,
        alt.clamp(-3.0, 3.0),
        lat * 1000,
      );

      if (position.length > 5) {
        position = position.normalized() * 5;
      }

      nodePositions[node.nodeNum] = position;
    }

    return nodePositions;
  }

  /// Radial layout centred on [myNodeNum].
  ///
  /// Each other node is placed at a distance proportional to its signal
  /// quality (good signal = close to centre, poor/unknown = far out).
  /// Nodes are spread evenly around the circle, grouped by presence so
  /// active nodes cluster together and stale nodes are pushed outward.
  static Map<int, vector.Vector3> calculateRadialPositions({
    required Map<int, MeshNode> nodes,
    required int? myNodeNum,
    required Map<int, NodePresence> presenceMap,
  }) {
    final positions = <int, vector.Vector3>{};
    if (nodes.isEmpty) return positions;

    // My node at the origin, slightly elevated.
    if (myNodeNum != null && nodes.containsKey(myNodeNum)) {
      positions[myNodeNum] = vector.Vector3(0, 0.3, 0);
    }

    // Partition other nodes by presence for grouping.
    final active = <MeshNode>[];
    final fading = <MeshNode>[];
    final stale = <MeshNode>[];

    for (final node in nodes.values) {
      if (node.nodeNum == myNodeNum) continue;
      final presence = presenceConfidenceFor(presenceMap, node);
      switch (presence) {
        case PresenceConfidence.active:
          active.add(node);
        case PresenceConfidence.fading:
          fading.add(node);
        case PresenceConfidence.stale:
        case PresenceConfidence.unknown:
          stale.add(node);
      }
    }

    int snrSort(MeshNode a, MeshNode b) =>
        (b.snr ?? -999).compareTo(a.snr ?? -999);
    active.sort(snrSort);
    fading.sort(snrSort);
    stale.sort(snrSort);

    final ordered = [...active, ...fading, ...stale];
    final total = ordered.length;
    if (total == 0) return positions;

    for (int i = 0; i < total; i++) {
      final node = ordered[i];

      final angle = (i / total) * 2 * math.pi;

      // Radius: map SNR to distance.
      //   SNR 10 dB (excellent) -> radius ~1.2
      //   SNR 0 dB  (ok)        -> radius ~2.5
      //   SNR -20 or unknown    -> radius ~4.0
      final snr = (node.snr ?? -20).clamp(-20, 10).toDouble();
      final quality = (snr + 20) / 30; // 0..1 (0 = worst, 1 = best)
      final radius = 4.0 - quality * 2.8; // 4.0..1.2

      positions[node.nodeNum] = vector.Vector3(
        radius * math.cos(angle),
        0,
        radius * math.sin(angle),
      );
    }

    return positions;
  }

  /// Simple grid layout for bar-chart views.
  static Map<int, vector.Vector3> _calculateGridPositions(
    Map<int, MeshNode> nodes,
  ) {
    final list = nodes.values.toList();
    final cols = math.sqrt(list.length).ceil();
    const spacing = 1.2;
    final offset = (cols - 1) * spacing / 2;
    final map = <int, vector.Vector3>{};
    for (int idx = 0; idx < list.length; idx++) {
      final row = idx ~/ cols;
      final col = idx % cols;
      map[list[idx].nodeNum] = vector.Vector3(
        col * spacing - offset,
        0,
        row * spacing - offset,
      );
    }
    return map;
  }

  // =========================================================================
  // Shape primitives
  // =========================================================================

  /// Build an octahedron (diamond / crystal) shape.
  static List<Model3D<Model3D>> buildOctahedron(
    vector.Vector3 position,
    double size,
    Color color, {
    double alpha = 1.0,
  }) {
    final figures = <Model3D<Model3D>>[];
    final halfSize = size / 2;
    final effectiveColor = color.withValues(alpha: alpha);

    final top = position + vector.Vector3(0, halfSize, 0);
    final bottom = position + vector.Vector3(0, -halfSize, 0);
    final front = position + vector.Vector3(0, 0, halfSize);
    final back = position + vector.Vector3(0, 0, -halfSize);
    final left = position + vector.Vector3(-halfSize, 0, 0);
    final right = position + vector.Vector3(halfSize, 0, 0);

    // Top pyramid (4 faces)
    figures.add(Face3D.fromVertices(top, front, right, color: effectiveColor));
    figures.add(Face3D.fromVertices(top, right, back, color: effectiveColor));
    figures.add(Face3D.fromVertices(top, back, left, color: effectiveColor));
    figures.add(Face3D.fromVertices(top, left, front, color: effectiveColor));

    // Bottom pyramid (4 faces)
    figures.add(
      Face3D.fromVertices(bottom, right, front, color: effectiveColor),
    );
    figures.add(
      Face3D.fromVertices(bottom, back, right, color: effectiveColor),
    );
    figures.add(Face3D.fromVertices(bottom, left, back, color: effectiveColor));
    figures.add(
      Face3D.fromVertices(bottom, front, left, color: effectiveColor),
    );

    return figures;
  }

  /// Build glowing energy rings around a node.
  static List<Model3D<Model3D>> buildEnergyRings(
    vector.Vector3 position,
    double radius,
    Color color, {
    int ringCount = 2,
    int segments = 16,
    double alpha = 0.6,
  }) {
    final figures = <Model3D<Model3D>>[];

    for (int ring = 0; ring < ringCount; ring++) {
      final ringRadius = radius * (0.8 + ring * 0.4);
      final ringAlpha = alpha * (1.0 - ring * 0.2);
      final yOffset = ring * 0.05;

      for (int i = 0; i < segments; i++) {
        final angle1 = (i / segments) * 2 * math.pi;
        final angle2 = ((i + 1) / segments) * 2 * math.pi;

        figures.add(
          Line3D(
            position +
                vector.Vector3(
                  ringRadius * math.cos(angle1),
                  yOffset,
                  ringRadius * math.sin(angle1),
                ),
            position +
                vector.Vector3(
                  ringRadius * math.cos(angle2),
                  yOffset,
                  ringRadius * math.sin(angle2),
                ),
            color: color.withValues(alpha: ringAlpha),
            width: 2,
          ),
        );
      }
    }

    return figures;
  }

  /// Build a holographic wireframe node.
  static List<Model3D<Model3D>> buildHologramNode(
    vector.Vector3 position,
    double size,
    Color color, {
    double alpha = 0.8,
  }) {
    final figures = <Model3D<Model3D>>[];
    final halfSize = size / 2;

    final top = position + vector.Vector3(0, halfSize, 0);
    final bottom = position + vector.Vector3(0, -halfSize, 0);
    final front = position + vector.Vector3(0, 0, halfSize);
    final back = position + vector.Vector3(0, 0, -halfSize);
    final left = position + vector.Vector3(-halfSize, 0, 0);
    final right = position + vector.Vector3(halfSize, 0, 0);

    final wireColor = color.withValues(alpha: alpha);

    // Top pyramid edges
    figures.add(Line3D(top, front, color: wireColor, width: 2));
    figures.add(Line3D(top, right, color: wireColor, width: 2));
    figures.add(Line3D(top, back, color: wireColor, width: 2));
    figures.add(Line3D(top, left, color: wireColor, width: 2));

    // Bottom pyramid edges
    figures.add(Line3D(bottom, front, color: wireColor, width: 2));
    figures.add(Line3D(bottom, right, color: wireColor, width: 2));
    figures.add(Line3D(bottom, back, color: wireColor, width: 2));
    figures.add(Line3D(bottom, left, color: wireColor, width: 2));

    // Equator edges
    figures.add(Line3D(front, right, color: wireColor, width: 2));
    figures.add(Line3D(right, back, color: wireColor, width: 2));
    figures.add(Line3D(back, left, color: wireColor, width: 2));
    figures.add(Line3D(left, front, color: wireColor, width: 2));

    return figures;
  }

  /// Build a complete sci-fi node with octahedron core + energy rings.
  static List<Model3D<Model3D>> buildSciFiNode(
    vector.Vector3 position,
    double size,
    Color color, {
    bool isHighlighted = false,
    bool showRings = true,
  }) {
    final figures = <Model3D<Model3D>>[];

    // Core octahedron (solid)
    figures.addAll(buildOctahedron(position, size, color));

    // Energy rings for highlighted or primary nodes
    if (showRings) {
      figures.addAll(
        buildEnergyRings(
          position,
          size * (isHighlighted ? 1.2 : 0.9),
          color,
          ringCount: isHighlighted ? 3 : 2,
          alpha: isHighlighted ? 0.7 : 0.4,
        ),
      );
    }

    // Hologram wireframe overlay for highlighted nodes
    if (isHighlighted) {
      figures.addAll(
        buildHologramNode(position, size * 1.3, Colors.white, alpha: 0.3),
      );
    }

    return figures;
  }

  /// Build a data bar with glowing top cap (for chart views).
  static List<Model3D<Model3D>> buildGlowingBar(
    vector.Vector3 basePosition,
    double width,
    double height,
    Color color, {
    bool showCap = true,
    double alpha = 1.0,
  }) {
    final figures = <Model3D<Model3D>>[];

    // Main bar line
    figures.add(
      Line3D(
        basePosition,
        basePosition + vector.Vector3(0, height, 0),
        color: color.withValues(alpha: alpha * 0.8),
        width: width * 10,
      ),
    );

    // Glowing cap at top
    if (showCap) {
      final capPosition = basePosition + vector.Vector3(0, height, 0);
      figures.addAll(
        buildOctahedron(capPosition, width * 1.5, color, alpha: alpha),
      );
    }

    return figures;
  }

  /// Build the default empty grid plane.
  static List<Model3D<Model3D>> buildGridPlane() {
    final figures = <Model3D<Model3D>>[];
    const gridSize = 5;
    const gridStep = 1.0;

    for (int i = -gridSize; i <= gridSize; i++) {
      final pos = i * gridStep;
      final alpha = i == 0 ? 0.3 : 0.1;

      figures.add(
        Line3D(
          vector.Vector3(-gridSize * gridStep, 0, pos),
          vector.Vector3(gridSize * gridStep, 0, pos),
          color: Colors.white.withValues(alpha: alpha),
          width: i == 0 ? 2 : 1,
        ),
      );

      figures.add(
        Line3D(
          vector.Vector3(pos, 0, -gridSize * gridStep),
          vector.Vector3(pos, 0, gridSize * gridStep),
          color: Colors.white.withValues(alpha: alpha),
          width: i == 0 ? 2 : 1,
        ),
      );
    }

    return figures;
  }

  // =========================================================================
  // Colour helpers
  // =========================================================================

  static Color getNodeColor(
    MeshNode node,
    Map<int, NodePresence> presenceMap,
    Color textSecondary,
    Color textTertiary,
  ) {
    final presence = presenceConfidenceFor(presenceMap, node);
    return switch (presence) {
      PresenceConfidence.active => AppTheme.successGreen,
      PresenceConfidence.fading => AppTheme.warningYellow,
      PresenceConfidence.stale => textSecondary,
      PresenceConfidence.unknown => textTertiary,
    };
  }

  static Color getRssiColor(double rssi) {
    if (rssi >= -60) return AppTheme.successGreen;
    if (rssi >= -75) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  static Color getSnrColor(double snr) {
    if (snr >= 5) return AccentColors.cyan;
    if (snr >= 0) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  // =========================================================================
  // View-mode figure builders (private)
  // =========================================================================

  /// Honest star-topology layout.
  ///
  /// We only know the relationship between **our** node and every other node
  /// (that is how we learned about them). So we render a radial layout with
  /// my node at the centre and each other node at a distance proportional to
  /// its signal quality. Connection lines run **only** from the centre to
  /// each peer — no fabricated inter-node links.
  static List<Model3D<Model3D>> _buildTopologyFigures({
    required Map<int, MeshNode> nodes,
    required int? myNodeNum,
    required Map<int, NodePresence> presenceMap,
    required bool showConnections,
    required double connectionQualityThreshold,
  }) {
    final figures = <Model3D<Model3D>>[];

    if (nodes.isEmpty) {
      figures.addAll(buildGridPlane());
      return figures;
    }

    final positions = calculateRadialPositions(
      nodes: nodes,
      myNodeNum: myNodeNum,
      presenceMap: presenceMap,
    );
    final myPos = myNodeNum != null ? positions[myNodeNum] : null;

    // Concentric reference rings so the user can gauge distance.
    const ringRadii = [1.5, 2.8, 4.0];
    for (int r = 0; r < ringRadii.length; r++) {
      final radius = ringRadii[r];
      const segments = 48;
      for (int i = 0; i < segments; i++) {
        final a1 = (i / segments) * 2 * math.pi;
        final a2 = ((i + 1) / segments) * 2 * math.pi;
        figures.add(
          Line3D(
            vector.Vector3(radius * math.cos(a1), 0, radius * math.sin(a1)),
            vector.Vector3(radius * math.cos(a2), 0, radius * math.sin(a2)),
            color: Colors.white.withValues(alpha: r == 0 ? 0.12 : 0.07),
            width: 1,
          ),
        );
      }
      // Small label tick at +X axis for each ring.
      figures.add(
        Point3D(
          vector.Vector3(radius, 0, 0),
          color: Colors.white.withValues(alpha: 0.15),
          width: 3,
        ),
      );
    }

    // Subtle cross-hair through origin.
    figures.add(
      Line3D(
        vector.Vector3(-4.5, 0, 0),
        vector.Vector3(4.5, 0, 0),
        color: Colors.white.withValues(alpha: 0.06),
        width: 1,
      ),
    );
    figures.add(
      Line3D(
        vector.Vector3(0, 0, -4.5),
        vector.Vector3(0, 0, 4.5),
        color: Colors.white.withValues(alpha: 0.06),
        width: 1,
      ),
    );

    // Draw nodes + connection lines from my node.
    for (final node in nodes.values) {
      final pos = positions[node.nodeNum];
      if (pos == null) continue;

      final isMyNode = node.nodeNum == myNodeNum;
      final presence = presenceConfidenceFor(presenceMap, node);
      final nodeColor = isMyNode
          ? AppTheme.primaryBlue
          : _nodeColorFromPresence(presence);

      // Node shape.
      figures.addAll(
        buildSciFiNode(
          pos,
          isMyNode ? 0.45 : 0.28,
          nodeColor,
          isHighlighted: isMyNode,
          showRings: isMyNode || presence.isActive,
        ),
      );

      // Connection line from my node to this node.
      if (!isMyNode && showConnections && myPos != null) {
        final snr = (node.snr ?? -20).clamp(-20, 10).toDouble();
        final quality = (snr + 20) / 30;

        if (quality >= connectionQualityThreshold) {
          double recencyAlpha = 0.6;
          if (node.lastHeard != null) {
            final minutesAgo = DateTime.now()
                .difference(node.lastHeard!)
                .inMinutes;
            recencyAlpha = minutesAgo < 5
                ? 0.7
                : minutesAgo < 30
                ? 0.5
                : 0.25;
          } else {
            recencyAlpha = 0.15;
          }

          figures.add(
            Line3D(
              myPos,
              pos,
              color: Color.lerp(
                AppTheme.errorRed.withValues(alpha: recencyAlpha),
                AppTheme.successGreen.withValues(alpha: recencyAlpha),
                quality,
              )!,
              width: 1 + quality * 1.5,
            ),
          );
        }
      }
    }

    return figures;
  }

  /// Signal strength bar chart — RSSI (left) and SNR (right) per node,
  /// sorted by signal quality so the best nodes are at the front.
  static List<Model3D<Model3D>> _buildSignalStrengthFigures({
    required Map<int, MeshNode> nodes,
    required int? myNodeNum,
    required Map<int, NodePresence> presenceMap,
    required Color surfaceColor,
  }) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;

    if (nodeCount == 0) {
      figures.addAll(buildGridPlane());
      return figures;
    }

    // Sort by SNR descending so best-signal nodes are at front.
    nodeList.sort((a, b) => (b.snr ?? -999).compareTo(a.snr ?? -999));

    final gridCols = math.sqrt(nodeCount).ceil();
    const spacing = 1.2;
    final gridOffset = (gridCols - 1) * spacing / 2;

    int index = 0;
    for (final node in nodeList) {
      final row = index ~/ gridCols;
      final col = index % gridCols;
      final x = col * spacing - gridOffset;
      final z = row * spacing - gridOffset;

      // RSSI bar (left).
      final rssi = (node.rssi ?? -120).clamp(-120, -30).toDouble();
      final rssiNormalized = (rssi + 120) / 90;
      final rssiHeight = 0.2 + rssiNormalized * 2.5;
      final rssiColor = getRssiColor(rssi);

      figures.addAll(
        buildGlowingBar(
          vector.Vector3(x - 0.2, 0, z),
          0.15,
          rssiHeight,
          rssiColor,
        ),
      );

      // SNR bar (right).
      final snr = (node.snr ?? -20).clamp(-20, 15).toDouble();
      final snrNormalized = (snr + 20) / 35;
      final snrHeight = 0.2 + snrNormalized * 2.5;
      final snrColor = getSnrColor(snr);

      figures.addAll(
        buildGlowingBar(
          vector.Vector3(x + 0.2, 0, z),
          0.15,
          snrHeight,
          snrColor,
        ),
      );

      // Node indicator at base.
      final isMyNode = node.nodeNum == myNodeNum;
      final nodeColor = isMyNode
          ? AppTheme.primaryBlue
          : _nodeColorFromPresence(presenceConfidenceFor(presenceMap, node));
      figures.addAll(
        buildOctahedron(vector.Vector3(x, 0.08, z), 0.18, nodeColor),
      );

      index++;
    }

    // Base plane.
    figures.add(
      Plane3D(
        (gridCols + 1) * spacing,
        Axis3D.y,
        false,
        vector.Vector3(0, 0, 0),
        color: surfaceColor.withValues(alpha: 0.5),
      ),
    );

    return figures;
  }

  /// Activity bar chart — nodes sorted by recency, bar height = how recently
  /// heard, colour = activity level (blue -> red).
  static List<Model3D<Model3D>> _buildActivityFigures({
    required Map<int, MeshNode> nodes,
    required Map<int, NodePresence> presenceMap,
    required Color surfaceColor,
  }) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();

    if (nodeList.isEmpty) {
      figures.addAll(buildGridPlane());
      return figures;
    }

    // Sort by activity (most recently heard first).
    final sortedNodes = List<MeshNode>.from(nodeList)
      ..sort((a, b) {
        final aHeard = a.lastHeard ?? DateTime(1970);
        final bHeard = b.lastHeard ?? DateTime(1970);
        return bHeard.compareTo(aHeard);
      });

    final gridCols = math.sqrt(sortedNodes.length).ceil();
    final gridRows = (sortedNodes.length / gridCols).ceil();
    const spacing = 0.8;
    final gridOffsetX = (gridCols - 1) * spacing / 2;
    final gridOffsetZ = (gridRows - 1) * spacing / 2;

    for (int i = 0; i < sortedNodes.length; i++) {
      final node = sortedNodes[i];
      final row = i ~/ gridCols;
      final col = i % gridCols;
      final x = col * spacing - gridOffsetX;
      final z = row * spacing - gridOffsetZ;

      double activity = 0.0;
      if (node.lastHeard != null) {
        final minutesAgo = DateTime.now().difference(node.lastHeard!).inMinutes;
        if (minutesAgo < 5) {
          activity = 1.0;
        } else if (minutesAgo < 30) {
          activity = 0.8;
        } else if (minutesAgo < 120) {
          activity = 0.6;
        } else if (minutesAgo < 1440) {
          activity = 0.3;
        } else {
          activity = 0.1;
        }
      }

      final height = activity * 2.5 + 0.1;

      final color = Color.lerp(
        Colors.blue.shade700,
        AppTheme.errorRed,
        activity,
      )!;

      figures.addAll(
        buildGlowingBar(vector.Vector3(x, 0, z), 0.2, height, color),
      );

      final nodeColor = _nodeColorFromPresence(
        presenceConfidenceFor(presenceMap, node),
      );
      figures.addAll(
        buildOctahedron(vector.Vector3(x, height + 0.15, z), 0.15, nodeColor),
      );
    }

    // Base plane.
    final planeSize = math.max(gridCols, gridRows) * spacing + 1;
    figures.add(
      Plane3D(
        planeSize,
        Axis3D.y,
        false,
        vector.Vector3(0, 0, 0),
        color: surfaceColor.withValues(alpha: 0.5),
      ),
    );

    return figures;
  }

  /// Terrain view — GPS nodes on an interpolated terrain mesh with altitude.
  static List<Model3D<Model3D>> _buildTerrainFigures({
    required Map<int, MeshNode> nodes,
    required int? myNodeNum,
    required Map<int, NodePresence> presenceMap,
    required Color surfaceColor,
  }) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();

    if (nodeList.isEmpty) {
      figures.addAll(buildGridPlane());
      return figures;
    }

    // Collect nodes with valid GPS data.
    final gpsNodes = nodeList
        .where(
          (n) =>
              n.latitude != null &&
              n.longitude != null &&
              n.latitude != 0 &&
              n.longitude != 0,
        )
        .toList();

    if (gpsNodes.isEmpty) {
      // Fall back to grid plane; show nodes in a circle.
      figures.addAll(buildGridPlane());
      int index = 0;
      for (final node in nodeList) {
        final angle = (index / nodeList.length) * 2 * math.pi;
        const radius = 3.0;
        final position = vector.Vector3(
          radius * math.cos(angle),
          0.3,
          radius * math.sin(angle),
        );
        final isMyNode = node.nodeNum == myNodeNum;
        final nodeColor = isMyNode
            ? AppTheme.primaryBlue
            : _nodeColorFromPresence(presenceConfidenceFor(presenceMap, node));
        figures.addAll(
          buildSciFiNode(
            position,
            0.25,
            nodeColor,
            isHighlighted: isMyNode,
            showRings: true,
          ),
        );
        index++;
      }
      return figures;
    }

    // Calculate bounds from real GPS data.
    double minLat = double.infinity, maxLat = -double.infinity;
    double minLon = double.infinity, maxLon = -double.infinity;
    double minAlt = double.infinity, maxAlt = -double.infinity;

    for (final node in gpsNodes) {
      minLat = math.min(minLat, node.latitude!);
      maxLat = math.max(maxLat, node.latitude!);
      minLon = math.min(minLon, node.longitude!);
      maxLon = math.max(maxLon, node.longitude!);
      final alt = (node.altitude ?? 0).toDouble();
      minAlt = math.min(minAlt, alt);
      maxAlt = math.max(maxAlt, alt);
    }

    // Padding.
    final latRange = maxLat - minLat;
    final lonRange = maxLon - minLon;
    final altRange = maxAlt - minAlt;
    final padding = math.max(latRange, lonRange) * 0.1;
    minLat -= padding;
    maxLat += padding;
    minLon -= padding;
    maxLon += padding;

    // Scale factors to fit in 3D space (-5 to 5 range).
    const worldSize = 8.0;
    final latScale = latRange > 0 ? worldSize / (maxLat - minLat) : 1.0;
    final lonScale = lonRange > 0 ? worldSize / (maxLon - minLon) : 1.0;
    final altScale = altRange > 50 ? 3.0 / altRange : 0.01;

    vector.Vector3 gpsTo3D(double lat, double lon, double alt) {
      final x = (lon - (minLon + maxLon) / 2) * lonScale;
      final z = (lat - (minLat + maxLat) / 2) * latScale;
      final y = (alt - minAlt) * altScale;
      return vector.Vector3(x, y, z);
    }

    // Build terrain grid interpolated from node altitudes.
    const gridSize = 12;
    final heights = List.generate(
      gridSize + 1,
      (_) => List.filled(gridSize + 1, 0.0),
    );
    final weights = List.generate(
      gridSize + 1,
      (_) => List.filled(gridSize + 1, 0.0),
    );

    final gridMinX = (minLon - (minLon + maxLon) / 2) * lonScale;
    final gridMaxX = (maxLon - (minLon + maxLon) / 2) * lonScale;
    final gridMinZ = (minLat - (minLat + maxLat) / 2) * latScale;
    final gridMaxZ = (maxLat - (minLat + maxLat) / 2) * latScale;
    final cellWidth = (gridMaxX - gridMinX) / gridSize;
    final cellDepth = (gridMaxZ - gridMinZ) / gridSize;

    // Inverse distance weighting for height interpolation.
    for (final node in gpsNodes) {
      final pos = gpsTo3D(
        node.latitude!,
        node.longitude!,
        (node.altitude ?? 0).toDouble(),
      );

      for (int gx = 0; gx <= gridSize; gx++) {
        for (int gz = 0; gz <= gridSize; gz++) {
          final gridX = gridMinX + gx * cellWidth;
          final gridZ = gridMinZ + gz * cellDepth;
          final dx = pos.x - gridX;
          final dz = pos.z - gridZ;
          final dist = math.sqrt(dx * dx + dz * dz);
          final weight = 1.0 / (dist * dist + 0.1);
          heights[gx][gz] += pos.y * weight;
          weights[gx][gz] += weight;
        }
      }
    }

    // Normalize.
    for (int gx = 0; gx <= gridSize; gx++) {
      for (int gz = 0; gz <= gridSize; gz++) {
        if (weights[gx][gz] > 0) {
          heights[gx][gz] /= weights[gx][gz];
        }
      }
    }

    // Draw terrain mesh.
    for (int gx = 0; gx < gridSize; gx++) {
      for (int gz = 0; gz < gridSize; gz++) {
        final x0 = gridMinX + gx * cellWidth;
        final z0 = gridMinZ + gz * cellDepth;
        final x1 = gridMinX + (gx + 1) * cellWidth;
        final z1 = gridMinZ + (gz + 1) * cellDepth;

        final h00 = heights[gx][gz];
        final h10 = heights[gx + 1][gz];
        final h01 = heights[gx][gz + 1];
        final h11 = heights[gx + 1][gz + 1];

        final avgHeight = (h00 + h10 + h01 + h11) / 4;
        final heightNorm = altRange > 0
            ? ((avgHeight / altScale) / altRange).clamp(0.0, 1.0)
            : 0.5;
        final terrainColor = Color.lerp(
          Colors.green.shade800,
          Colors.brown.shade400,
          heightNorm,
        )!;

        figures.add(
          Line3D(
            vector.Vector3(x0, h00, z0),
            vector.Vector3(x1, h10, z0),
            color: terrainColor,
            width: 1,
          ),
        );
        figures.add(
          Line3D(
            vector.Vector3(x0, h00, z0),
            vector.Vector3(x0, h01, z1),
            color: terrainColor,
            width: 1,
          ),
        );
        // Diagonal for mesh effect.
        figures.add(
          Line3D(
            vector.Vector3(x0, h00, z0),
            vector.Vector3(x1, h11, z1),
            color: terrainColor.withValues(alpha: 0.5),
            width: 1,
          ),
        );
      }
    }

    // Add nodes at their actual GPS positions and altitudes.
    for (final node in nodeList) {
      final isMyNode = node.nodeNum == myNodeNum;

      vector.Vector3 nodePosition;
      double groundHeight = 0;

      if (node.latitude != null &&
          node.longitude != null &&
          node.latitude != 0 &&
          node.longitude != 0) {
        nodePosition = gpsTo3D(
          node.latitude!,
          node.longitude!,
          (node.altitude ?? 0).toDouble(),
        );

        // Find terrain height at node position for ground line.
        final gxFloat = (nodePosition.x - gridMinX) / cellWidth;
        final gzFloat = (nodePosition.z - gridMinZ) / cellDepth;
        final gx = gxFloat.clamp(0, gridSize - 1).toInt();
        final gz = gzFloat.clamp(0, gridSize - 1).toInt();
        groundHeight = heights[gx][gz];
      } else {
        // No GPS — place at edge.
        final index = nodeList.indexOf(node);
        final angle = (index / nodeList.length) * 2 * math.pi;
        const radius = 4.5;
        nodePosition = vector.Vector3(
          radius * math.cos(angle),
          0.3,
          radius * math.sin(angle),
        );
      }

      final nodeColor = isMyNode
          ? AppTheme.primaryBlue
          : _nodeColorFromPresence(presenceConfidenceFor(presenceMap, node));

      // Draw node.
      figures.addAll(
        buildSciFiNode(
          nodePosition + vector.Vector3(0, 0.2, 0),
          isMyNode ? 0.35 : 0.25,
          nodeColor,
          isHighlighted: isMyNode,
          showRings: true,
        ),
      );

      // Vertical line from ground to node (shows elevation).
      if (node.altitude != null && node.altitude! > 0) {
        figures.add(
          Line3D(
            vector.Vector3(nodePosition.x, groundHeight, nodePosition.z),
            nodePosition + vector.Vector3(0, 0.1, 0),
            color: Colors.white.withValues(alpha: 0.4),
            width: 1,
          ),
        );
      }
    }

    // Subtle base plane.
    figures.add(
      Plane3D(
        worldSize + 2,
        Axis3D.y,
        false,
        vector.Vector3(0, -0.01, 0),
        color: surfaceColor.withValues(alpha: 0.2),
      ),
    );

    return figures;
  }

  // =========================================================================
  // Internal helpers
  // =========================================================================

  static Color _nodeColorFromPresence(PresenceConfidence presence) {
    return switch (presence) {
      PresenceConfidence.active => AppTheme.successGreen,
      PresenceConfidence.fading => AppTheme.warningYellow,
      PresenceConfidence.stale => Colors.grey.shade500,
      PresenceConfidence.unknown => Colors.grey.shade700,
    };
  }
}
