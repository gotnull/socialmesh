// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Pin the merge contract on the source-of-truth `PurchaseState` model
// that every UI widget reads.
//
// Why this test exists: chunk 2 wired `hasFeatureProvider` /
// `hasPurchasedProvider` through `effectiveEntitlementsProvider` to
// merge RevenueCat (store) purchases with external (BMC / unlock-code)
// entitlements. But the codebase has 30+ widget call sites that read
// the `PurchaseState` model DIRECTLY:
//
//   final purchaseState = ref.watch(purchaseStateProvider);
//   if (purchaseState.hasFeature(PremiumFeature.customRingtones)) ...
//
// Those sites bypassed the derived providers entirely and so missed
// every external entitlement. The drawer used `hasFeatureProvider` and
// showed Ringtone Pack unlocked; the subscription screen used
// `purchaseState.hasPurchased(...)` and showed it locked. Same user,
// inconsistent UI.
//
// Fix: merge external into the `PurchaseState` itself at the
// `PurchaseStateNotifier` boundary, so every consumer (provider-based
// AND direct-method-based) gets the union for free. This file pins
// that merge contract via the pure `mergePurchaseStateForTest`
// function so the two paths can never drift again.

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/subscription_models.dart';
import 'package:socialmesh/providers/subscription_providers.dart';

void main() {
  setUpAll(() {
    // RevenueCatConfig reads productId env vars at class-load time.
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

  group('mergePurchaseStateForTest', () {
    test('rc-only entitlement is preserved', () {
      // The original RC-only path must keep working unchanged. Any
      // user with a store purchase and no external entitlement
      // continues to see their store unlocks.
      final merged = mergePurchaseStateForTest(
        const PurchaseState(purchasedProductIds: {'theme_pack'}),
        const {},
      );
      expect(merged.purchasedProductIds, {'theme_pack'});
      expect(merged.hasFeature(PremiumFeature.premiumThemes), isTrue);
      expect(merged.hasPurchased('theme_pack'), isTrue);
    });

    test('external-only entitlement appears in the merged state', () {
      // The bug we just fixed. Drawer used the providers (worked);
      // every direct purchaseState.hasPurchased(...) call missed it.
      // After the merge, both paths see the unlock.
      final merged = mergePurchaseStateForTest(const PurchaseState(), {
        'ringtone_pack',
      });
      expect(merged.purchasedProductIds, {'ringtone_pack'});
      expect(merged.hasFeature(PremiumFeature.customRingtones), isTrue);
      expect(merged.hasPurchased('ringtone_pack'), isTrue);
    });

    test('rc + external merge — union, not intersection', () {
      // If a future refactor flips the merge to intersection, a user
      // with store-purchased theme_pack and external-purchased
      // widget_pack would see neither — silent regression. Pin the
      // semantics here.
      final merged = mergePurchaseStateForTest(
        const PurchaseState(purchasedProductIds: {'theme_pack'}),
        {'widget_pack'},
      );
      expect(
        merged.purchasedProductIds,
        containsAll({'theme_pack', 'widget_pack'}),
      );
      expect(merged.hasFeature(PremiumFeature.premiumThemes), isTrue);
      expect(merged.hasFeature(PremiumFeature.homeWidgets), isTrue);
    });

    test('store complete_pack expands to all 6 individual packs', () {
      final merged = mergePurchaseStateForTest(
        const PurchaseState(purchasedProductIds: {'complete_pack'}),
        const {},
      );
      for (final p in OneTimePurchases.completePackPurchases) {
        expect(
          merged.purchasedProductIds,
          contains(p.productId),
          reason: 'complete_pack should imply ${p.productId}',
        );
      }
    });

    test('external complete_pack expands to all bundled individual packs', () {
      // Mirror of the previous test for the external pipeline. Without
      // expansion at the merge, a complete_pack-via-BMC user would only
      // unlock the literal complete_pack id and miss the bundled packs.
      // Note: the translation pack has been retired from the catalog
      // and is intentionally NOT bundled into complete_pack; the test
      // covers only the features that ARE in the current bundle.
      final merged = mergePurchaseStateForTest(const PurchaseState(), {
        'complete_pack',
      });
      for (final p in OneTimePurchases.completePackPurchases) {
        expect(merged.purchasedProductIds, contains(p.productId));
      }
      expect(merged.hasFeature(PremiumFeature.customRingtones), isTrue);
    });

    test('external never overrides — additive only', () {
      // Empty external set must NOT clear store entitlements. The
      // merge is union, so adding an empty set is a no-op.
      final merged = mergePurchaseStateForTest(
        const PurchaseState(purchasedProductIds: {'theme_pack', 'widget_pack'}),
        const {},
      );
      expect(merged.hasPurchased('theme_pack'), isTrue);
      expect(merged.hasPurchased('widget_pack'), isTrue);
    });

    test('reproduces the live bug: anonymous user with external ringtone_pack '
        'only — `hasFeature(customRingtones)` must return true', () {
      // The exact case from logs.txt: no RC purchases (anon user, no
      // store CTAs ever tapped), one external entitlement
      // `ringtone_pack` from an unlock code. Before the merge fix
      // this returned false, drawer showed unlocked, subscription
      // screen showed locked. After the fix both surfaces agree.
      final merged = mergePurchaseStateForTest(const PurchaseState(), {
        'ringtone_pack',
      });
      expect(merged.hasFeature(PremiumFeature.customRingtones), isTrue);
      expect(merged.hasPurchased('ringtone_pack'), isTrue);
    });

    test('preserves the rc state customerId field', () {
      // copyWith sanity — only purchasedProductIds should be merged;
      // customerId (and any future RC-side metadata) survives.
      final merged = mergePurchaseStateForTest(
        const PurchaseState(
          purchasedProductIds: {'theme_pack'},
          customerId: 'rc-customer-abc',
        ),
        {'widget_pack'},
      );
      expect(merged.customerId, 'rc-customer-abc');
    });
  });
}
