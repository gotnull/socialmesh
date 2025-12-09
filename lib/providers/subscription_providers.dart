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
    StateNotifierProvider<PurchaseStateNotifier, PurchaseState>((ref) {
      return PurchaseStateNotifier(ref);
    });

class PurchaseStateNotifier extends StateNotifier<PurchaseState> {
  final Ref _ref;

  PurchaseStateNotifier(this._ref) : super(PurchaseState.initial) {
    _init();
  }

  Future<void> _init() async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    state = service.currentState;

    // Listen for state changes
    service.stateStream.listen((newState) {
      state = newState;
    });
  }

  /// Refresh purchases from RevenueCat
  Future<void> refresh() async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    await service.refreshPurchases();
    state = service.currentState;
  }

  /// For debug/testing - add purchase
  Future<void> debugAddPurchase(String productId) async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    await service.debugAddPurchase(productId);
    state = service.currentState;
  }

  /// For debug/testing - reset purchases
  Future<void> debugReset() async {
    final service = await _ref.read(subscriptionServiceProvider.future);
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

/// Purchase loading state for async operations
final subscriptionLoadingProvider = StateProvider<bool>((ref) => false);

/// Purchase error state
final subscriptionErrorProvider = StateProvider<String?>((ref) => null);

/// Purchase a one-time product
/// Returns PurchaseResult indicating success, cancellation, or error
Future<PurchaseResult> purchaseProduct(WidgetRef ref, String productId) async {
  ref.read(subscriptionLoadingProvider.notifier).state = true;
  ref.read(subscriptionErrorProvider.notifier).state = null;

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final result = await service.purchaseProduct(productId);
    if (result == PurchaseResult.success) {
      ref.read(purchaseStateProvider.notifier).refresh();
    }
    return result;
  } catch (e) {
    ref.read(subscriptionErrorProvider.notifier).state = e.toString();
    return PurchaseResult.error;
  } finally {
    ref.read(subscriptionLoadingProvider.notifier).state = false;
  }
}

/// Restore purchases
Future<bool> restorePurchases(WidgetRef ref) async {
  ref.read(subscriptionLoadingProvider.notifier).state = true;
  ref.read(subscriptionErrorProvider.notifier).state = null;

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final success = await service.restorePurchases();
    if (success) {
      ref.read(purchaseStateProvider.notifier).refresh();
    }
    return success;
  } catch (e) {
    ref.read(subscriptionErrorProvider.notifier).state = e.toString();
    return false;
  } finally {
    ref.read(subscriptionLoadingProvider.notifier).state = false;
  }
}
