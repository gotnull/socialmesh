import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'widget_marketplace_service.dart';

/// Provider for the marketplace service instance
final marketplaceServiceProvider = Provider<WidgetMarketplaceService>((ref) {
  return WidgetMarketplaceService();
});

/// State for marketplace data
class MarketplaceState {
  final List<MarketplaceWidget> featured;
  final List<MarketplaceWidget> popular;
  final List<MarketplaceWidget> newest;
  final Map<String, List<MarketplaceWidget>> categoryWidgets;
  final bool isLoading;
  final String? error;

  const MarketplaceState({
    this.featured = const [],
    this.popular = const [],
    this.newest = const [],
    this.categoryWidgets = const {},
    this.isLoading = false,
    this.error,
  });

  MarketplaceState copyWith({
    List<MarketplaceWidget>? featured,
    List<MarketplaceWidget>? popular,
    List<MarketplaceWidget>? newest,
    Map<String, List<MarketplaceWidget>>? categoryWidgets,
    bool? isLoading,
    String? error,
  }) {
    return MarketplaceState(
      featured: featured ?? this.featured,
      popular: popular ?? this.popular,
      newest: newest ?? this.newest,
      categoryWidgets: categoryWidgets ?? this.categoryWidgets,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Notifier for marketplace state management
class MarketplaceNotifier extends Notifier<MarketplaceState> {
  @override
  MarketplaceState build() {
    return const MarketplaceState();
  }

  WidgetMarketplaceService get _service => ref.read(marketplaceServiceProvider);

  /// Load featured widgets
  Future<void> loadFeatured() async {
    debugPrint(
      '[Marketplace] loadFeatured called, current featured: ${state.featured.length}, error: ${state.error}',
    );
    if (state.featured.isNotEmpty && state.error == null) {
      debugPrint(
        '[Marketplace] Skipping loadFeatured - already have ${state.featured.length} widgets',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    debugPrint('[Marketplace] Loading featured widgets...');
    try {
      final featured = await _service.getFeatured();
      debugPrint('[Marketplace] Got ${featured.length} featured widgets');
      state = state.copyWith(featured: featured, isLoading: false);
    } catch (e, st) {
      debugPrint('[Marketplace] Error loading featured: $e');
      debugPrint('[Marketplace] Stack trace: $st');
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Load popular widgets
  Future<void> loadPopular() async {
    debugPrint(
      '[Marketplace] loadPopular called, current: ${state.popular.length}',
    );
    if (state.popular.isNotEmpty) {
      debugPrint('[Marketplace] Skipping loadPopular - already have data');
      return;
    }

    try {
      debugPrint('[Marketplace] Loading popular widgets...');
      final response = await _service.getPopular();
      debugPrint(
        '[Marketplace] Got ${response.widgets.length} popular widgets',
      );
      state = state.copyWith(popular: response.widgets);
    } catch (e, st) {
      debugPrint('[Marketplace] Error loading popular: $e');
      debugPrint('[Marketplace] Stack trace: $st');
    }
  }

  /// Load newest widgets
  Future<void> loadNewest() async {
    debugPrint(
      '[Marketplace] loadNewest called, current: ${state.newest.length}',
    );
    if (state.newest.isNotEmpty) {
      debugPrint('[Marketplace] Skipping loadNewest - already have data');
      return;
    }

    try {
      debugPrint('[Marketplace] Loading newest widgets...');
      final response = await _service.getNewest();
      debugPrint('[Marketplace] Got ${response.widgets.length} newest widgets');
      state = state.copyWith(newest: response.widgets);
    } catch (e, st) {
      debugPrint('[Marketplace] Error loading newest: $e');
      debugPrint('[Marketplace] Stack trace: $st');
    }
  }

  /// Load widgets for a category
  Future<void> loadCategory(String category) async {
    debugPrint('[Marketplace] loadCategory called for: $category');
    if (state.categoryWidgets.containsKey(category)) {
      debugPrint(
        '[Marketplace] Skipping loadCategory - already have data for $category',
      );
      return;
    }

    try {
      debugPrint('[Marketplace] Loading category: $category...');
      final response = await _service.getByCategory(category);
      debugPrint(
        '[Marketplace] Got ${response.widgets.length} widgets for $category',
      );
      final updated = Map<String, List<MarketplaceWidget>>.from(
        state.categoryWidgets,
      );
      updated[category] = response.widgets;
      state = state.copyWith(categoryWidgets: updated);
    } catch (e, st) {
      debugPrint('[Marketplace] Error loading category $category: $e');
      debugPrint('[Marketplace] Stack trace: $st');
    }
  }

  /// Refresh all data
  Future<void> refresh() async {
    debugPrint('[Marketplace] Refresh requested');
    state = const MarketplaceState(isLoading: true);
    await loadFeatured();
  }
}

/// Provider for marketplace state
final marketplaceProvider =
    NotifierProvider<MarketplaceNotifier, MarketplaceState>(
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
