import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../marketplace/widget_marketplace_service.dart';
import '../models/widget_schema.dart';
import '../renderer/widget_renderer.dart';
import '../storage/widget_storage_service.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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

  @override
  Widget build(BuildContext context) {
    final marketplaceAsync = ref.watch(marketplaceProvider);
    final searchState = ref.watch(marketplaceSearchProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: const Text(
          'Widget Marketplace',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: context.accentColor,
          labelColor: context.accentColor,
          unselectedLabelColor: AppTheme.textSecondary,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Featured'),
            Tab(text: 'Popular'),
            Tab(text: 'New'),
            Tab(text: 'Categories'),
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
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search widgets...',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                prefixIcon: Icon(Icons.search, color: AppTheme.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppTheme.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(marketplaceSearchProvider.notifier).clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.darkCard,
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
                        _buildCategoriesTab(),
                      ],
                    ),
                  ),
          ),
        ],
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
            Icon(Icons.search_off, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              'No widgets found',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
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

  Widget _buildErrorState(String message, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.textTertiary),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
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
            Icon(
              Icons.widgets_outlined,
              size: 48,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
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
      color: AppTheme.darkCard,
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
        onTap: () => _openCategory(category),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case WidgetCategories.status:
        return Icons.battery_std;
      case WidgetCategories.sensors:
        return Icons.thermostat;
      case WidgetCategories.connectivity:
        return Icons.signal_cellular_alt;
      case WidgetCategories.navigation:
        return Icons.navigation;
      case WidgetCategories.network:
        return Icons.hub;
      case WidgetCategories.messaging:
        return Icons.message;
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
            Icon(
              Icons.widgets_outlined,
              size: 48,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No widgets available',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
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

  void _openWidgetDetails(MarketplaceWidget widget) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _WidgetDetailsScreen(marketplaceWidget: widget),
      ),
    );
  }
}

/// Marketplace widget card - renders EXACTLY like widget_builder_screen._buildWidgetCard
class _MarketplaceWidgetCard extends ConsumerWidget {
  final MarketplaceWidget widget;
  final VoidCallback onTap;

  const _MarketplaceWidgetCard({required this.widget, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(marketplaceServiceProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final node = myNodeNum != null ? nodes[myNodeNum] : null;

    return FutureBuilder<WidgetSchema>(
      future: service.downloadWidget(widget.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Loading placeholder - same structure as loaded card
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 120,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorder),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by ${widget.author}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStats(),
                ],
              ),
              const SizedBox(height: 16),
            ],
          );
        }

        final schema = snapshot.data!;

        // Widget preview auto-sizes to content (matches My Widgets)

        return GestureDetector(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Widget preview - auto-sizes to content (matches My Widgets)
              WidgetRenderer(
                schema: schema,
                node: node,
                allNodes: nodes,
                accentColor: context.accentColor,
                enableActions: false, // Only interactive on dashboard
              ),
              const SizedBox(height: 8),
              // Info section
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schema.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by ${widget.author}',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  _buildStats(),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, size: 14, color: AppTheme.warningYellow),
        const SizedBox(width: 4),
        Text(
          widget.rating.toStringAsFixed(1),
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.download, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(
          _formatDownloads(widget.downloads),
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDownloads(int count) {
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
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

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          mWidget.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
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
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<WidgetSchema>(
                future: service.downloadWidget(mWidget.id),
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
                            const SizedBox(height: 8),
                            Text(
                              'Loading preview...',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
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
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            // Title and version
            Row(
              children: [
                Expanded(
                  child: Text(
                    mWidget.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'v${mWidget.version}',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Author
            Text(
              'by ${mWidget.author}',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),
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
                  Icons.download,
                  '${mWidget.downloads} downloads',
                  AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Description
            Text(
              'Description',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mWidget.description,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Tags
            if (mWidget.tags.isNotEmpty) ...[
              Text(
                'Tags',
                style: const TextStyle(
                  color: Colors.white,
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
            const SizedBox(height: 32),
            // Install button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isInstalling ? null : _installWidget,
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.accentColor,
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
                    : const Text(
                        'Install Widget',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
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
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _installWidget() async {
    setState(() => _isInstalling = true);

    try {
      final service = ref.read(marketplaceServiceProvider);
      // Download widget schema
      final schema = await service.downloadWidget(widget.marketplaceWidget.id);

      // Save to local storage
      final storage = WidgetStorageService();
      await storage.init();
      await storage.installMarketplaceWidget(schema);

      if (mounted) {
        showSuccessSnackBar(
          context,
          '${widget.marketplaceWidget.name} installed!',
        );
        // Pop back to marketplace, then pop marketplace with result=true
        Navigator.pop(context); // Pop details screen
        Navigator.pop(context, true); // Pop marketplace with installed=true
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          WidgetCategories.getDisplayName(widget.category),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: asyncState.when(
        loading: () => const ScreenLoadingIndicator(),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: 16),
              Text(
                'Failed to load category',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
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
                    color: AppTheme.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No widgets in this category',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        _WidgetDetailsScreen(marketplaceWidget: widgets[index]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
