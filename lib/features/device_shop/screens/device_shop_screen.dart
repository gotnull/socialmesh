import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../providers/auth_providers.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import 'product_detail_screen.dart';
import 'category_products_screen.dart';
import 'seller_profile_screen.dart';
import 'search_products_screen.dart';
import 'favorites_screen.dart';

/// Main device shop screen
class DeviceShopScreen extends ConsumerStatefulWidget {
  const DeviceShopScreen({super.key});

  @override
  ConsumerState<DeviceShopScreen> createState() => _DeviceShopScreenState();
}

class _DeviceShopScreenState extends ConsumerState<DeviceShopScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.background,
      body: CustomScrollView(
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
                children: [
                  Icon(Icons.store, color: context.accentColor, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Device Shop',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              centerTitle: true,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _openSearch(context),
                tooltip: 'Search',
              ),
              IconButton(
                icon: const Icon(Icons.favorite_outline),
                onPressed: () => _openFavorites(context),
                tooltip: 'Favorites',
              ),
            ],
          ),

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

          // Bottom padding
          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchProductsScreen()),
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
                Text(
                  category.label,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          title: '⭐ Featured',
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
                Text(
                  seller.name,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          title: '🆕 New Arrivals',
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
          title: '🔥 Best Sellers',
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
          title: '💰 On Sale',
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
  final List<ShopProduct> products;
  final VoidCallback? onSeeAll;
  final Color? highlightColor;

  const _ProductSection({
    required this.title,
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
              Text(
                title,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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
class ProductCard extends ConsumerWidget {
  final ShopProduct product;
  final Color? highlightColor;

  const ProductCard({super.key, required this.product, this.highlightColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final favoriteIdsAsync = user != null
        ? ref.watch(userFavoriteIdsProvider(user.uid))
        : const AsyncValue<Set<String>>.data({});
    final isFavorite = favoriteIdsAsync.value?.contains(product.id) ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: product.id),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: product.isOnSale
                    ? (highlightColor ?? Colors.red).withValues(alpha: 0.5)
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
                      child: product.primaryImage != null
                          ? Image.network(
                              product.primaryImage!,
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
                    // Sale badge
                    if (product.isOnSale)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: highlightColor ?? Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${product.discountPercent}%',
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
                      child: IconButton(
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_outline,
                          color: isFavorite ? Colors.red : Colors.white,
                          size: 20,
                        ),
                        onPressed: () => _toggleFavorite(ref, user?.uid),
                      ),
                    ),
                    // Out of stock overlay
                    if (!product.isInStock)
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
                          product.name,
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
                          product.sellerName,
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
                              product.formattedPrice,
                              style: TextStyle(
                                color: context.accentColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (product.isOnSale) ...[
                              SizedBox(width: 6),
                              Text(
                                product.formattedComparePrice!,
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
                        if (product.reviewCount > 0) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                product.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                ' (${product.reviewCount})',
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

  void _toggleFavorite(WidgetRef ref, String? oderId) {
    if (oderId == null) return;
    ref.read(deviceShopServiceProvider).toggleFavorite(oderId, product.id);
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
