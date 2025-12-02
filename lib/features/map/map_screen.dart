import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../messaging/messaging_screen.dart';

/// Map tile style options
enum MapTileStyle {
  dark('Dark', 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'),
  satellite(
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  ),
  terrain('Terrain', 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png'),
  light(
    'Light',
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
  );

  final String label;
  final String url;
  const MapTileStyle(this.label, this.url);
}

/// Node filter options
enum NodeFilter {
  all('All'),
  online('Online'),
  offline('Offline'),
  withGps('With GPS'),
  inRange('In Range');

  final String label;
  const NodeFilter(this.label);
}

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
  bool _showFilters = false;
  bool _measureMode = false;
  bool _showRangeCircles = false;
  String _searchQuery = '';

  // Map style
  MapTileStyle _mapStyle = MapTileStyle.dark;

  // Filtering
  NodeFilter _nodeFilter = NodeFilter.all;

  // Measurement points
  LatLng? _measureStart;
  LatLng? _measureEnd;

  // Waypoints dropped by user
  final List<_Waypoint> _waypoints = [];

  // Animation controller for smooth camera movements
  AnimationController? _animationController;

  // Compass rotation
  double _mapRotation = 0.0;

  // Track last known positions for nodes (to handle GPS loss gracefully)
  final Map<int, _CachedPosition> _positionCache = {};

  // Trail history for moving nodes
  final Map<int, List<_TrailPoint>> _nodeTrails = {};

  // Search controller
  final TextEditingController _searchController = TextEditingController();

  // Layout constants for consistent spacing
  static const double _mapPadding = 16.0;
  static const double _controlSpacing = 8.0;
  static const double _controlSize = 44.0;
  static const double _zoomControlsHeight =
      136.0; // 3 buttons × 44 + 2 dividers

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Animate camera to a specific location with smooth easing
  void _animatedMove(LatLng destLocation, double destZoom, {double? rotation}) {
    _animationController?.dispose();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    final startZoom = _mapController.camera.zoom;
    final startCenter = _mapController.camera.center;
    final startRotation = _mapController.camera.rotation;

    final latTween = Tween<double>(
      begin: startCenter.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: startCenter.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(begin: startZoom, end: destZoom);
    final rotationTween = Tween<double>(
      begin: startRotation,
      end: rotation ?? startRotation,
    );

    final animation = CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeOutCubic,
    );

    _animationController!.addListener(() {
      _mapController.moveAndRotate(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
        rotationTween.evaluate(animation),
      );
    });

    _animationController!.forward();
  }

  /// Update position cache and return nodes with valid (current or cached) positions
  List<_NodeWithPosition> _getNodesWithPositions(Map<int, MeshNode> nodes) {
    final result = <_NodeWithPosition>[];
    final now = DateTime.now();

    const staleThreshold = Duration(minutes: 30);

    for (final node in nodes.values) {
      if (node.hasPosition) {
        // Update trail history
        _updateNodeTrail(node.nodeNum, node.latitude!, node.longitude!);

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
        final cached = _positionCache[node.nodeNum]!;
        final age = now.difference(cached.timestamp);
        final isStale = age > staleThreshold;

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

    _positionCache.removeWhere((nodeNum, _) => !nodes.containsKey(nodeNum));

    return result;
  }

  /// Update trail history for a node
  void _updateNodeTrail(int nodeNum, double lat, double lng) {
    final trails = _nodeTrails[nodeNum] ?? [];
    final now = DateTime.now();

    // Only add if position changed significantly (> 10 meters)
    if (trails.isEmpty ||
        const Distance().as(
              LengthUnit.Meter,
              LatLng(trails.last.latitude, trails.last.longitude),
              LatLng(lat, lng),
            ) >
            10) {
      trails.add(_TrailPoint(latitude: lat, longitude: lng, timestamp: now));

      // Keep only last 50 points (or last hour)
      while (trails.length > 50 ||
          (trails.isNotEmpty &&
              now.difference(trails.first.timestamp) >
                  const Duration(hours: 1))) {
        trails.removeAt(0);
      }

      _nodeTrails[nodeNum] = trails;
    }
  }

  /// Filter nodes based on current filter
  List<_NodeWithPosition> _filterNodes(
    List<_NodeWithPosition> nodes,
    int? myNodeNum,
  ) {
    var filtered = nodes;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((n) {
        final name = n.node.displayName.toLowerCase();
        final id = n.node.userId?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    }

    // Apply node filter
    switch (_nodeFilter) {
      case NodeFilter.all:
        break;
      case NodeFilter.online:
        filtered = filtered.where((n) => n.node.isOnline).toList();
        break;
      case NodeFilter.offline:
        filtered = filtered.where((n) => !n.node.isOnline).toList();
        break;
      case NodeFilter.withGps:
        filtered = filtered.where((n) => !n.isStale).toList();
        break;
      case NodeFilter.inRange:
        if (myNodeNum != null) {
          final myNode = nodes
              .where((n) => n.node.nodeNum == myNodeNum)
              .firstOrNull;
          if (myNode != null) {
            filtered = filtered.where((n) {
              if (n.node.nodeNum == myNodeNum) return true;
              final dist = _calculateDistance(
                myNode.latitude,
                myNode.longitude,
                n.latitude,
                n.longitude,
              );
              return dist <= 15.0; // Within 15km
            }).toList();
          }
        }
        break;
    }

    return filtered;
  }

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

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()}m';
    } else if (km < 10) {
      return '${km.toStringAsFixed(1)}km';
    } else {
      return '${km.round()}km';
    }
  }

  /// Calculate bearing from one point to another
  double _calculateBearing(double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * math.pi / 180;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;

    final x = math.sin(dLng) * math.cos(lat2Rad);
    final y =
        math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLng);

    final bearing = math.atan2(x, y) * 180 / math.pi;
    return (bearing + 360) % 360;
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

  void _addWaypoint(LatLng point) {
    setState(() {
      _waypoints.add(
        _Waypoint(
          id: DateTime.now().millisecondsSinceEpoch,
          position: point,
          label: 'WP ${_waypoints.length + 1}',
        ),
      );
    });
    HapticFeedback.mediumImpact();
  }

  void _removeWaypoint(int id) {
    setState(() {
      _waypoints.removeWhere((w) => w.id == id);
    });
  }

  void _shareLocation(LatLng point, {String? label}) {
    final lat = point.latitude.toStringAsFixed(6);
    final lng = point.longitude.toStringAsFixed(6);
    final text = label != null
        ? '$label\nhttps://maps.google.com/?q=$lat,$lng'
        : 'https://maps.google.com/?q=$lat,$lng';
    Share.share(text);
  }

  void _copyCoordinates(LatLng point) {
    final lat = point.latitude.toStringAsFixed(6);
    final lng = point.longitude.toStringAsFixed(6);
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordinates copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Get nodes with positions (current or cached)
    final allNodesWithPosition = _getNodesWithPositions(nodes);
    final nodesWithPosition = _filterNodes(allNodesWithPosition, myNodeNum);

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
          // Search toggle
          IconButton(
            icon: Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.search,
              color: _searchQuery.isNotEmpty
                  ? AppTheme.primaryMagenta
                  : AppTheme.textSecondary,
            ),
            onPressed: () => _showSearchDialog(),
            tooltip: 'Search nodes',
          ),
          // Filter toggle
          IconButton(
            icon: Icon(
              _nodeFilter != NodeFilter.all
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined,
              color: _nodeFilter != NodeFilter.all
                  ? AppTheme.primaryMagenta
                  : AppTheme.textSecondary,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Filter nodes',
          ),
          // Map style
          PopupMenuButton<MapTileStyle>(
            icon: const Icon(Icons.map, color: AppTheme.textSecondary),
            tooltip: 'Map style',
            onSelected: (style) => setState(() => _mapStyle = style),
            itemBuilder: (context) => MapTileStyle.values.map((style) {
              return PopupMenuItem(
                value: style,
                child: Row(
                  children: [
                    Icon(
                      _mapStyle == style ? Icons.check : Icons.map_outlined,
                      size: 18,
                      color: _mapStyle == style
                          ? AppTheme.primaryMagenta
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(style.label),
                  ],
                ),
              );
            }).toList(),
          ),
          // More options menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'refresh':
                  _refreshPositions();
                  break;
                case 'heatmap':
                  setState(() => _showHeatmap = !_showHeatmap);
                  break;
                case 'range':
                  setState(() => _showRangeCircles = !_showRangeCircles);
                  break;
                case 'measure':
                  setState(() {
                    _measureMode = !_measureMode;
                    _measureStart = null;
                    _measureEnd = null;
                  });
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 18,
                      color: _isRefreshing
                          ? AppTheme.textTertiary
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(_isRefreshing ? 'Refreshing...' : 'Refresh positions'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'heatmap',
                child: Row(
                  children: [
                    Icon(
                      _showHeatmap ? Icons.layers : Icons.layers_outlined,
                      size: 18,
                      color: _showHeatmap
                          ? AppTheme.primaryMagenta
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(_showHeatmap ? 'Hide heatmap' : 'Show heatmap'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'range',
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 18,
                      color: _showRangeCircles
                          ? AppTheme.primaryMagenta
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _showRangeCircles
                          ? 'Hide range circles'
                          : 'Show range circles',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'measure',
                child: Row(
                  children: [
                    Icon(
                      Icons.straighten,
                      size: 18,
                      color: _measureMode
                          ? AppTheme.primaryMagenta
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _measureMode ? 'Exit measure mode' : 'Measure distance',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: allNodesWithPosition.isEmpty
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
                      flags: InteractiveFlag.all,
                      pinchZoomThreshold: 0.5,
                      scrollWheelVelocity: 0.005,
                    ),
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture) {
                        setState(() {
                          _currentZoom = position.zoom;
                          _mapRotation = position.rotation;
                        });
                      }
                    },
                    onTap: (tapPos, point) {
                      if (_measureMode) {
                        _handleMeasureTap(point);
                      } else {
                        setState(() {
                          _selectedNode = null;
                          _showNodeList = false;
                          _showFilters = false;
                        });
                      }
                    },
                    onLongPress: (tapPos, point) {
                      if (!_measureMode) {
                        _showWaypointMenu(point);
                      }
                    },
                  ),
                  children: [
                    // Map tiles
                    TileLayer(
                      urlTemplate: _mapStyle.url,
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.protofluff.app',
                      retinaMode: _mapStyle != MapTileStyle.satellite,
                      tileBuilder: (context, tileWidget, tile) {
                        return AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: tileWidget,
                        );
                      },
                    ),
                    // Range circles (theoretical coverage)
                    if (_showRangeCircles)
                      CircleLayer(
                        circles: nodesWithPosition.map((n) {
                          final isMyNode = n.node.nodeNum == myNodeNum;
                          return CircleMarker(
                            point: LatLng(n.latitude, n.longitude),
                            radius: 5000, // 5km range circle
                            useRadiusInMeter: true,
                            color:
                                (isMyNode
                                        ? AppTheme.primaryMagenta
                                        : AppTheme.primaryPurple)
                                    .withValues(alpha: 0.08),
                            borderColor:
                                (isMyNode
                                        ? AppTheme.primaryMagenta
                                        : AppTheme.primaryPurple)
                                    .withValues(alpha: 0.2),
                            borderStrokeWidth: 1,
                          );
                        }).toList(),
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
                    // Node trails (movement history)
                    PolylineLayer(
                      polylines: _buildNodeTrails(nodesWithPosition, myNodeNum),
                    ),
                    // Connection lines
                    PolylineLayer(
                      polylines: _buildConnectionLines(
                        nodesWithPosition,
                        myNodeNum,
                      ),
                    ),
                    // Measurement line
                    if (_measureStart != null && _measureEnd != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [_measureStart!, _measureEnd!],
                            color: AppTheme.warningYellow,
                            strokeWidth: 3,
                            pattern: const StrokePattern.dotted(
                              spacingFactor: 1.5,
                            ),
                          ),
                        ],
                      ),
                    // Waypoint markers
                    MarkerLayer(
                      markers: _waypoints.map((w) {
                        return Marker(
                          point: w.position,
                          width: 32,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showWaypointDetails(w),
                            child: Column(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningYellow,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.place,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 12,
                                  color: AppTheme.warningYellow,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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
                    // Measurement markers
                    if (_measureStart != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _measureStart!,
                            width: 20,
                            height: 20,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.warningYellow,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  'A',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_measureEnd != null)
                            Marker(
                              point: _measureEnd!,
                              width: 20,
                              height: 20,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.warningYellow,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'B',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
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
                // Filter bar
                if (_showFilters)
                  Positioned(
                    left: _mapPadding,
                    right: _mapPadding + _controlSize + _controlSpacing,
                    top: _mapPadding,
                    child: _FilterBar(
                      currentFilter: _nodeFilter,
                      onFilterChanged: (filter) =>
                          setState(() => _nodeFilter = filter),
                      totalCount: allNodesWithPosition.length,
                      filteredCount: nodesWithPosition.length,
                    ),
                  ),
                // Measurement card (shown at bottom when measurement complete)
                if (_measureMode &&
                    _measureStart != null &&
                    _measureEnd != null)
                  Positioned(
                    left: _mapPadding,
                    right: _mapPadding,
                    bottom: _selectedNode != null ? 220 : _mapPadding,
                    child: _MeasurementCard(
                      start: _measureStart!,
                      end: _measureEnd!,
                      onClear: () => setState(() {
                        _measureStart = null;
                        _measureEnd = null;
                      }),
                      onShare: () => _shareLocation(
                        _measureStart!,
                        label:
                            'Distance: ${_formatDistance(_calculateDistance(_measureStart!.latitude, _measureStart!.longitude, _measureEnd!.latitude, _measureEnd!.longitude))}',
                      ),
                    ),
                  ),
                // Mode indicator (centered at top)
                if (_measureMode &&
                    (_measureStart == null || _measureEnd == null))
                  Positioned(
                    top: _mapPadding,
                    left: _mapPadding + 140, // Leave room for node count badge
                    right: _mapPadding + _controlSize + _controlSpacing,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warningYellow,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.straighten,
                              size: 16,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _measureStart == null
                                  ? 'Tap to set start point'
                                  : 'Tap to set end point',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Node info card
                if (_selectedNode != null)
                  Positioned(
                    left: _mapPadding,
                    right: _mapPadding,
                    bottom: _mapPadding,
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
                      bearingFromMe: _getBearingFromMyNode(
                        _selectedNode!,
                        nodesWithPosition,
                        myNodeNum,
                      ),
                      onShareLocation: () {
                        final nodeWithPos = nodesWithPosition
                            .where(
                              (n) => n.node.nodeNum == _selectedNode!.nodeNum,
                            )
                            .firstOrNull;
                        if (nodeWithPos != null) {
                          _shareLocation(
                            LatLng(nodeWithPos.latitude, nodeWithPos.longitude),
                            label: _selectedNode!.displayName,
                          );
                        }
                      },
                      onCopyCoordinates: () {
                        final nodeWithPos = nodesWithPosition
                            .where(
                              (n) => n.node.nodeNum == _selectedNode!.nodeNum,
                            )
                            .firstOrNull;
                        if (nodeWithPos != null) {
                          _copyCoordinates(
                            LatLng(nodeWithPos.latitude, nodeWithPos.longitude),
                          );
                        }
                      },
                    ),
                  ),
                // Node list panel
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _showNodeList ? 0 : -300,
                  top: 0,
                  bottom: 0,
                  width: 300,
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
                    searchController: _searchController,
                    onSearchChanged: (query) =>
                        setState(() => _searchQuery = query),
                  ),
                ),
                // Node count indicator
                if (!_showNodeList && !_showFilters)
                  Positioned(
                    left: _mapPadding,
                    top: _mapPadding,
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
                              '${nodesWithPosition.length}${nodesWithPosition.length != allNodesWithPosition.length ? '/${allNodesWithPosition.length}' : ''} nodes',
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
                // Compass
                Positioned(
                  right: _mapPadding,
                  top: _mapPadding,
                  child: _Compass(
                    rotation: _mapRotation,
                    onPressed: () => _animatedMove(
                      _mapController.camera.center,
                      _currentZoom,
                      rotation: 0,
                    ),
                  ),
                ),
                // Zoom controls
                Positioned(
                  right: _mapPadding,
                  top: _mapPadding + _controlSize + _controlSpacing,
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
                // Navigation buttons (center on me, reset north)
                Positioned(
                  right: _mapPadding,
                  top:
                      _mapPadding +
                      _controlSize +
                      _controlSpacing +
                      _zoomControlsHeight +
                      _controlSpacing,
                  child: _NavigationControls(
                    onCenterOnMe: () =>
                        _centerOnMyNode(nodesWithPosition, myNodeNum),
                    onResetNorth: () => _animatedMove(
                      _mapController.camera.center,
                      _currentZoom,
                      rotation: 0,
                    ),
                    hasMyNode: nodesWithPosition.any(
                      (n) => n.node.nodeNum == myNodeNum,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _handleMeasureTap(LatLng point) {
    setState(() {
      if (_measureStart == null) {
        _measureStart = point;
        _measureEnd = null;
      } else if (_measureEnd == null) {
        _measureEnd = point;
      } else {
        _measureStart = point;
        _measureEnd = null;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text(
          'Search Nodes',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter node name or ID...',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
            prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.clear,
                      color: AppTheme.textSecondary,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppTheme.darkBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showWaypointMenu(LatLng point) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.add_location,
                  color: AppTheme.warningYellow,
                ),
                title: const Text(
                  'Drop Waypoint',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _addWaypoint(point);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.share,
                  color: AppTheme.primaryMagenta,
                ),
                title: const Text(
                  'Share Location',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _shareLocation(point);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: AppTheme.textSecondary),
                title: const Text(
                  'Copy Coordinates',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _copyCoordinates(point);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWaypointDetails(_Waypoint waypoint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                waypoint.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${waypoint.position.latitude.toStringAsFixed(6)}, ${waypoint.position.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.share,
                  color: AppTheme.primaryMagenta,
                ),
                title: const Text(
                  'Share',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _shareLocation(waypoint.position, label: waypoint.label);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: AppTheme.textSecondary),
                title: const Text(
                  'Copy Coordinates',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _copyCoordinates(waypoint.position);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppTheme.errorRed),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeWaypoint(waypoint.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _getBearingFromMyNode(
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

    return _calculateBearing(
      myNodeWithPos.latitude,
      myNodeWithPos.longitude,
      nodeWithPos.latitude,
      nodeWithPos.longitude,
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

  /// Build node movement trails
  List<Polyline> _buildNodeTrails(
    List<_NodeWithPosition> nodes,
    int? myNodeNum,
  ) {
    final trails = <Polyline>[];

    for (final node in nodes) {
      final trail = _nodeTrails[node.node.nodeNum];
      if (trail == null || trail.length < 2) continue;

      final isMyNode = node.node.nodeNum == myNodeNum;
      final points = trail.map((t) => LatLng(t.latitude, t.longitude)).toList();

      trails.add(
        Polyline(
          points: points,
          color: (isMyNode ? AppTheme.primaryMagenta : AppTheme.primaryPurple)
              .withValues(alpha: 0.4),
          strokeWidth: 2,
          pattern: const StrokePattern.dotted(spacingFactor: 1.5),
        ),
      );
    }

    return trails;
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

/// Trail point for node movement history
class _TrailPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  _TrailPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

/// Waypoint dropped by user
class _Waypoint {
  final int id;
  final LatLng position;
  final String label;

  _Waypoint({required this.id, required this.position, required this.label});
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
  final TextEditingController searchController;
  final void Function(String) onSearchChanged;

  const _NodeListPanel({
    required this.nodesWithPosition,
    required this.myNodeNum,
    required this.selectedNode,
    required this.onNodeSelected,
    required this.onClose,
    required this.calculateDistanceFromMe,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Sort: my node first, then by distance from me, then alphabetically
    final sortedNodes = List<_NodeWithPosition>.from(nodesWithPosition);
    sortedNodes.sort((a, b) {
      if (a.node.nodeNum == myNodeNum) return -1;
      if (b.node.nodeNum == myNodeNum) return 1;

      final distA = calculateDistanceFromMe(a);
      final distB = calculateDistanceFromMe(b);
      if (distA != null && distB != null) {
        return distA.compareTo(distB);
      }
      if (distA != null) return -1;
      if (distB != null) return 1;

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
          // Search field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search nodes...',
                hintStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        color: AppTheme.textSecondary,
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.darkBackground,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          // Node list
          Expanded(
            child: sortedNodes.isEmpty
                ? Center(
                    child: Text(
                      'No nodes found',
                      style: TextStyle(color: AppTheme.textTertiary),
                    ),
                  )
                : ListView.builder(
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
  final double? bearingFromMe;
  final VoidCallback onShareLocation;
  final VoidCallback onCopyCoordinates;

  const _NodeInfoCard({
    required this.node,
    required this.isMyNode,
    required this.onClose,
    required this.onMessage,
    this.distanceFromMe,
    this.bearingFromMe,
    required this.onShareLocation,
    required this.onCopyCoordinates,
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

  String _formatBearing(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return '${bearing.round()}° ${directions[index]}';
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
                        if (bearingFromMe != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _formatBearing(bearingFromMe!),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons (compact)
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: AppTheme.textTertiary,
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.share, size: 18),
                        color: AppTheme.textSecondary,
                        onPressed: onShareLocation,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Share location',
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        color: AppTheme.textSecondary,
                        onPressed: onCopyCoordinates,
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: 'Copy coordinates',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Stats row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (node.batteryLevel != null)
                _StatChip(
                  icon: Icons.battery_full,
                  value: '${node.batteryLevel}%',
                  color: _getBatteryColor(node.batteryLevel!),
                ),
              if (node.snr != null)
                _StatChip(
                  icon: Icons.signal_cellular_alt,
                  value: '${node.snr} dB',
                  color: AppTheme.textSecondary,
                ),
              if (node.altitude != null)
                _StatChip(
                  icon: Icons.terrain,
                  value: '${node.altitude}m',
                  color: AppTheme.textSecondary,
                ),
              if (node.hardwareModel != null)
                _StatChip(
                  icon: Icons.memory,
                  value: node.hardwareModel!,
                  color: AppTheme.textSecondary,
                ),
              // Last heard
              _StatChip(
                icon: Icons.access_time,
                value: _formatLastHeard(node.lastHeard),
                color: node.isOnline
                    ? AppTheme.successGreen
                    : AppTheme.textTertiary,
              ),
            ],
          ),
          if (!isMyNode) ...[
            const SizedBox(height: 12),
            // Action buttons row
            Row(
              children: [
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

  String _formatLastHeard(DateTime? lastHeard) {
    if (lastHeard == null) return 'Never';
    final diff = DateTime.now().difference(lastHeard);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

/// Navigation control buttons (center on me, reset north)
class _NavigationControls extends StatelessWidget {
  final VoidCallback onCenterOnMe;
  final VoidCallback onResetNorth;
  final bool hasMyNode;

  const _NavigationControls({
    required this.onCenterOnMe,
    required this.onResetNorth,
    required this.hasMyNode,
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
          // Center on me
          Tooltip(
            message: 'Center on my location',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: hasMyNode ? onCenterOnMe : null,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.my_location,
                    size: 20,
                    color: hasMyNode
                        ? AppTheme.primaryMagenta
                        : AppTheme.textTertiary.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 1,
            width: 32,
            color: AppTheme.darkBorder.withValues(alpha: 0.3),
          ),
          // Reset to north
          Tooltip(
            message: 'Reset to north',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onResetNorth,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.explore,
                    size: 20,
                    color: AppTheme.textSecondary,
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

/// Compass widget showing map rotation
class _Compass extends StatelessWidget {
  final double rotation;
  final VoidCallback onPressed;

  const _Compass({required this.rotation, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.darkCard.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.darkBorder.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Transform.rotate(
          angle: -rotation * (3.14159 / 180),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // North indicator (red)
              Positioned(
                top: 6,
                child: Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // South indicator (white)
              Positioned(
                bottom: 6,
                child: Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Center dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filter bar for node filtering
class _FilterBar extends StatelessWidget {
  final NodeFilter currentFilter;
  final void Function(NodeFilter) onFilterChanged;
  final int totalCount;
  final int filteredCount;

  const _FilterBar({
    required this.currentFilter,
    required this.onFilterChanged,
    required this.totalCount,
    required this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.filter_alt,
                size: 16,
                color: AppTheme.primaryMagenta,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter Nodes',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '$filteredCount / $totalCount',
                style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: NodeFilter.values.map((filter) {
              final isSelected = filter == currentFilter;
              return GestureDetector(
                onTap: () => onFilterChanged(filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryMagenta.withValues(alpha: 0.2)
                        : AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryMagenta
                          : AppTheme.darkBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    filter.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppTheme.primaryMagenta
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Measurement card showing distance between two points
class _MeasurementCard extends StatelessWidget {
  final LatLng start;
  final LatLng end;
  final VoidCallback onClear;
  final VoidCallback onShare;

  const _MeasurementCard({
    required this.start,
    required this.end,
    required this.onClear,
    required this.onShare,
  });

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} meters';
    } else if (km < 10) {
      return '${km.toStringAsFixed(2)} km';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }

  double _calculateDistance() {
    return const Distance().as(LengthUnit.Kilometer, start, end);
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateDistance();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.warningYellow.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.warningYellow.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.straighten,
              size: 18,
              color: AppTheme.warningYellow,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDistance(distance),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.warningYellow,
                  ),
                ),
                Text(
                  'A: ${start.latitude.toStringAsFixed(4)}, ${start.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                ),
                Text(
                  'B: ${end.latitude.toStringAsFixed(4)}, ${end.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 10, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            color: AppTheme.textSecondary,
            onPressed: onShare,
            tooltip: 'Share',
          ),
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            color: AppTheme.textTertiary,
            onPressed: onClear,
            tooltip: 'Clear',
          ),
        ],
      ),
    );
  }
}
