import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_shop_data.dart';
import '../models/shop_models.dart';
import '../services/device_shop_service.dart';

/// Set to true to use mock data, false to use Firebase
const bool useMockData = true;

/// Provider for DeviceShopService
final deviceShopServiceProvider = Provider<DeviceShopService>((ref) {
  return DeviceShopService();
});

/// Provider for all active products
final shopProductsProvider = StreamProvider<List<ShopProduct>>((ref) {
  if (useMockData) {
    return Stream.value(MockShopData.products);
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchProducts();
});

/// Provider for featured products
final featuredProductsProvider = StreamProvider<List<ShopProduct>>((ref) {
  if (useMockData) {
    return Stream.value(MockShopData.getFeaturedProducts());
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchFeaturedProducts();
});

/// Provider for new arrivals
final newArrivalsProvider = StreamProvider<List<ShopProduct>>((ref) {
  if (useMockData) {
    return Stream.value(MockShopData.getNewArrivals());
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchNewArrivals();
});

/// Provider for best sellers
final bestSellersProvider = StreamProvider<List<ShopProduct>>((ref) {
  if (useMockData) {
    return Stream.value(MockShopData.getBestSellers());
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchBestSellers();
});

/// Provider for products on sale
final onSaleProductsProvider = StreamProvider<List<ShopProduct>>((ref) {
  if (useMockData) {
    return Stream.value(MockShopData.getOnSale());
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchOnSale();
});

/// Provider for products by category
final categoryProductsProvider =
    StreamProvider.family<List<ShopProduct>, DeviceCategory>((ref, category) {
      if (useMockData) {
        return Stream.value(MockShopData.getByCategory(category));
      }
      final service = ref.watch(deviceShopServiceProvider);
      return service.watchByCategory(category);
    });

/// Provider for a single product
final singleProductProvider = StreamProvider.family<ShopProduct?, String>((
  ref,
  productId,
) {
  if (useMockData) {
    return Stream.value(MockShopData.getProduct(productId));
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchProduct(productId);
});

/// Provider for product search
final productSearchProvider = FutureProvider.family<List<ShopProduct>, String>((
  ref,
  query,
) {
  if (useMockData) {
    return Future.value(MockShopData.searchProducts(query));
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.searchProducts(query);
});

/// Provider for all sellers
final shopSellersProvider = StreamProvider<List<ShopSeller>>((ref) {
  if (useMockData) {
    return Stream.value(MockShopData.sellers);
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchSellers();
});

/// Provider for official partners
final officialPartnersProvider = StreamProvider<List<ShopSeller>>((ref) {
  if (useMockData) {
    return Stream.value(MockShopData.getOfficialPartners());
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchOfficialPartners();
});

/// Provider for a single seller
final singleSellerProvider = StreamProvider.family<ShopSeller?, String>((
  ref,
  sellerId,
) {
  if (useMockData) {
    return Stream.value(MockShopData.getSeller(sellerId));
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchSeller(sellerId);
});

/// Provider for seller's products
final sellerProductsProvider = StreamProvider.family<List<ShopProduct>, String>(
  (ref, sellerId) {
    if (useMockData) {
      return Stream.value(MockShopData.getSellerProducts(sellerId));
    }
    final service = ref.watch(deviceShopServiceProvider);
    return service.watchProducts(sellerId: sellerId);
  },
);

/// Provider for product reviews
final productReviewsProvider =
    StreamProvider.family<List<ProductReview>, String>((ref, productId) {
      if (useMockData) {
        return Stream.value(MockShopData.getProductReviews(productId));
      }
      final service = ref.watch(deviceShopServiceProvider);
      return service.watchProductReviews(productId);
    });

/// Provider for review statistics
final reviewStatsProvider = FutureProvider.family<Map<int, int>, String>((
  ref,
  productId,
) {
  if (useMockData) {
    return Future.value(MockShopData.getReviewStats(productId));
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.getReviewStats(productId);
});

/// Provider for user's favorites (mock returns empty for now)
final userFavoritesProvider =
    StreamProvider.family<List<ProductFavorite>, String>((ref, userId) {
      if (useMockData) {
        return Stream.value(<ProductFavorite>[]);
      }
      final service = ref.watch(deviceShopServiceProvider);
      return service.watchUserFavorites(userId);
    });

/// Provider for user's favorite IDs (for quick lookup)
final userFavoriteIdsProvider = StreamProvider.family<Set<String>, String>((
  ref,
  userId,
) {
  if (useMockData) {
    return Stream.value(<String>{});
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchUserFavoriteIds(userId);
});

/// Provider for shop statistics
final shopStatisticsProvider = FutureProvider<ShopStatistics>((ref) {
  if (useMockData) {
    return Future.value(
      ShopStatistics(
        totalProducts: MockShopData.products.length,
        totalSellers: MockShopData.sellers.length,
        totalSales: MockShopData.products.fold(
          0,
          (sum, p) => sum + p.salesCount,
        ),
        officialPartners: MockShopData.getOfficialPartners().length,
      ),
    );
  }
  final service = ref.watch(deviceShopServiceProvider);
  return service.getShopStatistics();
});
