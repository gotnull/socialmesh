import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/premium_gating.dart';
import '../../../models/subscription_models.dart';
import '../../../providers/help_providers.dart';
import '../../../providers/subscription_providers.dart';
import '../marketplace/widget_marketplace_service.dart';
import '../models/widget_schema.dart';
import '../renderer/widget_renderer.dart';
import '../storage/widget_storage_service.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/widget_preview_card.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/splash_mesh_provider.dart';
import '../../../utils/snackbar.dart';
import 'marketplace_providers.dart';

/// Marketplace browse screen
class WidgetMarketplaceScreen extends ConsumerStatefulWidget {
  const WidgetMarketplaceScreen({super.key});

  @override
  ConsumerState<WidgetMarketplaceScreen> createState() =>
      _WidgetMarketplaceScreenState();
}

class _WidgetMarketplaceScreenState
    extends ConsumerState<WidgetMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    // No manual load needed - AsyncNotifier auto-loads in build()
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final notifier = ref.read(marketplaceProvider.notifier);
      switch (_tabController.index) {
        case 1:
          notifier.loadPopular();
          break;
        case 2:
          notifier.loadNewest();
          break;
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    ref.read(marketplaceSearchProvider.notifier).search(query);
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceAsync = ref.watch(marketplaceProvider);
    final searchState = ref.watch(marketplaceSearchProvider);
    final favoritesCount = ref.watch(widgetFavoritesCountProvider);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'marketplace_overview',
        stepKeys: const {},
        child: Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            title: Text(
              'Widget Marketplace',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.help_outline),
                onPressed: () => ref
                    .read(helpProvider.notifier)
                    .startTour('marketplace_overview'),
                tooltip: 'Help',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: context.accentColor,
              labelColor: context.accentColor,
              unselectedLabelColor: context.textSecondary,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(text: 'Featured'),
                const Tab(text: 'Popular'),
                const Tab(text: 'New'),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Favorites${favoritesCount > 0 ? ' ($favoritesCount)' : ''}',
                      ),
                    ],
                  ),
                ),
                const Tab(text: 'Categories'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => _search(value),
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search widgets...',
                    hintStyle: TextStyle(color: context.textTertiary),
                    prefixIcon: Icon(Icons.search, color: context.textTertiary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: context.textTertiary,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(marketplaceSearchProvider.notifier)
                                  .clear();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: context.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: searchState.query.isNotEmpty
                    ? _buildSearchResults(searchState)
                    : marketplaceAsync.when(
                        loading: () => const ScreenLoadingIndicator(),
                        error: (error, stack) => _buildErrorState(
                          'Unable to load marketplace',
                          onRetry: () => ref.invalidate(marketplaceProvider),
                        ),
                        data: (state) => TabBarView(
                          controller: _tabController,
                          children: [
                            _buildFeaturedTab(state),
                            _buildPopularTab(state),
                            _buildNewTab(state),
                            _buildFavoritesTab(state),
                            _buildCategoriesTab(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(MarketplaceSearchState searchState) {
    if (searchState.isSearching) {
      return const ScreenLoadingIndicator();
    }

    if (searchState.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: context.textTertiary),
            SizedBox(height: 16),
            Text(
              'No widgets found',
              style: TextStyle(color: context.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return _buildWidgetGrid(searchState.results);
  }

  Widget _buildFeaturedTab(MarketplaceState state) {
    if (state.featured.isEmpty) {
      return _buildEmptyState('No featured widgets');
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(marketplaceProvider.notifier).refresh();
      },
      child: _buildWidgetGrid(state.featured),
    );
  }

  Widget _buildPopularTab(MarketplaceState state) {
    if (!state.popularLoaded) {
      // Still loading
      return const ScreenLoadingIndicator();
    }

    if (state.popularError != null) {
      return _buildErrorState(
        'Failed to load popular widgets',
        onRetry: () {
          ref.invalidate(marketplaceProvider);
        },
      );
    }

    if (state.popular.isEmpty) {
      return _buildEmptyState('No popular widgets yet');
    }

    return _buildWidgetGrid(state.popular);
  }

  Widget _buildNewTab(MarketplaceState state) {
    if (!state.newestLoaded) {
      // Still loading
      return const ScreenLoadingIndicator();
    }

    if (state.newestError != null) {
      return _buildErrorState(
        'Failed to load newest widgets',
        onRetry: () {
          ref.invalidate(marketplaceProvider);
        },
      );
    }

    if (state.newest.isEmpty) {
      return _buildEmptyState('No new widgets yet');
    }

    return _buildWidgetGrid(state.newest);
  }

  Widget _buildFavoritesTab(MarketplaceState state) {
    final favoriteIds = ref.watch(widgetFavoritesProvider);

    // Get all widgets from state and filter to favorites
    final allWidgets = <MarketplaceWidget>[
      ...state.featured,
      ...state.popular,
      ...state.newest,
    ];

    // Remove duplicates by ID and filter to favorites only
    final seenIds = <String>{};
    final favoriteWidgets = allWidgets.where((widget) {
      if (seenIds.contains(widget.id)) return false;
      seenIds.add(widget.id);
      return favoriteIds.contains(widget.id);
    }).toList();

    if (favoriteWidgets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 48,
                color: context.textTertiary,
              ),
              SizedBox(height: 16),
              Text(
                'No favorite widgets yet',
                style: TextStyle(color: context.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Tap the heart icon on any widget to add it here',
                style: TextStyle(color: context.textTertiary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return _buildWidgetGrid(favoriteWidgets);
  }

  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.textTertiary),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: context.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.widgets_outlined, size: 48, color: context.textTertiary),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: context.textSecondary, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: WidgetCategories.all.length,
      itemBuilder: (context, index) {
        final category = WidgetCategories.all[index];
        return _buildCategoryCard(category);
      },
    );
  }

  Widget _buildCategoryCard(String category) {
    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.accentColor.withValues(alpha: 0.2),
          child: Icon(
            _getCategoryIcon(category),
            color: context.accentColor,
            size: 20,
          ),
        ),
        title: Text(
          WidgetCategories.getDisplayName(category),
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: context.textTertiary),
        onTap: () => _openCategory(category),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case WidgetCategories.deviceStatus:
        return Icons.phone_android;
      case WidgetCategories.metrics:
        return Icons.analytics;
      case WidgetCategories.charts:
        return Icons.bar_chart;
      case WidgetCategories.mesh:
        return Icons.hub;
      case WidgetCategories.location:
        return Icons.location_on;
      case WidgetCategories.weather:
        return Icons.cloud;
      case WidgetCategories.utility:
        return Icons.build;
      case WidgetCategories.other:
        return Icons.category;
      default:
        return Icons.widgets;
    }
  }

  void _openCategory(String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _CategoryScreen(category: category),
      ),
    );
  }

  Widget _buildWidgetGrid(List<MarketplaceWidget> widgets) {
    if (widgets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.widgets_outlined, size: 48, color: context.textTertiary),
            SizedBox(height: 16),
            Text(
              'No widgets available',
              style: TextStyle(color: context.textSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Use single column list - matches My Widgets style
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widgets.length,
      itemBuilder: (context, index) {
        return _MarketplaceWidgetCard(
          widget: widgets[index],
          onTap: () => _openWidgetDetails(widgets[index]),
        );
      },
    );
  }

  void _openWidgetDetails(MarketplaceWidget widget) async {
    final installed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => _WidgetDetailsScreen(marketplaceWidget: widget),
      ),
    );

    // Refresh data if a widget was installed (install count changed)
    if (installed == true && mounted) {
      ref.read(marketplaceProvider.notifier).refresh();
    }
  }
}

/// Marketplace widget card - uses shared WidgetPreviewCard component
class _MarketplaceWidgetCard extends ConsumerWidget {
  final MarketplaceWidget widget;
  final VoidCallback onTap;

  const _MarketplaceWidgetCard({required this.widget, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(marketplaceServiceProvider);
    final isFavorited = ref.watch(isWidgetFavoritedProvider(widget.id));

    return FutureBuilder<WidgetSchema>(
      future: service.previewWidget(widget.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Loading placeholder with metadata visible
          return WidgetPreviewCardLoading(
            height: 120,
            title: widget.name,
            subtitle: 'by ${widget.author}',
          );
        }

        return WidgetPreviewCard(
          schema: snapshot.data!,
          title: snapshot.data!.name,
          subtitle: 'by ${widget.author}',
          onTap: onTap,
          trailing: WidgetMarketplaceStats(
            rating: widget.rating,
            installs: widget.installs,
            isFavorited: isFavorited,
            onFavoriteToggle: () {
              ref
                  .read(widgetFavoritesProvider.notifier)
                  .toggleFavorite(widget.id);
              HapticFeedback.lightImpact();
            },
          ),
        );
      },
    );
  }
}

/// Widget details screen
class _WidgetDetailsScreen extends ConsumerStatefulWidget {
  final MarketplaceWidget marketplaceWidget;

  const _WidgetDetailsScreen({required this.marketplaceWidget});

  @override
  ConsumerState<_WidgetDetailsScreen> createState() =>
      _WidgetDetailsScreenState();
}

class _WidgetDetailsScreenState extends ConsumerState<_WidgetDetailsScreen> {
  bool _isInstalling = false;

  @override
  Widget build(BuildContext context) {
    final mWidget = widget.marketplaceWidget;
    final service = ref.watch(marketplaceServiceProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final node = myNodeNum != null ? nodes[myNodeNum] : null;

    // Check against Firebase-backed user profile (reactive)
    final profile = ref.watch(userProfileProvider).value;
    final isAlreadyInstalled =
        profile?.installedWidgetIds.contains(mWidget.id) ?? false;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: AutoScrollText(
          mWidget.name,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live preview - widget fills container
            Container(
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<WidgetSchema>(
                future: service.previewWidget(mWidget.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return AspectRatio(
                      aspectRatio: 2.0,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.widgets,
                              size: 48,
                              color: context.accentColor.withValues(alpha: 0.4),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Loading preview...',
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Render widget at its natural size
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: WidgetRenderer(
                      schema: snapshot.data!,
                      node: node,
                      allNodes: nodes,
                      accentColor: context.accentColor,
                      enableActions: false, // Only interactive on dashboard
                      isPreview: true,
                      usePlaceholderData: node == null,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 24),
            // Title and author
            Text(
              mWidget.name,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Author
            Text(
              'by ${mWidget.author}',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
            SizedBox(height: 16),
            // Stats row
            Row(
              children: [
                _buildStatItem(
                  Icons.star,
                  '${mWidget.rating.toStringAsFixed(1)} (${mWidget.ratingCount})',
                  AppTheme.warningYellow,
                ),
                const SizedBox(width: 24),
                _buildStatItem(
                  Icons.download_done,
                  '${mWidget.installs} installs',
                  context.textSecondary,
                ),
              ],
            ),
            SizedBox(height: 24),
            // Description
            Text(
              'Description',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mWidget.description,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            SizedBox(height: 24),
            // Tags
            if (mWidget.tags.isNotEmpty) ...[
              Text(
                'Tags',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mWidget.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.accentColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: 32),
            // Install button
            Builder(
              builder: (context) {
                final hasPremium = ref.watch(
                  hasFeatureProvider(PremiumFeature.homeWidgets),
                );
                final isLocked = !hasPremium && !isAlreadyInstalled;

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isInstalling || isAlreadyInstalled
                        ? null
                        : _installWidget,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAlreadyInstalled
                          ? context.textSecondary.withValues(alpha: 0.3)
                          : isLocked
                          ? Colors.grey.shade600
                          : context.accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isInstalling
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isAlreadyInstalled)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              if (isLocked)
                                const Icon(
                                  Icons.lock,
                                  color: Colors.white70,
                                  size: 18,
                                ),
                              if (isAlreadyInstalled || isLocked)
                                const SizedBox(width: 8),
                              Text(
                                isAlreadyInstalled
                                    ? 'Already Installed'
                                    : 'Install Widget',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isAlreadyInstalled || isLocked
                                      ? Colors.white70
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _installWidget() async {
    // Check premium before allowing widget install
    final hasPremium = ref.read(hasFeatureProvider(PremiumFeature.homeWidgets));
    if (!hasPremium) {
      showPremiumInfoSheet(
        context: context,
        ref: ref,
        feature: PremiumFeature.homeWidgets,
      );
      return;
    }

    setState(() => _isInstalling = true);

    try {
      final service = ref.read(marketplaceServiceProvider);
      final marketplaceId = widget.marketplaceWidget.id;

      // Download widget schema
      final schema = await service.downloadWidget(marketplaceId);

      // Save to local storage with marketplace ID for proper tracking
      final storage = WidgetStorageService();
      await storage.init();
      await storage.installMarketplaceWidget(
        schema,
        marketplaceId: marketplaceId,
      );

      // Add to user profile for cloud sync (survives reinstall)
      await ref
          .read(userProfileProvider.notifier)
          .addInstalledWidget(marketplaceId);

      if (mounted) {
        showSuccessSnackBar(
          context,
          '${widget.marketplaceWidget.name} installed!',
        );
        // Pop back to Widget Builder screen (2 pops: detail sheet + marketplace)
        // This preserves the navigation stack better than pushAndRemoveUntil
        var popCount = 0;
        Navigator.of(context).popUntil((route) {
          popCount++;
          // Pop until we're at the WidgetBuilderScreen (usually 2 routes back)
          // or until we can't pop anymore
          return popCount > 2 || !Navigator.of(context).canPop();
        });
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to install: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isInstalling = false);
      }
    }
  }
}

/// Category screen using provider-based state management
class _CategoryScreen extends ConsumerStatefulWidget {
  final String category;

  const _CategoryScreen({required this.category});

  @override
  ConsumerState<_CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<_CategoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () =>
          ref.read(marketplaceProvider.notifier).loadCategory(widget.category),
    );
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(marketplaceProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: AutoScrollText(
          WidgetCategories.getDisplayName(widget.category),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const ScreenLoadingIndicator(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.textTertiary),
              SizedBox(height: 16),
              Text(
                'Failed to load category',
                style: TextStyle(color: context.textSecondary, fontSize: 16),
              ),
            ],
          ),
        ),
        data: (state) {
          final widgets = state.categoryWidgets[widget.category] ?? [];
          final isLoading = !state.categoryWidgets.containsKey(widget.category);

          if (isLoading) {
            return const ScreenLoadingIndicator();
          }

          if (widgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.widgets_outlined,
                    size: 48,
                    color: context.textTertiary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No widgets in this category',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widgets.length,
            itemBuilder: (context, index) {
              return _MarketplaceWidgetCard(
                widget: widgets[index],
                onTap: () async {
                  final installed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _WidgetDetailsScreen(
                        marketplaceWidget: widgets[index],
                      ),
                    ),
                  );
                  // Refresh if widget was installed
                  if (installed == true && mounted) {
                    ref.read(marketplaceProvider.notifier).refresh();
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
