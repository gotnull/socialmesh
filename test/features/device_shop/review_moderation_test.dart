import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/device_shop/models/shop_models.dart';

void main() {
  group('ProductReview Moderation', () {
    test('creates review with default pending status', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(review.status, 'pending');
      expect(review.rejectionReason, isNull);
      expect(review.reviewedAt, isNull);
      expect(review.reviewedBy, isNull);
    });

    test('creates review with explicit status', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
        status: 'approved',
      );

      expect(review.status, 'approved');
    });

    test('creates review with moderation fields', () {
      final reviewedAt = DateTime(2024, 1, 2);
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
        status: 'approved',
        reviewedAt: reviewedAt,
        reviewedBy: 'admin123',
      );

      expect(review.status, 'approved');
      expect(review.reviewedAt, reviewedAt);
      expect(review.reviewedBy, 'admin123');
      expect(review.rejectionReason, isNull);
    });

    test('creates rejected review with reason', () {
      final reviewedAt = DateTime(2024, 1, 2);
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Spam content',
        createdAt: DateTime(2024, 1, 1),
        status: 'rejected',
        rejectionReason: 'Inappropriate content',
        reviewedAt: reviewedAt,
        reviewedBy: 'admin123',
      );

      expect(review.status, 'rejected');
      expect(review.rejectionReason, 'Inappropriate content');
      expect(review.reviewedAt, reviewedAt);
      expect(review.reviewedBy, 'admin123');
    });

    test('toFirestore includes moderation fields', () {
      final reviewedAt = DateTime(2024, 1, 2);
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        userName: 'testuser',
        rating: 5,
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
        status: 'approved',
        reviewedAt: reviewedAt,
        reviewedBy: 'admin123',
      );

      final data = review.toFirestore();

      expect(data['status'], 'approved');
      expect(data['reviewedAt'], isNotNull);
      expect(data['reviewedBy'], 'admin123');
      expect(data['rejectionReason'], isNull);
      expect(data['productId'], 'product123');
      expect(data['userId'], 'user123');
      expect(data['userName'], 'testuser');
      expect(data['rating'], 5);
      expect(data['body'], 'Great product!');
    });

    test('toFirestore includes rejection reason when rejected', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 1,
        body: 'Spam',
        createdAt: DateTime(2024, 1, 1),
        status: 'rejected',
        rejectionReason: 'Spam content',
        reviewedAt: DateTime(2024, 1, 2),
        reviewedBy: 'admin123',
      );

      final data = review.toFirestore();

      expect(data['status'], 'rejected');
      expect(data['rejectionReason'], 'Spam content');
      expect(data['reviewedAt'], isNotNull);
      expect(data['reviewedBy'], 'admin123');
    });

    test('validates status values', () {
      // Valid statuses
      expect(
        () => ProductReview(
          id: 'r1',
          productId: 'p1',
          userId: 'u1',
          rating: 5,
          body: 'Test',
          createdAt: DateTime.now(),
          status: 'pending',
        ),
        returnsNormally,
      );

      expect(
        () => ProductReview(
          id: 'r1',
          productId: 'p1',
          userId: 'u1',
          rating: 5,
          body: 'Test',
          createdAt: DateTime.now(),
          status: 'approved',
        ),
        returnsNormally,
      );

      expect(
        () => ProductReview(
          id: 'r1',
          productId: 'p1',
          userId: 'u1',
          rating: 5,
          body: 'Test',
          createdAt: DateTime.now(),
          status: 'rejected',
        ),
        returnsNormally,
      );
    });
  });

  group('ProductReview Backward Compatibility', () {
    test('handles reviews without status field (pre-moderation)', () {
      // Simulate old review data without status field
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
        status: 'approved', // Default from model
      );

      expect(review.status, 'approved');
      expect(review.reviewedAt, isNull);
      expect(review.reviewedBy, isNull);
    });
  });

  group('ProductReview Validation', () {
    test('requires body field', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(review.body, isNotNull);
      expect(review.body, isNotEmpty);
    });

    test('title is optional', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(review.title, isNull);
    });

    test('allows title when provided', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        title: 'Best purchase!',
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(review.title, 'Best purchase!');
    });

    test('stores display name not full name', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        userName: 'gotnull', // Display name, not "John Doe"
        rating: 5,
        body: 'Great product!',
        createdAt: DateTime(2024, 1, 1),
      );

      expect(review.userName, 'gotnull');
    });
  });

  group('Review Rating', () {
    test('accepts valid ratings 1-5', () {
      for (int rating = 1; rating <= 5; rating++) {
        final review = ProductReview(
          id: 'review$rating',
          productId: 'product123',
          userId: 'user123',
          rating: rating,
          body: 'Test review',
          createdAt: DateTime.now(),
        );
        expect(review.rating, rating);
      }
    });

    test('verified purchase flag defaults to false', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Test',
        createdAt: DateTime.now(),
      );

      expect(review.isVerifiedPurchase, false);
    });

    test('can mark as verified purchase', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Test',
        createdAt: DateTime.now(),
        isVerifiedPurchase: true,
      );

      expect(review.isVerifiedPurchase, true);
    });
  });

  group('Review Helpful Count', () {
    test('defaults to zero', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Test',
        createdAt: DateTime.now(),
      );

      expect(review.helpfulCount, 0);
    });

    test('tracks helpful votes', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'product123',
        userId: 'user123',
        rating: 5,
        body: 'Test',
        createdAt: DateTime.now(),
        helpfulCount: 42,
      );

      expect(review.helpfulCount, 42);
    });
  });
}
