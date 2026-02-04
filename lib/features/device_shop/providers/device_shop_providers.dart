// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../models/shop_models.dart';
import '../services/device_shop_service.dart';
import '../services/device_shop_event_logger.dart';
import '../services/lilygo_api_service.dart';

/// Provider for DeviceShopEventLogger
final deviceShopEventLoggerProvider = Provider<DeviceShopEventLogger>((ref) {
  return LocalDeviceShopEventLogger();
});

// ============ LILYGO SELLER DATA ============

/// The official LILYGO seller ID used for all LILYGO API products
const lilygoSellerId = 'lilygo_official';

/// Official LILYGO seller data - this is the real company information
/// Used when displaying seller info for products fetched from LILYGO API
ShopSeller lilygoSeller(int productCount) => ShopSeller(
  id: lilygoSellerId,
  name: 'LILYGO',
  description:
      'LILYGO is a leading manufacturer of LoRa and ESP32-based devices, '
      'specializing in Meshtastic-compatible hardware. Founded in 2017, '
      'they produce the popular T-Beam, T-Deck, T-Echo, and T-Watch series.',
  logoUrl: 'https://lilygo.cc/cdn/shop/files/LILYGO.png?v=1680253546',
  websiteUrl: 'https://lilygo.cc',
  contactEmail: 'support@lilygo.cc',
  isVerified: true,
  isOfficialPartner: true,
  rating: 4.6, // Based on aggregate reviews
  reviewCount: 0, // We don't have review data from API
  productCount: productCount,
  salesCount: 0, // We don't have sales data from API
  joinedAt: DateTime(2017, 1, 1), // LILYGO founded ~2017
  countries: [
    'Worldwide', // LILYGO ships globally via their store
  ],
  isActive: true,
);

/// Provider for LILYGO seller with dynamic product count
final lilygoSellerProvider = Provider<AsyncValue<ShopSeller>>((ref) {
  final productsAsync = ref.watch(lilygoProductsProvider);
  return productsAsync.whenData((products) => lilygoSeller(products.length));
});

// ============ LILYGO API PROVIDERS ============

/// Provider for LILYGO API service
final lilygoApiServiceProvider = Provider<LilygoApiService>((ref) {
  AppLogging.shop('[Provider] lilygoApiServiceProvider creating service...');
  final service = LilygoApiService();
  ref.onDispose(() {
    AppLogging.shop('[Provider] lilygoApiServiceProvider disposing service');
    service.dispose();
  });
  return service;
});

/// Provider for LILYGO Meshtastic products (fetched directly from their API)
final lilygoProductsProvider = FutureProvider<List<ShopProduct>>((ref) async {
  AppLogging.shop('[Provider] lilygoProductsProvider called');
  final service = ref.watch(lilygoApiServiceProvider);
  AppLogging.shop('[Provider] lilygoProductsProvider fetching products...');
  try {
    final products = await service.fetchMeshtasticProducts();
    AppLogging.shop(
      '[Provider] lilygoProductsProvider got ${products.length} products',
    );
    return products;
  } catch (e, stack) {
    AppLogging.shop('[Provider] lilygoProductsProvider ERROR: $e');
    AppLogging.shop('[Provider] Stack: $stack');
    rethrow;
  }
});

/// Provider for a single LILYGO product by handle
final lilygoProductProvider = FutureProvider.family<ShopProduct?, String>((
  ref,
  handle,
) async {
  AppLogging.shop('[Provider] lilygoProductProvider($handle) called');
  final service = ref.watch(lilygoApiServiceProvider);
  return service.fetchProduct(handle);
});

/// Provider for featured LILYGO products
final lilygoFeaturedProductsProvider = Provider<AsyncValue<List<ShopProduct>>>((
  ref,
) {
  AppLogging.shop('[Provider] lilygoFeaturedProductsProvider called');
  final productsAsync = ref.watch(lilygoProductsProvider);
  return productsAsync.whenData((products) {
    final featured = products.where((p) => p.isFeatured).toList();
    AppLogging.shop(
      '[Provider] lilygoFeaturedProductsProvider: ${featured.length} featured',
    );
    return featured;
  });
});

/// Provider for LILYGO products by category
final lilygoCategoryProductsProvider =
    Provider.family<AsyncValue<List<ShopProduct>>, DeviceCategory>((
      ref,
      category,
    ) {
      AppLogging.shop(
        '[Provider] lilygoCategoryProductsProvider($category) called',
      );
      final productsAsync = ref.watch(lilygoProductsProvider);
      return productsAsync.whenData((products) {
        final filtered = products.where((p) => p.category == category).toList();
        AppLogging.shop(
          '[Provider] lilygoCategoryProductsProvider: ${filtered.length} in $category',
        );
        return filtered;
      });
    });

/// Provider to find a LILYGO product by its ID (from cached products)
final lilygoProductByIdProvider =
    Provider.family<AsyncValue<ShopProduct?>, String>((ref, productId) {
      AppLogging.shop(
        '[Provider] lilygoProductByIdProvider($productId) called',
      );

      // Check if this is a LILYGO product ID
      if (!productId.startsWith('lilygo_')) {
        AppLogging.shop('[Provider] Not a LILYGO product ID, returning null');
        return const AsyncValue.data(null);
      }

      final productsAsync = ref.watch(lilygoProductsProvider);
      return productsAsync.whenData((products) {
        final product = products.where((p) => p.id == productId).firstOrNull;
        AppLogging.shop(
          '[Provider] lilygoProductByIdProvider: '
          '${product != null ? "found ${product.name}" : "not found"}',
        );
        return product;
      });
    });

/// Provider for LILYGO product search
final lilygoSearchProvider =
    Provider.family<AsyncValue<List<ShopProduct>>, String>((ref, query) {
      AppLogging.shop('[Provider] lilygoSearchProvider("$query") called');

      if (query.isEmpty) {
        return const AsyncValue.data([]);
      }

      final productsAsync = ref.watch(lilygoProductsProvider);
      return productsAsync.whenData((products) {
        final queryLower = query.toLowerCase();
        final results = products.where((p) {
          final nameMatch = p.name.toLowerCase().contains(queryLower);
          final descMatch = p.description.toLowerCase().contains(queryLower);
          final tagMatch = p.tags.any(
            (t) => t.toLowerCase().contains(queryLower),
          );
          final chipMatch =
              p.chipset?.toLowerCase().contains(queryLower) ?? false;
          final loraMatch =
              p.loraChip?.toLowerCase().contains(queryLower) ?? false;
          return nameMatch || descMatch || tagMatch || chipMatch || loraMatch;
        }).toList();

        AppLogging.shop(
          '[Provider] lilygoSearchProvider: ${results.length} results for "$query"',
        );
        return results;
      });
    });

// ============ FIREBASE PROVIDERS ============

/// Provider for DeviceShopService
final deviceShopServiceProvider = Provider<DeviceShopService>((ref) {
  return DeviceShopService();
});

/// Provider for all active products
final shopProductsProvider = StreamProvider<List<ShopProduct>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchProducts();
});

/// Provider for featured products
final featuredProductsProvider = StreamProvider<List<ShopProduct>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchFeaturedProducts();
});

/// Provider for new arrivals
final newArrivalsProvider = StreamProvider<List<ShopProduct>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchNewArrivals();
});

/// Provider for best sellers
final bestSellersProvider = StreamProvider<List<ShopProduct>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchBestSellers();
});

/// Provider for products on sale
final onSaleProductsProvider = StreamProvider<List<ShopProduct>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchOnSale();
});

/// Provider for products by category
final categoryProductsProvider =
    StreamProvider.family<List<ShopProduct>, DeviceCategory>((ref, category) {
      final service = ref.watch(deviceShopServiceProvider);
      return service.watchByCategory(category);
    });

/// Provider for a single product - checks LILYGO cache first, then Firebase
final singleProductProvider = StreamProvider.family<ShopProduct?, String>((
  ref,
  productId,
) {
  AppLogging.shop('[Provider] singleProductProvider($productId) called');

  // Check if this is a LILYGO product (ID starts with 'lilygo_')
  if (productId.startsWith('lilygo_')) {
    AppLogging.shop('[Provider] Detected LILYGO product, checking cache...');
    final lilygoProductAsync = ref.watch(lilygoProductByIdProvider(productId));

    return lilygoProductAsync.when(
      data: (product) {
        if (product != null) {
          AppLogging.shop(
            '[Provider] Found LILYGO product in cache: ${product.name}',
          );
          return Stream.value(product);
        }
        AppLogging.shop(
          '[Provider] LILYGO product not in cache, falling back to Firebase',
        );
        final service = ref.watch(deviceShopServiceProvider);
        return service.watchProduct(productId);
      },
      loading: () {
        AppLogging.shop('[Provider] LILYGO products still loading...');
        // Return loading stream while LILYGO products load
        return const Stream<ShopProduct?>.empty();
      },
      error: (e, _) {
        AppLogging.shop('[Provider] Error loading LILYGO products: $e');
        // Fall back to Firebase on error
        final service = ref.watch(deviceShopServiceProvider);
        return service.watchProduct(productId);
      },
    );
  }

  // Not a LILYGO product, use Firebase
  AppLogging.shop('[Provider] Not a LILYGO product, using Firebase');
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchProduct(productId);
});

/// Provider for single product by ID (future, for one-time reads in favorites)
/// Checks LILYGO cache first for lilygo_ prefixed IDs, falls back to Firebase
final singleProductFutureProvider = FutureProvider.family<ShopProduct?, String>(
  (ref, productId) async {
    AppLogging.shop(
      '[Provider] singleProductFutureProvider($productId) called',
    );

    // Check if this is a LILYGO product
    if (productId.startsWith('lilygo_')) {
      AppLogging.shop('[Provider] Detected LILYGO product, checking cache...');
      final lilygoProductAsync = ref.watch(
        lilygoProductByIdProvider(productId),
      );

      return lilygoProductAsync.when(
        data: (product) {
          if (product != null) {
            AppLogging.shop('[Provider] Found LILYGO product: ${product.name}');
            return product;
          }
          AppLogging.shop(
            '[Provider] LILYGO product not in cache, falling back to Firebase',
          );
          final service = ref.read(deviceShopServiceProvider);
          return service.getProduct(productId);
        },
        loading: () {
          AppLogging.shop('[Provider] LILYGO products still loading...');
          return null;
        },
        error: (e, _) {
          AppLogging.shop('[Provider] Error loading LILYGO products: $e');
          final service = ref.read(deviceShopServiceProvider);
          return service.getProduct(productId);
        },
      );
    }

    // Not a LILYGO product, use Firebase
    AppLogging.shop('[Provider] Not a LILYGO product, using Firebase');
    final service = ref.read(deviceShopServiceProvider);
    return service.getProduct(productId);
  },
);

/// Provider for product search
final productSearchProvider = FutureProvider.family<List<ShopProduct>, String>((
  ref,
  query,
) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.searchProducts(query);
});

/// Provider for all sellers
final shopSellersProvider = StreamProvider<List<ShopSeller>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchSellers();
});

/// Provider for official partners - includes LILYGO from API
final officialPartnersProvider = Provider<AsyncValue<List<ShopSeller>>>((ref) {
  final lilygoSellerAsync = ref.watch(lilygoSellerProvider);

  return lilygoSellerAsync.whenData((lilygoSeller) {
    // Return LILYGO as the official partner
    // Firebase partners could be added here if needed in the future
    return [lilygoSeller];
  });
});

/// Provider for a single seller - checks for LILYGO first
final singleSellerProvider = StreamProvider.family<ShopSeller?, String>((
  ref,
  sellerId,
) {
  // Check if this is the LILYGO seller
  if (sellerId == lilygoSellerId) {
    final lilygoSellerAsync = ref.watch(lilygoSellerProvider);
    return lilygoSellerAsync.when(
      data: (seller) => Stream.value(seller),
      loading: () => const Stream.empty(),
      error: (e, _) {
        // Fall back to Firebase on error
        final service = ref.watch(deviceShopServiceProvider);
        return service.watchSeller(sellerId);
      },
    );
  }

  // Not LILYGO, use Firebase
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchSeller(sellerId);
});

/// Provider for seller's products - returns LILYGO products for LILYGO seller
final sellerProductsProvider = StreamProvider.family<List<ShopProduct>, String>(
  (ref, sellerId) {
    // Check if this is the LILYGO seller
    if (sellerId == lilygoSellerId) {
      final productsAsync = ref.watch(lilygoProductsProvider);
      return productsAsync.when(
        data: (products) => Stream.value(products),
        loading: () => const Stream.empty(),
        error: (e, _) {
          // Fall back to Firebase on error
          final service = ref.watch(deviceShopServiceProvider);
          return service.watchProducts(sellerId: sellerId);
        },
      );
    }

    // Not LILYGO, use Firebase
    final service = ref.watch(deviceShopServiceProvider);
    return service.watchProducts(sellerId: sellerId);
  },
);

/// Provider for product reviews
final productReviewsProvider =
    StreamProvider.family<List<ProductReview>, String>((ref, productId) {
      final service = ref.watch(deviceShopServiceProvider);
      return service.watchProductReviews(productId);
    });

/// Provider for review statistics
final reviewStatsProvider = FutureProvider.family<Map<int, int>, String>((
  ref,
  productId,
) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.getReviewStats(productId);
});

/// Provider for user's favorites
final userFavoritesProvider =
    StreamProvider.family<List<ProductFavorite>, String>((ref, userId) {
      final service = ref.watch(deviceShopServiceProvider);
      return service.watchUserFavorites(userId);
    });

/// Provider for user's favorite IDs (for quick lookup)
final userFavoriteIdsProvider = StreamProvider.family<Set<String>, String>((
  ref,
  userId,
) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchUserFavoriteIds(userId);
});

/// Provider for shop statistics
final shopStatisticsProvider = FutureProvider<ShopStatistics>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.getShopStatistics();
});

/// Provider for trending products (by view count)
/// Used for "Popular" section - safe because based on product data, not user input
final trendingProductsProvider = StreamProvider<List<ShopProduct>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchTrendingProducts();
});
