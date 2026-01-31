import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../providers/auth_providers.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import 'product_detail_screen.dart';

/// Screen showing user's favorited products
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return GlassScaffold(
        titleWidget: AutoScrollText(
          'Favorites',
          style: TextStyle(color: context.textPrimary),
          maxLines: 1,
          velocity: 30.0,
          fadeWidth: 20.0,
        ),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_outline,
                    color: context.textTertiary,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Sign in to save favorites',
                    style: TextStyle(color: context.textPrimary, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your favorite devices will appear here',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final favoritesAsync = ref.watch(userFavoritesProvider(user.uid));

    return GlassScaffold(
      titleWidget: AutoScrollText(
        'Favorites',
        style: TextStyle(color: context.textPrimary),
        maxLines: 1,
        velocity: 30.0,
        fadeWidth: 20.0,
      ),
      slivers: [
        favoritesAsync.when(
          loading: () => SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading favorites',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(userFavoritesProvider(user.uid)),
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (favorites) {
            if (favorites.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_outline,
                        color: context.textTertiary,
                        size: 64,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No favorites yet',
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap the heart icon on products to save them',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _FavoriteProductCard(
                    favorite: favorites[index],
                    userId: user.uid,
                  );
                }, childCount: favorites.length),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _FavoriteProductCard extends ConsumerWidget {
  final ProductFavorite favorite;
  final String userId;

  const _FavoriteProductCard({required this.favorite, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(
      singleProductFutureProvider(favorite.productId),
    );

    return productAsync.when(
      loading: () => _buildLoadingCard(context),
      error: (error, stack) => _buildErrorCard(context, ref),
      data: (product) {
        if (product == null) {
          return _buildRemovedCard(context, ref);
        }
        return _buildProductCard(context, ref, product);
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.error_outline, color: AppTheme.errorRed),
        title: Text(
          'Unable to load product',
          style: TextStyle(color: context.textPrimary),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: context.textTertiary),
          onPressed: () => _removeFavorite(ref),
        ),
      ),
    );
  }

  Widget _buildRemovedCard(BuildContext context, WidgetRef ref) {
    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.inventory_2_outlined, color: context.textTertiary),
        title: Text(
          'Product no longer available',
          style: TextStyle(color: context.textSecondary),
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline, color: context.textTertiary),
          onPressed: () => _removeFavorite(ref),
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    WidgetRef ref,
    ShopProduct product,
  ) {
    return Dismissible(
      key: Key(favorite.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeFavorite(ref),
      child: Card(
        color: context.card,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: product.id),
            ),
          ),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.primaryImage != null
                      ? Image.network(
                          product.primaryImage!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _imagePlaceholder(context),
                        )
                      : _imagePlaceholder(context),
                ),
                SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
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
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            product.formattedPrice,
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (product.isOnSale) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-${product.discountPercent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Stock status
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: product.isInStock
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.isInStock ? 'In Stock' : 'Out of Stock',
                              style: TextStyle(
                                color: product.isInStock
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Reviews
                      if (product.reviewCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              product.rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              ' (${product.reviewCount} review${product.reviewCount == 1 ? '' : 's'})',
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

                // Remove button
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _removeFavorite(ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      color: context.background,
      child: Icon(Icons.router, color: context.textTertiary, size: 32),
    );
  }

  void _removeFavorite(WidgetRef ref) {
    ref
        .read(deviceShopServiceProvider)
        .toggleFavorite(userId, favorite.productId);
  }
}
