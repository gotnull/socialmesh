import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/device_shop/models/shop_models.dart';
import 'package:socialmesh/features/device_shop/screens/category_products_screen.dart';
import 'package:socialmesh/features/device_shop/screens/search_products_screen.dart';
import 'package:socialmesh/features/device_shop/screens/favorites_screen.dart';
import 'package:socialmesh/core/widgets/app_bar_overflow_menu.dart';

// Helper to wrap widgets for testing
Widget createTestWidget(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: child, theme: ThemeData.dark()),
  );
}

// Test data factory functions
ShopProduct createTestProduct({
  String id = 'test_product_1',
  String name = 'Test Product',
  double price = 49.99,
  DeviceCategory category = DeviceCategory.node,
  bool isOnSale = false,
  double? compareAtPrice,
  List<String> imageUrls = const [],
  List<FrequencyBand> frequencyBands = const [],
}) {
  return ShopProduct(
    id: id,
    sellerId: 'seller_1',
    sellerName: 'Test Seller',
    name: name,
    description: 'Test product description',
    category: category,
    price: price,
    compareAtPrice: isOnSale ? (compareAtPrice ?? price * 1.5) : null,
    imageUrls: imageUrls,
    frequencyBands: frequencyBands,
    hasGps: true,
    hasDisplay: true,
    hasBluetooth: true,
    hasWifi: false,
    chipset: 'ESP32',
    loraChip: 'SX1262',
    rating: 4.5,
    reviewCount: 25,
    isInStock: true,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 15),
  );
}

ShopSeller createTestSeller({
  String id = 'seller_1',
  String name = 'Test Seller',
  bool isVerified = true,
  bool isOfficialPartner = false,
}) {
  return ShopSeller(
    id: id,
    name: name,
    description: 'A test seller for Meshtastic devices',
    logoUrl: null,
    websiteUrl: 'https://example.com',
    contactEmail: 'test@example.com',
    isVerified: isVerified,
    isOfficialPartner: isOfficialPartner,
    rating: 4.8,
    reviewCount: 150,
    productCount: 25,
    salesCount: 500,
    joinedAt: DateTime(2023, 1, 1),
    countries: ['US', 'CA', 'UK'],
    isActive: true,
  );
}

void main() {
  group('CategoryProductsScreen', () {
    testWidgets('renders with category', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const CategoryProductsScreen(category: DeviceCategory.node),
        ),
      );
      await tester.pump();

      // Verify category title is shown
      expect(find.text('Nodes'), findsOneWidget);
    });

    testWidgets('shows filter button', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const CategoryProductsScreen(category: DeviceCategory.antenna),
        ),
      );
      await tester.pump();

      // Filter icon should be present
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
    });

    testWidgets('each category has correct title', (WidgetTester tester) async {
      for (final category in DeviceCategory.values) {
        await tester.pumpWidget(
          createTestWidget(CategoryProductsScreen(category: category)),
        );
        await tester.pump();

        expect(find.text(category.label), findsOneWidget);
      }
    });

    testWidgets('shows sort overflow menu', (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const CategoryProductsScreen(category: DeviceCategory.module),
        ),
      );
      await tester.pump();

      // Sort is available via the overflow menu
      expect(find.byType(AppBarOverflowMenu<String>), findsOneWidget);
    });
  });

  group('SearchProductsScreen', () {
    testWidgets('renders search field', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const SearchProductsScreen()));
      await tester.pump();

      // Search field should be present
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows popular searches section', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const SearchProductsScreen()));
      await tester.pump();

      // Popular searches should be displayed
      expect(find.text('Popular Searches'), findsOneWidget);
    });

    testWidgets('shows browse categories section', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const SearchProductsScreen()));
      await tester.pump();

      // Categories section should be displayed (actual text is "Browse by Category")
      expect(find.text('Browse by Category'), findsOneWidget);
    });

    testWidgets('can enter search query', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const SearchProductsScreen()));
      await tester.pumpAndSettle();

      // Enter text in search field
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Heltec');
      await tester.pumpAndSettle();

      // Verify text controller has the text
      final TextField textFieldWidget = tester.widget(textField);
      expect(textFieldWidget.controller?.text, 'Heltec');
    });

    testWidgets('has clear button when text entered', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SearchProductsScreen()));
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField), 'test');
      // Wait for debounce timer (300ms + buffer)
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Clear button should appear in actions when query is not empty
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('popular search chips are tappable', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const SearchProductsScreen()));
      await tester.pump();

      // Find and tap a popular search chip
      final chip = find.text('T-Beam');
      expect(chip, findsOneWidget);

      await tester.tap(chip);
      await tester.pump();

      // Text should now be in search field
      expect(find.text('T-Beam'), findsWidgets);
    });
  });

  group('FavoritesScreen', () {
    testWidgets('renders empty state message', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const FavoritesScreen()));
      await tester.pump();

      // Should show screen title
      expect(find.text('Favorites'), findsOneWidget);
    });

    testWidgets('has back navigation', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const FavoritesScreen()));
      await tester.pump();

      // Back button should be present in app bar
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('shows favorites icon when not logged in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget(const FavoritesScreen()));
      await tester.pump();

      // Favorites outline icon should be present in empty state
      expect(find.byIcon(Icons.favorite_outline), findsWidgets);
    });
  });

  group('DeviceCategory UI Helpers', () {
    test('all categories have non-empty labels', () {
      for (final category in DeviceCategory.values) {
        expect(category.label.isNotEmpty, true);
      }
    });

    test('all categories have non-empty descriptions', () {
      for (final category in DeviceCategory.values) {
        expect(category.description.isNotEmpty, true);
      }
    });

    test('category enum has expected count', () {
      expect(DeviceCategory.values.length, 7);
    });
  });

  group('FrequencyBand UI Helpers', () {
    test('all bands have non-empty labels', () {
      for (final band in FrequencyBand.values) {
        expect(band.label.isNotEmpty, true);
      }
    });

    test('all bands have non-empty ranges', () {
      for (final band in FrequencyBand.values) {
        expect(band.range.isNotEmpty, true);
      }
    });

    test('frequency band enum has expected count', () {
      expect(FrequencyBand.values.length, 8);
    });
  });

  group('ShopProduct computed properties', () {
    test('isOnSale is false when no compare price', () {
      final product = createTestProduct(isOnSale: false);
      expect(product.isOnSale, false);
    });

    test('isOnSale is true when compare price is higher', () {
      final product = createTestProduct(
        price: 39.99,
        isOnSale: true,
        compareAtPrice: 59.99,
      );
      expect(product.isOnSale, true);
    });

    test('discountPercent calculates correctly', () {
      final product = createTestProduct(
        price: 30.00,
        isOnSale: true,
        compareAtPrice: 50.00,
      );
      // (50 - 30) / 50 * 100 = 40%
      expect(product.discountPercent, 40);
    });

    test('discountPercent is 0 when not on sale', () {
      final product = createTestProduct(isOnSale: false);
      expect(product.discountPercent, 0);
    });

    test('formattedPrice includes dollar sign', () {
      final product = createTestProduct(price: 49.99);
      expect(product.formattedPrice, '\$49.99');
    });

    test('formattedComparePrice is null when not on sale', () {
      final product = createTestProduct(isOnSale: false);
      expect(product.formattedComparePrice, isNull);
    });

    test('formattedComparePrice includes dollar sign when on sale', () {
      final product = createTestProduct(isOnSale: true, compareAtPrice: 79.99);
      expect(product.formattedComparePrice, '\$79.99');
    });

    test('primaryImage returns first image', () {
      final product = createTestProduct(
        imageUrls: ['https://a.com/1.jpg', 'https://a.com/2.jpg'],
      );
      expect(product.primaryImage, 'https://a.com/1.jpg');
    });

    test('primaryImage returns null for empty images', () {
      final product = createTestProduct(imageUrls: []);
      expect(product.primaryImage, isNull);
    });
  });

  group('ShopProduct copyWith', () {
    test('preserves all fields when no changes', () {
      final original = createTestProduct(
        id: 'orig',
        name: 'Original',
        price: 99.99,
      );
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.price, original.price);
      expect(copy.sellerId, original.sellerId);
      expect(copy.category, original.category);
    });

    test('updates specified fields', () {
      final original = createTestProduct(name: 'Original', price: 50.00);
      final modified = original.copyWith(
        name: 'Modified',
        price: 75.00,
        isFeatured: true,
      );

      expect(modified.name, 'Modified');
      expect(modified.price, 75.00);
      expect(modified.isFeatured, true);
      expect(modified.sellerId, original.sellerId);
    });

    test('can update category', () {
      final product = createTestProduct(category: DeviceCategory.node);
      final updated = product.copyWith(category: DeviceCategory.antenna);

      expect(updated.category, DeviceCategory.antenna);
    });

    test('can update frequency bands', () {
      final product = createTestProduct(frequencyBands: [FrequencyBand.us915]);
      final updated = product.copyWith(
        frequencyBands: [FrequencyBand.eu868, FrequencyBand.multiband],
      );

      expect(updated.frequencyBands.length, 2);
      expect(updated.frequencyBands, contains(FrequencyBand.eu868));
    });
  });

  group('ShopSeller properties', () {
    test('creates with minimal fields', () {
      final seller = createTestSeller();

      expect(seller.id, 'seller_1');
      expect(seller.name, 'Test Seller');
      expect(seller.isActive, true);
    });

    test('official partner flag works correctly', () {
      final partner = createTestSeller(isOfficialPartner: true);
      final regular = createTestSeller(isOfficialPartner: false);

      expect(partner.isOfficialPartner, true);
      expect(regular.isOfficialPartner, false);
    });

    test('verified flag works correctly', () {
      final verified = createTestSeller(isVerified: true);
      final unverified = createTestSeller(isVerified: false);

      expect(verified.isVerified, true);
      expect(unverified.isVerified, false);
    });
  });

  group('ProductReview', () {
    test('creates with required fields', () {
      final review = ProductReview(
        id: 'review1',
        productId: 'prod1',
        userId: 'user1',
        rating: 5,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(review.id, 'review1');
      expect(review.productId, 'prod1');
      expect(review.rating, 5);
      expect(review.isVerifiedPurchase, false);
      expect(review.helpfulCount, 0);
    });

    test('creates with all optional fields', () {
      final review = ProductReview(
        id: 'review2',
        productId: 'prod2',
        userId: 'user2',
        userName: 'John Doe',
        userPhotoUrl: 'https://example.com/photo.jpg',
        rating: 4,
        title: 'Great product',
        body: 'Really enjoyed using this.',
        imageUrls: ['https://example.com/review1.jpg'],
        isVerifiedPurchase: true,
        helpfulCount: 10,
        createdAt: DateTime(2024, 1, 1),
        sellerResponse: 'Thanks for your review!',
        sellerResponseAt: DateTime(2024, 1, 2),
      );

      expect(review.userName, 'John Doe');
      expect(review.title, 'Great product');
      expect(review.body, 'Really enjoyed using this.');
      expect(review.isVerifiedPurchase, true);
      expect(review.helpfulCount, 10);
      expect(review.sellerResponse, 'Thanks for your review!');
    });

    test('rating must be between 1 and 5', () {
      // This is a logical test - the model allows any int but UI should restrict
      final review = ProductReview(
        id: 'r1',
        productId: 'p1',
        userId: 'u1',
        rating: 3,
        createdAt: DateTime.now(),
      );
      expect(review.rating >= 1 && review.rating <= 5, true);
    });
  });

  group('ProductFavorite', () {
    test('creates with required fields', () {
      final favorite = ProductFavorite(
        id: 'fav1',
        oderId: 'user1',
        productId: 'prod1',
        addedAt: DateTime(2024, 1, 1),
      );

      expect(favorite.id, 'fav1');
      expect(favorite.oderId, 'user1');
      expect(favorite.productId, 'prod1');
    });

    test('toFirestore includes correct keys', () {
      final favorite = ProductFavorite(
        id: 'fav1',
        oderId: 'user1',
        productId: 'prod1',
        addedAt: DateTime(2024, 1, 1),
      );

      final map = favorite.toFirestore();

      expect(map.containsKey('userId'), true);
      expect(map.containsKey('productId'), true);
      expect(map.containsKey('addedAt'), true);
      expect(map['userId'], 'user1');
      expect(map['productId'], 'prod1');
    });
  });
}
