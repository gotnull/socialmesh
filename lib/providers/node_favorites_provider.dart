// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/logging.dart';

import '../features/world_mesh/services/node_favorites_service.dart';
import '../models/world_mesh_node.dart';

/// State for node favorites (data only, loading/error handled by AsyncValue)
class NodeFavoritesData {
  final Set<String> favoriteIds;
  final List<FavoriteNodeMetadata> favorites;

  const NodeFavoritesData({
    this.favoriteIds = const {},
    this.favorites = const [],
  });

  bool isFavorite(String nodeId) => favoriteIds.contains(nodeId.toUpperCase());

  int get count => favoriteIds.length;
}

/// Provider for managing node favorites with Riverpod AsyncNotifier
/// This is the idiomatic way to handle async initialization in Riverpod
class NodeFavoritesNotifier extends AsyncNotifier<NodeFavoritesData> {
  final NodeFavoritesService _service = NodeFavoritesService();

  @override
  Future<NodeFavoritesData> build() async {
    AppLogging.nodes('[NodeFavorites] build() called - loading favorites');
    return _loadFavorites();
  }

  Future<NodeFavoritesData> _loadFavorites() async {
    AppLogging.nodes('[NodeFavorites] _loadFavorites() entered');

    final ids = await _service.getFavoriteIds();
    AppLogging.nodes('[NodeFavorites] Got ${ids.length} favorite IDs: $ids');

    final favorites = await _service.getFavorites();
    AppLogging.nodes(
      '[NodeFavorites] Got ${favorites.length} favorites with metadata',
    );

    final data = NodeFavoritesData(
      favoriteIds: ids.map((id) => id.toUpperCase()).toSet(),
      favorites: favorites,
    );
    AppLogging.nodes(
      '[NodeFavorites] Load complete: ${data.favoriteIds.length} IDs',
    );
    return data;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadFavorites);
  }

  bool isFavorite(int nodeNum) {
    final nodeId = nodeNum.toRadixString(16).padLeft(8, '0').toUpperCase();
    return state.maybeWhen(
      data: (data) => data.isFavorite(nodeId),
      orElse: () => false,
    );
  }

  Future<void> addFavorite(WorldMeshNode node) async {
    await _service.addFavorite(node);
    state = await AsyncValue.guard(_loadFavorites);
  }

  Future<void> removeFavorite(String nodeId) async {
    await _service.removeFavorite(nodeId.toUpperCase());
    state = await AsyncValue.guard(_loadFavorites);
  }

  Future<void> toggleFavorite(WorldMeshNode node) async {
    final nodeId = node.nodeNum.toRadixString(16).padLeft(8, '0').toUpperCase();
    final isFav = state.maybeWhen(
      data: (data) => data.isFavorite(nodeId),
      orElse: () => false,
    );
    if (isFav) {
      await removeFavorite(nodeId);
    } else {
      await addFavorite(node);
    }
  }
}

/// Main provider for node favorites
final nodeFavoritesProvider =
    AsyncNotifierProvider<NodeFavoritesNotifier, NodeFavoritesData>(
      NodeFavoritesNotifier.new,
    );

/// Convenience provider to check if a specific node is favorited
final isNodeFavoriteProvider = Provider.family<bool, int>((ref, nodeNum) {
  final favorites = ref.watch(nodeFavoritesProvider);
  final nodeId = nodeNum.toRadixString(16).padLeft(8, '0').toUpperCase();
  return favorites.maybeWhen(
    data: (data) => data.isFavorite(nodeId),
    orElse: () => false,
  );
});

/// Provider for favorites count (for badge)
final favoritesCountProvider = Provider<int>((ref) {
  return ref
      .watch(nodeFavoritesProvider)
      .maybeWhen(data: (data) => data.count, orElse: () => 0);
});
