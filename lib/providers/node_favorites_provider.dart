import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/world_mesh/services/node_favorites_service.dart';
import '../models/world_mesh_node.dart';

/// State for node favorites
class NodeFavoritesState {
  final Set<String> favoriteIds;
  final List<FavoriteNodeMetadata> favorites;
  final bool isLoading;

  const NodeFavoritesState({
    this.favoriteIds = const {},
    this.favorites = const [],
    this.isLoading = false,
  });

  NodeFavoritesState copyWith({
    Set<String>? favoriteIds,
    List<FavoriteNodeMetadata>? favorites,
    bool? isLoading,
  }) {
    return NodeFavoritesState(
      favoriteIds: favoriteIds ?? this.favoriteIds,
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool isFavorite(String nodeId) => favoriteIds.contains(nodeId.toUpperCase());

  int get count => favoriteIds.length;
}

/// Provider for managing node favorites with Riverpod
class NodeFavoritesNotifier extends Notifier<NodeFavoritesState> {
  final NodeFavoritesService _service = NodeFavoritesService();

  @override
  NodeFavoritesState build() {
    _loadFavorites();
    return const NodeFavoritesState(isLoading: true);
  }

  Future<void> _loadFavorites() async {
    state = state.copyWith(isLoading: true);

    final ids = await _service.getFavoriteIds();
    final favorites = await _service.getFavorites();

    state = NodeFavoritesState(
      favoriteIds: ids.map((id) => id.toUpperCase()).toSet(),
      favorites: favorites,
      isLoading: false,
    );
  }

  Future<void> refresh() async {
    await _loadFavorites();
  }

  bool isFavorite(int nodeNum) {
    final nodeId = nodeNum.toRadixString(16).padLeft(8, '0').toUpperCase();
    return state.isFavorite(nodeId);
  }

  Future<void> addFavorite(WorldMeshNode node) async {
    await _service.addFavorite(node);
    await _loadFavorites();
  }

  Future<void> removeFavorite(String nodeId) async {
    await _service.removeFavorite(nodeId.toUpperCase());
    await _loadFavorites();
  }

  Future<void> toggleFavorite(WorldMeshNode node) async {
    final nodeId = node.nodeNum.toRadixString(16).padLeft(8, '0').toUpperCase();
    if (state.isFavorite(nodeId)) {
      await removeFavorite(nodeId);
    } else {
      await addFavorite(node);
    }
  }
}

/// Main provider for node favorites
final nodeFavoritesProvider =
    NotifierProvider<NodeFavoritesNotifier, NodeFavoritesState>(
      NodeFavoritesNotifier.new,
    );

/// Convenience provider to check if a specific node is favorited
final isNodeFavoriteProvider = Provider.family<bool, int>((ref, nodeNum) {
  final favorites = ref.watch(nodeFavoritesProvider);
  final nodeId = nodeNum.toRadixString(16).padLeft(8, '0').toUpperCase();
  return favorites.isFavorite(nodeId);
});

/// Provider for favorites count (for badge)
final favoritesCountProvider = Provider<int>((ref) {
  return ref.watch(nodeFavoritesProvider).count;
});
