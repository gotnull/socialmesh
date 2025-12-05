import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/map_config.dart';
import '../../core/theme.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Result from the geofence picker
class GeofenceResult {
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int? monitoredNodeNum;
  final String? monitoredNodeName;

  const GeofenceResult({
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.monitoredNodeNum,
    this.monitoredNodeName,
  });
}

/// Screen for visually picking a geofence location and radius on a map
class GeofencePickerScreen extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLon;
  final double initialRadius;
  final int? initialMonitoredNodeNum;

  const GeofencePickerScreen({
    super.key,
    this.initialLat,
    this.initialLon,
    this.initialRadius = 1000.0,
    this.initialMonitoredNodeNum,
  });

  @override
  ConsumerState<GeofencePickerScreen> createState() =>
      _GeofencePickerScreenState();
}

/// Helper class for nodes with GPS positions
class _NodeWithPosition {
  final MeshNode node;
  final double latitude;
  final double longitude;

  _NodeWithPosition({
    required this.node,
    required this.latitude,
    required this.longitude,
  });
}

class _GeofencePickerScreenState extends ConsumerState<GeofencePickerScreen> {
  late final MapController _mapController;
  LatLng? _center;
  double _radiusMeters = 1000.0;
  bool _isDraggingRadius = false;
  bool _isLoadingLocation = false;
  bool _showNodeList = false;
  final TextEditingController _searchController = TextEditingController();
  int? _monitoredNodeNum;
  String? _monitoredNodeName;
  int? _selectedNodeNum; // For visual selection highlight

  // Threshold for starting edge drag (in screen pixels)
  static const double _edgeDragThreshold = 40.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _radiusMeters = widget.initialRadius;
    _monitoredNodeNum = widget.initialMonitoredNodeNum;

    if (widget.initialLat != null && widget.initialLon != null) {
      _center = LatLng(widget.initialLat!, widget.initialLon!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Get nodes with GPS positions
  List<_NodeWithPosition> _getNodesWithPositions(Map<int, MeshNode> nodes) {
    final result = <_NodeWithPosition>[];
    for (final node in nodes.values) {
      if (node.hasPosition) {
        result.add(
          _NodeWithPosition(
            node: node,
            latitude: node.latitude!,
            longitude: node.longitude!,
          ),
        );
      }
    }
    return result;
  }

  /// Filter nodes by search query
  List<_NodeWithPosition> _filterNodes(List<_NodeWithPosition> nodes) {
    if (_searchController.text.isEmpty) return nodes;
    final query = _searchController.text.toLowerCase();
    return nodes.where((n) {
      return n.node.displayName.toLowerCase().contains(query) ||
          (n.node.shortName?.toLowerCase().contains(query) ?? false) ||
          n.node.nodeNum.toString().contains(query);
    }).toList();
  }

  void _selectNode(
    _NodeWithPosition nodeWithPos, {
    bool setAsMonitored = false,
  }) {
    HapticFeedback.selectionClick();
    final point = LatLng(nodeWithPos.latitude, nodeWithPos.longitude);
    setState(() {
      _selectedNodeNum = nodeWithPos.node.nodeNum;
      _center = point;
      _showNodeList = false;
      if (setAsMonitored) {
        _monitoredNodeNum = nodeWithPos.node.nodeNum;
        _monitoredNodeName = nodeWithPos.node.displayName;
      }
    });
    _mapController.move(point, 14.0);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final newCenter = LatLng(position.latitude, position.longitude);
      setState(() {
        _center = newCenter;
        _isLoadingLocation = false;
      });

      _mapController.move(newCenter, _mapController.camera.zoom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get location: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _isLoadingLocation = false);
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    // Close sidebar if open
    if (_showNodeList) {
      setState(() => _showNodeList = false);
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedNodeNum = null; // Clear node selection
      // Only move center if not locked to a monitored node
      if (_monitoredNodeNum == null) {
        _center = point;
      }
    });
  }

  void _onMapLongPress(TapPosition tapPosition, LatLng point) {
    // Long press no longer used for radius - use edge drag instead
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, from, to);
  }

  /// Check if a screen point is near the geofence edge
  bool _isNearGeofenceEdge(Offset screenPoint) {
    if (_center == null) return false;

    // Get center screen position
    final centerScreen = _mapController.camera.latLngToScreenPoint(_center!);

    // Calculate the radius in screen pixels
    // Use a point at the edge of the geofence to find screen radius
    final edgePoint = _calculatePointAtDistance(
      _center!,
      _radiusMeters,
      90, // Due east
    );
    final edgeScreen = _mapController.camera.latLngToScreenPoint(edgePoint);
    final screenRadius = (edgeScreen.x - centerScreen.x).abs();

    // Distance from touch to center
    final dx = screenPoint.dx - centerScreen.x;
    final dy = screenPoint.dy - centerScreen.y;
    final distanceFromCenter = math.sqrt(dx * dx + dy * dy);

    // Check if within threshold of the edge
    return (distanceFromCenter - screenRadius).abs() < _edgeDragThreshold;
  }

  /// Calculate a point at a given distance and bearing from origin
  LatLng _calculatePointAtDistance(
    LatLng origin,
    double distanceMeters,
    double bearingDegrees,
  ) {
    const double earthRadius = 6371000; // meters
    final lat1 = origin.latitude * math.pi / 180;
    final lon1 = origin.longitude * math.pi / 180;
    final bearing = bearingDegrees * math.pi / 180;
    final angularDistance = distanceMeters / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(angularDistance) +
          math.cos(lat1) * math.sin(angularDistance) * math.cos(bearing),
    );
    final lon2 =
        lon1 +
        math.atan2(
          math.sin(bearing) * math.sin(angularDistance) * math.cos(lat1),
          math.cos(angularDistance) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_center != null && _isNearGeofenceEdge(event.localPosition)) {
      HapticFeedback.mediumImpact();
      setState(() => _isDraggingRadius = true);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_isDraggingRadius && _center != null) {
      // Convert screen position to map position
      final point = _mapController.camera.pointToLatLng(
        math.Point(event.localPosition.dx, event.localPosition.dy),
      );

      final newRadius = _calculateDistance(_center!, point);
      if (newRadius >= 50 && newRadius <= 50000) {
        setState(() {
          _radiusMeters = newRadius;
        });
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isDraggingRadius) {
      setState(() {
        _isDraggingRadius = false;
      });
    }
  }

  void _confirmGeofence() {
    if (_center == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please tap on the map to set a geofence center'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      GeofenceResult(
        latitude: _center!.latitude,
        longitude: _center!.longitude,
        radiusMeters: _radiusMeters,
        monitoredNodeNum: _monitoredNodeNum,
        monitoredNodeName: _monitoredNodeName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final allNodesWithPosition = _getNodesWithPositions(nodes);
    final filteredNodes = _filterNodes(allNodesWithPosition);

    // Look up monitored node name if we have a nodeNum but no name yet
    if (_monitoredNodeNum != null && _monitoredNodeName == null) {
      final monitoredNode = nodes[_monitoredNodeNum];
      if (monitoredNode != null) {
        _monitoredNodeName = monitoredNode.displayName;
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCard,
        title: Text('Set Geofence'),
        actions: [
          TextButton(
            onPressed: _center != null ? _confirmGeofence : null,
            child: Text(
              'Done',
              style: TextStyle(
                color: _center != null
                    ? context.accentColor
                    : AppTheme.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          Listener(
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _center ?? const LatLng(-33.8688, 151.2093),
                initialZoom: 13.0,
                minZoom: 3.0,
                maxZoom: 18.0,
                onTap: _onMapTap,
                onLongPress: _onMapLongPress,
                interactionOptions: InteractionOptions(
                  flags: _isDraggingRadius
                      ? InteractiveFlag.none
                      : InteractiveFlag.all,
                ),
              ),
              children: [
                MapConfig.darkTileLayer(),
                // Geofence circle
                if (_center != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _center!,
                        radius: _radiusMeters,
                        useRadiusInMeter: true,
                        color: context.accentColor.withAlpha(40),
                        borderColor: context.accentColor,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                // Node markers
                MarkerLayer(
                  rotate: true,
                  markers: allNodesWithPosition.map((n) {
                    final isMyNode = n.node.nodeNum == myNodeNum;
                    final isSelected = n.node.nodeNum == _selectedNodeNum;
                    final isMonitored = n.node.nodeNum == _monitoredNodeNum;
                    return Marker(
                      point: LatLng(n.latitude, n.longitude),
                      width: isSelected ? 52 : 44,
                      height: isSelected ? 52 : 44,
                      child: GestureDetector(
                        onTap: () => _selectNode(n),
                        child: _NodeMarker(
                          node: n.node,
                          isMyNode: isMyNode,
                          isSelected: isSelected,
                          isMonitored: isMonitored,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                // Center marker (geofence center)
                if (_center != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _center!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.accentColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(80),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Instructions overlay
          Positioned(
            top: 16,
            left: _showNodeList ? 316 : 16,
            right: 16,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showNodeList ? 0.0 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkCard.withAlpha(230),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: context.accentColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _center == null
                                ? 'Tap to set geofence center'
                                : 'Drag the circle edge to adjust radius',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_center != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Radius: ${_radiusMeters >= 1000 ? '${(_radiusMeters / 1000).toStringAsFixed(1)} km' : '${_radiusMeters.toStringAsFixed(0)} m'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Node list toggle button
          if (!_showNodeList && allNodesWithPosition.isNotEmpty)
            Positioned(
              left: 16,
              top: 120,
              child: GestureDetector(
                onTap: () => setState(() => _showNodeList = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard.withAlpha(230),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.darkBorder.withAlpha(128),
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
                        '${allNodesWithPosition.length} nodes',
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

          // Node list panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            left: _showNodeList ? 0 : -300,
            top: 0,
            bottom: 0,
            width: 300,
            child: _NodeListPanel(
              nodesWithPosition: filteredNodes,
              myNodeNum: myNodeNum,
              monitoredNodeNum: _monitoredNodeNum,
              onNodeSelected: _selectNode,
              onClose: () => setState(() => _showNodeList = false),
              searchController: _searchController,
              onSearchChanged: (query) => setState(() {}),
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                border: Border(top: BorderSide(color: AppTheme.darkBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Monitored node indicator
                  if (_monitoredNodeNum != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.accentColor.withAlpha(77),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.radar,
                            size: 18,
                            color: context.accentColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Monitored Node',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
                                Text(
                                  _monitoredNodeName ??
                                      '!${_monitoredNodeNum!.toRadixString(16)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _monitoredNodeNum = null;
                                _monitoredNodeName = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Radius slider
                  if (_center != null) ...[
                    Row(
                      children: [
                        const Text(
                          'Radius',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _radiusMeters >= 1000
                              ? '${(_radiusMeters / 1000).toStringAsFixed(1)} km'
                              : '${_radiusMeters.toStringAsFixed(0)} m',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        inactiveTrackColor: AppTheme.darkBorder,
                        thumbColor: context.accentColor,
                        overlayColor: context.accentColor.withAlpha(40),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: _radiusMeters.clamp(100, 10000),
                        min: 100,
                        max: 10000,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _radiusMeters = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(height: 8),
                  ],

                  // Buttons row
                  Row(
                    children: [
                      // Current location button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingLocation
                              ? null
                              : _getCurrentLocation,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.accentColor,
                            side: BorderSide(
                              color: context.accentColor.withAlpha(100),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: _isLoadingLocation
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.accentColor,
                                  ),
                                )
                              : Icon(Icons.my_location, size: 18),
                          label: Text(
                            _isLoadingLocation
                                ? 'Getting...'
                                : 'Use My Location',
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      // Confirm button
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _center != null ? _confirmGeofence : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: context.accentColor,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppTheme.darkBorder,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Set Geofence'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom marker widget for nodes
class _NodeMarker extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final bool isSelected;
  final bool isMonitored;

  const _NodeMarker({
    required this.node,
    required this.isMyNode,
    this.isSelected = false,
    this.isMonitored = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isMyNode
        ? context.accentColor
        : (node.isOnline ? AppTheme.primaryPurple : AppTheme.textTertiary);

    // Use green border if monitored, white if selected
    final borderColor = isMonitored
        ? context.accentColor
        : (isSelected ? Colors.white : baseColor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: isSelected || isMonitored ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isMonitored ? context.accentColor : baseColor).withAlpha(
              isSelected ? 150 : 102,
            ),
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

/// Node list panel sliding from left
class _NodeListPanel extends StatelessWidget {
  final List<_NodeWithPosition> nodesWithPosition;
  final int? myNodeNum;
  final int? monitoredNodeNum;
  final void Function(_NodeWithPosition, {bool setAsMonitored}) onNodeSelected;
  final VoidCallback onClose;
  final TextEditingController searchController;
  final void Function(String) onSearchChanged;

  const _NodeListPanel({
    required this.nodesWithPosition,
    required this.myNodeNum,
    required this.monitoredNodeNum,
    required this.onNodeSelected,
    required this.onClose,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Sort: my node first, then alphabetically
    final sortedNodes = List<_NodeWithPosition>.from(nodesWithPosition);
    sortedNodes.sort((a, b) {
      if (a.node.nodeNum == myNodeNum) return -1;
      if (b.node.nodeNum == myNodeNum) return 1;
      return a.node.displayName.compareTo(b.node.displayName);
    });

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          border: Border(
            right: BorderSide(color: AppTheme.darkBorder.withAlpha(128)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(77),
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
                  bottom: BorderSide(color: AppTheme.darkBorder.withAlpha(128)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.list,
                    size: 20,
                    color: context.accentColor,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Select Node',
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
                  hintStyle: const TextStyle(
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
                  ? const Center(
                      child: Text(
                        'No nodes with GPS',
                        style: TextStyle(color: AppTheme.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: sortedNodes.length,
                      itemBuilder: (context, index) {
                        final nodeWithPos = sortedNodes[index];
                        final isMyNode = nodeWithPos.node.nodeNum == myNodeNum;
                        final isMonitored =
                            nodeWithPos.node.nodeNum == monitoredNodeNum;

                        return _NodeListItem(
                          nodeWithPos: nodeWithPos,
                          isMyNode: isMyNode,
                          isMonitored: isMonitored,
                          onTap: () => onNodeSelected(
                            nodeWithPos,
                            setAsMonitored: false,
                          ),
                          onSetMonitored: () =>
                              onNodeSelected(nodeWithPos, setAsMonitored: true),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual node item in the list
class _NodeListItem extends StatelessWidget {
  final _NodeWithPosition nodeWithPos;
  final bool isMyNode;
  final bool isMonitored;
  final VoidCallback onTap;
  final VoidCallback onSetMonitored;

  const _NodeListItem({
    required this.nodeWithPos,
    required this.isMyNode,
    required this.isMonitored,
    required this.onTap,
    required this.onSetMonitored,
  });

  @override
  Widget build(BuildContext context) {
    final node = nodeWithPos.node;
    final baseColor = isMyNode
        ? context.accentColor
        : (node.isOnline ? AppTheme.primaryPurple : AppTheme.textTertiary);

    return Material(
      color: isMonitored
          ? context.accentColor.withAlpha(26)
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
                  color: baseColor.withAlpha(51),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: baseColor.withAlpha(153),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    node.shortName?.substring(0, 1).toUpperCase() ??
                        node.nodeNum.toString().substring(0, 1),
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
                        Flexible(
                          child: Text(
                            node.displayName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMyNode) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withAlpha(51),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'YOU',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: context.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      node.shortName ??
                          '!${node.nodeNum.toRadixString(16).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              // Monitor button or indicator
              if (isMonitored)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor.withAlpha(51),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar, size: 12, color: context.accentColor),
                      SizedBox(width: 4),
                      Text(
                        'Monitored',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: context.accentColor,
                        ),
                      ),
                    ],
                  ),
                )
              else
                GestureDetector(
                  onTap: onSetMonitored,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkBorder.withAlpha(100),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Monitor',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
