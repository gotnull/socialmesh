import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/device_shop/models/shop_models.dart';

void main() {
  group('DeviceCategory', () {
    test('has all expected values', () {
      expect(DeviceCategory.values.length, 7);
      expect(DeviceCategory.values, contains(DeviceCategory.node));
      expect(DeviceCategory.values, contains(DeviceCategory.module));
      expect(DeviceCategory.values, contains(DeviceCategory.antenna));
      expect(DeviceCategory.values, contains(DeviceCategory.enclosure));
      expect(DeviceCategory.values, contains(DeviceCategory.accessory));
      expect(DeviceCategory.values, contains(DeviceCategory.kit));
      expect(DeviceCategory.values, contains(DeviceCategory.solar));
    });

    test('has correct labels', () {
      expect(DeviceCategory.node.label, 'Nodes');
      expect(DeviceCategory.module.label, 'Modules');
      expect(DeviceCategory.antenna.label, 'Antennas');
      expect(DeviceCategory.enclosure.label, 'Enclosures');
      expect(DeviceCategory.accessory.label, 'Accessories');
      expect(DeviceCategory.kit.label, 'Kits');
      expect(DeviceCategory.solar.label, 'Solar');
    });

    test('has correct descriptions', () {
      expect(DeviceCategory.node.description, 'Complete Meshtastic devices');
      expect(DeviceCategory.module.description, 'Add-on modules and boards');
      expect(DeviceCategory.antenna.description, 'Antennas and RF accessories');
      expect(
        DeviceCategory.accessory.description,
        'Cables, batteries, and more',
      );
    });

    test('fromString returns correct category', () {
      expect(DeviceCategory.fromString('node'), DeviceCategory.node);
      expect(DeviceCategory.fromString('module'), DeviceCategory.module);
      expect(DeviceCategory.fromString('antenna'), DeviceCategory.antenna);
      expect(DeviceCategory.fromString('solar'), DeviceCategory.solar);
    });

    test('fromString returns node for unknown value', () {
      expect(DeviceCategory.fromString('unknown'), DeviceCategory.node);
      expect(DeviceCategory.fromString(''), DeviceCategory.node);
      expect(DeviceCategory.fromString('invalid'), DeviceCategory.node);
    });
  });

  group('FrequencyBand', () {
    test('has all expected values', () {
      expect(FrequencyBand.values.length, 8);
      expect(FrequencyBand.values, contains(FrequencyBand.us915));
      expect(FrequencyBand.values, contains(FrequencyBand.eu868));
      expect(FrequencyBand.values, contains(FrequencyBand.cn470));
      expect(FrequencyBand.values, contains(FrequencyBand.jp920));
      expect(FrequencyBand.values, contains(FrequencyBand.kr920));
      expect(FrequencyBand.values, contains(FrequencyBand.au915));
      expect(FrequencyBand.values, contains(FrequencyBand.in865));
      expect(FrequencyBand.values, contains(FrequencyBand.multiband));
    });

    test('has correct labels', () {
      expect(FrequencyBand.us915.label, 'US 915MHz');
      expect(FrequencyBand.eu868.label, 'EU 868MHz');
      expect(FrequencyBand.cn470.label, 'CN 470MHz');
      expect(FrequencyBand.multiband.label, 'Multi-band');
    });

    test('has correct ranges', () {
      expect(FrequencyBand.us915.range, '902-928 MHz');
      expect(FrequencyBand.eu868.range, '863-870 MHz');
      expect(FrequencyBand.cn470.range, '470-510 MHz');
      expect(FrequencyBand.multiband.range, 'Multiple frequencies');
    });

    test('fromString returns correct band', () {
      expect(FrequencyBand.fromString('us915'), FrequencyBand.us915);
      expect(FrequencyBand.fromString('eu868'), FrequencyBand.eu868);
      expect(FrequencyBand.fromString('multiband'), FrequencyBand.multiband);
    });

    test('fromString returns us915 for unknown value', () {
      expect(FrequencyBand.fromString('unknown'), FrequencyBand.us915);
      expect(FrequencyBand.fromString(''), FrequencyBand.us915);
    });
  });

  group('ShopSeller', () {
    test('creates with required fields', () {
      final seller = ShopSeller(
        id: 'seller123',
        name: 'Test Seller',
        joinedAt: DateTime(2024, 1, 1),
      );

      expect(seller.id, 'seller123');
      expect(seller.name, 'Test Seller');
      expect(seller.description, isNull);
      expect(seller.isVerified, false);
      expect(seller.isOfficialPartner, false);
      expect(seller.rating, 0);
      expect(seller.reviewCount, 0);
      expect(seller.productCount, 0);
      expect(seller.salesCount, 0);
      expect(seller.countries, isEmpty);
      expect(seller.isActive, true);
    });

    test('creates with all fields', () {
      final seller = ShopSeller(
        id: 'seller456',
        name: 'Premium Seller',
        description: 'High quality products',
        logoUrl: 'https://example.com/logo.png',
        websiteUrl: 'https://example.com',
        contactEmail: 'contact@example.com',
        isVerified: true,
        isOfficialPartner: true,
        rating: 4.8,
        reviewCount: 150,
        productCount: 25,
        salesCount: 500,
        joinedAt: DateTime(2023, 6, 15),
        countries: ['US', 'CA', 'UK'],
        stripeAccountId: 'acct_123',
        isActive: true,
      );

      expect(seller.id, 'seller456');
      expect(seller.name, 'Premium Seller');
      expect(seller.description, 'High quality products');
      expect(seller.logoUrl, 'https://example.com/logo.png');
      expect(seller.websiteUrl, 'https://example.com');
      expect(seller.contactEmail, 'contact@example.com');
      expect(seller.isVerified, true);
      expect(seller.isOfficialPartner, true);
      expect(seller.rating, 4.8);
      expect(seller.reviewCount, 150);
      expect(seller.productCount, 25);
      expect(seller.salesCount, 500);
      expect(seller.countries, ['US', 'CA', 'UK']);
      expect(seller.stripeAccountId, 'acct_123');
    });

    test('officialPartners contains known partners', () {
      // Currently only LilyGO is an official partner
      expect(ShopSeller.officialPartners, contains('LilyGO'));
      expect(ShopSeller.officialPartners.length, 1);
    });

    test('toFirestore returns correct map', () {
      final seller = ShopSeller(
        id: 'seller123',
        name: 'Test Seller',
        description: 'Test description',
        isVerified: true,
        rating: 4.5,
        reviewCount: 100,
        joinedAt: DateTime(2024, 1, 1),
        countries: ['US', 'UK'],
      );

      final map = seller.toFirestore();

      expect(map['name'], 'Test Seller');
      expect(map['description'], 'Test description');
      expect(map['isVerified'], true);
      expect(map['rating'], 4.5);
      expect(map['reviewCount'], 100);
      expect(map['countries'], ['US', 'UK']);
      expect(map['isActive'], true);
    });
  });

  group('ShopProduct', () {
    late ShopProduct basicProduct;
    late ShopProduct saleProduct;

    setUp(() {
      basicProduct = ShopProduct(
        id: 'prod123',
        sellerId: 'seller123',
        sellerName: 'Test Seller',
        name: 'T-Beam Supreme',
        description: 'A powerful Meshtastic device',
        category: DeviceCategory.node,
        price: 49.99,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 15),
      );

      saleProduct = ShopProduct(
        id: 'prod456',
        sellerId: 'seller456',
        sellerName: 'Sale Seller',
        name: 'Discounted Node',
        description: 'On sale!',
        category: DeviceCategory.node,
        price: 39.99,
        compareAtPrice: 59.99,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 15),
      );
    });

    test('creates with required fields', () {
      expect(basicProduct.id, 'prod123');
      expect(basicProduct.sellerId, 'seller123');
      expect(basicProduct.sellerName, 'Test Seller');
      expect(basicProduct.name, 'T-Beam Supreme');
      expect(basicProduct.description, 'A powerful Meshtastic device');
      expect(basicProduct.category, DeviceCategory.node);
      expect(basicProduct.price, 49.99);
      expect(basicProduct.currency, 'USD');
      expect(basicProduct.isInStock, true);
      expect(basicProduct.isActive, true);
      expect(basicProduct.isFeatured, false);
      expect(basicProduct.isMeshtasticCompatible, true);
    });

    test('creates with technical specs', () {
      final product = ShopProduct(
        id: 'prod789',
        sellerId: 'seller123',
        sellerName: 'Tech Seller',
        name: 'Advanced Node',
        description: 'Full featured node',
        category: DeviceCategory.node,
        price: 79.99,
        frequencyBands: [FrequencyBand.us915, FrequencyBand.eu868],
        chipset: 'ESP32-S3',
        loraChip: 'SX1262',
        hasGps: true,
        hasDisplay: true,
        hasBluetooth: true,
        hasWifi: true,
        batteryCapacity: '3000mAh',
        dimensions: '100x50x20mm',
        weight: '150g',
        includedAccessories: ['USB Cable', 'Antenna', 'Manual'],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 15),
      );

      expect(product.frequencyBands.length, 2);
      expect(product.frequencyBands, contains(FrequencyBand.us915));
      expect(product.frequencyBands, contains(FrequencyBand.eu868));
      expect(product.chipset, 'ESP32-S3');
      expect(product.loraChip, 'SX1262');
      expect(product.hasGps, true);
      expect(product.hasDisplay, true);
      expect(product.hasBluetooth, true);
      expect(product.hasWifi, true);
      expect(product.batteryCapacity, '3000mAh');
      expect(product.dimensions, '100x50x20mm');
      expect(product.weight, '150g');
      expect(product.includedAccessories.length, 3);
    });

    test('isOnSale returns true when compareAtPrice is set and higher', () {
      expect(basicProduct.isOnSale, false);
      expect(saleProduct.isOnSale, true);
    });

    test('discountPercent calculates correctly', () {
      expect(basicProduct.discountPercent, 0);
      // (59.99 - 39.99) / 59.99 * 100 = 33.34%
      expect(saleProduct.discountPercent, 33);
    });

    test('primaryImage returns first image or null', () {
      expect(basicProduct.primaryImage, isNull);

      final productWithImages = ShopProduct(
        id: 'prod_img',
        sellerId: 'seller123',
        sellerName: 'Seller',
        name: 'Product',
        description: 'Description',
        category: DeviceCategory.node,
        price: 29.99,
        imageUrls: [
          'https://example.com/img1.jpg',
          'https://example.com/img2.jpg',
        ],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 15),
      );

      expect(productWithImages.primaryImage, 'https://example.com/img1.jpg');
    });

    test('formattedPrice formats correctly', () {
      expect(basicProduct.formattedPrice, '\$49.99');
      expect(saleProduct.formattedPrice, '\$39.99');
    });

    test('formattedComparePrice formats correctly', () {
      expect(basicProduct.formattedComparePrice, isNull);
      expect(saleProduct.formattedComparePrice, '\$59.99');
    });

    test('toFirestore returns correct map', () {
      final map = basicProduct.toFirestore();

      expect(map['sellerId'], 'seller123');
      expect(map['sellerName'], 'Test Seller');
      expect(map['name'], 'T-Beam Supreme');
      expect(map['description'], 'A powerful Meshtastic device');
      expect(map['category'], 'node');
      expect(map['price'], 49.99);
      expect(map['currency'], 'USD');
      expect(map['isInStock'], true);
      expect(map['isActive'], true);
      expect(map['isMeshtasticCompatible'], true);
    });

    test('copyWith creates modified copy', () {
      final modified = basicProduct.copyWith(
        name: 'Updated Name',
        price: 59.99,
        isFeatured: true,
      );

      expect(modified.id, basicProduct.id);
      expect(modified.sellerId, basicProduct.sellerId);
      expect(modified.name, 'Updated Name');
      expect(modified.price, 59.99);
      expect(modified.isFeatured, true);
      expect(modified.description, basicProduct.description);
    });

    test('copyWith preserves original when no changes', () {
      final copy = basicProduct.copyWith();

      expect(copy.id, basicProduct.id);
      expect(copy.name, basicProduct.name);
      expect(copy.price, basicProduct.price);
      expect(copy.sellerId, basicProduct.sellerId);
    });
  });

  group('ProductReview', () {
    test('creates with required fields', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'prod123',
        userId: 'user123',
        rating: 5,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(review.id, 'review123');
      expect(review.productId, 'prod123');
      expect(review.userId, 'user123');
      expect(review.rating, 5);
      expect(review.userName, isNull);
      expect(review.title, isNull);
      expect(review.body, isNull);
      expect(review.imageUrls, isEmpty);
      expect(review.isVerifiedPurchase, false);
      expect(review.helpfulCount, 0);
      expect(review.sellerResponse, isNull);
    });

    test('creates with all fields', () {
      final review = ProductReview(
        id: 'review456',
        productId: 'prod456',
        userId: 'user456',
        userName: 'John Doe',
        userPhotoUrl: 'https://example.com/avatar.jpg',
        rating: 4,
        title: 'Great product!',
        body: 'Really enjoyed using this device.',
        imageUrls: ['https://example.com/review1.jpg'],
        isVerifiedPurchase: true,
        helpfulCount: 15,
        createdAt: DateTime(2024, 1, 1),
        sellerResponse: 'Thank you for your review!',
        sellerResponseAt: DateTime(2024, 1, 2),
      );

      expect(review.userName, 'John Doe');
      expect(review.userPhotoUrl, 'https://example.com/avatar.jpg');
      expect(review.rating, 4);
      expect(review.title, 'Great product!');
      expect(review.body, 'Really enjoyed using this device.');
      expect(review.imageUrls.length, 1);
      expect(review.isVerifiedPurchase, true);
      expect(review.helpfulCount, 15);
      expect(review.sellerResponse, 'Thank you for your review!');
      expect(review.sellerResponseAt, DateTime(2024, 1, 2));
    });

    test('toFirestore returns correct map', () {
      final review = ProductReview(
        id: 'review123',
        productId: 'prod123',
        userId: 'user123',
        userName: 'John',
        rating: 5,
        title: 'Excellent',
        body: 'Works perfectly',
        isVerifiedPurchase: true,
        createdAt: DateTime(2024, 1, 1),
      );

      final map = review.toFirestore();

      expect(map['productId'], 'prod123');
      expect(map['userId'], 'user123');
      expect(map['userName'], 'John');
      expect(map['rating'], 5);
      expect(map['title'], 'Excellent');
      expect(map['body'], 'Works perfectly');
      expect(map['isVerifiedPurchase'], true);
    });
  });

  group('ProductFavorite', () {
    test('creates with required fields', () {
      final favorite = ProductFavorite(
        id: 'fav123',
        oderId: 'user123',
        productId: 'prod123',
        addedAt: DateTime(2024, 1, 1),
      );

      expect(favorite.id, 'fav123');
      expect(favorite.oderId, 'user123');
      expect(favorite.productId, 'prod123');
      expect(favorite.addedAt, DateTime(2024, 1, 1));
    });

    test('toFirestore returns correct map', () {
      final favorite = ProductFavorite(
        id: 'fav123',
        oderId: 'user123',
        productId: 'prod123',
        addedAt: DateTime(2024, 1, 1),
      );

      final map = favorite.toFirestore();

      expect(map['userId'], 'user123');
      expect(map['productId'], 'prod123');
    });
  });
}
