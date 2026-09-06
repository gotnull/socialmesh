// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'map_tile_layer.dart';
import '../l10n/l10n_extension.dart';
import '../map_config.dart';
import '../node_color.dart';
import '../safe_lat_lng.dart';
import '../theme.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import 'app_bottom_sheet.dart';

/// A shared, configurable map widget for displaying mesh nodes.
///
/// This widget provides a consistent map experience across all screens.
/// Use the various parameters to enable/disable features as needed.
class MeshMapWidget extends StatefulWidget {
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

  /// Whether to disable manual map rotation. Defaults to `true` so a pinch-zoom
  /// can never accidentally rotate ("wiggle") the map off north. Screens that
  /// offer an explicit compass/rotation control opt back in with `false`.
  final bool disableRotation;

  /// Callback when map position changes
  final void Function(MapCamera, bool)? onPositionChanged;

  /// Callback when map is tapped
  final void Function(TapPosition, LatLng)? onTap;

  /// Callback when map is long pressed
  final void Function(TapPosition, LatLng)? onLongPress;

  /// Additional map layers to add (polylines, circles, etc.)
  final List<Widget> additionalLayers;

  /// Node markers to display (non-clustered)
  final List<MeshNodeMarkerData>? nodeMarkers;

  /// Currently selected node (for highlighting)
  final int? selectedNodeNum;

  /// My node number (for special styling)
  final int? myNodeNum;

  /// Callback when a node marker is tapped
  final void Function(MeshNode)? onNodeTap;

  /// Opacity applied to every node marker, own node included (0.2-1.0), so
  /// the map underneath stays visible. Mirrors the main map screen's
  /// overlay-transparency setting; the own node stays distinguishable by its
  /// larger marker and styling rather than by being exempt from the setting.
  final double nodeOverlayOpacity;

  /// Whether to animate tile loading
  final bool animateTiles;

  /// Background color (defaults to context.background if null)
  final Color? backgroundColor;

  /// Enable clustering for markers (for large datasets like world mesh)
  final bool enableClustering;

  /// Custom markers when using clustering (overrides nodeMarkers if set)
  final List<Marker>? clusteredMarkers;

  /// Builder for cluster marker appearance
  final Widget Function(BuildContext, List<Marker>)? clusterBuilder;

  /// Max cluster radius (controls how aggressively markers cluster)
  final double clusterRadius;

  /// Zoom level at and beyond which clustering stops and every marker renders
  /// individually. Mirrors the main map screen; pass
  /// `MapConfig.clusterDisableZoom(style)` to match it. Null keeps the
  /// package default (never disables until z20).
  final int? disableClusteringAtZoom;

  /// Show attribution widget
  final bool showAttribution;

  /// Attribution widgets
  final List<SourceAttribution>? attributions;

  /// Stack a transparent place-name + boundary overlay above satellite
  /// imagery so village / town / city labels appear in satellite mode. Has
  /// no effect when [mapStyle] is not [MapTileStyle.satellite].
  final bool showSatelliteLabels;

  const MeshMapWidget({
    super.key,
    this.mapController,
    this.mapStyle = MapTileStyle.dark,
    required this.initialCenter,
    this.initialZoom = 13.0,
    this.minZoom = 3.0,
    this.maxZoom = 18.0,
    this.interactive = true,
    this.disableRotation = true,
    this.onPositionChanged,
    this.onTap,
    this.onLongPress,
    this.additionalLayers = const [],
    this.nodeMarkers,
    this.selectedNodeNum,
    this.myNodeNum,
    this.onNodeTap,
    this.nodeOverlayOpacity = 1.0,
    this.animateTiles = true,
    this.backgroundColor,
    // Clustering options
    this.enableClustering = false,
    this.clusteredMarkers,
    this.clusterBuilder,
    this.clusterRadius = 45,
    this.disableClusteringAtZoom,
    this.showAttribution = true,
    this.attributions,
    this.showSatelliteLabels = true,
  });

  @override
  State<MeshMapWidget> createState() => _MeshMapWidgetState();
}

class _MeshMapWidgetState extends State<MeshMapWidget> {
  // Effective controller: the caller's when supplied, otherwise our own — so
  // the camera-NaN recovery below always has a handle to snap back with.
  late final bool _ownsController = widget.mapController == null;
  late final MapController _effectiveController =
      widget.mapController ?? MapController();

  // Camera-boundary NaN recovery, centralised here so every MeshMapWidget
  // consumer is protected at once. flutter_map's pinch pipeline can commit a
  // non-finite pose through its internal moveRaw() (a math.log(scale<=0)
  // overflow) that bypasses every safeMove guard, leaving the camera centre
  // NaN — which then throws fatally in Crs.checkLatLng on the next tile build
  // and every later pinch. onPositionChanged fires on that internal move, so
  // we snap back to the last finite pose before the crashing frame builds.
  // See lib/core/safe_lat_lng.dart isFiniteCameraPose.
  LatLng? _lastFiniteCenter;
  late double _lastFiniteZoom = widget.initialZoom;
  bool _cameraRecoveryScheduled = false;

  @override
  void dispose() {
    if (_ownsController) _effectiveController.dispose();
    super.dispose();
  }

  void _handlePositionChanged(MapCamera camera, bool hasGesture) {
    if (isFiniteCameraPose(camera.center, camera.zoom)) {
      _lastFiniteCenter = camera.center;
      _lastFiniteZoom = camera.zoom;
    } else if (!_cameraRecoveryScheduled) {
      _cameraRecoveryScheduled = true;
      final recoverCenter = _lastFiniteCenter;
      final recoverZoom = _lastFiniteZoom;
      scheduleMicrotask(() {
        _cameraRecoveryScheduled = false;
        if (!mounted || recoverCenter == null) return;
        _effectiveController.safeMove(recoverCenter, recoverZoom);
      });
      return;
    }
    widget.onPositionChanged?.call(camera, hasGesture);
  }

  @override
  Widget build(BuildContext context) {
    // Build interaction flags
    int interactionFlags = widget.interactive
        ? InteractiveFlag.all
        : InteractiveFlag.none;
    if (widget.disableRotation && widget.interactive) {
      interactionFlags = InteractiveFlag.all & ~InteractiveFlag.rotate;
    }

    // Wrap in RepaintBoundary for better performance with large datasets
    return RepaintBoundary(
      child: FlutterMap(
        mapController: _effectiveController,
        options: MapOptions(
          initialCenter: widget.initialCenter,
          initialZoom: widget.initialZoom,
          minZoom: widget.minZoom,
          maxZoom: widget.maxZoom,
          backgroundColor: widget.backgroundColor ?? context.background,
          interactionOptions: InteractionOptions(
            flags: interactionFlags,
            pinchZoomThreshold: 0.5,
            scrollWheelVelocity: 0.005,
          ),
          onPositionChanged: _handlePositionChanged,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
        ),
        children: [
          // Map tiles. Routes to Mapbox when its flag + token are set.
          StyledTileLayer(
            style: widget.mapStyle,
            satelliteLabelsOn: widget.showSatelliteLabels,
            // Disable tile animation for better performance
            tileBuilder: widget.animateTiles
                ? (context, tileWidget, tile) {
                    return tileWidget; // Just return widget without animation for perf
                  }
                : null,
          ),

          // Transparent place-name + boundary overlay above satellite
          // imagery. Sits below additional layers and node markers. Skipped
          // on the Mapbox path (labels baked into satellite-streets-v12).
          if (widget.mapStyle == MapTileStyle.satellite &&
              widget.showSatelliteLabels &&
              !MapConfig.isMapboxActive)
            MapConfig.satelliteReferenceLabelsTileLayer(),

          // Additional layers (polylines, circles, etc.)
          ...widget.additionalLayers,

          // Node markers — built once from `nodeMarkers` (or an explicit
          // `clusteredMarkers` override) and rendered either plain or in a
          // cluster layer, mirroring the main map screen. Each marker keys on
          // its nodeNum so the cluster tap-to-list sheet can recover the node.
          Builder(
            builder: (context) {
              final markers = widget.clusteredMarkers != null
                  ? finiteMarkers(widget.clusteredMarkers!)
                  : _buildNodeMarkers();
              if (markers.isEmpty) return const SizedBox.shrink();
              if (!widget.enableClustering) {
                return MarkerLayer(rotate: true, markers: markers);
              }
              return MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: widget.clusterRadius.toInt(),
                  size: const Size(44, 44),
                  alignment: Alignment.center,
                  rotate: true,
                  padding: EdgeInsets.zero,
                  disableClusteringAtZoom: widget.disableClusteringAtZoom ?? 20,
                  zoomToBoundsOnClick: false,
                  animationsOptions: const AnimationsOptions(
                    zoom: Duration.zero,
                    fitBound: Duration(milliseconds: 300),
                    centerMarker: Duration.zero,
                    spiderfy: Duration(milliseconds: 200),
                  ),
                  markers: markers,
                  builder: widget.clusterBuilder ?? _defaultClusterBuilder,
                ),
              );
            },
          ),

          // Attribution (matches world mesh style). Mapbox TOS requires
          // their attribution line and tap-through. Centered horizontally so
          // the pill doesn't get clipped by rounded screen corners / device
          // chrome at the bottom-left, and lifted above the home indicator
          // via the system safe-area inset.
          if (widget.showAttribution)
            Positioned(
              left: 0,
              right: 0,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
              child: Center(
                child: MapAttributionChip(
                  style: widget.mapStyle,
                  satelliteLabelsOn: widget.showSatelliteLabels,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Build the node markers once from `nodeMarkers`, keyed on nodeNum so the
  // cluster tap-to-list sheet can recover each underlying node. Shared by the
  // plain and clustered render paths.
  List<Marker> _buildNodeMarkers() {
    final data = widget.nodeMarkers;
    if (data == null || data.isEmpty) return const [];
    return finiteMarkers(
      data.map((d) {
        final isMyNode = d.node.nodeNum == widget.myNodeNum;
        final isSelected = d.node.nodeNum == widget.selectedNodeNum;
        return Marker(
          key: ValueKey<int>(d.node.nodeNum),
          point: LatLng(d.latitude, d.longitude),
          width: (isMyNode || isSelected) ? 56 : 44,
          height: (isMyNode || isSelected) ? 56 : 44,
          child: GestureDetector(
            onTap: widget.onNodeTap != null
                ? () {
                    HapticFeedback.selectionClick();
                    widget.onNodeTap!(d.node);
                  }
                : null,
            child: _applyOverlayOpacity(
              child: MeshNodeMarker(
                node: d.node,
                isMyNode: isMyNode,
                isSelected: isSelected,
                isStale: d.isStale,
              ),
            ),
          ),
        );
      }),
    );
  }

  // Fades node markers per the overlay-opacity setting so the map underneath
  // stays visible. The own node is faded like every other marker: users set
  // this to see the map through the markers, and an always-opaque own node
  // read as the setting silently not applying. Its larger marker keeps it
  // findable at any opacity the setting allows.
  Widget _applyOverlayOpacity({required Widget child}) {
    if (widget.nodeOverlayOpacity >= 1.0) return child;
    return Opacity(opacity: widget.nodeOverlayOpacity, child: child);
  }

  // Open the tap-to-list sheet for a tapped cluster, recovering the nodes from
  // the cluster's marker keys. Selecting a row routes through [onNodeTap], the
  // same callback the individual markers use.
  Future<void> _showClusterSheet(
    BuildContext context,
    List<Marker> clusterMarkers,
  ) async {
    final byNum = <int, MeshNode>{
      for (final d in widget.nodeMarkers ?? const <MeshNodeMarkerData>[])
        d.node.nodeNum: d.node,
    };
    final nodes = <MeshNode>[];
    for (final m in clusterMarkers) {
      final key = m.key;
      if (key is ValueKey<int>) {
        final node = byNum[key.value];
        if (node != null) nodes.add(node);
      }
    }
    if (nodes.isEmpty) return;
    HapticFeedback.selectionClick();
    await AppBottomSheet.show<void>(
      context: context,
      child: ClusterListSheet(
        nodes: nodes,
        onNodeSelected: (node) => widget.onNodeTap?.call(node),
      ),
    );
  }

  // Cluster bubble matching the main map screen: solid accent circle, white
  // border, count (or "x.xk"), sized by member count. Tapping opens the
  // tap-to-list sheet.
  Widget _defaultClusterBuilder(BuildContext context, List<Marker> markers) {
    final count = markers.length;
    final size = count > 100 ? 48.0 : (count > 50 ? 44.0 : 40.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_showClusterSheet(context, markers)),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.accentColor.withValues(alpha: 0.9),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet content listing the nodes inside a tapped map cluster. The
/// sheet is presented via [AppBottomSheet.show]; tapping a row closes the sheet
/// (via its own build context) and invokes [onNodeSelected]. Shared by the main
/// map screen and the route detail map so cluster taps behave identically.
class ClusterListSheet extends StatelessWidget {
  final List<MeshNode> nodes;
  final ValueChanged<MeshNode> onNodeSelected;

  const ClusterListSheet({
    super.key,
    required this.nodes,
    required this.onNodeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bubble_chart, size: 22, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.mapClusterTapToListTitle(nodes.length),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    context.l10n.mapClusterTapToListSubtitle,
                    style: TextStyle(fontSize: 12, color: context.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: nodes.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: context.border.withValues(alpha: 0.3),
            ),
            itemBuilder: (context, index) {
              final node = nodes[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.accentColor.withValues(alpha: 0.15),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    nodeMarkerLabel(node),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: context.accentColor,
                    ),
                  ),
                ),
                title: Text(
                  node.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onNodeSelected(node);
                },
              );
            },
          ),
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
  final PresenceConfidence? presence;

  const MeshNodeMarkerData({
    required this.node,
    required this.latitude,
    required this.longitude,
    this.isStale = false,
    this.presence,
  });

  factory MeshNodeMarkerData.fromNode(
    MeshNode node, {
    bool? isStale,
    PresenceConfidence? presence,
  }) {
    final resolvedPresence = presence ?? node.presenceConfidence;
    return MeshNodeMarkerData(
      node: node,
      latitude: node.latitude ?? 0,
      longitude: node.longitude ?? 0,
      isStale: isStale ?? resolvedPresence.isInactive,
      presence: resolvedPresence,
    );
  }
}

/// Standard node marker widget used across all maps (the main map screen and
/// every [MeshMapWidget] consumer). Renders a node as a circle filled with its
/// per-node identity colour (the official Meshtastic derivation, user override
/// wins) labelled with its short name (or hex fallback). The own node stays on
/// the app accent and pulses; a stale node keeps its colour and shows a "?"
/// badge so it never ghosts away with age.
class MeshNodeMarker extends StatefulWidget {
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
  State<MeshNodeMarker> createState() => _MeshNodeMarkerState();
}

class _MeshNodeMarkerState extends State<MeshNodeMarker>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isMyNode) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2000),
      )..repeat();
      _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeOut),
      );
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Per-node colour (low three bytes of nodeNum as RGB, user override wins)
    // so every node keeps its identity colour on the map and never ghosts with
    // age. The own node uses its identity colour too - the pulse ring and the
    // larger marker mark it as ours, so it reads the same colour peers see.
    final color = resolveNodeColor(
      nodeNum: widget.node.nodeNum,
      avatarColor: widget.node.avatarColor,
    );
    final labelColor = nodeContrastColor(color);

    final marker = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: widget.isSelected
            ? Border.all(
                color: Colors.white,
                width: 3,
                strokeAlign: BorderSide.strokeAlignOutside,
              )
            : null,
        boxShadow: [
          // Coloured glow for selection emphasis.
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: widget.isSelected ? 12 : 6,
            spreadRadius: widget.isSelected ? 2 : 0,
          ),
          // Dark drop shadow defines the circle edge against same-toned map
          // terrain so the marker never blends into the background.
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Full shortName (Meshtastic spec: <=4 chars) instead of just the
          // first character, so a node labelled e.g. "MYSO" reads as itself on
          // the map rather than collapsing to "M". FittedBox keeps long
          // shortnames or wide grapheme clusters from overflowing the circle.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                nodeMarkerLabel(widget.node),
                maxLines: 1,
                style: TextStyle(
                  fontSize: widget.isSelected ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  // Black-or-white by the fill's luminance so the label stays
                  // legible on any per-node colour.
                  color: labelColor,
                ),
              ),
            ),
          ),
          // Stale indicator (small question mark overlay).
          if (widget.isStale)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.card, width: 1.5),
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

    if (!widget.isMyNode || _pulseAnimation == null) return marker;

    return AnimatedBuilder(
      animation: _pulseAnimation!,
      builder: (context, child) {
        final value = _pulseAnimation!.value;
        return CustomPaint(
          painter: _PulseRingPainter(color: color, progress: value),
          child: child,
        );
      },
      child: marker,
    );
  }
}

/// Expanding ring drawn behind the own-node marker to draw the eye to "you".
class _PulseRingPainter extends CustomPainter {
  final Color color;
  final double progress;

  _PulseRingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2 + 10;
    final radius = size.width / 2 + (maxRadius - size.width / 2) * progress;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5 * (1.0 - progress))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * (1.0 - progress);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_PulseRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Helper to calculate the center of multiple nodes
LatLng calculateNodesCenter(List<MeshNodeMarkerData> nodes) {
  const fallback = LatLng(MapConfig.defaultLat, MapConfig.defaultLon);
  final finite = nodes
      .where((n) => n.latitude.isFinite && n.longitude.isFinite)
      .toList(growable: false);
  if (finite.isEmpty) return fallback;

  double avgLat = 0, avgLon = 0;
  for (final node in finite) {
    avgLat += node.latitude;
    avgLon += node.longitude;
  }
  return safeLatLng(avgLat / finite.length, avgLon / finite.length) ?? fallback;
}

/// Helper to calculate zoom level to fit all nodes
double calculateZoomToFitNodes(List<MeshNodeMarkerData> nodes) {
  final finite = nodes
      .where((n) => n.latitude.isFinite && n.longitude.isFinite)
      .toList(growable: false);
  if (finite.length <= 1) return 13.0;

  final lats = finite.map((n) => n.latitude).toList();
  final lons = finite.map((n) => n.longitude).toList();

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
