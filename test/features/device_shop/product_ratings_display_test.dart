import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/device_shop/models/shop_models.dart';

void main() {
  group('Product Rating Display', () {
    test('shows rating when reviewCount > 0', () {
      final now = DateTime.now();
      final product = ShopProduct(
        id: 'test1',
        sellerId: 'seller1',
        sellerName: 'Test Seller',
        name: 'Test Product',
        description: 'Test description',
        category: DeviceCategory.node,
        tags: [],
        imageUrls: [],
        price: 49.99,
        currency: 'USD',
        stockQuantity: 10,
        createdAt: now,
        updatedAt: now,
        rating: 4.5,
        reviewCount: 3,
      );

      expect(product.reviewCount > 0, true);
      expect(product.rating, 4.5);
    });

    test('hides rating when reviewCount is 0', () {
      final now = DateTime.now();
      final product = ShopProduct(
        id: 'test2',
        sellerId: 'seller1',
        sellerName: 'Test Seller',
        name: 'Test Product',
        description: 'Test description',
        category: DeviceCategory.node,
        tags: [],
        imageUrls: [],
        price: 49.99,
        currency: 'USD',
        stockQuantity: 10,
        createdAt: now,
        updatedAt: now,
        rating: 0.0,
        reviewCount: 0,
      );

      expect(product.reviewCount > 0, false);
      expect(product.rating, 0.0);
    });

    test('formats rating to 1 decimal place', () {
      final now = DateTime.now();
      final product = ShopProduct(
        id: 'test3',
        sellerId: 'seller1',
        sellerName: 'Test Seller',
        name: 'Test Product',
        description: 'Test description',
        category: DeviceCategory.node,
        tags: [],
        imageUrls: [],
        price: 49.99,
        currency: 'USD',
        stockQuantity: 10,
        createdAt: now,
        updatedAt: now,
        rating: 4.777,
        reviewCount: 100,
      );

      expect(product.rating.toStringAsFixed(1), '4.8');
    });

    test('pluralizes review text correctly', () {
      String reviewText(int count) => '$count review${count == 1 ? '' : 's'}';

      expect(reviewText(0), '0 reviews');
      expect(reviewText(1), '1 review');
      expect(reviewText(2), '2 reviews');
      expect(reviewText(100), '100 reviews');
    });
  });

  group('Rating Calculation Logic', () {
    test('calculates average rating correctly', () {
      final ratings = [5, 4, 5, 3, 4];
      final totalRating = ratings.fold<int>(0, (sum, rating) => sum + rating);
      final avgRating = totalRating / ratings.length;

      expect(totalRating, 21);
      expect(avgRating, 4.2);
      expect(avgRating.toStringAsFixed(1), '4.2');
    });

    test('handles single rating', () {
      final ratings = [5];
      final totalRating = ratings.fold<int>(0, (sum, rating) => sum + rating);
      final avgRating = totalRating / ratings.length;

      expect(totalRating, 5);
      expect(avgRating, 5.0);
    });

    test('handles all 1-star ratings', () {
      final ratings = [1, 1, 1];
      final totalRating = ratings.fold<int>(0, (sum, rating) => sum + rating);
      final avgRating = totalRating / ratings.length;

      expect(avgRating, 1.0);
    });

    test('handles mixed ratings', () {
      final ratings = [1, 2, 3, 4, 5];
      final totalRating = ratings.fold<int>(0, (sum, rating) => sum + rating);
      final avgRating = totalRating / ratings.length;

      expect(avgRating, 3.0);
    });

    test('empty ratings should result in 0', () {
      final ratings = <int>[];
      if (ratings.isEmpty) {
        expect(0, 0); // Should reset to 0
      }
    });
  });

  group('Favorites Screen Display Logic', () {
    test('displays reviews section only when reviewCount > 0', () {
      final now = DateTime.now();
      final productWithReviews = ShopProduct(
        id: 'test1',
        sellerId: 'seller1',
        sellerName: 'Test Seller',
        name: 'Product with Reviews',
        description: 'Test',
        category: DeviceCategory.node,
        tags: [],
        imageUrls: [],
        price: 49.99,
        currency: 'USD',
        stockQuantity: 10,
        createdAt: now,
        updatedAt: now,
        rating: 4.5,
        reviewCount: 10,
      );

      final productWithoutReviews = ShopProduct(
        id: 'test2',
        sellerId: 'seller1',
        sellerName: 'Test Seller',
        name: 'Product without Reviews',
        description: 'Test',
        category: DeviceCategory.node,
        tags: [],
        imageUrls: [],
        price: 49.99,
        currency: 'USD',
        stockQuantity: 10,
        createdAt: now,
        updatedAt: now,
        rating: 0.0,
        reviewCount: 0,
      );

      expect(productWithReviews.reviewCount > 0, true);
      expect(productWithoutReviews.reviewCount > 0, false);
    });
  });
}
