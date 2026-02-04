// SPDX-License-Identifier: GPL-3.0-or-later

// Models for LILYGO Shopify API responses
//
// These models map directly to the Shopify JSON API structure.
// See: https://lilygo.cc/products.json

/// A product from LILYGO's Shopify store
class LilygoProduct {
  final int id;
  final String title;
  final String handle;
  final String bodyHtml;
  final String vendor;
  final String productType;
  final List<String> tags;
  final List<LilygoVariant> variants;
  final List<LilygoImage> images;
  final List<LilygoOption> options;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? publishedAt;

  const LilygoProduct({
    required this.id,
    required this.title,
    required this.handle,
    required this.bodyHtml,
    required this.vendor,
    required this.productType,
    required this.tags,
    required this.variants,
    required this.images,
    required this.options,
    required this.createdAt,
    required this.updatedAt,
    this.publishedAt,
  });

  factory LilygoProduct.fromJson(Map<String, dynamic> json) {
    return LilygoProduct(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      handle: json['handle'] as String? ?? '',
      bodyHtml: json['body_html'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      productType: json['product_type'] as String? ?? '',
      tags: _parseTags(json['tags']),
      variants:
          (json['variants'] as List<dynamic>?)
              ?.map((v) => LilygoVariant.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      images:
          (json['images'] as List<dynamic>?)
              ?.map((i) => LilygoImage.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      options:
          (json['options'] as List<dynamic>?)
              ?.map((o) => LilygoOption.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      publishedAt: json['published_at'] != null
          ? _parseDateTime(json['published_at'])
          : null,
    );
  }

  static List<String> _parseTags(dynamic tags) {
    if (tags == null) return [];
    if (tags is String) {
      return tags
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
    }
    if (tags is List) {
      return tags.map((t) => t.toString()).toList();
    }
    return [];
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  /// Get primary image URL
  String? get primaryImageUrl => images.isNotEmpty ? images.first.src : null;

  /// Check if any variants are available
  bool get isAvailable => variants.any((v) => v.available);

  /// Get price range as formatted string
  String get priceRange {
    if (variants.isEmpty) return 'Price unavailable';
    final prices = variants.map((v) => v.priceValue).toList();
    final min = prices.reduce((a, b) => a < b ? a : b);
    final max = prices.reduce((a, b) => a > b ? a : b);
    if (min == max) return '\$${min.toStringAsFixed(2)}';
    return '\$${min.toStringAsFixed(2)} - \$${max.toStringAsFixed(2)}';
  }

  @override
  String toString() => 'LilygoProduct(id: $id, title: $title, handle: $handle)';
}

/// A product variant (different configurations, frequencies, etc.)
class LilygoVariant {
  final int id;
  final int productId;
  final String title;
  final String price;
  final String? compareAtPrice;
  final String? sku;
  final int position;
  final String? option1;
  final String? option2;
  final String? option3;
  final bool available;
  final int grams;
  final bool requiresShipping;
  final bool taxable;
  final LilygoFeaturedImage? featuredImage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LilygoVariant({
    required this.id,
    required this.productId,
    required this.title,
    required this.price,
    this.compareAtPrice,
    this.sku,
    required this.position,
    this.option1,
    this.option2,
    this.option3,
    required this.available,
    required this.grams,
    required this.requiresShipping,
    required this.taxable,
    this.featuredImage,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LilygoVariant.fromJson(Map<String, dynamic> json) {
    return LilygoVariant(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      title: json['title'] as String? ?? '',
      price: json['price'] as String? ?? '0',
      compareAtPrice: json['compare_at_price'] as String?,
      sku: json['sku'] as String?,
      position: json['position'] as int? ?? 0,
      option1: json['option1'] as String?,
      option2: json['option2'] as String?,
      option3: json['option3'] as String?,
      available: json['available'] as bool? ?? false,
      grams: json['grams'] as int? ?? 0,
      requiresShipping: json['requires_shipping'] as bool? ?? true,
      taxable: json['taxable'] as bool? ?? false,
      featuredImage: json['featured_image'] != null
          ? LilygoFeaturedImage.fromJson(
              json['featured_image'] as Map<String, dynamic>,
            )
          : null,
      createdAt: LilygoProduct._parseDateTime(json['created_at']),
      updatedAt: LilygoProduct._parseDateTime(json['updated_at']),
    );
  }

  /// Parse price string to double
  double get priceValue => double.tryParse(price) ?? 0.0;

  /// Parse compare at price to double
  double? get compareAtPriceValue =>
      compareAtPrice != null ? double.tryParse(compareAtPrice!) : null;

  /// Check if variant is on sale
  bool get isOnSale {
    final compare = compareAtPriceValue;
    return compare != null && compare > priceValue;
  }

  /// Get discount percentage
  int get discountPercent {
    if (!isOnSale) return 0;
    return (((compareAtPriceValue! - priceValue) / compareAtPriceValue!) * 100)
        .round();
  }

  @override
  String toString() => 'LilygoVariant(id: $id, title: $title, price: $price)';
}

/// Product image
class LilygoImage {
  final int id;
  final int productId;
  final int position;
  final String src;
  final int? width;
  final int? height;
  final String? alt;
  final List<int> variantIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LilygoImage({
    required this.id,
    required this.productId,
    required this.position,
    required this.src,
    this.width,
    this.height,
    this.alt,
    required this.variantIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LilygoImage.fromJson(Map<String, dynamic> json) {
    return LilygoImage(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      position: json['position'] as int? ?? 0,
      src: json['src'] as String? ?? '',
      width: json['width'] as int?,
      height: json['height'] as int?,
      alt: json['alt'] as String?,
      variantIds:
          (json['variant_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      createdAt: LilygoProduct._parseDateTime(json['created_at']),
      updatedAt: LilygoProduct._parseDateTime(json['updated_at']),
    );
  }

  /// Get optimized image URL for given size
  String getResizedUrl({int? width, int? height}) {
    // Shopify CDN supports on-the-fly resizing
    // Format: url_widthxheight.ext
    if (width == null && height == null) return src;

    final lastDot = src.lastIndexOf('.');
    if (lastDot == -1) return src;

    final base = src.substring(0, lastDot);
    final ext = src.substring(lastDot);

    final size = <String>[];
    if (width != null) size.add('${width}x');
    if (height != null) size.add(height.toString());

    return '${base}_${size.join()}.jpg$ext';
  }

  @override
  String toString() => 'LilygoImage(id: $id, position: $position)';
}

/// Featured image for a variant
class LilygoFeaturedImage {
  final int id;
  final int productId;
  final int position;
  final String src;
  final int? width;
  final int? height;
  final String? alt;
  final List<int> variantIds;

  const LilygoFeaturedImage({
    required this.id,
    required this.productId,
    required this.position,
    required this.src,
    this.width,
    this.height,
    this.alt,
    required this.variantIds,
  });

  factory LilygoFeaturedImage.fromJson(Map<String, dynamic> json) {
    return LilygoFeaturedImage(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      position: json['position'] as int? ?? 0,
      src: json['src'] as String? ?? '',
      width: json['width'] as int?,
      height: json['height'] as int?,
      alt: json['alt'] as String?,
      variantIds:
          (json['variant_ids'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

/// Product option (e.g., Frequency, Color, Warehouse)
class LilygoOption {
  final String name;
  final int position;
  final List<String> values;

  const LilygoOption({
    required this.name,
    required this.position,
    required this.values,
  });

  factory LilygoOption.fromJson(Map<String, dynamic> json) {
    return LilygoOption(
      name: json['name'] as String? ?? '',
      position: json['position'] as int? ?? 0,
      values:
          (json['values'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  @override
  String toString() => 'LilygoOption(name: $name, values: $values)';
}

/// Collection metadata
class LilygoCollection {
  final int id;
  final String title;
  final String handle;
  final String? description;
  final int productsCount;
  final DateTime? publishedAt;
  final DateTime? updatedAt;

  const LilygoCollection({
    required this.id,
    required this.title,
    required this.handle,
    this.description,
    required this.productsCount,
    this.publishedAt,
    this.updatedAt,
  });

  factory LilygoCollection.fromJson(Map<String, dynamic> json) {
    return LilygoCollection(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      handle: json['handle'] as String? ?? '',
      description: json['description'] as String?,
      productsCount: json['products_count'] as int? ?? 0,
      publishedAt: json['published_at'] != null
          ? LilygoProduct._parseDateTime(json['published_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? LilygoProduct._parseDateTime(json['updated_at'])
          : null,
    );
  }

  @override
  String toString() =>
      'LilygoCollection(title: $title, productsCount: $productsCount)';
}
