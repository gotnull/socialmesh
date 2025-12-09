import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../config/revenuecat_config.dart';
import '../../models/subscription_models.dart';

/// Result of a purchase attempt
enum PurchaseResult { success, canceled, error }

/// Service for managing one-time purchases via RevenueCat
///
/// Testing with RevenueCat Sandbox:
/// - iOS: Uses StoreKit Testing or Sandbox Apple ID automatically in debug builds
/// - Android: Uses Google Play test tracks or license testing
/// - Debug logs are enabled in debug mode to help troubleshoot
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

      // Enable verbose debug logging in debug mode for sandbox testing
      if (kDebugMode) {
        await Purchases.setLogLevel(LogLevel.verbose);
        debugPrint('💰 RevenueCat debug logging enabled for sandbox testing');
      }

      debugPrint('💰 Configuring RevenueCat...');
      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = null; // Anonymous user

      await Purchases.configure(configuration);

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
  /// Returns PurchaseResult indicating success, cancellation, or error
  Future<PurchaseResult> purchaseProduct(String productId) async {
    if (!_isInitialized) return PurchaseResult.error;

    try {
      final products = await Purchases.getProducts([productId]);
      if (products.isEmpty) {
        debugPrint('Product not found: $productId');
        return PurchaseResult.error;
      }

      final customerInfo = await Purchases.purchaseStoreProduct(products.first);
      _updateStateFromCustomerInfo(customerInfo);
      return PurchaseResult.success;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('User cancelled purchase');
        return PurchaseResult.canceled;
      } else {
        debugPrint('Purchase error: $e');
        return PurchaseResult.error;
      }
    } catch (e) {
      debugPrint('Purchase error: $e');
      return PurchaseResult.error;
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

  /// Check if running in sandbox/test mode
  Future<bool> isSandboxMode() async {
    if (!_isInitialized) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // In sandbox, the environment will be "sandbox"
      debugPrint('💰 RevenueCat environment: sandbox (debug build)');
      debugPrint('💰 Customer ID: ${customerInfo.originalAppUserId}');
      return kDebugMode;
    } catch (e) {
      debugPrint('💰 Error checking sandbox mode: $e');
      return false;
    }
  }

  /// Debug: Get available products for testing
  Future<List<StoreProduct>> debugGetProducts() async {
    if (!_isInitialized) return [];
    try {
      debugPrint(
        '💰 Using ${RevenueCatConfig.useTestProducts ? "TEST" : "PRODUCTION"} product IDs',
      );
      final products = await Purchases.getProducts(
        RevenueCatConfig.allProductIds,
      );
      for (final product in products) {
        debugPrint(
          '💰 Product: ${product.identifier} - ${product.priceString}',
        );
      }
      return products;
    } catch (e) {
      debugPrint('💰 Error getting products: $e');
      return [];
    }
  }

  /// Debug: Get current offerings for testing
  Future<Offerings?> debugGetOfferings() async {
    if (!_isInitialized) return null;
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('💰 Current offering: ${offerings.current?.identifier}');
      if (offerings.current != null) {
        for (final package in offerings.current!.availablePackages) {
          debugPrint(
            '💰 Package: ${package.identifier} - ${package.storeProduct.priceString}',
          );
        }
      }
      return offerings;
    } catch (e) {
      debugPrint('💰 Error getting offerings: $e');
      return null;
    }
  }

  /// Debug: Print customer info for testing
  Future<void> debugPrintCustomerInfo() async {
    if (!_isInitialized) return;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      debugPrint('💰 === Customer Info ===');
      debugPrint('💰 App User ID: ${customerInfo.originalAppUserId}');
      debugPrint(
        '💰 Non-subscription transactions: ${customerInfo.nonSubscriptionTransactions.length}',
      );
      for (final transaction in customerInfo.nonSubscriptionTransactions) {
        debugPrint(
          '💰   - ${transaction.productIdentifier} (${transaction.purchaseDate})',
        );
      }
      debugPrint('💰 Entitlements: ${customerInfo.entitlements.all.keys}');
      debugPrint('💰 ======================');
    } catch (e) {
      debugPrint('💰 Error getting customer info: $e');
    }
  }

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
