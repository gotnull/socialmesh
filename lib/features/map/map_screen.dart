// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../utils/text_sanitizer.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/countdown_providers.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/map_config.dart';
import '../../core/safe_lat_lng.dart';
import 'map_session_providers.dart';
import '../../core/theme.dart';
import '../../core/transport.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/emoji_glyph.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/widgets/status_banner.dart';
import '../../core/widgets/map_controls.dart';
import '../../core/widgets/map_node_drawer.dart';
import '../../core/widgets/node_info_card.dart';
import '../../core/node_color.dart';
import '../../utils/snackbar.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../models/mesh_models.dart';
import '../nodedex/map/nodedex_map_pin.dart';
import '../nodedex/map/nodedex_map_pins_provider.dart';
import '../nodedex/map/widgets/nodedex_sigil_marker.dart';
import '../../models/presence_confidence.dart';
import '../../providers/age_eligibility_provider.dart';
import '../../core/units/distance_format.dart';
import '../../providers/app_providers.dart';
import '../../providers/presence_providers.dart';
import '../../providers/help_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/share_link_service.dart';
import '../../utils/location_privacy.dart';
import '../../utils/presence_utils.dart';
import '../messaging/messaging_screen.dart';
import '../navigation/main_shell.dart';
import '../nodedex/screens/nodedex_detail_screen.dart';
import '../nodes/node_detail_screen.dart';
import '../nodes/node_display_name_resolver.dart';
import '../telemetry/traceroute_log_screen.dart';
import '../telemetry/position_log_screen.dart';
import '../settings/settings_screen.dart';
import '../waypoints/models/mesh_waypoint.dart';
import '../waypoints/providers/waypoint_providers.dart';
import '../waypoints/waypoint_form_screen.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../core/los_analysis.dart';
import '../../services/terrain/elevation_service.dart';
import '../../models/telemetry_log.dart';
import '../../providers/telemetry_providers.dart';
import '../tak/models/tak_event.dart';
import '../tak/providers/tak_filter_provider.dart';
import '../tak/providers/tak_providers.dart';
import '../tak/providers/tak_tracking_provider.dart';
import '../tak/utils/cot_affiliation.dart';
import '../tak/screens/tak_dashboard_screen.dart';
import '../tak/screens/tak_event_detail_screen.dart';
import '../tak/screens/tak_navigate_screen.dart';
import 'terrain_profile_screen.dart';
import '../tak/widgets/tak_map_layer.dart';
import '../tak/widgets/tak_heading_vector_layer.dart';
import '../tak/widgets/tak_trail_layer.dart';

/// Node filter options
enum NodeFilter {
  all,
  active,
  inactive,
  withGps,
  inRange;

  String label(AppLocalizations l10n) {
    switch (this) {
      case NodeFilter.all:
        return l10n.mapFilterAll;
      case NodeFilter.active:
        return l10n.mapFilterActive;
      case NodeFilter.inactive:
        return l10n.mapFilterInactive;
      case NodeFilter.withGps:
        return l10n.mapFilterWithGps;
      case NodeFilter.inRange:
        return l10n.mapFilterInRange;
    }
  }
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

  /// When provided, the map shows the traceroute path as polylines.
  final TraceRouteLog? tracerouteLog;

  /// When true, the marker source switches from the live `nodesProvider`
  /// to `nodedexMapPinsProvider` — every entry in NodeDex with a
  /// positioned encounter is synthesized into a `MeshNode` and pinned at
  /// its last-known coordinates. All other MapScreen features (filter,
  /// search, controls, overlays, info card) keep working unchanged.
  /// The title swaps to "NodeDex Map" so users can tell which dataset
  /// they're looking at.
  final bool nodedexMode;

  const MapScreen({
    super.key,
    this.initialNodeNum,
    this.initialLatitude,
    this.initialLongitude,
    this.initialLocationLabel,
    this.locationOnlyMode = false,
    this.tracerouteLog,
    this.nodedexMode = false,
  });

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin, LifecycleSafeMixin<MapScreen> {
  final MapController _mapController = MapController();
  MeshNode? _selectedNode;
  // Cached display-units preference, refreshed each build so distance
  // strings (including those built inside tap callbacks) honour Imperial.
  MeasurementUnits _units = MeasurementUnits.metric;
  bool _showHeatmap = false;
  bool _clusterMarkers = false;
  bool _isRefreshing = false;

  // Build-profile counters, logged behind the map logging flag so
  // before/after rebuild-efficiency comparisons can be made on-device.
  // markersReused/markersRebuilt are populated by the marker cache;
  // connPairs counts pair evaluations in the connection-lines builder.
  int _buildProfileCount = 0;
  int _markersRebuiltLastBuild = 0;
  int _markersReusedLastBuild = 0;
  bool _markerListReusedLastBuild = false;
  int _connPairsEvaluatedLastBuild = 0;

  // ---------------------------------------------------------------
  // Layer caches. Decorative map layers used to be reconstructed
  // wholesale on every build, which on a busy mesh meant full marker /
  // circle / polyline re-creation per received packet. Each cache pairs
  // the built layer with the exact inputs it was derived from; an
  // element-wise compare (no hashing) decides reuse, so a needed
  // rebuild can never be skipped by a collision.
  // ---------------------------------------------------------------

  // Per-node marker cache. MeshNode instances are replaced by
  // NodesNotifier on any field change, so identity comparison on the
  // node (and NodeDex pin) is a complete change signal for everything
  // the marker child renders.
  final Map<int, _CachedNodeMarker> _markerCache = {};
  List<Marker>? _markerListCache;
  List<int>? _markerOrderCache;

  List<_GeomSig>? _rangeCirclesSigNodes;
  int? _rangeCirclesSigMyNodeNum;
  Color? _rangeCirclesSigAccent;
  Brightness? _rangeCirclesSigBrightness;
  List<CircleMarker>? _rangeCirclesCache;

  List<_GeomSig>? _heatmapSigNodes;
  Color? _heatmapSigAccent;
  Brightness? _heatmapSigBrightness;
  List<CircleMarker>? _heatmapCache;

  List<_GeomSig>? _trailsSigNodes;
  List<PositionLog>? _trailsSigLogs;
  int? _trailsSigTrackNode;
  bool? _trailsSigShowHistory;
  int? _trailsSigEpoch;
  int? _trailsSigMyNodeNum;
  Color? _trailsSigAccent;
  Brightness? _trailsSigBrightness;
  List<Polyline>? _trailsCache;

  // Bumped whenever an in-session trail point is appended, so the
  // trails cache observes `_nodeTrails` mutations without comparing
  // trail contents.
  int _trailsEpoch = 0;

  List<_GeomSig>? _connLinesSigNodes;
  double? _connLinesSigMaxKm;
  int? _connLinesSigMyNodeNum;
  Color? _connLinesSigAccent;
  Brightness? _connLinesSigBrightness;
  List<Polyline>? _connectionLinesCache;

  List<_GeomSig>? _distLabelsSigNodes;
  int? _distLabelsSigMyNodeNum;
  Color? _distLabelsSigAccent;
  Brightness? _distLabelsSigBrightness;
  bool? _distLabelsSigZoomedIn;
  List<Marker>? _distanceLabelsCache;

  static List<_GeomSig> _geometrySignatureOf(List<_NodeWithPosition> nodes) {
    return [
      for (final n in nodes)
        (n.node.nodeNum, n.latitude, n.longitude, n.isStale),
    ];
  }

  static bool _geomSigEquals(List<_GeomSig>? a, List<_GeomSig> b) {
    if (a == null) return false;
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _intListEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // Caches for layers whose toggle is off must not pin their last
  // contents in memory.
  void _releaseDisabledLayerCaches() {
    if (!_showRangeCircles) {
      _rangeCirclesCache = null;
      _rangeCirclesSigNodes = null;
    }
    if (!_showHeatmap) {
      _heatmapCache = null;
      _heatmapSigNodes = null;
    }
    if (!_showConnectionLines) {
      _connectionLinesCache = null;
      _connLinesSigNodes = null;
    }
    if (!_showDistanceLabels) {
      _distanceLabelsCache = null;
      _distLabelsSigNodes = null;
    }
  }

  double _currentZoom = 14.0;
  bool _showNodeList = false;
  bool _showFilters = false;
  bool _measureMode = false;
  bool _showRangeCircles = false;
  bool _showConnectionLines = false;
  bool _showPositionHistory = false;
  bool _showSatelliteLabels = true;
  bool _showDistanceLabels = true;
  bool _showMeshWaypoints = true;
  bool _showWaypoints = true;

  /// When true in traceroute mode, only nodes part of the route are shown.
  bool _tracerouteRouteOnly = false;

  /// When set, shows only this node's position history trail on the map.
  int? _trackNodeNum;
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

  // Measurement node references (populated when user taps a node in measure mode)
  MeshNode? _measureNodeA;
  MeshNode? _measureNodeB;

  // Terrain-aware measurement line segments
  List<Polyline>? _measureTerrainPolylines;
  TerrainLosResult? _measureTerrainResult;
  bool _terrainFetchInProgress = false;
  ElevationService? _elevationService;

  // Animation controller for smooth camera movements
  AnimationController? _animationController;

  // Compass rotation. Lives in a ValueNotifier so pan/rotate gestures don't
  // rebuild the screen on every frame — only the compass needle (wrapped in
  // ValueListenableBuilder around `MapControlsOverlay`) listens.
  final ValueNotifier<double> _mapRotationNotifier = ValueNotifier<double>(0.0);
  double get _mapRotation => _mapRotationNotifier.value;
  set _mapRotation(double value) => _mapRotationNotifier.value = value;

  // Compass interaction mode. North-locked is the default: rotation gestures
  // are disabled, so a pinch-zoom can never rotate ("wiggle") the map off
  // north. The compass button cycles north-locked -> free-rotate ->
  // follow-heading -> north-locked.
  MapCompassMode _compassMode = MapCompassMode.northLocked;
  StreamSubscription<CompassEvent>? _compassSubscription;

  bool get _headingUpMode => _compassMode == MapCompassMode.followHeading;

  // Interaction flags driven by the compass mode. Disabling InteractiveFlag
  // .rotate in the resting state is what kills the pinch-zoom wiggle.
  int get _interactionFlags => _compassMode == MapCompassMode.northLocked
      ? (InteractiveFlag.all & ~InteractiveFlag.rotate)
      : InteractiveFlag.all;

  // Track last known positions for nodes (to handle GPS loss gracefully)
  final Map<int, _CachedPosition> _positionCache = {};

  // Trail history for moving nodes
  final Map<int, List<_TrailPoint>> _nodeTrails = {};

  // Search controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _takSearchController = TextEditingController();

  // Track if initial node centering has been done
  bool _initialCenteringDone = false;

  // One-shot: on a plain Map-tab open (no deep-link / traceroute /
  // location target) the camera is placed imperatively after first
  // render. MapOptions.initialCenter only applies on the first build,
  // and node positions arrive async — so the computed `center` would
  // otherwise be stranded at the LatLng(0,0) fallback (blank ocean).
  bool _didInitialAutoFit = false;

  // One-shot flag: consume TAK provider values that were set before
  // this widget built (ref.listen only fires on *changes*, not
  // the current value at subscription time).
  bool _takInitialCheckDone = false;

  // Camera-boundary NaN recovery. flutter_map's pinch pipeline computes a
  // new zoom via math.log(scale) and commits it through the internal
  // moveRaw() — which bypasses every safeMove/safeLatLng guard. When the
  // gesture's scale term reaches <= 0 the log yields -Infinity/NaN, clampZoom
  // passes it through, and the camera lands on a non-finite center/zoom. The
  // next tile-layer build (and every later pinch) then projects that center
  // and throws fatally in Crs.checkLatLng. We cannot intercept moveRaw, but
  // onPositionChanged fires on every camera mutation including the internal
  // one, so we snap the camera back to the last finite pose before the frame
  // that would crash gets built.
  LatLng? _lastFiniteCenter;
  double _lastFiniteZoom = 2.0;
  bool _cameraRecoveryScheduled = false;

  // Layout constants for consistent spacing
  static const double _mapPadding = 16.0;
  static const double _controlSpacing = 8.0;
  static const double _controlSize = 44.0;

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _animationController?.dispose();
    _mapController.dispose();
    _searchController.dispose();
    _takSearchController.dispose();
    _mapRotationNotifier.dispose();
    _elevationService = null;
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
      safeSetState(() {
        _mapStyle = MapTileStyle.values[index];
        _showRangeCircles = settings.mapShowRangeCircles;
        _showConnectionLines = settings.mapShowConnectionLines;
        _showPositionHistory = settings.mapShowPositionHistory;
        _connectionMaxDistance = settings.mapConnectionMaxDistance;
        _showSatelliteLabels = settings.satelliteLabelsEnabled;
        _clusterMarkers = settings.mapClusterMarkers;
        _showDistanceLabels = settings.mapShowDistanceLabels;
        _showMeshWaypoints = settings.mapShowMeshWaypoints;
        _showWaypoints = settings.mapShowWaypoints;
      });
    }
  }

  Future<void> _saveMapStyle(MapTileStyle style) async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    if (!mounted) return;
    await settings.setMapTileStyleIndex(style.index);
  }

  Future<void> _saveMapLayerSettings() async {
    final settingsFuture = ref.read(settingsServiceProvider.future);
    final settings = await settingsFuture;
    if (!mounted) return;
    await settings.setMapShowRangeCircles(_showRangeCircles);
    await settings.setMapShowConnectionLines(_showConnectionLines);
    await settings.setMapShowPositionHistory(_showPositionHistory);
    await settings.setMapConnectionMaxDistance(_connectionMaxDistance);
    await settings.setSatelliteLabelsEnabled(_showSatelliteLabels);
    await settings.setMapClusterMarkers(_clusterMarkers);
    await settings.setMapShowDistanceLabels(_showDistanceLabels);
    await settings.setMapShowMeshWaypoints(_showMeshWaypoints);
    await settings.setMapShowWaypoints(_showWaypoints);
  }

  /// Animate camera to a specific location with smooth easing
  void _animatedMove(LatLng destLocation, double destZoom, {double? rotation}) {
    if (!isFiniteLatLng(destLocation) || !destZoom.isFinite) return;
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
      _mapController.safeMoveAndRotate(
        safeLatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
        rotationTween.evaluate(animation),
      );
      // Keep compass state in sync during programmatic moves. Rotation goes
      // through the notifier (compass-only rebuild). Zoom is mutated as a
      // plain field — the next data/selection-driven setState will pick it up.
      final currentRotation = rotationTween.evaluate(animation);
      if (currentRotation != _mapRotation) {
        _mapRotation = currentRotation;
      }
      _currentZoom = zoomTween.evaluate(animation);
    });

    _animationController!.forward();
  }

  void _enableHeadingUp() {
    _compassSubscription?.cancel();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null || !mounted) return;
      // FlutterCompass heading is degrees CW from north (device facing).
      // flutter_map rotates content by +rotation (CW), so to put the
      // facing-direction at the top of the map we apply the inverse.
      final newRotation = -heading;
      // Skip tiny changes to reduce redraws (accounts for 360°/0° wrap)
      final diff = ((newRotation - _mapRotation + 540) % 360) - 180;
      if (diff.abs() < 1.0) return;
      _mapController.safeMoveAndRotate(
        _mapController.camera.center,
        _currentZoom,
        newRotation,
      );
      _mapRotation = newRotation;
    });
    if (_compassSubscription != null) {
      setState(() => _compassMode = MapCompassMode.followHeading);
    }
  }

  // Cancel any heading subscription, snap the camera back to north and return
  // the compass to its resting (rotation-disabled) state.
  void _resetToNorthLocked() {
    _compassSubscription?.cancel();
    _compassSubscription = null;
    setState(() => _compassMode = MapCompassMode.northLocked);
    _animatedMove(_mapController.camera.center, _currentZoom, rotation: 0);
  }

  // Compass button: cycles north-locked -> free-rotate -> follow-heading ->
  // north-locked. Devices without a magnetometer skip the follow-heading step.
  void _onCompassTap() {
    switch (_compassMode) {
      case MapCompassMode.northLocked:
        setState(() => _compassMode = MapCompassMode.freeRotate);
      case MapCompassMode.freeRotate:
        if (FlutterCompass.events == null) {
          showWarningSnackBar(context, context.l10n.mapCompassUnavailable);
          _resetToNorthLocked();
          return;
        }
        _enableHeadingUp();
      case MapCompassMode.followHeading:
        _resetToNorthLocked();
    }
  }

  /// Synthesize a `Map<int, MeshNode>` from NodeDex map pins so the
  /// rest of MapScreen — which is built around live MeshNodes — works
  /// unchanged. Only the fields the marker / filter / search / info-
  /// card paths read are populated; everything else (snr, rssi, env
  /// metrics, etc.) is null because NodeDex doesn't carry it.
  Map<int, MeshNode> _nodedexPinsAsNodes(List<NodeDexMapPin> pins) {
    final result = <int, MeshNode>{};
    for (final pin in pins) {
      result[pin.nodeNum] = MeshNode(
        nodeNum: pin.nodeNum,
        longName: pin.displayName,
        shortName: pin.displayName,
        latitude: pin.position.latitude,
        longitude: pin.position.longitude,
        firstHeard: pin.positionedAt,
        lastHeard: pin.lastEncounterAt,
      );
    }
    return result;
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
    // Drop NaN/Infinity at the boundary: a single non-finite trail point
    // poisons the entire PolylineLayer (Crs.checkLatLng throws fatally on
    // projectAtZoom), so any caller leaking non-finite coords here would
    // crash every subsequent map build.
    if (!lat.isFinite || !lng.isFinite) return;
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
      // Make the in-place mutation observable to the trails layer cache.
      _trailsEpoch++;
    }
  }

  /// Filter nodes based on current filter.
  ///
  /// Single-pass evaluation — the previous chain of up to four
  /// `.where(...).toList()` calls materialised an intermediate list per
  /// filter step. Combined predicate, one walk, one allocation.
  List<_NodeWithPosition> _filterNodes(
    List<_NodeWithPosition> nodes,
    int? myNodeNum,
    Map<int, NodePresence> presenceMap,
  ) {
    final hasQuery = _searchQuery.isNotEmpty;
    final lowerQuery = hasQuery ? _searchQuery.toLowerCase() : '';

    // Pre-resolve the in-range pivot once instead of per-element.
    _NodeWithPosition? rangePivot;
    if (_nodeFilter == NodeFilter.inRange && myNodeNum != null) {
      rangePivot = nodes.where((n) => n.node.nodeNum == myNodeNum).firstOrNull;
    }

    final result = <_NodeWithPosition>[];
    for (final n in nodes) {
      if (hasQuery) {
        final name = n.node.displayName.toLowerCase();
        final id = n.node.userId?.toLowerCase() ?? '';
        if (!name.contains(lowerQuery) && !id.contains(lowerQuery)) continue;
      }
      switch (_nodeFilter) {
        case NodeFilter.all:
          break;
        case NodeFilter.active:
          if (!presenceConfidenceFor(presenceMap, n.node).isActive) continue;
        case NodeFilter.inactive:
          if (!presenceConfidenceFor(presenceMap, n.node).isInactive) continue;
        case NodeFilter.withGps:
          if (n.isStale) continue;
        case NodeFilter.inRange:
          if (rangePivot != null && n.node.nodeNum != myNodeNum) {
            final dist = _calculateDistance(
              rangePivot.latitude,
              rangePivot.longitude,
              n.latitude,
              n.longitude,
            );
            if (dist > 15.0) continue;
          }
      }
      result.add(n);
    }
    return result;
  }

  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    // Vincenty formula throws on identical / near-identical points
    if (lat1 == lat2 && lng1 == lng2) return 0.0;
    try {
      return const Distance().as(
        LengthUnit.Kilometer,
        LatLng(lat1, lng1),
        LatLng(lat2, lng2),
      );
    } catch (_) {
      // Vincenty can also fail on near-antipodal points
      return 0.0;
    }
  }

  String _formatDistance(double km) =>
      formatDistanceKm(km, _units, context.l10n);

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
    final notifier = ref.read(mapLocalWaypointsProvider.notifier);
    final count = ref.read(mapLocalWaypointsProvider).length;
    notifier.add(
      MapLocalWaypoint(
        id: DateTime.now().millisecondsSinceEpoch,
        position: point,
        label: label ?? context.l10n.mapWaypointDefaultLabel(count + 1),
      ),
    );
    HapticFeedback.mediumImpact();
  }

  void _removeWaypoint(int id) {
    ref.read(mapLocalWaypointsProvider.notifier).remove(id);
  }

  void _shareLocation(LatLng point, {String? label}) {
    // Coarsen coordinates when the user is a confirmed minor.
    final policy = ref.read(ageSafetyPolicyProvider);
    final coarsened = LocationPrivacy.coarsenCoordsForPolicy(
      point.latitude,
      point.longitude,
      policy,
    );
    final sharePoint = LatLng(coarsened.latitude, coarsened.longitude);

    // Get share position for iPad support
    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : const Rect.fromLTWH(0, 0, 100, 100);

    ref
        .read(shareLinkServiceProvider)
        .shareLocation(
          latitude: sharePoint.latitude,
          longitude: sharePoint.longitude,
          label: label,
          sharePositionOrigin: sharePositionOrigin,
        );
  }

  void _copyCoordinates(LatLng point) {
    // Coarsen coordinates when the user is a confirmed minor.
    final policy = ref.read(ageSafetyPolicyProvider);
    final coarsened = LocationPrivacy.coarsenCoordsForPolicy(
      point.latitude,
      point.longitude,
      policy,
    );
    final lat = coarsened.latitude.toStringAsFixed(6);
    final lng = coarsened.longitude.toStringAsFixed(6);
    Clipboard.setData(
      ClipboardData(text: '$lat, $lng'),
    ); // lint-allow: hardcoded-string
    showSuccessSnackBar(context, context.l10n.mapCoordinatesCopied);
  }

  @override
  Widget build(BuildContext context) {
    _units = ref.watch(measurementUnitsProvider);
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

    // In NodeDex mode, the marker source is the NodeDex pin list —
    // every entry with a positioned encounter, synthesized into a
    // MeshNode so the rest of MapScreen (filtering, search, info card,
    // overlays) keeps working unchanged.
    final List<NodeDexMapPin> nodedexPins = widget.nodedexMode
        ? ref.watch(nodedexMapPinsProvider)
        : const <NodeDexMapPin>[];
    // O(1) lookup so the marker builder doesn't scan the pin list per
    // marker. Empty in live mesh mode.
    final Map<int, NodeDexMapPin> nodedexPinsByNum = widget.nodedexMode
        ? {for (final pin in nodedexPins) pin.nodeNum: pin}
        : const <int, NodeDexMapPin>{};
    final nodes = widget.nodedexMode
        ? _nodedexPinsAsNodes(nodedexPins)
        : ref.watch(nodesProvider);
    final presenceMap = ref.watch(presenceMapProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final meshWaypoints = ref.watch(meshWaypointsProvider);
    final localWaypoints = ref.watch(mapLocalWaypointsProvider);

    // Load position history — per-node when tracking, all when global toggle
    final List<PositionLog> positionLogs;
    if (_trackNodeNum != null) {
      positionLogs =
          ref.watch(nodePositionLogsProvider(_trackNodeNum!)).asData?.value ??
          <PositionLog>[];
    } else if (_showPositionHistory) {
      positionLogs =
          ref.watch(positionLogsProvider).asData?.value ?? <PositionLog>[];
    } else {
      positionLogs = <PositionLog>[];
    }

    // Get nodes with positions (current or cached)
    final allNodesWithPosition = _getNodesWithPositions(nodes, presenceMap);
    var nodesWithPosition = _filterNodes(
      allNodesWithPosition,
      myNodeNum,
      presenceMap,
    );

    _buildProfileCount++;
    if (AppLogging.mapLoggingEnabled) {
      AppLogging.map(
        'event=map.build.profile build=$_buildProfileCount '
        'nodes=${nodes.length} positioned=${nodesWithPosition.length} '
        'markersReused=$_markersReusedLastBuild '
        'markersRebuilt=$_markersRebuiltLastBuild '
        'listReused=$_markerListReusedLastBuild '
        'connPairs=$_connPairsEvaluatedLastBuild',
      );
    }
    _releaseDisabledLayerCaches();

    // In traceroute mode, optionally show only route-related nodes
    if (_tracerouteRouteOnly && widget.tracerouteLog != null) {
      final log = widget.tracerouteLog!;
      final routeNodeNums = {
        log.nodeNum,
        log.targetNode,
        ...log.hops.map((h) => h.nodeNum),
      };
      nodesWithPosition = nodesWithPosition
          .where((n) => routeNodeNums.contains(n.node.nodeNum))
          .toList();
    }

    // Shared geometry signature for the layer caches: computed once per
    // build from the final filtered node list, after all filters above.
    final geomSig = _geometrySignatureOf(nodesWithPosition);
    final accentColor = context.accentColor;
    final themeBrightness = Theme.of(context).brightness;

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
    bool centerResolved = false;

    // Traceroute mode: fit camera to hop bounds when the traceroute
    // has at least two valid GPS points. When every hop reports 0,0
    // (or no GPS data exists for the route), `_tracerouteBounds`
    // returns null — in that case we MUST fall through to the
    // standard user-position / nodes-with-position fallback, otherwise
    // the camera lands at LatLng(0,0) (the Gulf of Guinea, "Africa
    // fallback bug").
    if (widget.tracerouteLog != null) {
      final tracerouteBounds = _tracerouteBounds(
        widget.tracerouteLog!,
        nodes,
        myNodeNum,
      );
      if (tracerouteBounds != null) {
        final midLat =
            (tracerouteBounds.southWest.latitude +
                tracerouteBounds.northEast.latitude) /
            2;
        final midLng =
            (tracerouteBounds.southWest.longitude +
                tracerouteBounds.northEast.longitude) /
            2;
        center = safeLatLng(midLat, midLng) ?? center;
        // Rough zoom from bounds span — the map will refine in onMapReady
        final latSpan =
            tracerouteBounds.northEast.latitude -
            tracerouteBounds.southWest.latitude;
        final lngSpan =
            tracerouteBounds.northEast.longitude -
            tracerouteBounds.southWest.longitude;
        final span = math.max(latSpan, lngSpan);
        if (span < 0.01) {
          zoom = 15.0;
        } else if (span < 0.1) {
          zoom = 12.0;
        } else if (span < 1.0) {
          zoom = 9.0;
        } else {
          zoom = 6.0;
        }
        centerResolved = true;
      } else {
        AppLogging.map(
          '[MapScreen] traceroute bounds null - all hops at 0,0; '
          'falling back to user / nodes-with-position chain',
        );
      }
    }

    // True when the screen was opened from a traceroute card but the
    // route has no usable GPS data (every hop reports 0,0 or has no
    // position). Drives the persistent banner below — without it, the
    // user sees an apparently-blank map with no explanation.
    final tracerouteHasNoGps = widget.tracerouteLog != null && !centerResolved;

    if (!centerResolved &&
        widget.locationOnlyMode &&
        widget.initialLatitude != null &&
        widget.initialLongitude != null) {
      center =
          safeLatLng(widget.initialLatitude!, widget.initialLongitude!) ??
          center;
      zoom = 15.0;
    } else if (!centerResolved && nodesWithPosition.isNotEmpty) {
      final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
      final myNodeWithPos = nodesWithPosition
          .where((n) => n.node.nodeNum == myNodeNum)
          .firstOrNull;

      if (myNodeWithPos != null) {
        center =
            safeLatLng(myNodeWithPos.latitude, myNodeWithPos.longitude) ??
            center;
        zoom = 14.0;
      } else if (myNode?.hasPosition == true) {
        center = safeLatLng(myNode!.latitude!, myNode.longitude!) ?? center;
        zoom = 14.0;
      } else {
        final finiteNodes = nodesWithPosition
            .where((n) => n.latitude.isFinite && n.longitude.isFinite)
            .toList(growable: false);
        if (finiteNodes.isNotEmpty) {
          double avgLat = 0, avgLng = 0;
          for (final n in finiteNodes) {
            avgLat += n.latitude;
            avgLng += n.longitude;
          }
          avgLat /= finiteNodes.length;
          avgLng /= finiteNodes.length;
          center = safeLatLng(avgLat, avgLng) ?? center;
          zoom = 12.0;
        }
      }
    }

    // Restore the camera the user left on the Map tab last time. MapScreen is
    // rebuilt from scratch on every tab switch, so without this the camera
    // resets to the computed fallback above (and the user loses their zoom and
    // place). Applied only on a plain Map-tab open — deep-link / traceroute /
    // location targets own the camera. Marking _didInitialAutoFit skips the
    // auto-fit below so the restored pose wins.
    if (!_didInitialAutoFit &&
        !_initialCenteringDone &&
        widget.tracerouteLog == null &&
        !widget.locationOnlyMode &&
        widget.initialNodeNum == null &&
        widget.initialLatitude == null) {
      final savedCamera = ref.read(mapCameraStateProvider);
      if (savedCamera != null &&
          isFiniteLatLng(savedCamera.center) &&
          savedCamera.zoom.isFinite) {
        center = savedCamera.center;
        zoom = savedCamera.zoom;
        _currentZoom = savedCamera.zoom;
        _didInitialAutoFit = true;
      }
    }

    // One-shot default camera placement for a plain Map-tab open. The
    // initialCenter above only applies on the first FlutterMap build and
    // node positions resolve async, so without this the camera stays at
    // the LatLng(0,0) fallback (blank ocean) even after nodes arrive. We
    // place it imperatively after first render: centre on my node when it
    // has a GPS fix, otherwise frame every node (the fit-all overview).
    // Deep-link / traceroute / location targets own the camera via
    // _initialCenteringDone above and are excluded here.
    if (!_didInitialAutoFit &&
        !_initialCenteringDone &&
        widget.tracerouteLog == null &&
        !widget.locationOnlyMode &&
        widget.initialNodeNum == null &&
        widget.initialLatitude == null &&
        allNodesWithPosition.isNotEmpty) {
      _didInitialAutoFit = true;
      final fitNodes = nodesWithPosition;
      final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
      final myNodeWithPos = nodesWithPosition
          .where((n) => n.node.nodeNum == myNodeNum)
          .firstOrNull;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (myNodeWithPos != null) {
          final target = safeLatLng(
            myNodeWithPos.latitude,
            myNodeWithPos.longitude,
          );
          if (target != null) {
            _animatedMove(target, 14.0);
            return;
          }
        } else if (myNode?.hasPosition == true) {
          final target = safeLatLng(myNode!.latitude!, myNode.longitude!);
          if (target != null) {
            _animatedMove(target, 14.0);
            return;
          }
        }
        _fitNodesCamera(fitNodes);
      });
    }

    // Check if this screen was pushed (can pop) or is a root drawer screen.
    // Use route.isFirst to avoid drawer local-history entries flipping this.
    final route = ModalRoute.of(context);
    final canPop = route != null ? !route.isFirst : Navigator.canPop(context);

    return HelpTourController(
      topicId: 'map_overview',
      stepKeys: const {},
      child: GlassScaffold.body(
        resizeToAvoidBottomInset: false,
        physics: const NeverScrollableScrollPhysics(),
        leading: canPop ? const BackButton() : const HamburgerMenuButton(),
        centerTitle: true,
        titleWidget: Text(
          widget.tracerouteLog != null
              ? context.l10n.tracerouteMapTitle
              : widget.locationOnlyMode
              ? (widget.initialLocationLabel ?? context.l10n.mapLocationTitle)
              : widget.nodedexMode
              ? context.l10n.nodedexMapTitle
              : context.l10n.mapScreenTitle,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: [
          // Per CLAUDE.md "App bar: one primary IconButton, rest in
          // AppBarOverflowMenu". DeviceStatusButton stays as the
          // primary because it is a live, app-wide connection-state
          // indicator (battery-icon-like). Filter, Map style, and
          // everything else lives in the kebab.
          if (!widget.locationOnlyMode) const DeviceStatusButton(),
          // More options menu
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'filter':
                  setState(() => _showFilters = !_showFilters);
                  break;
                case 'style_dark':
                  setState(() => _mapStyle = MapTileStyle.dark);
                  unawaited(_saveMapStyle(MapTileStyle.dark));
                  break;
                case 'style_satellite':
                  setState(() => _mapStyle = MapTileStyle.satellite);
                  unawaited(_saveMapStyle(MapTileStyle.satellite));
                  break;
                case 'style_terrain':
                  setState(() => _mapStyle = MapTileStyle.terrain);
                  unawaited(_saveMapStyle(MapTileStyle.terrain));
                  break;
                case 'style_light':
                  setState(() => _mapStyle = MapTileStyle.light);
                  unawaited(_saveMapStyle(MapTileStyle.light));
                  break;
                case 'satellite_labels':
                  setState(() => _showSatelliteLabels = !_showSatelliteLabels);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'traceroute_route_only':
                  setState(() => _tracerouteRouteOnly = !_tracerouteRouteOnly);
                  break;
                case 'refresh':
                  _refreshPositions();
                  break;
                case 'heatmap':
                  setState(() => _showHeatmap = !_showHeatmap);
                  break;
                case 'cluster_markers':
                  setState(() => _clusterMarkers = !_clusterMarkers);
                  unawaited(_saveMapLayerSettings());
                  AppLogging.map('[MapScreen] clusterMarkers=$_clusterMarkers');
                  break;
                case 'connections':
                  setState(() => _showConnectionLines = !_showConnectionLines);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'distance_1':
                  setState(() => _connectionMaxDistance = 1.0);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'distance_5':
                  setState(() => _connectionMaxDistance = 5.0);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'distance_10':
                  setState(() => _connectionMaxDistance = 10.0);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'distance_25':
                  setState(() => _connectionMaxDistance = 25.0);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'distance_all':
                  setState(() => _connectionMaxDistance = 100.0);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'range':
                  setState(() => _showRangeCircles = !_showRangeCircles);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'distance_labels':
                  setState(() => _showDistanceLabels = !_showDistanceLabels);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'history':
                  setState(() => _showPositionHistory = !_showPositionHistory);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'mesh_waypoints':
                  setState(() => _showMeshWaypoints = !_showMeshWaypoints);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'waypoints':
                  setState(() => _showWaypoints = !_showWaypoints);
                  unawaited(_saveMapLayerSettings());
                  break;
                case 'measure':
                  setState(() {
                    _measureMode = !_measureMode;
                    _measureStart = null;
                    _measureEnd = null;
                    _measureNodeA = null;
                    _measureNodeB = null;
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
              // Filter — hide in location-only mode (no nodes shown).
              if (!widget.locationOnlyMode)
                PopupMenuItem(
                  value: 'filter',
                  child: Row(
                    children: [
                      Icon(
                        _nodeFilter != NodeFilter.all || _showFilters
                            ? Icons.filter_alt
                            : Icons.filter_alt_outlined,
                        size: 18,
                        color: _nodeFilter != NodeFilter.all || _showFilters
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(context.l10n.mapFilterNodesTooltip),
                    ],
                  ),
                ),
              // Map style — radio-like, check on the active style.
              ...MapTileStyle.values.map(
                (style) => PopupMenuItem(
                  value: 'style_${style.name}',
                  child: Row(
                    children: [
                      Icon(
                        _mapStyle == style ? Icons.check : Icons.map_outlined,
                        size: 18,
                        color: _mapStyle == style
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(style.label),
                    ],
                  ),
                ),
              ),
              // Satellite labels toggle — only meaningful in satellite mode,
              // so the entry stays hidden for the other styles.
              if (_mapStyle == MapTileStyle.satellite)
                PopupMenuItem(
                  value: 'satellite_labels',
                  child: Row(
                    children: [
                      Icon(
                        _showSatelliteLabels
                            ? Icons.label
                            : Icons.label_outline,
                        size: 18,
                        color: _showSatelliteLabels
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _showSatelliteLabels
                            ? context.l10n.mapHideSatelliteLabels
                            : context.l10n.mapShowSatelliteLabels,
                      ),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              // Traceroute: show route only toggle
              if (widget.tracerouteLog != null)
                PopupMenuItem(
                  value: 'traceroute_route_only',
                  child: Row(
                    children: [
                      Icon(
                        _tracerouteRouteOnly
                            ? Icons.route
                            : Icons.route_outlined,
                        size: 18,
                        color: _tracerouteRouteOnly
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _tracerouteRouteOnly
                            ? context.l10n.tracerouteShowAllNodes
                            : context.l10n.tracerouteShowRouteOnly,
                      ),
                    ],
                  ),
                ),
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _isRefreshing
                            ? context.l10n.mapRefreshing
                            : context.l10n.mapRefreshPositions,
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _showHeatmap
                            ? context.l10n.mapHideHeatmap
                            : context.l10n.mapShowHeatmap,
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'cluster_markers',
                  child: Row(
                    children: [
                      Icon(
                        _clusterMarkers
                            ? Icons.bubble_chart
                            : Icons.bubble_chart_outlined,
                        size: 18,
                        color: _clusterMarkers
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _clusterMarkers
                            ? context.l10n.mapHideClusterMarkers
                            : context.l10n.mapShowClusterMarkers,
                      ),
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _showConnectionLines
                            ? context.l10n.mapHideConnectionLines
                            : context.l10n.mapShowConnectionLines,
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
                      context.l10n.mapMaxDistance,
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
                        SizedBox(width: AppTheme.spacing8),
                        Text(context.l10n.mapDistance1Km),
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
                        SizedBox(width: AppTheme.spacing8),
                        Text(context.l10n.mapDistance5Km),
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
                        SizedBox(width: AppTheme.spacing8),
                        Text(context.l10n.mapDistance10Km),
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
                        SizedBox(width: AppTheme.spacing8),
                        Text(context.l10n.mapDistance25Km),
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
                        SizedBox(width: AppTheme.spacing8),
                        Text(context.l10n.mapDistanceAll),
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _showRangeCircles
                            ? context.l10n.mapHideRangeCircles
                            : context.l10n.mapShowRangeCircles,
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'distance_labels',
                  child: Row(
                    children: [
                      Icon(
                        _showDistanceLabels
                            ? Icons.straighten
                            : Icons.straighten_outlined,
                        size: 18,
                        color: _showDistanceLabels
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _showDistanceLabels
                            ? context.l10n.mapHideDistanceLabels
                            : context.l10n.mapShowDistanceLabels,
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(
                        Icons.route,
                        size: 18,
                        color: _showPositionHistory
                            ? context.accentColor
                            : context.textSecondary,
                      ),
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _showPositionHistory
                            ? context.l10n.mapHidePositionHistory
                            : context.l10n.mapShowPositionHistory,
                      ),
                    ],
                  ),
                ),
              ], // End of node-related options
              PopupMenuItem(
                value: 'mesh_waypoints',
                child: Row(
                  children: [
                    Icon(
                      _showMeshWaypoints
                          ? Icons.share_location
                          : Icons.share_location_outlined,
                      size: 18,
                      color: _showMeshWaypoints
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                    SizedBox(width: AppTheme.spacing8),
                    Text(
                      _showMeshWaypoints
                          ? context.l10n.mapHideMeshWaypoints
                          : context.l10n.mapShowMeshWaypoints,
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'waypoints',
                child: Row(
                  children: [
                    Icon(
                      _showWaypoints ? Icons.place : Icons.place_outlined,
                      size: 18,
                      color: _showWaypoints
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                    SizedBox(width: AppTheme.spacing8),
                    Text(
                      _showWaypoints
                          ? context.l10n.mapHideWaypoints
                          : context.l10n.mapShowWaypoints,
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
                          ? context.accentColor
                          : context.textSecondary,
                    ),
                    SizedBox(width: AppTheme.spacing8),
                    Text(
                      _measureMode
                          ? context.l10n.mapExitMeasureMode
                          : context.l10n.mapMeasureDistance,
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'globe',
                child: Row(
                  children: [
                    Icon(Icons.public, size: 18, color: context.textSecondary),
                    SizedBox(width: AppTheme.spacing8),
                    Text(context.l10n.mapGlobeView),
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(
                        _showTakLayer
                            ? context.l10n.mapHideTakEntities
                            : context.l10n.mapShowTakEntities,
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
                      SizedBox(width: AppTheme.spacing8),
                      Text(context.l10n.mapSaDashboard),
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
                    SizedBox(width: AppTheme.spacing8),
                    Text(context.l10n.mapHelp),
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
                    SizedBox(width: AppTheme.spacing8),
                    Text(context.l10n.mapSettings),
                  ],
                ),
              ),
            ],
          ),
        ],
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
                      interactionOptions: InteractionOptions(
                        flags: _interactionFlags,
                        pinchZoomThreshold: 0.5,
                        scrollWheelVelocity: 0.005,
                      ),
                      onPositionChanged: (position, hasGesture) {
                        // Camera-boundary NaN guard (see _lastFiniteCenter).
                        // Record every finite pose; if a non-finite one lands
                        // (flutter_map pinch math overflow committed via the
                        // internal moveRaw), snap back to the last good pose
                        // on a microtask — which drains before the next frame
                        // builds, so the crashing tile projection never runs.
                        if (isFiniteCameraPose(
                          position.center,
                          position.zoom,
                        )) {
                          _lastFiniteCenter = position.center;
                          _lastFiniteZoom = position.zoom;
                          // Remember the pose for the app session so returning
                          // to the Map tab restores it instead of snapping back
                          // to the computed fallback. Cheap: nothing watches
                          // this provider, so the set notifies no listeners.
                          ref
                              .read(mapCameraStateProvider.notifier)
                              .save(position.center, position.zoom);
                        } else if (!_cameraRecoveryScheduled) {
                          _cameraRecoveryScheduled = true;
                          final recoverCenter = _lastFiniteCenter;
                          final recoverZoom = _lastFiniteZoom;
                          scheduleMicrotask(() {
                            _cameraRecoveryScheduled = false;
                            if (!mounted || recoverCenter == null) return;
                            _mapController.safeMove(recoverCenter, recoverZoom);
                          });
                          return;
                        }
                        if (hasGesture) {
                          // A manual two-finger rotate while following the
                          // device heading hands control back to the user:
                          // drop to free-rotate and stop driving rotation from
                          // the compass.
                          if (_compassMode == MapCompassMode.followHeading) {
                            final rotDiff =
                                ((position.rotation - _mapRotation + 540) %
                                    360) -
                                180;
                            if (rotDiff.abs() > 1.0) {
                              _compassSubscription?.cancel();
                              _compassSubscription = null;
                              setState(
                                () => _compassMode = MapCompassMode.freeRotate,
                              );
                            }
                          }
                          // No setState: rotation flows through the notifier
                          // (compass-only rebuild) and zoom is read on the
                          // next data/selection-triggered build. Avoiding a
                          // per-frame screen rebuild during pan/rotate.
                          _mapRotation = position.rotation;
                          _currentZoom = position.zoom;
                        }
                      },
                      onTap: (tapPos, point) {
                        if (_measureMode) {
                          _handleMeasureTap(point);
                        } else {
                          if (_selectedTakEntity != null) {
                            AppLogging.tak('Map entity deselected');
                          }
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
                      // Map tiles. When Mapbox is active the URL switches to
                      // Mapbox's raster Static Tiles API and the Esri labels
                      // overlay below is skipped — Mapbox bakes labels into
                      // satellite-streets-v12 directly.
                      TileLayer(
                        tileUpdateTransformer:
                            finiteCameraTileUpdateTransformer,
                        // Key off the resolved tile source so switching style
                        // (Dark / Satellite / Terrain / Light) rebuilds the
                        // layer and loads the new tiles immediately, instead of
                        // showing blue until the user pans or pinches.
                        key: ValueKey(
                          MapConfig.mapboxUrlForStyle(
                                _mapStyle,
                                satelliteLabelsOn: _showSatelliteLabels,
                              ) ??
                              _mapStyle.url,
                        ),
                        urlTemplate:
                            MapConfig.mapboxUrlForStyle(
                              _mapStyle,
                              satelliteLabelsOn: _showSatelliteLabels,
                            ) ??
                            _mapStyle.url,
                        subdomains: MapConfig.isMapboxActive
                            ? const <String>[]
                            : _mapStyle.subdomains,
                        // Overzoom past the source's native cap (e.g. terrain
                        // tops out at z17) by upscaling the last real tiles
                        // instead of requesting a non-existent tile. Mapbox
                        // styles serve deeper, so keep them at the interaction
                        // cap when active.
                        maxNativeZoom: MapConfig.isMapboxActive
                            ? 18
                            : _mapStyle.maxNativeZoom,
                        userAgentPackageName: MapConfig.userAgentPackageName,
                        // Retina only for sources that serve real @2x tiles
                        // (URL has {r}). Simulated retina shifts requested
                        // tile coords and would desync the offline cache.
                        retinaMode: MapConfig.isMapboxActive
                            ? true
                            : MapConfig.styleSupportsRetina(_mapStyle),
                        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                        // No tileBuilder — AnimatedOpacity at constant 1.0
                        // created unnecessary animation controllers per tile,
                        // causing visible lag on initial map load.
                      ),
                      // Transparent place-name + boundary overlay above
                      // satellite imagery. Sits below mesh / node overlays.
                      // Skipped on the Mapbox path (labels are baked into
                      // satellite-streets-v12).
                      if (_mapStyle == MapTileStyle.satellite &&
                          _showSatelliteLabels &&
                          !MapConfig.isMapboxActive)
                        MapConfig.satelliteReferenceLabelsTileLayer(),
                      // Range circles (theoretical coverage) - hide in location only mode
                      if (_showRangeCircles && !widget.locationOnlyMode)
                        CircleLayer(
                          circles: _rangeCirclesFor(
                            nodesWithPosition,
                            geomSig,
                            myNodeNum,
                            accentColor,
                            themeBrightness,
                          ),
                        ),
                      // Heatmap layer - hide in location only mode
                      if (_showHeatmap && !widget.locationOnlyMode)
                        CircleLayer(
                          circles: _heatmapFor(
                            nodesWithPosition,
                            geomSig,
                            accentColor,
                            themeBrightness,
                          ),
                        ),
                      // Node trails (movement history) - hide in location only mode
                      if (!widget.locationOnlyMode &&
                          (_showPositionHistory ||
                              _trackNodeNum != null ||
                              _nodeTrails.isNotEmpty))
                        PolylineLayer(
                          polylines: _nodeTrailsFor(
                            nodesWithPosition,
                            geomSig,
                            myNodeNum,
                            positionLogs,
                            accentColor,
                            themeBrightness,
                          ),
                        ),
                      // Connection lines (optional) - hide in location only mode
                      if (_showConnectionLines && !widget.locationOnlyMode)
                        PolylineLayer(
                          polylines: _connectionLinesFor(
                            nodesWithPosition,
                            geomSig,
                            myNodeNum,
                            accentColor,
                            themeBrightness,
                          ),
                        ),
                      // Measurement line — terrain-colored when available
                      if (_measureStart != null && _measureEnd != null)
                        PolylineLayer(
                          polylines:
                              _measureTerrainPolylines ??
                              [
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
                      // Traceroute route overlay
                      if (widget.tracerouteLog != null)
                        PolylineLayer(
                          polylines: _buildTraceroutePolylines(
                            widget.tracerouteLog!,
                            nodes,
                            myNodeNum,
                          ),
                        ),
                      if (widget.tracerouteLog != null)
                        MarkerLayer(
                          rotate: true,
                          markers: finiteMarkers(
                            _buildTracerouteMarkers(
                              widget.tracerouteLog!,
                              nodes,
                              myNodeNum,
                            ),
                          ),
                        ),
                      // Waypoint markers
                      if (_showWaypoints)
                        MarkerLayer(
                          rotate: true,
                          markers: finiteMarkers(
                            localWaypoints.map((w) {
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
                            }),
                          ),
                        ),
                      // Shared mesh waypoints (WAYPOINT_APP) — orange emoji
                      // markers, distinct from the local "dropped pin" above.
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
                                child: GestureDetector(
                                  onTap: () => _showMeshWaypointSheet(w),
                                  child: _MeshWaypointMarker(waypoint: w),
                                ),
                              );
                            }).whereType<Marker>(),
                          ),
                        ),
                      // Node markers - hide in location only mode.
                      // Markers are built once and consumed by either
                      // the plain MarkerLayer or the
                      // MarkerClusterLayerWidget depending on the
                      // user's `clusterMarkers` setting. Each marker
                      // keys on the nodeNum so the cluster tap-to-list
                      // sheet can recover the underlying MeshNode.
                      if (!widget.locationOnlyMode)
                        Builder(
                          builder: (context) {
                            // Deterministic render order: list order for
                            // peers, own node appended last so it always
                            // renders on top (the only documented
                            // ordering invariant). A stable order is
                            // required for marker-list identity reuse.
                            final orderedNodes = <_NodeWithPosition>[];
                            _NodeWithPosition? ownNode;
                            for (final n in nodesWithPosition) {
                              if (n.node.nodeNum == myNodeNum) {
                                ownNode = n;
                              } else {
                                orderedNodes.add(n);
                              }
                            }
                            if (ownNode != null) orderedNodes.add(ownNode);
                            final markers = _markersFor(
                              orderedNodes,
                              myNodeNum: myNodeNum,
                              nodedexPinsByNum: nodedexPinsByNum,
                            );

                            if (!_clusterMarkers) {
                              return MarkerLayer(
                                rotate: true,
                                markers: markers,
                              );
                            }
                            return _buildClusterLayer(
                              context: context,
                              markers: markers,
                              nodesByNum: {
                                for (final n in orderedNodes) n.node.nodeNum: n,
                              },
                            );
                          },
                        ),
                      // TAK movement trails for tracked entities
                      if (_showTakLayer &&
                          !widget.locationOnlyMode &&
                          AppFeatureFlags.isTakGatewayEnabled)
                        _TakTrailOverlay(),
                      // TAK entity markers - separate layer from mesh nodes
                      if (_showTakLayer &&
                          !widget.locationOnlyMode &&
                          AppFeatureFlags.isTakGatewayEnabled)
                        _TakMarkerLayer(
                          onMarkerTap: (event) {
                            HapticFeedback.selectionClick();
                            AppLogging.tak(
                              'Map entity selected: uid=${event.uid}, '
                              'callsign=${event.displayName}',
                            );
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
                      if (_measureStart != null &&
                          isFiniteLatLng(_measureStart))
                        MarkerLayer(
                          rotate: true,
                          markers: finiteMarkers([
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
                                child: Center(
                                  child: Text(
                                    context.l10n.mapMeasureMarkerA,
                                    style: const TextStyle(
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
                                  child: Center(
                                    child: Text(
                                      context.l10n.mapMeasureMarkerB,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      // Distance labels layer - hide in location only mode
                      if (!widget.locationOnlyMode && _showDistanceLabels)
                        MarkerLayer(
                          rotate: true,
                          markers: finiteMarkers(
                            _distanceLabelsFor(
                              nodesWithPosition,
                              geomSig,
                              myNodeNum,
                              accentColor,
                              themeBrightness,
                            ),
                          ),
                        ),
                      // Map attribution (matches world mesh style). Mapbox
                      // TOS requires the © Mapbox + © OpenStreetMap line and
                      // a tap-through to about/maps when their tiles are
                      // active.
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: GestureDetector(
                          onTap: () => launchUrl(
                            Uri.parse(
                              MapConfig.isMapboxActive
                                  ? MapConfig.mapboxAttributionUrl
                                  : _mapStyle == MapTileStyle.satellite
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
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
                              ),
                            ),
                            child: Text(
                              MapConfig.isMapboxActive
                                  ? MapConfig.mapboxAttributionLabel
                                  : _mapStyle == MapTileStyle.satellite
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
                  // Traceroute "no GPS data" notice. The Africa-fallback
                  // fix (Sprint 4) re-centers the camera on the user's
                  // location when the route has zero valid hops, but
                  // without this banner the user just sees a blank map
                  // with no route line and no explanation. The banner
                  // makes the empty state legible.
                  if (tracerouteHasNoGps)
                    Positioned(
                      left: _mapPadding,
                      right: _mapPadding + _controlSize + _controlSpacing,
                      top: _mapPadding,
                      child: StatusBanner.info(
                        title: context.l10n.mapTracerouteNoGpsTitle,
                        subtitle: context.l10n.mapTracerouteNoGpsSubtitle,
                        icon: Icons.location_off_outlined,
                      ),
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
                        nodeA: _measureNodeA,
                        nodeB: _measureNodeB,
                        hasTerrainSegments:
                            _measureTerrainPolylines != null &&
                            _measureTerrainPolylines!.length > 1,
                        terrainResult: _measureTerrainResult,
                        onClear: () => setState(() {
                          _measureStart = null;
                          _measureEnd = null;
                          _measureNodeA = null;
                          _measureNodeB = null;
                          _measureTerrainPolylines = null;
                          _measureTerrainResult = null;
                        }),
                        onShare: () => _shareLocation(
                          _measureStart!,
                          label: context.l10n.mapShareDistanceLabel(
                            _formatDistance(
                              _calculateDistance(
                                _measureStart!.latitude,
                                _measureStart!.longitude,
                                _measureEnd!.latitude,
                                _measureEnd!.longitude,
                              ),
                            ),
                          ),
                        ),
                        onExitMeasureMode: () => setState(() {
                          _measureMode = false;
                          _measureStart = null;
                          _measureEnd = null;
                          _measureNodeA = null;
                          _measureNodeB = null;
                          _measureTerrainPolylines = null;
                          _measureTerrainResult = null;
                        }),
                        onSwap: () {
                          setState(() {
                            final tmpStart = _measureStart;
                            final tmpEnd = _measureEnd;
                            final tmpNodeA = _measureNodeA;
                            final tmpNodeB = _measureNodeB;
                            _measureStart = tmpEnd;
                            _measureEnd = tmpStart;
                            _measureNodeA = tmpNodeB;
                            _measureNodeB = tmpNodeA;
                            _measureTerrainPolylines = null;
                            _measureTerrainResult = null;
                          });
                          _fetchMeasurementTerrain();
                        },
                        onCopyCoordinates: () {
                          final a = _measureStart!;
                          final b = _measureEnd!;
                          Clipboard.setData(
                            ClipboardData(
                              text:
                                  'A: ${a.latitude.toStringAsFixed(6)}, ' // lint-allow: hardcoded-string
                                  '${a.longitude.toStringAsFixed(6)}\n'
                                  'B: ${b.latitude.toStringAsFixed(6)}, ' // lint-allow: hardcoded-string
                                  '${b.longitude.toStringAsFixed(6)}',
                            ),
                          );
                          showSuccessSnackBar(
                            context,
                            context.l10n.mapCoordinatesCopied,
                          );
                        },
                        units: _units,
                      ),
                    ),
                  // Mode indicator (centered at top)
                  if (_measureMode &&
                      (_measureStart == null || _measureEnd == null))
                    Positioned(
                      top: _mapPadding,
                      left: _mapPadding,
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius20,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.straighten,
                                size: 16,
                                color: Colors.black,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Flexible(
                                child: Text(
                                  _measureStart == null
                                      ? context.l10n.mapMeasureTapPointA
                                      : context.l10n.mapMeasureTapPointB,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppTheme.spacing8),
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
                        onClose: () => setState(() {
                          _selectedNode = null;
                          _trackNodeNum = null;
                        }),
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
                        onTraceroute: _selectedNode!.nodeNum != myNodeNum
                            ? () => _sendTracerouteFromMap(_selectedNode!)
                            : null,
                        onViewDetails: () {
                          final node = _selectedNode!;
                          showNodeDetails(
                            context,
                            node,
                            node.nodeNum == myNodeNum,
                          );
                        },
                        onOpenInNodeDex: () {
                          final node = _selectedNode!;
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  NodeDexDetailScreen(nodeNum: node.nodeNum),
                            ),
                          );
                        },
                        onViewHistory: () {
                          final node = _selectedNode!;
                          TraceRouteLogScreen.open(
                            context,
                            nodeNum: node.nodeNum,
                          );
                        },
                        onShowTrack: _selectedNode!.hasPosition
                            ? () {
                                setState(() {
                                  if (_trackNodeNum == _selectedNode!.nodeNum) {
                                    _trackNodeNum = null;
                                  } else {
                                    _trackNodeNum = _selectedNode!.nodeNum;
                                  }
                                });
                              }
                            : null,
                        isTrackVisible: _trackNodeNum == _selectedNode!.nodeNum,
                        onViewPositionLog: () {
                          final node = _selectedNode!;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PositionLogScreen(
                                initialNodeNum: node.nodeNum,
                              ),
                            ),
                          );
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
                          AppLogging.tak(
                            'Map popup tap-through to detail: '
                            'uid=${_selectedTakEntity!.uid}',
                          );
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
                        onNavigateTo: () {
                          AppLogging.tak(
                            'Map navigate-to: uid=${_selectedTakEntity!.uid}',
                          );
                          ref.haptics.itemSelect();
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TakNavigateScreen(
                                targetUid: _selectedTakEntity!.uid,
                                initialCallsign:
                                    _selectedTakEntity!.displayName,
                              ),
                            ),
                          );
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
                        units: _units,
                      ),
                    ),
                  // Node count indicator - hide in location only mode, measure
                  // mode, and traceroute mode (in traceroute the count refers
                  // to the global NodeDB which is unrelated to the route, and
                  // its top-left position collides with the route banners).
                  if (!_showNodeList &&
                      !_showFilters &&
                      !widget.locationOnlyMode &&
                      !_measureMode &&
                      widget.tracerouteLog == null)
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
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius20,
                                ),
                                border: Border.all(
                                  color: context.border.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    context.l10n.mapNodeCount(
                                      '${nodesWithPosition.length}${nodesWithPosition.length != allNodesWithPosition.length ? '/${allNodesWithPosition.length}' : ''}',
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  if (takCount > 0) ...[
                                    const SizedBox(width: AppTheme.spacing6),
                                    Text(
                                      context.l10n.mapTakEntityCount(takCount),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(width: AppTheme.spacing4),
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
                  // Map controls — wrapped in ValueListenableBuilder so the
                  // compass needle redraws on rotation changes without
                  // rebuilding the whole screen.
                  ValueListenableBuilder<double>(
                    valueListenable: _mapRotationNotifier,
                    builder: (context, rotation, _) {
                      return MapControlsOverlay(
                        currentZoom: _currentZoom,
                        minZoom: 4,
                        maxZoom: 18,
                        mapRotation: rotation,
                        isHeadingUp: _headingUpMode,
                        compassMode: _compassMode,
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
                        onResetNorth: _onCompassTap,
                        hasMyLocation: nodesWithPosition.any(
                          (n) => n.node.nodeNum == myNodeNum,
                        ),
                        onLocationUnavailable: () {
                          final navigator = Navigator.of(context);
                          showActionSnackBar(
                            context,
                            'No position available. Enable GPS on your device or turn on "Provide phone location" in Settings.', // lint-allow: hardcoded-string
                            actionLabel: context.l10n.actionView,
                            onAction: () => navigator.push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(
                                  initialSearchQuery: 'phone location',
                                ),
                              ),
                            ),
                            type: SnackBarType.warning,
                          );
                        },
                        showFitAll: true,
                        showNavigation: true,
                        showCompass: true,
                      );
                    },
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
        _measureNodeA = null;
        _measureNodeB = null;
        _measureTerrainPolylines = null;
        _measureTerrainResult = null;
      } else if (_measureEnd == null) {
        _measureEnd = point;
        _measureNodeB = null;
      } else {
        _measureStart = point;
        _measureEnd = null;
        _measureNodeA = null;
        _measureNodeB = null;
        _measureTerrainPolylines = null;
        _measureTerrainResult = null;
      }
    });
    HapticFeedback.selectionClick();
    if (_measureStart != null && _measureEnd != null) {
      _fetchMeasurementTerrain();
    }
  }

  void _handleMeasureNodeTap(_NodeWithPosition n) {
    final point = LatLng(n.latitude, n.longitude);
    setState(() {
      if (_measureStart == null) {
        _measureStart = point;
        _measureEnd = null;
        _measureNodeA = n.node;
        _measureNodeB = null;
        _measureTerrainPolylines = null;
        _measureTerrainResult = null;
      } else if (_measureEnd == null) {
        _measureEnd = point;
        _measureNodeB = n.node;
      } else {
        _measureStart = point;
        _measureEnd = null;
        _measureNodeA = n.node;
        _measureNodeB = null;
        _measureTerrainPolylines = null;
        _measureTerrainResult = null;
      }
    });
    HapticFeedback.selectionClick();
    if (_measureStart != null && _measureEnd != null) {
      _fetchMeasurementTerrain();
    }
  }

  Future<void> _fetchMeasurementTerrain() async {
    final start = _measureStart;
    final end = _measureEnd;
    if (start == null || end == null) return;
    if (_terrainFetchInProgress) return;

    _elevationService ??= ElevationService();
    setState(() => _terrainFetchInProgress = true);

    final result = await _elevationService!.fetchProfile(start, end);
    if (!mounted) return;

    // Verify measurement hasn't changed while fetching
    if (_measureStart != start || _measureEnd != end) {
      setState(() => _terrainFetchInProgress = false);
      return;
    }

    switch (result) {
      case ElevationProfileSuccess(:final samples):
        final gpsAltA = _measureNodeA?.altitude;
        final gpsAltB = _measureNodeB?.altitude;
        // Fall back to terrain elevation at the endpoint when GPS altitude is
        // unavailable (e.g. a random map point with no node attached).
        final terrainAltA = samples.isNotEmpty
            ? samples.first.elevationMeters?.round()
            : null;
        final terrainAltB = samples.isNotEmpty
            ? samples.last.elevationMeters?.round()
            : null;
        final terrainResult = evaluateLosFromProfile(
          samples: samples
              .map(
                (s) => (
                  distanceMeters: s.distanceMeters,
                  latitude: s.latitude,
                  longitude: s.longitude,
                  elevationMeters: s.elevationMeters,
                ),
              )
              .toList(),
          altAMeters: gpsAltA ?? terrainAltA,
          altBMeters: gpsAltB ?? terrainAltB,
        );
        safeSetState(() {
          _measureTerrainPolylines = _buildTerrainAwarePolylines(
            samples,
            terrainResult,
          );
          _measureTerrainResult = terrainResult;
          _terrainFetchInProgress = false;
        });
      case ElevationProfileOffline():
      case ElevationProfileFailure():
        // Offline or API error — fall back to single-color line
        safeSetState(() {
          _measureTerrainPolylines = _buildFallbackMeasurePolylines();
          _measureTerrainResult = null;
          _terrainFetchInProgress = false;
        });
    }
  }

  List<Polyline> _buildTerrainAwarePolylines(
    List<ElevationSample> samples,
    TerrainLosResult terrainResult,
  ) {
    if (samples.length < 2) return _buildFallbackMeasurePolylines();

    // If no altitude data, color segments by terrain-only (all same color)
    if (!terrainResult.hasAltitudeData) {
      return _buildFallbackMeasurePolylines();
    }

    final polylines = <Polyline>[];
    for (var i = 0; i < samples.length - 1; i++) {
      final clearance = terrainResult.perSampleClearanceMeters[i];
      final nextClearance = terrainResult.perSampleClearanceMeters[i + 1];
      // Use the worse clearance of the two endpoints for this segment
      final segClearance = math.min(clearance, nextClearance);

      Color segColor;
      if (segClearance < 0) {
        segColor = AppTheme.errorRed;
      } else if (segClearance <
          terrainResult.perSampleFresnelRadiusMeters[i] * 0.4) {
        segColor = AppTheme.warningYellow;
      } else {
        segColor = AppTheme.successGreen;
      }

      polylines.add(
        Polyline(
          points: [
            LatLng(samples[i].latitude, samples[i].longitude),
            LatLng(samples[i + 1].latitude, samples[i + 1].longitude),
          ],
          color: segColor,
          strokeWidth: 3,
          pattern: const StrokePattern.dotted(spacingFactor: 1.5),
        ),
      );
    }
    return polylines;
  }

  List<Polyline> _buildFallbackMeasurePolylines() {
    final start = _measureStart;
    final end = _measureEnd;
    if (start == null || end == null) return [];

    final altA = _measureNodeA?.altitude;
    final altB = _measureNodeB?.altitude;
    final distanceM = const Distance().as(LengthUnit.Meter, start, end);

    Color lineColor;
    if (altA != null && altB != null) {
      final result = evaluateLos(
        altA: altA,
        altB: altB,
        distanceMeters: distanceM,
      );
      lineColor = switch (result.verdict) {
        LosVerdict.clear => AppTheme.successGreen,
        LosVerdict.marginal => AppTheme.warningYellow,
        LosVerdict.obstructed => AppTheme.errorRed,
        LosVerdict.unknown => AppTheme.warningYellow,
      };
    } else {
      lineColor = AppTheme.warningYellow;
    }

    return [
      Polyline(
        points: [start, end],
        color: lineColor,
        strokeWidth: 3,
        pattern: const StrokePattern.dotted(spacingFactor: 1.5),
      ),
    ];
  }

  void _showWaypointMenu(LatLng point) {
    AppBottomSheet.showActions(
      context: context,
      actions: [
        BottomSheetAction(
          icon: Icons.add_location,
          iconColor: AppTheme.warningYellow,
          label: context.l10n.mapDropWaypoint,
          onTap: () => _addWaypoint(point),
        ),
        BottomSheetAction(
          icon: Icons.place,
          iconColor: AccentColors.orange,
          label: context.l10n.mapCreateMeshWaypoint,
          onTap: () => _openWaypointForm(location: point),
        ),
        BottomSheetAction(
          icon: Icons.share,
          iconColor: context.accentColor,
          label: context.l10n.mapShareLocation,
          onTap: () => _shareLocation(point),
        ),
        BottomSheetAction(
          icon: Icons.copy,
          iconColor: context.textSecondary,
          label: context.l10n.mapCopyCoordinates,
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

  void _showWaypointDetails(MapLocalWaypoint waypoint) {
    AppBottomSheet.showActions(
      context: context,
      actions: [
        BottomSheetAction(
          icon: Icons.share,
          iconColor: context.accentColor,
          label: context.l10n.mapShare,
          onTap: () => _shareLocation(waypoint.position, label: waypoint.label),
        ),
        BottomSheetAction(
          icon: Icons.copy,
          iconColor: context.textSecondary,
          label: context.l10n.mapCopyCoordinates,
          onTap: () => _copyCoordinates(waypoint.position),
        ),
        BottomSheetAction(
          icon: Icons.delete,
          label: context.l10n.mapDelete,
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
          const SizedBox(height: AppTheme.spacing8),
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

  void _openWaypointForm({required LatLng location, MeshWaypoint? existing}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            WaypointFormScreen(location: location, existing: existing),
      ),
    );
  }

  void _showMeshWaypointSheet(MeshWaypoint waypoint) {
    final myNodeNum = ref.read(myNodeNumProvider);
    final canEdit = !waypoint.isLocked || waypoint.lockedTo == myNodeNum;
    final point = LatLng(waypoint.latitude, waypoint.longitude);
    final senderName =
        ref.read(nodesProvider)[waypoint.sourceNodeNum]?.displayName ??
        '!${waypoint.sourceNodeNum.toRadixString(16)}';

    AppBottomSheet.showActions(
      context: context,
      actions: [
        if (canEdit)
          BottomSheetAction(
            icon: Icons.edit,
            iconColor: context.accentColor,
            label: context.l10n.waypointEdit,
            onTap: () => _openWaypointForm(location: point, existing: waypoint),
          ),
        BottomSheetAction(
          icon: Icons.share,
          iconColor: context.accentColor,
          label: context.l10n.mapShare,
          onTap: () => _shareLocation(point, label: waypoint.name),
        ),
        BottomSheetAction(
          icon: Icons.copy,
          iconColor: context.textSecondary,
          label: context.l10n.mapCopyCoordinates,
          onTap: () => _copyCoordinates(point),
        ),
        BottomSheetAction(
          icon: Icons.delete_outline,
          label: context.l10n.waypointDeleteForMe,
          isDestructive: true,
          onTap: () => ref
              .read(waypointsNotifierProvider.notifier)
              .deleteForMe(waypoint.id),
        ),
        if (canEdit)
          BottomSheetAction(
            icon: Icons.delete_forever,
            label: context.l10n.waypointDeleteForEveryone,
            isDestructive: true,
            onTap: () => ref
                .read(waypointsNotifierProvider.notifier)
                .deleteForEveryone(waypoint),
          ),
      ],
      header: Column(
        children: [
          Text(
            waypoint.name.isNotEmpty
                ? '${waypoint.iconEmoji} ${waypoint.name}'.trim()
                : context.l10n.waypointCreateTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          if (waypoint.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing4),
            Text(
              waypoint.description,
              textAlign: TextAlign.center,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.spacing8),
          Text(
            context.l10n.waypointSheetFrom(senderName),
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textTertiary,
            ),
          ),
          if (waypoint.isLocked && !canEdit) ...[
            const SizedBox(height: AppTheme.spacing4),
            Text(
              context.l10n.waypointLockedReadOnly,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textTertiary,
              ),
            ),
          ],
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
    _fitNodesCamera(nodes);
    HapticFeedback.lightImpact();
  }

  // Frames every node in [nodes] without firing haptics — shared by the
  // fit-all button (via [_fitAllNodes]) and the one-shot auto-fit on a
  // plain Map-tab open, where a haptic on load would be wrong.
  void _fitNodesCamera(List<_NodeWithPosition> nodes) {
    // Single-pass min/max with strict WGS-84 range filter. The mesh-observer
    // / NodeDex feed contains a small fraction of nodes with garbage
    // coordinates (e.g. lat=-211, lon=194) that pass `.isFinite` but fail
    // `safeLatLng` — without this filter the bounds become invalid and
    // `CameraFit.bounds` no-ops silently.
    var minLat = double.infinity;
    var maxLat = double.negativeInfinity;
    var minLng = double.infinity;
    var maxLng = double.negativeInfinity;
    var anyValid = false;
    for (final n in nodes) {
      final lat = n.latitude;
      final lng = n.longitude;
      if (!lat.isFinite || !lng.isFinite) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      anyValid = true;
    }
    if (!anyValid) return;

    final latPadding = (maxLat - minLat) * 0.15;
    final lngPadding = (maxLng - minLng) * 0.15;

    final sw = safeLatLng(minLat - latPadding, minLng - lngPadding);
    final ne = safeLatLng(maxLat + latPadding, maxLng + lngPadding);
    if (sw == null || ne == null) return;

    final cameraFit = CameraFit.bounds(
      bounds: LatLngBounds(sw, ne),
      padding: const EdgeInsets.all(AppTheme.spacing50),
    );

    final camera = cameraFit.fit(_mapController.camera);
    _animatedMove(camera.center, camera.zoom.clamp(4.0, 16.0));
  }

  /// Wraps the mesh-map node markers in a [MarkerClusterLayerWidget]
  /// when the user has opted in via the map menu. Config mirrors the
  /// World Map (`maxClusterRadius: 80`, animations tuned for large
  /// node sets) so behaviour is consistent across the two map
  /// surfaces. Tapping a cluster opens a bottom sheet listing the
  /// underlying nodes — the user can pick one to select it (the
  /// existing node-info card surfaces it) or pinch-zoom to expand
  /// the cluster into individual markers.
  Widget _buildClusterLayer({
    required BuildContext context,
    required List<Marker> markers,
    required Map<int, _NodeWithPosition> nodesByNum,
  }) {
    final accentColor = context.accentColor;
    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: 80,
        size: const Size(44, 44),
        alignment: Alignment.center,
        padding: EdgeInsets.zero,
        maxZoom: 15,
        zoomToBoundsOnClick: false,
        animationsOptions: const AnimationsOptions(
          zoom: Duration.zero,
          fitBound: Duration(milliseconds: 300),
          centerMarker: Duration.zero,
          spiderfy: Duration(milliseconds: 200),
        ),
        markers: markers,
        builder: (context, clusterMarkers) {
          final count = clusterMarkers.length;
          final size = count > 100
              ? 48.0
              : count > 50
              ? 44.0
              : 40.0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                _showClusterListSheet(context, clusterMarkers, nodesByNum),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.9),
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
                  count > 999
                      ? '${(count / 1000).toStringAsFixed(1)}k'
                      : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Opens a bottom sheet listing the nodes contained in a tapped
  /// cluster. Tapping a row selects the node (which surfaces the
  /// existing node info card) and dismisses the sheet.
  Future<void> _showClusterListSheet(
    BuildContext context,
    List<Marker> clusterMarkers,
    Map<int, _NodeWithPosition> nodesByNum,
  ) async {
    final nodes = <_NodeWithPosition>[];
    for (final m in clusterMarkers) {
      final key = m.key;
      if (key is ValueKey<int>) {
        final node = nodesByNum[key.value];
        if (node != null) nodes.add(node);
      }
    }
    if (nodes.isEmpty) return;
    HapticFeedback.selectionClick();
    await AppBottomSheet.show<void>(
      context: context,
      child: _ClusterListSheet(
        nodes: nodes,
        onNodeSelected: (node) {
          // The cluster-marker context captured by this closure can
          // unmount between sheet open and node tap (filter change,
          // position refresh), so use the State's mounted-checked
          // pop helper rather than Navigator.of on the stale context.
          if (!safeNavigatorPop()) return;
          safeSetState(() {
            _selectedNode = node;
            _selectedTakEntity = null;
          });
        },
      ),
    );
  }

  /// Bottom-sheet content listing nodes contained in a tapped cluster.
  /// Header (count + interaction hint) followed by a scrollable list
  /// of row tiles. Tapping a row invokes [onNodeSelected].

  Widget _buildEmptyState() {
    final nodes = ref.watch(nodesProvider);
    final totalNodes = nodes.length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
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
            SizedBox(height: AppTheme.spacing24),
            Text(
              context.l10n.mapEmptyTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              totalNodes > 0
                  ? context.l10n.mapEmptyBodyWithNodes(totalNodes)
                  : context.l10n.mapEmptyBodyNoNodes,
              style: context.bodySecondaryStyle?.copyWith(
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacing24),
            ElevatedButton.icon(
              onPressed: _isRefreshing ? null : _refreshPositions,
              icon: _isRefreshing
                  ? const LoadingIndicator(size: 16)
                  : Icon(Icons.refresh, size: 18),
              label: Text(
                _isRefreshing
                    ? context.l10n.mapRequesting
                    : context.l10n.mapRequestPositions,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
            ),
            SizedBox(height: AppTheme.spacing12),
            Text(
              context.l10n.mapPositionBroadcastHint,
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
  /// Per-node diff over the marker cache. Reuses the cached [Marker]
  /// instance when every input it renders from is unchanged, so element
  /// reconciliation short-circuits the whole marker subtree; reuses the
  /// previous list instance when nothing at all changed, which lets the
  /// cluster layer's identity check skip a full re-cluster.
  List<Marker> _markersFor(
    List<_NodeWithPosition> orderedNodes, {
    required int? myNodeNum,
    required Map<int, NodeDexMapPin> nodedexPinsByNum,
  }) {
    var reused = 0;
    var rebuilt = 0;
    final markers = <Marker>[];
    final order = <int>[];
    final seen = <int>{};

    for (final n in orderedNodes) {
      // Mirrors the finiteMarkers gate the layer previously applied.
      if (!n.latitude.isFinite || !n.longitude.isFinite) continue;
      final nodeNum = n.node.nodeNum;
      final isMyNode = nodeNum == myNodeNum;
      final isSelected = _selectedNode?.nodeNum == nodeNum;
      final pin = widget.nodedexMode ? nodedexPinsByNum[nodeNum] : null;

      final cached = _markerCache[nodeNum];
      Marker marker;
      if (cached != null &&
          cached.matches(
            node: n.node,
            pin: pin,
            latitude: n.latitude,
            longitude: n.longitude,
            isStale: n.isStale,
            isMyNode: isMyNode,
            isSelected: isSelected,
          )) {
        marker = cached.marker;
        reused++;
      } else {
        marker = _buildNodeMarker(
          n,
          isMyNode: isMyNode,
          isSelected: isSelected,
          pin: pin,
        );
        _markerCache[nodeNum] = _CachedNodeMarker(
          marker: marker,
          node: n.node,
          pin: pin,
          latitude: n.latitude,
          longitude: n.longitude,
          isStale: n.isStale,
          isMyNode: isMyNode,
          isSelected: isSelected,
        );
        rebuilt++;
      }
      markers.add(marker);
      order.add(nodeNum);
      seen.add(nodeNum);
    }

    _markerCache.removeWhere((nodeNum, _) => !seen.contains(nodeNum));
    _markersReusedLastBuild = reused;
    _markersRebuiltLastBuild = rebuilt;

    final previousList = _markerListCache;
    final previousOrder = _markerOrderCache;
    if (rebuilt == 0 &&
        previousList != null &&
        previousOrder != null &&
        previousList.length == markers.length &&
        _intListEquals(previousOrder, order)) {
      _markerListReusedLastBuild = true;
      return previousList;
    }
    final markerList = List<Marker>.of(markers, growable: false);
    _markerListCache = markerList;
    _markerOrderCache = order;
    _markerListReusedLastBuild = false;
    return markerList;
  }

  Marker _buildNodeMarker(
    _NodeWithPosition n, {
    required bool isMyNode,
    required bool isSelected,
    required NodeDexMapPin? pin,
  }) {
    return Marker(
      key: ValueKey<int>(n.node.nodeNum),
      point: LatLng(n.latitude, n.longitude),
      width: isMyNode ? 56 : (isSelected ? 56 : 44),
      height: isMyNode ? 56 : (isSelected ? 56 : 44),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (_measureMode) {
            _handleMeasureNodeTap(n);
          } else {
            // A cached marker can outlive the MeshNode snapshot it was
            // built from; selection must always use the live node.
            final live = widget.nodedexMode
                ? n.node
                : (ref.read(nodesProvider)[n.node.nodeNum] ?? n.node);
            setState(() {
              _selectedNode = live;
              _selectedTakEntity = null;
            });
          }
        },
        onLongPress: () {
          HapticFeedback.heavyImpact();
          final live = widget.nodedexMode
              ? n.node
              : (ref.read(nodesProvider)[n.node.nodeNum] ?? n.node);
          setState(() {
            _measureMode = true;
            _measureStart = LatLng(n.latitude, n.longitude);
            _measureEnd = null;
            _measureNodeA = live;
            _measureNodeB = null;
            _measureTerrainPolylines = null;
            _measureTerrainResult = null;
            _selectedNode = null;
            _selectedTakEntity = null;
          });
        },
        child: widget.nodedexMode
            ? NodeDexSigilMarker(
                pin: pin!,
                isSelected: isSelected,
                isStale: n.isStale,
              )
            : _NodeMarker(
                node: n.node,
                isMyNode: isMyNode,
                isSelected: isSelected,
                isStale: n.isStale,
              ),
      ),
    );
  }

  List<CircleMarker> _rangeCirclesFor(
    List<_NodeWithPosition> nodes,
    List<_GeomSig> geomSig,
    int? myNodeNum,
    Color accent,
    Brightness brightness,
  ) {
    final cached = _rangeCirclesCache;
    if (cached != null &&
        _rangeCirclesSigMyNodeNum == myNodeNum &&
        _rangeCirclesSigAccent == accent &&
        _rangeCirclesSigBrightness == brightness &&
        _geomSigEquals(_rangeCirclesSigNodes, geomSig)) {
      return cached;
    }
    final circles = nodes
        .where((n) => n.latitude.isFinite && n.longitude.isFinite)
        .map((n) {
          final isMyNode = n.node.nodeNum == myNodeNum;
          // Per-node colour derived from nodeNum only (no avatar
          // override): the cache signature is geometry-based, so the
          // colour must be a pure function of inputs it captures.
          final circleColor = isMyNode
              ? accent
              : nodeColorFromId(n.node.nodeNum);
          return CircleMarker(
            point: LatLng(n.latitude, n.longitude),
            radius: 5000, // 5km range circle
            useRadiusInMeter: true,
            color: circleColor.withValues(alpha: 0.08),
            borderColor: circleColor.withValues(alpha: 0.2),
            borderStrokeWidth: 1,
          );
        })
        .toList(growable: false);
    _rangeCirclesSigNodes = geomSig;
    _rangeCirclesSigMyNodeNum = myNodeNum;
    _rangeCirclesSigAccent = accent;
    _rangeCirclesSigBrightness = brightness;
    _rangeCirclesCache = circles;
    return circles;
  }

  List<CircleMarker> _heatmapFor(
    List<_NodeWithPosition> nodes,
    List<_GeomSig> geomSig,
    Color accent,
    Brightness brightness,
  ) {
    final cached = _heatmapCache;
    if (cached != null &&
        _heatmapSigAccent == accent &&
        _heatmapSigBrightness == brightness &&
        _geomSigEquals(_heatmapSigNodes, geomSig)) {
      return cached;
    }
    final circles = nodes
        .where((n) => n.latitude.isFinite && n.longitude.isFinite)
        .map((n) {
          return CircleMarker(
            point: LatLng(n.latitude, n.longitude),
            radius: 50,
            color: accent.withValues(alpha: 0.15),
            borderColor: accent.withValues(alpha: 0.3),
            borderStrokeWidth: 1,
          );
        })
        .toList(growable: false);
    _heatmapSigNodes = geomSig;
    _heatmapSigAccent = accent;
    _heatmapSigBrightness = brightness;
    _heatmapCache = circles;
    return circles;
  }

  List<Polyline> _nodeTrailsFor(
    List<_NodeWithPosition> nodes,
    List<_GeomSig> geomSig,
    int? myNodeNum,
    List<PositionLog> positionLogs,
    Color accent,
    Brightness brightness,
  ) {
    final cached = _trailsCache;
    if (cached != null &&
        identical(_trailsSigLogs, positionLogs) &&
        _trailsSigTrackNode == _trackNodeNum &&
        _trailsSigShowHistory == _showPositionHistory &&
        _trailsSigEpoch == _trailsEpoch &&
        _trailsSigMyNodeNum == myNodeNum &&
        _trailsSigAccent == accent &&
        _trailsSigBrightness == brightness &&
        _geomSigEquals(_trailsSigNodes, geomSig)) {
      return cached;
    }
    final trails = developer.Timeline.timeSync(
      'map.nodeTrails',
      () => _buildNodeTrails(nodes, myNodeNum, positionLogs),
    );
    _trailsSigNodes = geomSig;
    _trailsSigLogs = positionLogs;
    _trailsSigTrackNode = _trackNodeNum;
    _trailsSigShowHistory = _showPositionHistory;
    _trailsSigEpoch = _trailsEpoch;
    _trailsSigMyNodeNum = myNodeNum;
    _trailsSigAccent = accent;
    _trailsSigBrightness = brightness;
    _trailsCache = trails;
    return trails;
  }

  List<Polyline> _connectionLinesFor(
    List<_NodeWithPosition> nodes,
    List<_GeomSig> geomSig,
    int? myNodeNum,
    Color accent,
    Brightness brightness,
  ) {
    final cached = _connectionLinesCache;
    if (cached != null &&
        _connLinesSigMaxKm == _connectionMaxDistance &&
        _connLinesSigMyNodeNum == myNodeNum &&
        _connLinesSigAccent == accent &&
        _connLinesSigBrightness == brightness &&
        _geomSigEquals(_connLinesSigNodes, geomSig)) {
      return cached;
    }
    final lines = developer.Timeline.timeSync(
      'map.connectionLines',
      () => _buildConnectionLines(nodes, myNodeNum),
    );
    _connLinesSigNodes = geomSig;
    _connLinesSigMaxKm = _connectionMaxDistance;
    _connLinesSigMyNodeNum = myNodeNum;
    _connLinesSigAccent = accent;
    _connLinesSigBrightness = brightness;
    _connectionLinesCache = lines;
    return lines;
  }

  List<Marker> _distanceLabelsFor(
    List<_NodeWithPosition> nodes,
    List<_GeomSig> geomSig,
    int? myNodeNum,
    Color accent,
    Brightness brightness,
  ) {
    // Zoom participates as the same coarse gate the builder applies; zoom
    // is deliberately only observed on data/selection-driven builds (the
    // camera handlers avoid setState), matching the pre-cache behavior.
    final zoomedIn = _currentZoom >= 10;
    final cached = _distanceLabelsCache;
    if (cached != null &&
        _distLabelsSigMyNodeNum == myNodeNum &&
        _distLabelsSigAccent == accent &&
        _distLabelsSigBrightness == brightness &&
        _distLabelsSigZoomedIn == zoomedIn &&
        _geomSigEquals(_distLabelsSigNodes, geomSig)) {
      return cached;
    }
    final labels = developer.Timeline.timeSync(
      'map.distanceLabels',
      () => _buildDistanceLabels(nodes, myNodeNum),
    );
    _distLabelsSigNodes = geomSig;
    _distLabelsSigMyNodeNum = myNodeNum;
    _distLabelsSigAccent = accent;
    _distLabelsSigBrightness = brightness;
    _distLabelsSigZoomedIn = zoomedIn;
    _distanceLabelsCache = labels;
    return labels;
  }

  List<Polyline> _buildNodeTrails(
    List<_NodeWithPosition> nodes,
    int? myNodeNum,
    List<PositionLog> positionLogs,
  ) {
    final trails = <Polyline>[];

    if ((_showPositionHistory || _trackNodeNum != null) &&
        positionLogs.isNotEmpty) {
      // Group persisted position logs by nodeNum
      final logsByNode = <int, List<PositionLog>>{};
      for (final log in positionLogs) {
        logsByNode.putIfAbsent(log.nodeNum, () => []).add(log);
      }

      // Build a polyline per node from persisted history
      for (final entry in logsByNode.entries) {
        final nodeNum = entry.key;
        final logs = entry.value;
        if (logs.length < 2) continue;

        // Sort chronologically
        logs.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Downsample to avoid GPU stutter from dotted pattern on 1000+ pts
        final points = _downsamplePoints(
          logs.map((l) => LatLng(l.latitude, l.longitude)).toList(),
          maxPoints: 200,
        );
        if (points.length < 2) continue;

        // Per-node identity colour (user-set avatar colour wins).
        final matchingNode = nodes
            .where((n) => n.node.nodeNum == nodeNum)
            .firstOrNull;
        final isMyNode = nodeNum == myNodeNum;
        final color = isMyNode
            ? context.accentColor
            : resolveNodeColor(
                nodeNum: nodeNum,
                avatarColor: matchingNode?.node.avatarColor,
              );

        trails.add(
          Polyline(
            points: points,
            color: color.withValues(alpha: 0.6),
            strokeWidth: 3,
            pattern: const StrokePattern.dotted(spacingFactor: 1.5),
          ),
        );
      }
    } else {
      // Fall back to ephemeral in-session trails
      for (final node in nodes) {
        final trail = _nodeTrails[node.node.nodeNum];
        if (trail == null || trail.length < 2) continue;

        final isMyNode = node.node.nodeNum == myNodeNum;
        final points = trail
            .map((t) => LatLng(t.latitude, t.longitude))
            .toList();

        trails.add(
          Polyline(
            points: points,
            color:
                (isMyNode
                        ? context.accentColor
                        : resolveNodeColor(
                            nodeNum: node.node.nodeNum,
                            avatarColor: node.node.avatarColor,
                          ))
                    .withValues(alpha: 0.4),
            strokeWidth: 2,
            pattern: const StrokePattern.dotted(spacingFactor: 1.5),
          ),
        );
      }
    }

    return trails;
  }

  /// Reduce a list of [LatLng] points to at most [maxPoints] by evenly
  /// sampling, always keeping the first and last point for continuity.
  List<LatLng> _downsamplePoints(List<LatLng> points, {int maxPoints = 200}) {
    if (points.length <= maxPoints) return points;
    final result = <LatLng>[points.first];
    final step = (points.length - 1) / (maxPoints - 1);
    for (int i = 1; i < maxPoints - 1; i++) {
      result.add(points[(i * step).round()]);
    }
    result.add(points.last);
    return result;
  }

  /// Build connection lines with visual distinction for uncertain connections
  List<Polyline> _buildConnectionLines(
    List<_NodeWithPosition> nodes,
    int? myNodeNum,
  ) {
    final lines = <Polyline>[];
    final maxDistanceKm = _connectionMaxDistance;
    var vincentyCalls = 0;

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final node1 = nodes[i];
        final node2 = nodes[j];

        // Cheap conservative prefilter; Vincenty stays the sole
        // decision function for pairs that pass, so the emitted line
        // set is identical to the unfiltered loop.
        if (!connectionPrefilterMayBeWithin(
          node1.latitude,
          node1.longitude,
          node2.latitude,
          node2.longitude,
          maxDistanceKm,
        )) {
          continue;
        }

        vincentyCalls++;
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

    _connPairsEvaluatedLastBuild = vincentyCalls;
    return lines;
  }

  /// Build polylines for a traceroute route overlay.
  ///
  /// Forward hops are rendered in teal, return hops in purple. Only hops
  /// with valid positions are included. The local device position is used
  /// as the origin for the forward path and destination for the return path.
  // Coordinates persisted by the traceroute pipeline have surfaced as
  // NaN / out-of-range in field reports; route every direct LatLng()
  // construction through safeLatLng so a malformed hop drops out of the
  // route instead of crashing the polyline / tile / marker layer at
  // build time. Shared by both the polyline and marker builders so the
  // map renders the route from one position-resolution source of truth.
  static LatLng? _safeRoutePoint(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat == 0.0 && lng == 0.0) return null; // unset sentinel
    return safeLatLng(lat, lng);
  }

  // Build the label pill marker shared by every traceroute node — the
  // intermediate hops and both route endpoints. Border colour encodes
  // direction: teal for the forward terminus / hops, purple for the
  // return terminus / hops.
  static Marker _tracerouteLabelMarker(
    LatLng point,
    String name,
    Color borderColor,
  ) {
    return Marker(
      point: point,
      width: 80,
      height: 32,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  List<Polyline> _buildTraceroutePolylines(
    TraceRouteLog log,
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final polylines = <Polyline>[];
    var droppedHops = 0;

    // Resolve local device position as the start of the forward route.
    // Prefer the stored position captured at traceroute time.
    var localPosition = _safeRoutePoint(
      log.originLatitude,
      log.originLongitude,
    );
    if (localPosition == null && myNodeNum != null) {
      final myNode = nodes[myNodeNum];
      if (myNode != null && myNode.hasPosition) {
        localPosition = safeLatLng(myNode.latitude, myNode.longitude);
      }
    }

    // Resolve target node position as the end of the forward route.
    var targetPosition = _safeRoutePoint(
      log.targetLatitude,
      log.targetLongitude,
    );
    if (targetPosition == null) {
      final targetNode = nodes[log.targetNode];
      if (targetNode != null && targetNode.hasPosition) {
        targetPosition = safeLatLng(targetNode.latitude, targetNode.longitude);
      }
    }

    LatLng? positionOf(TraceRouteHop hop) {
      final point = _safeRoutePoint(hop.latitude, hop.longitude);
      if (point == null &&
          hop.latitude != null &&
          hop.longitude != null &&
          !(hop.latitude == 0.0 && hop.longitude == 0.0)) {
        droppedHops++;
      }
      return point;
    }

    // Forward path: local → hop1 → hop2 → ... → target.
    //
    // Each entry is the logical adjacency in route order; nulls
    // mark hops that did not report a position. tracerouteSegmentsFor
    // turns the sequence into a list of segments tagged as
    // dashed/solid so each leg is rendered with a pattern that
    // honestly reflects how much of it the device actually verified.
    final forwardHops = log.hops.where((h) => !h.back).toList();
    final forwardRoute = <LatLng?>[
      localPosition,
      ...forwardHops.map(positionOf),
      targetPosition,
    ];
    final forwardSegments = tracerouteSegmentsFor(forwardRoute);

    // When the request never came back (`response == false`), the
    // forward path is conceptually unverified end-to-end — treat
    // every segment as dashed regardless of which hops we managed
    // to geolocate, and skip the return path entirely.
    final unverified = !log.response;
    for (final segment in forwardSegments) {
      final dashed = segment.dashed || unverified;
      polylines.add(
        Polyline(
          points: segment.points,
          color: AccentColors.teal,
          strokeWidth: 3.5,
          pattern: dashed
              ? StrokePattern.dashed(segments: const [12, 8])
              : const StrokePattern.solid(),
        ),
      );
    }

    if (droppedHops > 0) {
      AppLogging.maps(
        'Traceroute polyline target=${log.targetNode}: dropped '
        '$droppedHops hop(s) with non-finite/out-of-range coordinates',
      );
    }

    if (unverified) {
      return polylines;
    }

    // Return path: target → hop1 → hop2 → ... → local. Verified legs
    // stay dotted (the established return-direction visual); gaps
    // upgrade to dashed so the user can tell which legs were
    // confirmed and which were bridged.
    final returnHops = log.hops.where((h) => h.back).toList();
    final returnRoute = <LatLng?>[
      targetPosition,
      ...returnHops.map(positionOf),
      localPosition,
    ];
    final returnSegments = tracerouteSegmentsFor(returnRoute);
    for (final segment in returnSegments) {
      polylines.add(
        Polyline(
          points: segment.points,
          color: AccentColors.purple.withValues(alpha: 0.8),
          strokeWidth: 3.0,
          pattern: segment.dashed
              ? StrokePattern.dashed(segments: const [12, 8])
              : const StrokePattern.dotted(spacingFactor: 1.5),
        ),
      );
    }

    return polylines;
  }

  /// Build markers for every node in a traceroute route overlay — the
  /// intermediate hops plus the two route endpoints (local origin and
  /// target node). The detail view lists both endpoints as terminus
  /// rows, so the map must label them too or the two surfaces disagree.
  List<Marker> _buildTracerouteMarkers(
    TraceRouteLog log,
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final markers = <Marker>[];
    final seen = <int>{};

    // Endpoint markers first. Resolve their positions with the same
    // precedence as the polyline builder (stored trace-time position,
    // then the live node table) so the labels land on the polyline's
    // endpoint anchors.
    final targetNode = nodes[log.targetNode];
    var targetPosition = _safeRoutePoint(
      log.targetLatitude,
      log.targetLongitude,
    );
    if (targetPosition == null &&
        targetNode != null &&
        targetNode.hasPosition) {
      targetPosition = safeLatLng(targetNode.latitude, targetNode.longitude);
    }
    if (targetPosition != null) {
      seen.add(log.targetNode);
      final name =
          targetNode?.displayName ??
          NodeDisplayNameResolver.defaultName(log.targetNode);
      markers.add(
        _tracerouteLabelMarker(targetPosition, name, AccentColors.teal),
      );
    }

    final myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    var originPosition = _safeRoutePoint(
      log.originLatitude,
      log.originLongitude,
    );
    if (originPosition == null && myNode != null && myNode.hasPosition) {
      originPosition = safeLatLng(myNode.latitude, myNode.longitude);
    }
    if (originPosition != null) {
      if (myNodeNum != null) seen.add(myNodeNum);
      final name =
          myNode?.displayName ?? context.l10n.telemetryTracerouteYouLabel;
      markers.add(
        _tracerouteLabelMarker(originPosition, name, AccentColors.purple),
      );
    }

    for (final hop in log.hops) {
      if (seen.contains(hop.nodeNum)) continue;
      seen.add(hop.nodeNum);

      if (hop.latitude == null ||
          hop.longitude == null ||
          (hop.latitude == 0.0 && hop.longitude == 0.0)) {
        continue;
      }

      final point = safeLatLng(hop.latitude, hop.longitude);
      if (point == null) {
        AppLogging.maps(
          'Traceroute marker skipped: hop ${hop.nodeNum} has non-finite '
          'coordinates (lat=${hop.latitude}, lng=${hop.longitude})',
        );
        continue;
      }

      final node = nodes[hop.nodeNum];
      final name =
          node?.displayName ?? NodeDisplayNameResolver.defaultName(hop.nodeNum);

      markers.add(
        _tracerouteLabelMarker(
          point,
          name,
          hop.back ? AccentColors.purple : AccentColors.teal,
        ),
      );
    }

    return markers;
  }

  /// Compute the bounding box that contains all traceroute hop positions
  /// including the local device and target node.
  LatLngBounds? _tracerouteBounds(
    TraceRouteLog log,
    Map<int, MeshNode> nodes,
    int? myNodeNum,
  ) {
    final points = <LatLng>[];

    void addIfFinite(double? lat, double? lng) {
      if (lat == null || lng == null) return;
      if (lat == 0.0 && lng == 0.0) return; // unset sentinel
      final point = safeLatLng(lat, lng);
      if (point != null) points.add(point);
    }

    // Local device position - prefer stored position from traceroute time.
    addIfFinite(log.originLatitude, log.originLongitude);
    if (points.isEmpty && myNodeNum != null) {
      final myNode = nodes[myNodeNum];
      if (myNode != null && myNode.hasPosition) {
        addIfFinite(myNode.latitude, myNode.longitude);
      }
    }

    // Target node position - prefer stored position from traceroute time.
    final beforeTarget = points.length;
    addIfFinite(log.targetLatitude, log.targetLongitude);
    if (points.length == beforeTarget) {
      final target = nodes[log.targetNode];
      if (target != null && target.hasPosition) {
        addIfFinite(target.latitude, target.longitude);
      }
    }

    // Hop positions.
    for (final hop in log.hops) {
      addIfFinite(hop.latitude, hop.longitude);
    }

    if (points.length < 2) return null;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    // Add padding (10% on each side), clamped to WGS-84 range so we
    // never hand non-finite or out-of-range corners to LatLngBounds.
    final latPad = (maxLat - minLat) * 0.1;
    final lngPad = (maxLng - minLng) * 0.1;

    final sw =
        safeLatLng(minLat - latPad, minLng - lngPad) ??
        LatLng(
          (minLat - latPad).clamp(-90.0, 90.0),
          (minLng - lngPad).clamp(-180.0, 180.0),
        );
    final ne =
        safeLatLng(maxLat + latPad, maxLng + lngPad) ??
        LatLng(
          (maxLat + latPad).clamp(-90.0, 90.0),
          (maxLng + lngPad).clamp(-180.0, 180.0),
        );
    return LatLngBounds(sw, ne);
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
                borderRadius: BorderRadius.circular(AppTheme.radius10),
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

    // In NodeDex mode the synthesized `nodes` list comes from the encounter
    // log, and own-node encounters are not re-recorded as the device moves
    // (see _handleNodesUpdate's isOwnNode branch). The pin would be frozen
    // at first-discovery position. Center on the live current position via
    // nodesProvider instead.
    if (widget.nodedexMode) {
      final live = ref.read(nodesProvider)[myNodeNum];
      if (live != null && live.hasPosition) {
        _animatedMove(LatLng(live.latitude!, live.longitude!), 14.0);
        HapticFeedback.lightImpact();
        return;
      }
    }

    final myNode = nodes.where((n) => n.node.nodeNum == myNodeNum).firstOrNull;
    if (myNode != null) {
      _animatedMove(LatLng(myNode.latitude, myNode.longitude), 14.0);
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _sendTracerouteFromMap(MeshNode node) async {
    final cooldownRemaining = ref
        .read(countdownProvider.notifier)
        .globalTracerouteRemaining;
    if (cooldownRemaining > 0) {
      showInfoSnackBar(
        context,
        context.l10n.nodeDetailTracerouteCooldownTooltip(cooldownRemaining),
      );
      return;
    }

    final connectionState = ref.read(connectionStateProvider);
    final isConnected = connectionState.maybeWhen(
      data: (state) => state == DeviceConnectionState.connected,
      orElse: () => false,
    );

    if (!isConnected) {
      showErrorSnackBar(context, context.l10n.nodeDetailTracerouteNotConnected);
      return;
    }

    final protocol = ref.read(protocolServiceProvider);
    final displayName = node.displayName;

    try {
      await protocol.sendTraceroute(node.nodeNum);

      if (!mounted) return;

      ref
          .read(countdownProvider.notifier)
          .startTracerouteCountdown(node.nodeNum);

      if (context.mounted) {
        showSuccessSnackBar(
          context,
          context.l10n.nodeDetailTracerouteSent(displayName),
        );
      }
    } catch (e) {
      if (context.mounted) {
        // Readiness gate (Step 6c).
        if (maybeShowTxBlockedSnackBar(context, e)) {
          return;
        }
        showErrorSnackBar(
          context,
          context.l10n.nodeDetailTracerouteError(e.toString()),
        );
      }
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

/// Map marker for a shared mesh waypoint: an orange circle with the waypoint's
/// emoji glyph (or a pin icon when no emoji is set).
class _MeshWaypointMarker extends StatelessWidget {
  final MeshWaypoint waypoint;

  const _MeshWaypointMarker({required this.waypoint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AccentColors.orange,
        shape: BoxShape.circle,
        border: Border.all(color: SemanticColors.onMarker, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
        ],
      ),
      child: waypoint.hasRenderableIcon
          ? EmojiGlyph(codePoint: waypoint.icon, size: 18)
          : Icon(Icons.place, size: 18, color: SemanticColors.onMarker),
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

Color _presenceColor(BuildContext context, PresenceConfidence confidence) {
  switch (confidence) {
    case PresenceConfidence.active:
      return AccentColors.green;
    case PresenceConfidence.fading:
      return AppTheme.warningYellow;
    case PresenceConfidence.stale:
      return context.textSecondary;
    case PresenceConfidence.unknown:
      return context.textTertiary;
  }
}

/// Bottom-sheet content listing the nodes inside a tapped cluster on
/// the mesh map. The sheet itself is presented by [AppBottomSheet.show]
/// in `_showClusterListSheet`. Tapping a row delegates to
/// [onNodeSelected] which closes the sheet and selects the node.
class _ClusterListSheet extends StatelessWidget {
  final List<_NodeWithPosition> nodes;
  final ValueChanged<MeshNode> onNodeSelected;

  const _ClusterListSheet({required this.nodes, required this.onNodeSelected});

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
              final node = nodes[index].node;
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
                onTap: () => onNodeSelected(node),
              );
            },
          ),
        ),
      ],
    );
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

/// Conservative spherical (haversine) distance in km.
///
/// Top-level so tests can pin the prefilter's correctness contract
/// without spinning up the full map.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  const degToRad = math.pi / 180.0;
  final dLat = (lat2 - lat1) * degToRad;
  final dLng = (lng2 - lng1) * degToRad;
  final sinHalfLat = math.sin(dLat / 2);
  final sinHalfLng = math.sin(dLng / 2);
  final a =
      sinHalfLat * sinHalfLat +
      math.cos(lat1 * degToRad) *
          math.cos(lat2 * degToRad) *
          sinHalfLng *
          sinHalfLng;
  return 2 * earthRadiusKm * math.asin(math.min(1.0, math.sqrt(a)));
}

/// Cheap conservative screen for the connection-lines pair loop.
///
/// Returns false ONLY when the production decision function provably
/// rejects the pair. That decision is `Distance().as(Kilometer, ...)`,
/// which ROUNDS to whole kilometers, so a pair up to maxDistanceKm + 0.5
/// of true distance still renders a line. The screen therefore widens
/// the threshold by the rounding half-step plus a 1% margin for the
/// haversine-vs-Vincenty (Earth flattening) difference; the latitude
/// screen uses the same widened bound (one degree of latitude is never
/// less than ~110.567 km).
bool connectionPrefilterMayBeWithin(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
  double maxDistanceKm,
) {
  const minKmPerDegLat = 110.567;
  final screenKm = (maxDistanceKm + 0.5) * 1.01;
  if ((lat2 - lat1).abs() * minKmPerDegLat > screenKm) return false;
  return haversineKm(lat1, lng1, lat2, lng2) <= screenKm;
}

/// Exact per-node geometry signature for the map layer caches. Record
/// equality is structural, so an element-wise list compare is an exact
/// change detector with no collision risk.
typedef _GeomSig = (int nodeNum, double lat, double lng, bool isStale);

/// One marker cache entry: the built [Marker] plus every input it was
/// derived from. [node] and [pin] are compared by identity because
/// NodesNotifier replaces instances on any field change, making
/// identity a complete change signal for the rendered content.
class _CachedNodeMarker {
  final Marker marker;
  final MeshNode node;
  final NodeDexMapPin? pin;
  final double latitude;
  final double longitude;
  final bool isStale;
  final bool isMyNode;
  final bool isSelected;

  const _CachedNodeMarker({
    required this.marker,
    required this.node,
    required this.pin,
    required this.latitude,
    required this.longitude,
    required this.isStale,
    required this.isMyNode,
    required this.isSelected,
  });

  bool matches({
    required MeshNode node,
    required NodeDexMapPin? pin,
    required double latitude,
    required double longitude,
    required bool isStale,
    required bool isMyNode,
    required bool isSelected,
  }) {
    return identical(this.node, node) &&
        identical(this.pin, pin) &&
        this.latitude == latitude &&
        this.longitude == longitude &&
        this.isStale == isStale &&
        this.isMyNode == isMyNode &&
        this.isSelected == isSelected;
  }
}

/// Computes the label shown inside a map node marker.
///
/// Prefers the full shortName (capped to 4 chars per Meshtastic spec)
/// so a node labelled "MYSO" reads as itself, not the single letter
/// "M". Falls back to the last 4 hex digits of `nodeNum` when no
/// shortName is set — that matches NodeDisplayNameResolver.shortHex's
/// fallback shape and reads as a recognisable mesh identifier.
///
/// Top-level so widget tests can pin the contract without spinning up
/// the full map.
/// Splits a traceroute's logical route (a sequence of nullable
/// [LatLng]s — null where a hop did not report a position) into a
/// list of contiguous polyline segments.
///
/// A segment is solid when both endpoints are adjacent known points
/// in the route. It is dashed when the renderer had to bridge over
/// one or more hops with no known position — the dashed pattern
/// signals "we know A and we know D but the in-between hops did not
/// report a location, so the line you see is inferred rather than
/// measured."
///
/// Returns an empty list when fewer than two known points are
/// present. The helper is pure so widget tests can pin the
/// dashed/solid contract without spinning up the map.
List<({List<LatLng> points, bool dashed})> tracerouteSegmentsFor(
  List<LatLng?> route,
) {
  final segments = <({List<LatLng> points, bool dashed})>[];
  LatLng? last;
  bool crossedGap = false;

  for (final point in route) {
    if (point == null) {
      // Only count a missing position as a gap when we already have
      // a tail — leading nulls aren't a gap, they just push the
      // route start forward.
      if (last != null) crossedGap = true;
      continue;
    }
    if (last != null) {
      segments.add((points: [last, point], dashed: crossedGap));
    }
    last = point;
    crossedGap = false;
  }

  return segments;
}

String nodeMarkerLabel(MeshNode node) {
  final shortName = node.shortName;
  if (shortName != null && shortName.isNotEmpty) {
    // safeInitials sanitizes (repairs lone surrogates / strips controls) then
    // takes up to 4 grapheme clusters — grapheme-aware for emoji + accents.
    final initials = safeInitials(shortName, 4);
    if (initials.isNotEmpty) return initials;
  }
  // Last 4 hex digits — matches the canonical short-form id used
  // elsewhere in the app for nodes without a self-reported name.
  final hex = node.nodeNum.toRadixString(16).padLeft(8, '0');
  return hex.substring(hex.length - 4).toUpperCase();
}

/// Custom marker widget for nodes
class _NodeMarker extends StatefulWidget {
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
  State<_NodeMarker> createState() => _NodeMarkerState();
}

class _NodeMarkerState extends State<_NodeMarker>
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
    // Per-node colour (low three bytes of nodeNum as RGB, user override
    // wins) so every node keeps its identity colour on the map and never
    // ghosts with age. Own node stays on the app accent.
    final color = widget.isMyNode
        ? context.accentColor
        : resolveNodeColor(
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
          // Dark drop shadow defines the circle edge against same-toned
          // map terrain so the marker never blends into the background.
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
          // Full shortName (Meshtastic spec: <=4 chars) instead of just
          // the first character, so a node labelled e.g. "MYSO" reads
          // as itself on the map rather than collapsing to "M".
          // FittedBox keeps long shortnames or wide grapheme clusters
          // from overflowing the marker circle on small zooms.
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
                  // Black-or-white by the fill's luminance so the label
                  // stays legible on any per-node colour.
                  color: labelColor,
                ),
              ),
            ),
          ),
          // Stale indicator (small question mark overlay)
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
  final MeasurementUnits units;

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
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    // Sort: my node first, then by distance from me, then alphabetically.
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

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isEntityTab = activeTab == 1;

    return MapNodeDrawer(
      title: isEntityTab
          ? context.l10n.mapEntitiesTitle
          : context.l10n.mapNodesTitle,
      headerIcon: Icons.hub,
      itemCount: isEntityTab ? takEvents.length : sortedNodes.length,
      onClose: onClose,
      searchController: isEntityTab ? takSearchController : searchController,
      onSearchChanged: isEntityTab ? onTakSearchChanged : onSearchChanged,
      searchHintText: isEntityTab
          ? context.l10n.mapSearchEntitiesHint
          : context.l10n.mapSearchNodesHint,
      headerExtra: showTakTab
          ? Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: context.border.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  _PanelTab(
                    label: context.l10n.mapNodesTitle,
                    count: sortedNodes.length,
                    isActive: activeTab == 0,
                    onTap: () => onTabChanged(0),
                  ),
                  _PanelTab(
                    label: context.l10n.mapEntitiesTitle,
                    count: takEvents.length,
                    isActive: activeTab == 1,
                    onTap: () => onTabChanged(1),
                  ),
                ],
              ),
            )
          : null,
      content: isEntityTab
          ? Expanded(child: _buildTakEntityList(context, bottomPadding))
          : Expanded(
              child: sortedNodes.isEmpty
                  ? const DrawerEmptyState()
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        top: 4,
                        bottom: bottomPadding + 8,
                      ),
                      itemCount: sortedNodes.length,
                      itemBuilder: (context, index) {
                        final nodeWithPos = sortedNodes[index];
                        final isMyNode = nodeWithPos.node.nodeNum == myNodeNum;
                        final isSelected =
                            selectedNode?.nodeNum == nodeWithPos.node.nodeNum;
                        final distance = calculateDistanceFromMe(nodeWithPos);

                        final presence = presenceConfidenceFor(
                          presenceMap,
                          nodeWithPos.node,
                        );
                        return StaggeredDrawerTile(
                          index: index,
                          child: _NodeListItem(
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
                            units: units,
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildTakEntityList(BuildContext context, double bottomPadding) {
    final query = takSearchController.text.toLowerCase();
    final filtered = query.isEmpty
        ? takEvents
        : takEvents
              .where(
                (e) =>
                    e.displayName.toLowerCase().contains(query) ||
                    e.typeDescription.toLowerCase().contains(query) ||
                    e.uid.toLowerCase().contains(query),
              )
              .toList();
    if (filtered.isEmpty) {
      return DrawerEmptyState(
        icon: Icons.military_tech_outlined,
        message: query.isEmpty
            ? context.l10n.mapNoEntities
            : context.l10n.mapNoMatchingEntities,
        hint: query.isEmpty ? null : context.l10n.mapSearchHint,
      );
    }
    return ListView.builder(
      padding: EdgeInsets.only(top: 4, bottom: bottomPadding + 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final event = filtered[index];
        return StaggeredDrawerTile(
          index: index,
          child: _TakEntityListItem(
            event: event,
            onTap: () => onTakEntitySelected(event),
          ),
        );
      },
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
  final MeasurementUnits units;

  const _NodeListItem({
    required this.nodeWithPos,
    required this.isMyNode,
    required this.isSelected,
    required this.distance,
    required this.presence,
    required this.lastHeardAge,
    required this.onTap,
    required this.units,
  });

  String _formatDistance(double km, AppLocalizations l10n) =>
      formatDistanceKm(km, units, l10n);

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
                          ? safeInitials(node.shortName, 1)
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
              const SizedBox(width: AppTheme.spacing10),
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
                          SizedBox(width: AppTheme.spacing6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius3,
                              ),
                            ),
                            child: Text(
                              context.l10n.mapYouBadge,
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
                    SizedBox(height: AppTheme.spacing2),
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
                        SizedBox(width: AppTheme.spacing4),
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
                          SizedBox(width: AppTheme.spacing6),
                          Text(
                            context.l10n.mapLastKnown,
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
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Text(
                    _formatDistance(distance!, context.l10n),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              SizedBox(width: AppTheme.spacing4),
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
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
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
              SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.mapFilterNodesTitle,
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
          const SizedBox(height: AppTheme.spacing12),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius20),
                    border: Border.all(
                      color: isSelected ? context.accentColor : context.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    filter.label(context.l10n),
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

/// Measurement card showing distance, bearing, altitude, and LOS between two points.
///
/// Long-press the card to open an actions sheet with LOS analysis,
/// copy coordinates, copy summary, open in external maps, and swap endpoints.
class _MeasurementCard extends StatefulWidget {
  final LatLng start;
  final LatLng end;
  final MeshNode? nodeA;
  final MeshNode? nodeB;
  final VoidCallback onClear;
  final VoidCallback onShare;
  final VoidCallback onExitMeasureMode;
  final VoidCallback? onSwap;
  final VoidCallback? onCopyCoordinates;
  final bool hasTerrainSegments;
  final TerrainLosResult? terrainResult;
  final MeasurementUnits units;

  const _MeasurementCard({
    required this.start,
    required this.end,
    this.nodeA,
    this.nodeB,
    required this.onClear,
    required this.onShare,
    required this.onExitMeasureMode,
    this.onSwap,
    this.hasTerrainSegments = false,
    this.terrainResult,
    this.onCopyCoordinates,
    required this.units,
  });

  @override
  State<_MeasurementCard> createState() => _MeasurementCardState();
}

class _MeasurementCardState extends State<_MeasurementCard> {
  bool _showLos = false;

  String _formatDistance(double km) =>
      formatDistanceKm(km, widget.units, context.l10n);

  double _calculateDistanceKm() {
    return const Distance().as(LengthUnit.Kilometer, widget.start, widget.end);
  }

  String _pointLabel(LatLng point, MeshNode? node, String prefix) {
    if (node != null) {
      final name = node.displayName;
      final alt = node.altitude != null
          ? ' · ${node.altitude}m'
          : ''; // lint-allow: hardcoded-string
      return '$prefix: $name$alt';
    }
    return '$prefix: ${point.latitude.toStringAsFixed(4)}, '
        '${point.longitude.toStringAsFixed(4)}';
  }

  String _buildSummary({
    required double distanceKm,
    required double bearing,
    required String cardinal,
    int? elevDelta,
  }) {
    final buf = StringBuffer();
    buf.write(
      '${_formatDistance(distanceKm)} · '
      '${bearing.toStringAsFixed(0)}° $cardinal',
    );
    if (elevDelta != null) {
      buf.write(' · ${elevDelta >= 0 ? '+' : ''}${elevDelta}m');
    }
    buf.writeln();
    buf.writeln(_pointLabel(widget.start, widget.nodeA, 'A'));
    buf.write(_pointLabel(widget.end, widget.nodeB, 'B'));
    return buf.toString();
  }

  void _showActionsSheet(BuildContext context) {
    final distanceKm = _calculateDistanceKm();
    final distanceM = distanceKm * 1000;
    final bearing = calculateBearing(
      widget.start.latitude,
      widget.start.longitude,
      widget.end.latitude,
      widget.end.longitude,
    );
    final cardinal = formatBearingCardinal(bearing);
    final altA = widget.nodeA?.altitude;
    final altB = widget.nodeB?.altitude;
    final hasElevation = altA != null && altB != null;
    final elevDelta = hasElevation ? altB - altA : null;

    HapticFeedback.selectionClick();
    AppBottomSheet.showActions<String>(
      context: context,
      header: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
        child: Text(
          context.l10n.mapMeasurementActions,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      actions: [
        if (hasElevation)
          BottomSheetAction(
            icon: Icons.visibility,
            label: context.l10n.mapLosAnalysis,
            subtitle: context.l10n.mapLosAnalysisSubtitle,
            onTap: () => setState(() => _showLos = !_showLos),
          ),
        BottomSheetAction(
          icon: Icons.landscape,
          label: context.l10n.mapTerrainProfile,
          subtitle: context.l10n.mapTerrainProfileSubtitle,
          onTap: () {
            final capturedContext = context;
            Navigator.of(capturedContext).push(
              MaterialPageRoute<void>(
                builder: (_) => TerrainProfileScreen(
                  start: widget.start,
                  end: widget.end,
                  nodeA: widget.nodeA,
                  nodeB: widget.nodeB,
                ),
              ),
            );
          },
        ),
        BottomSheetAction(
          icon: Icons.share,
          label: context.l10n.mapShareMeasurement,
          subtitle: context.l10n.mapShareMeasurementSubtitle,
          onTap: widget.onShare,
        ),
        BottomSheetAction(
          icon: Icons.copy,
          label: context.l10n.mapCopySummary,
          subtitle: _formatDistance(distanceKm),
          onTap: () {
            Clipboard.setData(
              ClipboardData(
                text: _buildSummary(
                  distanceKm: distanceKm,
                  bearing: bearing,
                  cardinal: cardinal,
                  elevDelta: elevDelta,
                ),
              ),
            );
            if (context.mounted) {
              showSuccessSnackBar(context, context.l10n.mapMeasurementCopied);
            }
          },
        ),
        if (widget.onCopyCoordinates != null)
          BottomSheetAction(
            icon: Icons.pin_drop,
            label: context.l10n.mapCopyCoordinates,
            subtitle: context.l10n.mapCopyBothCoordinates,
            onTap: widget.onCopyCoordinates,
          ),
        BottomSheetAction(
          icon: Icons.open_in_new,
          label: context.l10n.mapOpenMidpointInMaps,
          subtitle: context.l10n.mapOpenInExternalApp,
          onTap: () {
            final midLat = (widget.start.latitude + widget.end.latitude) / 2.0;
            final midLon =
                (widget.start.longitude + widget.end.longitude) / 2.0;
            launchUrl(
              Uri.parse('https://maps.apple.com/?ll=$midLat,$midLon&z=14'),
              mode: LaunchMode.externalApplication,
            );
          },
        ),
        if (widget.onSwap != null)
          BottomSheetAction(
            icon: Icons.swap_horiz,
            label: context.l10n.mapSwapAB,
            subtitle: context.l10n.mapReverseDirection,
            onTap: widget.onSwap,
          ),
        if (hasElevation)
          BottomSheetAction(
            icon: Icons.terrain,
            label: context.l10n.mapRfLinkBudget,
            subtitle: context.l10n.mapEstimatedPathLoss(
              _estimatePathLoss(distanceM, 906.0).toStringAsFixed(0),
            ),
            onTap: () {
              final fspl = _estimatePathLoss(distanceM, 906.0);
              Clipboard.setData(
                ClipboardData(
                  text: context.l10n.mapRfLinkBudgetClipboard(
                    _formatDistance(distanceKm),
                    '906 MHz', // lint-allow: hardcoded-string
                    '${fspl.toStringAsFixed(1)} dB',
                    'Alt A: ${altA}m · Alt B: ${altB}m\n' // lint-allow: hardcoded-string
                        'Bearing: ${bearing.toStringAsFixed(0)}° $cardinal', // lint-allow: hardcoded-string
                  ),
                ),
              );
              if (context.mounted) {
                showSuccessSnackBar(context, context.l10n.mapLinkBudgetCopied);
              }
            },
          ),
      ],
    );
  }

  /// Free-space path loss in dB: FSPL = 20log10(d) + 20log10(f) - 27.55
  /// where d is in meters and f is in MHz.
  static double _estimatePathLoss(double distanceM, double freqMhz) {
    if (distanceM <= 0) return 0;
    return 20 * math.log(distanceM) / math.ln10 +
        20 * math.log(freqMhz) / math.ln10 -
        27.55;
  }

  @override
  Widget build(BuildContext context) {
    final distanceKm = _calculateDistanceKm();
    final distanceM = distanceKm * 1000;
    final bearing = calculateBearing(
      widget.start.latitude,
      widget.start.longitude,
      widget.end.latitude,
      widget.end.longitude,
    );
    final cardinal = formatBearingCardinal(bearing);

    // Elevation delta
    final altA = widget.nodeA?.altitude;
    final altB = widget.nodeB?.altitude;
    final hasElevation = altA != null && altB != null;
    final elevDelta = hasElevation ? altB - altA : null;

    return GestureDetector(
      onLongPress: () => _showActionsSheet(context),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppTheme.radius12),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _formatDistance(distanceKm),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.warningYellow,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            '${bearing.toStringAsFixed(0)}° $cardinal',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                            ),
                          ),
                          if (elevDelta != null) ...[
                            const SizedBox(width: AppTheme.spacing8),
                            Icon(
                              elevDelta >= 0
                                  ? Icons.trending_up
                                  : Icons.trending_down,
                              size: 14,
                              color: context.textSecondary,
                            ),
                            const SizedBox(width: AppTheme.spacing2),
                            Text(
                              '${elevDelta >= 0 ? '+' : ''}${elevDelta}m',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _pointLabel(widget.start, widget.nodeA, 'A'),
                        style: context.captionStyle?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                      Text(
                        _pointLabel(widget.end, widget.nodeB, 'B'),
                        style: context.captionStyle?.copyWith(
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 20),
                  color: context.textTertiary,
                  onPressed: widget.onClear,
                  tooltip: context.l10n.mapNewMeasurement,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: AppTheme.errorRed,
                  onPressed: widget.onExitMeasureMode,
                  tooltip: context.l10n.mapExitMeasureModeTooltip,
                ),
              ],
            ),
            // Long-press hint
            const SizedBox(height: AppTheme.spacing4),
            Text(
              context.l10n.mapLongPressForActions,
              style: TextStyle(fontSize: 10, color: context.textTertiary),
            ),
            // Terrain LOS color legend
            if (widget.hasTerrainSegments) ...[
              const SizedBox(height: AppTheme.spacing8),
              _LosColorLegend(),
            ],
            // LOS result panel (toggled from actions sheet)
            if (_showLos && hasElevation) ...[
              const SizedBox(height: AppTheme.spacing8),
              _LosResultPanel(
                altA: altA,
                altB: altB,
                distanceMeters: distanceM,
                terrainResult: widget.terrainResult,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact inline legend for terrain-aware LOS measurement line colors.
class _LosColorLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendDot(AppTheme.successGreen),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          context.l10n.mapLosLegendClear,
          style: TextStyle(fontSize: 10, color: context.textTertiary),
        ),
        const SizedBox(width: AppTheme.spacing12),
        _legendDot(AppTheme.warningYellow),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          context.l10n.mapLosLegendMarginal,
          style: TextStyle(fontSize: 10, color: context.textTertiary),
        ),
        const SizedBox(width: AppTheme.spacing12),
        _legendDot(AppTheme.errorRed),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          context.l10n.mapLosLegendObstructed,
          style: TextStyle(fontSize: 10, color: context.textTertiary),
        ),
      ],
    );
  }

  static Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Compact LOS result panel shown inside _MeasurementCard.
class _LosResultPanel extends StatelessWidget {
  final int altA;
  final int altB;
  final double distanceMeters;
  final TerrainLosResult? terrainResult;

  const _LosResultPanel({
    required this.altA,
    required this.altB,
    required this.distanceMeters,
    this.terrainResult,
  });

  @override
  Widget build(BuildContext context) {
    final basicResult = evaluateLos(
      altA: altA,
      altB: altB,
      distanceMeters: distanceMeters,
    );

    // Use terrain-based verdict when terrain data is available and has
    // altitude information; otherwise fall back to earth-bulge-only.
    final terrain = terrainResult;
    final useTerrain = terrain != null && terrain.hasAltitudeData;
    final verdict = useTerrain ? terrain.verdict : basicResult.verdict;

    Color verdictColor;
    IconData verdictIcon;
    switch (verdict) {
      case LosVerdict.clear:
        verdictColor = AppTheme.successGreen;
        verdictIcon = Icons.check_circle;
      case LosVerdict.marginal:
        verdictColor = AppTheme.warningYellow;
        verdictIcon = Icons.warning;
      case LosVerdict.obstructed:
        verdictColor = AppTheme.errorRed;
        verdictIcon = Icons.cancel;
      case LosVerdict.unknown:
        verdictColor = context.textTertiary;
        verdictIcon = Icons.help_outline;
    }

    // Explanation text: terrain-aware when available, earth-bulge-only otherwise
    final explanationText = useTerrain
        ? switch (verdict) {
            LosVerdict.unknown => context.l10n.losExplanationNoAltitude,
            LosVerdict.obstructed =>
              context.l10n.terrainLosExplanationObstructed(
                (-terrain.worstClearanceMeters!).toStringAsFixed(0),
              ),
            LosVerdict.marginal => context.l10n.terrainLosExplanationMarginal,
            LosVerdict.clear => context.l10n.terrainLosExplanationClear,
          }
        : switch (basicResult.verdict) {
            LosVerdict.unknown => context.l10n.losExplanationNoAltitude,
            LosVerdict.obstructed => context.l10n.losExplanationObstructed(
              (-basicResult.actualClearanceMeters).toStringAsFixed(0),
            ),
            LosVerdict.clear => context.l10n.losExplanationClear(
              basicResult.actualClearanceMeters.toStringAsFixed(0),
            ),
            LosVerdict.marginal => context.l10n.losExplanationMarginal(
              basicResult.actualClearanceMeters.toStringAsFixed(0),
              basicResult.requiredClearanceMeters.toStringAsFixed(0),
            ),
          };

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing8),
      decoration: BoxDecoration(
        color: verdictColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(verdictIcon, size: 16, color: verdictColor),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                context.l10n.mapLosVerdict(switch (verdict) {
                  LosVerdict.clear => context.l10n.losVerdictClear,
                  LosVerdict.marginal => context.l10n.losVerdictMarginal,
                  LosVerdict.obstructed => context.l10n.losVerdictObstructed,
                  LosVerdict.unknown => context.l10n.losVerdictUnknown,
                }),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: verdictColor,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.mapLosBulgeAndFresnel(
                  basicResult.earthBulgeMeters.toStringAsFixed(1),
                  basicResult.fresnelRadiusMeters.toStringAsFixed(1),
                ),
                style: TextStyle(fontSize: 11, color: context.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            explanationText,
            style: TextStyle(fontSize: 11, color: context.textSecondary),
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
                  const SizedBox(width: AppTheme.spacing4),
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
                borderRadius: BorderRadius.circular(AppTheme.radius1),
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
              const SizedBox(width: AppTheme.spacing10),
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
                    const SizedBox(height: AppTheme.spacing2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isStale
                                ? context.textTertiary
                                : AppTheme.successGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          isStale
                              ? context.l10n.mapTakStale
                              : context.l10n.mapTakActive,
                          style: TextStyle(
                            fontSize: 11,
                            color: isStale
                                ? context.textTertiary
                                : AppTheme.successGreen,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: affiliationColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius3,
                            ),
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
              const SizedBox(width: AppTheme.spacing4),
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
  final VoidCallback? onNavigateTo;

  const _TakEntityInfoCard({
    required this.event,
    required this.isTracked,
    required this.onClose,
    required this.onCopyCoordinates,
    required this.onTapDetail,
    required this.onToggleTracking,
    this.onNavigateTo,
  });

  @override
  Widget build(BuildContext context) {
    final affiliation = parseAffiliation(event.type);
    final affiliationColor = affiliation.color;
    final isStale = event.isStale;
    final age = _formatAge(event.receivedUtcMs, context.l10n);

    return GestureDetector(
      onTap: onTapDetail,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
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
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
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
            const SizedBox(width: AppTheme.spacing12),
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
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    '${event.typeDescription}  \u2022  '
                    '${event.lat.toStringAsFixed(4)}, '
                    '${event.lon.toStringAsFixed(4)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: affiliationColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radius6),
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
                      const SizedBox(width: AppTheme.spacing8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (isStale
                                      ? AppTheme.errorRed
                                      : AppTheme.successGreen)
                                  .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppTheme.radius6),
                        ),
                        child: Text(
                          isStale
                              ? context.l10n.mapTakStaleBadge
                              : context.l10n.mapTakActiveBadge,
                          style: TextStyle(
                            fontSize: 10,
                            color: isStale
                                ? AppTheme.errorRed
                                : AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
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
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          isTracked
                              ? context.l10n.mapTakTracked
                              : context.l10n.mapTakTrack,
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
                const SizedBox(height: AppTheme.spacing4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.navigation_outlined, size: 16),
                      color: context.textSecondary,
                      onPressed: onNavigateTo,
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.mapNavigateToTooltip,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, size: 16),
                      color: context.textSecondary,
                      onPressed: onCopyCoordinates,
                      visualDensity: VisualDensity.compact,
                      tooltip: context.l10n.mapCopyCoordinatesTooltip,
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
                      tooltip: context.l10n.mapDismissTooltip,
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
            const SizedBox(width: AppTheme.spacing4),
            Icon(Icons.chevron_right, size: 20, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  static String _formatAge(int receivedUtcMs, AppLocalizations l10n) {
    final age = DateTime.now().millisecondsSinceEpoch - receivedUtcMs;
    if (age < 60000) return l10n.mapAgeSeconds('${(age / 1000).round()}');
    if (age < 3600000) return l10n.mapAgeMinutes('${(age / 60000).round()}');
    return l10n.mapAgeHours('${(age / 3600000).round()}');
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

// ---------------------------------------------------------------------------
// Isolated TAK trail overlay — ConsumerWidget so it only rebuilds when
// trail data changes.
// ---------------------------------------------------------------------------

class _TakTrailOverlay extends ConsumerWidget {
  const _TakTrailOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trailData = ref.watch(takTrailDataProvider);
    return trailData.when(
      data: (trails) => TakTrailLayer(trails: trails),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
