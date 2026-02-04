// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import 'product_detail_screen.dart';

/// Search screen for finding products
class SearchProductsScreen extends ConsumerStatefulWidget {
  const SearchProductsScreen({super.key});

  @override
  ConsumerState<SearchProductsScreen> createState() =>
      _SearchProductsScreenState();
}

class _SearchProductsScreenState extends ConsumerState<SearchProductsScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  Timer? _debounce;

  final List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = value.trim());
    });
  }

  void _performSearch(String query) {
    _searchController.text = query;
    setState(() => _query = query.trim());
    if (query.isNotEmpty && !_recentSearches.contains(query)) {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    }
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: context.background,
        appBar: AppBar(
          backgroundColor: context.card,
          titleSpacing: 0,
          title: _buildSearchField(),
          actions: [
            if (_query.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _query = '');
                  _focusNode.requestFocus();
                },
              ),
          ],
        ),
        body: _query.isEmpty ? _buildSuggestions() : _buildResults(),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _focusNode,
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search devices, modules, antennas...',
        hintStyle: TextStyle(color: context.textTertiary),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      onChanged: _onSearchChanged,
      onSubmitted: _performSearch,
      textInputAction: TextInputAction.search,
    );
  }

  Widget _buildSuggestions() {
    return SingleChildScrollView(
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
            SizedBox(height: 24),
          ],

          // Trending products
          Text(
            'Trending',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ref
              .watch(lilygoTrendingProductsProvider)
              .when(
                data: (products) => products.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        children: products
                            .map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: context.card,
                                  borderRadius: BorderRadius.circular(12),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => ProductDetailScreen(
                                          productId: p.id,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.trending_up,
                                            size: 18,
                                            color: context.accentColor,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              p.name,
                                              style: TextStyle(
                                                color: context.textPrimary,
                                                fontSize: 14,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 20,
                                            color: context.textTertiary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                loading: () => Column(
                  children: List.generate(
                    4,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                error: (e, _) => const SizedBox.shrink(),
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
              trailing: Icon(Icons.chevron_right, color: context.textTertiary),
              onTap: () => _performSearch(cat.label),
            ),
          ),
        ],
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

  Widget _buildResults() {
    final searchAsync = ref.watch(lilygoSearchProvider(_query));

    return searchAsync.when(
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
            const SizedBox(height: 16),
            Text('Search failed', style: TextStyle(color: context.textPrimary)),
            TextButton(
              onPressed: () => ref.invalidate(lilygoProductsProvider),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
      data: (products) {
        if (products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, color: context.textTertiary, size: 64),
                SizedBox(height: 16),
                Text(
                  'No results for "$_query"',
                  style: TextStyle(color: context.textPrimary, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try different keywords or browse categories',
                  style: TextStyle(color: context.textSecondary),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results count
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${products.length} result${products.length == 1 ? '' : 's'} for "$_query"',
                style: TextStyle(color: context.textSecondary),
              ),
            ),

            // Results list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return _SearchResultCard(product: products[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

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
              SizedBox(width: 6),
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

class _SearchResultCard extends StatelessWidget {
  final ShopProduct product;

  const _SearchResultCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.category.label,
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),

                    // Name
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

                    // Seller
                    Text(
                      product.sellerName,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 6),

                    // Price & Rating
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
                          SizedBox(width: 6),
                          Text(
                            product.formattedComparePrice!,
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (product.reviewCount > 0) ...[
                          Icon(Icons.star, color: Colors.amber, size: 14),
                          SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Stock indicator
              if (!product.isInStock)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Out of Stock',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
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
}
