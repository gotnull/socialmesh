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

  // Animation controller for smooth camera movements
  AnimationController? _animationController;

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

  Future<void> _refreshPositions() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();

      // Show feedback
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
      // Wait a bit before allowing another refresh
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // Debug flag for map logging
  static const bool _debugMapLogging = false;

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // === MAP DEBUG LOGGING (controlled by flag) ===
    if (_debugMapLogging) {
      debugPrint('🗺️ === MAP SCREEN BUILD ===');
      debugPrint('🗺️ Total nodes: ${nodes.length}');
      debugPrint('🗺️ My node num: $myNodeNum');

      // Log ALL nodes with their position status
      for (final node in nodes.values) {
        final hasPos = node.hasPosition;
        final lat = node.latitude;
        final lng = node.longitude;
        debugPrint(
          '🗺️ Node ${node.nodeNum.toRadixString(16)} "${node.longName}": '
          'hasPosition=$hasPos, lat=$lat, lng=$lng',
        );
      }
    }

    // Filter nodes with valid positions
    final nodesWithPosition = nodes.values
        .where((node) => node.hasPosition)
        .toList();

    if (_debugMapLogging) {
      debugPrint('🗺️ Nodes with valid position: ${nodesWithPosition.length}');
      for (final node in nodesWithPosition) {
        debugPrint(
          '🗺️ ✅ Valid: ${node.nodeNum.toRadixString(16)} at '
          '${node.latitude}, ${node.longitude}',
        );
      }
      debugPrint('🗺️ === END MAP DEBUG ===');
    }

    // Calculate center point
    LatLng center = const LatLng(0, 0);
    double zoom = 2.0;

    if (nodesWithPosition.isNotEmpty) {
      // Center on my node if available, otherwise average of all nodes
      final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
      if (myNode?.hasPosition == true) {
        center = LatLng(myNode!.latitude!, myNode.longitude!);
        zoom = 14.0;
      } else {
        double avgLat = 0, avgLng = 0;
        for (final node in nodesWithPosition) {
          avgLat += node.latitude!;
          avgLng += node.longitude!;
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
            onPressed: () => _centerOnMyNode(nodes, myNodeNum),
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
                    minZoom: 4, // Prevent zooming out too far
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
                    onTap: (_, __) => setState(() => _selectedNode = null),
                  ),
                  children: [
                    // Dark map tiles with smooth fade
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
                    // Heatmap layer (simplified as circles with opacity)
                    if (_showHeatmap)
                      CircleLayer(
                        circles: nodesWithPosition.map((node) {
                          return CircleMarker(
                            point: LatLng(node.latitude!, node.longitude!),
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
                    // Connection lines between nodes
                    PolylineLayer(
                      polylines: _buildConnectionLines(nodesWithPosition),
                    ),
                    // Node markers
                    MarkerLayer(
                      markers: nodesWithPosition.map((node) {
                        final isMyNode = node.nodeNum == myNodeNum;
                        final isSelected =
                            _selectedNode?.nodeNum == node.nodeNum;
                        return Marker(
                          point: LatLng(node.latitude!, node.longitude!),
                          width: isSelected ? 56 : 44,
                          height: isSelected ? 56 : 44,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedNode = node);
                            },
                            child: _NodeMarker(
                              node: node,
                              isMyNode: isMyNode,
                              isSelected: isSelected,
                            ),
                          ),
                        );
                      }).toList(),
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
                    ),
                  ),
                // Node count indicator
                Positioned(
                  left: 16,
                  top: 16,
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
                          '${nodesWithPosition.length} nodes on map',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
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

  void _fitAllNodes(List<MeshNode> nodes) {
    if (nodes.isEmpty) return;

    // Calculate bounds
    double minLat = nodes.first.latitude!;
    double maxLat = nodes.first.latitude!;
    double minLng = nodes.first.longitude!;
    double maxLng = nodes.first.longitude!;

    for (final node in nodes) {
      if (node.latitude! < minLat) minLat = node.latitude!;
      if (node.latitude! > maxLat) maxLat = node.latitude!;
      if (node.longitude! < minLng) minLng = node.longitude!;
      if (node.longitude! > maxLng) maxLng = node.longitude!;
    }

    // Add padding
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

    // Get the fitted camera
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

  List<Polyline> _buildConnectionLines(List<MeshNode> nodes) {
    // Create lines between nearby nodes to visualize the mesh
    final lines = <Polyline>[];
    const maxDistanceKm = 10.0; // Only show connections within 10km

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];

        final distance = const Distance().as(
          LengthUnit.Kilometer,
          LatLng(node1.latitude!, node1.longitude!),
          LatLng(node2.latitude!, node2.longitude!),
        );

        if (distance <= maxDistanceKm) {
          lines.add(
            Polyline(
              points: [
                LatLng(node1.latitude!, node1.longitude!),
                LatLng(node2.latitude!, node2.longitude!),
              ],
              color: AppTheme.primaryPurple.withValues(alpha: 0.3),
              strokeWidth: 1.5,
            ),
          );
        }
      }
    }

    return lines;
  }

  void _centerOnMyNode(Map<int, MeshNode> nodes, int? myNodeNum) {
    if (myNodeNum == null) return;
    final myNode = nodes[myNodeNum];
    if (myNode?.hasPosition == true) {
      _animatedMove(LatLng(myNode!.latitude!, myNode.longitude!), 14.0);
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

/// Custom marker widget for nodes
class _NodeMarker extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final bool isSelected;

  const _NodeMarker({
    required this.node,
    required this.isMyNode,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = isMyNode
        ? AppTheme.primaryMagenta
        : (node.isOnline ? AppTheme.primaryPurple : AppTheme.textTertiary);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.white : color,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Center(
        child: Text(
          node.shortName?.substring(0, 1).toUpperCase() ??
              node.nodeNum.toString().substring(0, 1),
          style: TextStyle(
            fontSize: isSelected ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
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

  const _NodeInfoCard({
    required this.node,
    required this.isMyNode,
    required this.onClose,
    required this.onMessage,
  });

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
                    Text(
                      node.userId ?? '!${node.nodeNum.toRadixString(16)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
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
