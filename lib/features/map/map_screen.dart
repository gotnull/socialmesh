import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../messaging/messaging_screen.dart';

/// Map screen showing all mesh nodes with GPS positions
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  MeshNode? _selectedNode;
  bool _showHeatmap = false;
  bool _isRefreshing = false;
  double _currentZoom = 14.0;
  bool _showNodeList = false;

  // Animation controller for smooth camera movements
  AnimationController? _animationController;

  // Track last known positions for nodes (to handle GPS loss gracefully)
  final Map<int, _CachedPosition> _positionCache = {};

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  /// Animate camera to a specific location with smooth easing
  void _animatedMove(LatLng destLocation, double destZoom) {
    _animationController?.dispose();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final startZoom = _mapController.camera.zoom;
    final startCenter = _mapController.camera.center;

    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);

    final animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOutCubic,
    );

    _animationController!.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _animationController!.forward();
  }

  /// Update position cache and return nodes with valid (current or cached) positions
  List<_NodeWithPosition> _getNodesWithPositions(Map<int, MeshNode> nodes) {
    final result = <_NodeWithPosition>[];
    final now = DateTime.now();

    // Position considered stale after 30 minutes of no updates
    const staleThreshold = Duration(minutes: 30);

    for (final node in nodes.values) {
      if (node.hasPosition) {
        // Node has current GPS - update cache and use it
        _positionCache[node.nodeNum] = _CachedPosition(
          latitude: node.latitude!,
          longitude: node.longitude!,
          timestamp: now,
          isStale: false,
        );
        result.add(
          _NodeWithPosition(
            node: node,
            latitude: node.latitude!,
            longitude: node.longitude!,
            isStale: false,
          ),
        );
      } else if (_positionCache.containsKey(node.nodeNum)) {
        // Node lost GPS but we have cached position
        final cached = _positionCache[node.nodeNum]!;
        final age = now.difference(cached.timestamp);
        final isStale = age > staleThreshold;

        // Keep showing if node is still online, even if stale
        if (node.isOnline || !isStale) {
          result.add(
            _NodeWithPosition(
              node: node,
              latitude: cached.latitude,
              longitude: cached.longitude,
              isStale: true,
            ),
          );
        }
      }
    }

    // Clean up cache for nodes that no longer exist
    _positionCache.removeWhere((nodeNum, _) => !nodes.containsKey(nodeNum));

    return result;
  }

  /// Calculate distance between two nodes in km
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return const Distance().as(
      LengthUnit.Kilometer,
      LatLng(lat1, lng1),
      LatLng(lat2, lng2),
    );
  }

  /// Format distance for display
  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()}m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)}km';
    } else {
      return '${km.round()}km';
    }
  }

  Future<void> _refreshPositions() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Requesting positions from nodes...'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _selectNodeAndCenter(_NodeWithPosition nodeWithPos) {
    setState(() {
      _selectedNode = nodeWithPos.node;
      _showNodeList = false;
    });
    _animatedMove(LatLng(nodeWithPos.latitude, nodeWithPos.longitude), 15.0);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Get nodes with positions (current or cached)
    final nodesWithPosition = _getNodesWithPositions(nodes);

    // Calculate center point
    LatLng center = const LatLng(0, 0);
    double zoom = 2.0;

    if (nodesWithPosition.isNotEmpty) {
      final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
      final myNodeWithPos = nodesWithPosition
          .where((n) => n.node.nodeNum == myNodeNum)
          .firstOrNull;

      if (myNodeWithPos != null) {
        center = LatLng(myNodeWithPos.latitude, myNodeWithPos.longitude);
        zoom = 14.0;
      } else if (myNode?.hasPosition == true) {
        center = LatLng(myNode!.latitude!, myNode.longitude!);
        zoom = 14.0;
      } else {
        double avgLat = 0, avgLng = 0;
        for (final n in nodesWithPosition) {
          avgLat += n.latitude;
          avgLng += n.longitude;
        }
        avgLat /= nodesWithPosition.length;
        avgLng /= nodesWithPosition.length;
        center = LatLng(avgLat, avgLng);
        zoom = 12.0;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Mesh Map',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            fontFamily: 'Inter',
          ),
        ),
        actions: [
          // Node list toggle
          IconButton(
            icon: Icon(
              _showNodeList ? Icons.view_list : Icons.view_list_outlined,
              color: _showNodeList
                  ? AppTheme.primaryMagenta
                  : AppTheme.textSecondary,
            ),
            onPressed: nodesWithPosition.isEmpty
                ? null
                : () => setState(() => _showNodeList = !_showNodeList),
            tooltip: 'Node list',
          ),
          // Refresh positions
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textSecondary,
                    ),
                  )
                : const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _isRefreshing ? null : _refreshPositions,
            tooltip: 'Request positions from nodes',
          ),
          // Heatmap toggle
          IconButton(
            icon: Icon(
              _showHeatmap ? Icons.layers : Icons.layers_outlined,
              color: _showHeatmap
                  ? AppTheme.primaryMagenta
                  : AppTheme.textSecondary,
            ),
            onPressed: () => setState(() => _showHeatmap = !_showHeatmap),
            tooltip: 'Toggle coverage heatmap',
          ),
          // Center on my location
          IconButton(
            icon: const Icon(Icons.my_location, color: AppTheme.textSecondary),
            onPressed: () => _centerOnMyNode(nodesWithPosition, myNodeNum),
            tooltip: 'Center on my node',
          ),
        ],
      ),
      body: nodesWithPosition.isEmpty
          ? _buildEmptyState()
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                    minZoom: 4,
                    maxZoom: 18,
                    backgroundColor: AppTheme.darkBackground,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      pinchZoomThreshold: 0.5,
                      scrollWheelVelocity: 0.005,
                    ),
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() => _currentZoom = position.zoom);
                      }
                    },
                    onTap: (tapPos, point) => setState(() {
                      _selectedNode = null;
                      _showNodeList = false;
                    }),
                  ),
                  children: [
                    // Dark map tiles
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.protofluff.app',
                      retinaMode: true,
                      tileBuilder: (context, tileWidget, tile) {
                        return AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: tileWidget,
                        );
                      },
                    ),
                    // Heatmap layer
                    if (_showHeatmap)
                      CircleLayer(
                        circles: nodesWithPosition.map((n) {
                          return CircleMarker(
                            point: LatLng(n.latitude, n.longitude),
                            radius: 50,
                            color: AppTheme.primaryMagenta.withValues(
                              alpha: 0.15,
                            ),
                            borderColor: AppTheme.primaryMagenta.withValues(
                              alpha: 0.3,
                            ),
                            borderStrokeWidth: 1,
                          );
                        }).toList(),
                      ),
                    // Connection lines with distance labels
                    PolylineLayer(
                      polylines: _buildConnectionLines(
                        nodesWithPosition,
                        myNodeNum,
                      ),
                    ),
                    // Node markers
                    MarkerLayer(
                      markers: nodesWithPosition.map((n) {
                        final isMyNode = n.node.nodeNum == myNodeNum;
                        final isSelected =
                            _selectedNode?.nodeNum == n.node.nodeNum;
                        return Marker(
                          point: LatLng(n.latitude, n.longitude),
                          width: isSelected ? 56 : 44,
                          height: isSelected ? 56 : 44,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedNode = n.node);
                            },
                            child: _NodeMarker(
                              node: n.node,
                              isMyNode: isMyNode,
                              isSelected: isSelected,
                              isStale: n.isStale,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Distance labels layer
                    MarkerLayer(
                      markers: _buildDistanceLabels(
                        nodesWithPosition,
                        myNodeNum,
                      ),
                    ),
                  ],
                ),
                // Node info card
                if (_selectedNode != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: _NodeInfoCard(
                      node: _selectedNode!,
                      isMyNode: _selectedNode!.nodeNum == myNodeNum,
                      onClose: () => setState(() => _selectedNode = null),
                      onMessage: () => _openDM(_selectedNode!),
                      distanceFromMe: _getDistanceFromMyNode(
                        _selectedNode!,
                        nodesWithPosition,
                        myNodeNum,
                      ),
                    ),
                  ),
                // Node list panel (sliding from left)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _showNodeList ? 0 : -280,
                  top: 0,
                  bottom: 0,
                  width: 280,
                  child: _NodeListPanel(
                    nodesWithPosition: nodesWithPosition,
                    myNodeNum: myNodeNum,
                    selectedNode: _selectedNode,
                    onNodeSelected: _selectNodeAndCenter,
                    onClose: () => setState(() => _showNodeList = false),
                    calculateDistanceFromMe: (node) => _getDistanceFromMyNode(
                      node.node,
                      nodesWithPosition,
                      myNodeNum,
                    ),
                  ),
                ),
                // Node count indicator (hide when list is shown)
                if (!_showNodeList)
                  Positioned(
                    left: 16,
                    top: 16,
                    child: GestureDetector(
                      onTap: () => setState(() => _showNodeList = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.darkCard.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.darkBorder.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppTheme.successGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${nodesWithPosition.length} nodes',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: AppTheme.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Zoom controls
                Positioned(
                  right: 16,
                  top: 16,
                  child: _ZoomControls(
                    currentZoom: _currentZoom,
                    minZoom: 4,
                    maxZoom: 18,
                    onZoomIn: () {
                      final newZoom = (_currentZoom + 1).clamp(4.0, 18.0);
                      _animatedMove(_mapController.camera.center, newZoom);
                      HapticFeedback.selectionClick();
                    },
                    onZoomOut: () {
                      final newZoom = (_currentZoom - 1).clamp(4.0, 18.0);
                      _animatedMove(_mapController.camera.center, newZoom);
                      HapticFeedback.selectionClick();
                    },
                    onFitAll: () => _fitAllNodes(nodesWithPosition),
                  ),
                ),
              ],
            ),
    );
  }

  double? _getDistanceFromMyNode(
    MeshNode node,
    List<_NodeWithPosition> nodesWithPosition,
    int? myNodeNum,
  ) {
    if (myNodeNum == null || node.nodeNum == myNodeNum) return null;

    final myNodeWithPos = nodesWithPosition
        .where((n) => n.node.nodeNum == myNodeNum)
        .firstOrNull;
    if (myNodeWithPos == null) return null;

    final nodeWithPos = nodesWithPosition
        .where((n) => n.node.nodeNum == node.nodeNum)
        .firstOrNull;
    if (nodeWithPos == null) return null;

    return _calculateDistance(
      myNodeWithPos.latitude,
      myNodeWithPos.longitude,
      nodeWithPos.latitude,
      nodeWithPos.longitude,
    );
  }

  void _fitAllNodes(List<_NodeWithPosition> nodes) {
    if (nodes.isEmpty) return;

    double minLat = nodes.first.latitude;
    double maxLat = nodes.first.latitude;
    double minLng = nodes.first.longitude;
    double maxLng = nodes.first.longitude;

    for (final n in nodes) {
      if (n.latitude < minLat) minLat = n.latitude;
      if (n.latitude > maxLat) maxLat = n.latitude;
      if (n.longitude < minLng) minLng = n.longitude;
      if (n.longitude > maxLng) maxLng = n.longitude;
    }

    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;

    final bounds = LatLngBounds(
      LatLng(minLat - latPadding, minLng - lngPadding),
      LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    final cameraFit = CameraFit.bounds(
      bounds: bounds,
      padding: const EdgeInsets.all(50),
    );

    final camera = cameraFit.fit(_mapController.camera);
    _animatedMove(camera.center, camera.zoom.clamp(4.0, 16.0));
    HapticFeedback.lightImpact();
  }

  Widget _buildEmptyState() {
    final nodes = ref.watch(nodesProvider);
    final totalNodes = nodes.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryMagenta.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.map_outlined,
                size: 40,
                color: AppTheme.primaryMagenta,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Nodes with GPS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              totalNodes > 0
                  ? '$totalNodes nodes discovered but none have\nreported GPS position yet.'
                  : 'Nodes will appear on the map once they\nreport their GPS position.',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _refreshPositions,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(
                _isRefreshing ? 'Requesting...' : 'Request Positions',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryMagenta,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Position broadcasts can take up to 15 minutes.\nTap to request immediately.',
              style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build connection lines with visual distinction for uncertain connections
  List<Polyline> _buildConnectionLines(
    List<_NodeWithPosition> nodes,
    int? myNodeNum,
  ) {
    final lines = <Polyline>[];
    const maxDistanceKm = 15.0;

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];

        final distance = _calculateDistance(
          node1.latitude,
          node1.longitude,
          node2.latitude,
          node2.longitude,
        );

        if (distance <= maxDistanceKm) {
          final isMyConnection =
              node1.node.nodeNum == myNodeNum ||
              node2.node.nodeNum == myNodeNum;
          final hasStaleNode = node1.isStale || node2.isStale;

          // Use pattern for stale connections (visually indicates uncertainty)
          final pattern = hasStaleNode
              ? const StrokePattern.dotted(spacingFactor: 2.5)
              : const StrokePattern.solid();

          lines.add(
            Polyline(
              points: [
                LatLng(node1.latitude, node1.longitude),
                LatLng(node2.latitude, node2.longitude),
              ],
              color: isMyConnection
                  ? AppTheme.primaryMagenta.withValues(
                      alpha: hasStaleNode ? 0.25 : 0.5,
                    )
                  : AppTheme.primaryPurple.withValues(
                      alpha: hasStaleNode ? 0.2 : 0.35,
                    ),
              strokeWidth: isMyConnection ? 2.0 : 1.5,
              pattern: pattern,
            ),
          );
        }
      }
    }

    return lines;
  }

  /// Build distance label markers for connections from my node
  List<Marker> _buildDistanceLabels(
    List<_NodeWithPosition> nodes,
    int? myNodeNum,
  ) {
    if (myNodeNum == null || _currentZoom < 10) return [];

    final myNode = nodes.where((n) => n.node.nodeNum == myNodeNum).firstOrNull;
    if (myNode == null) return [];

    final labels = <Marker>[];
    const maxDistanceKm = 15.0;

    for (final node in nodes) {
      if (node.node.nodeNum == myNodeNum) continue;

      final distance = _calculateDistance(
        myNode.latitude,
        myNode.longitude,
        node.latitude,
        node.longitude,
      );

      if (distance <= maxDistanceKm) {
        // Position label at midpoint
        final midLat = (myNode.latitude + node.latitude) / 2;
        final midLng = (myNode.longitude + node.longitude) / 2;

        labels.add(
          Marker(
            point: LatLng(midLat, midLng),
            width: 60,
            height: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.primaryMagenta.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _formatDistance(distance),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryMagenta,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      }
    }

    return labels;
  }

  void _centerOnMyNode(List<_NodeWithPosition> nodes, int? myNodeNum) {
    if (myNodeNum == null) return;
    final myNode = nodes.where((n) => n.node.nodeNum == myNodeNum).firstOrNull;
    if (myNode != null) {
      _animatedMove(LatLng(myNode.latitude, myNode.longitude), 14.0);
      HapticFeedback.lightImpact();
    }
  }

  void _openDM(MeshNode node) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          type: ConversationType.directMessage,
          nodeNum: node.nodeNum,
          title: node.displayName,
        ),
      ),
    );
  }
}

/// Cached position for nodes that lose GPS
class _CachedPosition {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isStale;

  _CachedPosition({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.isStale,
  });
}

/// Node with resolved position (current or cached)
class _NodeWithPosition {
  final MeshNode node;
  final double latitude;
  final double longitude;
  final bool isStale;

  _NodeWithPosition({
    required this.node,
    required this.latitude,
    required this.longitude,
    required this.isStale,
  });
}

/// Custom marker widget for nodes
class _NodeMarker extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final bool isSelected;
  final bool isStale;

  const _NodeMarker({
    required this.node,
    required this.isMyNode,
    required this.isSelected,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isMyNode
        ? AppTheme.primaryMagenta
        : (node.isOnline ? AppTheme.primaryPurple : AppTheme.textTertiary);
    final color = isStale ? baseColor.withValues(alpha: 0.5) : baseColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : color,
          width: isSelected ? 3 : 2,
          strokeAlign: isStale
              ? BorderSide.strokeAlignOutside
              : BorderSide.strokeAlignCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isStale ? 0.2 : 0.4),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            node.shortName?.substring(0, 1).toUpperCase() ??
                node.nodeNum.toString().substring(0, 1),
            style: TextStyle(
              fontSize: isSelected ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: isStale ? 0.7 : 1.0),
            ),
          ),
          // Stale indicator (small question mark overlay)
          if (isStale)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.darkCard, width: 1.5),
                ),
                child: const Center(
                  child: Text(
                    '?',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Node list panel sliding from left
class _NodeListPanel extends StatelessWidget {
  final List<_NodeWithPosition> nodesWithPosition;
  final int? myNodeNum;
  final MeshNode? selectedNode;
  final void Function(_NodeWithPosition) onNodeSelected;
  final VoidCallback onClose;
  final double? Function(_NodeWithPosition) calculateDistanceFromMe;

  const _NodeListPanel({
    required this.nodesWithPosition,
    required this.myNodeNum,
    required this.selectedNode,
    required this.onNodeSelected,
    required this.onClose,
    required this.calculateDistanceFromMe,
  });

  @override
  Widget build(BuildContext context) {
    // Sort: my node first, then by distance from me, then alphabetically
    final sortedNodes = List<_NodeWithPosition>.from(nodesWithPosition);
    sortedNodes.sort((a, b) {
      // My node always first
      if (a.node.nodeNum == myNodeNum) return -1;
      if (b.node.nodeNum == myNodeNum) return 1;

      // Then by distance from me
      final distA = calculateDistanceFromMe(a);
      final distB = calculateDistanceFromMe(b);
      if (distA != null && distB != null) {
        return distA.compareTo(distB);
      }
      if (distA != null) return -1;
      if (distB != null) return 1;

      // Finally alphabetically
      return a.node.displayName.compareTo(b.node.displayName);
    });

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        border: Border(
          right: BorderSide(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
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
                  color: AppTheme.darkBorder.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.list,
                  size: 20,
                  color: AppTheme.primaryMagenta,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Nodes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${sortedNodes.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textTertiary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppTheme.textTertiary,
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          // Node list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: sortedNodes.length,
              itemBuilder: (context, index) {
                final nodeWithPos = sortedNodes[index];
                final isMyNode = nodeWithPos.node.nodeNum == myNodeNum;
                final isSelected =
                    selectedNode?.nodeNum == nodeWithPos.node.nodeNum;
                final distance = calculateDistanceFromMe(nodeWithPos);

                return _NodeListItem(
                  nodeWithPos: nodeWithPos,
                  isMyNode: isMyNode,
                  isSelected: isSelected,
                  distance: distance,
                  onTap: () => onNodeSelected(nodeWithPos),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual node item in the list
class _NodeListItem extends StatelessWidget {
  final _NodeWithPosition nodeWithPos;
  final bool isMyNode;
  final bool isSelected;
  final double? distance;
  final VoidCallback onTap;

  const _NodeListItem({
    required this.nodeWithPos,
    required this.isMyNode,
    required this.isSelected,
    required this.distance,
    required this.onTap,
  });

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()}m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)}km';
    } else {
      return '${km.round()}km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final node = nodeWithPos.node;
    final baseColor = isMyNode
        ? AppTheme.primaryMagenta
        : (node.isOnline ? AppTheme.primaryPurple : AppTheme.textTertiary);

    return Material(
      color: isSelected
          ? AppTheme.primaryMagenta.withValues(alpha: 0.15)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Node indicator
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: baseColor.withValues(
                    alpha: nodeWithPos.isStale ? 0.3 : 0.2,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: baseColor.withValues(
                      alpha: nodeWithPos.isStale ? 0.4 : 0.6,
                    ),
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      node.shortName?.substring(0, 1).toUpperCase() ??
                          node.nodeNum.toString().substring(0, 1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: baseColor,
                      ),
                    ),
                    if (nodeWithPos.isStale)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppTheme.warningYellow,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.darkCard,
                              width: 1.5,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '?',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Node info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            node.displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (node.isOnline
                                        ? Colors.white
                                        : AppTheme.textSecondary),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMyNode) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryMagenta.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryMagenta,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Online/offline status
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: node.isOnline
                                ? AppTheme.successGreen
                                : AppTheme.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          node.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        if (nodeWithPos.isStale) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• Last known',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.warningYellow.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Distance badge
              if (distance != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDistance(distance!),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              // Arrow indicator
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isSelected
                    ? AppTheme.primaryMagenta
                    : AppTheme.textTertiary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Info card shown when a node is selected
class _NodeInfoCard extends ConsumerWidget {
  final MeshNode node;
  final bool isMyNode;
  final VoidCallback onClose;
  final VoidCallback onMessage;
  final double? distanceFromMe;

  const _NodeInfoCard({
    required this.node,
    required this.isMyNode,
    required this.onClose,
    required this.onMessage,
    this.distanceFromMe,
  });

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()}m away';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)}km away';
    } else {
      return '${km.round()}km away';
    }
  }

  Future<void> _exchangePositions(BuildContext context, WidgetRef ref) async {
    final protocol = ref.read(protocolServiceProvider);

    try {
      await protocol.requestPosition(node.nodeNum);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Position requested from ${node.displayName}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Node avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    node.shortName?.substring(0, 2).toUpperCase() ?? '??',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                        Flexible(
                          child: Text(
                            node.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMyNode) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryMagenta.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryMagenta,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          node.userId ?? '!${node.nodeNum.toRadixString(16)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
                          ),
                        ),
                        if (distanceFromMe != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: AppTheme.textTertiary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDistance(distanceFromMe!),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryMagenta,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: AppTheme.textTertiary,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Row(
            children: [
              if (node.batteryLevel != null) ...[
                _StatChip(
                  icon: Icons.battery_full,
                  value: '${node.batteryLevel}%',
                  color: _getBatteryColor(node.batteryLevel!),
                ),
                const SizedBox(width: 8),
              ],
              if (node.snr != null) ...[
                _StatChip(
                  icon: Icons.signal_cellular_alt,
                  value: '${node.snr} dB',
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
              ],
              if (node.altitude != null)
                _StatChip(
                  icon: Icons.terrain,
                  value: '${node.altitude}m',
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
          if (!isMyNode) ...[
            const SizedBox(height: 12),
            // Action buttons row
            Row(
              children: [
                // Exchange position button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exchangePositions(context, ref),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Position'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryMagenta,
                      side: BorderSide(
                        color: AppTheme.primaryMagenta.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Message button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onMessage,
                    icon: const Icon(Icons.message, size: 18),
                    label: const Text('Message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryMagenta,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 50) return AppTheme.successGreen;
    if (level > 20) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Zoom control buttons widget
class _ZoomControls extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFitAll;

  const _ZoomControls({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Zoom in
          _ZoomButton(
            icon: Icons.add,
            onPressed: currentZoom < maxZoom ? onZoomIn : null,
            isTop: true,
          ),
          Container(
            height: 1,
            width: 32,
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
          ),
          // Zoom out
          _ZoomButton(
            icon: Icons.remove,
            onPressed: currentZoom > minZoom ? onZoomOut : null,
          ),
          Container(
            height: 1,
            width: 32,
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
          ),
          // Fit all nodes
          _ZoomButton(
            icon: Icons.fit_screen,
            onPressed: onFitAll,
            isBottom: true,
            tooltip: 'Fit all nodes',
          ),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isTop;
  final bool isBottom;
  final String? tooltip;

  const _ZoomButton({
    required this.icon,
    required this.onPressed,
    this.isTop = false,
    this.isBottom = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.vertical(
          top: isTop ? const Radius.circular(12) : Radius.zero,
          bottom: isBottom ? const Radius.circular(12) : Radius.zero,
        ),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null
                ? AppTheme.textSecondary
                : AppTheme.textTertiary.withValues(alpha: 0.5),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
