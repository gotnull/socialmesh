// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:socialmesh/core/logging.dart';
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
      AppLogging.app('[DeviceShop] Error checking admin status: $e');
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
      AppLogging.app(
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
      AppLogging.app('[DeviceShop] Error deleting image: $e');
    }
  }

  // ============ PRODUCT OPERATIONS ============

  /// Get set of active seller IDs for filtering products
  Future<Set<String>> _getActiveSellerIds() async {
    final snapshot = await _sellersCollection.get();
    return snapshot.docs
        .map((doc) => ShopSeller.fromFirestore(doc))
        .where((s) => s.isActive)
        .map((s) => s.id)
        .toSet();
  }

  /// Watch all active products (from active sellers only)
  /// Note: Filters client-side for isActive/isFeatured/isInStock to handle
  /// documents that may be missing these fields (backward compatibility)
  Stream<List<ShopProduct>> watchProducts({
    DeviceCategory? category,
    String? sellerId,
    bool? featuredOnly,
    bool? inStockOnly,
    String? searchQuery,
  }) {
    // Start with base query - only use where clauses for fields that
    // are guaranteed to exist (category, sellerId set at creation time)
    Query<Map<String, dynamic>> query = _productsCollection;

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (sellerId != null) {
      query = query.where('sellerId', isEqualTo: sellerId);
    }

    return query.snapshots().asyncMap((snapshot) async {
      final activeSellerIds = await _getActiveSellerIds();
      var products = snapshot.docs
          .map((doc) => ShopProduct.fromFirestore(doc))
          .toList();

      // Client-side filters for fields that might be missing in old documents
      // Model defaults: isActive=true, isFeatured=false, isInStock=true
      // Also filter by active sellers
      products = products
          .where((p) => p.isActive && activeSellerIds.contains(p.sellerId))
          .toList();

      if (featuredOnly == true) {
        products = products.where((p) => p.isFeatured).toList();
      }

      if (inStockOnly == true) {
        products = products.where((p) => p.isInStock).toList();
      }

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

  /// Watch featured products (from active sellers only)
  /// Note: Filters client-side for backward compatibility with old documents
  Stream<List<ShopProduct>> watchFeaturedProducts({int limit = 10}) {
    return _productsCollection.snapshots().asyncMap((snapshot) async {
      final activeSellerIds = await _getActiveSellerIds();
      final products = snapshot.docs
          .map((doc) => ShopProduct.fromFirestore(doc))
          .where(
            (p) =>
                p.isActive &&
                p.isFeatured &&
                activeSellerIds.contains(p.sellerId),
          )
          .take(limit)
          .toList();
      return products;
    });
  }

  /// Watch new arrivals (from active sellers only)
  /// Note: Filters client-side for backward compatibility with old documents
  Stream<List<ShopProduct>> watchNewArrivals({int limit = 20}) {
    return _productsCollection.snapshots().asyncMap((snapshot) async {
      final activeSellerIds = await _getActiveSellerIds();
      final products =
          snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .where((p) => p.isActive && activeSellerIds.contains(p.sellerId))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return products.take(limit).toList();
    });
  }

  /// Watch best sellers (from active sellers only)
  /// Note: Filters client-side for backward compatibility with old documents
  Stream<List<ShopProduct>> watchBestSellers({int limit = 20}) {
    return _productsCollection.snapshots().asyncMap((snapshot) async {
      final activeSellerIds = await _getActiveSellerIds();
      final products =
          snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .where((p) => p.isActive && activeSellerIds.contains(p.sellerId))
              .toList()
            ..sort((a, b) => b.salesCount.compareTo(a.salesCount));
      return products.take(limit).toList();
    });
  }

  /// Watch trending products by view count (from active sellers only)
  /// Used for "Popular" section - safe because it's based on product data, not user input
  Stream<List<ShopProduct>> watchTrendingProducts({int limit = 8}) {
    return _productsCollection.snapshots().asyncMap((snapshot) async {
      final activeSellerIds = await _getActiveSellerIds();
      final products =
          snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .where((p) => p.isActive && activeSellerIds.contains(p.sellerId))
              .toList()
            ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
      return products.take(limit).toList();
    });
  }

  /// Watch products on sale (from active sellers only)
  /// Note: Filters client-side for backward compatibility with old documents
  Stream<List<ShopProduct>> watchOnSale({int limit = 20}) {
    return _productsCollection.snapshots().asyncMap((snapshot) async {
      final activeSellerIds = await _getActiveSellerIds();
      final products = snapshot.docs
          .map((doc) => ShopProduct.fromFirestore(doc))
          .where(
            (p) =>
                p.isActive &&
                (p.compareAtPrice ?? 0) > 0 &&
                activeSellerIds.contains(p.sellerId),
          )
          .take(limit)
          .toList();
      return products;
    });
  }

  /// Watch products by category (from active sellers only)
  /// Note: Filters client-side for backward compatibility with old documents
  Stream<List<ShopProduct>> watchByCategory(DeviceCategory category) {
    return _productsCollection
        .where('category', isEqualTo: category.name)
        .snapshots()
        .asyncMap((snapshot) async {
          final activeSellerIds = await _getActiveSellerIds();
          return snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .where((p) => p.isActive && activeSellerIds.contains(p.sellerId))
              .toList()
            ..sort((a, b) => b.salesCount.compareTo(a.salesCount));
        });
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
      AppLogging.app('Failed to increment view count for $productId: $e');
    }
  }

  /// Search products (from active sellers only)
  /// Note: Filters client-side for backward compatibility with old documents
  Future<List<ShopProduct>> searchProducts(String query) async {
    if (query.isEmpty) return [];

    // Get all products and filter client-side
    // For production, consider using Algolia or similar
    final snapshot = await _productsCollection.get();
    final activeSellerIds = await _getActiveSellerIds();

    final products = snapshot.docs
        .map((doc) => ShopProduct.fromFirestore(doc))
        .where((p) => p.isActive && activeSellerIds.contains(p.sellerId))
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
  /// Note: Filters client-side for backward compatibility with old documents
  Stream<List<ShopSeller>> watchSellers() {
    return _sellersCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => ShopSeller.fromFirestore(doc))
              .where((s) => s.isActive)
              .toList()
            ..sort((a, b) {
              // Sort official partners first
              if (a.isOfficialPartner != b.isOfficialPartner) {
                return a.isOfficialPartner ? -1 : 1;
              }
              return a.name.compareTo(b.name);
            }),
    );
  }

  /// Watch official partners
  /// Note: Filters client-side for backward compatibility with old documents
  Stream<List<ShopSeller>> watchOfficialPartners() {
    return _sellersCollection.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ShopSeller.fromFirestore(doc))
          .where((s) => s.isActive && s.isOfficialPartner)
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

  /// Watch reviews for a product (only approved reviews for public view)
  /// Note: Reviews without a status field (created before moderation) are treated as approved
  Stream<List<ProductReview>> watchProductReviews(String productId) {
    return _reviewsCollection
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map((snapshot) {
          final reviews =
              snapshot.docs
                  .where((doc) {
                    // Show reviews that are approved OR don't have a status field (backward compatibility)
                    final data = doc.data();
                    final hasStatusField = data.containsKey('status');
                    final status = data['status'] as String?;
                    return !hasStatusField || status == 'approved';
                  })
                  .map((doc) => ProductReview.fromFirestore(doc))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }

  /// Watch ALL reviews for a product (admin only, includes pending/rejected)
  Stream<List<ProductReview>> watchAllProductReviews(String productId) {
    return _reviewsCollection
        .where('productId', isEqualTo: productId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ProductReview.fromFirestore(doc))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  /// Watch all pending reviews (admin moderation)
  Stream<List<ProductReview>> watchPendingReviews() {
    return _reviewsCollection
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ProductReview.fromFirestore(doc))
                  .toList()
                ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
        );
  }

  /// Watch ALL reviews for admin management (including those without status)
  Stream<List<ProductReview>> watchAllReviews() {
    return _reviewsCollection.snapshots().map((snapshot) {
      final reviews = snapshot.docs.map((doc) {
        try {
          return ProductReview.fromFirestore(doc);
        } catch (e) {
          // Handle old reviews without status field
          AppLogging.app('Error parsing review ${doc.id}: $e');
          // Return a review with pending status as fallback
          final data = doc.data();
          return ProductReview(
            id: doc.id,
            productId: data['productId'] as String? ?? '',
            userId: data['userId'] as String? ?? '',
            userName: data['userName'] as String? ?? 'Unknown',
            rating: data['rating'] as int? ?? 0,
            body: data['body'] as String?,
            createdAt:
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            status: data['status'] as String? ?? 'legacy', // Mark old reviews
          );
        }
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return reviews;
    });
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
    // Fetch all reviews for this product and filter client-side
    // to handle old reviews that may be missing the status field
    // (those default to 'approved' in the model)
    final snapshot = await _reviewsCollection
        .where('productId', isEqualTo: productId)
        .get();

    final approvedReviews = snapshot.docs
        .map((doc) => ProductReview.fromFirestore(doc))
        .where((r) => r.status == 'approved')
        .toList();

    if (approvedReviews.isEmpty) {
      // No approved reviews, reset to defaults
      await _productsCollection.doc(productId).update({
        'rating': 0.0,
        'reviewCount': 0,
      });
      return;
    }

    final totalRating = approvedReviews.fold<int>(
      0,
      (total, review) => total + review.rating,
    );
    final avgRating = totalRating / approvedReviews.length;

    await _productsCollection.doc(productId).update({
      'rating': avgRating,
      'reviewCount': approvedReviews.length,
    });
  }

  /// Mark review as helpful
  Future<void> markReviewHelpful(String reviewId) async {
    await _reviewsCollection.doc(reviewId).update({
      'helpfulCount': FieldValue.increment(1),
    });
  }

  /// Approve a review (admin only)
  Future<void> approveReview(String reviewId, String adminId) async {
    await _reviewsCollection.doc(reviewId).update({
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminId,
    });

    // Update product rating after approval
    final review = await _reviewsCollection.doc(reviewId).get();
    final productId = review.data()?['productId'] as String?;
    if (productId != null) {
      await _updateProductRating(productId);
    }
  }

  /// Reject a review (admin only)
  Future<void> rejectReview(
    String reviewId,
    String adminId,
    String reason,
  ) async {
    await _reviewsCollection.doc(reviewId).update({
      'status': 'rejected',
      'rejectionReason': reason,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': adminId,
    });
  }

  /// Delete a review (admin only)
  Future<void> deleteReview(String reviewId) async {
    final review = await _reviewsCollection.doc(reviewId).get();
    await _reviewsCollection.doc(reviewId).delete();

    // Update product rating after deletion
    final productId = review.data()?['productId'] as String?;
    if (productId != null) {
      await _updateProductRating(productId);
    }
  }

  // ============ FAVORITES OPERATIONS ============

  /// Watch user's favorites
  Stream<List<ProductFavorite>> watchUserFavorites(String oderId) {
    return _favoritesCollection
        .where('userId', isEqualTo: oderId)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ProductFavorite.fromFirestore(doc))
                  .toList()
                ..sort((a, b) => b.addedAt.compareTo(a.addedAt)),
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

  /// Deactivate a seller (soft delete)
  Future<void> deactivateSeller(String sellerId, {String? adminId}) async {
    final updates = <String, dynamic>{
      'isActive': false,
      'updatedAt': Timestamp.now(),
      'deactivatedAt': Timestamp.now(),
    };
    if (adminId != null) {
      updates['deactivatedBy'] = adminId;
    }
    await _sellersCollection.doc(sellerId).update(updates);
  }

  /// Reactivate a seller
  Future<void> reactivateSeller(String sellerId, {String? adminId}) async {
    final updates = <String, dynamic>{
      'isActive': true,
      'updatedAt': Timestamp.now(),
      'deactivatedAt': FieldValue.delete(),
      'deactivatedBy': FieldValue.delete(),
    };
    if (adminId != null) {
      updates['updatedBy'] = adminId;
    }
    await _sellersCollection.doc(sellerId).update(updates);
  }

  /// Delete a seller permanently (admin only)
  /// This also deactivates all products from this seller
  Future<void> deleteSellerPermanently(String sellerId) async {
    // Deactivate all products from this seller
    final productsSnapshot = await _productsCollection
        .where('sellerId', isEqualTo: sellerId)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in productsSnapshot.docs) {
      batch.update(doc.reference, {
        'isActive': false,
        'deletedAt': Timestamp.now(),
        'deletedReason': 'Seller deleted',
      });
    }

    // Delete the seller
    batch.delete(_sellersCollection.doc(sellerId));

    await batch.commit();
  }

  /// Update featured order for products (batch operation)
  Future<void> updateFeaturedOrders(
    Map<String, int> productOrders, {
    String? adminId,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    for (final entry in productOrders.entries) {
      final updates = <String, dynamic>{
        'featuredOrder': entry.value,
        'updatedAt': Timestamp.now(),
      };
      if (adminId != null) {
        updates['updatedBy'] = adminId;
      }
      batch.update(_productsCollection.doc(entry.key), updates);
    }

    await batch.commit();
  }

  /// Watch featured products ordered by featuredOrder
  /// Note: Filters client-side for backward compatibility with old documents
  Stream<List<ShopProduct>> watchFeaturedProductsOrdered() {
    return _productsCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => ShopProduct.fromFirestore(doc))
              .where((p) => p.isActive && p.isFeatured)
              .toList()
            ..sort((a, b) => a.featuredOrder.compareTo(b.featuredOrder)),
    );
  }

  /// Watch all sellers (including inactive) for admin
  Stream<List<ShopSeller>> watchAllSellersAdmin() {
    return _sellersCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ShopSeller.fromFirestore(doc)).toList()
            ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt)),
    );
  }

  /// Watch all products (including inactive) for admin
  Stream<List<ShopProduct>> watchAllProductsAdmin() {
    return _productsCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => ShopProduct.fromFirestore(doc)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  // ============ ANALYTICS ============

  /// Get shop statistics
  /// Note: Filters client-side for backward compatibility with old documents
  Future<ShopStatistics> getShopStatistics() async {
    try {
      final productsSnapshot = await _productsCollection.get();
      final sellersSnapshot = await _sellersCollection.get();

      final activeProducts = productsSnapshot.docs
          .map((doc) => ShopProduct.fromFirestore(doc))
          .where((p) => p.isActive)
          .toList();
      final activeSellers = sellersSnapshot.docs
          .map((doc) => ShopSeller.fromFirestore(doc))
          .where((s) => s.isActive)
          .toList();

      int totalProducts = activeProducts.length;
      int totalSellers = activeSellers.length;
      int totalSales = 0;
      int totalViews = 0;
      int officialPartners = 0;

      for (final product in activeProducts) {
        totalSales += product.salesCount;
        totalViews += product.viewCount;
      }

      for (final seller in activeSellers) {
        if (seller.isOfficialPartner) {
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
      AppLogging.app('[DeviceShop] Error getting statistics: $e');
      return const ShopStatistics();
    }
  }

  /// Get extended admin statistics
  /// Note: Filters client-side for backward compatibility with old documents
  Future<AdminShopStatistics> getAdminStatistics() async {
    try {
      final allProductsSnapshot = await _productsCollection.get();
      final allProducts = allProductsSnapshot.docs
          .map((doc) => ShopProduct.fromFirestore(doc))
          .toList();
      final activeProducts = allProducts.where((p) => p.isActive).toList();
      final sellersSnapshot = await _sellersCollection.get();
      final reviewsSnapshot = await _reviewsCollection.get();

      int totalSales = 0;
      int totalViews = 0;
      double totalRevenue = 0;
      int outOfStock = 0;

      for (final product in allProducts) {
        totalSales += product.salesCount;
        totalViews += product.viewCount;
        totalRevenue += product.salesCount * product.price;
        if (!product.isInStock) outOfStock++;
      }

      return AdminShopStatistics(
        totalProducts: allProducts.length,
        activeProducts: activeProducts.length,
        inactiveProducts: allProducts.length - activeProducts.length,
        totalSellers: sellersSnapshot.docs.length,
        totalReviews: reviewsSnapshot.docs.length,
        totalSales: totalSales,
        totalViews: totalViews,
        estimatedRevenue: totalRevenue,
        outOfStockProducts: outOfStock,
      );
    } catch (e) {
      AppLogging.app('[DeviceShop] Error getting admin statistics: $e');
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
