// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide PurchaseResult;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/constants.dart';
import 'package:socialmesh/core/logging.dart';
import '../config/revenuecat_config.dart';
import '../models/subscription_models.dart';
import '../services/subscription/subscription_service.dart';
import 'external_purchase_providers.dart';

/// Shared preferences provider - initialized at app start
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return SharedPreferences.getInstance();
});

/// Purchase service singleton provider
final subscriptionServiceProvider = FutureProvider<PurchaseService>((
  ref,
) async {
  final service = PurchaseService();
  // Configure RevenueCat directly under the Firebase UID when one is already
  // available. This avoids the "configure anonymous → logIn(uid)" hop that
  // creates a fresh alias edge on every cold start and eventually saturates
  // RC's per-user alias chain (error code 23).
  final appUserId = FirebaseAuth.instance.currentUser?.uid;
  await service.initialize(appUserId: appUserId);
  return service;
});

/// Current purchase state - auto-refreshes from service
final purchaseStateProvider =
    NotifierProvider<PurchaseStateNotifier, PurchaseState>(
      PurchaseStateNotifier.new,
    );

/// State holder that merges RevenueCat (store) purchases with external
/// (BMC / unlock-code) entitlements into a single [PurchaseState].
///
/// Why the merge happens HERE instead of just in the derived providers
/// (`hasFeatureProvider`, `hasPurchasedProvider`, `effectiveEntitlementsProvider`):
/// the codebase has 30+ widget call sites that read the model directly
/// — `purchaseState.hasFeature(feature)` / `purchaseState.hasPurchased(productId)`
/// — bypassing the derived providers. Merging at the source ensures every
/// consumer (provider-based AND direct-method-based) sees the same
/// unified entitlement set without sweeping every call site.
///
/// Bundle expansion is also done here: when the merged set contains
/// `complete_pack`, all six individual pack ids are added too. Single
/// source of truth keeps `effectiveEntitlementsProvider` and the model
/// methods in agreement.
class PurchaseStateNotifier extends Notifier<PurchaseState> {
  StreamSubscription<PurchaseState>? _subscription;

  /// Latest snapshot from the RevenueCat / store service. Kept private
  /// so `state` always reflects the *merged* view downstream consumers
  /// expect.
  PurchaseState _rcState = PurchaseState.initial;

  /// Latest snapshot of external (install-keyed) entitlements,
  /// supplied by [externalEntitlementsProvider] via `ref.listen`.
  Set<String> _external = const {};

  @override
  PurchaseState build() {
    AppLogging.subscriptions('💳 [PurchaseStateNotifier] build() called');

    ref.onDispose(() {
      AppLogging.subscriptions(
        '💳 [PurchaseStateNotifier] onDispose - cancelling stream subscription',
      );
      _subscription?.cancel();
      _subscription = null;
    });

    // External (Stripe / BMC / unlock-code) entitlement merge: on
    // when any external provider is enabled. When all external flags
    // are off we skip the listen + initial read entirely so the
    // FutureProvider's network fetch never fires AND no external
    // product ids leak into the merged state. `_external` stays at
    // its initial empty value, so `_computeMerged()` returns an
    // RC-only PurchaseState exactly as the legacy code did before
    // chunk 2 shipped.
    if (AppFeatureFlags.isExternalPurchaseEnabled) {
      // Side-effect: when external entitlements change (cache loaded,
      // unlock-code redeemed, BMC webhook landed), recompute the merged
      // state so every direct purchaseState consumer sees the new union
      // immediately. `ref.listen` is the right tool here per the
      // providers/CLAUDE.md guidance ("side effects use ref.listen").
      ref.listen<AsyncValue<Set<String>>>(externalEntitlementsProvider, (
        previous,
        next,
      ) {
        final newExternal = next.maybeWhen(
          data: (set) => set,
          orElse: () => const <String>{},
        );
        if (_setEquals(newExternal, _external)) return;
        _external = newExternal;
        AppLogging.subscriptions(
          '💳 [PurchaseStateNotifier] external entitlements changed: $_external',
        );
        state = _computeMerged();
      });

      // Initial read of external — may be AsyncLoading at first call.
      _external = ref
          .read(externalEntitlementsProvider)
          .maybeWhen(data: (set) => set, orElse: () => const <String>{});
    } else {
      AppLogging.subscriptions(
        '💳 [PurchaseStateNotifier] external purchase feature flag OFF — '
        'skipping external entitlement merge',
      );
    }

    _init();
    return _computeMerged();
  }

  PurchaseState _computeMerged() =>
      mergePurchaseStateForTest(_rcState, _external);

  Future<void> _init() async {
    AppLogging.subscriptions('💳 [PurchaseStateNotifier] _init() starting...');
    final service = await ref.read(subscriptionServiceProvider.future);
    if (!ref.mounted) {
      AppLogging.subscriptions(
        '💳 [PurchaseStateNotifier] Not mounted after await, skipping init',
      );
      return;
    }
    _rcState = service.currentState;
    AppLogging.subscriptions(
      '💳 [PurchaseStateNotifier] Initial RC state: ${_rcState.purchasedProductIds}',
    );
    if (_rcState.purchasedProductIds.isNotEmpty) {
      AppLogging.purchase(
        'WIDGET_GATE: restored entitlement source=revenuecat '
        'productIds=${_rcState.purchasedProductIds}',
      );
    }
    state = _computeMerged();

    AppLogging.subscriptions(
      '💳 [PurchaseStateNotifier] Setting up stateStream listener...',
    );
    _subscription = service.stateStream.listen(
      (newState) {
        if (!ref.mounted) {
          AppLogging.subscriptions(
            '💳 [PurchaseStateNotifier] Not mounted, ignoring stream update',
          );
          return;
        }
        AppLogging.subscriptions(
          '💳 [PurchaseStateNotifier] Stream received new RC state: ${newState.purchasedProductIds}',
        );
        _rcState = newState;
        state = _computeMerged();
      },
      onError: (e) {
        AppLogging.subscriptions('💳 [PurchaseStateNotifier] Stream error: $e');
      },
    );
    AppLogging.subscriptions('💳 [PurchaseStateNotifier] _init() complete');
  }

  /// Refresh purchases from RevenueCat
  Future<void> refresh() async {
    AppLogging.subscriptions('💳 [PurchaseStateNotifier] refresh() called');
    final service = await ref.read(subscriptionServiceProvider.future);
    await service.refreshPurchases();

    if (!ref.mounted) {
      AppLogging.subscriptions(
        '💳 [PurchaseStateNotifier] Not mounted after refresh, skipping state update',
      );
      return;
    }
    _rcState = service.currentState;
    AppLogging.subscriptions(
      '💳 [PurchaseStateNotifier] refresh() setting RC state: ${_rcState.purchasedProductIds}',
    );
    state = _computeMerged();
  }

  /// For debug/testing - add purchase
  Future<void> debugAddPurchase(String productId) async {
    final service = await ref.read(subscriptionServiceProvider.future);
    await service.debugAddPurchase(productId);
    _rcState = service.currentState;
    state = _computeMerged();
  }

  /// For debug/testing - reset purchases
  Future<void> debugReset() async {
    final service = await ref.read(subscriptionServiceProvider.future);
    await service.debugReset();
    _rcState = service.currentState;
    state = _computeMerged();
  }
}

bool _setEquals<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  for (final v in a) {
    if (!b.contains(v)) return false;
  }
  return true;
}

/// Pure merge function. Combines RevenueCat purchasedProductIds with
/// external entitlements and applies bundle expansion (complete_pack
/// implies all six individual packs).
///
/// Exposed for testing so the merge contract can be pinned without
/// booting the full Notifier + service stack. Both
/// [PurchaseStateNotifier._computeMerged] and the test suite call this
/// directly — keeps the two in lockstep.
@visibleForTesting
PurchaseState mergePurchaseStateForTest(
  PurchaseState rc,
  Set<String> external,
) {
  final union = <String>{...rc.purchasedProductIds, ...external};
  if (union.contains(RevenueCatConfig.completePackProductId)) {
    for (final p in OneTimePurchases.completePackPurchases) {
      union.add(p.productId);
    }
  }
  return rc.copyWith(purchasedProductIds: union);
}

/// Check if a specific feature is available.
///
/// Reads through [effectiveEntitlementsProvider], which merges:
///   - App Store / Play Store / RevenueCat entitlements
///   - External (Buy Me a Coffee / unlock-code) entitlements
///   - Bundle expansion: complete_pack implies all individual packs
///
/// UI gates depend on this provider directly. Adding a new entitlement
/// source means extending the merge in [effectiveEntitlementsProvider]
/// — no changes are needed here.
final hasFeatureProvider = Provider.family<bool, PremiumFeature>((
  ref,
  feature,
) {
  final purchase = OneTimePurchases.getByFeature(feature);
  if (purchase == null) return false;
  final union = ref.watch(effectiveEntitlementsProvider);
  return union.contains(purchase.productId);
});

/// Check if a specific product has been purchased (via any source).
///
/// See [hasFeatureProvider] for the merge contract.
final hasPurchasedProvider = Provider.family<bool, String>((ref, productId) {
  final union = ref.watch(effectiveEntitlementsProvider);
  return union.contains(productId);
});

/// Check if user has all premium features unlocked (owns complete pack OR all individual packs).
/// Users with all premium features get an "Authorised" badge.
///
/// Walks the same merged entitlement set as [hasFeatureProvider], so
/// external unlocks count toward the badge.
final hasAllPremiumFeaturesProvider = Provider<bool>((ref) {
  final union = ref.watch(effectiveEntitlementsProvider);
  if (union.contains(RevenueCatConfig.completePackProductId)) {
    return true;
  }
  for (final purchase in OneTimePurchases.completePackPurchases) {
    if (!union.contains(purchase.productId)) {
      return false;
    }
  }
  return true;
});

/// Notifier for subscription loading state
class SubscriptionLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setLoading(bool value) => state = value;
}

/// Purchase loading state for async operations
final subscriptionLoadingProvider =
    NotifierProvider<SubscriptionLoadingNotifier, bool>(
      SubscriptionLoadingNotifier.new,
    );

/// Notifier for subscription error state
class SubscriptionErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String? error) => state = error;
  void clear() => state = null;
}

/// Purchase error state
final subscriptionErrorProvider =
    NotifierProvider<SubscriptionErrorNotifier, String?>(
      SubscriptionErrorNotifier.new,
    );

/// Purchase a one-time product
/// Returns PurchaseResult indicating success, cancellation, or error
Future<PurchaseResult> purchaseProduct(WidgetRef ref, String productId) async {
  AppLogging.subscriptions(
    '💳 [PurchaseProduct] Starting purchase for: $productId',
  );

  // Capture notifier references up front. WidgetRef becomes invalid when the
  // calling widget unmounts (e.g. sheet dismissed mid-purchase), but the
  // underlying notifiers live in the ProviderContainer and survive — so the
  // finally block can always clear loading state.
  final SubscriptionLoadingNotifier loadingNotifier;
  final SubscriptionErrorNotifier errorNotifier;
  try {
    loadingNotifier = ref.read(subscriptionLoadingProvider.notifier);
    errorNotifier = ref.read(subscriptionErrorProvider.notifier);
  } catch (_) {
    return PurchaseResult.error;
  }

  loadingNotifier.setLoading(true);
  errorNotifier.clear();

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    AppLogging.subscriptions(
      '💳 [PurchaseProduct] Calling service.purchaseProduct...',
    );
    final result = await service.purchaseProduct(productId);
    AppLogging.subscriptions('💳 [PurchaseProduct] Result: $result');

    if (result == PurchaseResult.success) {
      AppLogging.subscriptions(
        '💳 [PurchaseProduct] Success! Refreshing purchase state notifier...',
      );
      try {
        // Await the refresh to ensure state is updated before returning
        await ref.read(purchaseStateProvider.notifier).refresh();
        AppLogging.subscriptions('💳 [PurchaseProduct] Refresh complete');

        // Double-check the state
        final state = ref.read(purchaseStateProvider);
        AppLogging.subscriptions(
          '💳 [PurchaseProduct] Final state: ${state.purchasedProductIds}',
        );
      } catch (_) {
        // ref may be disposed if the calling widget was unmounted during purchase
        AppLogging.subscriptions(
          '💳 [PurchaseProduct] Widget unmounted during purchase — skipping state refresh',
        );
      }
    }
    return result;
  } catch (e) {
    AppLogging.subscriptions('💳 [PurchaseProduct] Error: $e');
    errorNotifier.setError(e.toString());
    return PurchaseResult.error;
  } finally {
    loadingNotifier.setLoading(false);
  }
}

/// Restore purchases
/// On iOS, this queries the App Store for purchases tied to the current Apple ID.
/// On Android, this queries Google Play for purchases tied to the current Google account.
/// Firebase sign-in is optional but recommended for cross-device purchase syncing.
Future<bool> restorePurchases(WidgetRef ref) async {
  AppLogging.subscriptions(
    '💳 [RestorePurchases] ═══════════════════════════════════════════════',
  );
  AppLogging.subscriptions('💳 [RestorePurchases] Provider function called');

  // Capture notifier references up front — see purchaseProduct for rationale.
  final SubscriptionLoadingNotifier loadingNotifier;
  final SubscriptionErrorNotifier errorNotifier;
  try {
    loadingNotifier = ref.read(subscriptionLoadingProvider.notifier);
    errorNotifier = ref.read(subscriptionErrorProvider.notifier);
  } catch (_) {
    return false;
  }

  AppLogging.subscriptions(
    '💳 [RestorePurchases] Setting loading state to true',
  );
  loadingNotifier.setLoading(true);
  errorNotifier.clear();

  try {
    AppLogging.subscriptions(
      '💳 [RestorePurchases] Getting subscription service...',
    );
    final service = await ref.read(subscriptionServiceProvider.future);
    AppLogging.subscriptions(
      '💳 [RestorePurchases] Service obtained, isInitialized: ${service.isInitialized}',
    );

    // Capture state BEFORE restore to compare later
    final stateBefore = ref.read(purchaseStateProvider);
    final purchaseCountBefore = stateBefore.purchasedProductIds.length;
    AppLogging.subscriptions(
      '💳 [RestorePurchases] State BEFORE restore: ${stateBefore.purchasedProductIds} (count: $purchaseCountBefore)',
    );

    AppLogging.subscriptions('💳 [RestorePurchases] Calling restorePurchases');
    await service.restorePurchases();
    AppLogging.subscriptions('💳 [RestorePurchases] Restore completed');

    // Mirror restored purchases into Firestore so the admin panel and the
    // cloud-sync entitlement service see them. Skipped when signed out —
    // there's no Firestore document to mirror into. Non-fatal: a failure
    // here MUST NOT revoke RC-backed access (RC is the source of truth).
    // The result is logged with a stable MIRROR_SYNC_FAILED prefix on
    // failure so it is observable without crashing the restore flow.
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      await _syncPurchasesToFirestoreSafe('RestorePurchases');
    } else {
      AppLogging.subscriptions(
        '💳 [RestorePurchases] No Firebase user — skipping Firestore mirror',
      );
    }

    // Also restore Stripe / external entitlements. This runs the
    // device-to-account claim (idempotent, no-op for anonymous users)
    // and then refreshes the external entitlement cache so any
    // entitlements already bound to the signed-in account on this OR
    // a previous install surface in the merged purchase state.
    try {
      final externalService = await ref.read(
        externalPurchaseServiceProvider.future,
      );
      // Bind any install-scoped entitlements on this device to the
      // signed-in account. Backend handles the unauthenticated case
      // by returning empty (the method itself swallows errors).
      await externalService.claimEntitlementsToAccount();
      // Pull the union of install + uid entitlements from Firestore.
      // After a claim or a cross-device sign-in, this is where Stripe
      // purchases land in the local cache.
      await externalService.refreshEntitlements();
      AppLogging.subscriptions(
        '💳 [RestorePurchases] External (Stripe) entitlements refreshed',
      );
    } catch (e) {
      // External restore is best-effort. RC remains the source of
      // truth for store IAP, so failure here must not fail the whole
      // restore flow.
      AppLogging.subscriptions(
        '💳 [RestorePurchases] External entitlement restore failed (non-fatal): $e',
      );
    }

    // Always refresh state after restore
    AppLogging.subscriptions(
      '💳 [RestorePurchases] Explicitly refreshing purchase state notifier...',
    );
    try {
      await ref.read(purchaseStateProvider.notifier).refresh();
    } catch (_) {
      // ref may be disposed if the calling widget was unmounted
      AppLogging.subscriptions(
        '💳 [RestorePurchases] ref disposed during refresh — returning true',
      );
      return true;
    }
    AppLogging.subscriptions('💳 [RestorePurchases] Refresh complete');

    // Determine success by comparing state BEFORE and AFTER
    PurchaseState stateAfter;
    try {
      stateAfter = ref.read(purchaseStateProvider);
    } catch (_) {
      AppLogging.subscriptions(
        '💳 [RestorePurchases] ref disposed reading state — returning true',
      );
      return true;
    }
    final purchaseCountAfter = stateAfter.purchasedProductIds.length;
    AppLogging.subscriptions(
      '💳 [RestorePurchases] State AFTER restore: ${stateAfter.purchasedProductIds} (count: $purchaseCountAfter)',
    );

    // Success if we have ANY purchases now, regardless of what we had before
    // This handles the case where purchases were already restored but user taps again
    final hasPurchases = purchaseCountAfter > 0;
    final restoredNew = purchaseCountAfter > purchaseCountBefore;

    AppLogging.subscriptions('💳 [RestorePurchases] Result analysis:');
    AppLogging.subscriptions(
      '💳 [RestorePurchases]   hasPurchases: $hasPurchases',
    );
    AppLogging.subscriptions(
      '💳 [RestorePurchases]   restoredNew: $restoredNew',
    );
    AppLogging.subscriptions(
      '💳 [RestorePurchases] ═══════════════════════════════════════════════',
    );

    // Return true if user has purchases (either already had or just restored)
    return hasPurchases;
  } catch (e, stackTrace) {
    AppLogging.subscriptions('💳 [RestorePurchases] ❌ ERROR: $e');
    AppLogging.subscriptions('💳 [RestorePurchases] Stack trace: $stackTrace');
    errorNotifier.setError(e.toString());
    return false;
  } finally {
    AppLogging.subscriptions(
      '💳 [RestorePurchases] Setting loading state to false',
    );
    loadingNotifier.setLoading(false);
  }
}

/// Result of a syncPurchasesToFirestore Cloud Function call.
///
/// The mirror is intentionally a soft dependency: a failure here MUST NOT
/// revoke RC-backed access. Callers ignore [success] for the purposes of
/// reporting restore success to the user — RevenueCat is the source of
/// truth — but the result is logged with a stable `MIRROR_SYNC_FAILED`
/// prefix so failures are observable in logs and Crashlytics, and tests
/// can assert behavior deterministically.
class FirestoreMirrorSyncResult {
  final bool success;
  final Object? error;
  final String? statusFromBackend;

  const FirestoreMirrorSyncResult({
    required this.success,
    this.error,
    this.statusFromBackend,
  });
}

/// Best-effort callable to mirror RC purchases into Firestore. Never throws.
///
/// Failures are logged with a stable prefix (`MIRROR_SYNC_FAILED`) so they
/// are greppable in logs and queryable in Crashlytics. The caller decides
/// whether to surface the failure to the user; restore-success accounting
/// must stay independent of the mirror sync (RC truth wins).
Future<FirestoreMirrorSyncResult> _syncPurchasesToFirestoreSafe(
  String callerTag,
) async {
  AppLogging.subscriptions(
    '💳 [$callerTag] Mirror sync — calling syncPurchasesToFirestore...',
  );
  try {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'syncPurchasesToFirestore',
    );
    final result = await callable.call<Map<String, dynamic>>();
    final data = result.data;
    final status = data['status']?.toString();
    AppLogging.subscriptions(
      '💳 [$callerTag] Mirror sync OK — status=$status data=$data',
    );
    return FirestoreMirrorSyncResult(success: true, statusFromBackend: status);
  } catch (syncError, stackTrace) {
    // Stable greppable prefix. Do NOT change without updating downstream
    // log queries / Crashlytics filters.
    AppLogging.subscriptions(
      '💳 [$callerTag] MIRROR_SYNC_FAILED — '
      'type=${syncError.runtimeType} error=$syncError',
    );
    AppLogging.subscriptions(
      '💳 [$callerTag] MIRROR_SYNC_FAILED stack: $stackTrace',
    );
    AppLogging.subscriptions(
      '💳 [$callerTag] MIRROR_SYNC_FAILED is non-fatal — RC entitlements are '
      'unaffected. The mirror will retry on next foreground/restore.',
    );
    return FirestoreMirrorSyncResult(success: false, error: syncError);
  }
}

/// Sync RevenueCat with Firebase Auth
/// Call this when the user signs in to Firebase to ensure purchases are properly tracked
Future<bool> syncRevenueCatWithFirebase(WidgetRef ref) async {
  AppLogging.subscriptions(
    '💳 [SyncRevenueCat] Starting sync with Firebase Auth...',
  );

  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    AppLogging.subscriptions('💳 [SyncRevenueCat] No Firebase user signed in');
    return false;
  }

  AppLogging.subscriptions(
    '💳 [SyncRevenueCat] Firebase UID: ${firebaseUser.uid}',
  );

  try {
    PurchaseService service;
    try {
      service = await ref.read(subscriptionServiceProvider.future);
    } catch (_) {
      // ref may be disposed if the calling widget was unmounted
      AppLogging.subscriptions(
        '💳 [SyncRevenueCat] ref disposed getting service — aborting',
      );
      return false;
    }
    final success = await service.logIn(firebaseUser.uid);

    if (success) {
      // Refresh to get any purchases associated with this user
      await service.refreshPurchases();
      try {
        await ref.read(purchaseStateProvider.notifier).refresh();
      } catch (_) {
        // ref may be disposed if the calling widget was unmounted
        AppLogging.subscriptions(
          '💳 [SyncRevenueCat] ref disposed during refresh — continuing',
        );
      }

      // Mirror purchases into Firestore. See _syncPurchasesToFirestoreSafe
      // for failure semantics — failures are observable but never fatal.
      await _syncPurchasesToFirestoreSafe('SyncRevenueCat');

      AppLogging.subscriptions('💳 [SyncRevenueCat] ✅ Sync complete');
    }

    return success;
  } catch (e) {
    AppLogging.subscriptions('💳 [SyncRevenueCat] ❌ Error: $e');
    return false;
  }
}

/// Store product info fetched from RevenueCat
class StoreProductInfo {
  final String productId;
  final String title;
  final String description;
  final String priceString;
  final double price;

  const StoreProductInfo({
    required this.productId,
    required this.title,
    required this.description,
    required this.priceString,
    required this.price,
  });

  /// Clean the product title by removing the app name suffix that Google Play
  /// automatically appends (e.g., "Widget Pack (SocialMesh)" -> "Widget Pack")
  static String cleanTitle(String rawTitle) {
    // Google Play appends " (AppName)" to product titles on Android
    // Remove any trailing parenthetical content
    final parenIndex = rawTitle.lastIndexOf(' (');
    if (parenIndex > 0 && rawTitle.endsWith(')')) {
      return rawTitle.substring(0, parenIndex);
    }
    return rawTitle;
  }
}

/// Provider for fetching real store product info from RevenueCat
/// Uses Offerings API which properly returns localized prices
/// Returns a map of productId -> StoreProductInfo (title, description, price)
final storeProductsProvider = FutureProvider<Map<String, StoreProductInfo>>((
  ref,
) async {
  AppLogging.subscriptions(
    '💳 [StoreProducts] ═══════════════════════════════════════',
  );
  AppLogging.subscriptions(
    '💳 [StoreProducts] Fetching store products via Offerings...',
  );

  try {
    // Wait for subscription service to be initialized first
    await ref.watch(subscriptionServiceProvider.future);
    AppLogging.subscriptions('💳 [StoreProducts] Subscription service ready');

    // Use getOfferings() - this is the proper way to get localized prices
    final offerings = await Purchases.getOfferings();
    AppLogging.subscriptions(
      '💳 [StoreProducts] Offerings fetched, current: ${offerings.current?.identifier}',
    );

    final productMap = <String, StoreProductInfo>{};

    // Extract products from all offerings
    for (final offering in offerings.all.values) {
      AppLogging.subscriptions(
        '💳 [StoreProducts] Processing offering: ${offering.identifier}',
      );
      for (final package in offering.availablePackages) {
        final product = package.storeProduct;
        final cleanedTitle = StoreProductInfo.cleanTitle(product.title);
        AppLogging.subscriptions(
          '💳 [StoreProducts]   Package: ${package.identifier} -> ${product.identifier}: ${product.priceString} (title: "${product.title}" -> "$cleanedTitle")',
        );
        productMap[product.identifier] = StoreProductInfo(
          productId: product.identifier,
          title: cleanedTitle,
          description: product.description,
          priceString: product.priceString,
          price: product.price,
        );
      }
    }

    AppLogging.subscriptions(
      '💳 [StoreProducts] Loaded ${productMap.length} products from offerings',
    );
    for (final entry in productMap.entries) {
      AppLogging.subscriptions(
        '💳 [StoreProducts]   ${entry.key}: ${entry.value.priceString} - "${entry.value.title}"',
      );
    }

    // If offerings didn't have our products, try direct getProducts as fallback
    if (productMap.isEmpty) {
      AppLogging.subscriptions(
        '💳 [StoreProducts] No products in offerings, trying direct getProducts...',
      );
      final productIds = [
        ...OneTimePurchases.allIndividualPurchases.map((p) => p.productId),
        RevenueCatConfig.completePackProductId,
      ];
      AppLogging.subscriptions(
        '💳 [StoreProducts] Fetching product IDs: $productIds',
      );

      final products = await Purchases.getProducts(
        productIds,
        productCategory: ProductCategory.nonSubscription,
      );
      AppLogging.subscriptions(
        '💳 [StoreProducts] getProducts returned ${products.length} products',
      );

      for (final product in products) {
        final cleanedTitle = StoreProductInfo.cleanTitle(product.title);
        AppLogging.subscriptions(
          '💳 [StoreProducts]   ${product.identifier}: "${product.title}" -> "$cleanedTitle" - ${product.priceString}',
        );
        productMap[product.identifier] = StoreProductInfo(
          productId: product.identifier,
          title: cleanedTitle,
          description: product.description,
          priceString: product.priceString,
          price: product.price,
        );
      }
    }

    AppLogging.subscriptions(
      '💳 [StoreProducts] ═══════════════════════════════════════',
    );
    AppLogging.subscriptions(
      '💳 [StoreProducts] FINAL: ${productMap.length} products loaded',
    );
    for (final entry in productMap.entries) {
      AppLogging.subscriptions(
        '💳 [StoreProducts]   ${entry.key}: ${entry.value.priceString}',
      );
    }
    AppLogging.subscriptions(
      '💳 [StoreProducts] ═══════════════════════════════════════',
    );

    return productMap;
  } catch (e, stackTrace) {
    AppLogging.subscriptions('💳 [StoreProducts] ❌ ERROR: $e');
    AppLogging.subscriptions('💳 [StoreProducts] Stack trace: $stackTrace');
    return {};
  }
});
