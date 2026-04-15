// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import '../widgets/device_shop_components.dart';
import '../widgets/product_card.dart';

/// Screen showing all products in a specific category
class CategoryProductsScreen extends ConsumerStatefulWidget {
  final DeviceCategory category;

  const CategoryProductsScreen({super.key, required this.category});

  @override
  ConsumerState<CategoryProductsScreen> createState() =>
      _CategoryProductsScreenState();
}

class _CategoryProductsScreenState
    extends ConsumerState<CategoryProductsScreen> {
  String _sortBy = 'popular';
  bool _inStockOnly = false;
  RangeValues _priceRange = const RangeValues(0, 1000);
  List<FrequencyBand> _selectedBands = [];

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(
      lilygoCategoryProductsProvider(widget.category),
    );

    return GlassScaffold(
      title: widget.category.displayLabel(context.l10n),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _showFilterSheet(context),
          tooltip: context.l10n.categoryProductsFilter,
        ),
        AppBarOverflowMenu<String>(
          onSelected: (value) => setState(() => _sortBy = value),
          itemBuilder: (context) => [
            _sortMenuItem('popular', context.l10n.categoryProductsSortPopular),
            _sortMenuItem('newest', context.l10n.categoryProductsSortNewest),
            _sortMenuItem(
              'price_low',
              context.l10n.categoryProductsSortPriceLow,
            ),
            _sortMenuItem(
              'price_high',
              context.l10n.categoryProductsSortPriceHigh,
            ),
            _sortMenuItem('rating', context.l10n.categoryProductsSortRating),
          ],
        ),
      ],
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing8)),
        productsAsync.when(
          loading: () => SliverPadding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, _) => const ProductCardSkeleton(),
                childCount: 4,
              ),
            ),
          ),
          error: (e, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Center(
                child: DeviceShopStatePanel(
                  icon: Icons.cloud_off,
                  title: context.l10n.categoryProductsErrorLoading,
                  description: context.l10n.deviceShopTryAgain,
                  actionLabel: context.l10n.categoryProductsRetry,
                  actionIcon: Icons.refresh,
                  onAction: () => ref.invalidate(lilygoProductsProvider),
                  compact: true,
                ),
              ),
            ),
          ),
          data: (products) {
            final filtered = _filterProducts(products);
            final sorted = _sortProducts(filtered);

            if (sorted.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  child: Center(
                    child: DeviceShopStatePanel(
                      icon: _categoryIcon,
                      title: context.l10n.categoryProductsNotFound,
                      description: context.l10n.categoryProductsTryFilters,
                      actionLabel: _hasActiveFilters
                          ? context.l10n.categoryProductsClearFilters
                          : null,
                      actionIcon: _hasActiveFilters ? Icons.tune : null,
                      onAction: _hasActiveFilters ? _clearFilters : null,
                      compact: true,
                    ),
                  ),
                ),
              );
            }

            return SliverMainAxisGroup(
              slivers: [
                if (_hasActiveFilters)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spacing16,
                        AppTheme.spacing0,
                        AppTheme.spacing16,
                        AppTheme.spacing12,
                      ),
                      child: GradientBorderContainer(
                        borderRadius: AppTheme.radius18,
                        borderWidth: 1,
                        accentOpacity: 0.24,
                        padding: const EdgeInsets.all(AppTheme.spacing14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.categoryProductsResultCount(
                                  sorted.length,
                                ),
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DeviceShopSecondaryButton(
                              label: context.l10n.categoryProductsClearFilters,
                              icon: Icons.tune,
                              onTap: _clearFilters,
                            ),
                          ],
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.62,
                          crossAxisSpacing: AppTheme.spacing12,
                          mainAxisSpacing: AppTheme.spacing12,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return ProductCard(product: sorted[index]);
                    }, childCount: sorted.length),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  IconData get _categoryIcon {
    switch (widget.category) {
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

  bool get _hasActiveFilters {
    return _inStockOnly ||
        _priceRange.start > 0 ||
        _priceRange.end < 1000 ||
        _selectedBands.isNotEmpty;
  }

  void _clearFilters() {
    setState(() {
      _inStockOnly = false;
      _priceRange = const RangeValues(0, 1000);
      _selectedBands = [];
    });
  }

  List<ShopProduct> _filterProducts(List<ShopProduct> products) {
    return products.where((p) {
      if (_inStockOnly && !p.isInStock) return false;
      if (p.price < _priceRange.start || p.price > _priceRange.end) {
        return false;
      }
      if (_selectedBands.isNotEmpty) {
        final hasBand = _selectedBands.any(
          (band) => p.frequencyBands.contains(band),
        );
        if (!hasBand) return false;
      }
      return true;
    }).toList();
  }

  List<ShopProduct> _sortProducts(List<ShopProduct> products) {
    final sorted = List<ShopProduct>.from(products);
    switch (_sortBy) {
      case 'popular':
        sorted.sort((a, b) => b.salesCount.compareTo(a.salesCount));
        break;
      case 'newest':
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'price_low':
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_high':
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
        break;
    }
    return sorted;
  }

  PopupMenuItem<String> _sortMenuItem(String value, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          if (_sortBy == value)
            Icon(Icons.check, color: context.accentColor, size: 18)
          else
            const SizedBox(width: AppTheme.spacing18),
          const SizedBox(width: AppTheme.spacing8),
          Text(label, style: TextStyle(color: context.textPrimary)),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    AppBottomSheet.showScrollable<void>(
      context: context,
      title: context.l10n.categoryProductsFiltersTitle,
      initialChildSize: 0.76,
      footer: SizedBox(
        width: double.infinity,
        child: DeviceShopPrimaryButton(
          label: context.l10n.categoryProductsApplyFilters,
          icon: Icons.tune,
          onTap: () => Navigator.pop(context),
          animate: true,
        ),
      ),
      builder: (scrollController) => StatefulBuilder(
        builder: (context, setSheetState) {
          void sync(VoidCallback updates) {
            updates();
            setSheetState(() {});
            setState(() {});
          }

          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing24,
              AppTheme.spacing0,
              AppTheme.spacing24,
              AppTheme.spacing8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.categoryProductsResultCount(
                          _sortProducts(
                            _filterProducts(
                              ref
                                      .read(
                                        lilygoCategoryProductsProvider(
                                          widget.category,
                                        ),
                                      )
                                      .value ??
                                  const [],
                            ),
                          ).length,
                        ),
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DeviceShopSecondaryButton(
                      label: context.l10n.categoryProductsReset,
                      icon: Icons.refresh,
                      onTap: () => sync(() {
                        _inStockOnly = false;
                        _priceRange = const RangeValues(0, 1000);
                        _selectedBands = [];
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing16),
                GradientBorderContainer(
                  borderRadius: AppTheme.radius18,
                  borderWidth: 1,
                  accentOpacity: 0.22,
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.categoryProductsInStockOnly,
                              style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spacing4),
                            Text(
                              context.l10n.shopFavoritesInStock,
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ThemedSwitch(
                        value: _inStockOnly,
                        onChanged: (value) => sync(() => _inStockOnly = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                GradientBorderContainer(
                  borderRadius: AppTheme.radius18,
                  borderWidth: 1,
                  accentOpacity: 0.22,
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.categoryProductsPriceRange,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '\$${_priceRange.start.round()}',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '\$${_priceRange.end.round()}',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      RangeSlider(
                        values: _priceRange,
                        min: 0,
                        max: 1000,
                        divisions: 20,
                        activeColor: context.accentColor,
                        onChanged: (value) => sync(() => _priceRange = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                GradientBorderContainer(
                  borderRadius: AppTheme.radius18,
                  borderWidth: 1,
                  accentOpacity: 0.22,
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.categoryProductsFrequencyBands,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      Wrap(
                        spacing: AppTheme.spacing8,
                        runSpacing: AppTheme.spacing8,
                        children: FrequencyBand.values.map((band) {
                          final isSelected = _selectedBands.contains(band);
                          return DeviceShopChoiceChip(
                            label: band.displayLabel(context.l10n),
                            icon: Icons.radio,
                            isSelected: isSelected,
                            onTap: () => sync(() {
                              if (isSelected) {
                                _selectedBands = _selectedBands
                                    .where((b) => b != band)
                                    .toList();
                              } else {
                                _selectedBands = [..._selectedBands, band];
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
