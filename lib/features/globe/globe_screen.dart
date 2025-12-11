import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/widgets/mesh_globe.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Screen showing the 3D mesh globe with node positions
class GlobeScreen extends ConsumerStatefulWidget {
  /// Optional node number to focus on initially
  final int? initialNodeNum;

  const GlobeScreen({super.key, this.initialNodeNum});

  @override
  ConsumerState<GlobeScreen> createState() => _GlobeScreenState();
}

class _GlobeScreenState extends ConsumerState<GlobeScreen> {
  final GlobalKey<MeshGlobeState> _globeKey = GlobalKey();
  GlobeNodeMarker? _selectedNode;
  bool _showConnections = true;

  @override
  void initState() {
    super.initState();
    // Focus on initial node after a short delay to let globe initialize
    if (widget.initialNodeNum != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _focusOnNode(widget.initialNodeNum!);
      });
    }
  }

  void _focusOnNode(int nodeNum) {
    final nodes = ref.read(nodesProvider);
    final node = nodes[nodeNum];
    if (node != null && node.hasPosition) {
      final marker = GlobeNodeMarker.fromNode(node);
      _globeKey.currentState?.rotateToNode(marker);
      setState(() {
        _selectedNode = marker;
      });
    }
  }

  List<GlobeNodeMarker> _getMarkers(Map<int, MeshNode> nodes) {
    return nodes.values
        .where((node) => node.hasPosition)
        .map((node) => GlobeNodeMarker.fromNode(node))
        .toList();
  }

  List<GlobeConnection> _getConnections(List<GlobeNodeMarker> markers) {
    if (!_showConnections || markers.length < 2) return [];

    // Create connections between all nodes
    // In a real implementation, this would be based on actual mesh connections
    final connections = <GlobeConnection>[];

    for (int i = 0; i < markers.length - 1; i++) {
      for (int j = i + 1; j < markers.length; j++) {
        final distance = _calculateDistance(
          markers[i].latitude,
          markers[i].longitude,
          markers[j].latitude,
          markers[j].longitude,
        );
        connections.add(
          GlobeConnection(from: markers[i], to: markers[j], distance: distance),
        );
      }
    }

    return connections;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    // Haversine formula for distance in km
    const earthRadius = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  void _onNodeSelected(GlobeNodeMarker marker) {
    setState(() {
      _selectedNode = marker;
    });
    _globeKey.currentState?.rotateToNode(marker);
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final markers = _getMarkers(nodes);
    final connections = _getConnections(markers);
    final myNodeNum = ref.watch(myNodeNumProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Mesh Globe'),
        actions: [
          // Toggle connections
          IconButton(
            icon: Icon(
              _showConnections ? Icons.link : Icons.link_off,
              color: _showConnections
                  ? context.accentColor
                  : AppTheme.textTertiary,
            ),
            onPressed: () {
              setState(() {
                _showConnections = !_showConnections;
              });
            },
            tooltip: _showConnections ? 'Hide connections' : 'Show connections',
          ),
          // Reset view
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () {
              _globeKey.currentState?.rotateToLocation(0, 0);
              setState(() {
                _selectedNode = null;
              });
            },
            tooltip: 'Reset view',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Globe - needs to fill the entire space
          Positioned.fill(
            child: MeshGlobe(
              key: _globeKey,
              markers: markers,
              connections: connections,
              onNodeSelected: _onNodeSelected,
              autoRotateSpeed: _selectedNode == null ? 0.2 : 0.0,
              baseColor: const Color(0xFF16213e),
              dotColor: const Color(0xFF4a5568),
              markerColor: context.accentColor,
              connectionColor: context.accentColor.withAlpha(150),
            ),
          ),

          // Node list overlay
          Positioned(
            left: 16,
            top: 16,
            bottom: 100,
            width: 200,
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard.withAlpha(200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.public,
                          size: 16,
                          color: context.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${markers.length} nodes',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.darkBorder),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: markers.length,
                      itemBuilder: (context, index) {
                        final marker = markers[index];
                        final isSelected =
                            _selectedNode?.nodeNum == marker.nodeNum;
                        final isMyNode = marker.nodeNum == myNodeNum;

                        return InkWell(
                          onTap: () => _onNodeSelected(marker),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            color: isSelected
                                ? context.accentColor.withAlpha(30)
                                : null,
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: marker.color,
                                    shape: BoxShape.circle,
                                    boxShadow: marker.isOnline
                                        ? [
                                            BoxShadow(
                                              color: marker.color.withAlpha(
                                                100,
                                              ),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    marker.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? context.accentColor
                                          : AppTheme.textPrimary,
                                      fontSize: 12,
                                      fontFamily: 'JetBrainsMono',
                                      fontWeight: isMyNode
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMyNode)
                                  Icon(
                                    Icons.person,
                                    size: 12,
                                    color: context.accentColor,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected node info panel
          if (_selectedNode != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard.withAlpha(230),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.accentColor.withAlpha(100)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _selectedNode!.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedNode!.name,
                          style: TextStyle(
                            color: context.accentColor,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'JetBrainsMono',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${_selectedNode!.latitude.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                    Text(
                      'Lon: ${_selectedNode!.longitude.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'JetBrainsMono',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _selectedNode!.isOnline ? Icons.wifi : Icons.wifi_off,
                          size: 14,
                          color: _selectedNode!.isOnline
                              ? AppTheme.successGreen
                              : AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _selectedNode!.isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: _selectedNode!.isOnline
                                ? AppTheme.successGreen
                                : AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Empty state
          if (markers.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.public,
                    size: 64,
                    color: AppTheme.textTertiary.withAlpha(100),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No nodes with GPS',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nodes with position data will appear here',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
