import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../config/stripe_config.dart';
import '../../models/subscription_models.dart';

/// Service for managing subscriptions via Stripe/RevenueCat
class SubscriptionService {
  static const _subscriptionKey = 'subscription_state';
  static const _purchasesKey = 'one_time_purchases';

  final SharedPreferences _prefs;
  final StreamController<SubscriptionState> _stateController =
      StreamController<SubscriptionState>.broadcast();

  SubscriptionState _currentState = SubscriptionState.initial;
  Set<String> _purchasedItems = {};

  SubscriptionService(this._prefs) {
    _loadState();
  }

  /// Current subscription state
  SubscriptionState get currentState => _currentState;

  /// Stream of subscription state changes
  Stream<SubscriptionState> get stateStream => _stateController.stream;

  /// Check if user has a specific feature
  bool hasFeature(PremiumFeature feature) {
    // Check if feature is unlocked via subscription
    if (_currentState.hasFeature(feature)) return true;

    // Check if feature was unlocked via one-time purchase
    for (final purchase in OneTimePurchases.allPurchases) {
      if (purchase.unlocksFeature == feature &&
          _purchasedItems.contains(purchase.id)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a one-time purchase has been made
  bool hasPurchased(String purchaseId) {
    return _purchasedItems.contains(purchaseId);
  }

  /// Get current tier
  SubscriptionTier get currentTier => _currentState.tier;

  /// Check if premium or higher
  bool get isPremiumOrHigher => _currentState.isPremiumOrHigher;

  /// Check if pro
  bool get isPro => _currentState.isPro;

  /// Load saved state from preferences
  Future<void> _loadState() async {
    try {
      final stateJson = _prefs.getString(_subscriptionKey);
      if (stateJson != null) {
        final data = jsonDecode(stateJson) as Map<String, dynamic>;
        _currentState = SubscriptionState(
          tier: SubscriptionTier.values[data['tier'] as int],
          expiresAt: data['expiresAt'] != null
              ? DateTime.parse(data['expiresAt'] as String)
              : null,
          isTrialing: data['isTrialing'] as bool? ?? false,
          trialDaysRemaining: data['trialDaysRemaining'] as int? ?? 0,
          customerId: data['customerId'] as String?,
          subscriptionId: data['subscriptionId'] as String?,
          willRenew: data['willRenew'] as bool? ?? true,
        );
      }

      final purchasesJson = _prefs.getStringList(_purchasesKey);
      if (purchasesJson != null) {
        _purchasedItems = purchasesJson.toSet();
      }

      _stateController.add(_currentState);
    } catch (e) {
      debugPrint('Error loading subscription state: $e');
    }
  }

  /// Save current state to preferences
  Future<void> _saveState() async {
    try {
      final data = {
        'tier': _currentState.tier.index,
        'expiresAt': _currentState.expiresAt?.toIso8601String(),
        'isTrialing': _currentState.isTrialing,
        'trialDaysRemaining': _currentState.trialDaysRemaining,
        'customerId': _currentState.customerId,
        'subscriptionId': _currentState.subscriptionId,
        'willRenew': _currentState.willRenew,
      };
      await _prefs.setString(_subscriptionKey, jsonEncode(data));
      await _prefs.setStringList(_purchasesKey, _purchasedItems.toList());
    } catch (e) {
      debugPrint('Error saving subscription state: $e');
    }
  }

  /// Update subscription state
  void _updateState(SubscriptionState state) {
    _currentState = state;
    _stateController.add(state);
    _saveState();
  }

  // ============================================================================
  // STRIPE INTEGRATION
  // ============================================================================

  /// Create a Stripe checkout session for subscription
  Future<String?> createCheckoutSession({
    required SubscriptionPlan plan,
    required bool yearly,
    String? email,
  }) async {
    try {
      final priceId = yearly
          ? plan.stripeYearlyPriceId
          : plan.stripeMonthlyPriceId;
      if (priceId == null) return null;

      final response = await http.post(
        Uri.parse('${StripeConfig.apiBaseUrl}/create-checkout-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'priceId': priceId,
          'email': email,
          'customerId': _currentState.customerId,
          'successUrl': 'protofluff://subscription/success',
          'cancelUrl': 'protofluff://subscription/cancel',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      }
    } catch (e) {
      debugPrint('Error creating checkout session: $e');
    }
    return null;
  }

  /// Create a Stripe checkout session for one-time purchase
  Future<String?> createPurchaseCheckoutSession({
    required OneTimePurchase purchase,
    String? email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${StripeConfig.apiBaseUrl}/create-purchase-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'priceId': purchase.stripePriceId,
          'purchaseId': purchase.id,
          'email': email,
          'customerId': _currentState.customerId,
          'successUrl': 'protofluff://purchase/success?id=${purchase.id}',
          'cancelUrl': 'protofluff://purchase/cancel',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      }
    } catch (e) {
      debugPrint('Error creating purchase session: $e');
    }
    return null;
  }

  /// Open customer portal to manage subscription
  Future<String?> createCustomerPortalSession() async {
    if (_currentState.customerId == null) return null;

    try {
      final response = await http.post(
        Uri.parse('${StripeConfig.apiBaseUrl}/create-portal-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'customerId': _currentState.customerId,
          'returnUrl': 'protofluff://settings',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      }
    } catch (e) {
      debugPrint('Error creating portal session: $e');
    }
    return null;
  }

  /// Verify subscription status with backend
  Future<void> verifySubscription() async {
    if (_currentState.customerId == null) return;

    try {
      final response = await http.get(
        Uri.parse(
          '${StripeConfig.apiBaseUrl}/subscription-status?customerId=${_currentState.customerId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _updateState(
          SubscriptionState(
            tier: _tierFromString(data['tier'] as String?),
            expiresAt: data['expiresAt'] != null
                ? DateTime.parse(data['expiresAt'] as String)
                : null,
            isTrialing: data['isTrialing'] as bool? ?? false,
            trialDaysRemaining: data['trialDaysRemaining'] as int? ?? 0,
            customerId: _currentState.customerId,
            subscriptionId: data['subscriptionId'] as String?,
            willRenew: data['willRenew'] as bool? ?? true,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error verifying subscription: $e');
    }
  }

  /// Handle successful subscription (called from deep link)
  Future<void> handleSubscriptionSuccess({
    required String customerId,
    required String subscriptionId,
    required SubscriptionTier tier,
    DateTime? expiresAt,
  }) async {
    _updateState(
      SubscriptionState(
        tier: tier,
        expiresAt: expiresAt,
        customerId: customerId,
        subscriptionId: subscriptionId,
        willRenew: true,
      ),
    );
  }

  /// Handle successful one-time purchase
  Future<void> handlePurchaseSuccess(String purchaseId) async {
    _purchasedItems.add(purchaseId);
    await _saveState();
    _stateController.add(_currentState); // Notify listeners
  }

  /// Start free trial
  Future<void> startTrial({
    required SubscriptionTier tier,
    int durationDays = 7,
  }) async {
    final expiresAt = DateTime.now().add(Duration(days: durationDays));
    _updateState(
      SubscriptionState(
        tier: tier,
        expiresAt: expiresAt,
        isTrialing: true,
        trialDaysRemaining: durationDays,
        customerId: _currentState.customerId,
      ),
    );
  }

  /// Cancel subscription (just marks locally, actual cancel via portal)
  void markCancelled() {
    _updateState(_currentState.copyWith(willRenew: false));
  }

  /// Restore purchases (re-verify with server)
  Future<bool> restorePurchases() async {
    await verifySubscription();
    // Also verify one-time purchases
    if (_currentState.customerId != null) {
      try {
        final response = await http.get(
          Uri.parse(
            '${StripeConfig.apiBaseUrl}/purchases?customerId=${_currentState.customerId}',
          ),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as List;
          _purchasedItems = data.map((e) => e.toString()).toSet();
          await _saveState();
          return true;
        }
      } catch (e) {
        debugPrint('Error restoring purchases: $e');
      }
    }
    return false;
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  SubscriptionTier _tierFromString(String? tier) {
    switch (tier?.toLowerCase()) {
      case 'premium':
        return SubscriptionTier.premium;
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }

  /// Dispose resources
  void dispose() {
    _stateController.close();
  }

  // ============================================================================
  // DEBUG / TESTING
  // ============================================================================

  /// Debug: Set tier directly (for testing)
  Future<void> debugSetTier(SubscriptionTier tier) async {
    if (!kDebugMode) return;

    final expiresAt = tier == SubscriptionTier.free
        ? null
        : DateTime.now().add(const Duration(days: 365));

    _updateState(
      SubscriptionState(
        tier: tier,
        expiresAt: expiresAt,
        customerId: 'debug_customer',
        subscriptionId: 'debug_subscription',
      ),
    );
  }

  /// Debug: Add purchase (for testing)
  Future<void> debugAddPurchase(String purchaseId) async {
    if (!kDebugMode) return;
    await handlePurchaseSuccess(purchaseId);
  }

  /// Debug: Reset to free tier
  Future<void> debugReset() async {
    if (!kDebugMode) return;
    _purchasedItems.clear();
    _updateState(SubscriptionState.initial);
  }
}
