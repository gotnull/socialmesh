// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/features/device_shop/models/shop_models.dart';
import 'package:socialmesh/features/device_shop/providers/device_shop_providers.dart';
import 'package:socialmesh/features/device_shop/services/device_shop_event_logger.dart';
import 'package:socialmesh/features/device_shop/screens/device_shop_screen.dart';

void main() {
  group('Device Shop LILYGO-only Tests', () {
    late List<DeviceShopEvent> capturedEvents;
    late DeviceShopEventLogger fakeLogger;

    setUp(() {
      capturedEvents = [];
      fakeLogger = FakeDeviceShopEventLogger(capturedEvents);
    });

    testWidgets('Only LilyGO appears in Official Partners section', (
      WidgetTester tester,
    ) async {
      // Use larger screen size to avoid overflow
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockSellers = [
        ShopSeller(
          id: 'lilygo',
          name: 'LilyGO',
          isOfficialPartner: true,
          isActive: true,
          joinedAt: DateTime(2024, 1, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            officialPartnersProvider.overrideWith((ref) {
              return Stream.value(mockSellers);
            }),
            deviceShopEventLoggerProvider.overrideWithValue(fakeLogger),
          ],
          child: MaterialApp(home: DeviceShopScreen()),
        ),
      );

      // Pump past AutoScrollText timer (1 second) to avoid pending timer issues
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Look for "Official Partners" section header
      expect(find.text('Official Partners'), findsOneWidget);

      // Should only find LilyGO
      expect(find.text('LilyGO'), findsWidgets);

      // Should not find other sellers
      expect(find.text('RAK Wireless'), findsNothing);
      expect(find.text('Rokland'), findsNothing);
      expect(find.text('SenseCAP'), findsNothing);
      expect(find.text('Heltec'), findsNothing);
    });

    testWidgets('Marketplace disclaimer appears on main shop screen', (
      WidgetTester tester,
    ) async {
      // Use larger screen size to avoid overflow
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shopProductsProvider.overrideWith((ref) => Stream.value([])),
            featuredProductsProvider.overrideWith((ref) => Stream.value([])),
            officialPartnersProvider.overrideWith((ref) => Stream.value([])),
            deviceShopEventLoggerProvider.overrideWithValue(fakeLogger),
          ],
          child: MaterialApp(home: DeviceShopScreen()),
        ),
      );

      // Pump past AutoScrollText timer (1 second) to avoid pending timer issues
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Check for marketplace information
      expect(find.text('Marketplace Information'), findsOneWidget);

      // Check for disclaimer text (combined in one text widget)
      expect(
        find.textContaining(
          'Purchases are completed on the seller\'s official store',
        ),
        findsOneWidget,
      );
    });

    test('Event logger correctly captures buy now events', () async {
      final testProduct = ShopProduct(
        id: 'test-product',
        sellerId: 'lilygo',
        sellerName: 'LilyGO',
        name: 'Test Device',
        description: 'Test description',
        category: DeviceCategory.node,
        price: 49.99,
        currency: 'USD',
        isInStock: true,
        isActive: true,
        isFeatured: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        purchaseUrl: 'https://lilygo.cc/products/test',
      );

      // Call the logger directly
      await fakeLogger.logBuyNowTap(
        sellerId: testProduct.sellerId,
        sellerName: testProduct.sellerName,
        productId: testProduct.id,
        productName: testProduct.name,
        category: testProduct.category.name,
        price: testProduct.price,
        currency: testProduct.currency,
        destinationUrl: testProduct.purchaseUrl ?? 'no-url',
        screen: 'detail',
      );

      // Verify the event was logged
      expect(capturedEvents.length, 1);
      expect(capturedEvents.first.event, 'device_shop_buy_now_tap');
      expect(capturedEvents.first.payload['product_id'], 'test-product');
      expect(capturedEvents.first.payload['seller_id'], 'lilygo');
      expect(capturedEvents.first.payload['seller_name'], 'LilyGO');
      expect(capturedEvents.first.payload['price'], 49.99);
      expect(
        capturedEvents.first.payload['destination_url'],
        'https://lilygo.cc/products/test',
      );
    });
  });
}

/// Fake event logger for testing
class FakeDeviceShopEventLogger implements DeviceShopEventLogger {
  final List<DeviceShopEvent> events;

  FakeDeviceShopEventLogger(this.events);

  @override
  Future<void> logBuyNowTap({
    required String sellerId,
    required String sellerName,
    required String productId,
    required String productName,
    required String category,
    required double price,
    required String currency,
    required String destinationUrl,
    required String screen,
  }) async {
    events.add(
      DeviceShopEvent(
        event: 'device_shop_buy_now_tap',
        timestamp: DateTime.now(),
        payload: {
          'seller_id': sellerId,
          'seller_name': sellerName,
          'product_id': productId,
          'product_name': productName,
          'category': category,
          'price': price,
          'currency': currency,
          'destination_url': destinationUrl,
          'screen': screen,
        },
      ),
    );
  }

  @override
  Future<void> logPartnerContactTap({
    required String sellerId,
    required String sellerName,
    required String actionType,
    String? destinationUrl,
  }) async {
    events.add(
      DeviceShopEvent(
        event: 'device_shop_partner_contact_tap',
        timestamp: DateTime.now(),
        payload: {
          'seller_id': sellerId,
          'seller_name': sellerName,
          'action_type': actionType,
          if (destinationUrl != null) 'destination_url': destinationUrl,
        },
      ),
    );
  }

  @override
  Future<void> logDiscountReveal({
    required String sellerId,
    required String sellerName,
    required String code,
  }) async {
    events.add(
      DeviceShopEvent(
        event: 'device_shop_discount_reveal',
        timestamp: DateTime.now(),
        payload: {
          'seller_id': sellerId,
          'seller_name': sellerName,
          'code': code,
        },
      ),
    );
  }

  @override
  Future<void> logDiscountCopy({
    required String sellerId,
    required String sellerName,
    required String code,
  }) async {
    events.add(
      DeviceShopEvent(
        event: 'device_shop_discount_copy',
        timestamp: DateTime.now(),
        payload: {
          'seller_id': sellerId,
          'seller_name': sellerName,
          'code': code,
        },
      ),
    );
  }

  @override
  Future<List<DeviceShopEvent>> getEvents() async => events;

  @override
  Future<void> clearEvents() async => events.clear();
}
