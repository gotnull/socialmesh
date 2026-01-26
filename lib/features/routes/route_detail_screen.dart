import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/map_config.dart';
import '../../core/theme.dart';
import '../../core/widgets/map_controls.dart';
import '../../core/widgets/mesh_map_widget.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../utils/presence_utils.dart';
import '../../models/route.dart' as route_model;
import '../../providers/app_providers.dart';
import '../../providers/presence_providers.dart';
import '../../providers/telemetry_providers.dart';
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
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isExporting = false;
  final bool _showNodes = true;
  MapTileStyle _mapStyle = MapTileStyle.dark;
  MeshNode? _selectedNode;
  AnimationController? _animationController;
  double _currentZoom = 13.0;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    final settings = await ref.read(settingsServiceProvider.future);
    final index = settings.mapTileStyleIndex;
    if (!mounted) return;
    if (index >= 0 && index < MapTileStyle.values.length) {
      setState(() => _mapStyle = MapTileStyle.values[index]);
    }
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

  @override
  Widget build(BuildContext context) {
    final presenceMap = ref.watch(presenceMapProvider);
    final route = widget.route;
    final hasLocations = route.locations.isNotEmpty;
    final center = route.center;

    // Get mesh nodes with positions
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final nodesWithPosition = nodes.values
        .where((node) => node.hasPosition)
        .toList();

    // Convert to marker data for shared widget
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
              initialCenter: LatLng(center.lat, center.lon),
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
              additionalLayers: [
                // Route polyline
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

                // Start/End route markers
                if (route.locations.isNotEmpty)
                  MarkerLayer(
                    markers: [
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
                    ],
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
                  const SizedBox(height: 16),
                  Text(
                    'No GPS Points',
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
                  const SizedBox(width: 8),
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
              right: 16 + MapControlLayout.controlSize + MapControlLayout.controlSpacing,
              child: _NodeInfoCard(
                node: _selectedNode!,
                isMyNode: _selectedNode!.nodeNum == myNodeNum,
                presence: presenceConfidenceFor(
                  presenceMap,
                  _selectedNode!,
                ),
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
                        label: 'Distance',
                        value: _formatDistance(route.totalDistance),
                      ),
                      _StatItem(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value: route.duration != null
                            ? _formatDuration(route.duration!)
                            : '--',
                      ),
                      _StatItem(
                        icon: Icons.terrain,
                        label: 'Elevation',
                        value: '${route.elevationGain.toStringAsFixed(0)}m',
                      ),
                      _StatItem(
                        icon: Icons.location_on,
                        label: 'Points',
                        value: '${route.locations.length}',
                      ),
                    ],
                  ),
                  if (route.notes != null && route.notes!.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
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

    final points = widget.route.locations
        .map((l) => LatLng(l.latitude, l.longitude))
        .toList();

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  Future<void> _exportRoute() async {
    setState(() => _isExporting = true);

    // Get the render box for sharePositionOrigin (required on iPad) before async
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);

    try {
      final storageAsync = ref.read(routeStorageProvider);
      final storage = storageAsync.value;
      if (storage == null) {
        if (mounted) {
          showErrorSnackBar(context, 'Storage not available');
        }
        return;
      }

      final gpx = storage.exportRouteAsGpx(widget.route);
      final fileName =
          '${widget.route.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.gpx';

      // Get temp directory and save file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(gpx);

      // Share file using shareXFiles for proper file sharing
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
        text: 'Route: ${widget.route.name}',
        sharePositionOrigin: getSafeSharePosition(null, sharePositionOrigin),
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Export failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)}m';
    }
    return '${(meters / 1000).toStringAsFixed(2)}km';
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}min';
    }
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
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
        padding: const EdgeInsets.all(12),
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
            const SizedBox(width: 12),
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
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'You',
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
                  const SizedBox(height: 4),
                  Tooltip(
                    message: kPresenceInferenceTooltip,
                    child: Text(
                      presenceStatusText(
                        presence,
                        lastHeardAge,
                      ),
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
              tooltip: 'Center on node',
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
        const SizedBox(height: 4),
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
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
      ],
    );
  }
}
