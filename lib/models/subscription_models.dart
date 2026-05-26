// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// One-time purchase definitions and feature flags for monetization

import '../config/revenuecat_config.dart';
import '../generated/product_catalog.g.dart';

/// Features that can be unlocked via one-time purchases
enum PremiumFeature {
  // Cosmetic
  premiumThemes,
  customRingtones,
  homeWidgets,

  // Automation
  automations,
  iftttIntegration,

  // Communication
  translation,
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
    id: ProductCatalog.themePack.id,
    name: ProductCatalog.themePack.name,
    description:
        'Unlock 12 stunning accent colors to personalize every screen, button, and highlight throughout the app — make it truly yours', // lint-allow: hardcoded-string
    price: ProductCatalog.themePack.priceUsd,
    productId: RevenueCatConfig.themePackProductId,
    unlocksFeature: PremiumFeature.premiumThemes,
  );

  static OneTimePurchase get ringtonePack => OneTimePurchase(
    id: ProductCatalog.ringtonePack.id,
    name: ProductCatalog.ringtonePack.name,
    description:
        'Access a massive searchable library of thousands of RTTTL ringtones — from classic melodies to TV themes, movie scores, and video game soundtracks', // lint-allow: hardcoded-string
    price: ProductCatalog.ringtonePack.priceUsd,
    productId: RevenueCatConfig.ringtonePackProductId,
    unlocksFeature: PremiumFeature.customRingtones,
  );

  static OneTimePurchase get widgetPack => OneTimePurchase(
    id: ProductCatalog.widgetPack.id,
    name: ProductCatalog.widgetPack.name,
    description:
        'Build your own custom dashboard widgets with live data bindings, real-time charts, gauges, graphs, and status indicators — monitor battery, telemetry, environment sensors, and more at a glance', // lint-allow: hardcoded-string
    price: ProductCatalog.widgetPack.priceUsd,
    productId: RevenueCatConfig.widgetPackProductId,
    unlocksFeature: PremiumFeature.homeWidgets,
  );

  static OneTimePurchase get automationsPack => OneTimePurchase(
    id: ProductCatalog.automationsPack.id,
    name: ProductCatalog.automationsPack.name,
    description:
        'Create powerful automation rules: auto-reply to messages, schedule broadcasts at specific times, trigger actions based on location or device events, and set up custom notification flows', // lint-allow: hardcoded-string
    price: ProductCatalog.automationsPack.priceUsd,
    productId: RevenueCatConfig.automationsPackProductId,
    unlocksFeature: PremiumFeature.automations,
  );

  static OneTimePurchase get iftttPack => OneTimePurchase(
    id: ProductCatalog.iftttPack.id,
    name: ProductCatalog.iftttPack.name,
    description:
        'Connect your mesh network to 700+ apps and services — trigger smart home devices, log events to spreadsheets, send Slack notifications, post to social media, and integrate with virtually anything', // lint-allow: hardcoded-string
    price: ProductCatalog.iftttPack.priceUsd,
    productId: RevenueCatConfig.iftttPackProductId,
    unlocksFeature: PremiumFeature.iftttIntegration,
  );

  static OneTimePurchase get translationPack => OneTimePurchase(
    id: ProductCatalog.translationPack.id,
    name: ProductCatalog.translationPack.name,
    description:
        'Unlock on-demand message translation with smart caching and privacy controls — includes a managed allowance, or bring your own API key for extended use', // lint-allow: hardcoded-string
    price: ProductCatalog.translationPack.priceUsd,
    productId: RevenueCatConfig.translationPackProductId,
    unlocksFeature: PremiumFeature.translation,
  );

  static double get bundlePrice => ProductCatalog.completePack.priceUsd;
  static double get bundleSavings {
    final total = completePackPurchases.fold<double>(
      0,
      (sum, p) => sum + p.price,
    );
    return total - bundlePrice;
  }

  static int get bundleDiscountPercent {
    final total = completePackPurchases.fold<double>(
      0,
      (sum, p) => sum + p.price,
    );
    return ((1 - bundlePrice / total) * 100).round();
  }

  static List<OneTimePurchase> get completePackPurchases => <OneTimePurchase>[
    themePack,
    ringtonePack,
    widgetPack,
    automationsPack,
    iftttPack,
  ];

  /// All individual purchases (includes Translation Pack, excludes bundle)
  static List<OneTimePurchase> get allIndividualPurchases => <OneTimePurchase>[
    translationPack,
    themePack,
    ringtonePack,
    widgetPack,
    automationsPack,
    iftttPack,
  ];

  static List<OneTimePurchase> get allPurchases => <OneTimePurchase>[
    translationPack,
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
  /// Also returns true if Complete Pack was purchased
  bool hasFeature(PremiumFeature feature) {
    final purchase = OneTimePurchases.getByFeature(feature);
    if (purchase == null) return false;
    return hasPurchased(purchase.productId);
  }

  /// Check if a specific product has been purchased
  /// Also returns true for individual packs if Complete Pack was purchased
  bool hasPurchased(String productId) {
    // Direct purchase check
    if (purchasedProductIds.contains(productId)) return true;

    if (purchasedProductIds.contains(RevenueCatConfig.completePackProductId)) {
      final bundledIds = OneTimePurchases.completePackPurchases
          .map((p) => p.productId)
          .toSet();
      if (bundledIds.contains(productId)) return true;
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
