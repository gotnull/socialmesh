import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import 'ar_calibration.dart';
import 'ar_engine.dart';
import 'ar_hud_painter.dart';

// ═══════════════════════════════════════════════════════════════════════════
// AR ENGINE PROVIDER
// ═══════════════════════════════════════════════════════════════════════════

/// Global AR engine instance - lazy initialized
final arEngineProvider = Provider<AREngine>((ref) {
  final engine = AREngine();
  ref.onDispose(() {
    engine.dispose();
  });
  return engine;
});

// ═══════════════════════════════════════════════════════════════════════════
// AR VIEW MODES - DISTINCT CONFIGURATIONS
// ═══════════════════════════════════════════════════════════════════════════

/// View modes with truly distinct visual styles and features
enum ARViewMode {
  /// Full tactical HUD with all features:
  /// - Complete compass with heading tape
  /// - Horizon line with pitch ladder
  /// - Altimeter scale
  /// - Full node information with trails
  /// - Alert system active
  /// - Distance rings on radar
  tactical,

  /// Explorer mode for outdoor navigation:
  /// - Simplified compass (card only)
  /// - No horizon/pitch display
  /// - Larger node markers with names
  /// - Color-coded signal strength
  /// - Trail breadcrumbs for moving nodes
  /// - POI-style markers
  explorer,

  /// Minimal distraction-free mode:
  /// - No compass (heading in corner only)
  /// - No horizon/altimeter
  /// - Simple dot markers
  /// - Distance only (no names)
  /// - No alerts
  /// - Translucent overlay
  minimal,
}

extension ARViewModeExtension on ARViewMode {
  String get displayName => switch (this) {
    ARViewMode.tactical => 'Tactical',
    ARViewMode.explorer => 'Explorer',
    ARViewMode.minimal => 'Minimal',
  };

  String get description => switch (this) {
    ARViewMode.tactical => 'Full HUD with compass, horizon, and detailed info',
    ARViewMode.explorer => 'Navigation-focused with large markers and trails',
    ARViewMode.minimal => 'Clean view with simple markers only',
  };

  String get iconName => switch (this) {
    ARViewMode.tactical => 'grid_view',
    ARViewMode.explorer => 'explore',
    ARViewMode.minimal => 'radio_button_unchecked',
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// AR STATE
// ═══════════════════════════════════════════════════════════════════════════

class ARState {
  final bool isRunning;
  final bool isInitializing;
  final String? error;
  final AROrientation orientation;
  final ARPosition? position;
  final List<ARWorldNode> nodes;
  final List<ARNodeCluster> clusters;
  final List<ARAlert> alerts;
  final ARWorldNode? selectedNode;
  final ARViewMode viewMode;
  final ARHudConfig hudConfig;
  final AREngineConfig engineConfig;
  final double animationValue;

  // Calibration state
  final ARCalibrationState calibration;

  // Filtering
  final double maxDistance;
  final bool showOfflineNodes;
  final bool showOnlyFavorites;
  final Set<int> favoriteNodeNums;

  // Visual options
  final bool showTrails;
  final bool showSignalStrength;

  ARState({
    this.isRunning = false,
    this.isInitializing = false,
    this.error,
    AROrientation? orientation,
    this.position,
    this.nodes = const [],
    this.clusters = const [],
    this.alerts = const [],
    this.selectedNode,
    this.viewMode = ARViewMode.tactical,
    this.hudConfig = ARHudConfig.tactical,
    this.engineConfig = const AREngineConfig(),
    this.animationValue = 0,
    this.calibration = const ARCalibrationState(),
    this.maxDistance = 50000,
    this.showOfflineNodes = true,
    this.showOnlyFavorites = false,
    this.favoriteNodeNums = const {},
    this.showTrails = true,
    this.showSignalStrength = true,
  }) : orientation = orientation ?? AROrientation.initial();

  factory ARState.initial() => ARState();

  ARState copyWith({
    bool? isRunning,
    bool? isInitializing,
    String? error,
    bool clearError = false,
    AROrientation? orientation,
    ARPosition? position,
    List<ARWorldNode>? nodes,
    List<ARNodeCluster>? clusters,
    List<ARAlert>? alerts,
    ARWorldNode? selectedNode,
    bool clearSelectedNode = false,
    ARViewMode? viewMode,
    ARHudConfig? hudConfig,
    AREngineConfig? engineConfig,
    double? animationValue,
    ARCalibrationState? calibration,
    double? maxDistance,
    bool? showOfflineNodes,
    bool? showOnlyFavorites,
    Set<int>? favoriteNodeNums,
    bool? showTrails,
    bool? showSignalStrength,
  }) {
    return ARState(
      isRunning: isRunning ?? this.isRunning,
      isInitializing: isInitializing ?? this.isInitializing,
      error: clearError ? null : (error ?? this.error),
      orientation: orientation ?? this.orientation,
      position: position ?? this.position,
      nodes: nodes ?? this.nodes,
      clusters: clusters ?? this.clusters,
      alerts: alerts ?? this.alerts,
      selectedNode: clearSelectedNode
          ? null
          : (selectedNode ?? this.selectedNode),
      viewMode: viewMode ?? this.viewMode,
      hudConfig: hudConfig ?? this.hudConfig,
      engineConfig: engineConfig ?? this.engineConfig,
      animationValue: animationValue ?? this.animationValue,
      calibration: calibration ?? this.calibration,
      maxDistance: maxDistance ?? this.maxDistance,
      showOfflineNodes: showOfflineNodes ?? this.showOfflineNodes,
      showOnlyFavorites: showOnlyFavorites ?? this.showOnlyFavorites,
      favoriteNodeNums: favoriteNodeNums ?? this.favoriteNodeNums,
      showTrails: showTrails ?? this.showTrails,
      showSignalStrength: showSignalStrength ?? this.showSignalStrength,
    );
  }

  /// Get visible node count
  int get visibleNodeCount =>
      nodes.where((n) => n.screenPosition.isInView).length;

  /// Get nearest node
  ARWorldNode? get nearestNode => nodes.isNotEmpty ? nodes.first : null;

  /// Get alerts by severity
  List<ARAlert> get criticalAlerts =>
      alerts.where((a) => a.severity == ARAlertSeverity.critical).toList();
  List<ARAlert> get warningAlerts =>
      alerts.where((a) => a.severity == ARAlertSeverity.warning).toList();

  /// Check if calibration is needed
  bool get needsCalibration =>
      calibration.needsCompassCalibration ||
      calibration.compassStatus == CalibrationStatus.unknown ||
      calibration.compassStatus == CalibrationStatus.poor;
}

// ═══════════════════════════════════════════════════════════════════════════
// AR NOTIFIER
// ═══════════════════════════════════════════════════════════════════════════

class ARNotifier extends Notifier<ARState> {
  AREngine? _engine;
  StreamSubscription<AROrientation>? _orientationSub;
  StreamSubscription<ARPosition>? _positionSub;
  StreamSubscription<List<ARWorldNode>>? _nodesSub;
  StreamSubscription<List<ARNodeCluster>>? _clustersSub;
  StreamSubscription<List<ARAlert>>? _alertsSub;
  StreamSubscription<ARCalibrationState>? _calibrationSub;
  Timer? _animationTimer;
  Timer? _processTimer;

  @override
  ARState build() => ARState.initial();

  /// Start AR mode
  Future<void> start() async {
    if (state.isRunning || state.isInitializing) return;

    state = state.copyWith(isInitializing: true, clearError: true);

    try {
      _engine = ref.read(arEngineProvider);
      await _engine!.start();

      // Subscribe to calibration state updates
      _calibrationSub = _engine!.calibrationStream.listen((calibration) {
        if (state.isRunning || state.isInitializing) {
          state = state.copyWith(calibration: calibration);
        }
      });

      // Subscribe to streams
      _orientationSub = _engine!.orientationStream.listen((orientation) {
        if (state.isRunning) {
          state = state.copyWith(orientation: orientation);
        }
      });

      _positionSub = _engine!.positionStream.listen((position) {
        if (state.isRunning) {
          state = state.copyWith(position: position);
        }
      });

      _nodesSub = _engine!.nodesStream.listen((nodes) {
        if (state.isRunning) {
          state = state.copyWith(nodes: nodes);
        }
      });

      _clustersSub = _engine!.clustersStream.listen((clusters) {
        if (state.isRunning) {
          state = state.copyWith(clusters: clusters);
        }
      });

      _alertsSub = _engine!.alertsStream.listen((alerts) {
        if (state.isRunning) {
          state = state.copyWith(alerts: alerts);
        }
      });

      // Start animation loop
      _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (state.isRunning) {
          var anim = state.animationValue + 0.02;
          if (anim >= 1.0) anim = 0.0;
          state = state.copyWith(animationValue: anim);
        }
      });

      // Start node processing loop
      _processTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        _processNodes();
      });

      state = state.copyWith(isRunning: true, isInitializing: false);
    } catch (e) {
      state = state.copyWith(
        isInitializing: false,
        error: 'Failed to start AR: $e',
      );
    }
  }

  /// Stop AR mode
  void stop() {
    _orientationSub?.cancel();
    _positionSub?.cancel();
    _nodesSub?.cancel();
    _clustersSub?.cancel();
    _alertsSub?.cancel();
    _calibrationSub?.cancel();
    _animationTimer?.cancel();
    _processTimer?.cancel();

    _orientationSub = null;
    _positionSub = null;
    _nodesSub = null;
    _clustersSub = null;
    _alertsSub = null;
    _calibrationSub = null;
    _animationTimer = null;
    _processTimer = null;

    _engine?.stop();
    _engine = null;

    state = state.copyWith(isRunning: false);
  }

  /// Process mesh nodes into AR nodes
  void _processNodes() {
    if (!state.isRunning || _engine == null) return;

    // Get mesh nodes from provider
    final meshNodes = ref.read(nodesProvider).values.toList();

    // Filter nodes based on settings
    var filteredNodes = meshNodes.where((node) {
      // Must have position
      if (node.latitude == null ||
          node.longitude == null ||
          node.latitude == 0 ||
          node.longitude == 0) {
        return false;
      }

      // Filter offline nodes
      if (!state.showOfflineNodes && node.lastHeard != null) {
        final age = DateTime.now().difference(node.lastHeard!);
        if (age.inHours > 1) return false;
      }

      // Filter favorites
      if (state.showOnlyFavorites &&
          !state.favoriteNodeNums.contains(node.nodeNum)) {
        return false;
      }

      return true;
    }).toList();

    // Process with engine
    final config = state.engineConfig.copyWith(maxDistance: state.maxDistance);

    _engine!.processNodes(filteredNodes, config: config);
  }

  /// Select a node
  void selectNode(ARWorldNode? node) {
    if (node == null) {
      state = state.copyWith(clearSelectedNode: true);
    } else {
      state = state.copyWith(selectedNode: node);
    }
  }

  /// Select node by screen tap
  void selectNodeAt(
    double x,
    double y,
    double screenWidth,
    double screenHeight,
  ) {
    const tapRadius = 50.0;

    for (final node in state.nodes) {
      if (!node.screenPosition.isInView) continue;

      final pos = node.screenPosition.toPixels(screenWidth, screenHeight);
      final dx = pos.dx - x;
      final dy = pos.dy - y;
      final dist = (dx * dx + dy * dy);

      if (dist < tapRadius * tapRadius) {
        selectNode(node);
        return;
      }
    }

    // Check clusters
    for (final cluster in state.clusters) {
      if (!cluster.screenPosition.isInView) continue;

      final pos = cluster.screenPosition.toPixels(screenWidth, screenHeight);
      final dx = pos.dx - x;
      final dy = pos.dy - y;
      final dist = (dx * dx + dy * dy);

      if (dist < 60 * 60) {
        // Expand cluster - select first node
        if (cluster.nodes.isNotEmpty) {
          selectNode(cluster.nodes.first);
        }
        return;
      }
    }

    // Clear selection
    selectNode(null);
  }

  /// Set view mode
  void setViewMode(ARViewMode mode) {
    final hudConfig = switch (mode) {
      ARViewMode.tactical => ARHudConfig.tactical,
      ARViewMode.explorer => ARHudConfig.explorer,
      ARViewMode.minimal => ARHudConfig.minimal,
    };

    state = state.copyWith(viewMode: mode, hudConfig: hudConfig);
  }

  /// Toggle HUD element
  void toggleHudElement(String element) {
    final config = state.hudConfig;
    final newConfig = switch (element) {
      'horizon' => config.copyWith(showHorizon: !config.showHorizon),
      'compass' => config.copyWith(showCompass: !config.showCompass),
      'altimeter' => config.copyWith(showAltimeter: !config.showAltimeter),
      'alerts' => config.copyWith(showAlerts: !config.showAlerts),
      _ => config,
    };

    state = state.copyWith(hudConfig: newConfig);
  }

  /// Set max distance filter
  void setMaxDistance(double distance) {
    state = state.copyWith(maxDistance: distance);
  }

  /// Toggle offline nodes visibility
  void toggleOfflineNodes() {
    state = state.copyWith(showOfflineNodes: !state.showOfflineNodes);
  }

  /// Toggle favorites only
  void toggleFavoritesOnly() {
    state = state.copyWith(showOnlyFavorites: !state.showOnlyFavorites);
  }

  /// Add node to favorites
  void addFavorite(int nodeNum) {
    final favorites = Set<int>.from(state.favoriteNodeNums)..add(nodeNum);
    state = state.copyWith(favoriteNodeNums: favorites);
  }

  /// Remove node from favorites
  void removeFavorite(int nodeNum) {
    final favorites = Set<int>.from(state.favoriteNodeNums)..remove(nodeNum);
    state = state.copyWith(favoriteNodeNums: favorites);
  }

  /// Clear all alerts
  void clearAlerts() {
    state = state.copyWith(alerts: []);
  }

  /// Dismiss specific alert
  void dismissAlert(ARAlert alert) {
    final alerts = state.alerts.where((a) => a != alert).toList();
    state = state.copyWith(alerts: alerts);
  }

  /// Start compass calibration
  void startCompassCalibration() {
    _engine?.startCompassCalibration();
  }

  /// Cancel compass calibration
  void cancelCompassCalibration() {
    _engine?.cancelCompassCalibration();
  }

  /// Toggle visual trails
  void toggleTrails() {
    state = state.copyWith(showTrails: !state.showTrails);
  }

  /// Toggle signal strength indicators
  void toggleSignalStrength() {
    state = state.copyWith(showSignalStrength: !state.showSignalStrength);
  }
}

/// AR state notifier provider
final arStateProvider = NotifierProvider<ARNotifier, ARState>(ARNotifier.new);

// ═══════════════════════════════════════════════════════════════════════════
// DERIVED PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for visible nodes only
final visibleARNodesProvider = Provider<List<ARWorldNode>>((ref) {
  final state = ref.watch(arStateProvider);
  return state.nodes.where((n) => n.screenPosition.isInView).toList();
});

/// Provider for off-screen nodes only
final offscreenARNodesProvider = Provider<List<ARWorldNode>>((ref) {
  final state = ref.watch(arStateProvider);
  return state.nodes.where((n) => !n.screenPosition.isInView).toList();
});

/// Provider for moving nodes
final movingARNodesProvider = Provider<List<ARWorldNode>>((ref) {
  final state = ref.watch(arStateProvider);
  return state.nodes.where((n) => n.isMoving).toList();
});

/// Provider for new nodes (discovered recently)
final newARNodesProvider = Provider<List<ARWorldNode>>((ref) {
  final state = ref.watch(arStateProvider);
  return state.nodes.where((n) => n.isNew).toList();
});

/// Provider for nodes with warnings
final warningARNodesProvider = Provider<List<ARWorldNode>>((ref) {
  final state = ref.watch(arStateProvider);
  return state.nodes
      .where(
        (n) =>
            n.threatLevel == ARThreatLevel.warning ||
            n.threatLevel == ARThreatLevel.critical,
      )
      .toList();
});

/// Provider for nearest node
final nearestARNodeProvider = Provider<ARWorldNode?>((ref) {
  final state = ref.watch(arStateProvider);
  return state.nearestNode;
});

/// Provider for AR statistics
final arStatsProvider = Provider<ARStats>((ref) {
  final state = ref.watch(arStateProvider);

  return ARStats(
    totalNodes: state.nodes.length,
    visibleNodes: state.visibleNodeCount,
    clusters: state.clusters.length,
    movingNodes: state.nodes.where((n) => n.isMoving).length,
    newNodes: state.nodes.where((n) => n.isNew).length,
    warningNodes: state.nodes
        .where(
          (n) =>
              n.threatLevel == ARThreatLevel.warning ||
              n.threatLevel == ARThreatLevel.critical,
        )
        .length,
    nearestDistance: state.nearestNode?.worldPosition.distance,
    alerts: state.alerts.length,
    criticalAlerts: state.criticalAlerts.length,
    orientationAccuracy: state.orientation.accuracy,
    positionAccuracy: state.position?.accuracy,
  );
});

/// AR statistics data class
class ARStats {
  final int totalNodes;
  final int visibleNodes;
  final int clusters;
  final int movingNodes;
  final int newNodes;
  final int warningNodes;
  final double? nearestDistance;
  final int alerts;
  final int criticalAlerts;
  final double orientationAccuracy;
  final double? positionAccuracy;

  const ARStats({
    required this.totalNodes,
    required this.visibleNodes,
    required this.clusters,
    required this.movingNodes,
    required this.newNodes,
    required this.warningNodes,
    this.nearestDistance,
    required this.alerts,
    required this.criticalAlerts,
    required this.orientationAccuracy,
    this.positionAccuracy,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// ENGINE CONFIG EXTENSION
// ═══════════════════════════════════════════════════════════════════════════

extension AREngineConfigCopyWith on AREngineConfig {
  AREngineConfig copyWith({
    double? maxDistance,
    double? horizontalFov,
    double? verticalFov,
    double? clusterRadius,
    bool? enablePrediction,
    bool? enableTracking,
  }) {
    return AREngineConfig(
      maxDistance: maxDistance ?? this.maxDistance,
      horizontalFov: horizontalFov ?? this.horizontalFov,
      verticalFov: verticalFov ?? this.verticalFov,
      clusterRadius: clusterRadius ?? this.clusterRadius,
      enablePrediction: enablePrediction ?? this.enablePrediction,
      enableTracking: enableTracking ?? this.enableTracking,
    );
  }
}
