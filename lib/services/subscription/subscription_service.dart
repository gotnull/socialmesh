import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../config/revenuecat_config.dart';
import '../../models/subscription_models.dart';

/// Service for managing one-time purchases via RevenueCat
class PurchaseService {
  final StreamController<PurchaseState> _stateController =
      StreamController<PurchaseState>.broadcast();

  PurchaseState _currentState = PurchaseState.initial;
  bool _isInitialized = false;

  /// Current purchase state
  PurchaseState get currentState => _currentState;

  /// Stream of purchase state changes
  Stream<PurchaseState> get stateStream => _stateController.stream;

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
        debugPrint('💰 RevenueCat API key not configured');
        return;
      }

      debugPrint('💰 Configuring RevenueCat...');
      await Purchases.configure(
        PurchasesConfiguration(apiKey)..appUserID = null, // Anonymous user
      );

      // Listen for customer info updates
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      _isInitialized = true;
      debugPrint('💰 RevenueCat SDK initialized successfully');

      // Get initial customer info
      await refreshPurchases();
    } catch (e) {
      debugPrint('💰 Error initializing RevenueCat: $e');
    }
  }

  /// Handle customer info updates from RevenueCat
  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    _updateStateFromCustomerInfo(customerInfo);
  }

  /// Update local state from RevenueCat customer info
  void _updateStateFromCustomerInfo(CustomerInfo customerInfo) {
    // Get non-consumable purchases
    final purchasedIds = customerInfo.nonSubscriptionTransactions
        .map((t) => t.productIdentifier)
        .toSet();

    _updateState(
      PurchaseState(
        purchasedProductIds: purchasedIds,
        customerId: customerInfo.originalAppUserId,
      ),
    );
  }

  /// Check if user has a specific feature
  bool hasFeature(PremiumFeature feature) {
    return _currentState.hasFeature(feature);
  }

  /// Check if a one-time purchase has been made
  bool hasPurchased(String productId) {
    return _currentState.hasPurchased(productId);
  }

  /// Update purchase state
  void _updateState(PurchaseState state) {
    _currentState = state;
    _stateController.add(state);
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

  /// Refresh purchases from RevenueCat
  Future<void> refreshPurchases() async {
    if (!_isInitialized) return;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      debugPrint('Error refreshing purchases: $e');
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;

    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateStateFromCustomerInfo(customerInfo);
      return customerInfo.nonSubscriptionTransactions.isNotEmpty;
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

  /// Dispose resources
  void dispose() {
    _stateController.close();
  }

  // ============================================================================
  // DEBUG / TESTING
  // ============================================================================

  /// Debug: Add purchase (for testing)
  Future<void> debugAddPurchase(String productId) async {
    if (!kDebugMode) return;
    final newIds = {..._currentState.purchasedProductIds, productId};
    _updateState(_currentState.copyWith(purchasedProductIds: newIds));
  }

  /// Debug: Reset purchases
  Future<void> debugReset() async {
    if (!kDebugMode) return;
    _updateState(PurchaseState.initial);
  }
}
