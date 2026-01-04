import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/shop_models.dart';
import '../services/device_shop_service.dart';

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

/// Provider for a single product
final singleProductProvider = StreamProvider.family<ShopProduct?, String>((
  ref,
  productId,
) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchProduct(productId);
});

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

/// Provider for official partners
final officialPartnersProvider = StreamProvider<List<ShopSeller>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchOfficialPartners();
});

/// Provider for a single seller
final singleSellerProvider = StreamProvider.family<ShopSeller?, String>((
  ref,
  sellerId,
) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchSeller(sellerId);
});

/// Provider for seller's products
final sellerProductsProvider = StreamProvider.family<List<ShopProduct>, String>(
  (ref, sellerId) {
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
