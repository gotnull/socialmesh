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
Future<bool> restorePurchases(WidgetRef ref) async {
  ref.read(subscriptionLoadingProvider.notifier).setLoading(true);
  ref.read(subscriptionErrorProvider.notifier).clear();

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final success = await service.restorePurchases();
    if (success) {
      ref.read(purchaseStateProvider.notifier).refresh();
    }
    return success;
  } catch (e) {
    ref.read(subscriptionErrorProvider.notifier).setError(e.toString());
    return false;
  } finally {
    ref.read(subscriptionLoadingProvider.notifier).setLoading(false);
  }
}
