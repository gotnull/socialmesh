// This is a generated file - do not edit.
//
// Generated from config/product_catalog.json by
// scripts/gen_product_catalog.sh. Edit the JSON; regenerate via:
//     scripts/gen_product_catalog.sh

// ignore_for_file: constant_identifier_names

enum ProductKind { oneTime, subscription }

class ProductSpec {
  final String id;
  final String name;
  final double priceUsd;
  final ProductKind kind;
  final List<String> grants;
  final bool stripeEnabled;

  const ProductSpec({
    required this.id,
    required this.name,
    required this.priceUsd,
    required this.kind,
    required this.grants,
    required this.stripeEnabled,
  });
}

/// Canonical product catalog (USD pricing).
///
/// Single source of truth: config/product_catalog.json.
class ProductCatalog {
  ProductCatalog._();

  static const String currency = 'USD';

  static const ProductSpec themePack = ProductSpec(
    id: 'theme_pack',
    name: 'Theme Pack',
    priceUsd: 2.99,
    kind: ProductKind.oneTime,
    grants: <String>['theme_pack'],
    stripeEnabled: true,
  );

  static const ProductSpec ringtonePack = ProductSpec(
    id: 'ringtone_pack',
    name: 'Ringtone Pack',
    priceUsd: 1.99,
    kind: ProductKind.oneTime,
    grants: <String>['ringtone_pack'],
    stripeEnabled: true,
  );

  static const ProductSpec widgetPack = ProductSpec(
    id: 'widget_pack',
    name: 'Widgets',
    priceUsd: 3.99,
    kind: ProductKind.oneTime,
    grants: <String>['widget_pack'],
    stripeEnabled: true,
  );

  static const ProductSpec automationsPack = ProductSpec(
    id: 'automations_pack',
    name: 'Automations',
    priceUsd: 4.99,
    kind: ProductKind.oneTime,
    grants: <String>['automations_pack'],
    stripeEnabled: true,
  );

  static const ProductSpec iftttPack = ProductSpec(
    id: 'ifttt_pack',
    name: 'IFTTT Integration',
    priceUsd: 3.99,
    kind: ProductKind.oneTime,
    grants: <String>['ifttt_pack'],
    stripeEnabled: true,
  );

  static const ProductSpec completePack = ProductSpec(
    id: 'complete_pack',
    name: 'Complete Pack',
    priceUsd: 9.99,
    kind: ProductKind.oneTime,
    grants: <String>[
      'complete_pack',
      'theme_pack',
      'ringtone_pack',
      'widget_pack',
      'automations_pack',
      'ifttt_pack',
    ],
    stripeEnabled: true,
  );

  static const ProductSpec communityPack10 = ProductSpec(
    id: 'community_pack_10',
    name: 'Community Pack 10',
    priceUsd: 49.99,
    kind: ProductKind.oneTime,
    grants: <String>[
      'complete_pack',
      'theme_pack',
      'ringtone_pack',
      'widget_pack',
      'automations_pack',
      'ifttt_pack',
    ],
    stripeEnabled: true,
  );

  static const ProductSpec communityPack20 = ProductSpec(
    id: 'community_pack_20',
    name: 'Community Pack 20',
    priceUsd: 79.99,
    kind: ProductKind.oneTime,
    grants: <String>[
      'complete_pack',
      'theme_pack',
      'ringtone_pack',
      'widget_pack',
      'automations_pack',
      'ifttt_pack',
    ],
    stripeEnabled: true,
  );

  static const ProductSpec translationPack = ProductSpec(
    id: 'translation_pack',
    name: 'Translation Pack',
    priceUsd: 2.99,
    kind: ProductKind.oneTime,
    grants: <String>['translation_pack'],
    stripeEnabled: false,
  );

  static const ProductSpec cloudMonthly = ProductSpec(
    id: 'cloud_monthly',
    name: 'Cloud Monthly',
    priceUsd: 2.99,
    kind: ProductKind.subscription,
    grants: <String>[],
    stripeEnabled: false,
  );

  static const ProductSpec cloudYearly = ProductSpec(
    id: 'cloud_yearly',
    name: 'Cloud Yearly',
    priceUsd: 24.99,
    kind: ProductKind.subscription,
    grants: <String>[],
    stripeEnabled: false,
  );

  static const Map<String, ProductSpec> all = <String, ProductSpec>{
    'theme_pack': themePack,
    'ringtone_pack': ringtonePack,
    'widget_pack': widgetPack,
    'automations_pack': automationsPack,
    'ifttt_pack': iftttPack,
    'complete_pack': completePack,
    'community_pack_10': communityPack10,
    'community_pack_20': communityPack20,
    'translation_pack': translationPack,
    'cloud_monthly': cloudMonthly,
    'cloud_yearly': cloudYearly,
  };

  static const Map<String, double> pricesUsd = <String, double>{
    'theme_pack': 2.99,
    'ringtone_pack': 1.99,
    'widget_pack': 3.99,
    'automations_pack': 4.99,
    'ifttt_pack': 3.99,
    'complete_pack': 9.99,
    'community_pack_10': 49.99,
    'community_pack_20': 79.99,
    'translation_pack': 2.99,
    'cloud_monthly': 2.99,
    'cloud_yearly': 24.99,
  };
}
