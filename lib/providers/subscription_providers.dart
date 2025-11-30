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

/// Subscription service singleton provider
final subscriptionServiceProvider = FutureProvider<SubscriptionService>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SubscriptionService(prefs);
});

/// Current subscription state - auto-refreshes from service
final subscriptionStateProvider =
    StateNotifierProvider<SubscriptionStateNotifier, SubscriptionState>((ref) {
      return SubscriptionStateNotifier(ref);
    });

class SubscriptionStateNotifier extends StateNotifier<SubscriptionState> {
  final Ref _ref;

  SubscriptionStateNotifier(this._ref) : super(SubscriptionState.initial) {
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

  /// Refresh subscription from server
  Future<void> refresh() async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    await service.verifySubscription();
    state = service.currentState;
  }

  /// Start a trial
  Future<void> startTrial(SubscriptionTier tier) async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    await service.startTrial(tier: tier);
    state = service.currentState;
  }

  /// Handle subscription success callback
  Future<void> handleSubscriptionSuccess({
    required String customerId,
    required String subscriptionId,
    required SubscriptionTier tier,
    DateTime? expiresAt,
  }) async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    await service.handleSubscriptionSuccess(
      customerId: customerId,
      subscriptionId: subscriptionId,
      tier: tier,
      expiresAt: expiresAt,
    );
    state = service.currentState;
  }

  /// Handle purchase success callback
  Future<void> handlePurchaseSuccess(String purchaseId) async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    await service.handlePurchaseSuccess(purchaseId);
    state = service.currentState;
  }

  /// For debug/testing - set tier directly
  Future<void> debugSetTier(SubscriptionTier tier) async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    await service.debugSetTier(tier);
    state = service.currentState;
  }

  /// For debug/testing - add purchase
  Future<void> debugAddPurchase(String purchaseId) async {
    final service = await _ref.read(subscriptionServiceProvider.future);
    await service.debugAddPurchase(purchaseId);
    state = service.currentState;
  }
}

/// Current subscription tier - derived from state
final currentTierProvider = Provider<SubscriptionTier>((ref) {
  final state = ref.watch(subscriptionStateProvider);
  return state.tier;
});

/// Is premium subscriber (Premium or Pro)
final isPremiumProvider = Provider<bool>((ref) {
  final state = ref.watch(subscriptionStateProvider);
  return state.isPremiumOrHigher;
});

/// Is pro subscriber
final isProProvider = Provider<bool>((ref) {
  final state = ref.watch(subscriptionStateProvider);
  return state.isPro;
});

/// Check if a specific feature is available
final hasFeatureProvider = Provider.family<bool, PremiumFeature>((
  ref,
  feature,
) {
  final state = ref.watch(subscriptionStateProvider);
  return state.hasFeature(feature);
});

/// Trial status - check if currently in trial
final isTrialActiveProvider = Provider<bool>((ref) {
  final state = ref.watch(subscriptionStateProvider);
  return state.isTrialing;
});

/// Trial days remaining
final trialDaysRemainingProvider = Provider<int>((ref) {
  final state = ref.watch(subscriptionStateProvider);
  return state.trialDaysRemaining;
});

/// Get current plan details
final currentPlanProvider = Provider<SubscriptionPlan>((ref) {
  final tier = ref.watch(currentTierProvider);
  return SubscriptionPlans.getPlan(tier);
});

/// Get upgrade prompt text based on current tier
final upgradePromptProvider = Provider<String>((ref) {
  final tier = ref.watch(currentTierProvider);
  switch (tier) {
    case SubscriptionTier.free:
      return 'Upgrade to Premium for more features';
    case SubscriptionTier.premium:
      return 'Upgrade to Pro for unlimited access';
    case SubscriptionTier.pro:
      return '';
  }
});

/// Available upgrades from current tier
final availableUpgradesProvider = Provider<List<SubscriptionPlan>>((ref) {
  final tier = ref.watch(currentTierProvider);
  switch (tier) {
    case SubscriptionTier.free:
      return [SubscriptionPlans.premium, SubscriptionPlans.pro];
    case SubscriptionTier.premium:
      return [SubscriptionPlans.pro];
    case SubscriptionTier.pro:
      return [];
  }
});

/// Subscription loading state for async operations
final subscriptionLoadingProvider = StateProvider<bool>((ref) => false);

/// Subscription error state
final subscriptionErrorProvider = StateProvider<String?>((ref) => null);

/// Start checkout session for subscription
Future<String?> startCheckout(
  WidgetRef ref,
  SubscriptionPlan plan, {
  bool yearly = false,
}) async {
  ref.read(subscriptionLoadingProvider.notifier).state = true;
  ref.read(subscriptionErrorProvider.notifier).state = null;

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final url = await service.createCheckoutSession(plan: plan, yearly: yearly);
    return url;
  } catch (e) {
    ref.read(subscriptionErrorProvider.notifier).state = e.toString();
    return null;
  } finally {
    ref.read(subscriptionLoadingProvider.notifier).state = false;
  }
}

/// Start checkout session for one-time purchase
Future<String?> startPurchaseCheckout(
  WidgetRef ref,
  OneTimePurchase purchase,
) async {
  ref.read(subscriptionLoadingProvider.notifier).state = true;
  ref.read(subscriptionErrorProvider.notifier).state = null;

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final url = await service.createPurchaseCheckoutSession(purchase: purchase);
    return url;
  } catch (e) {
    ref.read(subscriptionErrorProvider.notifier).state = e.toString();
    return null;
  } finally {
    ref.read(subscriptionLoadingProvider.notifier).state = false;
  }
}

/// Open customer portal for subscription management
Future<String?> openCustomerPortal(WidgetRef ref) async {
  ref.read(subscriptionLoadingProvider.notifier).state = true;
  ref.read(subscriptionErrorProvider.notifier).state = null;

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final url = await service.createCustomerPortalSession();
    return url;
  } catch (e) {
    ref.read(subscriptionErrorProvider.notifier).state = e.toString();
    return null;
  } finally {
    ref.read(subscriptionLoadingProvider.notifier).state = false;
  }
}

/// Check if user has purchased a specific one-time purchase
Future<bool> hasPurchased(WidgetRef ref, String purchaseId) async {
  final service = await ref.read(subscriptionServiceProvider.future);
  return service.hasPurchased(purchaseId);
}

/// Restore purchases
Future<bool> restorePurchases(WidgetRef ref) async {
  ref.read(subscriptionLoadingProvider.notifier).state = true;
  ref.read(subscriptionErrorProvider.notifier).state = null;

  try {
    final service = await ref.read(subscriptionServiceProvider.future);
    final success = await service.restorePurchases();
    if (success) {
      ref.read(subscriptionStateProvider.notifier).refresh();
    }
    return success;
  } catch (e) {
    ref.read(subscriptionErrorProvider.notifier).state = e.toString();
    return false;
  } finally {
    ref.read(subscriptionLoadingProvider.notifier).state = false;
  }
}
