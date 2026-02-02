// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/device_shop/services/device_shop_event_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceShopEventLogger', () {
    late LocalDeviceShopEventLogger logger;

    setUp(() async {
      // Set up SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      logger = LocalDeviceShopEventLogger();
    });

    tearDown(() async {
      await logger.clearEvents();
    });

    test('logBuyNowTap creates event with all required fields', () async {
      await logger.logBuyNowTap(
        sellerId: 'lilygo',
        sellerName: 'LilyGO',
        productId: 'tbeam-s3',
        productName: 'T-Beam S3 Core',
        category: 'node',
        price: 49.99,
        currency: 'USD',
        destinationUrl: 'https://lilygo.cc/products/t-beam-s3',
        screen: 'detail',
      );

      final events = await logger.getEvents();
      expect(events.length, 1);

      final event = events.first;
      expect(event.event, 'device_shop_buy_now_tap');
      expect(event.payload['seller_id'], 'lilygo');
      expect(event.payload['seller_name'], 'LilyGO');
      expect(event.payload['product_id'], 'tbeam-s3');
      expect(event.payload['product_name'], 'T-Beam S3 Core');
      expect(event.payload['category'], 'node');
      expect(event.payload['price'], 49.99);
      expect(event.payload['currency'], 'USD');
      expect(
        event.payload['destination_url'],
        'https://lilygo.cc/products/t-beam-s3',
      );
      expect(event.payload['screen'], 'detail');
    });

    test(
      'logPartnerContactTap creates event with seller and action details',
      () async {
        await logger.logPartnerContactTap(
          sellerId: 'lilygo',
          sellerName: 'LilyGO',
          actionType: 'website',
          destinationUrl: 'https://lilygo.cc',
        );

        final events = await logger.getEvents();
        expect(events.length, 1);

        final event = events.first;
        expect(event.event, 'device_shop_partner_contact_tap');
        expect(event.payload['seller_id'], 'lilygo');
        expect(event.payload['seller_name'], 'LilyGO');
        expect(event.payload['action_type'], 'website');
        expect(event.payload['destination_url'], 'https://lilygo.cc');
      },
    );

    test('logDiscountReveal creates event with code', () async {
      await logger.logDiscountReveal(
        sellerId: 'lilygo',
        sellerName: 'LilyGO',
        code: 'SOCIALMESH10',
      );

      final events = await logger.getEvents();
      expect(events.length, 1);

      final event = events.first;
      expect(event.event, 'device_shop_discount_reveal');
      expect(event.payload['code'], 'SOCIALMESH10');
    });

    test('logDiscountCopy creates event with code', () async {
      await logger.logDiscountCopy(
        sellerId: 'lilygo',
        sellerName: 'LilyGO',
        code: 'SOCIALMESH10',
      );

      final events = await logger.getEvents();
      expect(events.length, 1);

      final event = events.first;
      expect(event.event, 'device_shop_discount_copy');
      expect(event.payload['code'], 'SOCIALMESH10');
    });

    test('multiple events are stored in order', () async {
      await logger.logBuyNowTap(
        sellerId: 'lilygo',
        sellerName: 'LilyGO',
        productId: 'product1',
        productName: 'Product 1',
        category: 'node',
        price: 49.99,
        currency: 'USD',
        destinationUrl: 'https://example.com/1',
        screen: 'detail',
      );

      await logger.logPartnerContactTap(
        sellerId: 'lilygo',
        sellerName: 'LilyGO',
        actionType: 'email',
      );

      await logger.logDiscountReveal(
        sellerId: 'lilygo',
        sellerName: 'LilyGO',
        code: 'TEST123',
      );

      final events = await logger.getEvents();
      expect(events.length, 3);
      expect(events[0].event, 'device_shop_buy_now_tap');
      expect(events[1].event, 'device_shop_partner_contact_tap');
      expect(events[2].event, 'device_shop_discount_reveal');
    });

    test('clearEvents removes all events', () async {
      await logger.logBuyNowTap(
        sellerId: 'lilygo',
        sellerName: 'LilyGO',
        productId: 'product1',
        productName: 'Product 1',
        category: 'node',
        price: 49.99,
        currency: 'USD',
        destinationUrl: 'https://example.com/1',
        screen: 'detail',
      );

      var events = await logger.getEvents();
      expect(events.length, 1);

      await logger.clearEvents();

      events = await logger.getEvents();
      expect(events.length, 0);
    });
  });
}
