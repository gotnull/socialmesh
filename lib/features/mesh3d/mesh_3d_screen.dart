import 'dart:async';
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
  signalStrength,
  channelUtilization,
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
      case Mesh3DViewMode.signalStrength:
        return 'Signal Strength';
      case Mesh3DViewMode.channelUtilization:
        return 'Channel Util';
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
        return 'View nodes and connections in 3D';
      case Mesh3DViewMode.signalStrength:
        return 'Live RSSI/SNR signal bars';
      case Mesh3DViewMode.channelUtilization:
        return 'Airtime & channel usage';
      case Mesh3DViewMode.signalPropagation:
        return 'Signal range visualization';
      case Mesh3DViewMode.traceroute:
        return 'Message paths through mesh';
      case Mesh3DViewMode.activityHeatmap:
        return '3D activity chart';
      case Mesh3DViewMode.terrain:
        return 'Network on terrain';
    }
  }

  IconData get icon {
    switch (this) {
      case Mesh3DViewMode.topology:
        return Icons.hub;
      case Mesh3DViewMode.signalStrength:
        return Icons.signal_cellular_alt;
      case Mesh3DViewMode.channelUtilization:
        return Icons.donut_small;
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
  Timer? _signalUpdateTimer;

  // Channel utilization history for live updates
  final List<double> _channelUtilHistory = [];

  // Signal history for live updates
  final Map<int, List<double>> _rssiHistory = {};
  final Map<int, List<double>> _snrHistory = {};

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

    // Update signal data periodically
    _signalUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _updateSignalHistory();
    });
  }

  void _updateSignalHistory() {
    final nodes = ref.read(nodesProvider);
    for (final node in nodes.values) {
      // Track RSSI history
      if (node.rssi != null) {
        _rssiHistory.putIfAbsent(node.nodeNum, () => []);
        _rssiHistory[node.nodeNum]!.add(node.rssi!.toDouble());
        if (_rssiHistory[node.nodeNum]!.length > 30) {
          _rssiHistory[node.nodeNum]!.removeAt(0);
        }
      }
      // Track SNR history
      if (node.snr != null) {
        _snrHistory.putIfAbsent(node.nodeNum, () => []);
        _snrHistory[node.nodeNum]!.add(node.snr!.toDouble());
        if (_snrHistory[node.nodeNum]!.length > 30) {
          _snrHistory[node.nodeNum]!.removeAt(0);
        }
      }
    }

    // Track channel utilization from stream
    final channelUtilAsync = ref.read(currentChannelUtilProvider);
    final channelUtil = channelUtilAsync.value ?? 0.0;
    _channelUtilHistory.add(channelUtil);
    if (_channelUtilHistory.length > 60) {
      _channelUtilHistory.removeAt(0);
    }

    if (_currentMode == Mesh3DViewMode.signalStrength ||
        _currentMode == Mesh3DViewMode.channelUtilization) {
      setState(() {}); // Trigger rebuild for live updates
    }
  }

  void _onRotate() {
    if (_autoRotate) {
      _controller.update(rotationY: _controller.rotationY + 0.5);
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _signalUpdateTimer?.cancel();
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // Label toggle
          IconButton(
            icon: Icon(
              _showLabels ? Icons.label : Icons.label_off,
              color: _showLabels ? theme.colorScheme.primary : null,
            ),
            tooltip: _showLabels ? 'Hide Labels' : 'Show Labels',
            onPressed: () => setState(() => _showLabels = !_showLabels),
          ),
          // Auto rotate toggle
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
      case Mesh3DViewMode.signalStrength:
        return _buildSignalStrengthFigures(nodes, myNodeNum);
      case Mesh3DViewMode.channelUtilization:
        return _buildChannelUtilizationFigures(nodes, myNodeNum);
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

  /// Calculate normalized positions for nodes centered around their centroid
  Map<int, vector.Vector3> _calculateNodePositions(Map<int, MeshNode> nodes) {
    final nodePositions = <int, vector.Vector3>{};
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;

    if (nodeCount == 0) return nodePositions;

    // First pass: collect all GPS coordinates to find centroid
    double sumLat = 0, sumLon = 0, sumAlt = 0;
    int gpsCount = 0;

    for (final node in nodeList) {
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

    // Calculate centroid
    final centerLat = gpsCount > 0 ? sumLat / gpsCount : 0.0;
    final centerLon = gpsCount > 0 ? sumLon / gpsCount : 0.0;
    final centerAlt = gpsCount > 0 ? sumAlt / gpsCount : 0.0;

    // Second pass: calculate positions relative to centroid
    int index = 0;
    for (final node in nodeList) {
      vector.Vector3 position;

      if (node.latitude != null &&
          node.longitude != null &&
          node.latitude != 0 &&
          node.longitude != 0) {
        // Use actual GPS position (normalized around centroid)
        final lat = node.latitude! - centerLat;
        final lon = node.longitude! - centerLon;
        final alt = ((node.altitude ?? 0) - centerAlt) / 50; // Scale altitude

        // Scale to reasonable 3D space (roughly 100m = 1 unit)
        // 1 degree latitude ≈ 111km, 1 degree longitude varies
        position = vector.Vector3(
          lon * 1000, // Scale for visibility
          alt.clamp(-3.0, 3.0), // Height based on altitude
          lat * 1000, // Scale for visibility
        );

        // If position is too far out, bring it in
        if (position.length > 5) {
          position = position.normalized() * 5;
        }
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
      index++;
    }

    return nodePositions;
  }

  /// Build 3D network topology - nodes as cubes, connections as lines
  List<Model3D<Model3D>> _buildTopologyFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();

    if (nodeList.isEmpty) {
      // Show placeholder message
      figures.addAll(_buildGridPlane());
      return figures;
    }

    final nodePositions = _calculateNodePositions(nodes);

    // Add nodes
    for (final node in nodeList) {
      final position = nodePositions[node.nodeNum];
      if (position == null) continue;

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

      // Highlight my node with larger size
      final isMyNode = node.nodeNum == myNodeNum;
      if (isMyNode) {
        nodeColor = AppTheme.primaryBlue;
      }

      // Add node as a cube
      figures.add(Cube3D(isMyNode ? 0.4 : 0.3, position, color: nodeColor));
    }

    // Add connections between nodes based on SNR data
    final connectedPairs = <String>{};
    for (final node in nodeList) {
      final nodePos = nodePositions[node.nodeNum];
      if (nodePos == null) continue;

      for (final otherNode in nodeList) {
        if (otherNode.nodeNum == node.nodeNum) continue;

        final otherPos = nodePositions[otherNode.nodeNum];
        if (otherPos == null) continue;

        // Create unique pair key to avoid duplicate connections
        final nodes = [node.nodeNum, otherNode.nodeNum]..sort();
        final pairKey = '${nodes[0]}-${nodes[1]}';
        if (connectedPairs.contains(pairKey)) continue;

        // Draw connection if within view range
        final distance = (nodePos - otherPos).length;
        if (distance < 8) {
          // Calculate line color based on signal quality
          final snr = (node.snr ?? otherNode.snr ?? 0)
              .clamp(-20, 10)
              .toDouble();
          final quality = (snr + 20) / 30; // 0 to 1

          figures.add(
            Line3D(
              nodePos,
              otherPos,
              color: Color.lerp(
                Colors.red.withValues(alpha: 0.4),
                Colors.green.withValues(alpha: 0.6),
                quality,
              )!,
              width: 1 + quality * 2,
            ),
          );
          connectedPairs.add(pairKey);
        }
      }
    }

    // Add a reference grid
    figures.addAll(_buildGridPlane());

    return figures;
  }

  /// Build signal strength visualization - 3D bar chart of RSSI/SNR
  List<Model3D<Model3D>> _buildSignalStrengthFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;

    if (nodeCount == 0) {
      figures.addAll(_buildGridPlane());
      return figures;
    }

    // Arrange nodes in a grid layout
    final gridCols = math.sqrt(nodeCount).ceil();
    const spacing = 1.2;
    final gridOffset = (gridCols - 1) * spacing / 2;

    int index = 0;
    for (final node in nodeList) {
      final row = index ~/ gridCols;
      final col = index % gridCols;
      final x = col * spacing - gridOffset;
      final z = row * spacing - gridOffset;

      // RSSI bar (left)
      final rssi = (node.rssi ?? -120).clamp(-120, -30).toDouble();
      final rssiNormalized = (rssi + 120) / 90; // 0 to 1
      final rssiHeight = 0.2 + rssiNormalized * 2.5;
      final rssiColor = _getRssiColor(rssi);

      figures.add(
        Cube3D(
          0.15,
          vector.Vector3(x - 0.2, rssiHeight / 2, z),
          color: rssiColor,
        ),
      );
      figures.add(
        Line3D(
          vector.Vector3(x - 0.2, 0, z),
          vector.Vector3(x - 0.2, rssiHeight, z),
          color: rssiColor,
          width: 8,
        ),
      );

      // SNR bar (right)
      final snr = (node.snr ?? -20).clamp(-20, 15).toDouble();
      final snrNormalized = (snr + 20) / 35; // 0 to 1
      final snrHeight = 0.2 + snrNormalized * 2.5;
      final snrColor = _getSnrColor(snr);

      figures.add(
        Cube3D(
          0.15,
          vector.Vector3(x + 0.2, snrHeight / 2, z),
          color: snrColor,
        ),
      );
      figures.add(
        Line3D(
          vector.Vector3(x + 0.2, 0, z),
          vector.Vector3(x + 0.2, snrHeight, z),
          color: snrColor,
          width: 8,
        ),
      );

      // Node indicator at base
      final isMyNode = node.nodeNum == myNodeNum;
      figures.add(
        Cube3D(
          0.12,
          vector.Vector3(x, 0.06, z),
          color: isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
        ),
      );

      index++;
    }

    // Add base plane
    figures.add(
      Plane3D(
        (gridCols + 1) * spacing,
        Axis3D.y,
        false,
        vector.Vector3(0, 0, 0),
        color: AppTheme.darkSurface.withValues(alpha: 0.5),
      ),
    );

    return figures;
  }

  Color _getRssiColor(double rssi) {
    if (rssi >= -60) return AppTheme.successGreen;
    if (rssi >= -75) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  Color _getSnrColor(double snr) {
    if (snr >= 5) return AccentColors.cyan;
    if (snr >= 0) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }

  /// Build channel utilization visualization - 3D timeline of airtime usage
  List<Model3D<Model3D>> _buildChannelUtilizationFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final figures = <Model3D<Model3D>>[];

    // Current channel utilization from provider
    final channelUtilAsync = ref.read(currentChannelUtilProvider);
    final currentUtil = channelUtilAsync.value ?? 0.0;

    // Build 3D bar chart showing channel utilization history
    final historyLength = _channelUtilHistory.length;
    const maxBars = 30;
    const spacing = 0.3;
    final barCount = math.min(historyLength, maxBars);

    // Draw historical utilization bars
    for (int i = 0; i < barCount; i++) {
      final historyIndex = historyLength - barCount + i;
      if (historyIndex < 0) continue;

      final util = _channelUtilHistory[historyIndex].clamp(0.0, 100.0);
      final normalizedUtil = util / 100.0;
      final height = 0.1 + normalizedUtil * 3.0;

      final x = (i - barCount / 2) * spacing;
      final z = 0.0;

      // Color based on utilization level
      Color barColor;
      if (util < 25) {
        barColor = AppTheme.successGreen;
      } else if (util < 50) {
        barColor = AccentColors.cyan;
      } else if (util < 75) {
        barColor = AppTheme.warningYellow;
      } else {
        barColor = AppTheme.errorRed;
      }

      // Make the most recent bar brighter
      final isRecent = i >= barCount - 3;
      final alpha = isRecent ? 1.0 : 0.6;

      figures.add(
        Line3D(
          vector.Vector3(x, 0, z),
          vector.Vector3(x, height, z),
          color: barColor.withValues(alpha: alpha),
          width: isRecent ? 10 : 6,
        ),
      );

      // Cap on top of bar
      figures.add(
        Cube3D(
          isRecent ? 0.12 : 0.08,
          vector.Vector3(x, height, z),
          color: barColor,
        ),
      );
    }

    // Add current utilization as a prominent center display
    final currentHeight = 0.1 + (currentUtil / 100.0) * 3.0;
    Color currentColor;
    if (currentUtil < 25) {
      currentColor = AppTheme.successGreen;
    } else if (currentUtil < 50) {
      currentColor = AccentColors.cyan;
    } else if (currentUtil < 75) {
      currentColor = AppTheme.warningYellow;
    } else {
      currentColor = AppTheme.errorRed;
    }

    // Large center indicator for current value
    figures.add(
      Cube3D(
        0.4,
        vector.Vector3(0, currentHeight + 0.5, 1.5),
        color: currentColor,
      ),
    );

    // Vertical stem for current indicator
    figures.add(
      Line3D(
        vector.Vector3(0, 0, 1.5),
        vector.Vector3(0, currentHeight + 0.3, 1.5),
        color: currentColor.withValues(alpha: 0.7),
        width: 4,
      ),
    );

    // Add threshold lines
    final thresholds = [25.0, 50.0, 75.0];
    for (final threshold in thresholds) {
      final thresholdHeight = 0.1 + (threshold / 100.0) * 3.0;
      figures.add(
        Line3D(
          vector.Vector3(-barCount * spacing / 2, thresholdHeight, -0.5),
          vector.Vector3(barCount * spacing / 2, thresholdHeight, -0.5),
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      );
    }

    // Add node battery/power indicators in background
    final nodeList = nodes.values.toList();
    final nodeCount = nodeList.length;
    if (nodeCount > 0) {
      int nodeIndex = 0;
      for (final node in nodeList.take(8)) {
        final angle = (nodeIndex / math.min(8, nodeCount)) * 2 * math.pi;
        const radius = 3.5;
        final x = radius * math.cos(angle);
        final z = radius * math.sin(angle) - 1;

        // Show battery level as vertical bar
        final battery = (node.batteryLevel ?? 0).clamp(0, 100).toDouble();
        final batteryHeight = 0.2 + (battery / 100.0) * 1.5;

        Color batteryColor;
        if (battery >= 50) {
          batteryColor = AppTheme.successGreen;
        } else if (battery >= 20) {
          batteryColor = AppTheme.warningYellow;
        } else {
          batteryColor = AppTheme.errorRed;
        }

        figures.add(
          Line3D(
            vector.Vector3(x, 0, z),
            vector.Vector3(x, batteryHeight, z),
            color: batteryColor.withValues(alpha: 0.5),
            width: 4,
          ),
        );

        // Node marker
        final isMyNode = node.nodeNum == myNodeNum;
        figures.add(
          Cube3D(
            0.15,
            vector.Vector3(x, batteryHeight + 0.1, z),
            color: isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
          ),
        );

        nodeIndex++;
      }
    }

    // Add base plane
    figures.add(
      Plane3D(
        6,
        Axis3D.y,
        false,
        vector.Vector3(0, 0, 0),
        color: AppTheme.darkSurface.withValues(alpha: 0.3),
      ),
    );

    return figures;
  }

  /// Build signal propagation visualization with spheres showing range
  List<Model3D<Model3D>> _buildSignalPropagationFigures(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodePositions = _calculateNodePositions(nodes);
    final nodeList = nodes.values.toList();

    for (final node in nodeList) {
      final position = nodePositions[node.nodeNum];
      if (position == null) continue;

      // Determine signal range based on RSSI
      final rssi = (node.rssi ?? -90).clamp(-120, -30).toDouble();
      final signalRadius = 0.5 + ((rssi + 120) / 90) * 1.5;

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
      final coneHeight = 0.5 + signalRadius * 0.5;
      final coneRadius = signalRadius * 0.4;

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
    final nodePositions = _calculateNodePositions(nodes);
    final nodeList = nodes.values.toList();

    // Draw all nodes
    for (final node in nodeList) {
      final position = nodePositions[node.nodeNum];
      if (position == null) continue;

      figures.add(
        Cube3D(
          node.nodeNum == myNodeNum ? 0.35 : 0.25,
          position,
          color: node.nodeNum == myNodeNum
              ? AppTheme.primaryBlue
              : _getNodeColor(node),
        ),
      );
    }

    // Create a simulated traceroute path from my node
    if (myNodeNum != null && nodeList.length > 1) {
      // Sort nodes by last heard to simulate recent communication path
      final sortedNodes =
          nodeList
              .where((n) => n.nodeNum != myNodeNum && n.lastHeard != null)
              .toList()
            ..sort(
              (a, b) => (b.lastHeard ?? DateTime(1970)).compareTo(
                a.lastHeard ?? DateTime(1970),
              ),
            );

      final pathNodes = sortedNodes
          .take(math.min(4, sortedNodes.length))
          .toList();
      final myPos = nodePositions[myNodeNum];

      if (myPos != null && pathNodes.isNotEmpty) {
        var prevPos = myPos;
        int hopNum = 1;

        for (final pathNode in pathNodes) {
          final toPos = nodePositions[pathNode.nodeNum];
          if (toPos == null) continue;

          // Animated path line (thicker, glowing)
          figures.add(
            Line3D(prevPos, toPos, color: AccentColors.cyan, width: 4),
          );

          // Add hop number indicator (point above the line midpoint)
          final midpoint = (prevPos + toPos) / 2;
          figures.add(
            Point3D(
              midpoint + vector.Vector3(0, 0.3, 0),
              color: AccentColors.magenta,
              width: 10 + hopNum * 2,
            ),
          );

          prevPos = toPos;
          hopNum++;
        }
      }
    }

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
    final nodePositions = _calculateNodePositions(nodes);
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
    for (final node in nodeList) {
      final position = nodePositions[node.nodeNum];
      if (position == null) continue;

      // Clamp position to terrain bounds
      final x = position.x.clamp(
        -gridSize * spacing / 2,
        gridSize * spacing / 2 - spacing,
      );
      final z = position.z.clamp(
        -gridSize * spacing / 2,
        gridSize * spacing / 2 - spacing,
      );

      // Sample terrain height at node position
      final gridX = ((x / spacing) + gridSize / 2)
          .clamp(0, gridSize - 1)
          .toInt();
      final gridZ = ((z / spacing) + gridSize / 2)
          .clamp(0, gridSize - 1)
          .toInt();
      final terrainHeight = heights[gridX][gridZ];

      final nodePosition = vector.Vector3(x, terrainHeight + 0.3, z);

      figures.add(
        Cube3D(
          0.2,
          nodePosition,
          color: node.nodeNum == myNodeNum
              ? AppTheme.primaryBlue
              : _getNodeColor(node),
        ),
      );

      // Add vertical line from terrain to node
      figures.add(
        Line3D(
          vector.Vector3(x, terrainHeight, z),
          nodePosition,
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      );
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
    // Different legends for different modes
    final items = <(Color, String)>[];

    switch (_currentMode) {
      case Mesh3DViewMode.signalStrength:
        items.addAll([
          (AppTheme.successGreen, 'RSSI: Excellent'),
          (AppTheme.warningYellow, 'RSSI: Fair'),
          (AppTheme.errorRed, 'RSSI: Poor'),
          (AccentColors.cyan, 'SNR: Good'),
        ]);
      case Mesh3DViewMode.channelUtilization:
        items.addAll([
          (AppTheme.successGreen, 'Low (<25%)'),
          (AccentColors.cyan, 'Medium (<50%)'),
          (AppTheme.warningYellow, 'High (<75%)'),
          (AppTheme.errorRed, 'Critical (>75%)'),
        ]);
      case Mesh3DViewMode.traceroute:
        items.addAll([
          (AppTheme.primaryBlue, 'My Node'),
          (AccentColors.cyan, 'Route Path'),
          (AccentColors.magenta, 'Hop Point'),
        ]);
      default:
        items.addAll([
          (AppTheme.primaryBlue, 'My Node'),
          (AppTheme.successGreen, 'Active'),
          (AppTheme.warningYellow, 'Idle'),
          (AppTheme.textTertiary, 'Offline'),
        ]);
    }

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
          ...items.map((item) => _buildLegendItem(item.$1, item.$2)),
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
          if (node.rssi != null) _buildInfoRow('RSSI', '${node.rssi} dBm'),
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
