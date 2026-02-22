// SPDX-License-Identifier: GPL-3.0-or-later

// Mesh 3D Screen — the primary 3D mesh visualization.
//
// Refactored to match NodeDex-level UX polish:
// - GlassScaffold.body with proper SafeArea compliance
// - Glass-styled stats card, legend, and node panel
// - Filter chips using SectionFilterChip + SearchFilterLayout constants
// - AppBottomSheet-based view selector
// - Staggered animations in the node panel
// - All 3D figure construction delegated to Mesh3DFigureBuilder
// - Models/enums extracted to mesh_3d_models.dart
//
// Architecture:
//   mesh_3d_screen.dart  — this file (UI shell, state, layout)
//   mesh_3d_models.dart  — enums + extensions
//   mesh_3d_figures.dart — all 3D geometry construction
//   mesh_3d_stats_card.dart — stats summary card
//   mesh_3d_legend.dart — legend overlay
//   mesh_3d_node_panel.dart — sliding node list panel
//   mesh_3d_view_selector.dart — view mode bottom sheet

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:ditredi/ditredi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/node_info_card.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../providers/presence_providers.dart';
import 'mesh_3d_figures.dart';
import 'mesh_3d_legend.dart';
import 'mesh_3d_models.dart';
import 'mesh_3d_node_panel.dart';
import 'mesh_3d_stats_card.dart';
import 'mesh_3d_view_selector.dart';

/// 3D Mesh Visualization Screen.
///
/// Displays mesh network nodes in an interactive 3D viewport with multiple
/// view modes (topology, signal strength, activity, terrain). Supports
/// node filtering, search, and tap-to-select with compact info cards.
class Mesh3DScreen extends ConsumerStatefulWidget {
  const Mesh3DScreen({super.key});

  @override
  ConsumerState<Mesh3DScreen> createState() => _Mesh3DScreenState();
}

class _Mesh3DScreenState extends ConsumerState<Mesh3DScreen>
    with SingleTickerProviderStateMixin, LifecycleSafeMixin {
  late DiTreDiController _controller;
  late AnimationController _rotationController;

  Mesh3DViewMode _currentMode = Mesh3DViewMode.topology;
  Mesh3DNodeFilter _nodeFilter = Mesh3DNodeFilter.all;
  bool _autoRotate = false;
  bool _showConnections = true;
  final double _connectionQualityThreshold = 0.0;
  int? _selectedNodeNum;
  Timer? _signalUpdateTimer;

  // Node list panel state.
  bool _showNodeList = false;

  // Signal history for live updates.
  final List<double> _channelUtilHistory = [];
  final Map<int, List<double>> _rssiHistory = {};
  final Map<int, List<double>> _snrHistory = {};
  Map<int, NodePresence> _presenceMap = const {};

  // =========================================================================
  // Lifecycle
  // =========================================================================

  @override
  void initState() {
    super.initState();
    _controller = DiTreDiController(
      rotationX: -30,
      rotationY: 30,
      light: vector.Vector3(1, 1, 1),
      minUserScale: 0.3,
      maxUserScale: 15.0,
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..addListener(_onRotate);

    // Periodic signal data collection.
    _signalUpdateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _updateSignalHistory();
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _signalUpdateTimer?.cancel();
    super.dispose();
  }

  // =========================================================================
  // Signal history tracking
  // =========================================================================

  void _updateSignalHistory() {
    final nodes = ref.read(nodesProvider);
    for (final node in nodes.values) {
      if (node.rssi != null) {
        _rssiHistory.putIfAbsent(node.nodeNum, () => []);
        _rssiHistory[node.nodeNum]!.add(node.rssi!.toDouble());
        if (_rssiHistory[node.nodeNum]!.length > 30) {
          _rssiHistory[node.nodeNum]!.removeAt(0);
        }
      }
      if (node.snr != null) {
        _snrHistory.putIfAbsent(node.nodeNum, () => []);
        _snrHistory[node.nodeNum]!.add(node.snr!.toDouble());
        if (_snrHistory[node.nodeNum]!.length > 30) {
          _snrHistory[node.nodeNum]!.removeAt(0);
        }
      }
    }

    final channelUtilAsync = ref.read(currentChannelUtilProvider);
    final channelUtil = channelUtilAsync.value ?? 0.0;
    _channelUtilHistory.add(channelUtil);
    if (_channelUtilHistory.length > 60) {
      _channelUtilHistory.removeAt(0);
    }

    if (_currentMode == Mesh3DViewMode.signalStrength) {
      safeSetState(() {});
    }
  }

  // =========================================================================
  // Auto-rotate
  // =========================================================================

  void _onRotate() {
    if (_autoRotate) {
      _controller.update(rotationY: _controller.rotationY + 0.5);
    }
  }

  void _toggleAutoRotate() {
    safeSetState(() {
      _autoRotate = !_autoRotate;
      if (_autoRotate) {
        _rotationController.repeat();
      } else {
        _rotationController.stop();
      }
    });
  }

  // =========================================================================
  // Tap-to-select
  // =========================================================================

  void _handleTap(Offset tapPosition, Size viewSize, Map<int, MeshNode> nodes) {
    if (nodes.isEmpty) return;

    final int? myNode = ref.read(myNodeNumProvider);
    final nodePositions = Mesh3DFigureBuilder.calculatePositions(
      mode: _currentMode,
      nodes: nodes,
      myNodeNum: myNode,
      presenceMap: _presenceMap,
    );

    // Convert tap to normalised coordinates (-1..1).
    final normalizedX = (tapPosition.dx / viewSize.width) * 2 - 1;
    final normalizedY = -((tapPosition.dy / viewSize.height) * 2 - 1);

    final rotX = _controller.rotationX * math.pi / 180;
    final rotY = _controller.rotationY * math.pi / 180;
    final scale = _controller.scale;

    int? nearestNodeNum;
    double nearestDistance = double.infinity;
    const tapThreshold = 0.15;

    for (final entry in nodePositions.entries) {
      final pos3D = entry.value;

      // Simplified rotation + orthographic projection.
      final cosY = math.cos(rotY);
      final sinY = math.sin(rotY);
      var x = pos3D.x * cosY - pos3D.z * sinY;
      var z = pos3D.x * sinY + pos3D.z * cosY;
      var y = pos3D.y;

      final cosX = math.cos(rotX);
      final sinX = math.sin(rotX);
      final newY = y * cosX - z * sinX;
      y = newY;

      final screenX = x * scale * 0.1;
      final screenY = y * scale * 0.1;

      final dx = normalizedX - screenX;
      final dy = normalizedY - screenY;
      final distance = math.sqrt(dx * dx + dy * dy);

      if (distance < nearestDistance && distance < tapThreshold / scale * 10) {
        nearestDistance = distance;
        nearestNodeNum = entry.key;
      }
    }

    safeSetState(() {
      if (nearestNodeNum != null) {
        _selectedNodeNum = nearestNodeNum;
        HapticFeedback.selectionClick();
      } else {
        _selectedNodeNum = null;
      }
    });
  }

  // =========================================================================
  // Node filtering
  // =========================================================================

  Map<int, MeshNode> _applyNodeFilter(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    if (_nodeFilter == Mesh3DNodeFilter.all) return nodes;

    final filtered = <int, MeshNode>{};
    for (final entry in nodes.entries) {
      final node = entry.value;
      final presence = presenceConfidenceFor(_presenceMap, node);

      // Always keep my own node visible.
      if (node.nodeNum == myNodeNum) {
        filtered[entry.key] = node;
        continue;
      }

      switch (_nodeFilter) {
        case Mesh3DNodeFilter.all:
          filtered[entry.key] = node;
        case Mesh3DNodeFilter.active:
          if (presence.isActive) {
            filtered[entry.key] = node;
          }
        case Mesh3DNodeFilter.activeFading:
          if (presence.isActive || presence.isFading) {
            filtered[entry.key] = node;
          }
        case Mesh3DNodeFilter.gpsOnly:
          if (node.latitude != null &&
              node.longitude != null &&
              node.latitude != 0 &&
              node.longitude != 0) {
            filtered[entry.key] = node;
          }
      }
    }
    return filtered;
  }

  Map<Mesh3DNodeFilter, int> _computeFilterCounts(Map<int, MeshNode> allNodes) {
    int active = 0;
    int activeFading = 0;
    int gpsOnly = 0;

    for (final node in allNodes.values) {
      final presence = presenceConfidenceFor(_presenceMap, node);
      if (presence.isActive) {
        active++;
        activeFading++;
      } else if (presence.isFading) {
        activeFading++;
      }
      if (node.latitude != null &&
          node.longitude != null &&
          node.latitude != 0 &&
          node.longitude != 0) {
        gpsOnly++;
      }
    }

    return {
      Mesh3DNodeFilter.all: allNodes.length,
      Mesh3DNodeFilter.active: active,
      Mesh3DNodeFilter.activeFading: activeFading,
      Mesh3DNodeFilter.gpsOnly: gpsOnly,
    };
  }

  // =========================================================================
  // Build
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final allNodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    _presenceMap = ref.watch(presenceMapProvider);

    final nodes = _applyNodeFilter(allNodes, myNodeNum);

    // Watch stream providers for real-time data updates.
    ref.watch(currentRssiProvider);
    ref.watch(currentSnrProvider);
    ref.watch(currentChannelUtilProvider);

    final channelUtilAsync = ref.watch(currentChannelUtilProvider);
    final channelUtil = channelUtilAsync.value;

    final stats = Mesh3DStats.fromNodes(
      nodes: allNodes,
      presenceMap: _presenceMap,
      channelUtil: channelUtil,
    );

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return HelpTourController(
      topicId: 'mesh_3d_overview',
      stepKeys: const {},
      child: GlassScaffold.body(
        title: _currentMode.label,
        physics: const NeverScrollableScrollPhysics(),
        actions: [
          // View selector — most important action.
          IconButton(
            icon: const Icon(Icons.view_carousel),
            tooltip: 'Change View',
            onPressed: () async {
              final selected = await showMesh3DViewSelector(
                context: context,
                currentMode: _currentMode,
              );
              if (selected != null && selected != _currentMode && mounted) {
                safeSetState(() => _currentMode = selected);
              }
            },
          ),
          // Overflow menu for secondary actions.
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'connections':
                  safeSetState(() => _showConnections = !_showConnections);
                case 'rotate':
                  _toggleAutoRotate();
                case 'help':
                  ref.read(helpProvider.notifier).startTour('mesh_3d_overview');
              }
            },
            itemBuilder: (context) => [
              if (_currentMode == Mesh3DViewMode.topology)
                PopupMenuItem(
                  value: 'connections',
                  child: ListTile(
                    leading: Icon(
                      _showConnections ? Icons.share : Icons.share_outlined,
                    ),
                    title: Text(
                      _showConnections
                          ? 'Hide Connections'
                          : 'Show Connections',
                    ),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              PopupMenuItem(
                value: 'rotate',
                child: ListTile(
                  leading: const Icon(Icons.rotate_right),
                  title: Text(_autoRotate ? 'Stop Rotation' : 'Auto Rotate'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'help',
                child: ListTile(
                  leading: Icon(Icons.help_outline),
                  title: Text('Help'),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            children: [
              // Spacing between app bar and chip row.
              const SizedBox(height: 8),

              // Filter chip row — view modes + node filters.
              _buildFilterChipRow(_computeFilterCounts(allNodes)),

              // Stats card.
              Mesh3DStatsCard(stats: stats),

              // 3D Viewport + overlays.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // 3D viewport with tap detection.
                        GestureDetector(
                          onTapUp: (details) => _handleTap(
                            details.localPosition,
                            constraints.biggest,
                            nodes,
                          ),
                          child: DiTreDiDraggable(
                            controller: _controller,
                            child: DiTreDi(
                              figures: Mesh3DFigureBuilder.buildFigures(
                                mode: _currentMode,
                                nodes: nodes,
                                myNodeNum: myNodeNum,
                                presenceMap: _presenceMap,
                                showConnections: _showConnections,
                                connectionQualityThreshold:
                                    _connectionQualityThreshold,
                                surfaceColor: context.surface,
                              ),
                              controller: _controller,
                              config: const DiTreDiConfig(
                                supportZIndex: true,
                                defaultPointWidth: 8,
                                defaultLineWidth: 2,
                              ),
                            ),
                          ),
                        ),

                        // Node count badge (top-left, map-screen style).
                        if (!_showNodeList)
                          Positioned(
                            left: 16,
                            top: 12,
                            child: _NodeCountBadge(
                              filteredCount: nodes.length,
                              totalCount: allNodes.length,
                              isFiltered: _nodeFilter != Mesh3DNodeFilter.all,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                safeSetState(() {
                                  _showNodeList = true;
                                  _selectedNodeNum = null;
                                });
                              },
                            ),
                          ),

                        // Legend overlay (bottom-left).
                        Positioned(
                          left: 12,
                          bottom: _selectedNodeNum != null
                              ? 200 + bottomPadding
                              : 12 + bottomPadding,
                          child: Mesh3DLegend(mode: _currentMode),
                        ),

                        // Selected node info card (bottom, full width).
                        if (_selectedNodeNum != null &&
                            allNodes.containsKey(_selectedNodeNum))
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16 + bottomPadding,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 16,
                                  sigmaY: 16,
                                ),
                                child: NodeInfoCard(
                                  node: allNodes[_selectedNodeNum]!,
                                  isMyNode: _selectedNodeNum == myNodeNum,
                                  compact: true,
                                  onClose: () => safeSetState(
                                    () => _selectedNodeNum = null,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Tap-to-dismiss overlay when node list is open.
                        if (_showNodeList)
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () =>
                                  safeSetState(() => _showNodeList = false),
                              child: Container(color: Colors.transparent),
                            ),
                          ),

                        // Node list panel (slides from left).
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          left: _showNodeList ? 0 : -300,
                          top: 0,
                          bottom: 0,
                          width: 280,
                          child: Mesh3DNodePanel(
                            visibleNodes: nodes,
                            allNodes: allNodes,
                            myNodeNum: myNodeNum,
                            selectedNodeNum: _selectedNodeNum,
                            presenceMap: _presenceMap,
                            onNodeSelected: (nodeNum) {
                              safeSetState(() {
                                _selectedNodeNum = nodeNum;
                                _showNodeList = false;
                              });
                            },
                            onClose: () =>
                                safeSetState(() => _showNodeList = false),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Filter chip row
  // =========================================================================

  Widget _buildFilterChipRow(Map<Mesh3DNodeFilter, int> counts) {
    return SizedBox(
      height: SearchFilterLayout.chipRowHeight,
      child: EdgeFade.horizontal(
        fadeSize: SearchFilterLayout.edgeFadeSize,
        fadeColor: context.background,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: SearchFilterLayout.horizontalPadding,
          ),
          children: [
            // View mode chips (no counts — act as mode tabs).
            ...Mesh3DViewMode.values.map((mode) {
              final isSelected = mode == _currentMode;
              return Padding(
                padding: EdgeInsets.only(right: SearchFilterLayout.chipSpacing),
                child: SectionFilterChip(
                  label: mode.label,
                  isSelected: isSelected,
                  icon: mode.icon,
                  color: isSelected ? context.accentColor : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    safeSetState(() => _currentMode = mode);
                  },
                ),
              );
            }),

            // Visual separator between mode and filter chips.
            Padding(
              padding: EdgeInsets.only(right: SearchFilterLayout.chipSpacing),
              child: Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(vertical: 10),
                color: context.border.withValues(alpha: 0.3),
              ),
            ),

            // Node filter chips (with counts).
            ...Mesh3DNodeFilter.values.map((filter) {
              final count = counts[filter] ?? 0;
              return Padding(
                padding: EdgeInsets.only(right: SearchFilterLayout.chipSpacing),
                child: SectionFilterChip(
                  label: filter.label,
                  count: count,
                  isSelected: _nodeFilter == filter,
                  icon: filter.icon,
                  color: switch (filter) {
                    Mesh3DNodeFilter.all => null,
                    Mesh3DNodeFilter.active => AccentColors.green,
                    Mesh3DNodeFilter.activeFading => AppTheme.warningYellow,
                    Mesh3DNodeFilter.gpsOnly => AccentColors.cyan,
                  },
                  onTap: () {
                    HapticFeedback.selectionClick();
                    safeSetState(() => _nodeFilter = filter);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _NodeCountBadge — glass-styled node count pill
// =============================================================================

class _NodeCountBadge extends StatelessWidget {
  final int filteredCount;
  final int totalCount;
  final bool isFiltered;
  final VoidCallback onTap;

  const _NodeCountBadge({
    required this.filteredCount,
    required this.totalCount,
    required this.isFiltered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.card.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: context.border.withValues(alpha: 0.2),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.successGreen.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isFiltered
                      ? '$filteredCount/$totalCount nodes'
                      : '$filteredCount nodes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: context.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
