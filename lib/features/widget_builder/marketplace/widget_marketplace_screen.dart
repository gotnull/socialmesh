import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../marketplace/widget_marketplace_service.dart';
import '../storage/widget_storage_service.dart';
import '../../../core/theme.dart';
import '../../../providers/splash_mesh_provider.dart';

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
  final _marketplaceService = WidgetMarketplaceService();
  final _searchController = TextEditingController();

  List<MarketplaceWidget> _featuredWidgets = [];
  List<MarketplaceWidget> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadFeatured();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeatured() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final featured = await _marketplaceService.getFeatured();
      setState(() {
        _featuredWidgets = featured;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final response = await _marketplaceService.search(query);
      setState(() {
        _searchResults = response.widgets;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          _search('');
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
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFeaturedTab(),
                      _buildPopularTab(),
                      _buildNewTab(),
                      _buildCategoriesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const ScreenLoadingIndicator();
    }

    if (_searchResults.isEmpty) {
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

    return _buildWidgetGrid(_searchResults);
  }

  Widget _buildFeaturedTab() {
    if (_isLoading) {
      return const ScreenLoadingIndicator();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return RefreshIndicator(
      onRefresh: _loadFeatured,
      child: _buildWidgetGrid(_featuredWidgets),
    );
  }

  Widget _buildPopularTab() {
    return FutureBuilder<MarketplaceResponse>(
      future: _marketplaceService.getPopular(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ScreenLoadingIndicator();
        }
        if (snapshot.hasError) {
          return _buildErrorState();
        }
        return _buildWidgetGrid(snapshot.data?.widgets ?? []);
      },
    );
  }

  Widget _buildNewTab() {
    return FutureBuilder<MarketplaceResponse>(
      future: _marketplaceService.getNewest(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ScreenLoadingIndicator();
        }
        if (snapshot.hasError) {
          return _buildErrorState();
        }
        return _buildWidgetGrid(snapshot.data?.widgets ?? []);
      },
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
        builder: (context) => _CategoryScreen(
          category: category,
          marketplaceService: _marketplaceService,
        ),
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
        childAspectRatio: 0.85,
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
            onPressed: _loadFeatured,
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
        builder: (context) => _WidgetDetailsScreen(
          marketplaceWidget: widget,
          marketplaceService: _marketplaceService,
        ),
      ),
    );
  }
}

/// Marketplace widget card
class _MarketplaceWidgetCard extends StatelessWidget {
  final MarketplaceWidget widget;
  final VoidCallback onTap;

  const _MarketplaceWidgetCard({required this.widget, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.darkCard,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail placeholder
            Container(
              height: 80,
              color: AppTheme.darkBackground,
              child: Center(
                child: Icon(
                  Icons.widgets,
                  size: 32,
                  color: context.accentColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${widget.author}',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: 14,
                          color: AppTheme.warningYellow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.download,
                          size: 14,
                          color: AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDownloads(widget.downloads),
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
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
  final WidgetMarketplaceService marketplaceService;

  const _WidgetDetailsScreen({
    required this.marketplaceWidget,
    required this.marketplaceService,
  });

  @override
  ConsumerState<_WidgetDetailsScreen> createState() =>
      _WidgetDetailsScreenState();
}

class _WidgetDetailsScreenState extends ConsumerState<_WidgetDetailsScreen> {
  bool _isInstalling = false;

  @override
  Widget build(BuildContext context) {
    final mWidget = widget.marketplaceWidget;

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
            // Preview placeholder
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.widgets,
                  size: 64,
                  color: context.accentColor.withValues(alpha: 0.3),
                ),
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
      // Download widget schema
      final schema = await widget.marketplaceService.downloadWidget(
        widget.marketplaceWidget.id,
      );

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

/// Category screen
class _CategoryScreen extends StatelessWidget {
  final String category;
  final WidgetMarketplaceService marketplaceService;

  const _CategoryScreen({
    required this.category,
    required this.marketplaceService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        title: Text(
          WidgetCategories.getDisplayName(category),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: FutureBuilder<MarketplaceResponse>(
        future: marketplaceService.getByCategory(category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ScreenLoadingIndicator();
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Failed to load widgets',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            );
          }

          final widgets = snapshot.data?.widgets ?? [];
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

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
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
                      marketplaceService: marketplaceService,
                    ),
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
