// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Riverpod wiring for the external (fallback) purchase pipeline.
//
// Provider graph (read top-down):
//
//   externalPurchaseServiceProvider     ← service singleton
//        ↓
//   externalEntitlementsProvider        ← Set<String> active product ids,
//                                          backed by SharedPreferences cache
//        ↓
//   effectiveEntitlementsProvider       ← merge(store, external)
//        ↓
//   subscription_providers.dart's
//   hasFeatureProvider / hasPurchasedProvider
//
// The merge in [effectiveEntitlementsProvider] is the single point
// where store and external entitlements meet. UI never reads either
// source directly — it always goes through the merge. This guarantees
// a unified semantic for "is this pack unlocked?" even after we add
// future entitlement sources (Stripe, NOWPayments, manual codes).

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../models/subscription_models.dart';
import '../services/external_purchase/external_entitlement_cache.dart';
import '../services/external_purchase/external_purchase_service.dart';
import 'subscription_providers.dart';

/// Singleton ExternalPurchaseService. Disposes the underlying service
/// (closes its broadcast stream and cancels any in-flight polling
/// timer) on container teardown.
final externalPurchaseServiceProvider = FutureProvider<ExternalPurchaseService>(
  (ref) async {
    final prefs = await ref.watch(sharedPreferencesProvider.future);
    final cache = ExternalEntitlementCache(prefs);
    final service = ExternalPurchaseService(prefs: prefs, cache: cache);
    ref.onDispose(() {
      AppLogging.purchase('[ProviderGraph] disposing ExternalPurchaseService');
      unawaited(service.dispose());
    });
    AppLogging.purchase('[ProviderGraph] ExternalPurchaseService created');
    return service;
  },
);

/// Stream of confirmation states, used by the post-redirect overlay
/// (chunk 3 wires this into the UI). Never throws — the broadcast
/// stream's only error path is `dispose()`.
final externalConfirmationStreamProvider = StreamProvider<ConfirmationState>((
  ref,
) async* {
  final service = await ref.watch(externalPurchaseServiceProvider.future);
  yield service.currentConfirmation;
  yield* service.confirmationStream;
});

/// Set of currently-active external product ids.
///
/// First emission is the on-disk cache (offline-first contract).
/// Then a network refresh runs and re-emits if anything changed.
/// A network failure leaves the cache emission as the steady state.
final externalEntitlementsProvider = FutureProvider<Set<String>>((ref) async {
  final service = await ref.watch(externalPurchaseServiceProvider.future);
  // Surface the cached set immediately so the UI doesn't flash to
  // "locked" on cold start while the network refresh is in flight.
  // The cache is loaded synchronously from SharedPreferences — no IO.
  final cached = service.cachedActiveProductIds;
  // Fire-and-forget refresh in the background. The provider returns
  // the cache result; downstream invalidation by `refreshExternalEntitlements`
  // re-runs this builder if the network result changes.
  unawaited(
    service.refreshEntitlements().then((entitlements) {
      // Compare the active set against what we just emitted; if the
      // network said something different, invalidate so consumers
      // see the fresh truth.
      final freshActive = entitlements
          .where((e) => e.isActive)
          .map((e) => e.productId)
          .toSet();
      if (!_setEquals(freshActive, cached)) {
        AppLogging.purchase(
          '[ProviderGraph] external entitlements drift '
          'cached=$cached fresh=$freshActive — invalidating',
        );
        ref.invalidateSelf();
      }
    }),
  );
  return cached;
});

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final v in a) {
    if (!b.contains(v)) return false;
  }
  return true;
}

/// Family checker for "has this pack via the external pipeline?".
///
/// UI should NEVER read this directly — the canonical entry point is
/// [hasFeatureProvider] / [hasPurchasedProvider] in
/// `subscription_providers.dart`, which merge across all entitlement
/// sources via [effectiveEntitlementsProvider]. This family exists
/// for diagnostics and admin tooling.
final hasExternalEntitlementProvider = Provider.family<bool, String>((
  ref,
  productId,
) {
  final asyncSet = ref.watch(externalEntitlementsProvider);
  return asyncSet.maybeWhen(
    data: (set) => set.contains(productId),
    orElse: () => false,
  );
});

/// Effective set of unlocked product ids from ALL sources.
///
/// This is the single merge point. Adding a new entitlement source
/// (Stripe, NOWPayments, future webhook providers) means extending
/// the union here — UI gates require zero changes.
///
/// Bundle expansion: if the merge contains `complete_pack`, the six
/// individual packs are implicitly unlocked too. We expand here so
/// callers can do a flat `set.contains(productId)` check.
final effectiveEntitlementsProvider = Provider<Set<String>>((ref) {
  final storeState = ref.watch(purchaseStateProvider);
  final externalAsync = ref.watch(externalEntitlementsProvider);
  final external = externalAsync.maybeWhen(
    data: (set) => set,
    orElse: () => const <String>{},
  );

  final union = <String>{...storeState.purchasedProductIds, ...external};

  // Bundle expansion: complete_pack implies all individual packs.
  final completeId = OneTimePurchases.completePackPurchases.isEmpty
      ? null
      : 'complete_pack';
  if (completeId != null && union.contains(completeId)) {
    for (final p in OneTimePurchases.completePackPurchases) {
      union.add(p.productId);
    }
  }

  return Set.unmodifiable(union);
});

/// Convenience family: is the supplied product id unlocked by any
/// path? Use this in feature-gated widgets.
final hasEffectiveEntitlementProvider = Provider.family<bool, String>((
  ref,
  productId,
) {
  final union = ref.watch(effectiveEntitlementsProvider);
  return union.contains(productId);
});

/// Imperative refresh hook for the UI's "checking now" affordances.
/// Returns the freshly-loaded entitlement set (or the cache on
/// network failure — never throws).
Future<Set<String>> refreshExternalEntitlements(WidgetRef ref) async {
  AppLogging.purchase('[ProviderGraph] refreshExternalEntitlements requested');
  final service = await ref.read(externalPurchaseServiceProvider.future);
  final list = await service.refreshEntitlements();
  ref.invalidate(externalEntitlementsProvider);
  return list.where((e) => e.isActive).map((e) => e.productId).toSet();
}
