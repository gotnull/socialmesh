// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/logging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/safety/lifecycle_mixin.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/share_utils.dart';
import '../../../utils/snackbar.dart';
import '../models/shop_models.dart';
import '../providers/admin_shop_providers.dart';
import '../providers/device_shop_providers.dart';
import 'category_products_screen.dart';
import 'admin_products_screen.dart';

import 'seller_profile_screen.dart';

/// Product detail screen with full specs, images, and reviews
class ProductDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen>
    with LifecycleSafeMixin {
  int _currentImageIndex = 0;
  bool _showFullDescription = false;
  late ScrollController _scrollController;
  bool _showTitle = false;

  // Variant selection state
  ProductVariant? _selectedVariant;
  final Map<String, String> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    // Increment view count
    Future.microtask(() {
      ref.read(deviceShopServiceProvider).incrementViewCount(widget.productId);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show title when scrolled past image (350px expandedHeight)
    final shouldShowTitle =
        _scrollController.hasClients && _scrollController.offset > 300;
    if (shouldShowTitle != _showTitle) {
      setState(() => _showTitle = shouldShowTitle);
    }
  }

  /// Styled icon button with semi-transparent background for visibility over images
  Widget _buildStyledIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: context.background.withValues(alpha: 0.7),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? context.textPrimary, size: 22),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(singleProductProvider(widget.productId));
    final user = ref.watch(currentUserProvider);
    final favoriteIdsAsync = user != null
        ? ref.watch(userFavoriteIdsProvider(user.uid))
        : const AsyncValue<Set<String>>.data({});
    final isAdminAsync = ref.watch(isShopAdminProvider);

    return productAsync.when(
      loading: () => GlassScaffold(
        title: 'Product',
        slivers: [
          SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
      error: (e, _) => GlassScaffold(
        title: 'Product',
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading product',
                    style: TextStyle(color: context.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      data: (product) {
        if (product == null) {
          return GlassScaffold(
            title: 'Product',
            slivers: [
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        color: context.textTertiary,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Product not found',
                        style: TextStyle(color: context.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Go Back'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final isFavorite =
            favoriteIdsAsync.value?.contains(product.id) ?? false;

        return Scaffold(
          backgroundColor: context.background,
          bottomNavigationBar: _buildBottomBar(
            product,
            isAdminAsync.value ?? false,
          ),
          body: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App Bar with Image Gallery
              _buildImageGallery(
                product,
                isFavorite,
                user?.uid,
                isAdminAsync.value ?? false,
              ),

              // Product Info
              SliverToBoxAdapter(child: _buildProductInfo(product)),

              // Technical Specs
              if (_hasSpecs(product))
                SliverToBoxAdapter(child: _buildSpecsSection(product)),

              // Features
              SliverToBoxAdapter(child: _buildFeaturesSection(product)),

              // Shipping Info
              SliverToBoxAdapter(child: _buildShippingSection(product)),

              // Reviews Section
              SliverToBoxAdapter(child: _ReviewsSection(productId: product.id)),

              // Bottom padding for buy button
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageGallery(
    ShopProduct product,
    bool isFavorite,
    String? userId,
    bool isAdmin,
  ) {
    return SliverAppBar(
      backgroundColor: context.card,
      expandedHeight: 350,
      pinned: true,
      leading: _buildStyledIconButton(
        icon: Icons.arrow_back,
        onPressed: () => Navigator.pop(context),
      ),
      title: _showTitle
          ? AutoScrollText(
              product.name,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              velocity: 40.0,
              fadeWidth: 30.0,
            )
          : null,
      actions: [
        _buildStyledIconButton(
          icon: isFavorite ? Icons.favorite : Icons.favorite_outline,
          iconColor: isFavorite ? Colors.red : null,
          onPressed: () {
            if (userId != null) {
              ref
                  .read(deviceShopServiceProvider)
                  .toggleFavorite(userId, product.id);
            } else {
              showSignInRequiredSnackBar(context, 'Sign in to save favorites');
            }
          },
        ),
        _buildStyledIconButton(
          icon: Icons.share,
          onPressed: () => _shareProduct(product),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Image PageView
            if (product.imageUrls.isNotEmpty)
              PageView.builder(
                itemCount: product.imageUrls.length,
                onPageChanged: (index) {
                  setState(() => _currentImageIndex = index);
                },
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _showFullscreenImage(product.imageUrls, index),
                    child: Image.network(
                      product.imageUrls[index],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: context.background,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: context.background,
                        child: Icon(
                          Icons.image,
                          color: context.textTertiary,
                          size: 64,
                        ),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                color: context.background,
                child: Center(
                  child: Icon(
                    Icons.router,
                    color: context.textTertiary,
                    size: 80,
                  ),
                ),
              ),

            // Page indicator
            if (product.imageUrls.length > 1)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    product.imageUrls.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentImageIndex
                            ? context.accentColor
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),

            // Sale badge
            if (product.isOnSale)
              Positioned(
                top: 150,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${product.discountPercent}% OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo(ShopProduct product) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CategoryProductsScreen(category: product.category),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                product.category.label,
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(height: 12),

          // Name
          AutoScrollText(
            product.name,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            velocity: 40.0,
            fadeWidth: 30.0,
          ),
          const SizedBox(height: 8),

          // Seller
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SellerProfileScreen(sellerId: product.sellerId),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'by ',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
                Text(
                  product.sellerName,
                  style: TextStyle(
                    color: context.accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: context.accentColor, size: 18),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Rating & Stats
          Row(
            children: [
              if (product.reviewCount > 0) ...[
                Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 4),
                Text(
                  product.rating.toStringAsFixed(1),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${product.reviewCount} reviews)',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
                SizedBox(width: 16),
              ],
              Icon(
                Icons.remove_red_eye_outlined,
                color: context.textTertiary,
                size: 18,
              ),
              SizedBox(width: 4),
              Text(
                '${product.viewCount}',
                style: TextStyle(color: context.textTertiary, fontSize: 14),
              ),
              SizedBox(width: 16),
              Icon(
                Icons.shopping_bag_outlined,
                color: context.textTertiary,
                size: 18,
              ),
              SizedBox(width: 4),
              Text(
                '${product.salesCount} sold',
                style: TextStyle(color: context.textTertiary, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.formattedPrice,
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (product.isOnSale) ...[
                SizedBox(width: 12),
                Text(
                  product.formattedComparePrice!,
                  style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 18,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 8),

          // Stock status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: product.isInStock ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                product.isInStock
                    ? 'In Stock (${product.stockQuantity} available)'
                    : 'Out of Stock',
                style: TextStyle(
                  color: product.isInStock ? Colors.green : Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Variant selection (if product has options)
          if (product.hasOptions) ...[
            const SizedBox(height: 20),
            _buildVariantSelector(product),
          ],

          const SizedBox(height: 20),
          Divider(color: context.border),
          SizedBox(height: 16),

          // Description
          Text(
            'Description',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _showFullDescription
                ? product.description
                : _truncateDescription(product.description),
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          if (product.description.length > 200)
            TextButton(
              onPressed: () {
                setState(() => _showFullDescription = !_showFullDescription);
              },
              child: Text(
                _showFullDescription ? 'Show Less' : 'Read More',
                style: TextStyle(color: context.accentColor),
              ),
            ),
        ],
      ),
    );
  }

  String _truncateDescription(String desc) {
    if (desc.length <= 200) return desc;
    return '${desc.substring(0, 200)}...';
  }

  /// Build the variant selector UI
  Widget _buildVariantSelector(ShopProduct product) {
    // Initialize selected variant if not set
    if (_selectedVariant == null && product.variants.isNotEmpty) {
      _selectedVariant = product.defaultVariant;
      // Initialize selected options from default variant
      if (_selectedVariant != null) {
        if (_selectedVariant!.option1 != null && product.options.isNotEmpty) {
          _selectedOptions[product.options[0].name] =
              _selectedVariant!.option1!;
        }
        if (_selectedVariant!.option2 != null && product.options.length > 1) {
          _selectedOptions[product.options[1].name] =
              _selectedVariant!.option2!;
        }
        if (_selectedVariant!.option3 != null && product.options.length > 2) {
          _selectedOptions[product.options[2].name] =
              _selectedVariant!.option3!;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final option in product.options) ...[
          Text(
            option.name,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: option.values.map((value) {
              final isSelected = _selectedOptions[option.name] == value;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedOptions[option.name] = value;
                    // Find matching variant
                    _selectedVariant = _findMatchingVariant(product);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor.withValues(alpha: 0.15)
                        : context.card,
                    border: Border.all(
                      color: isSelected ? context.accentColor : context.border,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatOptionValue(value),
                    style: TextStyle(
                      color: isSelected
                          ? context.accentColor
                          : context.textPrimary,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        // Show selected variant price if different from base
        if (_selectedVariant != null &&
            _selectedVariant!.price != product.price) ...[
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: context.accentColor),
              const SizedBox(width: 6),
              Text(
                'Selected: \$${_selectedVariant!.price.toStringAsFixed(2)}',
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Find the variant matching current option selections
  ProductVariant? _findMatchingVariant(ShopProduct product) {
    for (final variant in product.variants) {
      bool matches = true;

      if (product.options.isNotEmpty) {
        final opt1 = _selectedOptions[product.options[0].name];
        if (opt1 != null && variant.option1 != opt1) matches = false;
      }
      if (product.options.length > 1) {
        final opt2 = _selectedOptions[product.options[1].name];
        if (opt2 != null && variant.option2 != opt2) matches = false;
      }
      if (product.options.length > 2) {
        final opt3 = _selectedOptions[product.options[2].name];
        if (opt3 != null && variant.option3 != opt3) matches = false;
      }

      if (matches) return variant;
    }
    return product.defaultVariant;
  }

  /// Format option value for display (clean up SKU codes)
  String _formatOptionValue(String value) {
    // Remove SKU codes in brackets like "[K257-01]" for cleaner display
    return value.replaceAll(RegExp(r'\s*\[[^\]]+\]'), '').trim();
  }

  /// Get the effective price (selected variant or base price)
  double _getEffectivePrice(ShopProduct product) {
    return _selectedVariant?.price ?? product.price;
  }

  bool _hasSpecs(ShopProduct product) {
    return product.chipset != null ||
        product.loraChip != null ||
        product.frequencyBands.isNotEmpty ||
        product.batteryCapacity != null ||
        product.dimensions != null;
  }

  Widget _buildSpecsSection(ShopProduct product) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Technical Specifications',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (product.vendorVerified)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: context.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified,
                        size: 14,
                        color: context.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Vendor Verified',
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (product.vendorVerified && product.approvedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Verified on ${_formatDate(product.approvedAt!)}',
              style: TextStyle(color: context.textTertiary, fontSize: 11),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Column(
              children: [
                if (product.chipset != null)
                  _specRow('Chipset', product.chipset!),
                if (product.loraChip != null)
                  _specRow('LoRa Chip', product.loraChip!),
                if (product.frequencyBands.isNotEmpty)
                  _specRow(
                    'Frequency Bands',
                    product.frequencyBands.map((f) => f.label).join(', '),
                  ),
                if (product.batteryCapacity != null)
                  _specRow('Battery', product.batteryCapacity!),
                if (product.dimensions != null)
                  _specRow('Dimensions', product.dimensions!),
                if (product.weight != null) _specRow('Weight', product.weight!),
                if (product.hardwareVersion != null)
                  _specRow('Hardware Version', product.hardwareVersion!),
                if (product.firmwareVersion != null)
                  _specRow('Firmware', product.firmwareVersion!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesSection(ShopProduct product) {
    final features = <_FeatureItem>[];

    if (product.hasGps) {
      features.add(_FeatureItem(Icons.gps_fixed, 'GPS', true));
    }
    if (product.hasDisplay) {
      features.add(_FeatureItem(Icons.screenshot_monitor, 'Display', true));
    }
    if (product.hasBluetooth) {
      features.add(_FeatureItem(Icons.bluetooth, 'Bluetooth', true));
    }
    if (product.hasWifi) {
      features.add(_FeatureItem(Icons.wifi, 'WiFi', true));
    }
    if (product.isMeshtasticCompatible) {
      features.add(
        _FeatureItem(Icons.check_circle, 'Meshtastic Compatible', true),
      );
    }

    if (features.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Features',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features
                .map((f) => _FeatureChip(icon: f.icon, label: f.label))
                .toList(),
          ),
          if (product.includedAccessories.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Included Accessories',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...product.includedAccessories.map(
              (acc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check, color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    Text(acc, style: TextStyle(color: context.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShippingSection(ShopProduct product) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shipping',
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping,
                      color: context.accentColor,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.shippingCost != null &&
                                    product.shippingCost! > 0
                                ? 'Shipping: \$${product.shippingCost!.toStringAsFixed(2)}'
                                : 'Free Shipping',
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (product.estimatedDeliveryDays != null)
                            Text(
                              'Estimated ${product.estimatedDeliveryDays} days',
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
                if (product.shippingInfo != null) ...[
                  SizedBox(height: 12),
                  Text(
                    product.shippingInfo!,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (product.shipsTo.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.public, color: context.textTertiary, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ships to: ${product.shipsTo.join(", ")}',
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ShopProduct product, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        border: Border(top: BorderSide(color: context.border)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Marketplace disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: context.background.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.accentColor.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: context.accentColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Purchases completed on seller\'s official store',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                // Price summary
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '\$${_getEffectivePrice(product).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Admin edit button
                if (isAdmin) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref
                          .read(productFormProvider.notifier)
                          .loadProduct(product);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AdminProductEditScreen(product: product),
                        ),
                      ).then(
                        (_) =>
                            ref.invalidate(singleProductProvider(product.id)),
                      );
                    },
                    icon: Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.accentColor,
                      side: BorderSide(color: context.accentColor),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                // Buy button
                Expanded(
                  child: ElevatedButton(
                    onPressed: product.isInStock
                        ? () => _buyProduct(product)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: context.border,
                    ),
                    child: Text(
                      product.isInStock ? 'Buy Now' : 'Out of Stock',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _showFullscreenImage(List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _FullscreenGallery(images: images, initialIndex: initialIndex),
      ),
    );
  }

  void _shareProduct(ShopProduct product) {
    final text =
        '''Check out ${product.name} on Socialmesh!

${product.shortDescription ?? product.description}

Price: ${product.formattedPrice}${product.purchaseUrl != null ? '\n\n${product.purchaseUrl}' : ''}''';
    shareText(text, subject: product.name, context: context);
  }

  Future<void> _buyProduct(ShopProduct product) async {
    // Capture navigator before async gap
    final navigator = Navigator.of(context);

    // Log the buy now tap
    final logger = ref.read(deviceShopEventLoggerProvider);
    await logger.logBuyNowTap(
      sellerId: product.sellerId,
      sellerName: product.sellerName,
      productId: product.id,
      productName: product.name,
      category: product.category.name,
      price: product.price,
      currency: product.currency,
      destinationUrl: product.purchaseUrl ?? 'no-url',
      screen: 'detail',
    );

    if (!mounted) return;

    if (product.purchaseUrl != null) {
      // Open purchase URL in in-app webview
      navigator.push(
        MaterialPageRoute(
          builder: (_) => _PurchaseWebViewScreen(
            title: product.name,
            url: product.purchaseUrl!,
          ),
        ),
      );
    } else {
      // Show in-app purchase dialog
      _showPurchaseDialog(product);
    }
  }

  void _showPurchaseDialog(ShopProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        title: Text('Purchase', style: TextStyle(color: context.textPrimary)),
        content: Text(
          'Contact the seller to purchase this product.',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SellerProfileScreen(sellerId: product.sellerId),
                ),
              );
            },
            child: Text('Contact Seller'),
          ),
        ],
      ),
    );
  }
}

/// In-app webview for purchase URLs
class _PurchaseWebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const _PurchaseWebViewScreen({required this.title, required this.url});

  @override
  State<_PurchaseWebViewScreen> createState() => _PurchaseWebViewScreenState();
}

class _PurchaseWebViewScreenState extends State<_PurchaseWebViewScreen> {
  double _progress = 0;
  InAppWebViewController? _webViewController;
  bool _canGoBack = false;
  bool _hasLoadError = false;
  String _errorDescription = '';

  void _retry() {
    setState(() {
      _hasLoadError = false;
      _errorDescription = '';
      _progress = 0;
    });
    _webViewController?.loadUrl(
      urlRequest: URLRequest(url: WebUri(widget.url)),
    );
  }

  Widget _buildOfflinePlaceholder(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
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
              'Unable to load page',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This content requires an internet connection. '
              'Please check your connection and try again.',
              style: TextStyle(color: context.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_errorDescription.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorDescription,
                style: TextStyle(color: context.textTertiary, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: Text(
          widget.title,
          style: context.titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _webViewController?.goBack(),
              tooltip: 'Go back',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _hasLoadError
                ? _retry
                : () => _webViewController?.reload(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator (only when loading and no error)
          if (_progress < 1.0 && !_hasLoadError)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: context.card,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 2,
            ),
          // Content: either the WebView or the offline placeholder
          Expanded(
            child: _hasLoadError
                ? _buildOfflinePlaceholder(context)
                : InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                    initialSettings: InAppWebViewSettings(
                      transparentBackground: true,
                      javaScriptEnabled: true,
                      useShouldOverrideUrlLoading: false,
                      mediaPlaybackRequiresUserGesture: false,
                      allowsInlineMediaPlayback: true,
                      iframeAllowFullscreen: true,
                    ),
                    onWebViewCreated: (controller) {
                      _webViewController = controller;
                    },
                    onLoadStart: (controller, url) {
                      if (mounted) {
                        setState(() {
                          _progress = 0;
                          _hasLoadError = false;
                          _errorDescription = '';
                        });
                      }
                    },
                    onProgressChanged: (controller, progress) {
                      if (mounted) setState(() => _progress = progress / 100);
                    },
                    onLoadStop: (controller, url) async {
                      if (!mounted) return;
                      setState(() => _progress = 1.0);
                      final canGoBack = await controller.canGoBack();
                      if (mounted) setState(() => _canGoBack = canGoBack);
                    },
                    onReceivedError: (controller, request, error) {
                      AppLogging.shop(
                        'PurchaseWebView error: type=${error.type}, '
                        'description=${error.description}, '
                        'url=${request.url}',
                      );

                      final isMainFrame = request.url.toString() == widget.url;

                      final isConnectivityError =
                          error.type == WebResourceErrorType.HOST_LOOKUP ||
                          error.type ==
                              WebResourceErrorType.CANNOT_CONNECT_TO_HOST ||
                          error.type ==
                              WebResourceErrorType.NOT_CONNECTED_TO_INTERNET ||
                          error.type == WebResourceErrorType.TIMEOUT ||
                          error.type ==
                              WebResourceErrorType.NETWORK_CONNECTION_LOST;

                      if (isMainFrame || isConnectivityError) {
                        if (mounted) {
                          setState(() {
                            _hasLoadError = true;
                            _errorDescription = error.description;
                          });
                        }
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;
  final bool available;

  _FeatureItem(this.icon, this.label, this.available);
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return GradientBorderContainer(
      borderRadius: 8,
      borderWidth: 2,
      accentOpacity: 0.3,
      backgroundColor: context.accentColor.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.accentColor, size: 18),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reviews section widget
class _ReviewsSection extends ConsumerWidget {
  final String productId;

  const _ReviewsSection({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(productReviewsProvider(productId));

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showWriteReviewSheet(context, ref),
                icon: Icon(Icons.edit, size: 18),
                label: Text('Write Review'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          reviewsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text(
              'Unable to load reviews',
              style: TextStyle(color: context.textSecondary),
            ),
            data: (reviews) {
              if (reviews.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.rate_review_outlined,
                          color: context.textTertiary,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No reviews yet',
                          style: TextStyle(color: context.textSecondary),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Be the first to review this product!',
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: reviews
                    .take(5)
                    .map((review) => _ReviewCard(review: review))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showWriteReviewSheet(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      showSignInRequiredSnackBar(context, 'Sign in to write a review');
      return;
    }

    // Use profile display name, not Firebase Auth displayName
    final displayName = ref.read(profileDisplayNameProvider);
    final profile = ref.read(userProfileProvider).value;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _WriteReviewSheet(
        productId: productId,
        userId: user.uid,
        userName: displayName,
        userPhotoUrl: profile?.avatarUrl ?? user.photoURL,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ProductReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                imageUrl: review.userPhotoUrl,
                size: 36,
                backgroundColor: context.background,
                foregroundColor: context.textTertiary,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          review.userName ?? 'Anonymous',
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (review.isVerifiedPurchase) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Verified',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        ...List.generate(
                          5,
                          (i) => Icon(
                            i < review.rating ? Icons.star : Icons.star_outline,
                            color: Colors.amber,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(review.createdAt),
                          style: TextStyle(
                            color: context.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.title != null) ...[
            SizedBox(height: 12),
            Text(
              review.title!,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (review.body != null) ...[
            const SizedBox(height: 8),
            Text(
              review.body!,
              style: TextStyle(color: context.textSecondary, height: 1.5),
            ),
          ],
          if (review.sellerResponse != null) ...[
            SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, color: context.accentColor, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Seller Response',
                        style: TextStyle(
                          color: context.accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    review.sellerResponse!,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${diff.inDays ~/ 7} weeks ago';
    if (diff.inDays < 365) return '${diff.inDays ~/ 30} months ago';
    return '${diff.inDays ~/ 365} years ago';
  }
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final String productId;
  final String userId;
  final String? userName;
  final String? userPhotoUrl;

  const _WriteReviewSheet({
    required this.productId,
    required this.userId,
    this.userName,
    this.userPhotoUrl,
  });

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet>
    with LifecycleSafeMixin {
  int _rating = 5;
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _bodyFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  bool _showValidation = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: _showValidation
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              SizedBox(height: 20),
              Text(
                'Write a Review',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Privacy notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: context.accentColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your review will be public and posted as "${widget.userName ?? 'Anonymous'}". Reviews are moderated before appearing on the product page.',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Rating
              Text(
                'Your Rating',
                style: TextStyle(color: context.textSecondary),
              ),
              SizedBox(height: 8),
              Row(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      i < _rating ? Icons.star : Icons.star_outline,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setState(() => _rating = i + 1),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: _titleController,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Title (optional)',
                  labelStyle: TextStyle(color: context.textSecondary),
                  filled: true,
                  fillColor: context.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Body
              TextFormField(
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                style: TextStyle(color: context.textPrimary),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please write a review description';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Your Review *',
                  labelStyle: TextStyle(color: context.textSecondary),
                  hintText: 'Share your experience with this product...',
                  hintStyle: TextStyle(color: context.textTertiary),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: context.background,
                  errorStyle: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.accentColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    // Enable validation display
    setState(() => _showValidation = true);

    // Validate form
    if (!_formKey.currentState!.validate()) {
      // Form is invalid, validation errors are now visible
      // Focus the review field to draw attention to the error
      _bodyFocusNode.requestFocus();
      return;
    }

    final reviewText = _bodyController.text.trim();

    // Pre-submission content moderation check
    final moderationService = ref.read(contentModerationServiceProvider);
    final checkResult = await moderationService.checkText(
      reviewText,
      useServerCheck: true,
    );

    if (!checkResult.passed || checkResult.action == 'reject') {
      // Content blocked - show warning and don't proceed
      if (mounted) {
        await ContentModerationWarning.show(
          context,
          result: ContentModerationCheckResult(
            passed: false,
            action: 'reject',
            categories: checkResult.categories.map((c) => c.name).toList(),
            details: checkResult.details,
          ),
        );
      }
      return;
    } else if (checkResult.action == 'review' || checkResult.action == 'flag') {
      // Content flagged - show warning but allow to proceed
      if (mounted) {
        final action = await ContentModerationWarning.show(
          context,
          result: ContentModerationCheckResult(
            passed: true,
            action: checkResult.action,
            categories: checkResult.categories.map((c) => c.name).toList(),
            details: checkResult.details,
          ),
        );
        if (action == ContentModerationAction.cancel) return;
        if (action == ContentModerationAction.edit) {
          // User wants to edit - focus on review field
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _bodyFocusNode.requestFocus();
          });
          return;
        }
        // If action is proceed, continue with review submission
      }
    }

    safeSetState(() => _isSubmitting = true);

    try {
      final shopService = ref.read(deviceShopServiceProvider);
      await shopService.addReview(
        productId: widget.productId,
        oderId: widget.userId,
        userName: widget.userName,
        userPhotoUrl: widget.userPhotoUrl,
        rating: _rating,
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        body: reviewText,
      );

      safeNavigatorPop();
      safeShowSnackBar('Review submitted for moderation. Thank you!');
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to submit review: $e');
      }
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }
}

/// Fullscreen image gallery
class _FullscreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.image, color: Colors.white54, size: 64),
              ),
            ),
          );
        },
      ),
    );
  }
}
