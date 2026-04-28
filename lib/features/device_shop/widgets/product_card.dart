// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/gradient_border_container.dart';
import 'device_shop_components.dart';
import '../../../core/widgets/skeleton_config.dart';
import '../../../providers/accessibility_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../utils/snackbar.dart';
import '../models/shop_models.dart';
import '../providers/device_shop_providers.dart';
import '../screens/product_detail_screen.dart';

class ProductCard extends ConsumerStatefulWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.width,
    this.highlightColor,
  });

  final ShopProduct product;
  final double? width;
  final Color? highlightColor;

  @override
  ConsumerState<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<ProductCard>
    with SingleTickerProviderStateMixin, LifecycleSafeMixin<ProductCard> {
  late final AnimationController _heartController;
  late final Animation<double> _heartScale;
  bool _isFavoriteLoading = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _heartScale = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final favoriteIdsAsync = user != null
        ? ref.watch(userFavoriteIdsProvider(user.uid))
        : const AsyncValue<Set<String>>.data({});
    final isFavorite =
        favoriteIdsAsync.value?.contains(widget.product.id) ?? false;
    final reduceMotion = ref.watch(reduceMotionEnabledProvider);
    final accent = _accentColor(context);

    final card = GradientBorderContainer(
      borderRadius: AppTheme.radius18,
      borderWidth: widget.product.isFeatured || widget.product.isOnSale
          ? 1.4
          : 1,
      accentOpacity: widget.product.isFeatured || widget.product.isOnSale
          ? 0.5
          : 0.26,
      accentColor: accent,
      enableDepthBlend: widget.product.isFeatured,
      depthBlendOpacity: 0.08,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius18),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: AppTheme.spacing20 + AppTheme.spacing2,
              offset: const Offset(AppTheme.spacing0, AppTheme.spacing12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(context, isFavorite),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing12,
                  AppTheme.spacing10,
                  AppTheme.spacing12,
                  AppTheme.spacing8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    _buildSellerRow(context),
                    const SizedBox(height: AppTheme.spacing6),
                    Text(
                      widget.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    Wrap(
                      spacing: AppTheme.spacing6,
                      runSpacing: AppTheme.spacing6,
                      children: _metadata(context),
                    ),
                    const Spacer(),
                    _buildPriceRow(context),
                    const SizedBox(height: AppTheme.spacing6),
                    _buildFooter(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final content = BouncyTap(
      enable3DPress: !reduceMotion,
      onTap: _openProduct,
      child: card,
    );

    if (widget.width == null) {
      return content;
    }

    return SizedBox(width: widget.width, child: content);
  }

  Widget _buildImage(BuildContext context, bool isFavorite) {
    return SizedBox(
      height: 136,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radius18),
            ),
            child: widget.product.primaryImage != null
                ? Image.network(
                    widget.product.primaryImage!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }
                      return _imagePlaceholder(context);
                    },
                    errorBuilder: (_, _, _) => _imagePlaceholder(context),
                  )
                : _imagePlaceholder(context),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radius18),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.32),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.18),
                ],
              ),
            ),
          ),
          Positioned(
            top: AppTheme.spacing10,
            left: AppTheme.spacing10,
            right: 52,
            child: Wrap(
              spacing: AppTheme.spacing6,
              runSpacing: AppTheme.spacing6,
              children: [
                if (widget.product.isFeatured)
                  DeviceShopBadgePill(
                    label: context.l10n.deviceShopFeatured,
                    color: AccentColors.yellow,
                    fillOpacity: 0.58,
                  ),
                if (widget.product.isOnSale)
                  DeviceShopBadgePill(
                    label: context.l10n.productDetailDiscountBadge(
                      widget.product.discountPercent,
                    ),
                    icon: Icons.local_offer,
                    color: widget.highlightColor ?? AppTheme.errorRed,
                  ),
              ],
            ),
          ),
          Positioned(
            top: AppTheme.spacing8,
            right: AppTheme.spacing8,
            child: ScaleTransition(
              scale: _heartScale,
              child: _isFavoriteLoading
                  ? Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.36),
                        borderRadius: BorderRadius.circular(AppTheme.radius14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spacing8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.accentColor,
                          ),
                        ),
                      ),
                    )
                  : DeviceShopIconOrb(
                      icon: isFavorite
                          ? Icons.favorite
                          : Icons.favorite_outline,
                      color: isFavorite ? AppTheme.errorRed : Colors.white,
                      onTap: () => _toggleFavorite(
                        ref.watch(currentUserProvider)?.uid,
                        isFavorite: isFavorite,
                      ),
                    ),
            ),
          ),
          if (!widget.product.isInStock)
            Positioned(
              left: AppTheme.spacing10,
              bottom: AppTheme.spacing10,
              child: DeviceShopBadgePill(
                label: context.l10n.deviceShopOutOfStock,
                icon: Icons.inventory_2_outlined,
                color: AppTheme.errorRed,
              ),
            ),
          if (widget.product.reviewCount > 0)
            Positioned(
              right: AppTheme.spacing10,
              bottom: AppTheme.spacing10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppTheme.radius16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AccentColors.yellow,
                    ),
                    const SizedBox(width: AppTheme.spacing4),
                    Text(
                      widget.product.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSellerRow(BuildContext context) {
    final accent = _accentColor(context);
    final verified =
        widget.product.vendorVerified || widget.product.sellerName == 'LILYGO';

    return Row(
      children: [
        Expanded(
          child: Text(
            widget.product.sellerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (verified) Icon(Icons.verified, size: 15, color: accent),
      ],
    );
  }

  List<Widget> _metadata(BuildContext context) {
    final items = <Widget>[
      DeviceShopInfoPill(
        label: widget.product.category.displayLabel(context.l10n),
        color: _accentColor(context),
      ),
    ];

    if (widget.product.chipset != null) {
      items.add(
        DeviceShopInfoPill(
          label: widget.product.chipset!,
          color: AccentColors.sky,
        ),
      );
    }
    if (widget.product.loraChip != null) {
      items.add(
        DeviceShopInfoPill(
          label: widget.product.loraChip!,
          color: AccentColors.orange,
        ),
      );
    }
    if (items.length == 1 && widget.product.frequencyBands.isNotEmpty) {
      items.add(
        DeviceShopInfoPill(
          label: widget.product.frequencyBands.first.displayLabel(context.l10n),
          color: AccentColors.teal,
        ),
      );
    }

    return items.take(2).toList();
  }

  Widget _buildPriceRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: Text(
            widget.product.formattedPrice(context.l10n),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _accentColor(context),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        if (widget.product.isOnSale) ...[
          const SizedBox(width: AppTheme.spacing8),
          Flexible(
            child: Text(
              widget.product.formattedComparePrice!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.textTertiary,
                fontSize: 12,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final stockColor = widget.product.isInStock
        ? AppTheme.successGreen
        : AppTheme.errorRed;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: stockColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spacing6),
        Expanded(
          child: Text(
            widget.product.isInStock
                ? context.l10n.shopFavoritesInStock
                : context.l10n.shopFavoritesOutOfStock,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.card, context.background],
        ),
      ),
      child: Center(
        child: Icon(
          widget.product.category == DeviceCategory.antenna
              ? Icons.cell_tower
              : Icons.router,
          color: context.textTertiary,
          size: 36,
        ),
      ),
    );
  }

  Color _accentColor(BuildContext context) {
    if (widget.product.isOnSale) {
      return widget.highlightColor ?? AppTheme.errorRed;
    }
    return widget.product.category == DeviceCategory.node
        ? context.accentColor
        : switch (widget.product.category) {
            DeviceCategory.module => AccentColors.purple,
            DeviceCategory.antenna => AccentColors.orange,
            DeviceCategory.enclosure => AccentColors.blue,
            DeviceCategory.accessory => AccentColors.teal,
            DeviceCategory.kit => AccentColors.yellow,
            DeviceCategory.solar => AccentColors.emerald,
            DeviceCategory.node => context.accentColor,
          };
  }

  void _openProduct() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(productId: widget.product.id),
      ),
    );
  }

  Future<void> _toggleFavorite(
    String? userId, {
    required bool isFavorite,
  }) async {
    if (userId == null) {
      showSignInRequiredSnackBar(context, context.l10n.shopFavoritesSignIn);
      return;
    }

    if (_isFavoriteLoading) {
      return;
    }

    // Show confirmation before removing from favorites
    if (isFavorite) {
      final confirmed = await AppBottomSheet.showConfirm(
        context: context,
        title: context.l10n.deviceShopRemoveFavoriteTitle,
        message: context.l10n.deviceShopRemoveFavoriteMessage,
        confirmLabel: context.l10n.commonDelete,
        cancelLabel: context.l10n.commonCancel,
        isDestructive: true,
      );

      if (confirmed != true) {
        return;
      }
    }

    setState(() => _isFavoriteLoading = true);
    final reduceMotion = ref.read(reduceMotionEnabledProvider);

    try {
      if (!reduceMotion) {
        await _heartController.forward();
        if (!mounted) {
          return;
        }
        await _heartController.reverse();
        if (!mounted) {
          return;
        }
      }

      await toggleFavoriteQueued(
        ref,
        userId: userId,
        productId: widget.product.id,
      );
    } finally {
      if (mounted) {
        setState(() => _isFavoriteLoading = false);
      }
    }
  }
}

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key, this.width});

  final double? width;

  @override
  Widget build(BuildContext context) {
    final skeleton = GradientBorderContainer(
      borderRadius: AppTheme.radius18,
      borderWidth: 1,
      accentOpacity: 0.18,
      child: AppSkeletonConfig.wrap(
        context: context,
        enabled: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Bone(
              width: double.infinity,
              height: 136,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radius18),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Bone.text(words: 2, fontSize: 12),
                    SizedBox(height: AppTheme.spacing10),
                    Bone.text(words: 3),
                    SizedBox(height: AppTheme.spacing8),
                    Bone.text(words: 2, fontSize: 12),
                    Spacer(),
                    Bone.text(words: 2, fontSize: 18),
                    SizedBox(height: AppTheme.spacing8),
                    Bone.text(words: 2, fontSize: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (width == null) {
      return skeleton;
    }

    return SizedBox(width: width, child: skeleton);
  }
}
