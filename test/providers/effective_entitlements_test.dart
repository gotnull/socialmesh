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
//   3. Both sources merge - neither is dropped.
//   4. complete_pack from EITHER source expands to all 6 individual packs.
//   5. External entitlements never override or revoke a store entitlement.
//   6. The set returned is unmodifiable (callers can't accidentally mutate
//      the cache).

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/subscription_models.dart';
import 'package:socialmesh/providers/external_purchase_providers.dart';
import 'package:socialmesh/providers/subscription_providers.dart';
import 'package:socialmesh/models/seat_allocation.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement.dart';
import 'package:socialmesh/services/external_purchase/external_entitlement_cache.dart';

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
      // Synchronous-ish stream: one event, then close. A live
      // subscriber on the StreamProvider receives the event on the
      // next event-loop tick; tests use `_pumpUntilData` to wait for
      // AsyncData to land before reading downstream providers.
      externalEntitlementsProvider.overrideWith(
        (ref) => Stream<Set<String>>.fromIterable([externalPurchases]),
      ),
    ],
  );
}

// Pump the event loop until `externalEntitlementsProvider` resolves
// to AsyncData. Riverpod 3's StreamProvider.future has flaky timing
// when overridden with synthetic streams in tests; an explicit
// listen() drives the stream subscription and the loop yields to the
// event queue until the AsyncValue carries data.
Future<void> _pumpUntilData(ProviderContainer c) async {
  final sub = c.listen<AsyncValue<Set<String>>>(
    externalEntitlementsProvider,
    (_, _) {},
    fireImmediately: true,
  );
  try {
    for (var i = 0; i < 20; i++) {
      if (sub.read().hasValue) return;
      await Future<void>.delayed(Duration.zero);
    }
    throw StateError(
      'externalEntitlementsProvider did not emit AsyncData within pump budget',
    );
  } finally {
    sub.close();
  }
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

  group('effectiveEntitlementsProvider - merge contract', () {
    test('store-only entitlement unlocks the feature', () async {
      final c = _container(
        storePurchases: {'theme_pack'},
        externalPurchases: {},
      );
      await _pumpUntilData(c);

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
      await _pumpUntilData(c);

      expect(c.read(effectiveEntitlementsProvider), contains('widget_pack'));
      expect(c.read(hasFeatureProvider(PremiumFeature.homeWidgets)), isTrue);
      c.dispose();
    });

    test('both sources merge - union, not intersection', () async {
      // The bug we're guarding against: if the merge ever flips to
      // intersection, a user who buys theme_pack on the App Store and
      // widget_pack via BMC would see neither unlocked.
      final c = _container(
        storePurchases: {'theme_pack'},
        externalPurchases: {'widget_pack'},
      );
      await _pumpUntilData(c);

      final union = c.read(effectiveEntitlementsProvider);
      expect(union, containsAll({'theme_pack', 'widget_pack'}));
      c.dispose();
    });

    test('store complete_pack expands to all 6 individual packs', () async {
      final c = _container(
        storePurchases: {'complete_pack'},
        externalPurchases: {},
      );
      await _pumpUntilData(c);

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
      await _pumpUntilData(c);

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
      await _pumpUntilData(c);

      expect(c.read(hasPurchasedProvider('theme_pack')), isTrue);
      expect(c.read(hasPurchasedProvider('widget_pack')), isTrue);
      c.dispose();
    });

    test('returned set is unmodifiable', () async {
      final c = _container(
        storePurchases: {'theme_pack'},
        externalPurchases: {},
      );
      await _pumpUntilData(c);

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
        await _pumpUntilData(c);

        expect(c.read(hasAllPremiumFeaturesProvider), isFalse);
        c.dispose();
      },
    );
  });

  group('effectiveEntitlementsProvider - ownership safety', () {
    // End-to-end assertion: an org-owned entitlement parsed from the
    // cache must not appear in the gate-feeding set, and therefore
    // must not unlock any premium feature. Future group/community
    // licensing will admit these rows only when a membership / seat
    // model says the current user qualifies. Until then, the cache
    // boundary fails closed.
    test(
      'org-owned cache rows never reach effectiveEntitlements (no membership)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cache = ExternalEntitlementCache(prefs);

        final ts = DateTime.parse('2026-05-05T10:00:00.000Z');
        await cache.write([
          ExternalEntitlement(
            productId: 'theme_pack',
            status: ExternalEntitlementStatus.active,
            provider: ExternalProvider.stripe,
            grantedAt: ts,
            lastVerifiedAt: ts,
            sessionId: 'sess-user',
          ),
          ExternalEntitlement(
            productId: 'widget_pack',
            status: ExternalEntitlementStatus.active,
            provider: ExternalProvider.stripe,
            grantedAt: ts,
            lastVerifiedAt: ts,
            sessionId: 'sess-org',
            ownerKind: OwnerKind.org,
            orgId: 'acme-eng-team',
          ),
        ]);

        final c = _container(
          storePurchases: const {},
          externalPurchases: cache.activeProductIds(),
        );
        await _pumpUntilData(c);

        final union = c.read(effectiveEntitlementsProvider);
        expect(union, contains('theme_pack'));
        expect(
          union,
          isNot(contains('widget_pack')),
          reason: 'org-owned widget_pack must not unlock without membership',
        );
        expect(c.read(hasPurchasedProvider('theme_pack')), isTrue);
        expect(c.read(hasPurchasedProvider('widget_pack')), isFalse);
        expect(c.read(hasFeatureProvider(PremiumFeature.homeWidgets)), isFalse);
        c.dispose();
      },
    );

    test(
      'mixed store + user external + org external: org row stays excluded',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cache = ExternalEntitlementCache(prefs);

        final ts = DateTime.parse('2026-05-05T10:00:00.000Z');
        await cache.write([
          ExternalEntitlement(
            productId: 'ringtone_pack',
            status: ExternalEntitlementStatus.active,
            provider: ExternalProvider.stripe,
            grantedAt: ts,
            lastVerifiedAt: ts,
            sessionId: 'sess-user',
          ),
          ExternalEntitlement(
            productId: 'automations_pack',
            status: ExternalEntitlementStatus.active,
            provider: ExternalProvider.stripe,
            grantedAt: ts,
            lastVerifiedAt: ts,
            sessionId: 'sess-org',
            ownerKind: OwnerKind.org,
            orgId: 'acme-eng-team',
          ),
        ]);

        final c = _container(
          storePurchases: {'theme_pack'},
          externalPurchases: cache.activeProductIds(),
        );
        await _pumpUntilData(c);

        final union = c.read(effectiveEntitlementsProvider);
        expect(union, containsAll({'theme_pack', 'ringtone_pack'}));
        expect(union, isNot(contains('automations_pack')));
      },
    );

    test(
      'membership + matching seat UNLOCKS the org-owned entitlement',
      () async {
        // Slice 3 load-bearing assertion: when the cache filter is fed
        // both ownedOrgIds AND a matching ownedSeats ref, the org row
        // makes it through to effectiveEntitlementsProvider and the
        // premium gate flips to true. This proves the end-to-end loop
        // (membership + seat -> unlock) without any change to the gate
        // call sites.
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cache = ExternalEntitlementCache(prefs);

        final ts = DateTime.parse('2026-05-05T10:00:00.000Z');
        await cache.write([
          ExternalEntitlement(
            productId: 'widget_pack',
            status: ExternalEntitlementStatus.active,
            provider: ExternalProvider.stripe,
            grantedAt: ts,
            lastVerifiedAt: ts,
            sessionId: 'sess-org',
            ownerKind: OwnerKind.org,
            orgId: 'acme-eng-team',
          ),
        ]);

        final filtered = cache.activeProductIds(
          ownedOrgIds: const {'acme-eng-team'},
          ownedSeats: {
            const SeatAllocationRef(
              orgId: 'acme-eng-team',
              productId: 'widget_pack',
            ),
          },
        );
        expect(filtered, {'widget_pack'});

        final c = _container(
          storePurchases: const {},
          externalPurchases: filtered,
        );
        await _pumpUntilData(c);

        final union = c.read(effectiveEntitlementsProvider);
        expect(union, contains('widget_pack'));
        expect(c.read(hasPurchasedProvider('widget_pack')), isTrue);
        expect(c.read(hasFeatureProvider(PremiumFeature.homeWidgets)), isTrue);
        c.dispose();
      },
    );

    test(
      'membership without matching seat still keeps the org row LOCKED',
      () async {
        // The companion to the unlock test: prove the loop is "AND",
        // not "OR". Even with full org membership, removing the seat
        // ref re-locks the entitlement.
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cache = ExternalEntitlementCache(prefs);

        final ts = DateTime.parse('2026-05-05T10:00:00.000Z');
        await cache.write([
          ExternalEntitlement(
            productId: 'widget_pack',
            status: ExternalEntitlementStatus.active,
            provider: ExternalProvider.stripe,
            grantedAt: ts,
            lastVerifiedAt: ts,
            sessionId: 'sess-org',
            ownerKind: OwnerKind.org,
            orgId: 'acme-eng-team',
          ),
        ]);

        final filtered = cache.activeProductIds(
          ownedOrgIds: const {'acme-eng-team'},
          // No seat refs - membership alone is insufficient.
        );
        expect(filtered, isEmpty);

        final c = _container(
          storePurchases: const {},
          externalPurchases: filtered,
        );
        await _pumpUntilData(c);

        expect(
          c.read(effectiveEntitlementsProvider),
          isNot(contains('widget_pack')),
        );
      },
    );
  });
}
