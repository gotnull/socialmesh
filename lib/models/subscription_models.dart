// One-time purchase definitions and feature flags for monetization

import '../config/revenuecat_config.dart';

/// Features that can be unlocked via one-time purchases
enum PremiumFeature {
  // Cosmetic
  premiumThemes,
  customRingtones,
  homeWidgets,

  // Automation
  automations,
  iftttIntegration,
}

/// One-time purchasable items
class OneTimePurchase {
  final String id;
  final String name;
  final String description;
  final double price;
  final String productId;
  final PremiumFeature unlocksFeature;

  const OneTimePurchase({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.productId,
    required this.unlocksFeature,
  });
}

class OneTimePurchases {
  static OneTimePurchase get themePack => OneTimePurchase(
    id: 'theme_pack',
    name: 'Theme Pack',
    description: '12 vibrant accent colors to personalize your experience',
    price: 1.99,
    productId: RevenueCatConfig.themePackProductId,
    unlocksFeature: PremiumFeature.premiumThemes,
  );

  static OneTimePurchase get ringtonePack => OneTimePurchase(
    id: 'ringtone_pack',
    name: 'Ringtone Library',
    description: 'Massive searchable RTTTL library — thousands of tones',
    price: 0.99,
    productId: RevenueCatConfig.ringtonePackProductId,
    unlocksFeature: PremiumFeature.customRingtones,
  );

  static OneTimePurchase get widgetPack => OneTimePurchase(
    id: 'widget_pack',
    name: 'Widget Pack',
    description: '9 dashboard widgets: signal charts, node maps & more',
    price: 2.99,
    productId: RevenueCatConfig.widgetPackProductId,
    unlocksFeature: PremiumFeature.homeWidgets,
  );

  static OneTimePurchase get automationsPack => OneTimePurchase(
    id: 'automations_pack',
    name: 'Automations',
    description: 'Auto-reply, scheduled broadcasts, location triggers & more',
    price: 3.99,
    productId: RevenueCatConfig.automationsPackProductId,
    unlocksFeature: PremiumFeature.automations,
  );

  static OneTimePurchase get iftttPack => OneTimePurchase(
    id: 'ifttt_pack',
    name: 'IFTTT Integration',
    description: 'Connect mesh events to 700+ apps — smart home, Slack & more',
    price: 2.99,
    productId: RevenueCatConfig.iftttPackProductId,
    unlocksFeature: PremiumFeature.iftttIntegration,
  );

  /// Complete Pack - all features bundled at 25% off
  static const double bundlePrice = 9.99;
  static double get bundleSavings {
    final total = allIndividualPurchases.fold<double>(
      0,
      (sum, p) => sum + p.price,
    );
    return total - bundlePrice;
  }

  static int get bundleDiscountPercent {
    final total = allIndividualPurchases.fold<double>(
      0,
      (sum, p) => sum + p.price,
    );
    return ((1 - bundlePrice / total) * 100).round();
  }

  /// Individual purchases (excludes bundle)
  static List<OneTimePurchase> get allIndividualPurchases => <OneTimePurchase>[
    themePack,
    ringtonePack,
    widgetPack,
    automationsPack,
    iftttPack,
  ];

  static List<OneTimePurchase> get allPurchases => <OneTimePurchase>[
    themePack,
    ringtonePack,
    widgetPack,
    automationsPack,
    iftttPack,
  ];

  /// Get purchase by product ID
  static OneTimePurchase? getByProductId(String productId) {
    return allPurchases.where((p) => p.productId == productId).firstOrNull;
  }

  /// Get purchase by feature
  static OneTimePurchase? getByFeature(PremiumFeature feature) {
    return allPurchases.where((p) => p.unlocksFeature == feature).firstOrNull;
  }
}

/// Current purchase state - tracks which features have been purchased
class PurchaseState {
  final Set<String> purchasedProductIds;
  final String? customerId;

  const PurchaseState({this.purchasedProductIds = const {}, this.customerId});

  /// Check if a specific feature is unlocked
  bool hasFeature(PremiumFeature feature) {
    final purchase = OneTimePurchases.getByFeature(feature);
    if (purchase == null) return false;
    return purchasedProductIds.contains(purchase.productId);
  }

  /// Check if a specific product has been purchased
  /// Also returns true for individual packs if Complete Pack was purchased
  bool hasPurchased(String productId) {
    // Direct purchase check
    if (purchasedProductIds.contains(productId)) return true;

    // If user owns Complete Pack, they have access to all individual packs
    if (purchasedProductIds.contains(RevenueCatConfig.completePackProductId)) {
      final individualIds = OneTimePurchases.allIndividualPurchases
          .map((p) => p.productId)
          .toSet();
      if (individualIds.contains(productId)) return true;
    }

    return false;
  }

  PurchaseState copyWith({
    Set<String>? purchasedProductIds,
    String? customerId,
  }) {
    return PurchaseState(
      purchasedProductIds: purchasedProductIds ?? this.purchasedProductIds,
      customerId: customerId ?? this.customerId,
    );
  }

  static const initial = PurchaseState();
}
