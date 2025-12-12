import 'dart:math' as math;
import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../navigation/main_shell.dart';
import '../presence/presence_screen.dart';

/// View modes for the 3D mesh visualization
enum Mesh3DViewMode {
  topology,
  signalPropagation,
  traceroute,
  activityHeatmap,
  terrain,
}

extension Mesh3DViewModeExt on Mesh3DViewMode {
  String get label {
    switch (this) {
      case Mesh3DViewMode.topology:
        return 'Network Topology';
      case Mesh3DViewMode.signalPropagation:
        return 'Signal Propagation';
      case Mesh3DViewMode.traceroute:
        return 'Traceroute';
      case Mesh3DViewMode.activityHeatmap:
        return 'Activity Heatmap';
      case Mesh3DViewMode.terrain:
        return 'Terrain View';
    }
  }

  String get description {
    switch (this) {
      case Mesh3DViewMode.topology:
        return 'View nodes and their connections in 3D space';
      case Mesh3DViewMode.signalPropagation:
        return 'Visualize signal strength and radio range';
      case Mesh3DViewMode.traceroute:
        return 'See message paths through the mesh';
      case Mesh3DViewMode.activityHeatmap:
        return '3D activity chart over time';
      case Mesh3DViewMode.terrain:
        return 'Network overlay on terrain';
    }
  }

  IconData get icon {
    switch (this) {
      case Mesh3DViewMode.topology:
        return Icons.hub;
      case Mesh3DViewMode.signalPropagation:
        return Icons.wifi_tethering;
      case Mesh3DViewMode.traceroute:
        return Icons.route;
      case Mesh3DViewMode.activityHeatmap:
        return Icons.bar_chart;
      case Mesh3DViewMode.terrain:
        return Icons.terrain;
    }
  }
}

/// 3D Mesh Visualization Screen
class Mesh3DScreen extends ConsumerStatefulWidget {
  const Mesh3DScreen({super.key});

  @override
  ConsumerState<Mesh3DScreen> createState() => _Mesh3DScreenState();
}

class _Mesh3DScreenState extends ConsumerState<Mesh3DScreen>
    with SingleTickerProviderStateMixin {
  late DiTreDiController _controller;
  Mesh3DViewMode _currentMode = Mesh3DViewMode.topology;
  bool _showLabels = true;
  bool _autoRotate = false;
  late AnimationController _rotationController;
  int? _selectedNodeNum;

  @override
  void initState() {
    super.initState();
    _controller = DiTreDiController(
      rotationX: -30,
      rotationY: 30,
      light: vector.Vector3(1, 1, 1),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..addListener(_onRotate);
  }

  void _onRotate() {
    if (_autoRotate) {
      _controller.update(rotationY: _controller.rotationY + 0.5);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  void _toggleAutoRotate() {
    setState(() {
      _autoRotate = !_autoRotate;
      if (_autoRotate) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: Text(
          _currentMode.label,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showLabels ? Icons.label : Icons.label_off,
              color: _showLabels ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Toggle Labels',
            onPressed: () => setState(() => _showLabels = !_showLabels),
          ),
          IconButton(
            icon: Icon(
              Icons.rotate_right,
              color: _autoRotate ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Auto Rotate',
            onPressed: _toggleAutoRotate,
          ),
          IconButton(
            icon: const Icon(Icons.view_carousel),
            tooltip: 'Change View',
            onPressed: () => _showViewSelector(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // View mode chips
          _buildViewModeChips(theme),

          // 3D View
          Expanded(
            child: Stack(
              children: [
                // 3D Visualization
                DiTreDiDraggable(
                  controller: _controller,
                  child: DiTreDi(
                    figures: _buildFigures(nodes, myNodeNum),
                    controller: _controller,
                    config: const DiTreDiConfig(
                      supportZIndex: true,
                      defaultPointWidth: 8,
                      defaultLineWidth: 2,
                    ),
                  ),
                ),

                // Legend
                Positioned(left: 16, bottom: 16, child: _buildLegend(theme)),

                // Node info card
                if (_selectedNodeNum != null)
                  Positioned(
                    right: 16,
                    top: 16,
                    child: _buildNodeInfoCard(theme, nodes[_selectedNodeNum]),
                  ),

                // Mode description
                Positioned(
                  left: 16,
                  top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentMode.icon,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentMode.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Controls hint
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildControlHint(Icons.pan_tool, 'Drag to rotate'),
                        const SizedBox(height: 4),
                        _buildControlHint(Icons.pinch, 'Pinch to zoom'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeChips(ThemeData theme) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: Mesh3DViewMode.values.map((mode) {
          final isSelected = mode == _currentMode;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              showCheckmark: false,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Text(mode.label),
                ],
              ),
              labelStyle: TextStyle(
                color: isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: theme.colorScheme.surface,
              selectedColor: theme.colorScheme.primary,
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withValues(alpha: 0.2),
              ),
              onSelected: (_) {
                HapticFeedback.selectionClick();
                setState(() => _currentMode = mode);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Model3D<Model3D>> _buildFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    switch (_currentMode) {
      case Mesh3DViewMode.topology:
        return _buildTopologyFigures(nodes, myNodeNum);
      case Mesh3DViewMode.signalPropagation:
        return _buildSignalPropagationFigures(nodes, myNodeNum);
      case Mesh3DViewMode.traceroute:
        return _buildTracerouteFigures(nodes, myNodeNum);
      case Mesh3DViewMode.activityHeatmap:
        return _buildActivityHeatmapFigures(nodes);
      case Mesh3DViewMode.terrain:
        return _buildTerrainFigures(nodes, myNodeNum);
    }
  }

  /// Build 3D network topology - nodes as cubes, connections as lines
  List<Model3D<Model3D>> _buildTopologyFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodePositions = <int, vector.Vector3>{};

    // Calculate positions for nodes
    int index = 0;
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;

    for (final node in nodeList) {
      vector.Vector3 position;

      if (node.latitude != null &&
          node.longitude != null &&
          node.latitude != 0 &&
          node.longitude != 0) {
        // Use actual GPS position (normalized to fit view)
        final lat = node.latitude!;
        final lon = node.longitude!;
        final alt = (node.altitude ?? 0) / 100;

        // Center around average position
        position = vector.Vector3(
          (lon - 0) * 10, // Scale longitude
          alt.clamp(-5.0, 5.0).toDouble(), // Height based on altitude
          (lat - 0) * 10, // Scale latitude
        );
      } else {
        // Arrange in a circle if no GPS
        final angle = (index / nodeCount) * 2 * math.pi;
        const radius = 3.0;
        position = vector.Vector3(
          radius * math.cos(angle),
          0,
          radius * math.sin(angle),
        );
      }

      nodePositions[node.nodeNum] = position;

      // Determine node color based on presence status
      final status = _getPresenceStatus(node);
      Color nodeColor;
      switch (status) {
        case PresenceStatus.active:
          nodeColor = AppTheme.successGreen;
        case PresenceStatus.idle:
          nodeColor = AppTheme.warningYellow;
        case PresenceStatus.offline:
          nodeColor = AppTheme.textTertiary;
      }

      // Highlight my node
      if (node.nodeNum == myNodeNum) {
        nodeColor = AppTheme.primaryBlue;
      }

      // Add node as a cube
      figures.add(Cube3D(0.3, position, color: nodeColor));

      index++;
    }

    // Add connections between nodes that have heard each other
    for (final node in nodeList) {
      final nodePos = nodePositions[node.nodeNum];
      if (nodePos == null) continue;

      // Connect to nodes with SNR data (they've heard each other)
      if (node.snr != null && node.snr != 0) {
        // Find nearest neighbors and draw connections
        for (final otherNode in nodeList) {
          if (otherNode.nodeNum == node.nodeNum) continue;

          final otherPos = nodePositions[otherNode.nodeNum];
          if (otherPos == null) continue;

          // Only draw connection if within reasonable range
          final distance = (nodePos - otherPos).length;
          if (distance < 5) {
            // Calculate line color based on signal quality
            final snr = (node.snr ?? 0).clamp(-20, 10).toDouble();
            final quality = (snr + 20) / 30; // 0 to 1

            figures.add(
              Line3D(
                nodePos,
                otherPos,
                color: Color.lerp(
                  Colors.red.withValues(alpha: 0.5),
                  Colors.green.withValues(alpha: 0.5),
                  quality,
                )!,
                width: 1 + quality * 2,
              ),
            );
          }
        }
      }
    }

    // Add a reference grid
    figures.addAll(_buildGridPlane());

    return figures;
  }

  /// Build signal propagation visualization with spheres showing range
  List<Model3D<Model3D>> _buildSignalPropagationFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;

    int index = 0;
    for (final node in nodeList) {
      // Calculate position
      final angle = (index / nodeCount) * 2 * math.pi;
      const radius = 3.0;
      final position = vector.Vector3(
        radius * math.cos(angle),
        0,
        radius * math.sin(angle),
      );

      // Determine signal range based on device role/power
      const signalRadius = 1.5;

      // Create concentric circles to simulate range sphere
      final isMyNode = node.nodeNum == myNodeNum;
      final baseColor = isMyNode
          ? AppTheme.primaryBlue
          : AppTheme.primaryPurple;

      // Add range rings (simulated sphere cross-section)
      for (int ring = 1; ring <= 3; ring++) {
        final ringRadius = signalRadius * ring / 3;
        const segments = 24;

        for (int i = 0; i < segments; i++) {
          final a1 = (i / segments) * 2 * math.pi;
          final a2 = ((i + 1) / segments) * 2 * math.pi;

          figures.add(
            Line3D(
              position +
                  vector.Vector3(
                    ringRadius * math.cos(a1),
                    0,
                    ringRadius * math.sin(a1),
                  ),
              position +
                  vector.Vector3(
                    ringRadius * math.cos(a2),
                    0,
                    ringRadius * math.sin(a2),
                  ),
              color: baseColor.withValues(alpha: 0.3 - ring * 0.08),
              width: 2,
            ),
          );
        }
      }

      // Add the node itself
      figures.add(
        Cube3D(
          0.2,
          position,
          color: isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
        ),
      );

      // Add vertical signal cone (pointing up)
      const coneSegments = 12;
      const coneHeight = 1.0;
      const coneRadius = 0.8;

      for (int i = 0; i < coneSegments; i++) {
        final a1 = (i / coneSegments) * 2 * math.pi;
        final a2 = ((i + 1) / coneSegments) * 2 * math.pi;

        // Cone from node to peak
        figures.add(
          Line3D(
            position,
            position +
                vector.Vector3(
                  coneRadius * math.cos(a1),
                  coneHeight,
                  coneRadius * math.sin(a1),
                ),
            color: baseColor.withValues(alpha: 0.2),
            width: 1,
          ),
        );

        // Base ring
        figures.add(
          Line3D(
            position +
                vector.Vector3(
                  coneRadius * math.cos(a1),
                  coneHeight,
                  coneRadius * math.sin(a1),
                ),
            position +
                vector.Vector3(
                  coneRadius * math.cos(a2),
                  coneHeight,
                  coneRadius * math.sin(a2),
                ),
            color: baseColor.withValues(alpha: 0.3),
            width: 1,
          ),
        );
      }

      index++;
    }

    figures.addAll(_buildGridPlane());
    return figures;
  }

  /// Build traceroute visualization showing message paths
  List<Model3D<Model3D>> _buildTracerouteFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodePositions = <int, vector.Vector3>{};
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;

    // Position all nodes
    int index = 0;
    for (final node in nodeList) {
      final angle = (index / nodeCount) * 2 * math.pi;
      const radius = 3.5;
      final position = vector.Vector3(
        radius * math.cos(angle),
        (index % 3 - 1) * 0.5, // Slight vertical variation
        radius * math.sin(angle),
      );

      nodePositions[node.nodeNum] = position;

      // Draw node
      figures.add(
        Cube3D(
          node.nodeNum == myNodeNum ? 0.35 : 0.25,
          position,
          color: node.nodeNum == myNodeNum
              ? AppTheme.primaryBlue
              : _getNodeColor(node),
        ),
      );

      index++;
    }

    // Create a simulated traceroute path
    if (myNodeNum != null && nodeList.length > 1) {
      // Simulate a multi-hop path
      final pathNodes = nodeList.take(math.min(4, nodeList.length)).toList();

      for (int i = 0; i < pathNodes.length - 1; i++) {
        final fromPos = nodePositions[pathNodes[i].nodeNum];
        final toPos = nodePositions[pathNodes[i + 1].nodeNum];

        if (fromPos != null && toPos != null) {
          // Animated path line (thicker, glowing)
          figures.add(
            Line3D(fromPos, toPos, color: AccentColors.cyan, width: 4),
          );

          // Add hop number indicator
          final midpoint = (fromPos + toPos) / 2;
          figures.add(
            Point3D(
              midpoint + vector.Vector3(0, 0.3, 0),
              color: AccentColors.magenta,
              width: 10,
            ),
          );
        }
      }
    }

    // Add directional arrows along paths (simulated with points)
    figures.addAll(_buildGridPlane());
    return figures;
  }

  /// Build activity heatmap as 3D bar chart
  List<Model3D<Model3D>> _buildActivityHeatmapFigures(
    Map<int, MeshNode> nodes,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;

    // Create a grid of bars representing activity
    const gridSize = 8;
    const spacing = 0.6;
    final random = math.Random(42); // Fixed seed for consistent visualization

    for (int x = 0; x < gridSize; x++) {
      for (int z = 0; z < gridSize; z++) {
        // Generate activity height (would use real data in production)
        final nodeIndex = (x * gridSize + z) % math.max(1, nodeCount).toInt();
        final node = nodeIndex < nodeList.length ? nodeList[nodeIndex] : null;

        // Calculate activity level (0-1)
        double activity;
        if (node != null) {
          final status = _getPresenceStatus(node);
          activity = switch (status) {
            PresenceStatus.active => 0.7 + random.nextDouble() * 0.3,
            PresenceStatus.idle => 0.3 + random.nextDouble() * 0.3,
            PresenceStatus.offline => random.nextDouble() * 0.2,
          };
        } else {
          activity = random.nextDouble() * 0.3;
        }

        final height = activity * 2 + 0.1;
        final position = vector.Vector3(
          (x - gridSize / 2) * spacing,
          height / 2,
          (z - gridSize / 2) * spacing,
        );

        // Color based on activity level
        final color = Color.lerp(Colors.blue, Colors.red, activity)!;

        // Add cube on top for visibility
        figures.add(
          Cube3D(
            0.2,
            position + vector.Vector3(0, height / 2, 0),
            color: color,
          ),
        );

        // Add vertical line from base to cube
        figures.add(
          Line3D(
            vector.Vector3(position.x, 0, position.z),
            position + vector.Vector3(0, height / 2, 0),
            color: color.withValues(alpha: 0.7),
            width: 3,
          ),
        );
      }
    }

    // Add base plane
    figures.add(
      Plane3D(
        gridSize * spacing,
        Axis3D.y,
        false,
        vector.Vector3(0, 0, 0),
        color: AppTheme.darkSurface.withValues(alpha: 0.5),
      ),
    );

    return figures;
  }

  /// Build terrain view with nodes overlaid
  List<Model3D<Model3D>> _buildTerrainFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();

    // Create a simple terrain mesh using points
    const gridSize = 10;
    const spacing = 0.5;
    final random = math.Random(123);

    // Generate height map for terrain
    final heights = List.generate(
      gridSize + 1,
      (x) => List.generate(
        gridSize + 1,
        (z) =>
            math.sin(x * 0.5) * math.cos(z * 0.5) * 0.5 +
            random.nextDouble() * 0.2,
      ),
    );

    // Create terrain using lines to form a grid mesh
    for (int x = 0; x < gridSize; x++) {
      for (int z = 0; z < gridSize; z++) {
        final x0 = (x - gridSize / 2) * spacing;
        final z0 = (z - gridSize / 2) * spacing;
        final x1 = (x + 1 - gridSize / 2) * spacing;
        final z1 = (z + 1 - gridSize / 2) * spacing;

        final h00 = heights[x][z];
        final h10 = heights[x + 1][z];
        final h01 = heights[x][z + 1];
        final h11 = heights[x + 1][z + 1];

        // Calculate color based on height
        final avgHeight = (h00 + h10 + h01 + h11) / 4;
        final terrainColor = Color.lerp(
          Colors.green.shade800,
          Colors.brown.shade400,
          (avgHeight + 0.5).clamp(0.0, 1.0),
        )!;

        // Draw terrain grid lines
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
        // Diagonal for mesh effect
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

    // Add nodes on top of terrain
    int index = 0;
    for (final node in nodeList) {
      final angle = (index / nodeList.length) * 2 * math.pi;
      const radius = 1.5;
      final x = radius * math.cos(angle);
      final z = radius * math.sin(angle);

      // Sample terrain height at node position
      final gridX = ((x / spacing) + gridSize / 2)
          .clamp(0, gridSize - 1)
          .toInt();
      final gridZ = ((z / spacing) + gridSize / 2)
          .clamp(0, gridSize - 1)
          .toInt();
      final terrainHeight = heights[gridX][gridZ];

      final position = vector.Vector3(x, terrainHeight + 0.3, z);

      figures.add(
        Cube3D(
          0.2,
          position,
          color: node.nodeNum == myNodeNum
              ? AppTheme.primaryBlue
              : _getNodeColor(node),
        ),
      );

      // Add vertical line from terrain to node
      figures.add(
        Line3D(
          vector.Vector3(x, terrainHeight, z),
          position,
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      );

      index++;
    }

    return figures;
  }

  List<Model3D<Model3D>> _buildGridPlane() {
    final figures = <Model3D<Model3D>>[];
    const gridSize = 5;
    const gridStep = 1.0;

    // Create grid lines
    for (int i = -gridSize; i <= gridSize; i++) {
      final pos = i * gridStep;
      final alpha = i == 0 ? 0.3 : 0.1;

      // X-axis lines
      figures.add(
        Line3D(
          vector.Vector3(-gridSize * gridStep, 0, pos),
          vector.Vector3(gridSize * gridStep, 0, pos),
          color: Colors.white.withValues(alpha: alpha),
          width: i == 0 ? 2 : 1,
        ),
      );

      // Z-axis lines
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

  PresenceStatus _getPresenceStatus(MeshNode node) {
    if (node.lastHeard == null) return PresenceStatus.offline;
    final diff = DateTime.now().difference(node.lastHeard!);
    if (diff.inMinutes < 2) return PresenceStatus.active;
    if (diff.inMinutes < 15) return PresenceStatus.idle;
    return PresenceStatus.offline;
  }

  Color _getNodeColor(MeshNode node) {
    final status = _getPresenceStatus(node);
    return switch (status) {
      PresenceStatus.active => AppTheme.successGreen,
      PresenceStatus.idle => AppTheme.warningYellow,
      PresenceStatus.offline => AppTheme.textTertiary,
    };
  }

  Widget _buildLegend(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Legend',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          _buildLegendItem(AppTheme.primaryBlue, 'My Node'),
          _buildLegendItem(AppTheme.successGreen, 'Active'),
          _buildLegendItem(AppTheme.warningYellow, 'Idle'),
          _buildLegendItem(AppTheme.textTertiary, 'Offline'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlHint(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.5)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeInfoCard(ThemeData theme, MeshNode? node) {
    if (node == null) return const SizedBox.shrink();

    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: _getNodeColor(node),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  node.longName ??
                      node.shortName ??
                      '!${node.nodeNum.toRadixString(16)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () => setState(() => _selectedNodeNum = null),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (node.snr != null) _buildInfoRow('SNR', '${node.snr} dB'),
          _buildInfoRow('Status', _getPresenceStatus(node).label),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showViewSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select View Mode',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...Mesh3DViewMode.values.map(
              (mode) => ListTile(
                leading: Icon(
                  mode.icon,
                  color: mode == _currentMode
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(mode.label),
                subtitle: Text(
                  mode.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
                selected: mode == _currentMode,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _currentMode = mode);
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
