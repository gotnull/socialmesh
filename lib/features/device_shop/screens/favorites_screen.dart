// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../providers/auth_providers.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import '../widgets/device_shop_components.dart';
import 'product_detail_screen.dart';

/// Screen showing user's favorited products.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return GlassScaffold(
        titleWidget: AutoScrollText(
          context.l10n.shopFavoritesTitle,
          style: TextStyle(color: context.textPrimary),
          maxLines: 1,
          velocity: 30,
          fadeWidth: 20,
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Center(
                child: DeviceShopStatePanel(
                  icon: Icons.favorite_outline,
                  title: context.l10n.shopFavoritesSignIn,
                  description: context.l10n.shopFavoritesSignInSubtitle,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final favoritesAsync = ref.watch(userFavoritesProvider(user.uid));

    return GlassScaffold(
      titleWidget: AutoScrollText(
        context.l10n.shopFavoritesTitle,
        style: TextStyle(color: context.textPrimary),
        maxLines: 1,
        velocity: 30,
        fadeWidth: 20,
      ),
      slivers: [
        favoritesAsync.when(
          loading: () => SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, _) => const _FavoriteProductSkeleton(),
                childCount: 3,
              ),
            ),
          ),
          error: (error, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Center(
                child: DeviceShopStatePanel(
                  icon: Icons.error_outline,
                  title: context.l10n.shopFavoritesErrorLoading,
                  description: context.l10n.deviceShopTryAgain,
                  actionLabel: context.l10n.shopFavoritesRetry,
                  actionIcon: Icons.refresh,
                  onAction: () =>
                      ref.invalidate(userFavoritesProvider(user.uid)),
                ),
              ),
            ),
          ),
          data: (favorites) {
            if (favorites.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  child: Center(
                    child: DeviceShopStatePanel(
                      icon: Icons.favorite_outline,
                      title: context.l10n.shopFavoritesEmpty,
                      description: context.l10n.shopFavoritesEmptySubtitle,
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
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
  const _FavoriteProductCard({required this.favorite, required this.userId});

  final ProductFavorite favorite;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(
      singleProductFutureProvider(favorite.productId),
    );

    return productAsync.when(
      loading: () => _buildLoadingCard(context),
      error: (_, _) => _buildErrorCard(context, ref),
      data: (product) {
        if (product == null) {
          return _buildRemovedCard(context, ref);
        }
        return _buildProductCard(context, ref, product);
      },
    );
  }

  Widget _buildLoadingCard(BuildContext context) {
    return const _FavoriteProductSkeleton();
  }

  Widget _buildErrorCard(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius18,
        borderWidth: 1,
        accentOpacity: 0.22,
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorRed),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                context.l10n.shopFavoritesUnableToLoad,
                style: TextStyle(color: context.textPrimary),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.textTertiary),
              onPressed: () => _removeFavorite(ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRemovedCard(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius18,
        borderWidth: 1,
        accentOpacity: 0.18,
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: context.textTertiary),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                context.l10n.shopFavoritesProductRemoved,
                style: TextStyle(color: context.textSecondary),
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: context.textTertiary),
              onPressed: () => _removeFavorite(ref),
            ),
          ],
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
        margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
        decoration: BoxDecoration(
          color: AppTheme.errorRed,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacing20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeFavorite(ref),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
        child: BouncyTap(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: product.id),
            ),
          ),
          child: GradientBorderContainer(
            borderRadius: AppTheme.radius18,
            borderWidth: 1,
            accentOpacity: 0.22,
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  child: product.primaryImage != null
                      ? Image.network(
                          product.primaryImage!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _imagePlaceholder(context),
                        )
                      : _imagePlaceholder(context),
                ),
                const SizedBox(width: AppTheme.spacing14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        product.sellerName,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing10),
                      Row(
                        children: [
                          Text(
                            product.formattedPrice(context.l10n),
                            style: TextStyle(
                              color: context.accentColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (product.isOnSale) ...[
                            const SizedBox(width: AppTheme.spacing8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius8,
                                ),
                              ),
                              child: Text(
                                context.l10n.productDetailDiscountBadge(
                                  product.discountPercent,
                                ),
                                style: TextStyle(
                                  color: AppTheme.errorRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing10),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: product.isInStock
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing6),
                          Text(
                            product.isInStock
                                ? context.l10n.shopFavoritesInStock
                                : context.l10n.shopFavoritesOutOfStock,
                            style: TextStyle(
                              color: product.isInStock
                                  ? AppTheme.successGreen
                                  : AppTheme.errorRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: context.textTertiary),
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
      width: 88,
      height: 88,
      color: context.background,
      child: Icon(Icons.router, color: context.textTertiary, size: 32),
    );
  }

  void _removeFavorite(WidgetRef ref) {
    toggleFavoriteQueued(ref, userId: userId, productId: favorite.productId);
  }
}

class _FavoriteProductSkeleton extends StatelessWidget {
  const _FavoriteProductSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius18,
        borderWidth: 1,
        accentOpacity: 0.18,
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: const SizedBox(
          height: 92,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
