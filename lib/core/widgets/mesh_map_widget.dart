import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../map_config.dart';
import '../theme.dart';
import '../../models/mesh_models.dart';

/// A shared, configurable map widget for displaying mesh nodes.
///
/// This widget provides a consistent map experience across all screens.
/// Use the various parameters to enable/disable features as needed.
class MeshMapWidget extends StatelessWidget {
  /// The map controller for programmatic control
  final MapController? mapController;

  /// Map style (dark, satellite, terrain, light)
  final MapTileStyle mapStyle;

  /// Initial center of the map
  final LatLng initialCenter;

  /// Initial zoom level
  final double initialZoom;

  /// Minimum zoom level
  final double minZoom;

  /// Maximum zoom level
  final double maxZoom;

  /// Whether to enable map interactions (pan, zoom, rotate)
  final bool interactive;

  /// Callback when map position changes
  final void Function(MapCamera, bool)? onPositionChanged;

  /// Callback when map is tapped
  final void Function(TapPosition, LatLng)? onTap;

  /// Callback when map is long pressed
  final void Function(TapPosition, LatLng)? onLongPress;

  /// Additional map layers to add (polylines, circles, etc.)
  final List<Widget> additionalLayers;

  /// Node markers to display
  final List<MeshNodeMarkerData>? nodeMarkers;

  /// Currently selected node (for highlighting)
  final int? selectedNodeNum;

  /// My node number (for special styling)
  final int? myNodeNum;

  /// Callback when a node marker is tapped
  final void Function(MeshNode)? onNodeTap;

  /// Whether to animate tile loading
  final bool animateTiles;

  /// Background color
  final Color backgroundColor;

  const MeshMapWidget({
    super.key,
    this.mapController,
    this.mapStyle = MapTileStyle.dark,
    required this.initialCenter,
    this.initialZoom = 13.0,
    this.minZoom = 3.0,
    this.maxZoom = 18.0,
    this.interactive = true,
    this.onPositionChanged,
    this.onTap,
    this.onLongPress,
    this.additionalLayers = const [],
    this.nodeMarkers,
    this.selectedNodeNum,
    this.myNodeNum,
    this.onNodeTap,
    this.animateTiles = true,
    this.backgroundColor = AppTheme.darkBackground,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        minZoom: minZoom,
        maxZoom: maxZoom,
        backgroundColor: backgroundColor,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          pinchZoomThreshold: 0.5,
          scrollWheelVelocity: 0.005,
        ),
        onPositionChanged: onPositionChanged,
        onTap: onTap,
        onLongPress: onLongPress,
      ),
      children: [
        // Map tiles
        TileLayer(
          urlTemplate: mapStyle.url,
          subdomains: mapStyle.subdomains,
          userAgentPackageName: MapConfig.userAgentPackageName,
          retinaMode: mapStyle != MapTileStyle.satellite,
          tileBuilder: animateTiles
              ? (context, tileWidget, tile) {
                  return AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: tileWidget,
                  );
                }
              : null,
        ),

        // Additional layers (polylines, circles, etc.)
        ...additionalLayers,

        // Node markers
        if (nodeMarkers != null && nodeMarkers!.isNotEmpty)
          MarkerLayer(
            rotate: true,
            markers: nodeMarkers!.map((data) {
              final isMyNode = data.node.nodeNum == myNodeNum;
              final isSelected = data.node.nodeNum == selectedNodeNum;
              return Marker(
                point: LatLng(data.latitude, data.longitude),
                width: isSelected ? 56 : 44,
                height: isSelected ? 56 : 44,
                child: GestureDetector(
                  onTap: onNodeTap != null
                      ? () {
                          HapticFeedback.selectionClick();
                          onNodeTap!(data.node);
                        }
                      : null,
                  child: MeshNodeMarker(
                    node: data.node,
                    isMyNode: isMyNode,
                    isSelected: isSelected,
                    isStale: data.isStale,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

/// Data class for node marker positioning
class MeshNodeMarkerData {
  final MeshNode node;
  final double latitude;
  final double longitude;
  final bool isStale;

  const MeshNodeMarkerData({
    required this.node,
    required this.latitude,
    required this.longitude,
    this.isStale = false,
  });

  factory MeshNodeMarkerData.fromNode(MeshNode node, {bool? isStale}) {
    return MeshNodeMarkerData(
      node: node,
      latitude: node.latitude ?? 0,
      longitude: node.longitude ?? 0,
      isStale: isStale ?? !node.isOnline,
    );
  }
}

/// Standard node marker widget used across all maps
class MeshNodeMarker extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final bool isSelected;
  final bool isStale;

  const MeshNodeMarker({
    super.key,
    required this.node,
    this.isMyNode = false,
    this.isSelected = false,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;
    final baseColor = isMyNode
        ? accentColor
        : (isStale ? AppTheme.textTertiary : accentColor);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: baseColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: isSelected ? 0.6 : 0.4),
            blurRadius: isSelected ? 12 : 6,
            spreadRadius: isSelected ? 2 : 0,
          ),
          if (isSelected)
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Center(
        child: isMyNode
            ? const Icon(Icons.person, color: Colors.white, size: 20)
            : Text(
                (node.shortName?.isNotEmpty ?? false)
                    ? node.shortName![0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}

/// Mini node marker for compact displays (dashboard widget, etc.)
class MiniMeshNodeMarker extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;

  const MiniMeshNodeMarker({
    super.key,
    required this.node,
    this.isMyNode = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isMyNode
        ? context.accentColor
        : (node.isOnline ? context.accentColor : AppTheme.textTertiary);

    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }
}

/// Helper to calculate the center of multiple nodes
LatLng calculateNodesCenter(List<MeshNodeMarkerData> nodes) {
  if (nodes.isEmpty) {
    return const LatLng(MapConfig.defaultLat, MapConfig.defaultLon);
  }

  double avgLat = 0, avgLon = 0;
  for (final node in nodes) {
    avgLat += node.latitude;
    avgLon += node.longitude;
  }
  return LatLng(avgLat / nodes.length, avgLon / nodes.length);
}

/// Helper to calculate zoom level to fit all nodes
double calculateZoomToFitNodes(List<MeshNodeMarkerData> nodes) {
  if (nodes.isEmpty || nodes.length == 1) {
    return 13.0;
  }

  final lats = nodes.map((n) => n.latitude).toList();
  final lons = nodes.map((n) => n.longitude).toList();

  final minLat = lats.reduce((a, b) => a < b ? a : b);
  final maxLat = lats.reduce((a, b) => a > b ? a : b);
  final minLon = lons.reduce((a, b) => a < b ? a : b);
  final maxLon = lons.reduce((a, b) => a > b ? a : b);

  final latDiff = maxLat - minLat;
  final lonDiff = maxLon - minLon;
  final maxDiff = latDiff > lonDiff ? latDiff : lonDiff;

  // Rough zoom calculation based on coordinate span
  if (maxDiff > 10) return 4.0;
  if (maxDiff > 5) return 6.0;
  if (maxDiff > 2) return 8.0;
  if (maxDiff > 1) return 10.0;
  if (maxDiff > 0.5) return 11.0;
  if (maxDiff > 0.1) return 13.0;
  if (maxDiff > 0.05) return 14.0;
  return 15.0;
}
