import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  @override
  PurchaseState build() {
    _init();
    return PurchaseState.initial;
  }

  Future<void> _init() async {
    final service = await ref.read(subscriptionServiceProvider.future);
    state = service.currentState;

    // Listen for state changes
    service.stateStream.listen((newState) {
      state = newState;
    });
  }

  /// Refresh purchases from RevenueCat
  Future<void> refresh() async {
    final service = await ref.read(subscriptionServiceProvider.future);
    await service.refreshPurchases();
    state = service.currentState;
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
  ref.read(subscriptionLoadingProvider.notifier).setLoading(true);
  ref.read(subscriptionErrorProvider.notifier).clear();

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final result = await service.purchaseProduct(productId);
    if (result == PurchaseResult.success) {
      ref.read(purchaseStateProvider.notifier).refresh();
    }
    return result;
  } catch (e) {
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
  debugPrint(
    '💳 [RestorePurchases] ═══════════════════════════════════════════════',
  );
  debugPrint('💳 [RestorePurchases] Provider function called');
  debugPrint('💳 [RestorePurchases] Setting loading state to true');

  ref.read(subscriptionLoadingProvider.notifier).setLoading(true);
  ref.read(subscriptionErrorProvider.notifier).clear();

  try {
    debugPrint('💳 [RestorePurchases] Getting subscription service...');
    final service = await ref.read(subscriptionServiceProvider.future);
    debugPrint(
      '💳 [RestorePurchases] Service obtained, isInitialized: ${service.isInitialized}',
    );

    // Optional: Sync with Firebase Auth for cross-device consistency
    // Note: iOS restore works via Apple ID regardless of this
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      debugPrint(
        '💳 [RestorePurchases] Firebase user signed in: ${firebaseUser.uid}',
      );
      debugPrint(
        '💳 [RestorePurchases] Syncing RevenueCat with Firebase UID for cross-device support...',
      );
      await service.logIn(firebaseUser.uid);
    } else {
      debugPrint(
        '💳 [RestorePurchases] No Firebase user signed in (restore still works via Apple ID)',
      );
    }

    debugPrint(
      '💳 [RestorePurchases] Current state before restore: ${service.currentState.purchasedProductIds}',
    );

    debugPrint('💳 [RestorePurchases] Calling service.restorePurchases()...');
    debugPrint(
      '💳 [RestorePurchases] This queries App Store for purchases tied to your Apple ID',
    );
    final success = await service.restorePurchases();
    debugPrint(
      '💳 [RestorePurchases] service.restorePurchases() returned: $success',
    );

    if (success) {
      debugPrint(
        '💳 [RestorePurchases] Success! Refreshing purchase state notifier...',
      );
      ref.read(purchaseStateProvider.notifier).refresh();
    } else {
      debugPrint('💳 [RestorePurchases] No purchases found for this Apple ID');
      debugPrint('💳 [RestorePurchases] Possible reasons:');
      debugPrint(
        '💳 [RestorePurchases]   1. No purchases made with this Apple ID',
      );
      debugPrint(
        '💳 [RestorePurchases]   2. Using different Apple ID than when purchased',
      );
      debugPrint(
        '💳 [RestorePurchases]   3. Sandbox vs Production environment mismatch',
      );
      debugPrint('💳 [RestorePurchases]   4. Purchase was refunded or revoked');
    }

    final stateAfter = ref.read(purchaseStateProvider);
    debugPrint(
      '💳 [RestorePurchases] State after restore: ${stateAfter.purchasedProductIds}',
    );
    debugPrint(
      '💳 [RestorePurchases] ═══════════════════════════════════════════════',
    );

    return success;
  } catch (e, stackTrace) {
    debugPrint('💳 [RestorePurchases] ❌ ERROR: $e');
    debugPrint('💳 [RestorePurchases] Stack trace: $stackTrace');
    ref.read(subscriptionErrorProvider.notifier).setError(e.toString());
    return false;
  } finally {
    debugPrint('💳 [RestorePurchases] Setting loading state to false');
    ref.read(subscriptionLoadingProvider.notifier).setLoading(false);
  }
}

/// Sync RevenueCat with Firebase Auth
/// Call this when the user signs in to Firebase to ensure purchases are properly tracked
Future<bool> syncRevenueCatWithFirebase(WidgetRef ref) async {
  debugPrint('💳 [SyncRevenueCat] Starting sync with Firebase Auth...');

  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    debugPrint('💳 [SyncRevenueCat] No Firebase user signed in');
    return false;
  }

  debugPrint('💳 [SyncRevenueCat] Firebase UID: ${firebaseUser.uid}');

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final success = await service.logIn(firebaseUser.uid);

    if (success) {
      // Refresh to get any purchases associated with this user
      await service.refreshPurchases();
      ref.read(purchaseStateProvider.notifier).refresh();
      debugPrint('💳 [SyncRevenueCat] ✅ Sync complete');
    }

    return success;
  } catch (e) {
    debugPrint('💳 [SyncRevenueCat] ❌ Error: $e');
    return false;
  }
}
