// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// The go-live switch in subscription_providers.dart routes every
// existing UI feature gate (hasFeatureProvider, hasPurchasedProvider,
// hasAllPremiumFeaturesProvider) through effectiveEntitlementsProvider.
//
// This test pins the merge contract so future refactors can't silently
// break it:
//
//   1. Store entitlements (RC) alone unlock features.
//   2. External entitlements alone unlock features.
//   3. Both sources merge — neither is dropped.
//   4. complete_pack from EITHER source expands to all 6 individual packs.
//   5. External entitlements never override or revoke a store entitlement.
//   6. The set returned is unmodifiable (callers can't accidentally mutate
//      the cache).

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/subscription_models.dart';
import 'package:socialmesh/providers/external_purchase_providers.dart';
import 'package:socialmesh/providers/subscription_providers.dart';

class _FakePurchaseStateNotifier extends Notifier<PurchaseState>
    implements PurchaseStateNotifier {
  final PurchaseState _initial;
  _FakePurchaseStateNotifier(this._initial);

  @override
  PurchaseState build() => _initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> debugAddPurchase(String productId) async {}

  @override
  Future<void> debugReset() async {}
}

ProviderContainer _container({
  required Set<String> storePurchases,
  required Set<String> externalPurchases,
}) {
  return ProviderContainer(
    overrides: [
      purchaseStateProvider.overrideWith(
        () => _FakePurchaseStateNotifier(
          PurchaseState(purchasedProductIds: storePurchases),
        ),
      ),
      externalEntitlementsProvider.overrideWith(
        (ref) async => externalPurchases,
      ),
    ],
  );
}

void main() {
  setUpAll(() {
    // RevenueCatConfig.themePackProductId and friends read these at
    // class-load time. Without dotenv the OneTimePurchases catalogue
    // is unbuildable, so the merge tests need to set up the same
    // env shape that subscription_models_test.dart uses.
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

  group('effectiveEntitlementsProvider — merge contract', () {
    test('store-only entitlement unlocks the feature', () async {
      final c = _container(
        storePurchases: {'theme_pack'},
        externalPurchases: {},
      );
      // Force the FutureProvider to resolve.
      await c.read(externalEntitlementsProvider.future);

      expect(c.read(effectiveEntitlementsProvider), contains('theme_pack'));
      expect(c.read(hasFeatureProvider(PremiumFeature.premiumThemes)), isTrue);
      expect(c.read(hasPurchasedProvider('theme_pack')), isTrue);
      c.dispose();
    });

    test('external-only entitlement unlocks the feature', () async {
      final c = _container(
        storePurchases: {},
        externalPurchases: {'widget_pack'},
      );
      await c.read(externalEntitlementsProvider.future);

      expect(c.read(effectiveEntitlementsProvider), contains('widget_pack'));
      expect(c.read(hasFeatureProvider(PremiumFeature.homeWidgets)), isTrue);
      c.dispose();
    });

    test('both sources merge — union, not intersection', () async {
      // The bug we're guarding against: if the merge ever flips to
      // intersection, a user who buys theme_pack on the App Store and
      // widget_pack via BMC would see neither unlocked.
      final c = _container(
        storePurchases: {'theme_pack'},
        externalPurchases: {'widget_pack'},
      );
      await c.read(externalEntitlementsProvider.future);

      final union = c.read(effectiveEntitlementsProvider);
      expect(union, containsAll({'theme_pack', 'widget_pack'}));
      c.dispose();
    });

    test('store complete_pack expands to all 6 individual packs', () async {
      final c = _container(
        storePurchases: {'complete_pack'},
        externalPurchases: {},
      );
      await c.read(externalEntitlementsProvider.future);

      final union = c.read(effectiveEntitlementsProvider);
      for (final p in OneTimePurchases.completePackPurchases) {
        expect(
          union,
          contains(p.productId),
          reason: 'complete_pack should imply ${p.productId}',
        );
      }
      expect(c.read(hasAllPremiumFeaturesProvider), isTrue);
      c.dispose();
    });

    test('external complete_pack expands to all 6 individual packs', () async {
      // Critical for the spec: "Complete Pack unlocks all packs" must
      // hold for the external pipeline as well as the store one.
      final c = _container(
        storePurchases: {},
        externalPurchases: {'complete_pack'},
      );
      await c.read(externalEntitlementsProvider.future);

      final union = c.read(effectiveEntitlementsProvider);
      for (final p in OneTimePurchases.completePackPurchases) {
        expect(union, contains(p.productId));
      }
      expect(c.read(hasAllPremiumFeaturesProvider), isTrue);
      c.dispose();
    });

    test('external entitlements never revoke a store entitlement', () async {
      // Even if the external set is empty (e.g. the user has no BMC
      // history), a store-purchased pack stays unlocked. The merge is
      // additive only.
      final c = _container(
        storePurchases: {'theme_pack', 'widget_pack'},
        externalPurchases: {},
      );
      await c.read(externalEntitlementsProvider.future);

      expect(c.read(hasPurchasedProvider('theme_pack')), isTrue);
      expect(c.read(hasPurchasedProvider('widget_pack')), isTrue);
      c.dispose();
    });

    test('returned set is unmodifiable', () async {
      final c = _container(
        storePurchases: {'theme_pack'},
        externalPurchases: {},
      );
      await c.read(externalEntitlementsProvider.future);

      final set = c.read(effectiveEntitlementsProvider);
      expect(
        () => set.add('hacker_pack'),
        throwsUnsupportedError,
        reason: 'callers must not mutate the merged set',
      );
      c.dispose();
    });

    test(
      'hasAllPremiumFeaturesProvider needs ALL packs OR complete_pack',
      () async {
        // Owning some but not all individual packs should NOT trigger
        // the "Authorised" badge.
        final c = _container(
          storePurchases: {'theme_pack', 'widget_pack'},
          externalPurchases: {'ringtone_pack'},
        );
        await c.read(externalEntitlementsProvider.future);

        expect(c.read(hasAllPremiumFeaturesProvider), isFalse);
        c.dispose();
      },
    );
  });
}
