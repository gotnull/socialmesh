import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../providers/auth_providers.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import 'product_detail_screen.dart';
import 'category_products_screen.dart';
import 'seller_profile_screen.dart';
import 'favorites_screen.dart';

/// Main device shop screen
class DeviceShopScreen extends ConsumerStatefulWidget {
  const DeviceShopScreen({super.key});

  @override
  ConsumerState<DeviceShopScreen> createState() => _DeviceShopScreenState();
}

class _DeviceShopScreenState extends ConsumerState<DeviceShopScreen> {
  late ScrollController _scrollController;
  bool _showTitle = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isSearchFocused = false;
  final List<String> _recentSearches = [];
  final List<String> _popularSearches = [
    'T-Beam',
    'LoRa',
    'SenseCAP',
    'RAK',
    'Solar',
    'Antenna',
    'ESP32',
    'nRF52',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    // Show title when scrolled past header (120px expandedHeight)
    final shouldShowTitle =
        _scrollController.hasClients && _scrollController.offset > 80;
    if (shouldShowTitle != _showTitle) {
      setState(() => _showTitle = shouldShowTitle);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _searchQuery = value.trim());
    });
  }

  void _performSearch(String query) {
    _searchController.text = query;
    setState(() => _searchQuery = query.trim());
    if (query.isNotEmpty && !_recentSearches.contains(query)) {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    }
    _searchFocusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // App Bar
            SliverAppBar(
              backgroundColor: context.card,
              floating: true,
              pinned: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.accentColor.withValues(alpha: 0.3),
                        context.card,
                      ],
                    ),
                  ),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store, color: context.accentColor, size: 24),
                    const SizedBox(width: 8),
                    AutoScrollText(
                      'Device Shop',
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      velocity: 30.0,
                      fadeWidth: 20.0,
                    ),
                  ],
                ),
                centerTitle: true,
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.favorite_outline),
                  onPressed: () => _openFavorites(context),
                  tooltip: 'Favorites',
                ),
              ],
            ),

            // Search bar - pinned below app bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _SearchBarDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                onClear: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                hintText: 'Search devices, modules, antennas...',
                backgroundColor: context.background,
                cardColor: context.card,
                textPrimary: context.textPrimary,
                textTertiary: context.textTertiary,
              ),
            ),

            // Show search suggestions, search results, or regular content
            if (_isSearchFocused && _searchQuery.isEmpty)
              _buildSearchSuggestions()
            else if (_searchQuery.isNotEmpty)
              _buildSearchResults()
            else ...[
              // Categories
              SliverToBoxAdapter(
                child: _CategoriesSection(onCategoryTap: _openCategory),
              ),

              // Featured Products
              const SliverToBoxAdapter(child: _FeaturedSection()),

              // Official Partners
              const SliverToBoxAdapter(child: _PartnersSection()),

              // New Arrivals
              const SliverToBoxAdapter(child: _NewArrivalsSection()),

              // Best Sellers
              const SliverToBoxAdapter(child: _BestSellersSection()),

              // On Sale
              const SliverToBoxAdapter(child: _OnSaleSection()),
            ],

            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  void _openFavorites(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FavoritesScreen()),
    );
  }

  void _openCategory(DeviceCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(category: category),
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent searches
            if (_recentSearches.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _recentSearches.clear()),
                    child: Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentSearches
                    .map(
                      (s) => _SearchChip(
                        label: s,
                        icon: Icons.history,
                        onTap: () => _performSearch(s),
                        onDelete: () {
                          setState(() => _recentSearches.remove(s));
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Popular searches
            Text(
              'Popular Searches',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _popularSearches
                  .map(
                    (s) => _SearchChip(
                      label: s,
                      icon: Icons.trending_up,
                      onTap: () => _performSearch(s),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),

            // Browse by category
            Text(
              'Browse by Category',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...DeviceCategory.values.map(
              (cat) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _categoryIcon(cat),
                    color: context.accentColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  cat.label,
                  style: TextStyle(color: context.textPrimary),
                ),
                subtitle: Text(
                  cat.description,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: context.textTertiary,
                ),
                onTap: () => _openCategory(cat),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(DeviceCategory category) {
    switch (category) {
      case DeviceCategory.node:
        return Icons.router;
      case DeviceCategory.module:
        return Icons.memory;
      case DeviceCategory.antenna:
        return Icons.cell_tower;
      case DeviceCategory.enclosure:
        return Icons.inventory_2;
      case DeviceCategory.accessory:
        return Icons.cable;
      case DeviceCategory.kit:
        return Icons.build;
      case DeviceCategory.solar:
        return Icons.solar_power;
    }
  }

  Widget _buildSearchResults() {
    return Consumer(
      builder: (context, ref, _) {
        final productsAsync = ref.watch(shopProductsProvider);

        return productsAsync.when(
          data: (products) {
            final filteredProducts = products.where((product) {
              final query = _searchQuery.toLowerCase();
              return product.name.toLowerCase().contains(query) ||
                  product.description.toLowerCase().contains(query) ||
                  product.category.label.toLowerCase().contains(query) ||
                  product.tags.any((tag) => tag.toLowerCase().contains(query));
            }).toList();

            if (filteredProducts.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: context.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results for "$_searchQuery"',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try different keywords',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = filteredProducts[index];
                  return ProductCard(product: product);
                }, childCount: filteredProducts.length),
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => SliverFillRemaining(
            child: Center(
              child: Text(
                'Error loading products',
                style: TextStyle(color: context.textSecondary),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Categories horizontal scroll
class _CategoriesSection extends StatelessWidget {
  final Function(DeviceCategory) onCategoryTap;

  const _CategoriesSection({required this.onCategoryTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Text(
            'Categories',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 100,
          child: EdgeFade.end(
            fadeSize: 32,
            fadeColor: context.background,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: DeviceCategory.values.length,
              itemBuilder: (context, index) {
                final category = DeviceCategory.values[index];
                return _CategoryCard(
                  category: category,
                  onTap: () => onCategoryTap(category),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Category card
class _CategoryCard extends StatelessWidget {
  final DeviceCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  IconData get _icon {
    switch (category) {
      case DeviceCategory.node:
        return Icons.router;
      case DeviceCategory.module:
        return Icons.memory;
      case DeviceCategory.antenna:
        return Icons.cell_tower;
      case DeviceCategory.enclosure:
        return Icons.inventory_2;
      case DeviceCategory.accessory:
        return Icons.cable;
      case DeviceCategory.kit:
        return Icons.build;
      case DeviceCategory.solar:
        return Icons.solar_power;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 80,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_icon, color: context.accentColor, size: 28),
                const SizedBox(height: 8),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: AutoScrollText(
                      category.label,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      velocity: 20.0,
                      fadeWidth: 8.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Featured products section
class _FeaturedSection extends ConsumerWidget {
  const _FeaturedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(featuredProductsProvider);

    return productsAsync.when(
      loading: () => _SectionLoading(title: 'Featured'),
      error: (error, stack) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        return _ProductSection(
          title: 'Featured',
          titleIcon: Icons.star,
          products: products,
          onSeeAll: null,
        );
      },
    );
  }
}

/// Official partners section
class _PartnersSection extends ConsumerWidget {
  const _PartnersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnersAsync = ref.watch(officialPartnersProvider);

    return partnersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (partners) {
        if (partners.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.verified, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Official Partners',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 80,
              child: EdgeFade.end(
                fadeSize: 32,
                fadeColor: context.background,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: partners.length,
                  itemBuilder: (context, index) {
                    return _PartnerCard(seller: partners[index]);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Partner card
class _PartnerCard extends StatelessWidget {
  final ShopSeller seller;

  const _PartnerCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerProfileScreen(sellerId: seller.id),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 120,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (seller.logoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      seller.logoUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.store, color: context.accentColor),
                    ),
                  )
                else
                  Icon(Icons.store, color: context.accentColor, size: 32),
                const SizedBox(height: 8),
                SizedBox(
                  width: 120,
                  child: Center(
                    child: AutoScrollText(
                      seller.name,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      velocity: 25.0,
                      fadeWidth: 10.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// New arrivals section
class _NewArrivalsSection extends ConsumerWidget {
  const _NewArrivalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(newArrivalsProvider);

    return productsAsync.when(
      loading: () => _SectionLoading(title: 'New Arrivals'),
      error: (error, stack) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        return _ProductSection(
          title: 'New Arrivals',
          titleIcon: Icons.fiber_new,
          products: products.take(10).toList(),
          onSeeAll: null,
        );
      },
    );
  }
}

/// Best sellers section
class _BestSellersSection extends ConsumerWidget {
  const _BestSellersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(bestSellersProvider);

    return productsAsync.when(
      loading: () => _SectionLoading(title: 'Best Sellers'),
      error: (error, stack) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        return _ProductSection(
          title: 'Best Sellers',
          titleIcon: Icons.local_fire_department,
          products: products.take(10).toList(),
          onSeeAll: null,
        );
      },
    );
  }
}

/// On sale section
class _OnSaleSection extends ConsumerWidget {
  const _OnSaleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(onSaleProductsProvider);

    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        return _ProductSection(
          title: 'On Sale',
          titleIcon: Icons.local_offer,
          products: products.take(10).toList(),
          onSeeAll: null,
          highlightColor: Colors.red,
        );
      },
    );
  }
}

/// Generic product section
class _ProductSection extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final List<ShopProduct> products;
  final VoidCallback? onSeeAll;
  final Color? highlightColor;

  const _ProductSection({
    required this.title,
    this.titleIcon,
    required this.products,
    this.onSeeAll,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, color: context.accentColor, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: Text(
                    'See All',
                    style: TextStyle(color: context.accentColor),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: EdgeFade.end(
            fadeSize: 32,
            fadeColor: context.background,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return ProductCard(
                  product: products[index],
                  highlightColor: highlightColor,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Product card widget
class ProductCard extends ConsumerStatefulWidget {
  final ShopProduct product;
  final Color? highlightColor;

  const ProductCard({super.key, required this.product, this.highlightColor});

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _heartScale = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _heartController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final favoriteIdsAsync = user != null
        ? ref.watch(userFavoriteIdsProvider(user.uid))
        : const AsyncValue<Set<String>>.data({});
    final isFavorite =
        favoriteIdsAsync.value?.contains(widget.product.id) ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: widget.product.id),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.product.isOnSale
                    ? (widget.highlightColor ?? Colors.red).withValues(
                        alpha: 0.5,
                      )
                    : context.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: widget.product.primaryImage != null
                          ? Image.network(
                              widget.product.primaryImage!,
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 120,
                                      color: context.background,
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    height: 120,
                                    color: context.background,
                                    child: Icon(
                                      Icons.image,
                                      color: context.textTertiary,
                                      size: 40,
                                    ),
                                  ),
                            )
                          : Container(
                              height: 120,
                              color: context.background,
                              child: Icon(
                                Icons.router,
                                color: context.textTertiary,
                                size: 40,
                              ),
                            ),
                    ),
                    // Gradient overlay for icon visibility
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.4),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Sale badge
                    if (widget.product.isOnSale)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.highlightColor ?? Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${widget.product.discountPercent}%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    // Favorite button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: ScaleTransition(
                        scale: _heartScale,
                        child: IconButton(
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite
                                : Icons.favorite_outline,
                            color: isFavorite ? Colors.red : Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _toggleFavorite(user?.uid),
                        ),
                      ),
                    ),
                    // Out of stock overlay
                    if (!widget.product.isInStock)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.product.sellerName,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        // Price
                        Row(
                          children: [
                            Text(
                              widget.product.formattedPrice,
                              style: TextStyle(
                                color: context.accentColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (widget.product.isOnSale) ...[
                              SizedBox(width: 6),
                              Text(
                                widget.product.formattedComparePrice!,
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                        // Rating
                        if (widget.product.reviewCount > 0) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                widget.product.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                ' (${widget.product.reviewCount})',
                                style: TextStyle(
                                  color: context.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleFavorite(String? oderId) async {
    if (oderId == null) return;

    // Animate heart
    await _heartController.forward();
    await _heartController.reverse();

    // Toggle favorite
    ref
        .read(deviceShopServiceProvider)
        .toggleFavorite(oderId, widget.product.id);
  }
}

/// Section loading placeholder
class _SectionLoading extends StatelessWidget {
  final String title;

  const _SectionLoading({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 240,
          child: EdgeFade.end(
            fadeSize: 32,
            fadeColor: context.background,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: 3,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 160,
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Search bar persistent header delegate
class _SearchBarDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final FocusNode focusNode;
  final Function(String) onChanged;
  final VoidCallback onClear;
  final String hintText;
  final Color backgroundColor;
  final Color cardColor;
  final Color textPrimary;
  final Color textTertiary;

  _SearchBarDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    required this.hintText,
    required this.backgroundColor,
    required this.cardColor,
    required this.textPrimary,
    required this.textTertiary,
  });

  @override
  double get minExtent => 72.0;

  @override
  double get maxExtent => 72.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: searchController,
          focusNode: focusNode,
          onChanged: onChanged,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: textTertiary),
            prefixIcon: Icon(Icons.search, color: textTertiary),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: textTertiary),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_SearchBarDelegate oldDelegate) {
    return searchQuery != oldDelegate.searchQuery;
  }
}

/// Search chip widget for suggestions
class _SearchChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _SearchChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: context.textTertiary, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: context.textPrimary, fontSize: 13),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.close,
                    color: context.textTertiary,
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
