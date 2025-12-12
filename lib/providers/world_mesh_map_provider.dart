import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/world_mesh_node.dart';
import '../services/world_mesh_map_service.dart';

/// Provider for the WorldMeshMapService
final worldMeshMapServiceProvider = Provider<WorldMeshMapService>((ref) {
  final service = WorldMeshMapService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// State for the world mesh map
class WorldMeshMapState {
  final Map<int, WorldMeshNode> nodes;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;

  const WorldMeshMapState({
    this.nodes = const {},
    this.isLoading = false,
    this.error,
    this.lastUpdated,
  });

  WorldMeshMapState copyWith({
    Map<int, WorldMeshNode>? nodes,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
  }) {
    return WorldMeshMapState(
      nodes: nodes ?? this.nodes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  /// Get total node count
  int get nodeCount => nodes.length;

  /// Get nodes with valid positions
  List<WorldMeshNode> get nodesWithPosition {
    return nodes.values
        .where((n) => n.latitude != 0 || n.longitude != 0)
        .toList();
  }
}

/// Notifier for world mesh map state
class WorldMeshMapNotifier extends Notifier<AsyncValue<WorldMeshMapState>> {
  Timer? _refreshTimer;
  static const _refreshInterval = Duration(minutes: 2);

  @override
  AsyncValue<WorldMeshMapState> build() {
    // Cancel timer on dispose
    ref.onDispose(() {
      _refreshTimer?.cancel();
    });

    // Start periodic refresh
    _startPeriodicRefresh();

    // Initial fetch
    _fetchNodes();
    return const AsyncValue.loading();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      refresh();
    });
  }

  Future<void> _fetchNodes() async {
    try {
      final service = ref.read(worldMeshMapServiceProvider);
      final nodes = await service.fetchNodes();
      state = AsyncValue.data(
        WorldMeshMapState(
          nodes: nodes,
          isLoading: false,
          lastUpdated: DateTime.now(),
        ),
      );
    } catch (e, st) {
      final currentData = state.whenOrNull(data: (d) => d);
      final currentNodes = currentData?.nodes ?? {};
      if (currentNodes.isEmpty) {
        state = AsyncValue.error(e, st);
      } else {
        // Keep existing data but mark error
        state = AsyncValue.data(
          WorldMeshMapState(
            nodes: currentNodes,
            isLoading: false,
            error: e.toString(),
            lastUpdated: currentData?.lastUpdated,
          ),
        );
      }
    }
  }

  /// Manually refresh nodes (silent if has data)
  Future<void> refresh() async {
    final currentData = state.whenOrNull(data: (d) => d);
    if (currentData != null && currentData.nodes.isNotEmpty) {
      // Silent refresh - don't show loading
      await _fetchNodes();
    } else {
      state = const AsyncValue.loading();
      await _fetchNodes();
    }
  }

  /// Force refresh (shows loading state)
  Future<void> forceRefresh() async {
    state = const AsyncValue.loading();
    await _fetchNodes();
  }
}

/// Provider for world mesh map state
final worldMeshMapProvider =
    NotifierProvider<WorldMeshMapNotifier, AsyncValue<WorldMeshMapState>>(
      WorldMeshMapNotifier.new,
    );

/// Provider for node count
final worldMeshNodeCountProvider = Provider<int>((ref) {
  return ref.watch(worldMeshMapProvider).whenOrNull(data: (d) => d.nodeCount) ??
      0;
});

/// Provider for nodes with positions only
final worldMeshNodesWithPositionProvider = Provider<List<WorldMeshNode>>((ref) {
  return ref
          .watch(worldMeshMapProvider)
          .whenOrNull(data: (d) => d.nodesWithPosition) ??
      [];
});

/// Provider for filtered/searched nodes
final worldMeshFilteredNodesProvider =
    Provider.family<List<WorldMeshNode>, String>((ref, query) {
      final nodes =
          ref
              .watch(worldMeshMapProvider)
              .whenOrNull(data: (d) => d.nodesWithPosition) ??
          [];
      if (query.isEmpty) return nodes;

      final lowerQuery = query.toLowerCase();
      return nodes.where((node) {
        return node.longName.toLowerCase().contains(lowerQuery) ||
            node.shortName.toLowerCase().contains(lowerQuery) ||
            node.nodeId.toLowerCase().contains(lowerQuery) ||
            (node.hwModel.toLowerCase().contains(lowerQuery));
      }).toList();
    });
