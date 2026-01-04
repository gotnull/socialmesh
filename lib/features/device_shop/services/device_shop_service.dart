import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

import '../models/shop_models.dart';

/// Service for device shop operations
class DeviceShopService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      _firestore.collection('shopProducts');

  CollectionReference<Map<String, dynamic>> get _sellersCollection =>
      _firestore.collection('shopSellers');

  CollectionReference<Map<String, dynamic>> get _reviewsCollection =>
      _firestore.collection('productReviews');

  CollectionReference<Map<String, dynamic>> get _favoritesCollection =>
      _firestore.collection('productFavorites');

  CollectionReference<Map<String, dynamic>> get _adminsCollection =>
      _firestore.collection('admins');

  // ============ ADMIN VERIFICATION ============

  /// Check if user is an admin
  Future<bool> isAdmin(String userId) async {
    try {
      final doc = await _adminsCollection.doc(userId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('[DeviceShop] Error checking admin status: $e');
      return false;
    }
  }

  // ============ IMAGE UPLOAD ============

  /// Pick an image from gallery
  Future<File?> pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null &&
        result.files.isNotEmpty &&
        result.files.first.path != null) {
      return File(result.files.first.path!);
    }
    return null;
  }

  /// Pick multiple images from gallery
  Future<List<File>> pickMultipleImages({int maxImages = 10}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files
          .where((f) => f.path != null)
          .take(maxImages)
          .map((f) => File(f.path!))
          .toList();
    }
    return [];
  }

  /// Upload a product image and return the download URL
  Future<String> uploadProductImage({
    required String productId,
    required File imageFile,
  }) async {
    final ext = path.extension(imageFile.path).toLowerCase();
    final fileName = '${_uuid.v4()}$ext';
    final ref = _storage.ref().child('shop_products/$productId/$fileName');

    final metadata = SettableMetadata(
      contentType: 'image/${ext.replaceFirst('.', '')}',
      customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
    );

    final uploadTask = ref.putFile(imageFile, metadata);

    uploadTask.snapshotEvents.listen((event) {
      final progress = event.bytesTransferred / event.totalBytes;
      debugPrint(
        '[DeviceShop] Upload progress: ${(progress * 100).toStringAsFixed(1)}%',
      );
    });

    await uploadTask;
    return ref.getDownloadURL();
  }

  /// Upload a seller logo and return the download URL
  Future<String> uploadSellerLogo({
    required String sellerId,
    required File imageFile,
  }) async {
    final ext = path.extension(imageFile.path).toLowerCase();
    final fileName = 'logo$ext';
    final ref = _storage.ref().child('shop_sellers/$sellerId/$fileName');

    final metadata = SettableMetadata(
      contentType: 'image/${ext.replaceFirst('.', '')}',
      customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
    );

    await ref.putFile(imageFile, metadata);
    return ref.getDownloadURL();
  }

  /// Delete a product image from storage
  Future<void> deleteProductImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      debugPrint('[DeviceShop] Error deleting image: $e');
    }
  }

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

  /// Increment view count for analytics
  /// Fails silently if permission denied (non-critical operation)
  Future<void> incrementViewCount(String productId) async {
    try {
      await _productsCollection.doc(productId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      // Log but don't crash - view count is non-critical analytics
      debugPrint('Failed to increment view count for $productId: $e');
    }
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

  /// Create a product listing (for admins)
  Future<String> createProduct(ShopProduct product, {String? adminId}) async {
    final data = product.toFirestore();
    if (adminId != null) {
      data['createdBy'] = adminId;
    }
    final docRef = await _productsCollection.add(data);

    // Update seller's product count
    await _sellersCollection.doc(product.sellerId).update({
      'productCount': FieldValue.increment(1),
    });

    return docRef.id;
  }

  /// Update a product listing
  Future<void> updateProduct(
    String productId,
    Map<String, dynamic> updates, {
    String? adminId,
  }) async {
    updates['updatedAt'] = Timestamp.now();
    if (adminId != null) {
      updates['updatedBy'] = adminId;
    }
    await _productsCollection.doc(productId).update(updates);
  }

  /// Update full product
  Future<void> updateFullProduct(ShopProduct product, {String? adminId}) async {
    final data = product.toFirestore();
    data['updatedAt'] = Timestamp.now();
    if (adminId != null) {
      data['updatedBy'] = adminId;
    }
    await _productsCollection.doc(product.id).update(data);
  }

  /// Deactivate a product
  Future<void> deactivateProduct(String productId, {String? adminId}) async {
    final updates = <String, dynamic>{
      'isActive': false,
      'updatedAt': Timestamp.now(),
    };
    if (adminId != null) {
      updates['deletedBy'] = adminId;
      updates['deletedAt'] = Timestamp.now();
    }
    await _productsCollection.doc(productId).update(updates);
  }

  /// Reactivate a product
  Future<void> reactivateProduct(String productId, {String? adminId}) async {
    final updates = <String, dynamic>{
      'isActive': true,
      'updatedAt': Timestamp.now(),
      'deletedBy': FieldValue.delete(),
      'deletedAt': FieldValue.delete(),
    };
    if (adminId != null) {
      updates['updatedBy'] = adminId;
    }
    await _productsCollection.doc(productId).update(updates);
  }

  /// Delete a product permanently (admin only)
  Future<void> deleteProductPermanently(String productId) async {
    final product = await getProduct(productId);
    if (product == null) return;

    // Delete all product images from storage
    for (final imageUrl in product.imageUrls) {
      await deleteProductImage(imageUrl);
    }

    await _productsCollection.doc(productId).delete();

    // Update seller's product count
    await _sellersCollection.doc(product.sellerId).update({
      'productCount': FieldValue.increment(-1),
    });
  }

  /// Delete a product (soft delete by default)
  Future<void> deleteProduct(String productId, String sellerId) async {
    final product = await getProduct(productId);
    if (product?.sellerId != sellerId) {
      throw Exception('Not authorized to delete this product');
    }

    await _productsCollection.doc(productId).delete();

    // Update seller's product count
    await _sellersCollection.doc(sellerId).update({
      'productCount': FieldValue.increment(-1),
    });
  }

  // ============ ADMIN SELLER OPERATIONS ============

  /// Create a new seller
  Future<String> createSeller(ShopSeller seller, {String? adminId}) async {
    final data = seller.toFirestore();
    if (adminId != null) {
      data['createdBy'] = adminId;
    }
    final docRef = await _sellersCollection.add(data);
    return docRef.id;
  }

  /// Update a seller
  Future<void> updateSeller(
    String sellerId,
    Map<String, dynamic> updates, {
    String? adminId,
  }) async {
    updates['updatedAt'] = Timestamp.now();
    if (adminId != null) {
      updates['updatedBy'] = adminId;
    }
    await _sellersCollection.doc(sellerId).update(updates);
  }

  /// Update full seller
  Future<void> updateFullSeller(ShopSeller seller, {String? adminId}) async {
    final data = seller.toFirestore();
    data['updatedAt'] = Timestamp.now();
    if (adminId != null) {
      data['updatedBy'] = adminId;
    }
    await _sellersCollection.doc(seller.id).update(data);
  }

  /// Deactivate a seller
  Future<void> deactivateSeller(String sellerId, {String? adminId}) async {
    final updates = <String, dynamic>{
      'isActive': false,
      'updatedAt': Timestamp.now(),
    };
    if (adminId != null) {
      updates['deactivatedBy'] = adminId;
    }
    await _sellersCollection.doc(sellerId).update(updates);
  }

  /// Watch all sellers (including inactive) for admin
  Stream<List<ShopSeller>> watchAllSellersAdmin() {
    return _sellersCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopSeller.fromFirestore(doc))
              .toList(),
        );
  }

  /// Watch all products (including inactive) for admin
  Stream<List<ShopProduct>> watchAllProductsAdmin() {
    return _productsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .toList(),
        );
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
      int totalViews = 0;
      int officialPartners = 0;

      for (final doc in productsSnapshot.docs) {
        totalSales += (doc.data()['salesCount'] as int?) ?? 0;
        totalViews += (doc.data()['viewCount'] as int?) ?? 0;
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
        totalViews: totalViews,
        officialPartners: officialPartners,
      );
    } catch (e) {
      debugPrint('[DeviceShop] Error getting statistics: $e');
      return const ShopStatistics();
    }
  }

  /// Get extended admin statistics
  Future<AdminShopStatistics> getAdminStatistics() async {
    try {
      final allProductsSnapshot = await _productsCollection.get();
      final activeProductsSnapshot = await _productsCollection
          .where('isActive', isEqualTo: true)
          .get();
      final sellersSnapshot = await _sellersCollection.get();
      final reviewsSnapshot = await _reviewsCollection.get();

      int totalSales = 0;
      int totalViews = 0;
      double totalRevenue = 0;
      int outOfStock = 0;

      for (final doc in allProductsSnapshot.docs) {
        final data = doc.data();
        final sales = (data['salesCount'] as int?) ?? 0;
        final price = (data['price'] as num?)?.toDouble() ?? 0;
        totalSales += sales;
        totalViews += (data['viewCount'] as int?) ?? 0;
        totalRevenue += sales * price;
        if (data['isInStock'] == false) outOfStock++;
      }

      return AdminShopStatistics(
        totalProducts: allProductsSnapshot.docs.length,
        activeProducts: activeProductsSnapshot.docs.length,
        inactiveProducts:
            allProductsSnapshot.docs.length -
            activeProductsSnapshot.docs.length,
        totalSellers: sellersSnapshot.docs.length,
        totalReviews: reviewsSnapshot.docs.length,
        totalSales: totalSales,
        totalViews: totalViews,
        estimatedRevenue: totalRevenue,
        outOfStockProducts: outOfStock,
      );
    } catch (e) {
      debugPrint('[DeviceShop] Error getting admin statistics: $e');
      return const AdminShopStatistics();
    }
  }
}

/// Shop statistics
class ShopStatistics {
  final int totalProducts;
  final int totalSellers;
  final int totalSales;
  final int totalViews;
  final int officialPartners;

  const ShopStatistics({
    this.totalProducts = 0,
    this.totalSellers = 0,
    this.totalSales = 0,
    this.totalViews = 0,
    this.officialPartners = 0,
  });
}

/// Extended admin statistics
class AdminShopStatistics {
  final int totalProducts;
  final int activeProducts;
  final int inactiveProducts;
  final int totalSellers;
  final int totalReviews;
  final int totalSales;
  final int totalViews;
  final double estimatedRevenue;
  final int outOfStockProducts;

  const AdminShopStatistics({
    this.totalProducts = 0,
    this.activeProducts = 0,
    this.inactiveProducts = 0,
    this.totalSellers = 0,
    this.totalReviews = 0,
    this.totalSales = 0,
    this.totalViews = 0,
    this.estimatedRevenue = 0,
    this.outOfStockProducts = 0,
  });
}
