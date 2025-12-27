import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import 'product_detail_screen.dart';

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
    final productsAsync = ref.watch(categoryProductsProvider(widget.category));

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.card,
        title: Text(
          widget.category.label,
          style: TextStyle(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context),
            tooltip: 'Filter',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            color: context.card,
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (context) => [
              _sortMenuItem('popular', 'Most Popular'),
              _sortMenuItem('newest', 'Newest First'),
              _sortMenuItem('price_low', 'Price: Low to High'),
              _sortMenuItem('price_high', 'Price: High to Low'),
              _sortMenuItem('rating', 'Highest Rated'),
            ],
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading products',
                style: TextStyle(color: context.textPrimary),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(categoryProductsProvider(widget.category)),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
        data: (products) {
          final filtered = _filterProducts(products);
          final sorted = _sortProducts(filtered);

          if (sorted.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_categoryIcon, color: context.textTertiary, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'No products found',
                    style: TextStyle(color: context.textPrimary, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Try adjusting your filters',
                    style: TextStyle(color: context.textSecondary),
                  ),
                  if (_hasActiveFilters)
                    TextButton(
                      onPressed: _clearFilters,
                      child: Text('Clear Filters'),
                    ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Active filters chip
              if (_hasActiveFilters)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${sorted.length} products',
                        style: TextStyle(color: context.textSecondary),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: Icon(Icons.clear, size: 18),
                        label: Text('Clear Filters'),
                        style: TextButton.styleFrom(
                          foregroundColor: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

              // Product grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    return _ProductGridCard(product: sorted[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
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
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              _inStockOnly = false;
                              _priceRange = const RangeValues(0, 1000);
                              _selectedBands = [];
                            });
                          },
                          child: Text('Reset'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // In Stock Only
                    SwitchListTile(
                      title: Text(
                        'In Stock Only',
                        style: TextStyle(color: Colors.white),
                      ),
                      value: _inStockOnly,
                      onChanged: (v) {
                        setSheetState(() => _inStockOnly = v);
                        setState(() => _inStockOnly = v);
                      },
                      thumbColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return context.accentColor;
                        }
                        return null;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return context.accentColor.withValues(alpha: 0.5);
                        }
                        return null;
                      }),
                    ),
                    SizedBox(height: 16),

                    // Price Range
                    Text(
                      'Price Range',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${_priceRange.start.round()}',
                          style: TextStyle(color: context.textSecondary),
                        ),
                        Text(
                          '\$${_priceRange.end.round()}',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      ],
                    ),
                    RangeSlider(
                      values: _priceRange,
                      min: 0,
                      max: 1000,
                      divisions: 20,
                      activeColor: context.accentColor,
                      onChanged: (v) {
                        setSheetState(() => _priceRange = v);
                        setState(() => _priceRange = v);
                      },
                    ),
                    const SizedBox(height: 24),

                    // Frequency Bands
                    Text(
                      'Frequency Bands',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: FrequencyBand.values.map((band) {
                        final isSelected = _selectedBands.contains(band);
                        return FilterChip(
                          label: Text(band.label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                _selectedBands = [..._selectedBands, band];
                              } else {
                                _selectedBands = _selectedBands
                                    .where((b) => b != band)
                                    .toList();
                              }
                            });
                            setState(() {});
                          },
                          selectedColor: context.accentColor.withValues(
                            alpha: 0.3,
                          ),
                          checkmarkColor: context.accentColor,
                          backgroundColor: context.background,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? context.accentColor
                                : context.textSecondary,
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 32),

                    // Apply button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Apply Filters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Product card for grid view
class _ProductGridCard extends ConsumerWidget {
  final ShopProduct product;

  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: product.primaryImage != null
                        ? Image.network(
                            product.primaryImage!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _placeholder(context),
                          )
                        : _placeholder(context),
                  ),
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
                          color: Colors.red,
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
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        color: Colors.white,
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
                          SizedBox(width: 4),
                          Text(
                            product.formattedComparePrice!,
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (product.reviewCount > 0) ...[
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 12),
                          const SizedBox(width: 2),
                          Text(
                            '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontSize: 10,
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
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: context.background,
      child: Center(
        child: Icon(Icons.router, color: context.textTertiary, size: 40),
      ),
    );
  }
}
