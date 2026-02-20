// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../providers/countdown_providers.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/map_config.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/map_controls.dart';
import '../../core/widgets/node_info_card.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/mesh_models.dart';
import '../../models/presence_confidence.dart';
import '../../providers/app_providers.dart';
import '../../providers/presence_providers.dart';
import '../../providers/help_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/share_link_service.dart';
import '../../utils/presence_utils.dart';
import '../messaging/messaging_screen.dart';
import '../navigation/main_shell.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../tak/models/tak_event.dart';
import '../tak/providers/tak_filter_provider.dart';
import '../tak/providers/tak_providers.dart';
import '../tak/providers/tak_tracking_provider.dart';
import '../tak/utils/cot_affiliation.dart';
import '../tak/screens/tak_dashboard_screen.dart';
import '../tak/screens/tak_event_detail_screen.dart';
import '../tak/widgets/tak_map_layer.dart';
import '../tak/widgets/tak_heading_vector_layer.dart';

/// Node filter options
enum NodeFilter {
  all('All'),
  active('Active'),
  inactive('Inactive'),
  withGps('With GPS'),
  inRange('In Range');

  final String label;
  const NodeFilter(this.label);
}

/// Map screen showing all mesh nodes with GPS positions
class MapScreen extends ConsumerStatefulWidget {
  final int? initialNodeNum;
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialLocationLabel;

  /// When true, hides all mesh nodes and only shows the location marker.
  /// Useful for viewing a specific location without clutter.
  final bool locationOnlyMode;

  const MapScreen({
    super.key,
    this.initialNodeNum,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationLabel,
    this.locationOnlyMode = false,
  });

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin, LifecycleSafeMixin<MapScreen> {
  final MapController _mapController = MapController();
  MeshNode? _selectedNode;
  bool _showHeatmap = false;
  bool _isRefreshing = false;
  double _currentZoom = 14.0;
  bool _showNodeList = false;
  bool _showFilters = false;
  bool _measureMode = false;
  bool _showRangeCircles = false;
  bool _showConnectionLines = false;
  bool _showTakLayer = true;
  double _connectionMaxDistance =
      15.0; // km - max distance for connection lines
  String _searchQuery = '';

  // TAK entity state
  TakEvent? _selectedTakEntity;
  int _panelTab = 0; // 0 = Nodes, 1 = TAK Entities

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

  // Search controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _takSearchController = TextEditingController();

  // Track if initial node centering has been done
  bool _initialCenteringDone = false;

  // One-shot flag: consume TAK provider values that were set before
  // this widget built (ref.listen only fires on *changes*, not
  // the current value at subscription time).
  bool _takInitialCheckDone = false;

  // Layout constants for consistent spacing
  static const double _mapPadding = 16.0;
  static const double _controlSpacing = 8.0;
  static const double _controlSize = 44.0;

  @override
  void dispose() {
    _animationController?.dispose();
    _mapController.dispose();
    _searchController.dispose();
    _takSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
  }

  Future<void> _loadMapStyle() async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    if (!mounted) return;
    final index = settings.mapTileStyleIndex;
    if (index >= 0 && index < MapTileStyle.values.length) {
      safeSetState(() => _mapStyle = MapTileStyle.values[index]);
    }
  }

  Future<void> _saveMapStyle(MapTileStyle style) async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    if (!mounted) return;
    await settings.setMapTileStyleIndex(style.index);
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
  List<_NodeWithPosition> _getNodesWithPositions(
    Map<int, MeshNode> nodes,
    Map<int, NodePresence> presenceMap,
  ) {
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

        if (presenceConfidenceFor(presenceMap, node).isActive || !isStale) {
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
    Map<int, NodePresence> presenceMap,
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
      case NodeFilter.active:
        filtered = filtered
            .where((n) => presenceConfidenceFor(presenceMap, n.node).isActive)
            .toList();
        break;
      case NodeFilter.inactive:
        filtered = filtered
            .where((n) => presenceConfidenceFor(presenceMap, n.node).isInactive)
            .toList();
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

    // Prevent duplicate requests while a countdown is active
    final notifier = ref.read(countdownProvider.notifier);
    if (notifier.isPositionRequestActive) return;

    setState(() => _isRefreshing = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.requestAllPositions();

      if (!mounted) return;

      // Start global position request countdown — banner persists
      // across navigation and sets expectations for trickle-in time.
      notifier.startPositionRequestCountdown();
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
      _selectedTakEntity = null;
      _showNodeList = false;
    });
    _animatedMove(LatLng(nodeWithPos.latitude, nodeWithPos.longitude), 15.0);
    HapticFeedback.selectionClick();
  }

  void _addWaypoint(LatLng point, {String? label}) {
    setState(() {
      _waypoints.add(
        _Waypoint(
          id: DateTime.now().millisecondsSinceEpoch,
          position: point,
          label: label ?? 'WP ${_waypoints.length + 1}',
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
    // Get share position for iPad support
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);

    ref
        .read(shareLinkServiceProvider)
        .shareLocation(
          latitude: point.latitude,
          longitude: point.longitude,
          label: label,
          sharePositionOrigin: sharePositionOrigin,
        );
  }

  void _copyCoordinates(LatLng point) {
    final lat = point.latitude.toStringAsFixed(6);
    final lng = point.longitude.toStringAsFixed(6);
    Clipboard.setData(ClipboardData(text: '$lat, $lng'));
    showSuccessSnackBar(context, 'Coordinates copied to clipboard');
  }

  @override
  Widget build(BuildContext context) {
    // When the drawer's "TAK Map" item is tapped, it switches to this tab
    // and requests TAK mode via the provider. Consume and reset it here.
    ref.listen<bool>(mapTakModeProvider, (prev, next) {
      if (next) {
        ref.read(mapTakModeProvider.notifier).consume();
        safeSetState(() {
          _showTakLayer = true;
          _panelTab = 1;
          _showNodeList = true;
        });
      }
    });

    // When "Show on Map" is tapped in the TAK detail screen, consume the
    // pending event and center the map on its coordinates.
    ref.listen<TakEvent?>(takShowOnMapProvider, (prev, next) {
      if (next != null) {
        ref.read(takShowOnMapProvider.notifier).consume();
        safeSetState(() {
          _showTakLayer = true;
          _selectedTakEntity = next;
          _selectedNode = null;
          _showNodeList = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animatedMove(LatLng(next.lat, next.lon), 15.0);
        });
      }
    });

    // One-shot: pick up TAK provider values that were set before this
    // widget built (e.g. "Show on Map" in TakEventDetailScreen sets the
    // providers, pops the stack, and MainShell then builds MapScreen
    // fresh — ref.listen misses the already-set value).
    if (!_takInitialCheckDone) {
      _takInitialCheckDone = true;

      final pendingTakMode = ref.read(mapTakModeProvider);
      if (pendingTakMode) {
        ref.read(mapTakModeProvider.notifier).consume();
        _showTakLayer = true;
        _panelTab = 1;
        _showNodeList = true;
      }

      final pendingEvent = ref.read(takShowOnMapProvider);
      if (pendingEvent != null) {
        ref.read(takShowOnMapProvider.notifier).consume();
        _showTakLayer = true;
        _selectedTakEntity = pendingEvent;
        _selectedNode = null;
        _showNodeList = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animatedMove(LatLng(pendingEvent.lat, pendingEvent.lon), 15.0);
        });
      }
    }

    final nodes = ref.watch(nodesProvider);
    final presenceMap = ref.watch(presenceMapProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    // Get nodes with positions (current or cached)
    final allNodesWithPosition = _getNodesWithPositions(nodes, presenceMap);
    final nodesWithPosition = _filterNodes(
      allNodesWithPosition,
      myNodeNum,
      presenceMap,
    );

    // Handle initial node centering from navigation
    if (!_initialCenteringDone && widget.initialNodeNum != null) {
      _initialCenteringDone = true;
      final targetNode = nodesWithPosition
          .where((n) => n.node.nodeNum == widget.initialNodeNum)
          .firstOrNull;
      if (targetNode != null) {
        // Schedule centering after the map is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _animatedMove(
            LatLng(targetNode.latitude, targetNode.longitude),
            15.0,
          );
          setState(() => _selectedNode = targetNode.node);
        });
      }
    }

    // Handle initial location centering (from post location tap or deep link)
    if (!_initialCenteringDone &&
        widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      _initialCenteringDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animatedMove(
          LatLng(widget.initialLatitude!, widget.initialLongitude!),
          15.0,
        );
        // Add a temporary waypoint to show the location
        if (widget.initialLocationLabel != null) {
          _addWaypoint(
            LatLng(widget.initialLatitude!, widget.initialLongitude!),
            label: widget.initialLocationLabel,
          );
        }
      });
    }

    // Calculate center point
    LatLng center = const LatLng(0, 0);
    double zoom = 2.0;

    // In location only mode, use the provided coordinates
    if (widget.locationOnlyMode &&
        widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      center = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      zoom = 15.0;
    } else if (nodesWithPosition.isNotEmpty) {
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

    // Check if this screen was pushed (can pop) or is a root drawer screen.
    // Use route.isFirst to avoid drawer local-history entries flipping this.
    final route = ModalRoute.of(context);
    final canPop = route != null ? !route.isFirst : Navigator.canPop(context);

    return HelpTourController(
      topicId: 'map_overview',
      stepKeys: const {},
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.background,
          leading: canPop ? const BackButton() : const HamburgerMenuButton(),
          centerTitle: true,
          title: Text(
            widget.locationOnlyMode
                ? (widget.initialLocationLabel ?? 'Location')
                : 'Mesh Map',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          actions: [
            // Filter toggle - hide in location only mode
            if (!widget.locationOnlyMode)
              IconButton(
                icon: Icon(
                  _nodeFilter != NodeFilter.all || _showFilters
                      ? Icons.filter_alt
                      : Icons.filter_alt_outlined,
                  color: _nodeFilter != NodeFilter.all || _showFilters
                      ? context.accentColor
                      : context.textSecondary,
                ),
                onPressed: () => setState(() => _showFilters = !_showFilters),
                tooltip: 'Filter nodes',
              ),
            // Map style
            PopupMenuButton<MapTileStyle>(
              icon: Icon(Icons.map, color: context.textSecondary),
              tooltip: 'Map style',
              onSelected: (style) {
                setState(() => _mapStyle = style);
                unawaited(_saveMapStyle(style));
              },
              itemBuilder: (context) => MapTileStyle.values.map((style) {
                return PopupMenuItem(
                  value: style,
                  child: Row(
                    children: [
                      Icon(
                        _mapStyle == style ? Icons.check : Icons.map_outlined,
                        size: 18,
                        color: _mapStyle == style
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(style.label),
                    ],
                  ),
                );
              }).toList(),
            ),
            // Device status - hide in location only mode
            if (!widget.locationOnlyMode) const DeviceStatusButton(),
            // More options menu
            AppBarOverflowMenu<String>(
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _refreshPositions();
                    break;
                  case 'heatmap':
                    setState(() => _showHeatmap = !_showHeatmap);
                    break;
                  case 'connections':
                    setState(
                      () => _showConnectionLines = !_showConnectionLines,
                    );
                    break;
                  case 'distance_1':
                    setState(() => _connectionMaxDistance = 1.0);
                    break;
                  case 'distance_5':
                    setState(() => _connectionMaxDistance = 5.0);
                    break;
                  case 'distance_10':
                    setState(() => _connectionMaxDistance = 10.0);
                    break;
                  case 'distance_25':
                    setState(() => _connectionMaxDistance = 25.0);
                    break;
                  case 'distance_all':
                    setState(() => _connectionMaxDistance = 100.0);
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
                  case 'tak_layer':
                    setState(() => _showTakLayer = !_showTakLayer);
                    AppLogging.tak(
                      'Map TAK layer toggled: visible=$_showTakLayer',
                    );
                    break;
                  case 'tak_dashboard':
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const TakDashboardScreen(),
                      ),
                    );
                    break;
                  case 'globe':
                    Navigator.of(context).pushNamed('/globe');
                    break;
                  case 'help':
                    ref.read(helpProvider.notifier).startTour('map_overview');
                    break;
                  case 'settings':
                    Navigator.of(context).pushNamed('/settings');
                    break;
                }
              },
              itemBuilder: (context) => [
                // Node-related options - hide in location only mode
                if (!widget.locationOnlyMode) ...[
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 18,
                          color: _isRefreshing
                              ? context.textTertiary
                              : context.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _isRefreshing ? 'Refreshing...' : 'Refresh positions',
                        ),
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
                              ? context.accentColor
                              : context.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(_showHeatmap ? 'Hide heatmap' : 'Show heatmap'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'connections',
                    child: Row(
                      children: [
                        Icon(
                          _showConnectionLines
                              ? Icons.share
                              : Icons.share_outlined,
                          size: 18,
                          color: _showConnectionLines
                              ? context.accentColor
                              : context.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _showConnectionLines
                              ? 'Hide connection lines'
                              : 'Show connection lines',
                        ),
                      ],
                    ),
                  ),
                  // Distance filter options (only shown when connections are enabled)
                  if (_showConnectionLines) ...[
                    PopupMenuItem(
                      enabled: false,
                      height: 32,
                      child: Text(
                        'Max Distance',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'distance_1',
                      child: Row(
                        children: [
                          Icon(
                            _connectionMaxDistance == 1.0
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 16,
                            color: _connectionMaxDistance == 1.0
                                ? context.accentColor
                                : context.textTertiary,
                          ),
                          SizedBox(width: 8),
                          const Text('1 km'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'distance_5',
                      child: Row(
                        children: [
                          Icon(
                            _connectionMaxDistance == 5.0
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 16,
                            color: _connectionMaxDistance == 5.0
                                ? context.accentColor
                                : context.textTertiary,
                          ),
                          SizedBox(width: 8),
                          const Text('5 km'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'distance_10',
                      child: Row(
                        children: [
                          Icon(
                            _connectionMaxDistance == 10.0
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 16,
                            color: _connectionMaxDistance == 10.0
                                ? context.accentColor
                                : context.textTertiary,
                          ),
                          SizedBox(width: 8),
                          const Text('10 km'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'distance_25',
                      child: Row(
                        children: [
                          Icon(
                            _connectionMaxDistance == 25.0
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 16,
                            color: _connectionMaxDistance == 25.0
                                ? context.accentColor
                                : context.textTertiary,
                          ),
                          SizedBox(width: 8),
                          const Text('25 km'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'distance_all',
                      child: Row(
                        children: [
                          Icon(
                            _connectionMaxDistance >= 100.0
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 16,
                            color: _connectionMaxDistance >= 100.0
                                ? context.accentColor
                                : context.textTertiary,
                          ),
                          SizedBox(width: 8),
                          const Text('All'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ],
                  PopupMenuItem(
                    value: 'range',
                    child: Row(
                      children: [
                        Icon(
                          Icons.radio_button_unchecked,
                          size: 18,
                          color: _showRangeCircles
                              ? context.accentColor
                              : context.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _showRangeCircles
                              ? 'Hide range circles'
                              : 'Show range circles',
                        ),
                      ],
                    ),
                  ),
                ], // End of node-related options
                PopupMenuItem(
                  value: 'measure',
                  child: Row(
                    children: [
                      Icon(
                        Icons.straighten,
                        size: 18,
                        color: _measureMode
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        _measureMode ? 'Exit measure mode' : 'Measure distance',
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'globe',
                  child: Row(
                    children: [
                      Icon(
                        Icons.public,
                        size: 18,
                        color: context.textSecondary,
                      ),
                      SizedBox(width: 8),
                      const Text('3D Globe View'),
                    ],
                  ),
                ),
                if (AppFeatureFlags.isTakGatewayEnabled &&
                    !widget.locationOnlyMode) ...[
                  PopupMenuItem(
                    value: 'tak_layer',
                    child: Row(
                      children: [
                        Icon(
                          _showTakLayer
                              ? Icons.military_tech
                              : Icons.military_tech_outlined,
                          size: 18,
                          color: _showTakLayer
                              ? context.accentColor
                              : context.textSecondary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          _showTakLayer
                              ? 'Hide TAK entities'
                              : 'Show TAK entities',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'tak_dashboard',
                    child: Row(
                      children: [
                        Icon(
                          Icons.dashboard_outlined,
                          size: 18,
                          color: context.textSecondary,
                        ),
                        SizedBox(width: 8),
                        const Text('SA Dashboard'),
                      ],
                    ),
                  ),
                ],
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 18,
                        color: context.textSecondary,
                      ),
                      SizedBox(width: 8),
                      const Text('Help'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(
                        Icons.settings_outlined,
                        size: 18,
                        color: context.textSecondary,
                      ),
                      SizedBox(width: 8),
                      const Text('Settings'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: (!widget.locationOnlyMode && allNodesWithPosition.isEmpty)
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
                      backgroundColor: context.background,
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
                            _selectedTakEntity = null;
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
                        subdomains: _mapStyle.subdomains,
                        userAgentPackageName: MapConfig.userAgentPackageName,
                        retinaMode: _mapStyle != MapTileStyle.satellite,
                        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                        tileBuilder: (context, tileWidget, tile) {
                          return AnimatedOpacity(
                            opacity: 1.0,
                            duration: const Duration(milliseconds: 300),
                            child: tileWidget,
                          );
                        },
                      ),
                      // Range circles (theoretical coverage) - hide in location only mode
                      if (_showRangeCircles && !widget.locationOnlyMode)
                        CircleLayer(
                          circles: nodesWithPosition.map((n) {
                            final isMyNode = n.node.nodeNum == myNodeNum;
                            return CircleMarker(
                              point: LatLng(n.latitude, n.longitude),
                              radius: 5000, // 5km range circle
                              useRadiusInMeter: true,
                              color:
                                  (isMyNode
                                          ? context.accentColor
                                          : AppTheme.primaryPurple)
                                      .withValues(alpha: 0.08),
                              borderColor:
                                  (isMyNode
                                          ? context.accentColor
                                          : AppTheme.primaryPurple)
                                      .withValues(alpha: 0.2),
                              borderStrokeWidth: 1,
                            );
                          }).toList(),
                        ),
                      // Heatmap layer - hide in location only mode
                      if (_showHeatmap && !widget.locationOnlyMode)
                        CircleLayer(
                          circles: nodesWithPosition.map((n) {
                            return CircleMarker(
                              point: LatLng(n.latitude, n.longitude),
                              radius: 50,
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderColor: context.accentColor.withValues(
                                alpha: 0.3,
                              ),
                              borderStrokeWidth: 1,
                            );
                          }).toList(),
                        ),
                      // Node trails (movement history) - hide in location only mode
                      if (!widget.locationOnlyMode)
                        PolylineLayer(
                          polylines: _buildNodeTrails(
                            nodesWithPosition,
                            myNodeNum,
                          ),
                        ),
                      // Connection lines (optional) - hide in location only mode
                      if (_showConnectionLines && !widget.locationOnlyMode)
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
                        rotate: true,
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
                      // Node markers - hide in location only mode
                      if (!widget.locationOnlyMode)
                        MarkerLayer(
                          rotate: true,
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
                                  setState(() {
                                    _selectedNode = n.node;
                                    _selectedTakEntity = null;
                                  });
                                },
                                child: _NodeMarker(
                                  node: n.node,
                                  presence: presenceConfidenceFor(
                                    presenceMap,
                                    n.node,
                                  ),
                                  isMyNode: isMyNode,
                                  isSelected: isSelected,
                                  isStale: n.isStale,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      // TAK entity markers - separate layer from mesh nodes
                      if (_showTakLayer &&
                          !widget.locationOnlyMode &&
                          AppFeatureFlags.isTakGatewayEnabled)
                        _TakMarkerLayer(
                          onMarkerTap: (event) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedNode = null;
                              _selectedTakEntity = event;
                            });
                          },
                          onMarkerLongPress: (event) async {
                            final tracking = ref.read(
                              takTrackingProvider.notifier,
                            );
                            final nowTracked = await tracking.toggle(event.uid);
                            if (!mounted) return;
                            ref.haptics.longPress();
                            AppLogging.tak(
                              'Map TAK entity '
                              '${nowTracked ? "tracked" : "untracked"}: '
                              'uid=${event.uid}, '
                              'callsign=${event.displayName}',
                            );
                          },
                        ),
                      // TAK heading vectors - above markers, below popups
                      if (_showTakLayer &&
                          !widget.locationOnlyMode &&
                          AppFeatureFlags.isTakGatewayEnabled)
                        _TakHeadingVectorOverlay(),
                      // Measurement markers
                      if (_measureStart != null)
                        MarkerLayer(
                          rotate: true,
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
                      // Distance labels layer - hide in location only mode
                      if (!widget.locationOnlyMode)
                        MarkerLayer(
                          rotate: true,
                          markers: _buildDistanceLabels(
                            nodesWithPosition,
                            myNodeNum,
                          ),
                        ),
                      // Map attribution (matches world mesh style)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse(
                              _mapStyle == MapTileStyle.satellite
                                  ? 'https://www.esri.com'
                                  : _mapStyle == MapTileStyle.terrain
                                  ? 'https://opentopomap.org'
                                  : 'https://carto.com/attributions',
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _mapStyle == MapTileStyle.satellite
                                  ? '© Esri'
                                  : _mapStyle == MapTileStyle.terrain
                                  ? '© OpenTopoMap © OSM'
                                  : '© OSM © CARTO',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Filter bar - hide in location only mode
                  if (_showFilters && !widget.locationOnlyMode)
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
                        onExitMeasureMode: () => setState(() {
                          _measureMode = false;
                          _measureStart = null;
                          _measureEnd = null;
                        }),
                      ),
                    ),
                  // Mode indicator (centered at top)
                  if (_measureMode &&
                      (_measureStart == null || _measureEnd == null))
                    Positioned(
                      top: _mapPadding,
                      left:
                          _mapPadding + 140, // Leave room for node count badge
                      right: _mapPadding + _controlSize + _controlSpacing,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.only(
                            left: 16,
                            top: 4,
                            bottom: 4,
                            right: 4,
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
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => setState(() {
                                  _measureMode = false;
                                  _measureStart = null;
                                  _measureEnd = null;
                                }),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Node info card - hide in location only mode
                  if (_selectedNode != null && !widget.locationOnlyMode)
                    Positioned(
                      left: _mapPadding,
                      right: _mapPadding,
                      bottom: _mapPadding,
                      child: NodeInfoCard(
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
                              LatLng(
                                nodeWithPos.latitude,
                                nodeWithPos.longitude,
                              ),
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
                              LatLng(
                                nodeWithPos.latitude,
                                nodeWithPos.longitude,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  // TAK entity info card
                  if (_selectedTakEntity != null && !widget.locationOnlyMode)
                    Positioned(
                      left: _mapPadding,
                      right: _mapPadding,
                      bottom: _mapPadding,
                      child: _TakEntityInfoCard(
                        event: _selectedTakEntity!,
                        isTracked: ref
                            .watch(takTrackedUidsProvider)
                            .contains(_selectedTakEntity!.uid),
                        onClose: () =>
                            setState(() => _selectedTakEntity = null),
                        onCopyCoordinates: () => _copyCoordinates(
                          LatLng(
                            _selectedTakEntity!.lat,
                            _selectedTakEntity!.lon,
                          ),
                        ),
                        onTapDetail: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TakEventDetailScreen(
                                event: _selectedTakEntity!,
                              ),
                            ),
                          );
                        },
                        onToggleTracking: () async {
                          final tracking = ref.read(
                            takTrackingProvider.notifier,
                          );
                          await tracking.toggle(_selectedTakEntity!.uid);
                          if (!mounted) return;
                          ref.haptics.toggle();
                        },
                      ),
                    ),
                  // Node list panel - hide in location only mode
                  if (!widget.locationOnlyMode)
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
                        calculateDistanceFromMe: (node) =>
                            _getDistanceFromMyNode(
                              node.node,
                              nodesWithPosition,
                              myNodeNum,
                            ),
                        searchController: _searchController,
                        onSearchChanged: (query) =>
                            setState(() => _searchQuery = query),
                        takSearchController: _takSearchController,
                        onTakSearchChanged: (_) => setState(() {}),
                        presenceMap: presenceMap,
                        showTakTab:
                            _showTakLayer &&
                            AppFeatureFlags.isTakGatewayEnabled,
                        activeTab: _panelTab,
                        onTabChanged: (tab) => setState(() => _panelTab = tab),
                        takEvents:
                            _showTakLayer && AppFeatureFlags.isTakGatewayEnabled
                            ? ref.watch(filteredTakEventsProvider)
                            : const [],
                        onTakEntitySelected: (event) {
                          setState(() {
                            _selectedTakEntity = event;
                            _selectedNode = null;
                            _showNodeList = false;
                          });
                          _animatedMove(LatLng(event.lat, event.lon), 15.0);
                          HapticFeedback.selectionClick();
                        },
                      ),
                    ),
                  // Node count indicator - hide in location only mode
                  if (!_showNodeList &&
                      !_showFilters &&
                      !widget.locationOnlyMode)
                    Positioned(
                      left: _mapPadding,
                      top: _mapPadding,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _showNodeList = true;
                          _selectedNode = null;
                          _selectedTakEntity = null;
                        }),
                        child: Builder(
                          builder: (context) {
                            final takCount =
                                _showTakLayer &&
                                    AppFeatureFlags.isTakGatewayEnabled
                                ? ref.watch(takActiveEventsProvider).length
                                : 0;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: context.card.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.border.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${nodesWithPosition.length}${nodesWithPosition.length != allNodesWithPosition.length ? '/${allNodesWithPosition.length}' : ''} nodes',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  if (takCount > 0) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '\u2022 $takCount entities',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: context.textTertiary,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // Map controls - use shared overlay for consistency
                  MapControlsOverlay(
                    currentZoom: _currentZoom,
                    minZoom: 4,
                    maxZoom: 18,
                    mapRotation: _mapRotation,
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
                    onCenterOnMe: () =>
                        _centerOnMyNode(nodesWithPosition, myNodeNum),
                    onResetNorth: () => _animatedMove(
                      _mapController.camera.center,
                      _currentZoom,
                      rotation: 0,
                    ),
                    hasMyLocation: nodesWithPosition.any(
                      (n) => n.node.nodeNum == myNodeNum,
                    ),
                    showFitAll: true,
                    showNavigation: true,
                    showCompass: true,
                  ),
                ],
              ),
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

  void _showWaypointMenu(LatLng point) {
    AppBottomSheet.showActions(
      context: context,
      actions: [
        BottomSheetAction(
          icon: Icons.add_location,
          iconColor: AppTheme.warningYellow,
          label: 'Drop Waypoint',
          onTap: () => _addWaypoint(point),
        ),
        BottomSheetAction(
          icon: Icons.share,
          iconColor: context.accentColor,
          label: 'Share Location',
          onTap: () => _shareLocation(point),
        ),
        BottomSheetAction(
          icon: Icons.copy,
          iconColor: context.textSecondary,
          label: 'Copy Coordinates',
          onTap: () => _copyCoordinates(point),
        ),
      ],
      header: Text(
        '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
        style: context.bodySecondaryStyle?.copyWith(
          color: context.textSecondary,
        ),
      ),
    );
  }

  void _showWaypointDetails(_Waypoint waypoint) {
    AppBottomSheet.showActions(
      context: context,
      actions: [
        BottomSheetAction(
          icon: Icons.share,
          iconColor: context.accentColor,
          label: 'Share',
          onTap: () => _shareLocation(waypoint.position, label: waypoint.label),
        ),
        BottomSheetAction(
          icon: Icons.copy,
          iconColor: context.textSecondary,
          label: 'Copy Coordinates',
          onTap: () => _copyCoordinates(waypoint.position),
        ),
        BottomSheetAction(
          icon: Icons.delete,
          label: 'Delete',
          isDestructive: true,
          onTap: () => _removeWaypoint(waypoint.id),
        ),
      ],
      header: Column(
        children: [
          Text(
            waypoint.label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${waypoint.position.latitude.toStringAsFixed(6)}, ${waypoint.position.longitude.toStringAsFixed(6)}',
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
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
                color: context.accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.map_outlined,
                size: 40,
                color: context.accentColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No Nodes with GPS',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              totalNodes > 0
                  ? '$totalNodes nodes discovered but none have\nreported GPS position yet.'
                  : 'Nodes will appear on the map once they\nreport their GPS position.',
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _refreshPositions,
              icon: _isRefreshing
                  ? const LoadingIndicator(size: 16)
                  : Icon(Icons.refresh, size: 18),
              label: Text(
                _isRefreshing ? 'Requesting...' : 'Request Positions',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
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
            SizedBox(height: 12),
            Text(
              'Position broadcasts can take up to 15 minutes.\nTap to request immediately.',
              style: context.bodySmallStyle?.copyWith(
                color: context.textTertiary,
              ),
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
          color: (isMyNode ? context.accentColor : AppTheme.primaryPurple)
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
    final maxDistanceKm = _connectionMaxDistance;

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

          // Always use dotted pattern, with different spacing for stale nodes
          final pattern = hasStaleNode
              ? const StrokePattern.dotted(spacingFactor: 3.0)
              : const StrokePattern.dotted(spacingFactor: 1.5);

          lines.add(
            Polyline(
              points: [
                LatLng(node1.latitude, node1.longitude),
                LatLng(node2.latitude, node2.longitude),
              ],
              color: isMyConnection
                  ? context.accentColor.withValues(
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
                color: context.card.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _formatDistance(distance),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.accentColor,
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
          avatarColor: node.avatarColor,
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

Color _presenceColor(BuildContext context, PresenceConfidence confidence) {
  switch (confidence) {
    case PresenceConfidence.active:
      return AppTheme.primaryPurple;
    case PresenceConfidence.fading:
      return AppTheme.warningYellow;
    case PresenceConfidence.stale:
      return context.textSecondary;
    case PresenceConfidence.unknown:
      return context.textTertiary;
  }
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
  final PresenceConfidence presence;
  final bool isMyNode;
  final bool isSelected;
  final bool isStale;

  const _NodeMarker({
    required this.node,
    required this.presence,
    required this.isMyNode,
    required this.isSelected,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isMyNode
        ? context.accentColor
        : _presenceColor(context, presence);
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
            (node.shortName?.isNotEmpty == true
                ? node.shortName!.substring(0, 1).toUpperCase()
                : node.nodeNum
                      .toRadixString(16)
                      .characters
                      .first
                      .toUpperCase()),
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
  final TextEditingController takSearchController;
  final void Function(String) onTakSearchChanged;
  final Map<int, NodePresence> presenceMap;
  final bool showTakTab;
  final int activeTab;
  final void Function(int) onTabChanged;
  final List<TakEvent> takEvents;
  final void Function(TakEvent) onTakEntitySelected;

  const _NodeListPanel({
    required this.nodesWithPosition,
    required this.myNodeNum,
    required this.selectedNode,
    required this.onNodeSelected,
    required this.onClose,
    required this.calculateDistanceFromMe,
    required this.searchController,
    required this.onSearchChanged,
    required this.takSearchController,
    required this.onTakSearchChanged,
    required this.presenceMap,
    this.showTakTab = false,
    this.activeTab = 0,
    required this.onTabChanged,
    this.takEvents = const [],
    required this.onTakEntitySelected,
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

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          border: Border(
            right: BorderSide(color: context.border.withValues(alpha: 0.5)),
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
            // Header with close button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.list, size: 20, color: context.accentColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      activeTab == 0 ? 'Nodes' : 'Entities',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    activeTab == 0
                        ? '${sortedNodes.length}'
                        : '${takEvents.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.textTertiary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 20),
                    color: context.textTertiary,
                    onPressed: onClose,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Tab bar (only when TAK tab is available)
            if (showTakTab)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.border.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    _PanelTab(
                      label: 'Nodes',
                      count: sortedNodes.length,
                      isActive: activeTab == 0,
                      onTap: () => onTabChanged(0),
                    ),
                    _PanelTab(
                      label: 'Entities',
                      count: takEvents.length,
                      isActive: activeTab == 1,
                      onTap: () => onTabChanged(1),
                    ),
                  ],
                ),
              ),
            if (!showTakTab)
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: context.border.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            // Search field
            if (activeTab == 0)
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: searchController,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  maxLength: 64,
                  decoration: InputDecoration(
                    hintText: 'Search nodes...',
                    hintStyle: TextStyle(
                      color: context.textTertiary,
                      fontSize: 14,
                    ),
                    counterText: '',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: context.textSecondary,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            color: context.textSecondary,
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.background,
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
            // Content: node list or TAK entity list
            if (activeTab == 0)
              Expanded(
                child: sortedNodes.isEmpty
                    ? Center(
                        child: Text(
                          'No nodes found',
                          style: TextStyle(color: context.textTertiary),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: sortedNodes.length,
                        itemBuilder: (context, index) {
                          final nodeWithPos = sortedNodes[index];
                          final isMyNode =
                              nodeWithPos.node.nodeNum == myNodeNum;
                          final isSelected =
                              selectedNode?.nodeNum == nodeWithPos.node.nodeNum;
                          final distance = calculateDistanceFromMe(nodeWithPos);

                          final presence = presenceConfidenceFor(
                            presenceMap,
                            nodeWithPos.node,
                          );
                          return _NodeListItem(
                            nodeWithPos: nodeWithPos,
                            isMyNode: isMyNode,
                            isSelected: isSelected,
                            distance: distance,
                            presence: presence,
                            lastHeardAge: lastHeardAgeFor(
                              presenceMap,
                              nodeWithPos.node,
                            ),
                            onTap: () => onNodeSelected(nodeWithPos),
                          );
                        },
                      ),
              ),
            if (activeTab == 1)
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: takSearchController,
                  style: TextStyle(color: context.textPrimary, fontSize: 14),
                  maxLength: 64,
                  decoration: InputDecoration(
                    hintText: 'Search entities...',
                    hintStyle: TextStyle(
                      color: context.textTertiary,
                      fontSize: 14,
                    ),
                    counterText: '',
                    prefixIcon: Icon(
                      Icons.search,
                      size: 20,
                      color: context.textSecondary,
                    ),
                    suffixIcon: takSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            color: context.textSecondary,
                            onPressed: () {
                              takSearchController.clear();
                              onTakSearchChanged('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: onTakSearchChanged,
                ),
              ),
            if (activeTab == 1)
              Expanded(
                child: () {
                  final query = takSearchController.text.toLowerCase();
                  final filtered = query.isEmpty
                      ? takEvents
                      : takEvents
                            .where(
                              (e) =>
                                  e.displayName.toLowerCase().contains(query) ||
                                  e.typeDescription.toLowerCase().contains(
                                    query,
                                  ) ||
                                  e.uid.toLowerCase().contains(query),
                            )
                            .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.military_tech_outlined,
                            size: 48,
                            color: context.textTertiary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            query.isEmpty
                                ? 'No entities'
                                : 'No matching entities',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final event = filtered[index];
                      return _TakEntityListItem(
                        event: event,
                        onTap: () => onTakEntitySelected(event),
                      );
                    },
                  );
                }(),
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
  final bool isSelected;
  final double? distance;
  final PresenceConfidence presence;
  final Duration? lastHeardAge;
  final VoidCallback onTap;

  const _NodeListItem({
    required this.nodeWithPos,
    required this.isMyNode,
    required this.isSelected,
    required this.distance,
    required this.presence,
    required this.lastHeardAge,
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
    final statusColor = _presenceColor(context, presence);
    final statusText = presenceStatusText(presence, lastHeardAge);
    final baseColor = isMyNode
        ? context.accentColor
        : _presenceColor(context, presence);

    return Material(
      color: isSelected
          ? context.accentColor.withValues(alpha: 0.15)
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
                      (node.shortName?.isNotEmpty == true
                          ? node.shortName!.substring(0, 1).toUpperCase()
                          : node.nodeNum
                                .toRadixString(16)
                                .characters
                                .first
                                .toUpperCase()),
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
                            border: Border.all(color: context.card, width: 1.5),
                          ),
                          child: Center(
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
                                  : (presence.isActive
                                        ? context.textPrimary
                                        : context.textSecondary),
                            ),
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
                              color: context.accentColor.withValues(alpha: 0.2),
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
                    SizedBox(height: 2),
                    Row(
                      children: [
                        // Presence status
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: presence.isActive
                                ? AppTheme.successGreen
                                : context.textTertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4),
                        Tooltip(
                          message: kPresenceInferenceTooltip,
                          child: Text(
                            statusText,
                            style: context.captionStyle?.copyWith(
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (nodeWithPos.isStale) ...[
                          SizedBox(width: 6),
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
                    color: context.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDistance(distance!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              SizedBox(width: 4),
              // Arrow indicator
              Icon(
                Icons.chevron_right,
                size: 18,
                color: isSelected
                    ? context.accentColor
                    : context.textTertiary.withValues(alpha: 0.5),
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
        color: context.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
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
              Icon(Icons.filter_alt, size: 16, color: context.accentColor),
              SizedBox(width: 8),
              Text(
                'Filter Nodes',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${NumberFormat.decimalPattern().format(filteredCount)} / ${NumberFormat.decimalPattern().format(totalCount)}',
                style: context.bodySmallStyle?.copyWith(
                  color: context.textTertiary,
                ),
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
                        ? context.accentColor.withValues(alpha: 0.2)
                        : context.background,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? context.accentColor : context.border,
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
                          ? context.accentColor
                          : context.textSecondary,
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
  final VoidCallback onExitMeasureMode;

  const _MeasurementCard({
    required this.start,
    required this.end,
    required this.onClear,
    required this.onShare,
    required this.onExitMeasureMode,
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
        color: context.card.withValues(alpha: 0.95),
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
            child: Icon(
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
                  style: context.captionStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
                Text(
                  'B: ${end.latitude.toStringAsFixed(4)}, ${end.longitude.toStringAsFixed(4)}',
                  style: context.captionStyle?.copyWith(
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.share, size: 20),
            color: context.textSecondary,
            onPressed: onShare,
            tooltip: 'Share',
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: 20),
            color: context.textTertiary,
            onPressed: onClear,
            tooltip: 'New measurement',
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.errorRed,
            onPressed: onExitMeasureMode,
            tooltip: 'Exit measure mode',
          ),
        ],
      ),
    );
  }
}

/// Tab for the node list panel (Nodes / TAK) — underlined tab style
class _PanelTab extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _PanelTab({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive
                          ? context.accentColor.withValues(alpha: 0.7)
                          : context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            // Active indicator bar (like a TabBar underline)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              decoration: BoxDecoration(
                color: isActive ? context.accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TAK entity list item for the node panel TAK tab
class _TakEntityListItem extends StatelessWidget {
  final TakEvent event;
  final VoidCallback onTap;

  const _TakEntityListItem({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final affiliation = parseAffiliation(event.type);
    final affiliationColor = affiliation.color;
    final isStale = event.isStale;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Affiliation indicator
              Opacity(
                opacity: isStale ? 0.4 : 1.0,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: affiliationColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: affiliationColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    cotTypeIcon(event.type),
                    size: 16,
                    color: affiliationColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Entity info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isStale
                            ? context.textSecondary
                            : context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isStale
                                ? context.textTertiary
                                : Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isStale ? 'Stale' : 'Active',
                          style: TextStyle(
                            fontSize: 11,
                            color: isStale
                                ? context.textTertiary
                                : AppTheme.successGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: affiliationColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            affiliation.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: affiliationColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.my_location,
                size: 16,
                color: context.textTertiary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TAK entity info card shown at the bottom of the mesh map
class _TakEntityInfoCard extends StatelessWidget {
  final TakEvent event;
  final bool isTracked;
  final VoidCallback onClose;
  final VoidCallback onCopyCoordinates;
  final VoidCallback onTapDetail;
  final VoidCallback onToggleTracking;

  const _TakEntityInfoCard({
    required this.event,
    required this.isTracked,
    required this.onClose,
    required this.onCopyCoordinates,
    required this.onTapDetail,
    required this.onToggleTracking,
  });

  @override
  Widget build(BuildContext context) {
    final affiliation = parseAffiliation(event.type);
    final affiliationColor = affiliation.color;
    final isStale = event.isStale;
    final age = _formatAge(event.receivedUtcMs);

    return GestureDetector(
      onTap: onTapDetail,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: affiliationColor.withValues(alpha: 0.3)),
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
            Opacity(
              opacity: isStale ? 0.4 : 1.0,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: affiliationColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: affiliationColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  cotTypeIcon(event.type),
                  color: affiliationColor,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${event.typeDescription}  \u2022  '
                    '${event.lat.toStringAsFixed(4)}, '
                    '${event.lon.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: affiliationColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: affiliationColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          affiliation.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: affiliationColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isStale ? Colors.red : Colors.green)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isStale ? 'STALE' : 'ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            color: isStale ? Colors.red : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        age,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onToggleTracking,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isTracked
                          ? affiliationColor.withValues(alpha: 0.15)
                          : context.card.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: affiliationColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isTracked ? Icons.push_pin : Icons.push_pin_outlined,
                          size: 12,
                          color: affiliationColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isTracked ? 'Tracked' : 'Track',
                          style: TextStyle(
                            fontSize: 11,
                            color: affiliationColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.copy, size: 16),
                      color: context.textSecondary,
                      onPressed: onCopyCoordinates,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Copy coordinates',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 16),
                      color: context.textTertiary,
                      onPressed: onClose,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Dismiss',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  static String _formatAge(int receivedUtcMs) {
    final age = DateTime.now().millisecondsSinceEpoch - receivedUtcMs;
    if (age < 60000) return '${(age / 1000).round()}s ago';
    if (age < 3600000) return '${(age / 60000).round()}m ago';
    return '${(age / 3600000).round()}h ago';
  }
}

// ---------------------------------------------------------------------------
// Isolated TAK marker layer — ConsumerWidget so it only rebuilds when
// takActiveEventsProvider or takTrackedUidsProvider change, not on every
// parent map build.
// ---------------------------------------------------------------------------

class _TakMarkerLayer extends ConsumerWidget {
  final ValueChanged<TakEvent>? onMarkerTap;
  final ValueChanged<TakEvent>? onMarkerLongPress;

  const _TakMarkerLayer({this.onMarkerTap, this.onMarkerLongPress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takEvents = ref.watch(filteredTakEventsProvider);
    final trackedUids = ref.watch(takTrackedUidsProvider);
    return TakMapLayer(
      events: takEvents,
      trackedUids: trackedUids,
      onMarkerTap: onMarkerTap,
      onMarkerLongPress: onMarkerLongPress,
    );
  }
}

// ---------------------------------------------------------------------------
// Isolated TAK heading vector overlay — ConsumerWidget so it only rebuilds
// when filtered events change, not on every parent map build.
// ---------------------------------------------------------------------------

class _TakHeadingVectorOverlay extends ConsumerWidget {
  const _TakHeadingVectorOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final takEvents = ref.watch(filteredTakEventsProvider);
    return TakHeadingVectorLayer(events: takEvents);
  }
}
