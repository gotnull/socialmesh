// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/shop_models.dart';
import '../providers/admin_shop_providers.dart';
import '../providers/device_shop_providers.dart';

/// Screen for managing featured product ordering via drag-and-drop
class FeaturedProductsScreen extends ConsumerStatefulWidget {
  const FeaturedProductsScreen({super.key});

  @override
  ConsumerState<FeaturedProductsScreen> createState() =>
      _FeaturedProductsScreenState();
}

class _FeaturedProductsScreenState
    extends ConsumerState<FeaturedProductsScreen> {
  List<ShopProduct> _products = [];
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final featuredAsync = ref.watch(adminFeaturedProductsProvider);

    return GlassScaffold(
      title: 'Featured Products',
      actions: [
        if (_hasChanges)
          TextButton.icon(
            onPressed: _isSaving ? null : _saveOrder,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save'),
            style: TextButton.styleFrom(foregroundColor: context.accentColor),
          ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: context.accentColor.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: context.accentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Drag and drop products to reorder. Products at the top will appear first in the featured section.',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        featuredAsync.when(
          data: (products) {
            // Initialize local list on first load
            if (_products.isEmpty && products.isNotEmpty) {
              _products = List.from(products);
            }

            if (_products.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star_border,
                        size: 64,
                        color: context.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text('No featured products', style: context.titleStyle),
                      const SizedBox(height: 8),
                      Text(
                        'Mark products as featured to manage their order here',
                        style: TextStyle(color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverReorderableList(
                itemCount: _products.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return ReorderableDragStartListener(
                    key: ValueKey(product.id),
                    index: index,
                    child: _FeaturedProductItem(
                      product: product,
                      order: index + 1,
                      onRemove: () => _removeFromFeatured(product),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) =>
              SliverFillRemaining(child: Center(child: Text('Error: $e'))),
        ),
        if (_hasChanges)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                color: Colors.amber.withValues(alpha: 0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You have unsaved changes',
                          style: TextStyle(color: Colors.amber),
                        ),
                      ),
                      TextButton(
                        onPressed: _discardChanges,
                        child: const Text('Discard'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _products.removeAt(oldIndex);
      _products.insert(newIndex, item);
      _hasChanges = true;
    });
  }

  Future<void> _saveOrder() async {
    if (!_hasChanges) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(deviceShopServiceProvider);
      final user = ref.read(currentUserProvider);

      // Build the order map
      final orders = <String, int>{};
      for (var i = 0; i < _products.length; i++) {
        orders[_products[i].id] = i;
      }

      await service.updateFeaturedOrders(orders, adminId: user?.uid);

      ref.invalidate(adminFeaturedProductsProvider);
      ref.invalidate(featuredProductsProvider);

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      if (mounted) {
        showSuccessSnackBar(context, 'Featured order updated');
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        showErrorSnackBar(context, 'Error: $e');
      }
    }
  }

  void _discardChanges() {
    ref.invalidate(adminFeaturedProductsProvider);
    setState(() {
      _products = [];
      _hasChanges = false;
    });
  }

  Future<void> _removeFromFeatured(ShopProduct product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Featured'),
        content: Text('Remove "${product.name}" from featured products?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(deviceShopServiceProvider);
        final user = ref.read(currentUserProvider);

        await service.updateProduct(product.id, {
          'isFeatured': false,
        }, adminId: user?.uid);

        setState(() {
          _products.removeWhere((p) => p.id == product.id);
        });

        ref.invalidate(adminFeaturedProductsProvider);
        ref.invalidate(featuredProductsProvider);
        ref.invalidate(adminAllProductsProvider);

        if (mounted) {
          showSuccessSnackBar(context, 'Removed from featured');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Error: $e');
        }
      }
    }
  }
}

class _FeaturedProductItem extends StatelessWidget {
  final ShopProduct product;
  final int order;
  final VoidCallback onRemove;

  const _FeaturedProductItem({
    required this.product,
    required this.order,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Order number
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$order',
                  style: TextStyle(
                    color: context.accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: product.primaryImage != null
                  ? Image.network(
                      product.primaryImage!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _placeholderImage(),
                    )
                  : _placeholderImage(),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        product.formattedPrice,
                        style: TextStyle(
                          color: context.accentColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        product.sellerName,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Remove button
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.red.withValues(alpha: 0.7),
              onPressed: onRemove,
              tooltip: 'Remove from featured',
            ),

            // Drag handle
            Icon(Icons.drag_handle, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 50,
      height: 50,
      color: Colors.grey.withValues(alpha: 0.3),
      child: const Icon(Icons.image, color: Colors.grey),
    );
  }
}
