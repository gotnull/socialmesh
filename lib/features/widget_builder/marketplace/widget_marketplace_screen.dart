import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../marketplace/widget_marketplace_service.dart';
import '../models/widget_schema.dart';
import '../renderer/widget_renderer.dart';
import '../storage/widget_storage_service.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/splash_mesh_provider.dart';
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
    // Load initial data
    Future.microtask(
      () => ref.read(marketplaceProvider.notifier).loadFeatured(),
    );
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
    final marketplaceState = ref.watch(marketplaceProvider);
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
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFeaturedTab(marketplaceState),
                      _buildPopularTab(marketplaceState),
                      _buildNewTab(marketplaceState),
                      _buildCategoriesTab(),
                    ],
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
    if (state.isLoading && state.featured.isEmpty) {
      return const ScreenLoadingIndicator();
    }

    if (state.error != null && state.featured.isEmpty) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(marketplaceProvider.notifier).refresh();
      },
      child: _buildWidgetGrid(state.featured),
    );
  }

  Widget _buildPopularTab(MarketplaceState state) {
    if (state.popular.isEmpty) {
      // Trigger load if not already loaded
      Future.microtask(
        () => ref.read(marketplaceProvider.notifier).loadPopular(),
      );
      return const ScreenLoadingIndicator();
    }

    return _buildWidgetGrid(state.popular);
  }

  Widget _buildNewTab(MarketplaceState state) {
    if (state.newest.isEmpty) {
      // Trigger load if not already loaded
      Future.microtask(
        () => ref.read(marketplaceProvider.notifier).loadNewest(),
      );
      return const ScreenLoadingIndicator();
    }

    return _buildWidgetGrid(state.newest);
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

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: widgets.length,
      itemBuilder: (context, index) {
        return _MarketplaceWidgetCard(
          widget: widgets[index],
          onTap: () => _openWidgetDetails(widgets[index]),
        );
      },
    );
  }

  Widget _buildErrorState() {
    final accentColor = context.accentColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 48,
            color: accentColor.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load widgets',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => ref.read(marketplaceProvider.notifier).refresh(),
            child: Text('Retry', style: TextStyle(color: accentColor)),
          ),
        ],
      ),
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

/// Marketplace widget card with live preview
class _MarketplaceWidgetCard extends ConsumerWidget {
  final MarketplaceWidget widget;
  final VoidCallback onTap;

  const _MarketplaceWidgetCard({required this.widget, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(marketplaceServiceProvider);

    return Card(
      color: AppTheme.darkCard,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Widget preview
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: _buildPreview(context, ref, service),
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'by ${widget.author}',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 12,
                          color: AppTheme.warningYellow,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          widget.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.download,
                          size: 12,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _formatDownloads(widget.downloads),
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(
    BuildContext context,
    WidgetRef ref,
    WidgetMarketplaceService service,
  ) {
    // Try to get the schema for this widget to show live preview
    return FutureBuilder<WidgetSchema>(
      future: service.downloadWidget(widget.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Show placeholder with icon based on category
          return _buildPlaceholder(context);
        }

        final schema = snapshot.data!;
        final nodes = ref.watch(nodesProvider);
        final myNodeNum = ref.watch(myNodeNumProvider);
        final node = myNodeNum != null ? nodes[myNodeNum] : null;

        return Padding(
          padding: const EdgeInsets.all(8),
          child: WidgetRenderer(
            schema: schema,
            node: node,
            allNodes: nodes,
            accentColor: context.accentColor,
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.accentColor.withValues(alpha: 0.15),
            context.accentColor.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _getCategoryIcon(widget.category),
          size: 36,
          color: context.accentColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'status':
        return Icons.battery_std;
      case 'sensors':
        return Icons.thermostat;
      case 'connectivity':
        return Icons.signal_cellular_alt;
      case 'navigation':
        return Icons.navigation;
      case 'network':
        return Icons.hub;
      case 'messaging':
        return Icons.message;
      default:
        return Icons.widgets;
    }
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
            // Live preview
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: FutureBuilder<WidgetSchema>(
                future: service.downloadWidget(mWidget.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: Icon(
                        Icons.widgets,
                        size: 64,
                        color: context.accentColor.withValues(alpha: 0.3),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: WidgetRenderer(
                      schema: snapshot.data!,
                      node: node,
                      allNodes: nodes,
                      accentColor: context.accentColor,
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
                        child: MeshLoadingIndicator(size: 24),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.marketplaceWidget.name} installed!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to install: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
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
    final state = ref.watch(marketplaceProvider);
    final widgets = state.categoryWidgets[widget.category] ?? [];
    final isLoading = !state.categoryWidgets.containsKey(widget.category);

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
      body: isLoading
          ? const ScreenLoadingIndicator()
          : widgets.isEmpty
          ? Center(
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
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widgets.length,
              itemBuilder: (context, index) {
                return _MarketplaceWidgetCard(
                  widget: widgets[index],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => _WidgetDetailsScreen(
                        marketplaceWidget: widgets[index],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
