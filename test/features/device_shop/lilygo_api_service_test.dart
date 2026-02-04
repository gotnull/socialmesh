// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:socialmesh/features/device_shop/services/lilygo_api_service.dart';
import 'package:socialmesh/features/device_shop/models/lilygo_models.dart';
import 'package:socialmesh/features/device_shop/models/shop_models.dart';

void main() {
  group('LilygoApiService', () {
    test('parses product JSON correctly', () {
      final json = {
        'id': 12345,
        'title': 'T-Beam Meshtastic',
        'handle': 't-beam-meshtastic',
        'body_html': '<p>ESP32 LoRa GPS device with Meshtastic firmware</p>',
        'vendor': 'LILYGO®',
        'product_type': 'Development Board',
        'tags': ['Meshtastic', 'LoRa or GPS Series'],
        'variants': [
          {
            'id': 111,
            'product_id': 12345,
            'title': '915MHz / Soldered OLED',
            'price': '33.02',
            'compare_at_price': null,
            'sku': 'Q407-Mesh',
            'position': 1,
            'option1': 'China [For Worldwide]',
            'option2': 'Meshtastic Firmware',
            'option3': '915Mhz Soldered OLED',
            'available': true,
            'grams': 150,
            'requires_shipping': true,
            'taxable': false,
            'created_at': '2025-05-05T15:21:59+08:00',
            'updated_at': '2026-02-04T13:25:38+08:00',
          },
          {
            'id': 112,
            'product_id': 12345,
            'title': '868MHz / Soldered OLED',
            'price': '33.32',
            'compare_at_price': null,
            'sku': 'Q410-Mesh',
            'position': 2,
            'option1': 'China [For Worldwide]',
            'option2': 'Meshtastic Firmware',
            'option3': '868Mhz Soldered OLED',
            'available': true,
            'grams': 150,
            'requires_shipping': true,
            'taxable': false,
            'created_at': '2025-05-05T15:21:59+08:00',
            'updated_at': '2026-02-04T13:25:38+08:00',
          },
        ],
        'images': [
          {
            'id': 222,
            'product_id': 12345,
            'position': 1,
            'src':
                'https://cdn.shopify.com/s/files/1/0617/7190/7253/files/LILYGO-T-BEAM_1.jpg',
            'width': 1000,
            'height': 1000,
            'alt': null,
            'variant_ids': [],
            'created_at': '2024-05-22T11:38:16+08:00',
            'updated_at': '2024-05-22T11:51:08+08:00',
          },
        ],
        'options': [
          {
            'name': 'Warehouse',
            'position': 1,
            'values': ['China [For Worldwide]', 'Germany [ For Europe only]'],
          },
          {
            'name': 'Firmware',
            'position': 2,
            'values': ['Meshtastic Firmware'],
          },
          {
            'name': 'Frequency',
            'position': 3,
            'values': ['915Mhz Soldered OLED', '868Mhz Soldered OLED'],
          },
        ],
        'created_at': '2025-05-05T15:21:58+08:00',
        'updated_at': '2026-02-04T13:25:38+08:00',
        'published_at': '2025-05-05T15:22:45+08:00',
      };

      final product = LilygoProduct.fromJson(json);

      expect(product.id, 12345);
      expect(product.title, 'T-Beam Meshtastic');
      expect(product.handle, 't-beam-meshtastic');
      expect(product.vendor, 'LILYGO®');
      expect(product.tags, contains('Meshtastic'));
      expect(product.variants.length, 2);
      expect(product.variants.first.priceValue, 33.02);
      expect(product.variants.first.available, true);
      expect(product.images.length, 1);
      expect(product.options.length, 3);
      expect(product.isAvailable, true);
    });

    test('variant parses price correctly', () {
      final json = {
        'id': 111,
        'product_id': 12345,
        'title': '915MHz',
        'price': '49.99',
        'compare_at_price': '59.99',
        'position': 1,
        'available': true,
        'grams': 100,
        'requires_shipping': true,
        'taxable': false,
        'created_at': '2025-01-01T00:00:00Z',
        'updated_at': '2025-01-01T00:00:00Z',
      };

      final variant = LilygoVariant.fromJson(json);

      expect(variant.priceValue, 49.99);
      expect(variant.compareAtPriceValue, 59.99);
      expect(variant.isOnSale, true);
      expect(variant.discountPercent, 17);
    });

    test('filters Meshtastic products by tags', () async {
      final mockResponse = {
        'products': [
          {
            'id': 1,
            'title': 'T-Beam Meshtastic',
            'handle': 't-beam-meshtastic',
            'body_html': '',
            'vendor': 'LILYGO',
            'product_type': '',
            'tags': ['Meshtastic'],
            'variants': [
              {
                'id': 10,
                'product_id': 1,
                'title': 'Default',
                'price': '30.00',
                'position': 1,
                'available': true,
                'grams': 100,
                'requires_shipping': true,
                'taxable': false,
                'created_at': '2025-01-01T00:00:00Z',
                'updated_at': '2025-01-01T00:00:00Z',
              },
            ],
            'images': [],
            'options': [],
            'created_at': '2025-01-01T00:00:00Z',
            'updated_at': '2025-01-01T00:00:00Z',
          },
          {
            'id': 2,
            'title': 'T-Display S3',
            'handle': 't-display-s3',
            'body_html': '',
            'vendor': 'LILYGO',
            'product_type': '',
            'tags': ['LCD / OLED'],
            'variants': [
              {
                'id': 20,
                'product_id': 2,
                'title': 'Default',
                'price': '15.00',
                'position': 1,
                'available': true,
                'grams': 50,
                'requires_shipping': true,
                'taxable': false,
                'created_at': '2025-01-01T00:00:00Z',
                'updated_at': '2025-01-01T00:00:00Z',
              },
            ],
            'images': [],
            'options': [],
            'created_at': '2025-01-01T00:00:00Z',
            'updated_at': '2025-01-01T00:00:00Z',
          },
          {
            'id': 3,
            'title': 'T-Echo Plus',
            'handle': 't-echo-plus',
            'body_html': 'LoRa GPS with Meshtastic support',
            'vendor': 'LILYGO',
            'product_type': '',
            'tags': ['LoRa or GPS Series'],
            'variants': [
              {
                'id': 30,
                'product_id': 3,
                'title': 'Default',
                'price': '45.00',
                'position': 1,
                'available': true,
                'grams': 80,
                'requires_shipping': true,
                'taxable': false,
                'created_at': '2025-01-01T00:00:00Z',
                'updated_at': '2025-01-01T00:00:00Z',
              },
            ],
            'images': [],
            'options': [],
            'created_at': '2025-01-01T00:00:00Z',
            'updated_at': '2025-01-01T00:00:00Z',
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final service = LilygoApiService(client: mockClient);
      final products = await service.fetchMeshtasticProducts();

      // Should get T-Beam (Meshtastic tag) and T-Echo Plus (known handle)
      expect(products.length, 2);
      expect(products.map((p) => p.name), contains('T-Beam Meshtastic'));
      expect(products.map((p) => p.name), contains('T-Echo Plus'));
      // T-Display S3 should be filtered out
      expect(products.map((p) => p.name), isNot(contains('T-Display S3')));
    });

    test('converts to ShopProduct correctly', () async {
      final mockResponse = {
        'products': [
          {
            'id': 12345,
            'title': 'T-Deck Meshtastic',
            'handle': 't-deck-meshtastic',
            'body_html':
                '<p>ESP32-S3 with SX1262 LoRa, 2.8" display, Bluetooth and WiFi</p>',
            'vendor': 'LILYGO®',
            'product_type': 'Development Board',
            'tags': ['Meshtastic'],
            'variants': [
              {
                'id': 100,
                'product_id': 12345,
                'title': '915MHz / White',
                'price': '52.66',
                'compare_at_price': null,
                'sku': 'H667-Mesh',
                'position': 1,
                'option1': 'Meshtastic Firmware',
                'option2': '915MHz',
                'option3': 'White',
                'available': true,
                'grams': 150,
                'requires_shipping': true,
                'taxable': false,
                'created_at': '2025-05-05T15:17:16+08:00',
                'updated_at': '2026-02-04T13:25:38+08:00',
              },
              {
                'id': 101,
                'product_id': 12345,
                'title': '868MHz / Black',
                'price': '52.66',
                'compare_at_price': null,
                'sku': 'H623-A-Mesh',
                'position': 2,
                'option1': 'Meshtastic Firmware',
                'option2': '868MHz',
                'option3': 'Black',
                'available': true,
                'grams': 150,
                'requires_shipping': true,
                'taxable': false,
                'created_at': '2025-05-05T15:17:16+08:00',
                'updated_at': '2026-02-04T13:25:38+08:00',
              },
            ],
            'images': [
              {
                'id': 200,
                'product_id': 12345,
                'position': 1,
                'src':
                    'https://cdn.shopify.com/s/files/1/0617/7190/7253/files/T-DECK_1.jpg',
                'width': 1000,
                'height': 1000,
                'alt': null,
                'variant_ids': [],
                'created_at': '2024-01-01T00:00:00Z',
                'updated_at': '2024-01-01T00:00:00Z',
              },
            ],
            'options': [
              {
                'name': 'Firmware',
                'position': 1,
                'values': ['Meshtastic Firmware'],
              },
              {
                'name': 'Version',
                'position': 2,
                'values': ['915MHz', '868MHz'],
              },
              {
                'name': 'Color',
                'position': 3,
                'values': ['White', 'Black'],
              },
            ],
            'created_at': '2025-05-05T15:17:16+08:00',
            'updated_at': '2026-02-04T13:25:38+08:00',
            'published_at': '2025-05-05T15:18:24+08:00',
          },
        ],
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200);
      });

      final service = LilygoApiService(client: mockClient);
      final products = await service.fetchMeshtasticProducts();

      expect(products.length, 1);

      final product = products.first;
      expect(product.id, 'lilygo_12345');
      expect(product.sellerId, 'lilygo');
      expect(product.sellerName, 'LILYGO');
      expect(product.name, 'T-Deck Meshtastic');
      expect(product.price, 52.66);
      expect(product.isInStock, true);
      expect(product.isMeshtasticCompatible, true);
      expect(
        product.purchaseUrl,
        'https://lilygo.cc/products/t-deck-meshtastic',
      );
      expect(product.imageUrls.length, 1);
      expect(product.category, DeviceCategory.node);

      // Check frequency bands extracted from variants
      expect(product.frequencyBands, contains(FrequencyBand.us915));
      expect(product.frequencyBands, contains(FrequencyBand.eu868));

      // Check specs parsed from body HTML
      expect(product.chipset, 'ESP32-S3');
      expect(product.loraChip, 'SX1262');
      expect(product.hasDisplay, true);
      expect(product.hasBluetooth, true);
      expect(product.hasWifi, true);
    });

    test('handles empty response gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'products': []}), 200);
      });

      final service = LilygoApiService(client: mockClient);
      final products = await service.fetchMeshtasticProducts();

      expect(products, isEmpty);
    });

    test('throws on HTTP error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = LilygoApiService(client: mockClient);

      expect(() => service.fetchMeshtasticProducts(), throwsException);
    });
  });

  group('LilygoProduct', () {
    test('priceRange formats correctly for single price', () {
      final product = LilygoProduct(
        id: 1,
        title: 'Test',
        handle: 'test',
        bodyHtml: '',
        vendor: 'LILYGO',
        productType: '',
        tags: [],
        variants: [
          LilygoVariant(
            id: 1,
            productId: 1,
            title: 'Default',
            price: '49.99',
            position: 1,
            available: true,
            grams: 100,
            requiresShipping: true,
            taxable: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        images: [],
        options: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.priceRange, '\$49.99');
    });

    test('priceRange formats correctly for price range', () {
      final product = LilygoProduct(
        id: 1,
        title: 'Test',
        handle: 'test',
        bodyHtml: '',
        vendor: 'LILYGO',
        productType: '',
        tags: [],
        variants: [
          LilygoVariant(
            id: 1,
            productId: 1,
            title: '915MHz',
            price: '30.00',
            position: 1,
            available: true,
            grams: 100,
            requiresShipping: true,
            taxable: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          LilygoVariant(
            id: 2,
            productId: 1,
            title: '868MHz BME280',
            price: '45.00',
            position: 2,
            available: true,
            grams: 100,
            requiresShipping: true,
            taxable: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        images: [],
        options: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(product.priceRange, '\$30.00 - \$45.00');
    });
  });
}
