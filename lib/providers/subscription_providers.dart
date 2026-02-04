// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart' hide PurchaseResult;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/logging.dart';
import '../config/revenuecat_config.dart';
import '../models/subscription_models.dart';
import '../services/subscription/subscription_service.dart';

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
  await service.initialize();
  return service;
});

/// Current purchase state - auto-refreshes from service
final purchaseStateProvider =
    NotifierProvider<PurchaseStateNotifier, PurchaseState>(
      PurchaseStateNotifier.new,
    );

class PurchaseStateNotifier extends Notifier<PurchaseState> {
  StreamSubscription<PurchaseState>? _subscription;

  @override
  PurchaseState build() {
    AppLogging.subscriptions('💳 [PurchaseStateNotifier] build() called');

    // Cancel any existing subscription when provider rebuilds
    ref.onDispose(() {
      AppLogging.subscriptions(
        '💳 [PurchaseStateNotifier] onDispose - cancelling stream subscription',
      );
      _subscription?.cancel();
      _subscription = null;
    });

    _init();
    return PurchaseState.initial;
  }

  Future<void> _init() async {
    AppLogging.subscriptions('💳 [PurchaseStateNotifier] _init() starting...');
    final service = await ref.read(subscriptionServiceProvider.future);
    final initialState = service.currentState;
    AppLogging.subscriptions(
      '💳 [PurchaseStateNotifier] Setting initial state: ${initialState.purchasedProductIds}',
    );

    // Check if still mounted before updating state (after async gap)
    if (!ref.mounted) {
      AppLogging.subscriptions(
        '💳 [PurchaseStateNotifier] Not mounted after await, skipping init',
      );
      return;
    }
    state = initialState;

    // Listen for state changes from the service
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
          '💳 [PurchaseStateNotifier] Stream received new state: ${newState.purchasedProductIds}',
        );
        state = newState;
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

    // Check if still mounted before updating state (after async gap)
    if (!ref.mounted) {
      AppLogging.subscriptions(
        '💳 [PurchaseStateNotifier] Not mounted after refresh, skipping state update',
      );
      return;
    }
    final newState = service.currentState;
    AppLogging.subscriptions(
      '💳 [PurchaseStateNotifier] refresh() setting state: ${newState.purchasedProductIds}',
    );
    state = newState;
  }

  /// For debug/testing - add purchase
  Future<void> debugAddPurchase(String productId) async {
    final service = await ref.read(subscriptionServiceProvider.future);
    await service.debugAddPurchase(productId);
    state = service.currentState;
  }

  /// For debug/testing - reset purchases
  Future<void> debugReset() async {
    final service = await ref.read(subscriptionServiceProvider.future);
    await service.debugReset();
    state = service.currentState;
  }
}

/// Check if a specific feature is available
final hasFeatureProvider = Provider.family<bool, PremiumFeature>((
  ref,
  feature,
) {
  final state = ref.watch(purchaseStateProvider);
  return state.hasFeature(feature);
});

/// Check if a specific product has been purchased
final hasPurchasedProvider = Provider.family<bool, String>((ref, productId) {
  final state = ref.watch(purchaseStateProvider);
  return state.hasPurchased(productId);
});

/// Check if user has all premium features unlocked (owns complete pack OR all individual packs)
/// Users with all premium features get an "Authorised" badge
final hasAllPremiumFeaturesProvider = Provider<bool>((ref) {
  final state = ref.watch(purchaseStateProvider);

  // Check if user owns complete pack
  if (state.hasPurchased(RevenueCatConfig.completePackProductId)) {
    return true;
  }

  // Check if user owns all individual packs
  for (final purchase in OneTimePurchases.allIndividualPurchases) {
    if (!state.hasPurchased(purchase.productId)) {
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
  ref.read(subscriptionLoadingProvider.notifier).setLoading(true);
  ref.read(subscriptionErrorProvider.notifier).clear();

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
      // Await the refresh to ensure state is updated before returning
      await ref.read(purchaseStateProvider.notifier).refresh();
      AppLogging.subscriptions('💳 [PurchaseProduct] Refresh complete');

      // Double-check the state
      final state = ref.read(purchaseStateProvider);
      AppLogging.subscriptions(
        '💳 [PurchaseProduct] Final state: ${state.purchasedProductIds}',
      );
    }
    return result;
  } catch (e) {
    AppLogging.subscriptions('💳 [PurchaseProduct] Error: $e');
    ref.read(subscriptionErrorProvider.notifier).setError(e.toString());
    return PurchaseResult.error;
  } finally {
    ref.read(subscriptionLoadingProvider.notifier).setLoading(false);
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
  AppLogging.subscriptions(
    '💳 [RestorePurchases] Setting loading state to true',
  );

  ref.read(subscriptionLoadingProvider.notifier).setLoading(true);
  ref.read(subscriptionErrorProvider.notifier).clear();

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

    // IMPORTANT: Do restore FIRST, before logging in with Firebase UID
    // This ensures we restore purchases from the anonymous ID that Google Play uses
    AppLogging.subscriptions(
      '💳 [RestorePurchases] Calling service.restorePurchases() FIRST (before Firebase login)...',
    );
    await service.restorePurchases();
    AppLogging.subscriptions('💳 [RestorePurchases] Initial restore completed');

    // Now sync with Firebase Auth for cross-device consistency
    // This transfers any restored purchases to the Firebase-linked customer
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      AppLogging.subscriptions(
        '💳 [RestorePurchases] Firebase user signed in: ${firebaseUser.uid}',
      );
      AppLogging.subscriptions(
        '💳 [RestorePurchases] Syncing RevenueCat with Firebase UID...',
      );
      await service.logIn(firebaseUser.uid);
      // Do another refresh after login to ensure state is synced
      AppLogging.subscriptions(
        '💳 [RestorePurchases] Refreshing after Firebase login...',
      );
      await service.refreshPurchases();

      // Sync purchases to Firestore via Cloud Function
      // This ensures the admin panel can see the purchases
      AppLogging.subscriptions(
        '💳 [RestorePurchases] Syncing purchases to Firestore...',
      );
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'syncPurchasesToFirestore',
        );
        final result = await callable.call<Map<String, dynamic>>();
        AppLogging.subscriptions(
          '💳 [RestorePurchases] Firestore sync result: ${result.data}',
        );
      } catch (syncError) {
        // Don't fail the restore if Firestore sync fails
        AppLogging.subscriptions(
          '💳 [RestorePurchases] ⚠️ Firestore sync failed (non-fatal): $syncError',
        );
      }
    } else {
      AppLogging.subscriptions(
        '💳 [RestorePurchases] No Firebase user signed in (restore still works via store account)',
      );
    }

    AppLogging.subscriptions(
      '💳 [RestorePurchases] service.restorePurchases() completed',
    );

    // Always refresh state after restore
    AppLogging.subscriptions(
      '💳 [RestorePurchases] Explicitly refreshing purchase state notifier...',
    );
    await ref.read(purchaseStateProvider.notifier).refresh();
    AppLogging.subscriptions('💳 [RestorePurchases] Refresh complete');

    // Determine success by comparing state BEFORE and AFTER
    final stateAfter = ref.read(purchaseStateProvider);
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
    ref.read(subscriptionErrorProvider.notifier).setError(e.toString());
    return false;
  } finally {
    AppLogging.subscriptions(
      '💳 [RestorePurchases] Setting loading state to false',
    );
    ref.read(subscriptionLoadingProvider.notifier).setLoading(false);
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
    final service = await ref.read(subscriptionServiceProvider.future);
    final success = await service.logIn(firebaseUser.uid);

    if (success) {
      // Refresh to get any purchases associated with this user
      await service.refreshPurchases();
      await ref.read(purchaseStateProvider.notifier).refresh();

      // Sync purchases to Firestore via Cloud Function
      AppLogging.subscriptions(
        '💳 [SyncRevenueCat] Syncing purchases to Firestore...',
      );
      try {
        final callable = FirebaseFunctions.instance.httpsCallable(
          'syncPurchasesToFirestore',
        );
        final result = await callable.call<Map<String, dynamic>>();
        AppLogging.subscriptions(
          '💳 [SyncRevenueCat] Firestore sync result: ${result.data}',
        );
      } catch (syncError) {
        AppLogging.subscriptions(
          '💳 [SyncRevenueCat] ⚠️ Firestore sync failed (non-fatal): $syncError',
        );
      }

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
  /// automatically appends (e.g., "Widget Pack (Socialmesh)" -> "Widget Pack")
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
