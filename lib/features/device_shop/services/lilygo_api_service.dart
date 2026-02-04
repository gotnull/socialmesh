// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:socialmesh/core/logging.dart';
import '../models/shop_models.dart';
import '../models/lilygo_models.dart';
import '../providers/device_shop_providers.dart' show lilygoSellerId;

/// Service for fetching products directly from LILYGO's Shopify API
///
/// LILYGO has granted permission to use their product information,
/// images, and descriptions in the Socialmesh Device Shop.
class LilygoApiService {
  static const String _tag = '[LilygoApi]';
  static const String _baseUrl = 'https://lilygo.cc';
  static const String _productsEndpoint = '/products.json';

  /// Meshtastic-related tags to filter products
  static const Set<String> _meshtasticTags = {
    'meshtastic',
    'mesh',
    'lora or gps series',
  };

  /// Product handles that are known Meshtastic devices
  static const Set<String> _knownMeshtasticHandles = {
    't-beam-meshtastic',
    't-echo-meshtastic',
    't-deck-meshtastic',
    't-deck-plus-meshtastic',
    't-lora-pager-meshtastic',
    't-lora-meshtastic',
    't-beam-supreme-meshtastic',
    't-echo-plus',
    't-echo-lite',
    't-deco-pro-meshtastic',
  };

  final http.Client _client;

  LilygoApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Fetch all Meshtastic-compatible products from LILYGO
  Future<List<ShopProduct>> fetchMeshtasticProducts() async {
    AppLogging.shop('$_tag fetchMeshtasticProducts() called');
    AppLogging.shop('$_tag Base URL: $_baseUrl');
    AppLogging.shop('$_tag Products endpoint: $_productsEndpoint');

    try {
      AppLogging.shop(
        '$_tag Starting to fetch all products from LILYGO API...',
      );
      final products = await _fetchAllProducts();
      AppLogging.shop(
        '$_tag Received ${products.length} total products from API',
      );

      AppLogging.shop('$_tag Filtering for Meshtastic-compatible products...');
      AppLogging.shop(
        '$_tag Known Meshtastic handles: $_knownMeshtasticHandles',
      );
      AppLogging.shop('$_tag Meshtastic tags to match: $_meshtasticTags');

      final meshtasticProducts = products.where(_isMeshtasticProduct).toList();
      AppLogging.shop(
        '$_tag Found ${meshtasticProducts.length} Meshtastic products '
        'out of ${products.length} total',
      );

      for (final p in meshtasticProducts) {
        AppLogging.shop(
          '$_tag   - ${p.title} (handle: ${p.handle}, tags: ${p.tags})',
        );
      }

      AppLogging.shop('$_tag Converting to ShopProduct models...');
      final shopProducts = meshtasticProducts.map(_toShopProduct).toList();

      for (final sp in shopProducts) {
        AppLogging.shop(
          '$_tag   Converted: ${sp.name} | \$${sp.price} | '
          'inStock: ${sp.isInStock} | images: ${sp.imageUrls.length} | '
          'featured: ${sp.isFeatured}',
        );
      }

      AppLogging.shop(
        '$_tag fetchMeshtasticProducts() complete - returning ${shopProducts.length} products',
      );
      return shopProducts;
    } catch (e, stack) {
      AppLogging.shop('$_tag ERROR fetching products: $e');
      AppLogging.shop('$_tag Stack trace: $stack');
      rethrow;
    }
  }

  /// Fetch a single product by handle
  Future<ShopProduct?> fetchProduct(String handle) async {
    AppLogging.shop('$_tag fetchProduct($handle) called');

    try {
      final uri = Uri.parse('$_baseUrl/products/$handle.json');
      AppLogging.shop('$_tag Fetching from: $uri');

      final response = await _client.get(uri);
      AppLogging.shop('$_tag Response status: ${response.statusCode}');
      AppLogging.shop(
        '$_tag Response body length: ${response.body.length} chars',
      );

      if (response.statusCode != 200) {
        AppLogging.shop(
          '$_tag FAILED to fetch product $handle: HTTP ${response.statusCode}',
        );
        AppLogging.shop(
          '$_tag Response body: ${response.body.substring(0, 200.clamp(0, response.body.length))}...',
        );
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      AppLogging.shop('$_tag JSON decoded successfully');

      final productJson = json['product'] as Map<String, dynamic>;
      AppLogging.shop('$_tag Product JSON keys: ${productJson.keys.toList()}');

      final product = LilygoProduct.fromJson(productJson);
      AppLogging.shop(
        '$_tag Parsed product: ${product.title} | '
        'variants: ${product.variants.length} | images: ${product.images.length}',
      );

      final shopProduct = _toShopProduct(product);
      AppLogging.shop(
        '$_tag Converted to ShopProduct: ${shopProduct.name} | \$${shopProduct.price}',
      );

      return shopProduct;
    } catch (e, stack) {
      AppLogging.shop('$_tag ERROR fetching product $handle: $e');
      AppLogging.shop('$_tag Stack trace: $stack');
      return null;
    }
  }

  /// Fetch all products from LILYGO (paginated)
  Future<List<LilygoProduct>> _fetchAllProducts() async {
    AppLogging.shop('$_tag _fetchAllProducts() starting...');
    final allProducts = <LilygoProduct>[];
    int page = 1;
    const limit = 250; // Shopify max

    while (true) {
      final uri = Uri.parse(
        '$_baseUrl$_productsEndpoint?limit=$limit&page=$page',
      );
      AppLogging.shop('$_tag Fetching page $page from: $uri');

      final response = await _client.get(uri);
      AppLogging.shop('$_tag Page $page response: HTTP ${response.statusCode}');
      AppLogging.shop(
        '$_tag Page $page body length: ${response.body.length} chars',
      );

      if (response.statusCode != 200) {
        AppLogging.shop('$_tag ERROR: HTTP ${response.statusCode}');
        AppLogging.shop(
          '$_tag Response: ${response.body.substring(0, 500.clamp(0, response.body.length))}',
        );
        throw Exception('Failed to fetch products: ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      AppLogging.shop('$_tag JSON keys on page $page: ${json.keys.toList()}');

      final productsJson = json['products'] as List<dynamic>;
      AppLogging.shop(
        '$_tag Page $page has ${productsJson.length} products in JSON',
      );

      if (productsJson.isEmpty) {
        AppLogging.shop('$_tag Page $page is empty, stopping pagination');
        break;
      }

      final products = productsJson
          .cast<Map<String, dynamic>>()
          .map(LilygoProduct.fromJson)
          .toList();

      AppLogging.shop(
        '$_tag Parsed ${products.length} products from page $page',
      );
      for (final p in products.take(5)) {
        AppLogging.shop('$_tag   Sample: ${p.title} (${p.handle})');
      }
      if (products.length > 5) {
        AppLogging.shop('$_tag   ... and ${products.length - 5} more');
      }

      allProducts.addAll(products);
      AppLogging.shop('$_tag Running total: ${allProducts.length} products');

      // If we got fewer than limit, we've reached the end
      if (products.length < limit) {
        AppLogging.shop(
          '$_tag Got ${products.length} < $limit products, reached end',
        );
        break;
      }

      page++;
    }

    AppLogging.shop(
      '$_tag _fetchAllProducts() complete: ${allProducts.length} total',
    );
    return allProducts;
  }

  /// Check if a product is Meshtastic-compatible
  bool _isMeshtasticProduct(LilygoProduct product) {
    final handle = product.handle.toLowerCase();
    final lowerTags = product.tags.map((t) => t.toLowerCase()).toSet();
    final lowerTitle = product.title.toLowerCase();

    // Check handle
    if (_knownMeshtasticHandles.contains(handle)) {
      AppLogging.shop('$_tag ✓ ${product.title} matched by handle: $handle');
      return true;
    }

    // Check tags
    if (lowerTags.any(_meshtasticTags.contains)) {
      final matchedTag = lowerTags.firstWhere(
        _meshtasticTags.contains,
        orElse: () => 'unknown',
      );
      AppLogging.shop('$_tag ✓ ${product.title} matched by tag: $matchedTag');
      return true;
    }

    // Check title
    if (lowerTitle.contains('meshtastic') || lowerTitle.contains('meshcore')) {
      AppLogging.shop('$_tag ✓ ${product.title} matched by title keyword');
      return true;
    }

    return false;
  }

  /// Convert LILYGO product to ShopProduct
  ShopProduct _toShopProduct(LilygoProduct product) {
    AppLogging.shop('$_tag Converting: ${product.title}');
    AppLogging.shop('$_tag   Handle: ${product.handle}');
    AppLogging.shop('$_tag   Variants: ${product.variants.length}');
    AppLogging.shop('$_tag   Images: ${product.images.length}');
    AppLogging.shop('$_tag   Tags: ${product.tags}');

    // Find variants - note: Shopify 'available' field only reflects the
    // DEFAULT warehouse inventory. LILYGO has multiple warehouses (China,
    // US, Germany) and the website allows selecting different ones.
    // A product is generally "in stock" if it's published on the store.
    final availableVariants = product.variants
        .where((v) => v.available)
        .toList();
    AppLogging.shop(
      '$_tag   Variants with available=true: ${availableVariants.length}',
    );
    AppLogging.shop(
      '$_tag   Note: available=false may just mean default warehouse is out, '
      'other warehouses may have stock',
    );

    final bestVariant = availableVariants.isNotEmpty
        ? availableVariants.reduce(
            (a, b) => a.priceValue < b.priceValue ? a : b,
          )
        : product.variants.isNotEmpty
        ? product.variants.first
        : null;
    AppLogging.shop(
      '$_tag   Best variant: ${bestVariant?.title ?? 'none'} @ \$${bestVariant?.priceValue ?? 0}',
    );

    // Calculate price range
    final prices = product.variants.map((v) => v.priceValue).toList();
    AppLogging.shop('$_tag   Variant prices: $prices');

    final minPrice = prices.isNotEmpty
        ? prices.reduce((a, b) => a < b ? a : b)
        : 0.0;
    final maxPrice = prices.isNotEmpty
        ? prices.reduce((a, b) => a > b ? a : b)
        : 0.0;
    AppLogging.shop(
      '$_tag   Price range: \$${minPrice.toStringAsFixed(2)} - \$${maxPrice.toStringAsFixed(2)}',
    );

    // Extract frequency bands from variants
    final frequencyBands = _extractFrequencyBands(product);
    AppLogging.shop('$_tag   Frequency bands: $frequencyBands');

    // Determine category
    final category = _determineCategory(product);
    AppLogging.shop('$_tag   Category: $category');

    // Parse specs from body HTML
    final specs = _parseSpecs(product.bodyHtml);
    AppLogging.shop('$_tag   Parsed specs: $specs');

    // Image URLs
    final imageUrls = product.images.map((i) => i.src).toList();
    AppLogging.shop('$_tag   Image URLs (${imageUrls.length}):');
    for (final url in imageUrls.take(3)) {
      AppLogging.shop('$_tag     - $url');
    }
    if (imageUrls.length > 3) {
      AppLogging.shop('$_tag     ... and ${imageUrls.length - 3} more');
    }

    final shopProduct = ShopProduct(
      id: 'lilygo_${product.id}',
      sellerId: lilygoSellerId,
      sellerName: 'LILYGO',
      name: product.title,
      description: _cleanHtml(product.bodyHtml),
      shortDescription: _extractShortDescription(product.bodyHtml),
      category: category,
      tags: product.tags,
      imageUrls: imageUrls,
      price: minPrice,
      currency: 'USD',
      compareAtPrice: bestVariant?.compareAtPriceValue,
      // Stock: Consider in-stock if published (multi-warehouse support)
      // The 'available' field only reflects default warehouse, but LILYGO
      // ships from China/US/Germany warehouses - check website for actual stock
      stockQuantity: product.variants.length,
      isInStock: product.publishedAt != null,
      isActive: true,
      isFeatured: _isFeaturedProduct(product),
      frequencyBands: frequencyBands,
      chipset: specs['chipset'],
      loraChip: specs['loraChip'],
      hasGps: specs['hasGps'] == 'true',
      hasDisplay: specs['hasDisplay'] == 'true',
      hasBluetooth: specs['hasBluetooth'] == 'true',
      hasWifi: specs['hasWifi'] == 'true',
      batteryCapacity: specs['batteryCapacity'],
      dimensions: specs['dimensions'],
      weight: '${product.variants.firstOrNull?.grams ?? 0}g',
      createdAt: product.createdAt,
      updatedAt: product.updatedAt,
      isMeshtasticCompatible: true,
      purchaseUrl: '$_baseUrl/products/${product.handle}',
      vendorVerified: true,
      // Store extra data for UI
      hardwareVersion: _formatPriceRange(minPrice, maxPrice),
    );

    AppLogging.shop('$_tag   Created ShopProduct:');
    AppLogging.shop('$_tag     id: ${shopProduct.id}');
    AppLogging.shop('$_tag     name: ${shopProduct.name}');
    AppLogging.shop('$_tag     price: \$${shopProduct.price}');
    AppLogging.shop('$_tag     inStock: ${shopProduct.isInStock}');
    AppLogging.shop('$_tag     isFeatured: ${shopProduct.isFeatured}');
    AppLogging.shop(
      '$_tag     imageUrls count: ${shopProduct.imageUrls.length}',
    );
    AppLogging.shop('$_tag     purchaseUrl: ${shopProduct.purchaseUrl}');

    return shopProduct;
  }

  /// Extract frequency bands from product variants
  List<FrequencyBand> _extractFrequencyBands(LilygoProduct product) {
    final bands = <FrequencyBand>{};

    for (final variant in product.variants) {
      final title = variant.title.toLowerCase();
      final option2 = (variant.option2 ?? '').toLowerCase();
      final option3 = (variant.option3 ?? '').toLowerCase();
      final combined = '$title $option2 $option3';

      if (combined.contains('915')) bands.add(FrequencyBand.us915);
      if (combined.contains('868')) bands.add(FrequencyBand.eu868);
      if (combined.contains('433')) bands.add(FrequencyBand.cn470);
      if (combined.contains('920') || combined.contains('923')) {
        bands.add(FrequencyBand.jp920);
      }
    }

    return bands.toList();
  }

  /// Determine product category from tags and title
  DeviceCategory _determineCategory(LilygoProduct product) {
    final lowerTitle = product.title.toLowerCase();
    final lowerTags = product.tags.map((t) => t.toLowerCase()).toSet();

    if (lowerTitle.contains('antenna')) return DeviceCategory.antenna;
    if (lowerTitle.contains('case') || lowerTitle.contains('enclosure')) {
      return DeviceCategory.enclosure;
    }
    if (lowerTitle.contains('accessory') ||
        lowerTitle.contains('accessories')) {
      return DeviceCategory.accessory;
    }
    if (lowerTitle.contains('kit')) return DeviceCategory.kit;
    if (lowerTitle.contains('solar') || lowerTitle.contains('battery')) {
      return DeviceCategory.solar;
    }
    if (lowerTags.contains('basic module')) return DeviceCategory.module;

    // Default to node for main devices
    return DeviceCategory.node;
  }

  /// Check if product should be featured
  bool _isFeaturedProduct(LilygoProduct product) {
    final featured = {
      't-beam-meshtastic',
      't-echo-meshtastic',
      't-deck-meshtastic',
      't-deck-plus-meshtastic',
      't-lora-pager-meshtastic',
    };
    return featured.contains(product.handle.toLowerCase());
  }

  /// Parse technical specs from body HTML
  Map<String, String> _parseSpecs(String bodyHtml) {
    final specs = <String, String>{};
    final lower = bodyHtml.toLowerCase();

    // Detect chipset
    if (lower.contains('esp32-s3')) {
      specs['chipset'] = 'ESP32-S3';
    } else if (lower.contains('esp32')) {
      specs['chipset'] = 'ESP32';
    } else if (lower.contains('nrf52840')) {
      specs['chipset'] = 'nRF52840';
    }

    // Detect LoRa chip
    if (lower.contains('sx1262')) {
      specs['loraChip'] = 'SX1262';
    } else if (lower.contains('sx1276')) {
      specs['loraChip'] = 'SX1276';
    } else if (lower.contains('sx1280')) {
      specs['loraChip'] = 'SX1280';
    } else if (lower.contains('lr1110') || lower.contains('lr1121')) {
      specs['loraChip'] = 'LR1121';
    }

    // Detect features
    specs['hasGps'] = (lower.contains('gps') || lower.contains('gnss'))
        .toString();
    specs['hasDisplay'] =
        (lower.contains('display') ||
                lower.contains('screen') ||
                lower.contains('oled') ||
                lower.contains('lcd') ||
                lower.contains('e-paper') ||
                lower.contains('e-ink'))
            .toString();
    specs['hasBluetooth'] =
        (lower.contains('bluetooth') || lower.contains('ble')).toString();
    specs['hasWifi'] = lower.contains('wifi').toString();

    // Extract battery capacity
    final batteryMatch = RegExp(
      r'(\d+)\s*mah',
      caseSensitive: false,
    ).firstMatch(lower);
    if (batteryMatch != null) {
      specs['batteryCapacity'] = '${batteryMatch.group(1)} mAh';
    }

    return specs;
  }

  /// Clean HTML tags from description
  String _cleanHtml(String html) {
    // Remove HTML tags
    var text = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
    // Decode HTML entities
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }

  /// Extract a short description from the body HTML
  String? _extractShortDescription(String bodyHtml) {
    final cleaned = _cleanHtml(bodyHtml);
    if (cleaned.length <= 150) return cleaned;

    // Find a good break point
    final truncated = cleaned.substring(0, 150);
    final lastSpace = truncated.lastIndexOf(' ');
    if (lastSpace > 100) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '$truncated...';
  }

  /// Format price range for display
  String _formatPriceRange(double min, double max) {
    if (min == max) {
      return '\$${min.toStringAsFixed(2)}';
    }
    return '\$${min.toStringAsFixed(2)} - \$${max.toStringAsFixed(2)}';
  }

  /// Dispose of resources
  void dispose() {
    _client.close();
  }
}
