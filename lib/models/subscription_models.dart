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
  static const themePack = OneTimePurchase(
    id: 'theme_pack',
    name: 'Theme Pack',
    description: 'Unlock 12 premium color themes',
    price: 1.99,
    productId: RevenueCatConfig.themePackProductId,
    unlocksFeature: PremiumFeature.premiumThemes,
  );

  static const ringtonePack = OneTimePurchase(
    id: 'ringtone_pack',
    name: 'Ringtone Pack',
    description: '25 additional RTTTL ringtones',
    price: 0.99,
    productId: RevenueCatConfig.ringtonePackProductId,
    unlocksFeature: PremiumFeature.customRingtones,
  );

  static const widgetPack = OneTimePurchase(
    id: 'widget_pack',
    name: 'Widget Pack',
    description: 'Home screen widgets for quick actions',
    price: 2.99,
    productId: RevenueCatConfig.widgetPackProductId,
    unlocksFeature: PremiumFeature.homeWidgets,
  );

  static const automationsPack = OneTimePurchase(
    id: 'automations_pack',
    name: 'Automations',
    description: 'Custom triggers, actions & scheduled tasks',
    price: 3.99,
    productId: RevenueCatConfig.automationsPackProductId,
    unlocksFeature: PremiumFeature.automations,
  );

  static const iftttPack = OneTimePurchase(
    id: 'ifttt_pack',
    name: 'IFTTT Integration',
    description: 'Connect to 700+ apps via IFTTT',
    price: 2.99,
    productId: RevenueCatConfig.iftttPackProductId,
    unlocksFeature: PremiumFeature.iftttIntegration,
  );

  static const allPurchases = <OneTimePurchase>[
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

  const PurchaseState({
    this.purchasedProductIds = const {},
    this.customerId,
  });

  /// Check if a specific feature is unlocked
  bool hasFeature(PremiumFeature feature) {
    final purchase = OneTimePurchases.getByFeature(feature);
    if (purchase == null) return false;
    return purchasedProductIds.contains(purchase.productId);
  }

  /// Check if a specific product has been purchased
  bool hasPurchased(String productId) {
    return purchasedProductIds.contains(productId);
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
