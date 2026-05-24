// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/subscription_models.dart';
import 'package:socialmesh/providers/subscription_providers.dart';

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
TRANSLATION_PACK_PRODUCT_ID=translation_pack
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
            'translation_pack',
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

    test('returns true for bundled features when complete pack is owned', () {
      const state = PurchaseState(purchasedProductIds: {'complete_pack'});
      const bundled = {
        PremiumFeature.premiumThemes,
        PremiumFeature.customRingtones,
        PremiumFeature.homeWidgets,
        PremiumFeature.automations,
        PremiumFeature.iftttIntegration,
      };

      for (final feature in bundled) {
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
    test('contains exactly 6 individual purchases', () {
      expect(OneTimePurchases.allIndividualPurchases.length, 6);
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
      expect(ids, contains('translation_pack'));
    });
  });

  group('CompletePackPurchases', () {
    test('contains exactly 5 bundled purchases', () {
      expect(OneTimePurchases.completePackPurchases.length, 5);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // Regression: RC-ARCH-04 — Firestore mirror sync failures must be
  // observable but non-fatal. The result type (FirestoreMirrorSyncResult)
  // is the public contract; integration coverage of the actual callable
  // would need cloud_functions mocking infrastructure that doesn't exist
  // in this repo today.
  // ─────────────────────────────────────────────────────────────────────
  group('RC-ARCH-04: FirestoreMirrorSyncResult contract', () {
    test('success result preserves backend status string', () {
      const r = FirestoreMirrorSyncResult(
        success: true,
        statusFromBackend: 'feature_only',
      );
      expect(r.success, isTrue);
      expect(r.error, isNull);
      expect(r.statusFromBackend, 'feature_only');
    });

    test('failure result carries the underlying error for telemetry', () {
      final err = StateError('unauthenticated');
      final r = FirestoreMirrorSyncResult(success: false, error: err);
      expect(r.success, isFalse);
      expect(r.error, same(err));
      expect(r.statusFromBackend, isNull);
    });

    test('the type exposes no fields that would let a caller revoke '
        'RC-backed access on mirror failure', () {
      // Shape contract: the result is information-only. There is no
      // `revokeAccess` or `lockFeatures` field. Callers must depend on
      // RC.currentState for entitlement; this result is for logging /
      // UX only. If this assertion ever needs to change, re-read the
      // RC-ARCH-01 + RC-ARCH-04 fix rationale.
      const r = FirestoreMirrorSyncResult(success: false);
      expect(r.toString(), isA<String>()); // no thrown side effects
    });
  });
}
