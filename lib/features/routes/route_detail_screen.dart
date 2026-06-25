// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — full-bleed map Stack with overlaid panels, no app bar
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/map_config.dart';
import '../../core/safe_lat_lng.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/units/distance_format.dart';
import '../../core/widgets/map_controls.dart';
import '../../core/widgets/map_overlay_layers.dart';
import '../../core/widgets/mesh_map_widget.dart';
import '../../core/widgets/waypoint_markers.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../models/telemetry_log.dart';
import '../../utils/presence_utils.dart';
import '../../models/route.dart' as route_model;
import '../../providers/app_providers.dart';
import '../../providers/map_local_waypoints.dart';
import '../../providers/presence_providers.dart';
import '../../providers/telemetry_providers.dart';
import '../waypoints/providers/waypoint_providers.dart';
import '../../utils/share_utils.dart';
import '../../utils/snackbar.dart';

/// Screen showing route details with map view and mesh nodes
class RouteDetailScreen extends ConsumerStatefulWidget {
  final route_model.Route route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen>
    with TickerProviderStateMixin, LifecycleSafeMixin {
  final MapController _mapController = MapController();
  bool _isExporting = false;
  final bool _showNodes = true;
  MapTileStyle _mapStyle = MapTileStyle.dark;
  MeshNode? _selectedNode;
  AnimationController? _animationController;
  double _currentZoom = 13.0;

  // Mirror the main Maps screen's persisted layer toggles so the route map
  // renders identically. Loaded in [_loadMapSettings]; initial values match
  // the map screen's defaults until the load completes.
  bool _clusterMarkers = false;
  bool _showWaypoints = true;
  bool _showMeshWaypoints = true;
  bool _showRangeCircles = false;
  bool _showConnectionLines = false;
  bool _showPositionHistory = false;
  bool _showSatelliteLabels = true;
  bool _showDistanceLabels = true;
  double _connectionMaxDistance = 15.0;
  double _nodeOverlayOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _loadMapSettings();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadMapSettings() async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    if (!mounted) return;
    final index = settings.mapTileStyleIndex;
    safeSetState(() {
      if (index >= 0 && index < MapTileStyle.values.length) {
        _mapStyle = MapTileStyle.values[index];
      }
      _clusterMarkers = settings.mapClusterMarkers;
      _showWaypoints = settings.mapShowWaypoints;
      _showMeshWaypoints = settings.mapShowMeshWaypoints;
      _showRangeCircles = settings.mapShowRangeCircles;
      _showConnectionLines = settings.mapShowConnectionLines;
      _showPositionHistory = settings.mapShowPositionHistory;
      _showSatelliteLabels = settings.satelliteLabelsEnabled;
      _showDistanceLabels = settings.mapShowDistanceLabels;
      _connectionMaxDistance = settings.mapConnectionMaxDistance;
      _nodeOverlayOpacity = settings.mapNodeOverlayOpacity;
    });
  }

  /// Animate camera to a specific location with smooth easing
  void _animatedMove(LatLng destLocation, double destZoom) {
    if (!isFiniteLatLng(destLocation) || !destZoom.isFinite) return;
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
      _mapController.safeMove(
        safeLatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    _animationController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    final presenceMap = ref.watch(presenceMapProvider);
    final route = widget.route;
    final hasLocations = route.locations.isNotEmpty;
    final routeCenter = route.center;
    final LatLng? center = routeCenter == null
        ? null
        : safeLatLng(routeCenter.lat, routeCenter.lon);

    // Get mesh nodes with positions
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final units = ref.watch(measurementUnitsProvider);
    final nodesWithPosition = nodes.values
        .where((node) => node.hasPosition)
        .toList();

    // Same waypoint context as the main Maps screen: shared mesh waypoints and
    // local "dropped pins", rendered below the node markers and the route line.
    final meshWaypoints = ref.watch(meshWaypointsProvider);
    final localWaypoints = ref.watch(mapLocalWaypointsProvider);

    // Persisted position history feeds the movement-trail layer, matching Maps.
    final positionLogs =
        ref.watch(positionLogsProvider).asData?.value ?? <PositionLog>[];

    // Convert to marker data for the shared widget + overlay-layer builders.
    final nodeMarkerData = nodesWithPosition
        .map(
          (node) => MeshNodeMarkerData.fromNode(
            node,
            presence: presenceConfidenceFor(presenceMap, node),
          ),
        )
        .toList();

    return Scaffold(
      backgroundColor: context.background,
      body: Stack(
        children: [
          // Map using shared MeshMapWidget
          if (hasLocations && center != null)
            MeshMapWidget(
              mapController: _mapController,
              mapStyle: _mapStyle,
              initialCenter: center,
              initialZoom: _calculateZoom(route),
              minZoom: 3,
              maxZoom: 18,
              onPositionChanged: (position, hasGesture) {
                if ((position.zoom - _currentZoom).abs() > 0.1) {
                  setState(() => _currentZoom = position.zoom);
                }
              },
              onTap: (_, _) {
                if (_selectedNode != null) {
                  setState(() => _selectedNode = null);
                }
              },
              nodeMarkers: _showNodes ? nodeMarkerData : null,
              selectedNodeNum: _selectedNode?.nodeNum,
              myNodeNum: myNodeNum,
              onNodeTap: (node) => setState(() => _selectedNode = node),
              showSatelliteLabels: _showSatelliteLabels,
              enableClustering: _clusterMarkers,
              disableClusteringAtZoom: MapConfig.clusterDisableZoom(_mapStyle),
              clusterRadius: 80,
              nodeOverlayOpacity: _nodeOverlayOpacity,
              additionalLayers: [
                // Overlay geometry first, matching the main Maps z-order:
                // range circles, movement trails, then connection lines.
                if (_showRangeCircles)
                  CircleLayer(
                    circles: rangeCircleMarkers(
                      context,
                      nodes: nodeMarkerData,
                      myNodeNum: myNodeNum,
                    ),
                  ),
                if (_showPositionHistory)
                  PolylineLayer(
                    polylines: positionHistoryTrailPolylines(
                      context,
                      nodes: nodeMarkerData,
                      myNodeNum: myNodeNum,
                      positionLogs: positionLogs,
                    ),
                  ),
                if (_showConnectionLines)
                  PolylineLayer(
                    polylines: connectionLinePolylines(
                      context,
                      nodes: nodeMarkerData,
                      myNodeNum: myNodeNum,
                      maxDistanceKm: _connectionMaxDistance,
                    ),
                  ),

                // The route line sits above the overlay geometry but below all
                // point markers (waypoints, nodes, start/end).
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.locations
                          .map((l) => LatLng(l.latitude, l.longitude))
                          .toList(),
                      color: Color(route.color),
                      strokeWidth: 4,
                    ),
                  ],
                ),

                // Shared mesh waypoints (WAYPOINT_APP) — orange emoji markers,
                // matching the main Maps screen. Render-only here.
                if (_showMeshWaypoints)
                  MarkerLayer(
                    rotate: true,
                    markers: finiteMarkers(
                      meshWaypoints.map((w) {
                        final point = safeLatLng(w.latitude, w.longitude);
                        if (point == null) return null;
                        return Marker(
                          point: point,
                          width: 40,
                          height: 40,
                          child: MeshWaypointMarker(
                            iconCodePoint: w.icon,
                            hasIcon: w.hasRenderableIcon,
                          ),
                        );
                      }).whereType<Marker>(),
                    ),
                  ),

                // Local "dropped pin" waypoints (yellow), matching Maps.
                if (_showWaypoints)
                  MarkerLayer(
                    rotate: true,
                    markers: finiteMarkers(
                      localWaypoints.map(
                        (w) => Marker(
                          point: w.position,
                          width: 32,
                          height: 40,
                          child: const LocalWaypointMarker(),
                        ),
                      ),
                    ),
                  ),

                // Distance labels between the own node and nearby peers.
                if (_showDistanceLabels)
                  MarkerLayer(
                    rotate: true,
                    markers: finiteMarkers(
                      distanceLabelMarkers(
                        context,
                        nodes: nodeMarkerData,
                        myNodeNum: myNodeNum,
                        zoomedIn: _currentZoom >= 10,
                        formatDistance: (km) =>
                            formatDistanceKm(km, units, context.l10n),
                      ),
                    ),
                  ),

                // Start/End route markers
                if (route.locations.isNotEmpty)
                  MarkerLayer(
                    markers: finiteMarkers([
                      // Start marker
                      Marker(
                        point: LatLng(
                          route.locations.first.latitude,
                          route.locations.first.longitude,
                        ),
                        width: 32,
                        height: 32,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AccentColors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // End marker
                      if (route.locations.length > 1)
                        Marker(
                          point: LatLng(
                            route.locations.last.latitude,
                            route.locations.last.longitude,
                          ),
                          width: 32,
                          height: 32,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.stop,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ]),
                  ),
              ],
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    context.l10n.routeDetailNoGpsPoints,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

          // Top bar with back button and title
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          route.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(route.createdAt),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share, color: Colors.white),
                    onPressed: _isExporting ? null : _exportRoute,
                  ),
                ],
              ),
            ),
          ),

          // Selected node info card
          if (_selectedNode != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right:
                  16 +
                  MapControlLayout.controlSize +
                  MapControlLayout.controlSpacing,
              child: _NodeInfoCard(
                node: _selectedNode!,
                isMyNode: _selectedNode!.nodeNum == myNodeNum,
                presence: presenceConfidenceFor(presenceMap, _selectedNode!),
                lastHeardAge: lastHeardAgeFor(presenceMap, _selectedNode!),
                onClose: () => setState(() => _selectedNode = null),
                onCenter: () {
                  if (_selectedNode!.hasPosition) {
                    _animatedMove(
                      LatLng(
                        _selectedNode!.latitude!,
                        _selectedNode!.longitude!,
                      ),
                      15.0,
                    );
                  }
                },
              ),
            ),

          // Map controls - use shared overlay for consistency
          if (hasLocations)
            MapControlsOverlay(
              currentZoom: _currentZoom,
              minZoom: 3,
              maxZoom: 18,
              onZoomIn: () {
                final newZoom = (_currentZoom + 1).clamp(3.0, 18.0);
                _animatedMove(_mapController.camera.center, newZoom);
              },
              onZoomOut: () {
                final newZoom = (_currentZoom - 1).clamp(3.0, 18.0);
                _animatedMove(_mapController.camera.center, newZoom);
              },
              onFitAll: _fitBounds,
              onResetNorth: () {},
              showFitAll: true,
              showNavigation: false,
              showCompass: false,
              mapRotation: 0,
              topOffset:
                  MediaQuery.of(context).padding.top +
                  kToolbarHeight +
                  MapControlLayout.padding,
            ),

          // Stats panel at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.9),
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                        icon: Icons.straighten,
                        label: context.l10n.routeDetailDistanceLabel,
                        value: _formatDistance(route.totalDistance),
                      ),
                      _StatItem(
                        icon: Icons.timer_outlined,
                        label: context.l10n.routeDetailDurationLabel,
                        value: route.duration != null
                            ? _formatDuration(route.duration!)
                            : context.l10n.routeDetailNoData,
                      ),
                      _StatItem(
                        icon: Icons.terrain,
                        label: context.l10n.routeDetailElevationLabel,
                        value: context.l10n.routeDetailElevationValue(
                          route.elevationGain.toStringAsFixed(0),
                        ),
                      ),
                      _StatItem(
                        icon: Icons.location_on,
                        label: context.l10n.routeDetailPointsLabel,
                        value: '${route.locations.length}',
                      ),
                    ],
                  ),
                  if (route.notes != null && route.notes!.isNotEmpty) ...[
                    SizedBox(height: AppTheme.spacing12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.spacing12),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                      child: Text(
                        route.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateZoom(route_model.Route route) {
    if (route.locations.isEmpty) return 14;
    if (route.locations.length == 1) return 16;

    // Calculate bounds
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLon = double.infinity;
    double maxLon = -double.infinity;

    for (final loc in route.locations) {
      if (loc.latitude < minLat) minLat = loc.latitude;
      if (loc.latitude > maxLat) maxLat = loc.latitude;
      if (loc.longitude < minLon) minLon = loc.longitude;
      if (loc.longitude > maxLon) maxLon = loc.longitude;
    }

    // Estimate zoom based on span
    final latSpan = maxLat - minLat;
    final lonSpan = maxLon - minLon;
    final maxSpan = latSpan > lonSpan ? latSpan : lonSpan;

    if (maxSpan < 0.001) return 17;
    if (maxSpan < 0.01) return 15;
    if (maxSpan < 0.1) return 13;
    if (maxSpan < 1) return 10;
    return 8;
  }

  void _fitBounds() {
    if (widget.route.locations.isEmpty) return;

    final points = widget.route.locations.map(
      (l) => LatLng(l.latitude, l.longitude),
    );
    final bounds = safeLatLngBounds(points);
    if (bounds == null) return;

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(AppTheme.spacing50),
      ),
    );
  }

  Future<void> _exportRoute() async {
    safeSetState(() => _isExporting = true);
    final l10n = context.l10n;

    // Get the render box for sharePositionOrigin (required on iPad) before async
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);

    // Capture provider before async gap
    final storageAsync = ref.read(routeStorageProvider);

    try {
      final storage = storageAsync.value;
      if (storage == null) {
        if (mounted) {
          showErrorSnackBar(context, l10n.routeDetailStorageUnavailable);
        }
        return;
      }

      final gpx = storage.exportRouteAsGpx(widget.route);
      final fileName =
          '${widget.route.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.gpx';

      // Get temp directory and save file
      final tempDir = await getTemporaryDirectory();
      if (!mounted) return;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(gpx);
      if (!mounted) return;

      // Share file using shareXFiles for proper file sharing
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
        text: l10n.routeDetailShareText(widget.route.name),
        sharePositionOrigin: getSafeSharePosition(null, sharePositionOrigin),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, l10n.routeDetailExportFailed(e.toString()));
      }
    } finally {
      safeSetState(() => _isExporting = false);
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return context.l10n.routeDetailDistanceMeters(meters.toStringAsFixed(0));
    }
    return context.l10n.routeDetailDistanceKilometers(
      (meters / 1000).toStringAsFixed(2),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return context.l10n.routeDetailDurationMinutes(duration.inMinutes);
    }
    return context.l10n.routeDetailDurationHoursMinutes(
      duration.inHours,
      duration.inMinutes % 60,
    );
  }
}

/// Info card shown when a node is selected
class _NodeInfoCard extends StatelessWidget {
  final MeshNode node;
  final bool isMyNode;
  final PresenceConfidence presence;
  final Duration? lastHeardAge;
  final VoidCallback onClose;
  final VoidCallback onCenter;

  const _NodeInfoCard({
    required this.node,
    required this.isMyNode,
    required this.presence,
    required this.lastHeardAge,
    required this.onClose,
    required this.onCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.card.withValues(alpha: 0.95),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: presence.isActive
                    ? AccentColors.green
                    : context.textTertiary,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            // Node info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        node.displayName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      if (isMyNode) ...[
                        const SizedBox(width: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius4,
                            ),
                          ),
                          child: Text(
                            context.l10n.routeDetailYouBadge,
                            style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Tooltip(
                    message: kPresenceInferenceTooltip,
                    child: Text(
                      presenceStatusText(presence, lastHeardAge),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Actions
            IconButton(
              icon: const Icon(Icons.my_location, size: 20),
              onPressed: onCenter,
              tooltip: context.l10n.routeDetailCenterOnNodeTooltip,
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: AccentColors.blue),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        Text(
          label,
          style: context.bodySmallStyle?.copyWith(color: context.textSecondary),
        ),
      ],
    );
  }
}
