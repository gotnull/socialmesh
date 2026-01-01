import 'dart:async';
import 'dart:math' as math;
import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../core/theme.dart';
import '../../core/widgets/edge_fade.dart';
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
  bool _showConnections = true;
  double _connectionQualityThreshold = 0.0; // 0.0 = show all, 1.0 = only best
  late AnimationController _rotationController;
  int? _selectedNodeNum;
  Timer? _signalUpdateTimer;

  // Node list panel state
  bool _showNodeList = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      minUserScale: 0.3, // Allow zooming out more
      maxUserScale: 15.0, // Allow zooming in much further
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
    _searchController.dispose();
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

  /// Handle tap on 3D view to select nodes
  void _handleTap(Offset tapPosition, Size viewSize, Map<int, MeshNode> nodes) {
    if (nodes.isEmpty) return;

    // Calculate node positions in 3D space
    final nodePositions = _calculateNodePositions(nodes);

    // Convert tap position to normalized coordinates (-1 to 1)
    final normalizedX = (tapPosition.dx / viewSize.width) * 2 - 1;
    final normalizedY = -((tapPosition.dy / viewSize.height) * 2 - 1);

    // Get camera rotation angles
    final rotX = _controller.rotationX * math.pi / 180;
    final rotY = _controller.rotationY * math.pi / 180;
    final scale = _controller.scale;

    // Find the nearest node to tap position
    int? nearestNodeNum;
    double nearestDistance = double.infinity;
    const tapThreshold = 0.15; // Tap tolerance in normalized units

    for (final entry in nodePositions.entries) {
      final pos3D = entry.value;

      // Apply rotation transformation (simplified projection)
      // Rotate around Y axis
      final cosY = math.cos(rotY);
      final sinY = math.sin(rotY);
      var x = pos3D.x * cosY - pos3D.z * sinY;
      var z = pos3D.x * sinY + pos3D.z * cosY;
      var y = pos3D.y;

      // Rotate around X axis
      final cosX = math.cos(rotX);
      final sinX = math.sin(rotX);
      final newY = y * cosX - z * sinX;
      final newZ = y * sinX + z * cosX;
      y = newY;
      z = newZ;

      // Simple orthographic projection with scale
      final screenX = x * scale * 0.1;
      final screenY = y * scale * 0.1;

      // Calculate distance from tap to projected node position
      final dx = normalizedX - screenX;
      final dy = normalizedY - screenY;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance < nearestDistance && distance < tapThreshold / scale * 10) {
        nearestDistance = distance;
        nearestNodeNum = entry.key;
      }
    }

    setState(() {
      if (nearestNodeNum != null) {
        _selectedNodeNum = nearestNodeNum;
        HapticFeedback.selectionClick();
      } else {
        // Tap on empty space - deselect
        _selectedNodeNum = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Watch stream providers for real-time data updates
    // This ensures the 3D view rebuilds when new signal data arrives
    ref.watch(currentRssiProvider);
    ref.watch(currentSnrProvider);
    ref.watch(currentChannelUtilProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: Text(
          _currentMode.label,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          // Connections toggle (topology mode only)
          if (_currentMode == Mesh3DViewMode.topology)
            IconButton(
              icon: Icon(
                _showConnections ? Icons.share : Icons.share_outlined,
                color: _showConnections ? theme.colorScheme.primary : null,
              ),
              tooltip: _showConnections
                  ? 'Hide Connections'
                  : 'Show Connections',
              onPressed: () =>
                  setState(() => _showConnections = !_showConnections),
            ),
          // Connection quality filter (topology mode only, when connections visible)
          if (_currentMode == Mesh3DViewMode.topology && _showConnections)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Filter Connections',
              onPressed: () => _showConnectionFilterSheet(context),
            ),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    // 3D Visualization with tap detection
                    GestureDetector(
                      onTapUp: (details) => _handleTap(
                        details.localPosition,
                        constraints.biggest,
                        nodes,
                      ),
                      child: DiTreDiDraggable(
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
                    ),

                    // Legend
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: _buildLegend(theme),
                    ),

                    // Node info card (when a node is selected)
                    if (_selectedNodeNum != null)
                      Positioned(
                        right: 16,
                        top: 16,
                        child: _buildNodeInfoCard(
                          theme,
                          nodes[_selectedNodeNum],
                        ),
                      ),

                    // Tap-to-dismiss overlay (when node list is open)
                    if (_showNodeList)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => setState(() => _showNodeList = false),
                          child: Container(color: Colors.transparent),
                        ),
                      ),

                    // Node list panel (sliding from left)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      left: _showNodeList ? 0 : -300,
                      top: 0,
                      bottom: 0,
                      width: 280,
                      child: _buildNodeListPanel(theme, nodes, myNodeNum),
                    ),

                    // Node list toggle button (bottom right, compact)
                    if (!_showNodeList)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: Material(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.9,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          elevation: 4,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: () => setState(() => _showNodeList = true),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.list,
                                    size: 18,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${nodes.length}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodeListPanel(
    ThemeData theme,
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    // Filter nodes by search query
    var filteredNodes = nodes.values.toList();
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredNodes = filteredNodes.where((node) {
        return node.displayName.toLowerCase().contains(query) ||
            node.shortName?.toLowerCase().contains(query) == true ||
            node.nodeNum.toRadixString(16).contains(query);
      }).toList();
    }

    // Sort: my node first, then online nodes, then by name
    filteredNodes.sort((a, b) {
      if (a.nodeNum == myNodeNum) return -1;
      if (b.nodeNum == myNodeNum) return 1;
      if (a.isOnline && !b.isOnline) return -1;
      if (!a.isOnline && b.isOnline) return 1;
      return a.displayName.compareTo(b.displayName);
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          border: Border(
            right: BorderSide(color: context.border.withValues(alpha: 0.5)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.border.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.hub, size: 20, color: context.accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nodes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '${filteredNodes.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.textTertiary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: context.textTertiary,
                    onPressed: () => setState(() => _showNodeList = false),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: context.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search nodes...',
                  hintStyle: TextStyle(
                    color: context.textTertiary,
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 20,
                    color: context.textSecondary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          color: context.textSecondary,
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
            // Node list
            Expanded(
              child: filteredNodes.isEmpty
                  ? Center(
                      child: Text(
                        'No nodes found',
                        style: TextStyle(color: context.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filteredNodes.length,
                      itemBuilder: (context, index) {
                        final node = filteredNodes[index];
                        final isMyNode = node.nodeNum == myNodeNum;
                        final isSelected = _selectedNodeNum == node.nodeNum;

                        return _buildNodeListItem(
                          theme,
                          node,
                          isMyNode: isMyNode,
                          isSelected: isSelected,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeListItem(
    ThemeData theme,
    MeshNode node, {
    required bool isMyNode,
    required bool isSelected,
  }) {
    final status = _getPresenceStatus(node);
    final baseColor = isMyNode
        ? context.accentColor
        : (status == PresenceStatus.active
              ? AppTheme.primaryPurple
              : (status == PresenceStatus.idle
                    ? AppTheme.warningYellow
                    : context.textTertiary));

    return Material(
      color: isSelected
          ? context.accentColor.withValues(alpha: 0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedNodeNum = node.nodeNum;
            _showNodeList = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Node indicator
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: baseColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: baseColor.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    node.shortName?.isNotEmpty == true
                        ? node.shortName!.substring(0, 1).toUpperCase()
                        : node.nodeNum
                              .toRadixString(16)
                              .characters
                              .first
                              .toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: baseColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Node info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isMyNode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ME',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: context.accentColor,
                              ),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            node.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Status indicator
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: status == PresenceStatus.active
                                ? AppTheme.successGreen
                                : (status == PresenceStatus.idle
                                      ? AppTheme.warningYellow
                                      : context.textTertiary),
                          ),
                        ),
                        Text(
                          _getStatusText(status, node.lastHeard),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                        if (node.snr != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.signal_cellular_alt,
                            size: 12,
                            color: _getSnrColor(node.snr!.toDouble()),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${node.snr}dB',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(PresenceStatus status, DateTime? lastHeard) {
    if (lastHeard == null) return 'Never heard';
    final diff = DateTime.now().difference(lastHeard);
    if (diff.inMinutes < 5) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildViewModeChips(ThemeData theme) {
    return EdgeFade.horizontal(
      fadeSize: 24,
      fadeColor: context.background,
      child: SingleChildScrollView(
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

  // ═══════════════════════════════════════════════════════════════════════════
  // SCI-FI SHAPE BUILDERS - Premium futuristic node visualizations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Build an octahedron (diamond/crystal) shape - sci-fi node representation
  List<Model3D<Model3D>> _buildOctahedron(
    vector.Vector3 position,
    double size,
    Color color, {
    double alpha = 1.0,
  }) {
    final figures = <Model3D<Model3D>>[];
    final halfSize = size / 2;
    final effectiveColor = color.withValues(alpha: alpha);

    // Octahedron vertices (6 points)
    final top = position + vector.Vector3(0, halfSize, 0);
    final bottom = position + vector.Vector3(0, -halfSize, 0);
    final front = position + vector.Vector3(0, 0, halfSize);
    final back = position + vector.Vector3(0, 0, -halfSize);
    final left = position + vector.Vector3(-halfSize, 0, 0);
    final right = position + vector.Vector3(halfSize, 0, 0);

    // Top pyramid faces (4 triangles)
    figures.add(Face3D.fromVertices(top, front, right, color: effectiveColor));
    figures.add(Face3D.fromVertices(top, right, back, color: effectiveColor));
    figures.add(Face3D.fromVertices(top, back, left, color: effectiveColor));
    figures.add(Face3D.fromVertices(top, left, front, color: effectiveColor));

    // Bottom pyramid faces (4 triangles)
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

  /// Build glowing energy rings around a node - futuristic effect
  List<Model3D<Model3D>> _buildEnergyRings(
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
      final yOffset = ring * 0.05; // Slight vertical offset between rings

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

  /// Build a holographic wireframe node - cutting-edge sci-fi aesthetic
  List<Model3D<Model3D>> _buildHologramNode(
    vector.Vector3 position,
    double size,
    Color color, {
    double alpha = 0.8,
  }) {
    final figures = <Model3D<Model3D>>[];
    final halfSize = size / 2;

    // Octahedron vertices
    final top = position + vector.Vector3(0, halfSize, 0);
    final bottom = position + vector.Vector3(0, -halfSize, 0);
    final front = position + vector.Vector3(0, 0, halfSize);
    final back = position + vector.Vector3(0, 0, -halfSize);
    final left = position + vector.Vector3(-halfSize, 0, 0);
    final right = position + vector.Vector3(halfSize, 0, 0);

    final wireColor = color.withValues(alpha: alpha);

    // Edge lines - top pyramid
    figures.add(Line3D(top, front, color: wireColor, width: 2));
    figures.add(Line3D(top, right, color: wireColor, width: 2));
    figures.add(Line3D(top, back, color: wireColor, width: 2));
    figures.add(Line3D(top, left, color: wireColor, width: 2));

    // Edge lines - bottom pyramid
    figures.add(Line3D(bottom, front, color: wireColor, width: 2));
    figures.add(Line3D(bottom, right, color: wireColor, width: 2));
    figures.add(Line3D(bottom, back, color: wireColor, width: 2));
    figures.add(Line3D(bottom, left, color: wireColor, width: 2));

    // Equator lines
    figures.add(Line3D(front, right, color: wireColor, width: 2));
    figures.add(Line3D(right, back, color: wireColor, width: 2));
    figures.add(Line3D(back, left, color: wireColor, width: 2));
    figures.add(Line3D(left, front, color: wireColor, width: 2));

    return figures;
  }

  /// Build a complete sci-fi node with octahedron core + energy rings
  List<Model3D<Model3D>> _buildSciFiNode(
    vector.Vector3 position,
    double size,
    Color color, {
    bool isHighlighted = false,
    bool showRings = true,
  }) {
    final figures = <Model3D<Model3D>>[];

    // Core octahedron (solid)
    figures.addAll(_buildOctahedron(position, size, color));

    // Add energy rings for highlighted or primary nodes
    if (showRings) {
      figures.addAll(
        _buildEnergyRings(
          position,
          size * (isHighlighted ? 1.2 : 0.9),
          color,
          ringCount: isHighlighted ? 3 : 2,
          alpha: isHighlighted ? 0.7 : 0.4,
        ),
      );
    }

    // Add hologram wireframe overlay for highlighted nodes
    if (isHighlighted) {
      figures.addAll(
        _buildHologramNode(position, size * 1.3, Colors.white, alpha: 0.3),
      );
    }

    return figures;
  }

  /// Build a pulsing beacon node (for signal sources)
  List<Model3D<Model3D>> _buildBeaconNode(
    vector.Vector3 position,
    double size,
    Color color, {
    double pulsePhase = 0.0,
  }) {
    final figures = <Model3D<Model3D>>[];

    // Inner core
    figures.addAll(_buildOctahedron(position, size * 0.6, color));

    // Outer shell (slightly transparent)
    figures.addAll(_buildOctahedron(position, size, color, alpha: 0.4));

    // Beacon ring (pulsing effect simulated by size)
    final ringSize = size * (1.0 + pulsePhase * 0.3);
    figures.addAll(
      _buildEnergyRings(
        position,
        ringSize,
        color,
        ringCount: 1,
        segments: 24,
        alpha: 0.6 - pulsePhase * 0.3,
      ),
    );

    return figures;
  }

  /// Build a data bar with glowing top cap (for charts)
  List<Model3D<Model3D>> _buildGlowingBar(
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
        width: width * 10, // Scale for visibility
      ),
    );

    // Glowing cap at top
    if (showCap) {
      final capPosition = basePosition + vector.Vector3(0, height, 0);
      figures.addAll(
        _buildOctahedron(capPosition, width * 1.5, color, alpha: alpha),
      );
    }

    return figures;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VIEW MODE BUILDERS
  // ═══════════════════════════════════════════════════════════════════════════

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
          nodeColor = context.textTertiary;
      }

      // Highlight my node with larger size and special effects
      final isMyNode = node.nodeNum == myNodeNum;
      if (isMyNode) {
        nodeColor = AppTheme.primaryBlue;
      }

      // Add sci-fi node with octahedron core + energy rings
      figures.addAll(
        _buildSciFiNode(
          position,
          isMyNode ? 0.5 : 0.35,
          nodeColor,
          isHighlighted: isMyNode,
          showRings: status == PresenceStatus.active || isMyNode,
        ),
      );
    }

    // Add connections between nodes based on SNR data
    if (_showConnections) {
      final connectedPairs = <String>{};
      for (final node in nodeList) {
        final nodePos = nodePositions[node.nodeNum];
        if (nodePos == null) continue;

        for (final otherNode in nodeList) {
          if (otherNode.nodeNum == node.nodeNum) continue;

          final otherPos = nodePositions[otherNode.nodeNum];
          if (otherPos == null) continue;

          // Create unique pair key to avoid duplicate connections
          final nodePair = [node.nodeNum, otherNode.nodeNum]..sort();
          final pairKey = '${nodePair[0]}-${nodePair[1]}';
          if (connectedPairs.contains(pairKey)) continue;

          // Draw connection if within view range
          final distance = (nodePos - otherPos).length;
          if (distance < 8) {
            // Calculate line color based on signal quality
            final snr = (node.snr ?? otherNode.snr ?? 0)
                .clamp(-20, 10)
                .toDouble();
            final quality = (snr + 20) / 30; // 0 to 1

            // Filter by quality threshold
            if (quality < _connectionQualityThreshold) continue;

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

      // RSSI bar (left) - glowing sci-fi bar
      final rssi = (node.rssi ?? -120).clamp(-120, -30).toDouble();
      final rssiNormalized = (rssi + 120) / 90; // 0 to 1
      final rssiHeight = 0.2 + rssiNormalized * 2.5;
      final rssiColor = _getRssiColor(rssi);

      figures.addAll(
        _buildGlowingBar(
          vector.Vector3(x - 0.2, 0, z),
          0.15,
          rssiHeight,
          rssiColor,
        ),
      );

      // SNR bar (right) - glowing sci-fi bar
      final snr = (node.snr ?? -20).clamp(-20, 15).toDouble();
      final snrNormalized = (snr + 20) / 35; // 0 to 1
      final snrHeight = 0.2 + snrNormalized * 2.5;
      final snrColor = _getSnrColor(snr);

      figures.addAll(
        _buildGlowingBar(
          vector.Vector3(x + 0.2, 0, z),
          0.15,
          snrHeight,
          snrColor,
        ),
      );

      // Node indicator at base - sci-fi octahedron
      final isMyNode = node.nodeNum == myNodeNum;
      figures.addAll(
        _buildOctahedron(
          vector.Vector3(x, 0.08, z),
          0.18,
          isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
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
        color: context.surface.withValues(alpha: 0.5),
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

      // Glowing octahedron cap on top of bar
      figures.addAll(
        _buildOctahedron(
          vector.Vector3(x, height, z),
          isRecent ? 0.18 : 0.12,
          barColor,
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

    // Large center indicator - sci-fi beacon node
    figures.addAll(
      _buildBeaconNode(
        vector.Vector3(0, currentHeight + 0.5, 1.5),
        0.5,
        currentColor,
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

        // Node marker - sci-fi octahedron
        final isMyNode = node.nodeNum == myNodeNum;
        figures.addAll(
          _buildOctahedron(
            vector.Vector3(x, batteryHeight + 0.1, z),
            0.2,
            isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
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
        color: context.surface.withValues(alpha: 0.3),
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

      // Add the node itself - sci-fi beacon node
      figures.addAll(
        _buildBeaconNode(
          position,
          0.3,
          isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
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

    // Draw all nodes - sci-fi octahedrons with rings
    for (final node in nodeList) {
      final position = nodePositions[node.nodeNum];
      if (position == null) continue;

      final isMyNode = node.nodeNum == myNodeNum;
      figures.addAll(
        _buildSciFiNode(
          position,
          isMyNode ? 0.4 : 0.3,
          isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
          isHighlighted: isMyNode,
          showRings: true,
        ),
      );
    }

    // Create traceroute path from my node to recently heard nodes
    if (myNodeNum != null && nodeList.length > 1) {
      // Sort nodes by last heard to show recent communication path
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

  /// Build activity heatmap as 3D bar chart using REAL node activity data
  List<Model3D<Model3D>> _buildActivityHeatmapFigures(
    Map<int, MeshNode> nodes,
  ) {
    final figures = <Model3D<Model3D>>[];
    final nodeList = nodes.values.toList();

    if (nodeList.isEmpty) {
      figures.addAll(_buildGridPlane());
      return figures;
    }

    // Sort by activity (most recently heard first)
    final sortedNodes = List<MeshNode>.from(nodeList)
      ..sort((a, b) {
        final aHeard = a.lastHeard ?? DateTime(1970);
        final bHeard = b.lastHeard ?? DateTime(1970);
        return bHeard.compareTo(aHeard);
      });

    // Arrange in a grid based on actual node count
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

      // Calculate REAL activity level based on lastHeard recency
      double activity = 0.0;
      if (node.lastHeard != null) {
        final minutesAgo = DateTime.now().difference(node.lastHeard!).inMinutes;
        if (minutesAgo < 5) {
          activity = 1.0; // Very active - heard in last 5 mins
        } else if (minutesAgo < 30) {
          activity = 0.8; // Active - heard in last 30 mins
        } else if (minutesAgo < 120) {
          activity = 0.6; // Recent - heard in last 2 hours
        } else if (minutesAgo < 1440) {
          activity = 0.3; // Idle - heard in last 24 hours
        } else {
          activity = 0.1; // Stale - not heard in 24+ hours
        }
      }

      final height = activity * 2.5 + 0.1;

      // Color based on activity level - blue (inactive) to red (active)
      final color = Color.lerp(
        Colors.blue.shade700,
        AppTheme.errorRed,
        activity,
      )!;

      // Glowing sci-fi bar with octahedron cap
      figures.addAll(
        _buildGlowingBar(vector.Vector3(x, 0, z), 0.2, height, color),
      );

      // Add node marker on top
      figures.addAll(
        _buildOctahedron(
          vector.Vector3(x, height + 0.15, z),
          0.15,
          _getNodeColor(node),
        ),
      );
    }

    // Add base plane
    final planeSize = math.max(gridCols, gridRows) * spacing + 1;
    figures.add(
      Plane3D(
        planeSize,
        Axis3D.y,
        false,
        vector.Vector3(0, 0, 0),
        color: context.surface.withValues(alpha: 0.5),
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

    if (nodeList.isEmpty) {
      figures.addAll(_buildGridPlane());
      return figures;
    }

    // Collect nodes with valid GPS data
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
      // Fall back to grid plane if no GPS data
      figures.addAll(_buildGridPlane());
      // Still show nodes in a circle
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
        figures.addAll(
          _buildSciFiNode(
            position,
            0.25,
            isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
            isHighlighted: isMyNode,
            showRings: true,
          ),
        );
        index++;
      }
      return figures;
    }

    // Calculate bounds from real GPS data
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

    // Add padding to bounds
    final latRange = maxLat - minLat;
    final lonRange = maxLon - minLon;
    final altRange = maxAlt - minAlt;
    final padding = math.max(latRange, lonRange) * 0.1;
    minLat -= padding;
    maxLat += padding;
    minLon -= padding;
    maxLon += padding;

    // Scale factors to fit in 3D space (-5 to 5 range)
    const worldSize = 8.0;
    final latScale = latRange > 0 ? worldSize / (maxLat - minLat) : 1.0;
    final lonScale = lonRange > 0 ? worldSize / (maxLon - minLon) : 1.0;
    final altScale = altRange > 50
        ? 3.0 / altRange
        : 0.01; // 3 units max height

    // Helper to convert GPS to 3D position
    vector.Vector3 gpsTo3D(double lat, double lon, double alt) {
      final x = (lon - (minLon + maxLon) / 2) * lonScale;
      final z = (lat - (minLat + maxLat) / 2) * latScale;
      final y = (alt - minAlt) * altScale;
      return vector.Vector3(x, y, z);
    }

    // Build terrain grid interpolated from node altitudes
    const gridSize = 12;
    final heights = List.generate(
      gridSize + 1,
      (_) => List.filled(gridSize + 1, 0.0),
    );
    final weights = List.generate(
      gridSize + 1,
      (_) => List.filled(gridSize + 1, 0.0),
    );

    // Calculate grid cell positions
    final gridMinX = (minLon - (minLon + maxLon) / 2) * lonScale;
    final gridMaxX = (maxLon - (minLon + maxLon) / 2) * lonScale;
    final gridMinZ = (minLat - (minLat + maxLat) / 2) * latScale;
    final gridMaxZ = (maxLat - (minLat + maxLat) / 2) * latScale;
    final cellWidth = (gridMaxX - gridMinX) / gridSize;
    final cellDepth = (gridMaxZ - gridMinZ) / gridSize;

    // Interpolate heights from node positions using inverse distance weighting
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
          // Inverse distance weighting (with small epsilon to avoid division by zero)
          final weight = 1.0 / (dist * dist + 0.1);
          heights[gx][gz] += pos.y * weight;
          weights[gx][gz] += weight;
        }
      }
    }

    // Normalize heights by weights
    for (int gx = 0; gx <= gridSize; gx++) {
      for (int gz = 0; gz <= gridSize; gz++) {
        if (weights[gx][gz] > 0) {
          heights[gx][gz] /= weights[gx][gz];
        }
      }
    }

    // Draw terrain mesh
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

        // Color based on height (green low, brown high)
        final avgHeight = (h00 + h10 + h01 + h11) / 4;
        final heightNorm = altRange > 0
            ? ((avgHeight / altScale) / altRange).clamp(0.0, 1.0)
            : 0.5;
        final terrainColor = Color.lerp(
          Colors.green.shade800,
          Colors.brown.shade400,
          heightNorm,
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

    // Add nodes at their actual GPS positions and altitudes
    for (final node in nodeList) {
      final isMyNode = node.nodeNum == myNodeNum;

      vector.Vector3 nodePosition;
      double groundHeight = 0;

      if (node.latitude != null &&
          node.longitude != null &&
          node.latitude != 0 &&
          node.longitude != 0) {
        // Real GPS position
        nodePosition = gpsTo3D(
          node.latitude!,
          node.longitude!,
          (node.altitude ?? 0).toDouble(),
        );

        // Find terrain height at node position for ground line
        final gxFloat = (nodePosition.x - gridMinX) / cellWidth;
        final gzFloat = (nodePosition.z - gridMinZ) / cellDepth;
        final gx = gxFloat.clamp(0, gridSize - 1).toInt();
        final gz = gzFloat.clamp(0, gridSize - 1).toInt();
        groundHeight = heights[gx][gz];
      } else {
        // No GPS - place at edge
        final index = nodeList.indexOf(node);
        final angle = (index / nodeList.length) * 2 * math.pi;
        const radius = 4.5;
        nodePosition = vector.Vector3(
          radius * math.cos(angle),
          0.3,
          radius * math.sin(angle),
        );
      }

      // Draw node
      figures.addAll(
        _buildSciFiNode(
          nodePosition +
              vector.Vector3(0, 0.2, 0), // Slight hover above terrain
          isMyNode ? 0.35 : 0.25,
          isMyNode ? AppTheme.primaryBlue : _getNodeColor(node),
          isHighlighted: isMyNode,
          showRings: true,
        ),
      );

      // Vertical line from ground to node (shows elevation)
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

    // Add a subtle base plane
    figures.add(
      Plane3D(
        worldSize + 2,
        Axis3D.y,
        false,
        vector.Vector3(0, -0.01, 0),
        color: context.surface.withValues(alpha: 0.2),
      ),
    );

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
      PresenceStatus.offline => context.textTertiary,
    };
  }

  Widget _buildLegend(ThemeData theme) {
    // Different legends for different modes
    final items = <(Color, String)>[];

    switch (_currentMode) {
      case Mesh3DViewMode.signalStrength:
        items.addAll([
          (AppTheme.successGreen, 'Excellent'),
          (AppTheme.warningYellow, 'Fair'),
          (AppTheme.errorRed, 'Poor'),
        ]);
      case Mesh3DViewMode.channelUtilization:
        items.addAll([
          (AppTheme.successGreen, '<25%'),
          (AccentColors.cyan, '<50%'),
          (AppTheme.warningYellow, '<75%'),
          (AppTheme.errorRed, '>75%'),
        ]);
      case Mesh3DViewMode.traceroute:
        items.addAll([
          (AppTheme.primaryBlue, 'Me'),
          (AccentColors.cyan, 'Route'),
        ]);
      case Mesh3DViewMode.activityHeatmap:
        items.addAll([
          (AppTheme.errorRed, 'Active'),
          (Colors.blue.shade700, 'Stale'),
        ]);
      default:
        items.addAll([
          (AppTheme.primaryBlue, 'Me'),
          (AppTheme.successGreen, 'Active'),
          (AppTheme.warningYellow, 'Idle'),
          (context.textTertiary, 'Offline'),
        ]);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children:
            items
                .map((item) => _buildLegendItem(item.$1, item.$2))
                .expand((widget) => [widget, const SizedBox(width: 12)])
                .toList()
              ..removeLast(),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: context.textSecondary),
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
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showConnectionFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Connection Quality Filter',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Show only connections above a minimum signal quality',
                style: TextStyle(fontSize: 14, color: context.textSecondary),
              ),
              const SizedBox(height: 24),

              // Quality threshold slider
              Row(
                children: [
                  const Icon(Icons.signal_cellular_0_bar, size: 20),
                  Expanded(
                    child: Slider(
                      value: _connectionQualityThreshold,
                      min: 0.0,
                      max: 1.0,
                      divisions: 10,
                      label: _getQualityLabel(_connectionQualityThreshold),
                      onChanged: (value) {
                        setSheetState(() {});
                        setState(() => _connectionQualityThreshold = value);
                      },
                    ),
                  ),
                  const Icon(Icons.signal_cellular_4_bar, size: 20),
                ],
              ),

              // Quality label
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getQualityColor(
                      _connectionQualityThreshold,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getQualityColor(_connectionQualityThreshold),
                    ),
                  ),
                  child: Text(
                    _getQualityLabel(_connectionQualityThreshold),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _getQualityColor(_connectionQualityThreshold),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Preset buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {});
                        setState(() => _connectionQualityThreshold = 0.0);
                      },
                      child: const Text('All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {});
                        setState(() => _connectionQualityThreshold = 0.33);
                      },
                      child: const Text('Fair+'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setSheetState(() {});
                        setState(() => _connectionQualityThreshold = 0.66);
                      },
                      child: const Text('Good+'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _getQualityLabel(double threshold) {
    if (threshold <= 0.1) return 'Show All Connections';
    if (threshold <= 0.33) return 'Poor or Better';
    if (threshold <= 0.5) return 'Fair or Better';
    if (threshold <= 0.66) return 'Good or Better';
    if (threshold <= 0.85) return 'Very Good or Better';
    return 'Excellent Only';
  }

  Color _getQualityColor(double threshold) {
    if (threshold <= 0.33) return Colors.red;
    if (threshold <= 0.5) return Colors.orange;
    if (threshold <= 0.66) return AppTheme.warningYellow;
    return AppTheme.successGreen;
  }

  void _showViewSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select View Mode',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: Mesh3DViewMode.values
                      .map(
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
                              color: context.textSecondary,
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
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
