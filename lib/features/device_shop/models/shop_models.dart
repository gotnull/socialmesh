import 'package:cloud_firestore/cloud_firestore.dart';

/// Device category
enum DeviceCategory {
  node('Nodes', 'Complete Meshtastic devices'),
  module('Modules', 'Add-on modules and boards'),
  antenna('Antennas', 'Antennas and RF accessories'),
  enclosure('Enclosures', 'Cases and enclosures'),
  accessory('Accessories', 'Cables, batteries, and more'),
  kit('Kits', 'DIY kits and bundles'),
  solar('Solar', 'Solar panels and power solutions');

  const DeviceCategory(this.label, this.description);
  final String label;
  final String description;

  static DeviceCategory fromString(String value) {
    return DeviceCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => DeviceCategory.node,
    );
  }
}

/// Frequency band support
enum FrequencyBand {
  us915('US 915MHz', '902-928 MHz'),
  eu868('EU 868MHz', '863-870 MHz'),
  cn470('CN 470MHz', '470-510 MHz'),
  jp920('JP 920MHz', '920-925 MHz'),
  kr920('KR 920MHz', '920-923 MHz'),
  au915('AU 915MHz', '915-928 MHz'),
  in865('IN 865MHz', '865-867 MHz'),
  multiband('Multi-band', 'Multiple frequencies');

  const FrequencyBand(this.label, this.range);
  final String label;
  final String range;

  static FrequencyBand fromString(String value) {
    return FrequencyBand.values.firstWhere(
      (f) => f.name == value,
      orElse: () => FrequencyBand.us915,
    );
  }
}

/// Seller/vendor profile
class ShopSeller {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? websiteUrl;
  final String? contactEmail;
  final bool isVerified;
  final bool isOfficialPartner;
  final double rating;
  final int reviewCount;
  final int productCount;
  final int salesCount;
  final DateTime joinedAt;
  final List<String> countries; // Ships to these countries
  final String? stripeAccountId;
  final bool isActive;

  const ShopSeller({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.websiteUrl,
    this.contactEmail,
    this.isVerified = false,
    this.isOfficialPartner = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.productCount = 0,
    this.salesCount = 0,
    required this.joinedAt,
    this.countries = const [],
    this.stripeAccountId,
    this.isActive = true,
  });

  /// Known official partners
  static const officialPartners = [
    'LilyGO',
    'SenseCAP',
    'RAK Wireless',
    'Heltec',
    'TTGO',
    'Rokland',
  ];

  factory ShopSeller.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopSeller(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'],
      logoUrl: data['logoUrl'],
      websiteUrl: data['websiteUrl'],
      contactEmail: data['contactEmail'],
      isVerified: data['isVerified'] ?? false,
      isOfficialPartner: data['isOfficialPartner'] ?? false,
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: data['reviewCount'] ?? 0,
      productCount: data['productCount'] ?? 0,
      salesCount: data['salesCount'] ?? 0,
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      countries:
          (data['countries'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      stripeAccountId: data['stripeAccountId'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'logoUrl': logoUrl,
      'websiteUrl': websiteUrl,
      'contactEmail': contactEmail,
      'isVerified': isVerified,
      'isOfficialPartner': isOfficialPartner,
      'rating': rating,
      'reviewCount': reviewCount,
      'productCount': productCount,
      'salesCount': salesCount,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'countries': countries,
      'stripeAccountId': stripeAccountId,
      'isActive': isActive,
    };
  }

  ShopSeller copyWith({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    String? websiteUrl,
    String? contactEmail,
    bool? isVerified,
    bool? isOfficialPartner,
    double? rating,
    int? reviewCount,
    int? productCount,
    int? salesCount,
    DateTime? joinedAt,
    List<String>? countries,
    String? stripeAccountId,
    bool? isActive,
  }) {
    return ShopSeller(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      contactEmail: contactEmail ?? this.contactEmail,
      isVerified: isVerified ?? this.isVerified,
      isOfficialPartner: isOfficialPartner ?? this.isOfficialPartner,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      productCount: productCount ?? this.productCount,
      salesCount: salesCount ?? this.salesCount,
      joinedAt: joinedAt ?? this.joinedAt,
      countries: countries ?? this.countries,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      isActive: isActive ?? this.isActive,
    );
  }
}

/// Product listing
class ShopProduct {
  final String id;
  final String sellerId;
  final String sellerName;
  final String name;
  final String description;
  final String? shortDescription;
  final DeviceCategory category;
  final List<String> tags;
  final List<String> imageUrls;
  final String? videoUrl;
  final double price;
  final String currency;
  final double? compareAtPrice; // Original price for sales
  final int stockQuantity;
  final bool isInStock;
  final bool isActive;
  final bool isFeatured;

  // Technical specs
  final List<FrequencyBand> frequencyBands;
  final String? chipset; // e.g., ESP32, nRF52840
  final String? loraChip; // e.g., SX1262, SX1276
  final bool hasGps;
  final bool hasDisplay;
  final bool hasBluetooth;
  final bool hasWifi;
  final String? batteryCapacity;
  final String? dimensions;
  final String? weight;
  final List<String> includedAccessories;

  // Ratings & reviews
  final double rating;
  final int reviewCount;
  final int salesCount;
  final int viewCount;
  final int favoriteCount;

  // Shipping
  final double? shippingCost;
  final String? shippingInfo;
  final int? estimatedDeliveryDays;
  final List<String> shipsTo;

  // Timestamps
  final DateTime createdAt;
  final DateTime updatedAt;

  // Meshtastic specific
  final bool isMeshtasticCompatible;
  final String? firmwareVersion; // Pre-installed firmware version
  final String? hardwareVersion;
  final String? purchaseUrl; // External URL if redirecting

  const ShopProduct({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.description,
    this.shortDescription,
    required this.category,
    this.tags = const [],
    this.imageUrls = const [],
    this.videoUrl,
    required this.price,
    this.currency = 'USD',
    this.compareAtPrice,
    this.stockQuantity = 0,
    this.isInStock = true,
    this.isActive = true,
    this.isFeatured = false,
    this.frequencyBands = const [],
    this.chipset,
    this.loraChip,
    this.hasGps = false,
    this.hasDisplay = false,
    this.hasBluetooth = false,
    this.hasWifi = false,
    this.batteryCapacity,
    this.dimensions,
    this.weight,
    this.includedAccessories = const [],
    this.rating = 0,
    this.reviewCount = 0,
    this.salesCount = 0,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.shippingCost,
    this.shippingInfo,
    this.estimatedDeliveryDays,
    this.shipsTo = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isMeshtasticCompatible = true,
    this.firmwareVersion,
    this.hardwareVersion,
    this.purchaseUrl,
  });

  /// Check if product is on sale
  bool get isOnSale => compareAtPrice != null && compareAtPrice! > price;

  /// Calculate discount percentage
  int get discountPercent {
    if (!isOnSale) return 0;
    return (((compareAtPrice! - price) / compareAtPrice!) * 100).round();
  }

  /// Get primary image
  String? get primaryImage => imageUrls.isNotEmpty ? imageUrls.first : null;

  /// Get formatted price
  String get formattedPrice {
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Get formatted compare price
  String? get formattedComparePrice {
    if (compareAtPrice == null) return null;
    return '\$${compareAtPrice!.toStringAsFixed(2)}';
  }

  factory ShopProduct.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ShopProduct(
      id: doc.id,
      sellerId: data['sellerId'] ?? '',
      sellerName: data['sellerName'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      shortDescription: data['shortDescription'],
      category: DeviceCategory.fromString(data['category'] ?? 'node'),
      tags:
          (data['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      imageUrls:
          (data['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videoUrl: data['videoUrl'],
      price: (data['price'] as num?)?.toDouble() ?? 0,
      currency: data['currency'] ?? 'USD',
      compareAtPrice: (data['compareAtPrice'] as num?)?.toDouble(),
      stockQuantity: data['stockQuantity'] ?? 0,
      isInStock: data['isInStock'] ?? true,
      isActive: data['isActive'] ?? true,
      isFeatured: data['isFeatured'] ?? false,
      frequencyBands:
          (data['frequencyBands'] as List<dynamic>?)
              ?.map((e) => FrequencyBand.fromString(e.toString()))
              .toList() ??
          [],
      chipset: data['chipset'],
      loraChip: data['loraChip'],
      hasGps: data['hasGps'] ?? false,
      hasDisplay: data['hasDisplay'] ?? false,
      hasBluetooth: data['hasBluetooth'] ?? false,
      hasWifi: data['hasWifi'] ?? false,
      batteryCapacity: data['batteryCapacity'],
      dimensions: data['dimensions'],
      weight: data['weight'],
      includedAccessories:
          (data['includedAccessories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: data['reviewCount'] ?? 0,
      salesCount: data['salesCount'] ?? 0,
      viewCount: data['viewCount'] ?? 0,
      favoriteCount: data['favoriteCount'] ?? 0,
      shippingCost: (data['shippingCost'] as num?)?.toDouble(),
      shippingInfo: data['shippingInfo'],
      estimatedDeliveryDays: data['estimatedDeliveryDays'],
      shipsTo:
          (data['shipsTo'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isMeshtasticCompatible: data['isMeshtasticCompatible'] ?? true,
      firmwareVersion: data['firmwareVersion'],
      hardwareVersion: data['hardwareVersion'],
      purchaseUrl: data['purchaseUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'sellerId': sellerId,
      'sellerName': sellerName,
      'name': name,
      'description': description,
      'shortDescription': shortDescription,
      'category': category.name,
      'tags': tags,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'price': price,
      'currency': currency,
      'compareAtPrice': compareAtPrice,
      'stockQuantity': stockQuantity,
      'isInStock': isInStock,
      'isActive': isActive,
      'isFeatured': isFeatured,
      'frequencyBands': frequencyBands.map((f) => f.name).toList(),
      'chipset': chipset,
      'loraChip': loraChip,
      'hasGps': hasGps,
      'hasDisplay': hasDisplay,
      'hasBluetooth': hasBluetooth,
      'hasWifi': hasWifi,
      'batteryCapacity': batteryCapacity,
      'dimensions': dimensions,
      'weight': weight,
      'includedAccessories': includedAccessories,
      'rating': rating,
      'reviewCount': reviewCount,
      'salesCount': salesCount,
      'viewCount': viewCount,
      'favoriteCount': favoriteCount,
      'shippingCost': shippingCost,
      'shippingInfo': shippingInfo,
      'estimatedDeliveryDays': estimatedDeliveryDays,
      'shipsTo': shipsTo,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isMeshtasticCompatible': isMeshtasticCompatible,
      'firmwareVersion': firmwareVersion,
      'hardwareVersion': hardwareVersion,
      'purchaseUrl': purchaseUrl,
    };
  }

  ShopProduct copyWith({
    String? id,
    String? sellerId,
    String? sellerName,
    String? name,
    String? description,
    String? shortDescription,
    DeviceCategory? category,
    List<String>? tags,
    List<String>? imageUrls,
    String? videoUrl,
    double? price,
    String? currency,
    double? compareAtPrice,
    int? stockQuantity,
    bool? isInStock,
    bool? isActive,
    bool? isFeatured,
    List<FrequencyBand>? frequencyBands,
    String? chipset,
    String? loraChip,
    bool? hasGps,
    bool? hasDisplay,
    bool? hasBluetooth,
    bool? hasWifi,
    String? batteryCapacity,
    String? dimensions,
    String? weight,
    List<String>? includedAccessories,
    double? rating,
    int? reviewCount,
    int? salesCount,
    int? viewCount,
    int? favoriteCount,
    double? shippingCost,
    String? shippingInfo,
    int? estimatedDeliveryDays,
    List<String>? shipsTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isMeshtasticCompatible,
    String? firmwareVersion,
    String? hardwareVersion,
    String? purchaseUrl,
  }) {
    return ShopProduct(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      name: name ?? this.name,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isInStock: isInStock ?? this.isInStock,
      isActive: isActive ?? this.isActive,
      isFeatured: isFeatured ?? this.isFeatured,
      frequencyBands: frequencyBands ?? this.frequencyBands,
      chipset: chipset ?? this.chipset,
      loraChip: loraChip ?? this.loraChip,
      hasGps: hasGps ?? this.hasGps,
      hasDisplay: hasDisplay ?? this.hasDisplay,
      hasBluetooth: hasBluetooth ?? this.hasBluetooth,
      hasWifi: hasWifi ?? this.hasWifi,
      batteryCapacity: batteryCapacity ?? this.batteryCapacity,
      dimensions: dimensions ?? this.dimensions,
      weight: weight ?? this.weight,
      includedAccessories: includedAccessories ?? this.includedAccessories,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      salesCount: salesCount ?? this.salesCount,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      shippingCost: shippingCost ?? this.shippingCost,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      estimatedDeliveryDays:
          estimatedDeliveryDays ?? this.estimatedDeliveryDays,
      shipsTo: shipsTo ?? this.shipsTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isMeshtasticCompatible:
          isMeshtasticCompatible ?? this.isMeshtasticCompatible,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      hardwareVersion: hardwareVersion ?? this.hardwareVersion,
      purchaseUrl: purchaseUrl ?? this.purchaseUrl,
    );
  }
}

/// Product review
class ProductReview {
  final String id;
  final String productId;
  final String userId;
  final String? userName;
  final String? userPhotoUrl;
  final int rating; // 1-5
  final String? title;
  final String? body;
  final List<String> imageUrls;
  final bool isVerifiedPurchase;
  final int helpfulCount;
  final DateTime createdAt;
  final String? sellerResponse;
  final DateTime? sellerResponseAt;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.userId,
    this.userName,
    this.userPhotoUrl,
    required this.rating,
    this.title,
    this.body,
    this.imageUrls = const [],
    this.isVerifiedPurchase = false,
    this.helpfulCount = 0,
    required this.createdAt,
    this.sellerResponse,
    this.sellerResponseAt,
  });

  factory ProductReview.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductReview(
      id: doc.id,
      productId: data['productId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'],
      userPhotoUrl: data['userPhotoUrl'],
      rating: data['rating'] ?? 5,
      title: data['title'],
      body: data['body'],
      imageUrls:
          (data['imageUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isVerifiedPurchase: data['isVerifiedPurchase'] ?? false,
      helpfulCount: data['helpfulCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sellerResponse: data['sellerResponse'],
      sellerResponseAt: (data['sellerResponseAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'rating': rating,
      'title': title,
      'body': body,
      'imageUrls': imageUrls,
      'isVerifiedPurchase': isVerifiedPurchase,
      'helpfulCount': helpfulCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'sellerResponse': sellerResponse,
      'sellerResponseAt': sellerResponseAt != null
          ? Timestamp.fromDate(sellerResponseAt!)
          : null,
    };
  }
}

/// User's favorite product
class ProductFavorite {
  final String id;
  final String oderId;
  final String productId;
  final DateTime addedAt;

  const ProductFavorite({
    required this.id,
    required this.oderId,
    required this.productId,
    required this.addedAt,
  });

  factory ProductFavorite.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ProductFavorite(
      id: doc.id,
      oderId: data['userId'] ?? '',
      productId: data['productId'] ?? '',
      addedAt: (data['addedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': oderId,
      'productId': productId,
      'addedAt': Timestamp.fromDate(addedAt),
    };
  }
}
