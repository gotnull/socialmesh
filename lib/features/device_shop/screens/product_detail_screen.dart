// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — CustomScrollView with image gallery sliver
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../../core/logging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/l10n/l10n_extension.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/bottom_action_bar.dart';
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
import '../widgets/device_shop_components.dart';
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
        title: context.l10n.productDetailTitle,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.accentColor,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    context.l10n.productDetailTitle,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      error: (e, _) => GlassScaffold(
        title: context.l10n.productDetailTitle,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Center(
                child: DeviceShopStatePanel(
                  icon: Icons.error_outline,
                  title: context.l10n.productDetailErrorLoading,
                  description: context.l10n.deviceShopTryAgain,
                  actionLabel: context.l10n.productDetailGoBack,
                  actionIcon: Icons.arrow_back,
                  onAction: () => Navigator.pop(context),
                  accentColor: AppTheme.errorRed,
                  compact: true,
                ),
              ),
            ),
          ),
        ],
      ),
      data: (product) {
        if (product == null) {
          return GlassScaffold(
            title: context.l10n.productDetailTitle,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing24),
                  child: Center(
                    child: DeviceShopStatePanel(
                      icon: Icons.search_off,
                      title: context.l10n.productDetailNotFound,
                      description: context.l10n.deviceShopTryAgain,
                      actionLabel: context.l10n.productDetailGoBack,
                      actionIcon: Icons.arrow_back,
                      onAction: () => Navigator.pop(context),
                      compact: true,
                    ),
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
      leading: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing8),
        child: DeviceShopIconOrb(
          icon: Icons.arrow_back,
          color: Colors.white,
          size: 38,
          onTap: () => Navigator.pop(context),
        ),
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
        Padding(
          padding: const EdgeInsets.only(right: AppTheme.spacing4),
          child: DeviceShopIconOrb(
            icon: isFavorite ? Icons.favorite : Icons.favorite_outline,
            color: isFavorite ? AppTheme.errorRed : Colors.white,
            size: 38,
            onTap: () {
              if (userId != null) {
                toggleFavoriteQueued(
                  ref,
                  userId: userId,
                  productId: product.id,
                );
              } else {
                showSignInRequiredSnackBar(
                  context,
                  context.l10n.productDetailSignInFavorites,
                );
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppTheme.spacing8),
          child: DeviceShopIconOrb(
            icon: Icons.share,
            color: Colors.white,
            size: 38,
            onTap: () => _shareProduct(product),
          ),
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
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showFullscreenImage(product.imageUrls, index);
                    },
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
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.only(top: 24, bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      product.imageUrls.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: index == _currentImageIndex ? 20 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppTheme.radius4),
                          color: index == _currentImageIndex
                              ? context.accentColor
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Sale badge
            if (product.isOnSale)
              Positioned(
                top: 140,
                left: 16,
                child: DeviceShopBadgePill(
                  label: context.l10n.productDetailDiscountBadge(
                    product.discountPercent,
                  ),
                  icon: Icons.local_offer,
                  color: AppTheme.errorRed,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductInfo(ShopProduct product) {
    final categoryColor = deviceShopCategoryColor(product.category);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category badge
          BouncyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CategoryProductsScreen(category: product.category),
                ),
              );
            },
            child: DeviceShopInfoPill(
              label: product.category.displayLabel(context.l10n),
              color: categoryColor,
            ),
          ),
          SizedBox(height: AppTheme.spacing12),

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
          const SizedBox(height: AppTheme.spacing8),

          // Seller
          BouncyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      SellerProfileScreen(sellerId: product.sellerId),
                ),
              );
            },
            child: Row(
              children: [
                Text(
                  context.l10n.productDetailBySeller(product.sellerName),
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
                SizedBox(width: AppTheme.spacing4),
                if (product.vendorVerified ||
                    product.sellerName == 'LILYGO') ...[
                  Icon(Icons.verified, size: 16, color: context.accentColor),
                  SizedBox(width: AppTheme.spacing4),
                ],
                Icon(Icons.chevron_right, color: context.accentColor, size: 18),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacing16),

          // Rating & Stats in a premium panel
          GradientBorderContainer(
            borderRadius: AppTheme.radius16,
            borderWidth: 1,
            accentOpacity: 0.2,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing14,
            ),
            child: Row(
              children: [
                if (product.reviewCount > 0) ...[
                  Icon(
                    Icons.star_rounded,
                    color: AppTheme.warningYellow,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    product.rating.toStringAsFixed(1),
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing4),
                  Text(
                    context.l10n.productDetailReviewCount(product.reviewCount),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  _statDivider(),
                ],
                Icon(
                  Icons.remove_red_eye_outlined,
                  color: context.textTertiary,
                  size: 17,
                ),
                SizedBox(width: AppTheme.spacing4),
                Text(
                  '${product.viewCount}',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
                _statDivider(),
                Icon(
                  Icons.shopping_bag_outlined,
                  color: context.textTertiary,
                  size: 17,
                ),
                SizedBox(width: AppTheme.spacing4),
                Text(
                  context.l10n.productDetailSoldCount(product.salesCount),
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacing16),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                product.formattedPrice(context.l10n),
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (product.isOnSale) ...[
                SizedBox(width: AppTheme.spacing12),
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
          SizedBox(height: AppTheme.spacing8),

          // Stock status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: product.isInStock
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                product.isInStock
                    ? context.l10n.productDetailInStockCount(
                        product.stockQuantity,
                      )
                    : context.l10n.productDetailOutOfStock,
                style: TextStyle(
                  color: product.isInStock
                      ? AppTheme.successGreen
                      : AppTheme.errorRed,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Variant selection (if product has options)
          if (product.hasOptions) ...[
            const SizedBox(height: AppTheme.spacing20),
            _buildVariantSelector(product),
          ],

          const SizedBox(height: AppTheme.spacing20),
          Divider(color: context.border.withValues(alpha: 0.5)),
          SizedBox(height: AppTheme.spacing16),

          // Description
          Text(
            context.l10n.productDetailDescription,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
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
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spacing4),
              child: DeviceShopSecondaryButton(
                label: _showFullDescription
                    ? context.l10n.productDetailShowLess
                    : context.l10n.productDetailReadMore,
                icon: _showFullDescription
                    ? Icons.expand_less
                    : Icons.expand_more,
                onTap: () {
                  setState(() => _showFullDescription = !_showFullDescription);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing10),
      child: Container(
        width: 1,
        height: 16,
        color: context.border.withValues(alpha: 0.5),
      ),
    );
  }

  String _truncateDescription(String desc) {
    if (desc.length <= 200) return desc;
    return '${desc.substring(0, 200)}…';
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
          const SizedBox(height: AppTheme.spacing8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: option.values.map((value) {
              final isSelected = _selectedOptions[option.name] == value;

              return DeviceShopChoiceChip(
                label: _formatOptionValue(value),
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _selectedOptions[option.name] = value;
                    // Find matching variant
                    _selectedVariant = _findMatchingVariant(product);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.spacing16),
        ],
        // Show selected variant price if different from base
        if (_selectedVariant != null &&
            _selectedVariant!.price != product.price) ...[
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                context.l10n.productDetailSelectedPrice(
                  _selectedVariant!.price.toStringAsFixed(2),
                ),
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
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.productDetailTechSpecs,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (product.vendorVerified)
                DeviceShopInfoPill(
                  label: context.l10n.productDetailVendorVerified,
                  color: context.accentColor,
                ),
            ],
          ),
          if (product.vendorVerified && product.approvedAt != null) ...[
            const SizedBox(height: AppTheme.spacing6),
            Text(
              context.l10n.productDetailVerifiedOn(
                _formatDate(product.approvedAt!),
              ),
              style: TextStyle(color: context.textTertiary, fontSize: 11),
            ),
          ],
          const SizedBox(height: AppTheme.spacing16),
          GradientBorderContainer(
            borderRadius: AppTheme.radius16,
            borderWidth: 1,
            accentOpacity: 0.22,
            child: Column(
              children: [
                if (product.chipset != null)
                  _specRow(context.l10n.productDetailChipset, product.chipset!),
                if (product.loraChip != null)
                  _specRow(
                    context.l10n.productDetailLoraChip,
                    product.loraChip!,
                  ),
                if (product.frequencyBands.isNotEmpty)
                  _specRow(
                    context.l10n.productDetailFrequencyBands,
                    product.frequencyBands.map((f) => f.label).join(', '),
                  ),
                if (product.batteryCapacity != null)
                  _specRow(
                    context.l10n.productDetailBattery,
                    product.batteryCapacity!,
                  ),
                if (product.dimensions != null)
                  _specRow(
                    context.l10n.productDetailDimensions,
                    product.dimensions!,
                  ),
                if (product.weight != null)
                  _specRow(context.l10n.productDetailWeight, product.weight!),
                if (product.hardwareVersion != null)
                  _specRow(
                    context.l10n.productDetailHardwareVersion,
                    product.hardwareVersion!,
                  ),
                if (product.firmwareVersion != null)
                  _specRow(
                    context.l10n.productDetailFirmware,
                    product.firmwareVersion!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      features.add(
        _FeatureItem(Icons.gps_fixed, context.l10n.productDetailGps, true),
      );
    }
    if (product.hasDisplay) {
      features.add(
        _FeatureItem(
          Icons.screenshot_monitor,
          context.l10n.productDetailDisplay,
          true,
        ),
      );
    }
    if (product.hasBluetooth) {
      features.add(
        _FeatureItem(
          Icons.bluetooth,
          context.l10n.productDetailBluetooth,
          true,
        ),
      );
    }
    if (product.hasWifi) {
      features.add(
        _FeatureItem(Icons.wifi, context.l10n.productDetailWifi, true),
      );
    }
    if (product.isMeshtasticCompatible) {
      features.add(
        _FeatureItem(
          Icons.check_circle,
          context.l10n.productDetailMeshtasticCompatible,
          true,
        ),
      );
    }

    if (features.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.productDetailFeatures,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: features
                .map((f) => _FeatureChip(icon: f.icon, label: f.label))
                .toList(),
          ),
          if (product.includedAccessories.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing20),
            Text(
              context.l10n.productDetailIncludedAccessories,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            ...product.includedAccessories.map(
              (acc) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.check, color: AppTheme.successGreen, size: 18),
                    const SizedBox(width: AppTheme.spacing8),
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
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.productDetailShipping,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          GradientBorderContainer(
            borderRadius: AppTheme.radius16,
            borderWidth: 1,
            accentOpacity: 0.22,
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping,
                      color: context.accentColor,
                      size: 24,
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.shippingCost != null &&
                                    product.shippingCost! > 0
                                ? context.l10n.productDetailShippingCost(
                                    product.shippingCost!.toStringAsFixed(2),
                                  )
                                : context.l10n.productDetailFreeShipping,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (product.estimatedDeliveryDays != null)
                            Text(
                              context.l10n.productDetailEstimatedDelivery(
                                product.estimatedDeliveryDays!,
                              ),
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
                  SizedBox(height: AppTheme.spacing12),
                  Text(
                    product.shippingInfo!,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
                if (product.shipsTo.isNotEmpty) ...[
                  SizedBox(height: AppTheme.spacing12),
                  Row(
                    children: [
                      Icon(Icons.public, color: context.textTertiary, size: 18),
                      SizedBox(width: AppTheme.spacing8),
                      Expanded(
                        child: Text(
                          context.l10n.productDetailShipsTo(
                            product.shipsTo.join(', '),
                          ),
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
    return BottomActionBar(
      horizontalPadding: AppTheme.spacing16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Marketplace disclaimer
          GradientBorderContainer(
            borderRadius: AppTheme.radius12,
            borderWidth: 1,
            accentOpacity: 0.16,
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.accentColor, size: 16),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    context.l10n.productDetailPurchaseDisclaimer,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              // Price summary
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.productDetailTotal,
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
                const SizedBox(width: AppTheme.spacing8),
                DeviceShopSecondaryButton(
                  label: context.l10n.productDetailEdit,
                  icon: Icons.edit,
                  onTap: () {
                    ref.read(productFormProvider.notifier).loadProduct(product);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AdminProductEditScreen(product: product),
                      ),
                    ).then(
                      (_) => ref.invalidate(singleProductProvider(product.id)),
                    );
                  },
                ),
              ],
              const SizedBox(width: AppTheme.spacing8),
              // Buy button
              Expanded(
                child: DeviceShopPrimaryButton(
                  label: product.isInStock
                      ? context.l10n.productDetailBuyNow
                      : context.l10n.productDetailOutOfStockButton,
                  icon: product.isInStock
                      ? Icons.shopping_cart_outlined
                      : Icons.inventory_2_outlined,
                  enabled: product.isInStock,
                  animate: product.isInStock,
                  onTap: () => _buyProduct(product),
                ),
              ),
            ],
          ),
        ],
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

Price: ${product.formattedPrice(context.l10n)}${product.purchaseUrl != null ? '\n\n${product.purchaseUrl}' : ''}''';
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
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.productDetailPurchaseTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.productDetailContactToPurchase,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Row(
            children: [
              Expanded(
                child: DeviceShopSecondaryButton(
                  label: context.l10n.productDetailCancel,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: DeviceShopPrimaryButton(
                  label: context.l10n.productDetailContactSeller,
                  icon: Icons.storefront,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SellerProfileScreen(sellerId: product.sellerId),
                      ),
                    );
                  },
                ),
              ),
            ],
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
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: accentColor.withValues(alpha: 0.7),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              context.l10n.productDetailUnableToLoadPage,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.productDetailWebviewOffline,
              style: TextStyle(color: context.textTertiary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (_errorDescription.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing8),
              Text(
                _errorDescription,
                style: TextStyle(color: context.textTertiary, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppTheme.spacing24),
            FilledButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.l10n.productDetailRetry),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
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
              tooltip: context.l10n.deviceShopGoBackTooltip,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _hasLoadError
                ? _retry
                : () => _webViewController?.reload(),
            tooltip: context.l10n.deviceShopRefreshTooltip,
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
      borderRadius: AppTheme.radius14,
      borderWidth: 1,
      accentOpacity: 0.28,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.accentColor, size: 18),
          SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.productDetailReviews,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              DeviceShopSecondaryButton(
                label: context.l10n.productDetailWriteReview,
                icon: Icons.edit,
                onTap: () => _showWriteReviewSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          reviewsAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
              child: Center(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.accentColor,
                  ),
                ),
              ),
            ),
            error: (error, stack) => Text(
              context.l10n.productDetailUnableToLoadReviews,
              style: TextStyle(color: context.textSecondary),
            ),
            data: (reviews) {
              if (reviews.isEmpty) {
                return DeviceShopStatePanel(
                  icon: Icons.rate_review_outlined,
                  title: context.l10n.productDetailNoReviews,
                  description: context.l10n.productDetailBeFirstReviewer,
                  compact: true,
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
      showSignInRequiredSnackBar(
        context,
        context.l10n.productDetailSignInReview,
      );
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GradientBorderContainer(
        borderRadius: AppTheme.radius16,
        borderWidth: 1,
        accentOpacity: 0.18,
        padding: const EdgeInsets.all(AppTheme.spacing16),
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
                SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            review.userName ??
                                context.l10n.productDetailAnonymous,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (review.isVerifiedPurchase) ...[
                            const SizedBox(width: AppTheme.spacing8),
                            DeviceShopInfoPill(
                              label: context.l10n.productDetailReviewVerified,
                              color: AppTheme.successGreen,
                            ),
                          ],
                        ],
                      ),
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (i) => Icon(
                              i < review.rating
                                  ? Icons.star
                                  : Icons.star_outline,
                              color: AppTheme.warningYellow,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            _formatDate(context, review.createdAt),
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
              SizedBox(height: AppTheme.spacing12),
              Text(
                review.title!,
                style: TextStyle(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (review.body != null) ...[
              const SizedBox(height: AppTheme.spacing8),
              Text(
                review.body!,
                style: TextStyle(color: context.textSecondary, height: 1.5),
              ),
            ],
            if (review.sellerResponse != null) ...[
              SizedBox(height: AppTheme.spacing12),
              GradientBorderContainer(
                borderRadius: AppTheme.radius12,
                borderWidth: 1,
                accentOpacity: 0.2,
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: context.accentColor, size: 16),
                        SizedBox(width: AppTheme.spacing6),
                        Text(
                          context.l10n.productDetailSellerResponse,
                          style: TextStyle(
                            color: context.accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppTheme.spacing8),
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
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return context.l10n.productDetailToday;
    if (diff.inDays == 1) return context.l10n.productDetailYesterday;
    if (diff.inDays < 7) return context.l10n.productDetailDaysAgo(diff.inDays);
    if (diff.inDays < 30) {
      return context.l10n.productDetailWeeksAgo(diff.inDays ~/ 7);
    }
    if (diff.inDays < 365) {
      return context.l10n.productDetailMonthsAgo(diff.inDays ~/ 30);
    }
    return context.l10n.productDetailYearsAgo(diff.inDays ~/ 365);
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
        padding: const EdgeInsets.all(AppTheme.spacing20),
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
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                ),
              ),
              SizedBox(height: AppTheme.spacing20),
              Text(
                context.l10n.productDetailWriteReviewTitle,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),

              // Privacy notice
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
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
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        context.l10n.productDetailReviewPrivacyNotice(
                          widget.userName ??
                              context.l10n.productDetailAnonymous,
                        ),
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),

              // Rating
              Text(
                context.l10n.productDetailYourRating,
                style: TextStyle(color: context.textSecondary),
              ),
              SizedBox(height: AppTheme.spacing8),
              Row(
                children: List.generate(
                  5,
                  (i) => IconButton(
                    icon: Icon(
                      i < _rating ? Icons.star : Icons.star_outline,
                      color: AppTheme.warningYellow,
                      size: 32,
                    ),
                    onPressed: () => setState(() => _rating = i + 1),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),

              // Title
              TextField(
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                maxLength: 100,
                controller: _titleController,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: context.l10n.productDetailReviewTitleLabel,
                  labelStyle: TextStyle(color: context.textSecondary),
                  filled: true,
                  fillColor: context.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    borderSide: BorderSide.none,
                  ),
                  counterText: '',
                ),
              ),
              SizedBox(height: AppTheme.spacing16),

              // Body
              TextFormField(
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                maxLength: 1000,
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                style: TextStyle(color: context.textPrimary),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return context.l10n.productDetailReviewValidation;
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: context.l10n.productDetailYourReview,
                  labelStyle: TextStyle(color: context.textSecondary),
                  hintText: context.l10n.productDetailReviewHint,
                  hintStyle: TextStyle(color: context.textTertiary),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: context.background,
                  errorStyle: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    borderSide: BorderSide(
                      color: context.accentColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                      width: 2,
                    ),
                  ),
                  counterText: '',
                ),
              ),
              SizedBox(height: AppTheme.spacing24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: DeviceShopPrimaryButton(
                  label: context.l10n.productDetailSubmitReview,
                  icon: Icons.send,
                  enabled: !_isSubmitting,
                  onTap: _submitReview,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
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
    final reviewSubmittedMsg = context.l10n.productDetailReviewSubmitted;

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
      safeShowSnackBar(reviewSubmittedMsg);
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(
          context,
          context.l10n.deviceShopReviewSubmitFailed('$e'),
        );
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
          context.l10n.productDetailImageCounter(
            _currentIndex + 1,
            widget.images.length,
          ),
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
