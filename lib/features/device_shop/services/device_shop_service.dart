import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/shop_models.dart';

/// Service for device shop operations
class DeviceShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      _firestore.collection('shopProducts');

  CollectionReference<Map<String, dynamic>> get _sellersCollection =>
      _firestore.collection('shopSellers');

  CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      _firestore.collection('productReviews');

  CollectionReference<Map<String, dynamic>> get _favoritesCollection =>
      _firestore.collection('productFavorites');

  // ============ PRODUCT OPERATIONS ============

  /// Watch all active products
  Stream<List<ShopProduct>> watchProducts({
    DeviceCategory? category,
    String? sellerId,
    bool? featuredOnly,
    bool? inStockOnly,
    String? searchQuery,
  }) {
    Query<Map<String, dynamic>> query = _productsCollection.where(
      'isActive',
      isEqualTo: true,
    );

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (sellerId != null) {
      query = query.where('sellerId', isEqualTo: sellerId);
    }

    if (featuredOnly == true) {
      query = query.where('isFeatured', isEqualTo: true);
    }

    if (inStockOnly == true) {
      query = query.where('isInStock', isEqualTo: true);
    }

    return query.snapshots().map((snapshot) {
      var products = snapshot.docs
          .map((doc) => ShopProduct.fromFirestore(doc))
          .toList();

      // Client-side search filter (Firestore doesn't support full-text search)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        products = products.where((p) {
          return p.name.toLowerCase().contains(lowerQuery) ||
              p.description.toLowerCase().contains(lowerQuery) ||
              p.sellerName.toLowerCase().contains(lowerQuery) ||
              p.tags.any((t) => t.toLowerCase().contains(lowerQuery));
        }).toList();
      }

      return products;
    });
  }

  /// Watch featured products
  Stream<List<ShopProduct>> watchFeaturedProducts({int limit = 10}) {
    return _productsCollection
        .where('isActive', isEqualTo: true)
        .where('isFeatured', isEqualTo: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .toList(),
        );
  }

  /// Watch new arrivals
  Stream<List<ShopProduct>> watchNewArrivals({int limit = 20}) {
    return _productsCollection
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .toList(),
        );
  }

  /// Watch best sellers
  Stream<List<ShopProduct>> watchBestSellers({int limit = 20}) {
    return _productsCollection
        .where('isActive', isEqualTo: true)
        .orderBy('salesCount', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .toList(),
        );
  }

  /// Watch products on sale
  Stream<List<ShopProduct>> watchOnSale({int limit = 20}) {
    return _productsCollection
        .where('isActive', isEqualTo: true)
        .where('compareAtPrice', isGreaterThan: 0)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .toList(),
        );
  }

  /// Watch products by category
  Stream<List<ShopProduct>> watchByCategory(DeviceCategory category) {
    return _productsCollection
        .where('isActive', isEqualTo: true)
        .where('category', isEqualTo: category.name)
        .orderBy('salesCount', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a single product
  Future<ShopProduct?> getProduct(String productId) async {
    final doc = await _productsCollection.doc(productId).get();
    if (!doc.exists) return null;
    return ShopProduct.fromFirestore(doc);
  }

  /// Watch a single product
  Stream<ShopProduct?> watchProduct(String productId) {
    return _productsCollection.doc(productId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ShopProduct.fromFirestore(doc);
    });
  }

  /// Increment view count
  Future<void> incrementViewCount(String productId) async {
    await _productsCollection.doc(productId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Search products
  Future<List<ShopProduct>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    // Get all active products and filter client-side
    // For production, consider using Algolia or similar
    final snapshot = await _productsCollection
        .where('isActive', isEqualTo: true)
        .get();

    final products = snapshot.docs
        .map((doc) => ShopProduct.fromFirestore(doc))
        .toList();

    final lowerQuery = query.toLowerCase();
    return products.where((p) {
      return p.name.toLowerCase().contains(lowerQuery) ||
          p.description.toLowerCase().contains(lowerQuery) ||
          p.sellerName.toLowerCase().contains(lowerQuery) ||
          p.tags.any((t) => t.toLowerCase().contains(lowerQuery)) ||
          p.chipset?.toLowerCase().contains(lowerQuery) == true ||
          p.loraChip?.toLowerCase().contains(lowerQuery) == true;
    }).toList();
  }

  // ============ SELLER OPERATIONS ============

  /// Watch all verified sellers
  Stream<List<ShopSeller>> watchSellers() {
    return _sellersCollection
        .where('isActive', isEqualTo: true)
        .orderBy('isOfficialPartner', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopSeller.fromFirestore(doc))
              .toList(),
        );
  }

  /// Watch official partners
  Stream<List<ShopSeller>> watchOfficialPartners() {
    return _sellersCollection
        .where('isActive', isEqualTo: true)
        .where('isOfficialPartner', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopSeller.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a seller
  Future<ShopSeller?> getSeller(String oderId) async {
    final doc = await _sellersCollection.doc(oderId).get();
    if (!doc.exists) return null;
    return ShopSeller.fromFirestore(doc);
  }

  /// Watch a seller
  Stream<ShopSeller?> watchSeller(String oderId) {
    return _sellersCollection.doc(oderId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ShopSeller.fromFirestore(doc);
    });
  }

  // ============ REVIEW OPERATIONS ============

  /// Watch reviews for a product
  Stream<List<ProductReview>> watchProductReviews(String productId) {
    return _reviewsCollection
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductReview.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get review stats for a product
  Future<Map<int, int>> getReviewStats(String productId) async {
    final snapshot = await _reviewsCollection
        .where('productId', isEqualTo: productId)
        .get();

    final stats = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final doc in snapshot.docs) {
      final rating = doc.data()['rating'] as int? ?? 5;
      stats[rating] = (stats[rating] ?? 0) + 1;
    }
    return stats;
  }

  /// Add a review
  Future<void> addReview({
    required String productId,
    required String oderId,
    String? userName,
    String? userPhotoUrl,
    required int rating,
    String? title,
    String? body,
    List<String> imageUrls = const [],
    bool isVerifiedPurchase = false,
  }) async {
    final review = ProductReview(
      id: '',
      productId: productId,
      userId: oderId,
      userName: userName,
      userPhotoUrl: userPhotoUrl,
      rating: rating,
      title: title,
      body: body,
      imageUrls: imageUrls,
      isVerifiedPurchase: isVerifiedPurchase,
      createdAt: DateTime.now(),
    );

    await _reviewsCollection.add(review.toFirestore());

    // Update product rating
    await _updateProductRating(productId);
  }

  Future<void> _updateProductRating(String productId) async {
    final snapshot = await _reviewsCollection
        .where('productId', isEqualTo: productId)
        .get();

    if (snapshot.docs.isEmpty) return;

    final totalRating = snapshot.docs.fold<int>(
      0,
      (total, doc) => total + (doc.data()['rating'] as int? ?? 0),
    );
    final avgRating = totalRating / snapshot.docs.length;

    await _productsCollection.doc(productId).update({
      'rating': avgRating,
      'reviewCount': snapshot.docs.length,
    });
  }

  /// Mark review as helpful
  Future<void> markReviewHelpful(String reviewId) async {
    await _reviewsCollection.doc(reviewId).update({
      'helpfulCount': FieldValue.increment(1),
    });
  }

  // ============ FAVORITES OPERATIONS ============

  /// Watch user's favorites
  Stream<List<ProductFavorite>> watchUserFavorites(String oderId) {
    return _favoritesCollection
        .where('userId', isEqualTo: oderId)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ProductFavorite.fromFirestore(doc))
              .toList(),
        );
  }

  /// Watch user's favorite product IDs (for quick lookup)
  Stream<Set<String>> watchUserFavoriteIds(String oderId) {
    return _favoritesCollection
        .where('userId', isEqualTo: oderId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => doc.data()['productId'] as String)
              .toSet(),
        );
  }

  /// Check if product is favorited
  Future<bool> isFavorited(String oderId, String productId) async {
    final snapshot = await _favoritesCollection
        .where('userId', isEqualTo: oderId)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Toggle favorite
  Future<bool> toggleFavorite(String oderId, String productId) async {
    final snapshot = await _favoritesCollection
        .where('userId', isEqualTo: oderId)
        .where('productId', isEqualTo: productId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      // Remove favorite
      await snapshot.docs.first.reference.delete();
      await _productsCollection.doc(productId).update({
        'favoriteCount': FieldValue.increment(-1),
      });
      return false;
    } else {
      // Add favorite
      final favorite = ProductFavorite(
        id: '',
        oderId: oderId,
        productId: productId,
        addedAt: DateTime.now(),
      );
      await _favoritesCollection.add(favorite.toFirestore());
      await _productsCollection.doc(productId).update({
        'favoriteCount': FieldValue.increment(1),
      });
      return true;
    }
  }

  // ============ SELLER MANAGEMENT ============

  /// Create or update seller profile
  Future<void> upsertSeller(ShopSeller seller) async {
    await _sellersCollection
        .doc(seller.id)
        .set(seller.toFirestore(), SetOptions(merge: true));
  }

  /// Create a product listing (for sellers)
  Future<String> createProduct(ShopProduct product) async {
    final docRef = await _productsCollection.add(product.toFirestore());

    // Update seller's product count
    await _sellersCollection.doc(product.sellerId).update({
      'productCount': FieldValue.increment(1),
    });

    return docRef.id;
  }

  /// Update a product listing
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates,
  ) async {
    updates['updatedAt'] = Timestamp.now();
    await _productsCollection.doc(productId).update(updates);
  }

  /// Deactivate a product
  Future<void> deactivateProduct(String productId) async {
    await _productsCollection.doc(productId).update({
      'isActive': false,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Delete a product
  Future<void> deleteProduct(String productId, String oderId) async {
    final product = await getProduct(productId);
    if (product?.sellerId != oderId) {
      throw Exception('Not authorized to delete this product');
    }

    await _productsCollection.doc(productId).delete();

    // Update seller's product count
    await _sellersCollection.doc(oderId).update({
      'productCount': FieldValue.increment(-1),
    });
  }

  // ============ ANALYTICS ============

  /// Get shop statistics
  Future<ShopStatistics> getShopStatistics() async {
    try {
      final productsSnapshot = await _productsCollection
          .where('isActive', isEqualTo: true)
          .get();
      final sellersSnapshot = await _sellersCollection
          .where('isActive', isEqualTo: true)
          .get();

      int totalProducts = productsSnapshot.docs.length;
      int totalSellers = sellersSnapshot.docs.length;
      int totalSales = 0;
      int officialPartners = 0;

      for (final doc in productsSnapshot.docs) {
        totalSales += (doc.data()['salesCount'] as int?) ?? 0;
      }

      for (final doc in sellersSnapshot.docs) {
        if (doc.data()['isOfficialPartner'] == true) {
          officialPartners++;
        }
      }

      return ShopStatistics(
        totalProducts: totalProducts,
        totalSellers: totalSellers,
        totalSales: totalSales,
        officialPartners: officialPartners,
      );
    } catch (e) {
      debugPrint('[DeviceShop] Error getting statistics: $e');
      return const ShopStatistics();
    }
  }
}

/// Shop statistics
class ShopStatistics {
  final int totalProducts;
  final int totalSellers;
  final int totalSales;
  final int officialPartners;

  const ShopStatistics({
    this.totalProducts = 0,
    this.totalSellers = 0,
    this.totalSales = 0,
    this.officialPartners = 0,
  });
}
