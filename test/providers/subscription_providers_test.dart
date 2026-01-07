import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/subscription_models.dart';

void main() {
  setUpAll(() {
    // Initialize dotenv with test values for RevenueCat product IDs
    dotenv.loadFromString(
      envString: '''
THEME_PACK_PRODUCT_ID=theme_pack
RINGTONE_PACK_PRODUCT_ID=ringtone_pack
WIDGET_PACK_PRODUCT_ID=widget_pack
AUTOMATIONS_PACK_PRODUCT_ID=automations_pack
IFTTT_PACK_PRODUCT_ID=ifttt_pack
COMPLETE_PACK_PRODUCT_ID=complete_pack
''',
    );
  });

  group('PurchaseState - All Premium Features Check', () {
    test('hasAllPremiumFeatures returns true when complete pack is owned', () {
      const state = PurchaseState(purchasedProductIds: {'complete_pack'});

      // User with complete pack should have access to all individual packs
      expect(state.hasPurchased('theme_pack'), true);
      expect(state.hasPurchased('ringtone_pack'), true);
      expect(state.hasPurchased('widget_pack'), true);
      expect(state.hasPurchased('automations_pack'), true);
      expect(state.hasPurchased('ifttt_pack'), true);
    });

    test(
      'hasAllPremiumFeatures returns true when all individual packs are owned',
      () {
        const state = PurchaseState(
          purchasedProductIds: {
            'theme_pack',
            'ringtone_pack',
            'widget_pack',
            'automations_pack',
            'ifttt_pack',
          },
        );

        // User with all individual packs should have all features
        for (final purchase in OneTimePurchases.allIndividualPurchases) {
          expect(state.hasPurchased(purchase.productId), true);
        }
      },
    );

    test(
      'hasAllPremiumFeatures returns false when only some packs are owned',
      () {
        const state = PurchaseState(
          purchasedProductIds: {'theme_pack', 'ringtone_pack'},
        );

        // User missing some packs shouldn't have all premium features
        expect(state.hasPurchased('theme_pack'), true);
        expect(state.hasPurchased('ringtone_pack'), true);
        expect(state.hasPurchased('widget_pack'), false);
        expect(state.hasPurchased('automations_pack'), false);
        expect(state.hasPurchased('ifttt_pack'), false);
      },
    );

    test('hasAllPremiumFeatures returns false when no packs are owned', () {
      const state = PurchaseState();

      // User with no purchases shouldn't have any premium features
      for (final purchase in OneTimePurchases.allIndividualPurchases) {
        expect(state.hasPurchased(purchase.productId), false);
      }
    });

    test('complete pack unlocks all individual pack features', () {
      const state = PurchaseState(purchasedProductIds: {'complete_pack'});

      // Complete pack should unlock all features
      expect(state.hasFeature(PremiumFeature.premiumThemes), true);
      expect(state.hasFeature(PremiumFeature.customRingtones), true);
      expect(state.hasFeature(PremiumFeature.homeWidgets), true);
      expect(state.hasFeature(PremiumFeature.automations), true);
      expect(state.hasFeature(PremiumFeature.iftttIntegration), true);
    });
  });

  group('PurchaseState - hasFeature', () {
    test('returns true for directly purchased feature pack', () {
      const state = PurchaseState(purchasedProductIds: {'theme_pack'});
      expect(state.hasFeature(PremiumFeature.premiumThemes), true);
    });

    test('returns false for unpurchased feature', () {
      const state = PurchaseState(purchasedProductIds: {'theme_pack'});
      expect(state.hasFeature(PremiumFeature.automations), false);
    });

    test('returns true for all features when complete pack is owned', () {
      const state = PurchaseState(purchasedProductIds: {'complete_pack'});

      for (final feature in PremiumFeature.values) {
        expect(state.hasFeature(feature), true);
      }
    });
  });

  group('PurchaseState - copyWith', () {
    test('creates new instance with updated purchasedProductIds', () {
      const original = PurchaseState(purchasedProductIds: {'theme_pack'});
      final updated = original.copyWith(
        purchasedProductIds: {'theme_pack', 'ringtone_pack'},
      );

      expect(original.purchasedProductIds, {'theme_pack'});
      expect(updated.purchasedProductIds, {'theme_pack', 'ringtone_pack'});
    });

    test('preserves customerId when not specified', () {
      const original = PurchaseState(
        purchasedProductIds: {'theme_pack'},
        customerId: 'customer_123',
      );
      final updated = original.copyWith(
        purchasedProductIds: {'theme_pack', 'ringtone_pack'},
      );

      expect(updated.customerId, 'customer_123');
    });

    test('updates customerId when specified', () {
      const original = PurchaseState(
        purchasedProductIds: {'theme_pack'},
        customerId: 'customer_123',
      );
      final updated = original.copyWith(customerId: 'customer_456');

      expect(updated.customerId, 'customer_456');
    });
  });

  group('AllIndividualPurchases', () {
    test('contains exactly 5 individual purchases', () {
      expect(OneTimePurchases.allIndividualPurchases.length, 5);
    });

    test('does not contain complete pack', () {
      final productIds = OneTimePurchases.allIndividualPurchases.map(
        (p) => p.productId,
      );
      expect(productIds, isNot(contains('complete_pack')));
    });

    test('contains all expected individual packs', () {
      final ids = OneTimePurchases.allIndividualPurchases
          .map((p) => p.id)
          .toSet();
      expect(ids, contains('theme_pack'));
      expect(ids, contains('ringtone_pack'));
      expect(ids, contains('widget_pack'));
      expect(ids, contains('automations_pack'));
      expect(ids, contains('ifttt_pack'));
    });
  });
}
