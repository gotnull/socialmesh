import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../config/revenuecat_config.dart';
import '../../models/subscription_models.dart';

/// Service for managing subscriptions via RevenueCat
class SubscriptionService {
  final StreamController<SubscriptionState> _stateController =
      StreamController<SubscriptionState>.broadcast();

  SubscriptionState _currentState = SubscriptionState.initial;
  Set<String> _purchasedItems = {};
  bool _isInitialized = false;

  /// Current subscription state
  SubscriptionState get currentState => _currentState;

  /// Stream of subscription state changes
  Stream<SubscriptionState> get stateStream => _stateController.stream;

  /// Whether RevenueCat SDK is initialized
  bool get isInitialized => _isInitialized;

  /// Initialize RevenueCat SDK
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final apiKey = Platform.isIOS
          ? RevenueCatConfig.iosApiKey
          : RevenueCatConfig.androidApiKey;

      if (apiKey.isEmpty) {
        debugPrint('RevenueCat API key not configured');
        return;
      }

      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = null, // Anonymous user
      );

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      _isInitialized = true;

      // Get initial customer info
      await refreshSubscriptionStatus();
    } catch (e) {
      debugPrint('Error initializing RevenueCat: $e');
    }
  }

  /// Handle customer info updates from RevenueCat
  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    _updateStateFromCustomerInfo(customerInfo);
  }

  /// Update local state from RevenueCat customer info
  void _updateStateFromCustomerInfo(CustomerInfo customerInfo) {
    final entitlements = customerInfo.entitlements.active;

    SubscriptionTier tier = SubscriptionTier.free;
    DateTime? expiresAt;
    bool willRenew = true;

    // Check Pro entitlement first (higher tier)
    if (entitlements.containsKey(RevenueCatConfig.proEntitlementId)) {
      tier = SubscriptionTier.pro;
      final entitlement = entitlements[RevenueCatConfig.proEntitlementId]!;
      expiresAt = entitlement.expirationDate != null
          ? DateTime.parse(entitlement.expirationDate!)
          : null;
      willRenew = entitlement.willRenew;
    }
    // Check Premium entitlement
    else if (entitlements.containsKey(RevenueCatConfig.premiumEntitlementId)) {
      tier = SubscriptionTier.premium;
      final entitlement = entitlements[RevenueCatConfig.premiumEntitlementId]!;
      expiresAt = entitlement.expirationDate != null
          ? DateTime.parse(entitlement.expirationDate!)
          : null;
      willRenew = entitlement.willRenew;
    }

    // Check for non-consumable purchases
    _purchasedItems = customerInfo.nonSubscriptionTransactions
        .map((t) => t.productIdentifier)
        .toSet();

    _updateState(
      SubscriptionState(
        tier: tier,
        expiresAt: expiresAt,
        customerId: customerInfo.originalAppUserId,
        willRenew: willRenew,
      ),
    );
  }

  /// Check if user has a specific feature
  bool hasFeature(PremiumFeature feature) {
    // Check if feature is unlocked via subscription
    if (_currentState.hasFeature(feature)) return true;

    // Check if feature was unlocked via one-time purchase
    for (final purchase in OneTimePurchases.allPurchases) {
      if (purchase.unlocksFeature == feature &&
          _purchasedItems.contains(purchase.productId)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a one-time purchase has been made
  bool hasPurchased(String productId) {
    return _purchasedItems.contains(productId);
  }

  /// Get current tier
  SubscriptionTier get currentTier => _currentState.tier;

  /// Check if premium or higher
  bool get isPremiumOrHigher => _currentState.isPremiumOrHigher;

  /// Check if pro
  bool get isPro => _currentState.isPro;

  /// Update subscription state
  void _updateState(SubscriptionState state) {
    _currentState = state;
    _stateController.add(state);
  }

  // ============================================================================
  // REVENUECAT PURCHASES
  // ============================================================================

  /// Get available offerings from RevenueCat
  Future<Offerings?> getOfferings() async {
    if (!_isInitialized) return null;

    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('Error getting offerings: $e');
      return null;
    }
  }

  /// Get available packages for a specific offering
  Future<List<Package>?> getPackages({String? offeringId}) async {
    final offerings = await getOfferings();
    if (offerings == null) return null;

    final offering = offeringId != null
        ? offerings.getOffering(offeringId)
        : offerings.current;

    return offering?.availablePackages;
  }

  /// Purchase a subscription package
  Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      _updateStateFromCustomerInfo(customerInfo);
      return true;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('User cancelled purchase');
      } else {
        debugPrint('Purchase error: $e');
      }
      return false;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  /// Purchase a specific product by ID
  Future<bool> purchaseProduct(String productId) async {
    if (!_isInitialized) return false;

    try {
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) {
        debugPrint('Product not found: $productId');
        return false;
      }

      final customerInfo = await Purchases.purchaseStoreProduct(products.first);
      _updateStateFromCustomerInfo(customerInfo);
      return true;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('User cancelled purchase');
      } else {
        debugPrint('Purchase error: $e');
      }
      return false;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  /// Refresh subscription status from RevenueCat
  Future<void> refreshSubscriptionStatus() async {
    if (!_isInitialized) return;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('Error refreshing subscription: $e');
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;

    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateStateFromCustomerInfo(customerInfo);
      return true;
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  /// Log in user (for cross-device syncing)
  Future<void> logIn(String userId) async {
    if (!_isInitialized) return;

    try {
      final result = await Purchases.logIn(userId);
      _updateStateFromCustomerInfo(result.customerInfo);
    } catch (e) {
      debugPrint('Error logging in: $e');
    }
  }

  /// Log out user
  Future<void> logOut() async {
    if (!_isInitialized) return;

    try {
      final customerInfo = await Purchases.logOut();
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('Error logging out: $e');
    }
  }

  /// Start free trial (if available in offering)
  Future<bool> startTrial(Package package) async {
    // In RevenueCat, trials are configured in App Store Connect / Play Console
    // and automatically applied when purchasing eligible packages
    return purchasePackage(package);
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
  Future<void> debugAddPurchase(String productId) async {
    if (!kDebugMode) return;
    _purchasedItems.add(productId);
    _stateController.add(_currentState);
  }

  /// Debug: Reset to free tier
  Future<void> debugReset() async {
    if (!kDebugMode) return;
    _purchasedItems.clear();
    _updateState(SubscriptionState.initial);
  }
}
