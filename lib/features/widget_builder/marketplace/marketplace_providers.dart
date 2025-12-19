import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_marketplace_service.dart';

/// Provider for the marketplace service instance
final marketplaceServiceProvider = Provider<WidgetMarketplaceService>((ref) {
  return WidgetMarketplaceService();
});

// ============ Favorites ============

/// Key for storing favorites in SharedPreferences
const _favoritesKey = 'widget_marketplace_favorites';

/// Provider for favorite widget IDs
final widgetFavoritesProvider =
    NotifierProvider<WidgetFavoritesNotifier, Set<String>>(
      WidgetFavoritesNotifier.new,
    );

/// Notifier for managing favorite widgets
class WidgetFavoritesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _loadFavorites();
    return {};
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList(_favoritesKey) ?? [];
      state = favorites.toSet();
      debugPrint('[Favorites] Loaded ${state.length} favorites');
    } catch (e) {
      debugPrint('[Favorites] Error loading favorites: $e');
    }
  }

  Future<void> toggleFavorite(String widgetId) async {
    final newState = Set<String>.from(state);
    if (newState.contains(widgetId)) {
      newState.remove(widgetId);
      debugPrint('[Favorites] Removed $widgetId');
    } else {
      newState.add(widgetId);
      debugPrint('[Favorites] Added $widgetId');
    }
    state = newState;
    await _saveFavorites();
  }

  Future<void> addFavorite(String widgetId) async {
    if (!state.contains(widgetId)) {
      state = {...state, widgetId};
      await _saveFavorites();
    }
  }

  Future<void> removeFavorite(String widgetId) async {
    if (state.contains(widgetId)) {
      state = Set<String>.from(state)..remove(widgetId);
      await _saveFavorites();
    }
  }

  bool isFavorite(String widgetId) => state.contains(widgetId);

  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favoritesKey, state.toList());
      debugPrint('[Favorites] Saved ${state.length} favorites');
    } catch (e) {
      debugPrint('[Favorites] Error saving favorites: $e');
    }
  }
}

/// Provider to check if a specific widget is favorited
final isWidgetFavoritedProvider = Provider.family<bool, String>((ref, id) {
  final favorites = ref.watch(widgetFavoritesProvider);
  return favorites.contains(id);
});

/// Provider for favorite widgets count
final widgetFavoritesCountProvider = Provider<int>((ref) {
  return ref.watch(widgetFavoritesProvider).length;
});

/// State for marketplace data
class MarketplaceState {
  final List<MarketplaceWidget> featured;
  final List<MarketplaceWidget> popular;
  final List<MarketplaceWidget> newest;
  final Map<String, List<MarketplaceWidget>> categoryWidgets;
  final bool popularLoaded;
  final bool newestLoaded;
  final String? popularError;
  final String? newestError;

  const MarketplaceState({
    this.featured = const [],
    this.popular = const [],
    this.newest = const [],
    this.categoryWidgets = const {},
    this.popularLoaded = false,
    this.newestLoaded = false,
    this.popularError,
    this.newestError,
  });

  MarketplaceState copyWith({
    List<MarketplaceWidget>? featured,
    List<MarketplaceWidget>? popular,
    List<MarketplaceWidget>? newest,
    Map<String, List<MarketplaceWidget>>? categoryWidgets,
    bool? popularLoaded,
    bool? newestLoaded,
    String? popularError,
    String? newestError,
  }) {
    return MarketplaceState(
      featured: featured ?? this.featured,
      popular: popular ?? this.popular,
      newest: newest ?? this.newest,
      categoryWidgets: categoryWidgets ?? this.categoryWidgets,
      popularLoaded: popularLoaded ?? this.popularLoaded,
      newestLoaded: newestLoaded ?? this.newestLoaded,
      popularError: popularError,
      newestError: newestError,
    );
  }
}

/// AsyncNotifier for marketplace state - auto-loads on build like favorites
class MarketplaceNotifier extends AsyncNotifier<MarketplaceState> {
  WidgetMarketplaceService get _service => ref.read(marketplaceServiceProvider);

  // Loading flags to prevent concurrent requests
  bool _loadingPopular = false;
  bool _loadingNewest = false;
  final Set<String> _loadingCategories = {};

  @override
  Future<MarketplaceState> build() async {
    debugPrint('[Marketplace] build() called - auto-loading featured');
    final featured = await _loadFeatured();
    return MarketplaceState(featured: featured);
  }

  Future<List<MarketplaceWidget>> _loadFeatured() async {
    debugPrint('[Marketplace] _loadFeatured() entered');
    try {
      final featured = await _service.getFeatured();
      debugPrint('[Marketplace] Got ${featured.length} featured widgets');
      return featured;
    } catch (e, st) {
      debugPrint('[Marketplace] Error loading featured: $e');
      debugPrint('[Marketplace] Stack trace: $st');
      // Return empty list instead of crashing - featured is optional
      return [];
    }
  }

  /// Load popular widgets
  Future<void> loadPopular() async {
    final currentState = state.value;
    if (currentState == null) return;

    debugPrint(
      '[Marketplace] loadPopular called, current: ${currentState.popular.length}, loading: $_loadingPopular, loaded: ${currentState.popularLoaded}',
    );
    if (currentState.popularLoaded || _loadingPopular) {
      debugPrint(
        '[Marketplace] Skipping loadPopular - already loaded or loading',
      );
      return;
    }

    _loadingPopular = true;
    try {
      debugPrint('[Marketplace] Loading popular widgets...');
      final response = await _service.getPopular();
      debugPrint(
        '[Marketplace] Got ${response.widgets.length} popular widgets',
      );
      // Re-fetch current state in case it changed during async operation
      final latestState = state.value ?? currentState;
      state = AsyncValue.data(
        latestState.copyWith(
          popular: response.widgets,
          popularLoaded: true,
          popularError: null,
        ),
      );
    } catch (e, st) {
      debugPrint('[Marketplace] Error loading popular: $e');
      debugPrint('[Marketplace] Stack trace: $st');
      final latestState = state.value ?? currentState;
      state = AsyncValue.data(
        latestState.copyWith(popularLoaded: true, popularError: e.toString()),
      );
    } finally {
      _loadingPopular = false;
    }
  }

  /// Load newest widgets
  Future<void> loadNewest() async {
    final currentState = state.value;
    if (currentState == null) return;

    debugPrint(
      '[Marketplace] loadNewest called, current: ${currentState.newest.length}, loading: $_loadingNewest, loaded: ${currentState.newestLoaded}',
    );
    if (currentState.newestLoaded || _loadingNewest) {
      debugPrint(
        '[Marketplace] Skipping loadNewest - already loaded or loading',
      );
      return;
    }

    _loadingNewest = true;
    try {
      debugPrint('[Marketplace] Loading newest widgets...');
      final response = await _service.getNewest();
      debugPrint('[Marketplace] Got ${response.widgets.length} newest widgets');
      // Re-fetch current state in case it changed during async operation
      final latestState = state.value ?? currentState;
      state = AsyncValue.data(
        latestState.copyWith(
          newest: response.widgets,
          newestLoaded: true,
          newestError: null,
        ),
      );
    } catch (e, st) {
      debugPrint('[Marketplace] Error loading newest: $e');
      debugPrint('[Marketplace] Stack trace: $st');
      final latestState = state.value ?? currentState;
      state = AsyncValue.data(
        latestState.copyWith(newestLoaded: true, newestError: e.toString()),
      );
    } finally {
      _loadingNewest = false;
    }
  }

  /// Load widgets for a category
  Future<void> loadCategory(String category) async {
    final currentState = state.value;
    if (currentState == null) return;

    debugPrint(
      '[Marketplace] loadCategory called for: $category, loading: ${_loadingCategories.contains(category)}',
    );
    if (currentState.categoryWidgets.containsKey(category) ||
        _loadingCategories.contains(category)) {
      debugPrint(
        '[Marketplace] Skipping loadCategory - already have data or loading for $category',
      );
      return;
    }

    _loadingCategories.add(category);
    try {
      debugPrint('[Marketplace] Loading category: $category...');
      final response = await _service.getByCategory(category);
      debugPrint(
        '[Marketplace] Got ${response.widgets.length} widgets for $category',
      );
      // Re-fetch current state in case it changed during async operation
      final latestState = state.value ?? currentState;
      final updated = Map<String, List<MarketplaceWidget>>.from(
        latestState.categoryWidgets,
      );
      updated[category] = response.widgets;
      state = AsyncValue.data(latestState.copyWith(categoryWidgets: updated));
    } catch (e, st) {
      debugPrint('[Marketplace] Error loading category $category: $e');
      debugPrint('[Marketplace] Stack trace: $st');
    } finally {
      _loadingCategories.remove(category);
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    debugPrint('[Marketplace] Refresh requested');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final featured = await _loadFeatured();
      return MarketplaceState(featured: featured);
    });
  }
}

/// Provider for marketplace state - uses AsyncNotifierProvider for auto-load
final marketplaceProvider =
    AsyncNotifierProvider<MarketplaceNotifier, MarketplaceState>(
      MarketplaceNotifier.new,
    );

/// Search results state
class MarketplaceSearchState {
  final List<MarketplaceWidget> results;
  final bool isSearching;
  final String query;

  const MarketplaceSearchState({
    this.results = const [],
    this.isSearching = false,
    this.query = '',
  });

  MarketplaceSearchState copyWith({
    List<MarketplaceWidget>? results,
    bool? isSearching,
    String? query,
  }) {
    return MarketplaceSearchState(
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      query: query ?? this.query,
    );
  }
}

/// Notifier for search state
class MarketplaceSearchNotifier extends Notifier<MarketplaceSearchState> {
  @override
  MarketplaceSearchState build() {
    return const MarketplaceSearchState();
  }

  WidgetMarketplaceService get _service => ref.read(marketplaceServiceProvider);

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = const MarketplaceSearchState();
      return;
    }

    state = state.copyWith(isSearching: true, query: query);

    try {
      final response = await _service.search(query);
      state = state.copyWith(results: response.widgets, isSearching: false);
    } catch (_) {
      state = state.copyWith(results: [], isSearching: false);
    }
  }

  void clear() {
    state = const MarketplaceSearchState();
  }
}

/// Provider for search state
final marketplaceSearchProvider =
    NotifierProvider<MarketplaceSearchNotifier, MarketplaceSearchState>(
      MarketplaceSearchNotifier.new,
    );
