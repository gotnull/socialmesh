import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/subscription_models.dart';

void main() {
  group('PremiumFeature', () {
    test('has all expected values', () {
      expect(
        PremiumFeature.values,
        containsAll([
          PremiumFeature.premiumThemes,
          PremiumFeature.customRingtones,
          PremiumFeature.homeWidgets,
          PremiumFeature.automations,
          PremiumFeature.iftttIntegration,
        ]),
      );
    });

    test('count is 5', () {
      expect(PremiumFeature.values.length, 5);
    });
  });

  group('OneTimePurchase', () {
    test('creates valid instance', () {
      const purchase = OneTimePurchase(
        id: 'test_id',
        name: 'Test Purchase',
        description: 'A test purchase',
        price: 1.99,
        productId: 'com.test.product',
        unlocksFeature: PremiumFeature.premiumThemes,
      );

      expect(purchase.id, 'test_id');
      expect(purchase.name, 'Test Purchase');
      expect(purchase.description, 'A test purchase');
      expect(purchase.price, 1.99);
      expect(purchase.productId, 'com.test.product');
      expect(purchase.unlocksFeature, PremiumFeature.premiumThemes);
    });
  });

  group('OneTimePurchases', () {
    test('themePack has correct properties', () {
      expect(OneTimePurchases.themePack.id, 'theme_pack');
      expect(OneTimePurchases.themePack.name, 'Theme Pack');
      expect(OneTimePurchases.themePack.price, 1.99);
      expect(
        OneTimePurchases.themePack.unlocksFeature,
        PremiumFeature.premiumThemes,
      );
    });

    test('ringtonePack has correct properties', () {
      expect(OneTimePurchases.ringtonePack.id, 'ringtone_pack');
      expect(OneTimePurchases.ringtonePack.name, 'Ringtone Pack');
      expect(OneTimePurchases.ringtonePack.price, 0.99);
      expect(
        OneTimePurchases.ringtonePack.unlocksFeature,
        PremiumFeature.customRingtones,
      );
    });

    test('widgetPack has correct properties', () {
      expect(OneTimePurchases.widgetPack.id, 'widget_pack');
      expect(OneTimePurchases.widgetPack.name, 'Widget Pack');
      expect(OneTimePurchases.widgetPack.price, 2.99);
      expect(
        OneTimePurchases.widgetPack.unlocksFeature,
        PremiumFeature.homeWidgets,
      );
    });

    test('automationsPack has correct properties', () {
      expect(OneTimePurchases.automationsPack.id, 'automations_pack');
      expect(OneTimePurchases.automationsPack.name, 'Automations');
      expect(OneTimePurchases.automationsPack.price, 3.99);
      expect(
        OneTimePurchases.automationsPack.unlocksFeature,
        PremiumFeature.automations,
      );
    });

    test('iftttPack has correct properties', () {
      expect(OneTimePurchases.iftttPack.id, 'ifttt_pack');
      expect(OneTimePurchases.iftttPack.name, 'IFTTT Integration');
      expect(OneTimePurchases.iftttPack.price, 2.99);
      expect(
        OneTimePurchases.iftttPack.unlocksFeature,
        PremiumFeature.iftttIntegration,
      );
    });

    test('allPurchases contains all purchases', () {
      expect(OneTimePurchases.allPurchases.length, 5);
      expect(
        OneTimePurchases.allPurchases,
        contains(OneTimePurchases.themePack),
      );
      expect(
        OneTimePurchases.allPurchases,
        contains(OneTimePurchases.ringtonePack),
      );
      expect(
        OneTimePurchases.allPurchases,
        contains(OneTimePurchases.widgetPack),
      );
      expect(
        OneTimePurchases.allPurchases,
        contains(OneTimePurchases.automationsPack),
      );
      expect(
        OneTimePurchases.allPurchases,
        contains(OneTimePurchases.iftttPack),
      );
    });

    test('getByProductId returns correct purchase', () {
      final themePack = OneTimePurchases.getByProductId(
        OneTimePurchases.themePack.productId,
      );
      expect(themePack, isNotNull);
      expect(themePack!.id, 'theme_pack');
    });

    test('getByProductId returns null for unknown product', () {
      final unknown = OneTimePurchases.getByProductId('unknown_product');
      expect(unknown, isNull);
    });

    test('getByFeature returns correct purchase', () {
      final themePack = OneTimePurchases.getByFeature(
        PremiumFeature.premiumThemes,
      );
      expect(themePack, isNotNull);
      expect(themePack!.id, 'theme_pack');

      final automations = OneTimePurchases.getByFeature(
        PremiumFeature.automations,
      );
      expect(automations, isNotNull);
      expect(automations!.id, 'automations_pack');
    });

    test('each feature has a corresponding purchase', () {
      for (final feature in PremiumFeature.values) {
        final purchase = OneTimePurchases.getByFeature(feature);
        expect(
          purchase,
          isNotNull,
          reason: 'Feature $feature should have a purchase',
        );
        expect(purchase!.unlocksFeature, feature);
      }
    });
  });

  group('PurchaseState', () {
    test('initial state has empty purchases and null customerId', () {
      const state = PurchaseState.initial;
      expect(state.purchasedProductIds, isEmpty);
      expect(state.customerId, isNull);
    });

    test('creates state with purchases', () {
      const state = PurchaseState(
        purchasedProductIds: {'product1', 'product2'},
        customerId: 'customer_123',
      );

      expect(state.purchasedProductIds, {'product1', 'product2'});
      expect(state.customerId, 'customer_123');
    });

    test('hasFeature returns true when feature is purchased', () {
      final productId = OneTimePurchases.themePack.productId;
      final state = PurchaseState(purchasedProductIds: {productId});

      expect(state.hasFeature(PremiumFeature.premiumThemes), isTrue);
      expect(state.hasFeature(PremiumFeature.automations), isFalse);
    });

    test('hasFeature returns false for initial state', () {
      const state = PurchaseState.initial;
      for (final feature in PremiumFeature.values) {
        expect(state.hasFeature(feature), isFalse);
      }
    });

    test('hasPurchased returns true for purchased product', () {
      const state = PurchaseState(
        purchasedProductIds: {'product1', 'product2'},
      );

      expect(state.hasPurchased('product1'), isTrue);
      expect(state.hasPurchased('product2'), isTrue);
      expect(state.hasPurchased('product3'), isFalse);
    });

    test('copyWith creates new state with updated values', () {
      const original = PurchaseState(
        purchasedProductIds: {'product1'},
        customerId: 'customer1',
      );

      final updated = original.copyWith(
        purchasedProductIds: {'product1', 'product2'},
      );

      expect(updated.purchasedProductIds, {'product1', 'product2'});
      expect(updated.customerId, 'customer1'); // Preserved

      final updatedCustomerId = original.copyWith(customerId: 'customer2');
      expect(updatedCustomerId.purchasedProductIds, {'product1'}); // Preserved
      expect(updatedCustomerId.customerId, 'customer2');
    });

    test('copyWith with no arguments returns equivalent state', () {
      const original = PurchaseState(
        purchasedProductIds: {'product1'},
        customerId: 'customer1',
      );

      final copy = original.copyWith();

      expect(copy.purchasedProductIds, original.purchasedProductIds);
      expect(copy.customerId, original.customerId);
    });

    test('multiple features can be purchased', () {
      final state = PurchaseState(
        purchasedProductIds: {
          OneTimePurchases.themePack.productId,
          OneTimePurchases.automationsPack.productId,
          OneTimePurchases.iftttPack.productId,
        },
      );

      expect(state.hasFeature(PremiumFeature.premiumThemes), isTrue);
      expect(state.hasFeature(PremiumFeature.automations), isTrue);
      expect(state.hasFeature(PremiumFeature.iftttIntegration), isTrue);
      expect(state.hasFeature(PremiumFeature.customRingtones), isFalse);
      expect(state.hasFeature(PremiumFeature.homeWidgets), isFalse);
    });
  });
}
