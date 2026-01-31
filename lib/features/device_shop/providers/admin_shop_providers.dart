// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/auth_providers.dart';
import '../models/shop_models.dart';
import '../services/device_shop_service.dart';
import 'device_shop_providers.dart';

/// Provider to check if current user is admin
final isShopAdminProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final service = ref.watch(deviceShopServiceProvider);
  return service.isAdmin(user.uid);
});

/// Provider for pending review count (for badge)
final pendingReviewCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchPendingReviews().map((reviews) => reviews.length);
});

/// Provider for admin statistics
final adminShopStatisticsProvider = FutureProvider<AdminShopStatistics>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.getAdminStatistics();
});

/// Provider for all products (including inactive) for admin
final adminAllProductsProvider = StreamProvider<List<ShopProduct>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchAllProductsAdmin();
});

/// Provider for all sellers (including inactive) for admin
final adminAllSellersProvider = StreamProvider<List<ShopSeller>>((ref) {
  final service = ref.watch(deviceShopServiceProvider);
  return service.watchAllSellersAdmin();
});

/// State notifier for product form using Riverpod 3.x Notifier
class ProductFormNotifier extends Notifier<ShopProduct> {
  @override
  ShopProduct build() {
    return ShopProduct(
      id: '',
      name: '',
      description: '',
      category: DeviceCategory.node,
      price: 0,
      currency: 'USD',
      sellerId: '',
      sellerName: '',
      imageUrls: [],
      purchaseUrl: '',
      isActive: true,
      isInStock: true,
      isFeatured: false,
      viewCount: 0,
      salesCount: 0,
      favoriteCount: 0,
      rating: 0,
      reviewCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void loadProduct(ShopProduct product) {
    state = product;
  }

  void reset() {
    state = ShopProduct(
      id: '',
      name: '',
      description: '',
      category: DeviceCategory.node,
      price: 0,
      currency: 'USD',
      sellerId: '',
      sellerName: '',
      imageUrls: [],
      purchaseUrl: '',
      isActive: true,
      isInStock: true,
      isFeatured: false,
      viewCount: 0,
      salesCount: 0,
      favoriteCount: 0,
      rating: 0,
      reviewCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void updateShortDescription(String shortDescription) {
    state = state.copyWith(shortDescription: shortDescription);
  }

  void updateCategory(DeviceCategory category) {
    state = state.copyWith(category: category);
  }

  void updatePrice(double price) {
    state = state.copyWith(price: price);
  }

  void updateCompareAtPrice(double? compareAtPrice) {
    state = state.copyWith(compareAtPrice: compareAtPrice);
  }

  void updateSeller(String sellerId, String sellerName) {
    state = state.copyWith(sellerId: sellerId, sellerName: sellerName);
  }

  void updatePurchaseUrl(String url) {
    state = state.copyWith(purchaseUrl: url);
  }

  void updateTags(List<String> tags) {
    state = state.copyWith(tags: tags);
  }

  void updateFrequencyBands(List<FrequencyBand> bands) {
    state = state.copyWith(frequencyBands: bands);
  }

  void updateImageUrls(List<String> urls) {
    state = state.copyWith(imageUrls: urls);
  }

  void addImageUrl(String url) {
    state = state.copyWith(imageUrls: [...state.imageUrls, url]);
  }

  void removeImageUrl(int index) {
    final urls = List<String>.from(state.imageUrls);
    urls.removeAt(index);
    state = state.copyWith(imageUrls: urls);
  }

  void reorderImages(int oldIndex, int newIndex) {
    final urls = List<String>.from(state.imageUrls);
    if (newIndex > oldIndex) newIndex--;
    final item = urls.removeAt(oldIndex);
    urls.insert(newIndex, item);
    state = state.copyWith(imageUrls: urls);
  }

  void updateChipset(String? chipset) {
    state = state.copyWith(chipset: chipset);
  }

  void updateLoraChip(String? loraChip) {
    state = state.copyWith(loraChip: loraChip);
  }

  void updateHasGps(bool hasGps) {
    state = state.copyWith(hasGps: hasGps);
  }

  void updateHasWifi(bool hasWifi) {
    state = state.copyWith(hasWifi: hasWifi);
  }

  void updateHasBluetooth(bool hasBluetooth) {
    state = state.copyWith(hasBluetooth: hasBluetooth);
  }

  void updateHasDisplay(bool hasDisplay) {
    state = state.copyWith(hasDisplay: hasDisplay);
  }

  void updateBatteryCapacity(String? batteryCapacity) {
    state = state.copyWith(batteryCapacity: batteryCapacity);
  }

  void updateIsInStock(bool inStock) {
    state = state.copyWith(isInStock: inStock);
  }

  void updateIsFeatured(bool featured) {
    state = state.copyWith(isFeatured: featured);
  }

  void updateIsActive(bool active) {
    state = state.copyWith(isActive: active);
  }

  void updateWeight(String? weight) {
    state = state.copyWith(weight: weight);
  }

  void updateDimensions(String? dimensions) {
    state = state.copyWith(dimensions: dimensions);
  }

  void updateStockQuantity(int quantity) {
    state = state.copyWith(stockQuantity: quantity);
  }
}

final productFormProvider = NotifierProvider<ProductFormNotifier, ShopProduct>(
  ProductFormNotifier.new,
);

/// State notifier for seller form using Riverpod 3.x Notifier
class SellerFormNotifier extends Notifier<ShopSeller> {
  @override
  ShopSeller build() {
    return ShopSeller(
      id: '',
      name: '',
      description: '',
      websiteUrl: '',
      isActive: true,
      isVerified: false,
      isOfficialPartner: false,
      rating: 0,
      reviewCount: 0,
      productCount: 0,
      salesCount: 0,
      joinedAt: DateTime.now(),
      countries: [],
    );
  }

  void loadSeller(ShopSeller seller) {
    state = seller;
  }

  void reset() {
    state = ShopSeller(
      id: '',
      name: '',
      description: '',
      websiteUrl: '',
      isActive: true,
      isVerified: false,
      isOfficialPartner: false,
      rating: 0,
      reviewCount: 0,
      productCount: 0,
      salesCount: 0,
      joinedAt: DateTime.now(),
      countries: [],
    );
  }

  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void updateLogoUrl(String? logoUrl) {
    state = state.copyWith(logoUrl: logoUrl);
  }

  void updateWebsiteUrl(String url) {
    state = state.copyWith(websiteUrl: url);
  }

  void updateContactEmail(String? email) {
    state = state.copyWith(contactEmail: email);
  }

  void updateIsVerified(bool verified) {
    state = state.copyWith(isVerified: verified);
  }

  void updateIsOfficialPartner(bool partner) {
    state = state.copyWith(isOfficialPartner: partner);
  }

  void updateCountries(List<String> countries) {
    state = state.copyWith(countries: countries);
  }

  void updateIsActive(bool active) {
    state = state.copyWith(isActive: active);
  }
}

final sellerFormProvider = NotifierProvider<SellerFormNotifier, ShopSeller>(
  SellerFormNotifier.new,
);
