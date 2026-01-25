import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/world_mesh/services/node_cache_service.dart';
import '../features/world_mesh/world_mesh_filters.dart';
import '../models/world_mesh_node.dart';
import '../models/presence_confidence.dart';
import '../services/world_mesh_map_service.dart';

/// Provider for the WorldMeshMapService
final worldMeshMapServiceProvider = Provider<WorldMeshMapService>((ref) {
  final service = WorldMeshMapService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the NodeCacheService
final nodeCacheServiceProvider = Provider<NodeCacheService>((ref) {
  return NodeCacheService();
});

/// State for the world mesh map
class WorldMeshMapState {
  final Map<int, WorldMeshNode> nodes;
  final bool isLoading;
  final String? error;
  final DateTime? lastUpdated;
  final bool isFromCache;

  // Cached list of nodes with valid positions - computed once per state instance
  late final List<WorldMeshNode> nodesWithPosition = nodes.values
      .where((n) => n.latitude != 0 || n.longitude != 0)
      .toList();

  WorldMeshMapState({
    this.nodes = const {},
    this.isLoading = false,
    this.error,
    this.lastUpdated,
    this.isFromCache = false,
  });

  WorldMeshMapState copyWith({
    Map<int, WorldMeshNode>? nodes,
    bool? isLoading,
    String? error,
    DateTime? lastUpdated,
    bool? isFromCache,
  }) {
    return WorldMeshMapState(
      nodes: nodes ?? this.nodes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  /// Get total node count
  int get nodeCount => nodes.length;
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
    final service = ref.read(worldMeshMapServiceProvider);
    final cacheService = ref.read(nodeCacheServiceProvider);

    try {
      final nodes = await service.fetchNodes();

      // Cache the fetched nodes for offline use
      await cacheService.cacheNodes(nodes.values.toList());

      state = AsyncValue.data(
        WorldMeshMapState(
          nodes: nodes,
          isLoading: false,
          lastUpdated: DateTime.now(),
          isFromCache: false,
        ),
      );
    } catch (e, st) {
      final currentData = state.whenOrNull(data: (d) => d);
      final currentNodes = currentData?.nodes ?? {};

      if (currentNodes.isEmpty) {
        // Try to load from cache
        final cachedNodes = await cacheService.getCachedNodes();
        final cacheTimestamp = await cacheService.getCacheTimestamp();

        if (cachedNodes != null && cachedNodes.isNotEmpty) {
          final nodesMap = {for (final n in cachedNodes) n.nodeNum: n};
          state = AsyncValue.data(
            WorldMeshMapState(
              nodes: nodesMap,
              isLoading: false,
              error: 'Offline mode - using cached data',
              lastUpdated: cacheTimestamp,
              isFromCache: true,
            ),
          );
        } else {
          state = AsyncValue.error(e, st);
        }
      } else {
        // Keep existing data but mark error
        state = AsyncValue.data(
          WorldMeshMapState(
            nodes: currentNodes,
            isLoading: false,
            error: e.toString(),
            lastUpdated: currentData?.lastUpdated,
            isFromCache: currentData?.isFromCache ?? false,
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

/// Provider for filtered/searched nodes (simple text search)
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

/// Provider for filter state
final worldMeshFiltersProvider =
    NotifierProvider<WorldMeshFiltersNotifier, WorldMeshFilters>(
      WorldMeshFiltersNotifier.new,
    );

/// Notifier for filter state
class WorldMeshFiltersNotifier extends Notifier<WorldMeshFilters> {
  @override
  WorldMeshFilters build() => const WorldMeshFilters();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void toggleStatus(PresenceConfidence status) {
    final newSet = Set<PresenceConfidence>.from(state.statusFilter);
    if (newSet.contains(status)) {
      newSet.remove(status);
    } else {
      newSet.add(status);
    }
    state = state.copyWith(statusFilter: newSet);
  }

  void toggleHardware(String hardware) {
    final newSet = Set<String>.from(state.hardwareFilter);
    if (newSet.contains(hardware)) {
      newSet.remove(hardware);
    } else {
      newSet.add(hardware);
    }
    state = state.copyWith(hardwareFilter: newSet);
  }

  void toggleModemPreset(String preset) {
    final newSet = Set<String>.from(state.modemPresetFilter);
    if (newSet.contains(preset)) {
      newSet.remove(preset);
    } else {
      newSet.add(preset);
    }
    state = state.copyWith(modemPresetFilter: newSet);
  }

  void toggleRegion(String region) {
    final newSet = Set<String>.from(state.regionFilter);
    if (newSet.contains(region)) {
      newSet.remove(region);
    } else {
      newSet.add(region);
    }
    state = state.copyWith(regionFilter: newSet);
  }

  void toggleRole(String role) {
    final newSet = Set<String>.from(state.roleFilter);
    if (newSet.contains(role)) {
      newSet.remove(role);
    } else {
      newSet.add(role);
    }
    state = state.copyWith(roleFilter: newSet);
  }

  void toggleFirmware(String firmware) {
    final newSet = Set<String>.from(state.firmwareFilter);
    if (newSet.contains(firmware)) {
      newSet.remove(firmware);
    } else {
      newSet.add(firmware);
    }
    state = state.copyWith(firmwareFilter: newSet);
  }

  void setHasEnvironmentSensors(bool? value) {
    if (value == null) {
      state = state.copyWith(clearHasEnvironmentSensors: true);
    } else {
      state = state.copyWith(hasEnvironmentSensors: value);
    }
  }

  void setHasBattery(bool? value) {
    if (value == null) {
      state = state.copyWith(clearHasBattery: true);
    } else {
      state = state.copyWith(hasBattery: value);
    }
  }

  void clearAllFilters() {
    state = state.clear();
  }

  void clearCategory(WorldMeshFilterCategory category) {
    switch (category) {
      case WorldMeshFilterCategory.status:
        state = state.copyWith(statusFilter: {});
      case WorldMeshFilterCategory.hardware:
        state = state.copyWith(hardwareFilter: {});
      case WorldMeshFilterCategory.modemPreset:
        state = state.copyWith(modemPresetFilter: {});
      case WorldMeshFilterCategory.region:
        state = state.copyWith(regionFilter: {});
      case WorldMeshFilterCategory.role:
        state = state.copyWith(roleFilter: {});
      case WorldMeshFilterCategory.firmware:
        state = state.copyWith(firmwareFilter: {});
      case WorldMeshFilterCategory.hasEnvironmentSensors:
        state = state.copyWith(clearHasEnvironmentSensors: true);
      case WorldMeshFilterCategory.hasBattery:
        state = state.copyWith(clearHasBattery: true);
    }
  }
}

/// Provider for filter options extracted from nodes
final worldMeshFilterOptionsProvider = Provider<WorldMeshFilterOptions>((ref) {
  final nodes = ref.watch(worldMeshNodesWithPositionProvider);
  return WorldMeshFilterOptions.fromNodes(nodes);
});

/// Provider for filtered nodes (with all filters applied)
final worldMeshAdvancedFilteredNodesProvider = Provider<List<WorldMeshNode>>((
  ref,
) {
  final nodes = ref.watch(worldMeshNodesWithPositionProvider);
  final filters = ref.watch(worldMeshFiltersProvider);
  return filters.apply(nodes);
});
