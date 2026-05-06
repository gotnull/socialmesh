// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — search dismissal and delegated callbacks are handled by child widgets
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../providers/connectivity_providers.dart';
import '../../../providers/help_providers.dart';
import '../../../utils/email_launcher.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import '../widgets/device_shop_components.dart';
import '../widgets/product_card.dart';
import 'category_products_screen.dart';
import 'seller_profile_screen.dart';
import 'favorites_screen.dart';

enum _ShopCatalogFilter { all, inStock, featured, onSale, nodes }

bool _matchesShopCatalogFilter(ShopProduct product, _ShopCatalogFilter filter) {
  switch (filter) {
    case _ShopCatalogFilter.all:
      return true;
    case _ShopCatalogFilter.inStock:
      return product.isInStock;
    case _ShopCatalogFilter.featured:
      return product.isFeatured;
    case _ShopCatalogFilter.onSale:
      return product.compareAtPrice != null &&
          product.compareAtPrice! > product.price;
    case _ShopCatalogFilter.nodes:
      return product.category == DeviceCategory.node;
  }
}

/// Main device shop screen
class DeviceShopScreen extends ConsumerStatefulWidget {
  const DeviceShopScreen({super.key});

  @override
  ConsumerState<DeviceShopScreen> createState() => _DeviceShopScreenState();
}

class _DeviceShopScreenState extends ConsumerState<DeviceShopScreen> {
  String _searchQuery = '';
  _ShopCatalogFilter _catalogFilter = _ShopCatalogFilter.all;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  bool _isSearchFocused = false;
  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
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

  bool _matchesCatalogFilter(ShopProduct product) {
    return _matchesShopCatalogFilter(product, _catalogFilter);
  }

  @override
  Widget build(BuildContext context) {
    final productsSnapshot =
        ref.watch(lilygoProductsProvider).asData?.value ??
        const <ShopProduct>[];
    final inStockCount = productsSnapshot.where((p) => p.isInStock).length;
    final featuredCount = productsSnapshot.where((p) => p.isFeatured).length;
    final onSaleCount = productsSnapshot
        .where((p) => p.compareAtPrice != null && p.compareAtPrice! > p.price)
        .length;
    final nodesCount = productsSnapshot
        .where((p) => p.category == DeviceCategory.node)
        .length;

    return HelpTourController(
      topicId: 'device_shop_overview',
      stepKeys: const {},
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: GlassScaffold(
          resizeToAvoidBottomInset: false,
          titleWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.24),
                  ),
                ),
                child: Icon(
                  Icons.storefront,
                  size: 17,
                  color: context.accentColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing10),
              Flexible(
                child: AutoScrollText(
                  context.l10n.deviceShopTitle,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  velocity: 30.0,
                  fadeWidth: 24.0,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.favorite_outline),
              onPressed: () => _openFavorites(context),
              tooltip: context.l10n.deviceShopFavoritesTooltip,
            ),
            AppBarOverflowMenu<String>(
              tooltip: context.l10n.deviceShopHelpTooltip,
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    _refreshCatalog();
                  case 'help':
                    ref
                        .read(helpProvider.notifier)
                        .startTour('device_shop_overview');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 18, color: context.accentColor),
                      const SizedBox(width: AppTheme.spacing10),
                      Text(context.l10n.deviceShopRefreshTooltip),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'help',
                  child: Row(
                    children: [
                      Icon(
                        Icons.help_outline,
                        size: 18,
                        color: context.accentColor,
                      ),
                      const SizedBox(width: AppTheme.spacing10),
                      Text(context.l10n.deviceShopHelpTooltip),
                    ],
                  ),
                ),
              ],
            ),
          ],
          slivers: [
            const SliverToBoxAdapter(
              child: SizedBox(height: AppTheme.spacing8),
            ),
            SliverToBoxAdapter(child: _buildHeroSection()),
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchFilterHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                focusNode: _searchFocusNode,
                onSearchChanged: _onSearchChanged,
                hintText: context.l10n.deviceShopSearchHint,
                textScaler: MediaQuery.textScalerOf(context),
                rebuildKey: Object.hashAll([
                  _searchQuery,
                  _recentSearches,
                  _catalogFilter,
                  productsSnapshot.length,
                  inStockCount,
                  featuredCount,
                  onSaleCount,
                  nodesCount,
                ]),
                filterChips: [
                  StatusFilterChip(
                    label: context.l10n.deviceShopFilterAll,
                    count: productsSnapshot.length,
                    isSelected: _catalogFilter == _ShopCatalogFilter.all,
                    onTap: () =>
                        setState(() => _catalogFilter = _ShopCatalogFilter.all),
                  ),
                  StatusFilterChip(
                    label: context.l10n.deviceShopInStock,
                    count: inStockCount,
                    color: AccentColors.green,
                    isSelected: _catalogFilter == _ShopCatalogFilter.inStock,
                    onTap: () => setState(
                      () => _catalogFilter = _ShopCatalogFilter.inStock,
                    ),
                  ),
                  StatusFilterChip(
                    label: context.l10n.deviceShopFeatured,
                    count: featuredCount,
                    color: AccentColors.yellow,
                    isSelected: _catalogFilter == _ShopCatalogFilter.featured,
                    onTap: () => setState(
                      () => _catalogFilter = _ShopCatalogFilter.featured,
                    ),
                  ),
                  StatusFilterChip(
                    label: context.l10n.deviceShopOnSale,
                    count: onSaleCount,
                    color: AppTheme.errorRed,
                    icon: Icons.local_offer,
                    isSelected: _catalogFilter == _ShopCatalogFilter.onSale,
                    onTap: () => setState(
                      () => _catalogFilter = _ShopCatalogFilter.onSale,
                    ),
                  ),
                  StatusFilterChip(
                    label: DeviceCategory.node.displayLabel(context.l10n),
                    count: nodesCount,
                    color: context.accentColor,
                    icon: Icons.router,
                    isSelected: _catalogFilter == _ShopCatalogFilter.nodes,
                    onTap: () => setState(
                      () => _catalogFilter = _ShopCatalogFilter.nodes,
                    ),
                  ),
                ],
              ),
            ),
            if (_isSearchFocused && _searchQuery.isEmpty)
              _buildSearchSuggestions()
            else if (_searchQuery.isNotEmpty)
              _buildSearchResults()
            else ...[
              SliverToBoxAdapter(
                child: _CategoriesSection(onCategoryTap: _openCategory),
              ),
              const SliverToBoxAdapter(child: _PartnersSection()),
              SliverToBoxAdapter(
                child: _FeaturedSection(catalogFilter: _catalogFilter),
              ),
              SliverToBoxAdapter(
                child: _BestSellersSection(catalogFilter: _catalogFilter),
              ),
              SliverToBoxAdapter(
                child: _NewArrivalsSection(catalogFilter: _catalogFilter),
              ),
              SliverToBoxAdapter(
                child: _OnSaleSection(catalogFilter: _catalogFilter),
              ),
              const SliverToBoxAdapter(child: _BecomeSellerSection()),
            ],
            const SliverPadding(padding: EdgeInsets.only(bottom: 104)),
          ],
        ),
      ),
    );
  }

  void _refreshCatalog() {
    ref.invalidate(lilygoProductsProvider);
    ref.invalidate(lilygoFeaturedProductsProvider);
    ref.invalidate(lilygoTrendingProductsProvider);
    ref.invalidate(officialPartnersProvider);
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

  Widget _buildHeroSection() {
    return Consumer(
      builder: (context, ref, _) {
        final productsAsync = ref.watch(lilygoProductsProvider);
        final partnersAsync = ref.watch(officialPartnersProvider);

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing0,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          child: productsAsync.when(
            loading: () => GradientBorderContainer(
              borderRadius: AppTheme.radius20,
              borderWidth: 1.2,
              accentOpacity: 0.28,
              enableDepthBlend: true,
              depthBlendOpacity: 0.08,
              padding: const EdgeInsets.all(AppTheme.spacing20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 118,
                    height: 12,
                    decoration: BoxDecoration(
                      color: context.border,
                      borderRadius: BorderRadius.circular(AppTheme.radius20),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Container(
                    width: 184,
                    height: 28,
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius20),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Container(
                    width: double.infinity,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing20),
                  Row(
                    children: List.generate(
                      4,
                      (_) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Container(
                            height: 68,
                            decoration: BoxDecoration(
                              color: context.card,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            error: (error, _) => DeviceShopStatePanel(
              compact: true,
              icon: Icons.store_mall_directory_outlined,
              title: context.l10n.deviceShopUnableToLoad,
              description: context.l10n.deviceShopTryAgain,
              actionLabel: context.l10n.deviceShopRetry,
              actionIcon: Icons.refresh,
              onAction: _refreshCatalog,
            ),
            data: (products) {
              final partnerCount = partnersAsync.value?.length ?? 1;
              final featuredCount = products.where((p) => p.isFeatured).length;
              final onSaleCount = products
                  .where(
                    (p) =>
                        p.compareAtPrice != null && p.compareAtPrice! > p.price,
                  )
                  .length;
              final categoryCount = products
                  .map((p) => p.category)
                  .toSet()
                  .length;

              return GradientBorderContainer(
                borderRadius: AppTheme.radius20,
                borderWidth: 1.4,
                accentOpacity: 0.4,
                padding: const EdgeInsets.all(AppTheme.spacing20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacing10,
                            vertical: AppTheme.spacing8,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius16,
                            ),
                            border: Border.all(
                              color: context.accentColor.withValues(
                                alpha: 0.24,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 14,
                                color: context.accentColor,
                              ),
                              const SizedBox(width: AppTheme.spacing6),
                              Text(
                                context.l10n.deviceShopOfficialPartners,
                                style: TextStyle(
                                  color: context.accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Text(
                      context.l10n.deviceShopTitle,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing10),
                    Text(
                      context.l10n.deviceShopMarketplaceDisclaimer,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.auto_awesome,
                            label: context.l10n.deviceShopFeatured,
                            value: featuredCount.toString(),
                            color: AccentColors.yellow,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.verified,
                            label: context.l10n.deviceShopOfficialPartners,
                            value: partnerCount.toString(),
                            color: AccentColors.cyan,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.local_offer,
                            label: context.l10n.deviceShopOnSale,
                            value: onSaleCount.toString(),
                            color: AppTheme.errorRed,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.category_outlined,
                            label: context.l10n.deviceShopCategories,
                            value: categoryCount.toString(),
                            color: AccentColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSearchSuggestions() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_recentSearches.isNotEmpty) ...[
              _SectionHeading(
                icon: Icons.history,
                title: context.l10n.deviceShopRecentSearches,
                trailing: GestureDetector(
                  onTap: () => setState(() => _recentSearches.clear()),
                  child: Text(
                    context.l10n.deviceShopClear,
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing8,
                children: _recentSearches
                    .map(
                      (s) => DeviceShopChoiceChip(
                        label: s,
                        icon: Icons.history,
                        onTap: () => _performSearch(s),
                        trailingIcon: Icons.close,
                        onTrailingTap: () {
                          setState(() => _recentSearches.remove(s));
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: AppTheme.spacing24),
            ],

            _SectionHeading(
              icon: Icons.trending_up,
              title: context.l10n.deviceShopTrending,
            ),
            const SizedBox(height: AppTheme.spacing12),
            ref
                .watch(lilygoTrendingProductsProvider)
                .when(
                  data: (products) {
                    final filtered = products
                        .where(_matchesCatalogFilter)
                        .toList();
                    return filtered.isEmpty
                        ? const SizedBox.shrink()
                        : SizedBox(
                            height: 316,
                            child: EdgeFade.end(
                              fadeSize: 32,
                              fadeColor: context.background,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacing16,
                                ),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(width: AppTheme.spacing12),
                                itemBuilder: (context, index) {
                                  return ProductCard(
                                    product: filtered[index],
                                    width: 196,
                                  );
                                },
                              ),
                            ),
                          );
                  },
                  loading: () => SizedBox(
                    height: 316,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                      ),
                      itemCount: 3,
                      separatorBuilder: (_, _) =>
                          const SizedBox(width: AppTheme.spacing12),
                      itemBuilder: (_, _) =>
                          const ProductCardSkeleton(width: 196),
                    ),
                  ),
                  error: (e, _) => _SectionOffline(
                    onRetry: () =>
                        ref.invalidate(lilygoTrendingProductsProvider),
                  ),
                ),
            const SizedBox(height: AppTheme.spacing24),

            _SectionHeading(
              icon: Icons.explore_outlined,
              title: context.l10n.deviceShopBrowseByCategory,
            ),
            const SizedBox(height: AppTheme.spacing12),
            ...DeviceCategory.values.map(
              (cat) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                child: BouncyTap(
                  onTap: () => _openCategory(cat),
                  child: GradientBorderContainer(
                    borderRadius: AppTheme.radius18,
                    borderWidth: 1,
                    accentOpacity: 0.24,
                    accentColor: deviceShopCategoryColor(cat),
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: deviceShopCategoryColor(
                              cat,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius16,
                            ),
                            border: Border.all(
                              color: deviceShopCategoryColor(
                                cat,
                              ).withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(
                            deviceShopCategoryIcon(cat),
                            color: deviceShopCategoryColor(cat),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.displayLabel(context.l10n),
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spacing4),
                              Text(
                                cat.displayDescription(context.l10n),
                                maxLines: 3,
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                            border: Border.all(
                              color: context.border.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: context.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Consumer(
      builder: (context, ref, _) {
        final productsAsync = ref.watch(lilygoProductsProvider);

        return productsAsync.when(
          data: (products) {
            final filteredProducts = products
                .where((product) {
                  final query = _searchQuery.toLowerCase();
                  return product.name.toLowerCase().contains(query) ||
                      product.description.toLowerCase().contains(query) ||
                      product.category
                          .displayLabel(context.l10n)
                          .toLowerCase()
                          .contains(query) ||
                      product.tags.any(
                        (tag) => tag.toLowerCase().contains(query),
                      );
                })
                .where(_matchesCatalogFilter)
                .toList();

            if (filteredProducts.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  child: Center(
                    child: DeviceShopStatePanel(
                      icon: Icons.search_off,
                      title: context.l10n.deviceShopNoResults(_searchQuery),
                      description: context.l10n.deviceShopTryDifferentKeywords,
                      compact: true,
                    ),
                  ),
                ),
              );
            }

            final width = MediaQuery.sizeOf(context).width;
            final crossAxisCount = width >= 560 ? 3 : 2;

            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing16,
                      AppTheme.spacing12,
                      AppTheme.spacing16,
                      AppTheme.spacing8,
                    ),
                    child: _SectionHeading(
                      icon: Icons.search,
                      title: context.l10n.categoryProductsResultCount(
                        filteredProducts.length,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    AppTheme.spacing0,
                    AppTheme.spacing16,
                    AppTheme.spacing16,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: AppTheme.spacing12,
                      mainAxisSpacing: AppTheme.spacing12,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return ProductCard(product: filteredProducts[index]);
                    }, childCount: filteredProducts.length),
                  ),
                ),
              ],
            );
          },
          loading: () => SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing12,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: AppTheme.spacing12,
                mainAxisSpacing: AppTheme.spacing12,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, _) => const ProductCardSkeleton(),
                childCount: 4,
              ),
            ),
          ),
          error: (error, stack) => SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Center(
                child: DeviceShopStatePanel(
                  icon: Icons.cloud_off,
                  title: context.l10n.deviceShopErrorLoadingProducts,
                  description: context.l10n.deviceShopTryAgain,
                  actionLabel: context.l10n.deviceShopRetry,
                  actionIcon: Icons.refresh,
                  onAction: () => ref.invalidate(lilygoProductsProvider),
                  compact: true,
                ),
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
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 24, 16, 12),
          child: _SectionHeading(
            icon: Icons.widgets_outlined,
            title: context.l10n.deviceShopCategories,
            count: DeviceCategory.values.length,
          ),
        ),
        SizedBox(
          height: 166,
          child: EdgeFade.end(
            fadeSize: 32,
            fadeColor: context.background,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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

  @override
  Widget build(BuildContext context) {
    final accent = deviceShopCategoryColor(category);
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacing12),
      child: SizedBox(
        width: 138,
        child: BouncyTap(
          onTap: onTap,
          child: GradientBorderContainer(
            borderRadius: AppTheme.radius18,
            borderWidth: 1.1,
            accentOpacity: 0.3,
            accentColor: accent,
            padding: const EdgeInsets.all(AppTheme.spacing14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radius14),
                    border: Border.all(color: accent.withValues(alpha: 0.18)),
                  ),
                  child: Icon(deviceShopCategoryIcon(category), color: accent),
                ),
                const Spacer(),
                Text(
                  category.displayLabel(context.l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  category.displayDescription(context.l10n),
                  maxLines: 3,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 12,
                    height: 1.35,
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
  final _ShopCatalogFilter catalogFilter;

  const _FeaturedSection({required this.catalogFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use LILYGO API provider instead of Firebase
    final productsAsync = ref.watch(lilygoFeaturedProductsProvider);

    return productsAsync.when(
      loading: () => _SectionLoading(title: context.l10n.deviceShopFeatured),
      error: (error, stack) => _SectionOffline(
        onRetry: () => ref.invalidate(lilygoFeaturedProductsProvider),
      ),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        return _ProductSection(
          title: context.l10n.deviceShopFeatured,
          titleIcon: Icons.star,
          products: products,
          catalogFilter: catalogFilter,
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
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                24,
                16,
                12,
              ),
              child: _SectionHeading(
                icon: Icons.verified,
                title: context.l10n.deviceShopOfficialPartners,
                count: partners.length,
              ),
            ),
            SizedBox(
              height: 118,
              child: EdgeFade.end(
                fadeSize: 56,
                fadeColor: context.background,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 16, right: 48),
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
      padding: const EdgeInsets.only(right: AppTheme.spacing12),
      child: SizedBox(
        width: 176,
        child: BouncyTap(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SellerProfileScreen(sellerId: seller.id),
            ),
          ),
          child: GradientBorderContainer(
            borderRadius: AppTheme.radius18,
            borderWidth: 1,
            accentOpacity: 0.26,
            accentColor: AccentColors.cyan,
            padding: const EdgeInsets.all(AppTheme.spacing14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AccentColors.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppTheme.radius14),
                    border: Border.all(
                      color: AccentColors.cyan.withValues(alpha: 0.16),
                    ),
                  ),
                  child: seller.logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius14,
                          ),
                          child: Image.network(
                            seller.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => Icon(
                              Icons.storefront,
                              color: context.accentColor,
                            ),
                          ),
                        )
                      : Icon(Icons.storefront, color: context.accentColor),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              seller.name,
                              maxLines: 2,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing4),
                          Icon(
                            Icons.verified,
                            color: context.accentColor,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        context.l10n.deviceShopOfficialPartners,
                        maxLines: 2,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
  final _ShopCatalogFilter catalogFilter;

  const _NewArrivalsSection({required this.catalogFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use LILYGO API - sort by creation date for "new arrivals"
    final productsAsync = ref.watch(lilygoProductsProvider);

    return productsAsync.when(
      loading: () => _SectionLoading(title: context.l10n.deviceShopNewArrivals),
      error: (error, stack) => _SectionOffline(
        onRetry: () => ref.invalidate(lilygoProductsProvider),
      ),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();

        // Sort by creation date, newest first
        final sorted = List<ShopProduct>.from(products)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return _ProductSection(
          title: context.l10n.deviceShopNewArrivals,
          titleIcon: Icons.fiber_new,
          products: sorted.take(10).toList(),
          catalogFilter: catalogFilter,
          onSeeAll: null,
        );
      },
    );
  }
}

/// Best sellers section - shows popular LILYGO products based on Buy Now taps
class _BestSellersSection extends ConsumerWidget {
  final _ShopCatalogFilter catalogFilter;

  const _BestSellersSection({required this.catalogFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(lilygoProductsProvider);
    final tapCountsAsync = ref.watch(productTapCountsProvider);

    return productsAsync.when(
      loading: () =>
          _SectionLoading(title: context.l10n.deviceShopPopularDevices),
      error: (error, stack) => _SectionOffline(
        onRetry: () => ref.invalidate(lilygoProductsProvider),
      ),
      data: (products) {
        final tapCounts = tapCountsAsync.value ?? {};
        final hasUserData = tapCounts.isNotEmpty;

        List<ShopProduct> popular;

        if (hasUserData) {
          // Sort by tap counts (user engagement data)
          final sorted = List<ShopProduct>.from(products)
            ..sort((a, b) {
              final aTaps = tapCounts[a.id] ?? 0;
              final bTaps = tapCounts[b.id] ?? 0;
              return bTaps.compareTo(aTaps);
            });
          // Get products with at least one tap
          popular = sorted.where((p) => (tapCounts[p.id] ?? 0) > 0).toList();
        } else {
          // Fallback: show in-stock devices (nodes category) as "popular"
          popular = products
              .where((p) => p.isInStock && p.category == DeviceCategory.node)
              .toList();
        }

        if (popular.isEmpty) return const SizedBox.shrink();

        return _ProductSection(
          title: context.l10n.deviceShopPopularDevices,
          titleIcon: Icons.local_fire_department,
          products: popular.take(10).toList(),
          catalogFilter: catalogFilter,
          onSeeAll: null,
        );
      },
    );
  }
}

/// On sale section - shows products with compare-at price
class _BecomeSellerSection extends StatelessWidget {
  const _BecomeSellerSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 32, 16, 16),
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius20,
        borderWidth: 1.2,
        accentOpacity: 0.34,
        enableDepthBlend: true,
        depthBlendOpacity: 0.08,
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTheme.radius16),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Icon(Icons.storefront, color: context.accentColor),
                ),
                const SizedBox(width: AppTheme.spacing14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.deviceShopBecomeSeller,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        context.l10n.deviceShopSellYourDevices,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.deviceShopBecomeSellerBody,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacing18),
            SizedBox(
              width: double.infinity,
              child: DeviceShopPrimaryButton(
                label: context.l10n.deviceShopContactUs,
                icon: Icons.email_outlined,
                onTap: () => _contactSocialMesh(context),
                animate: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _contactSocialMesh(BuildContext context) async {
    await launchEmailCompose(
      context: context,
      to: 'support@socialmesh.app',
      subject: context.l10n.deviceShopContactEmailSubject,
      body: context.l10n.deviceShopContactEmailBody,
    );
  }
}

class _OnSaleSection extends ConsumerWidget {
  final _ShopCatalogFilter catalogFilter;

  const _OnSaleSection({required this.catalogFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use LILYGO API - show products with compareAtPrice (discounted)
    final productsAsync = ref.watch(lilygoProductsProvider);

    return productsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => _SectionOffline(
        onRetry: () => ref.invalidate(lilygoProductsProvider),
      ),
      data: (products) {
        // Find products with a compare-at price (on sale)
        final onSale = products
            .where(
              (p) => p.compareAtPrice != null && p.compareAtPrice! > p.price,
            )
            .toList();

        if (onSale.isEmpty) return const SizedBox.shrink();

        return _ProductSection(
          title: context.l10n.deviceShopOnSale,
          titleIcon: Icons.local_offer,
          products: onSale.take(10).toList(),
          catalogFilter: catalogFilter,
          onSeeAll: null,
          highlightColor: AppTheme.errorRed,
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
  final _ShopCatalogFilter catalogFilter;
  final VoidCallback? onSeeAll;
  final Color? highlightColor;

  const _ProductSection({
    required this.title,
    this.titleIcon,
    required this.products,
    required this.catalogFilter,
    this.onSeeAll,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final visibleProducts = products
        .where((p) => _matchesShopCatalogFilter(p, catalogFilter))
        .toList();

    if (visibleProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 24, 16, 12),
          child: _SectionHeading(
            icon: titleIcon,
            title: title,
            count: visibleProducts.length,
            trailing: onSeeAll == null
                ? null
                : GestureDetector(
                    onTap: onSeeAll,
                    child: Text(
                      context.l10n.deviceShopSeeAll,
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
        SizedBox(
          height: 316,
          child: EdgeFade.end(
            fadeSize: 56,
            fadeColor: context.background,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 16, right: 48),
              itemCount: visibleProducts.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spacing12),
                  child: ProductCard(
                    product: visibleProducts[index],
                    width: 172,
                    highlightColor: highlightColor,
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: AppTheme.spacing10),
          Text(
            value,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 11,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    this.icon,
    this.count,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: context.accentColor),
          const SizedBox(width: AppTheme.spacing8),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (count != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing8,
              vertical: AppTheme.spacing6,
            ),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius14),
              border: Border.all(color: context.border.withValues(alpha: 0.28)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (trailing != null) ...[
          const SizedBox(width: AppTheme.spacing12),
          trailing!,
        ],
      ],
    );
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
          padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 24, 16, 12),
          child: _SectionHeading(title: title),
        ),
        SizedBox(
          height: 316,
          child: EdgeFade.end(
            fadeSize: 32,
            fadeColor: context.background,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              itemBuilder: (context, index) {
                return const Padding(
                  padding: EdgeInsets.only(right: AppTheme.spacing12),
                  child: ProductCardSkeleton(width: 196),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Offline fallback for product sections that depend on external API
class _SectionOffline extends ConsumerWidget {
  final VoidCallback onRetry;

  const _SectionOffline({required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: DeviceShopStatePanel(
        compact: true,
        icon: isOnline ? Icons.cloud_off : Icons.wifi_off,
        title: isOnline
            ? context.l10n.deviceShopUnableToLoad
            : context.l10n.deviceShopNoInternet,
        description: isOnline
            ? context.l10n.deviceShopTryAgain
            : context.l10n.deviceShopConnectToBrowse,
        actionLabel: context.l10n.deviceShopRetry,
        actionIcon: Icons.refresh,
        onAction: onRetry,
      ),
    );
  }
}
