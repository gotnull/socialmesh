import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import 'ar_models.dart';
import 'ar_service.dart';

/// Provider for the AR service instance
final arServiceProvider = Provider<ARService>((ref) {
  final service = ARService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for device orientation stream
final arOrientationProvider = StreamProvider<ARDeviceOrientation>((ref) {
  final service = ref.watch(arServiceProvider);
  return service.orientationStream;
});

/// Provider for user position stream
final arPositionProvider = StreamProvider<Position>((ref) {
  final service = ref.watch(arServiceProvider);
  return service.positionStream;
});

/// Provider for AR permission status
final arPermissionProvider = FutureProvider<ARPermissionStatus>((ref) async {
  return ARService.checkPermissions();
});

/// State for the AR view
class ARViewState {
  final bool isActive;
  final List<ARNode> arNodes;
  final ARDeviceOrientation orientation;
  final Position? userPosition;
  final MeshNode? selectedNode;
  final ARConfig config;
  final String? errorMessage;

  const ARViewState({
    this.isActive = false,
    this.arNodes = const [],
    this.orientation = ARDeviceOrientation.zero,
    this.userPosition,
    this.selectedNode,
    this.config = const ARConfig(),
    this.errorMessage,
  });

  ARViewState copyWith({
    bool? isActive,
    List<ARNode>? arNodes,
    ARDeviceOrientation? orientation,
    Position? userPosition,
    MeshNode? selectedNode,
    ARConfig? config,
    String? errorMessage,
  }) {
    return ARViewState(
      isActive: isActive ?? this.isActive,
      arNodes: arNodes ?? this.arNodes,
      orientation: orientation ?? this.orientation,
      userPosition: userPosition ?? this.userPosition,
      selectedNode: selectedNode ?? this.selectedNode,
      config: config ?? this.config,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Notifier for AR view state
class ARViewNotifier extends Notifier<ARViewState> {
  StreamSubscription<ARDeviceOrientation>? _orientationSub;
  StreamSubscription<Position>? _positionSub;

  @override
  ARViewState build() {
    ref.onDispose(() {
      _orientationSub?.cancel();
      _positionSub?.cancel();
    });
    return const ARViewState();
  }

  /// Start the AR view
  Future<void> start() async {
    if (state.isActive) return;

    final service = ref.read(arServiceProvider);

    try {
      // Request permissions
      final hasPermission = await ARService.requestPermissions();
      if (!hasPermission) {
        state = state.copyWith(
          errorMessage: 'Location permission required for AR view',
        );
        return;
      }

      // Start sensors
      await service.start();

      // Subscribe to orientation updates
      _orientationSub = service.orientationStream.listen((orientation) {
        state = state.copyWith(orientation: orientation);
        _updateARNodes();
      });

      // Subscribe to position updates
      _positionSub = service.positionStream.listen((position) {
        state = state.copyWith(userPosition: position);
        _updateARNodes();
      });

      state = state.copyWith(
        isActive: true,
        userPosition: service.userPosition,
        errorMessage: null,
      );

      // Initial AR node calculation
      _updateARNodes();
    } catch (e) {
      state = state.copyWith(
        isActive: false,
        errorMessage: 'Failed to start AR: $e',
      );
    }
  }

  /// Stop the AR view
  void stop() {
    final service = ref.read(arServiceProvider);
    service.stop();

    _orientationSub?.cancel();
    _positionSub?.cancel();
    _orientationSub = null;
    _positionSub = null;

    state = state.copyWith(isActive: false);
  }

  /// Update AR nodes based on current mesh nodes and position
  void _updateARNodes() {
    final service = ref.read(arServiceProvider);
    final nodesNotifier = ref.read(nodesProvider);
    final nodes = nodesNotifier.values.toList();

    final arNodes = service.calculateARNodes(nodes);

    // Filter by max distance
    final filteredNodes = arNodes
        .where((n) => n.distance <= state.config.maxDisplayDistance)
        .toList();

    state = state.copyWith(arNodes: filteredNodes);
  }

  /// Select a node
  void selectNode(MeshNode? node) {
    state = state.copyWith(selectedNode: node);
  }

  /// Update AR config
  void updateConfig(ARConfig config) {
    state = state.copyWith(config: config);
    _updateARNodes();
  }

  /// Toggle distance labels
  void toggleDistanceLabels() {
    state = state.copyWith(
      config: ARConfig(
        horizontalFov: state.config.horizontalFov,
        verticalFov: state.config.verticalFov,
        maxDisplayDistance: state.config.maxDisplayDistance,
        showOffscreenIndicators: state.config.showOffscreenIndicators,
        showDistanceLabels: !state.config.showDistanceLabels,
        showSignalStrength: state.config.showSignalStrength,
        sortMode: state.config.sortMode,
      ),
    );
  }

  /// Toggle signal strength display
  void toggleSignalStrength() {
    state = state.copyWith(
      config: ARConfig(
        horizontalFov: state.config.horizontalFov,
        verticalFov: state.config.verticalFov,
        maxDisplayDistance: state.config.maxDisplayDistance,
        showOffscreenIndicators: state.config.showOffscreenIndicators,
        showDistanceLabels: state.config.showDistanceLabels,
        showSignalStrength: !state.config.showSignalStrength,
        sortMode: state.config.sortMode,
      ),
    );
  }

  /// Set max display distance
  void setMaxDistance(double distance) {
    state = state.copyWith(
      config: ARConfig(
        horizontalFov: state.config.horizontalFov,
        verticalFov: state.config.verticalFov,
        maxDisplayDistance: distance,
        showOffscreenIndicators: state.config.showOffscreenIndicators,
        showDistanceLabels: state.config.showDistanceLabels,
        showSignalStrength: state.config.showSignalStrength,
        sortMode: state.config.sortMode,
      ),
    );
    _updateARNodes();
  }
}

/// Provider for AR view state
final arViewProvider = NotifierProvider<ARViewNotifier, ARViewState>(
  ARViewNotifier.new,
);

/// Provider for filtered AR nodes based on sort mode
final sortedARNodesProvider = Provider<List<ARNode>>((ref) {
  final arState = ref.watch(arViewProvider);

  final nodes = List<ARNode>.from(arState.arNodes);

  switch (arState.config.sortMode) {
    case ARSortMode.distance:
      nodes.sort((a, b) => a.distance.compareTo(b.distance));
    case ARSortMode.signalStrength:
      nodes.sort((a, b) => b.signalQuality.compareTo(a.signalQuality));
    case ARSortMode.name:
      nodes.sort((a, b) {
        final aName = a.node.longName ?? a.node.shortName ?? '';
        final bName = b.node.longName ?? b.node.shortName ?? '';
        return aName.compareTo(bName);
      });
    case ARSortMode.lastHeard:
      nodes.sort((a, b) {
        final aTime = a.node.lastHeard?.millisecondsSinceEpoch ?? 0;
        final bTime = b.node.lastHeard?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime); // Most recent first
      });
  }

  return nodes;
});

/// Provider for nodes that are in the camera view
final visibleARNodesProvider = Provider<List<ARNode>>((ref) {
  final arState = ref.watch(arViewProvider);
  return arState.arNodes.where((n) {
    final pos = n.toScreenPosition(
      deviceHeading: arState.orientation.heading,
      devicePitch: arState.orientation.pitch,
      deviceRoll: arState.orientation.roll,
      fovHorizontal: arState.config.horizontalFov,
      fovVertical: arState.config.verticalFov,
      screenWidth: 400, // Will be overridden in UI
      screenHeight: 800,
    );
    return pos?.isInView ?? false;
  }).toList();
});

/// Provider for AR statistics
final arStatsProvider = Provider<ARStats>((ref) {
  final arState = ref.watch(arViewProvider);

  if (arState.arNodes.isEmpty) {
    return const ARStats.empty();
  }

  final nodes = arState.arNodes;
  final distances = nodes.map((n) => n.distance).toList();
  final nearest = distances.reduce((a, b) => a < b ? a : b);
  final farthest = distances.reduce((a, b) => a > b ? a : b);
  final avgDistance = distances.reduce((a, b) => a + b) / distances.length;

  return ARStats(
    totalNodes: nodes.length,
    nearestDistance: nearest,
    farthestDistance: farthest,
    averageDistance: avgDistance,
  );
});

class ARStats {
  final int totalNodes;
  final double nearestDistance;
  final double farthestDistance;
  final double averageDistance;

  const ARStats({
    required this.totalNodes,
    required this.nearestDistance,
    required this.farthestDistance,
    required this.averageDistance,
  });

  const ARStats.empty()
    : totalNodes = 0,
      nearestDistance = 0,
      farthestDistance = 0,
      averageDistance = 0;
}
