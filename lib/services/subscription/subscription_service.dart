import '../../core/logging.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
    AppLogging.subscriptions(
      '💰 ═══════════════════════════════════════════════',
    );
    AppLogging.subscriptions('💰 REVENUECAT INITIALIZE - START');
    AppLogging.subscriptions(
      '💰 ═══════════════════════════════════════════════',
    );
    AppLogging.subscriptions(
      '💰 Platform: ${Platform.isIOS ? "iOS" : "Android"}',
    );
    AppLogging.subscriptions('💰 Already initialized: $_isInitialized');

    if (_isInitialized) {
      AppLogging.subscriptions('💰 ⚠️ Already initialized, skipping');
      return;
    }

    try {
      final apiKey = RevenueCatConfig.currentPlatformApiKey;
      AppLogging.subscriptions('💰 API Key present: ${apiKey.isNotEmpty}');
      AppLogging.subscriptions(
        '💰 API Key prefix: ${apiKey.length > 10 ? apiKey.substring(0, 10) : "TOO_SHORT"}...',
      );

      if (apiKey.isEmpty) {
        AppLogging.subscriptions(
          '💰 ❌ RevenueCat API key not configured for ${Platform.isIOS ? "iOS" : "Android"}',
        );
        return;
      }

      // Enable verbose debug logging in debug mode for sandbox testing
      if (kDebugMode) {
        AppLogging.subscriptions(
          '💰 Setting LogLevel.verbose for debug mode...',
        );
        await Purchases.setLogLevel(LogLevel.verbose);
        AppLogging.subscriptions(
          '💰 RevenueCat debug logging enabled for sandbox testing',
        );
      }

      AppLogging.subscriptions(
        '💰 Configuring RevenueCat with anonymous user...',
      );
      final configuration = PurchasesConfiguration(apiKey)
        ..appUserID = null; // Anonymous user

      await Purchases.configure(configuration);
      AppLogging.subscriptions('💰 Purchases.configure() completed');

      // Listen for customer info updates
      AppLogging.subscriptions('💰 Adding customer info update listener...');
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);

      _isInitialized = true;
      AppLogging.subscriptions('💰 ✅ RevenueCat SDK initialized successfully');

      // Get initial customer info
      AppLogging.subscriptions('💰 Fetching initial customer info...');
      await refreshPurchases();
      AppLogging.subscriptions('💰 Initial customer info fetched');
      AppLogging.subscriptions(
        '💰 Current state: ${_currentState.purchasedProductIds}',
      );
    } catch (e, stackTrace) {
      AppLogging.subscriptions('💰 ❌ Error initializing RevenueCat:');
      AppLogging.subscriptions('💰   Error: $e');
      AppLogging.subscriptions('💰   Stack: $stackTrace');
    }
    AppLogging.subscriptions(
      '💰 ═══════════════════════════════════════════════',
    );
    AppLogging.subscriptions('💰 REVENUECAT INITIALIZE - END');
    AppLogging.subscriptions(
      '💰 ═══════════════════════════════════════════════',
    );
  }

  /// Handle customer info updates from RevenueCat
  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    AppLogging.subscriptions('💰 Customer info update received from listener');
    _updateStateFromCustomerInfo(customerInfo);
  }

  /// Update local state from RevenueCat customer info
  void _updateStateFromCustomerInfo(CustomerInfo customerInfo) {
    AppLogging.subscriptions('💰 _updateStateFromCustomerInfo called');

    // Get non-consumable purchases
    final purchasedIds = customerInfo.nonSubscriptionTransactions
        .map((t) => t.productIdentifier)
        .toSet();

    AppLogging.subscriptions(
      '💰 Extracted purchasedIds from nonSubscriptionTransactions: $purchasedIds',
    );

    // Also check entitlements for active purchases
    final entitlementProductIds = customerInfo.entitlements.all.values
        .where((e) => e.isActive)
        .map((e) => e.productIdentifier)
        .toSet();
    AppLogging.subscriptions(
      '💰 Extracted productIds from active entitlements: $entitlementProductIds',
    );

    // Also check all purchased product identifiers
    final allPurchased = customerInfo.allPurchasedProductIdentifiers;
    AppLogging.subscriptions(
      '💰 All purchased product identifiers: $allPurchased',
    );

    // Combine all sources of purchased products
    final combinedPurchasedIds = {
      ...purchasedIds,
      ...entitlementProductIds,
      ...allPurchased,
    };
    AppLogging.subscriptions(
      '💰 Combined purchased IDs: $combinedPurchasedIds',
    );

    final previousState = _currentState;
    final newState = PurchaseState(
      purchasedProductIds: combinedPurchasedIds,
      customerId: customerInfo.originalAppUserId,
    );

    AppLogging.subscriptions('💰 STATE TRANSITION:');
    AppLogging.subscriptions(
      '💰   Previous: ${previousState.purchasedProductIds}',
    );
    AppLogging.subscriptions('💰   New: ${newState.purchasedProductIds}');
    AppLogging.subscriptions('💰   Customer ID: ${newState.customerId}');

    _updateState(newState);
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
      final products = await Purchases.getProducts([
        productId,
      ], productCategory: ProductCategory.nonSubscription);
      if (products.isEmpty) {
        AppLogging.subscriptions('💳 Product not found: $productId');
        return PurchaseResult.error;
      }

      final result = await Purchases.purchase(
        PurchaseParams.storeProduct(products.first),
      );
      _updateStateFromCustomerInfo(result.customerInfo);
      return PurchaseResult.success;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        AppLogging.subscriptions('User cancelled purchase');
        return PurchaseResult.canceled;
      } else {
        AppLogging.subscriptions('Purchase error: $e');
        return PurchaseResult.error;
      }
    } catch (e) {
      AppLogging.subscriptions('Purchase error: $e');
      return PurchaseResult.error;
    }
  }

  /// Refresh purchases from RevenueCat
  Future<void> refreshPurchases() async {
    AppLogging.subscriptions(
      '💰 refreshPurchases() called, isInitialized: $_isInitialized',
    );
    if (!_isInitialized) {
      AppLogging.subscriptions(
        '💰 ❌ refreshPurchases skipped - not initialized',
      );
      return;
    }

    try {
      AppLogging.subscriptions('💰 Calling Purchases.getCustomerInfo()...');
      final customerInfo = await Purchases.getCustomerInfo();
      AppLogging.subscriptions(
        '💰 ✅ Got customer info: ${customerInfo.originalAppUserId}',
      );
      AppLogging.subscriptions(
        '💰   nonSubscriptionTransactions: ${customerInfo.nonSubscriptionTransactions.length}',
      );
      AppLogging.subscriptions(
        '💰   allPurchasedProductIdentifiers: ${customerInfo.allPurchasedProductIdentifiers}',
      );
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e, stackTrace) {
      AppLogging.subscriptions('💰 ❌ Error refreshing purchases: $e');
      AppLogging.subscriptions('💰 Stack: $stackTrace');
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    AppLogging.subscriptions(
      '💰 ═══════════════════════════════════════════════',
    );
    AppLogging.subscriptions('💰 RESTORE PURCHASES - START');
    AppLogging.subscriptions(
      '💰 ═══════════════════════════════════════════════',
    );
    AppLogging.subscriptions('💰 isInitialized: $_isInitialized');

    if (!_isInitialized) {
      AppLogging.subscriptions(
        '💰 ❌ RESTORE FAILED: RevenueCat not initialized',
      );
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      return false;
    }

    try {
      AppLogging.subscriptions('💰 Calling Purchases.restorePurchases()...');
      final stopwatch = Stopwatch()..start();
      final customerInfo = await Purchases.restorePurchases();
      stopwatch.stop();

      AppLogging.subscriptions(
        '💰 ✅ Restore call completed in ${stopwatch.elapsedMilliseconds}ms',
      );
      AppLogging.subscriptions(
        '💰 ───────────────────────────────────────────────',
      );
      AppLogging.subscriptions('💰 CUSTOMER INFO RECEIVED:');
      AppLogging.subscriptions(
        '💰   Original App User ID: ${customerInfo.originalAppUserId}',
      );
      AppLogging.subscriptions('💰   First Seen: ${customerInfo.firstSeen}');
      AppLogging.subscriptions(
        '💰   Request Date: ${customerInfo.requestDate}',
      );
      AppLogging.subscriptions(
        '💰   Management URL: ${customerInfo.managementURL}',
      );

      AppLogging.subscriptions(
        '💰 ───────────────────────────────────────────────',
      );
      AppLogging.subscriptions(
        '💰 NON-SUBSCRIPTION TRANSACTIONS (${customerInfo.nonSubscriptionTransactions.length}):',
      );
      if (customerInfo.nonSubscriptionTransactions.isEmpty) {
        AppLogging.subscriptions('💰   (none found)');
      } else {
        for (final transaction in customerInfo.nonSubscriptionTransactions) {
          AppLogging.subscriptions(
            '💰   • Product: ${transaction.productIdentifier}',
          );
          AppLogging.subscriptions(
            '💰     Purchase Date: ${transaction.purchaseDate}',
          );
          AppLogging.subscriptions(
            '💰     Transaction ID: ${transaction.transactionIdentifier}',
          );
        }
      }

      AppLogging.subscriptions(
        '💰 ───────────────────────────────────────────────',
      );
      AppLogging.subscriptions(
        '💰 ENTITLEMENTS (${customerInfo.entitlements.all.length}):',
      );
      if (customerInfo.entitlements.all.isEmpty) {
        AppLogging.subscriptions('💰   (none found)');
      } else {
        for (final entry in customerInfo.entitlements.all.entries) {
          final entitlement = entry.value;
          AppLogging.subscriptions('💰   • ${entry.key}:');
          AppLogging.subscriptions('💰     isActive: ${entitlement.isActive}');
          AppLogging.subscriptions(
            '💰     productIdentifier: ${entitlement.productIdentifier}',
          );
          AppLogging.subscriptions(
            '💰     latestPurchaseDate: ${entitlement.latestPurchaseDate}',
          );
          AppLogging.subscriptions(
            '💰     expirationDate: ${entitlement.expirationDate}',
          );
          AppLogging.subscriptions('💰     store: ${entitlement.store}');
          AppLogging.subscriptions(
            '💰     isSandbox: ${entitlement.isSandbox}',
          );
        }
      }

      AppLogging.subscriptions(
        '💰 ───────────────────────────────────────────────',
      );
      AppLogging.subscriptions(
        '💰 ACTIVE SUBSCRIPTIONS (${customerInfo.activeSubscriptions.length}):',
      );
      if (customerInfo.activeSubscriptions.isEmpty) {
        AppLogging.subscriptions('💰   (none found)');
      } else {
        for (final sub in customerInfo.activeSubscriptions) {
          AppLogging.subscriptions('💰   • $sub');
        }
      }

      AppLogging.subscriptions(
        '💰 ───────────────────────────────────────────────',
      );
      AppLogging.subscriptions(
        '💰 ALL PURCHASED PRODUCT IDS (${customerInfo.allPurchasedProductIdentifiers.length}):',
      );
      if (customerInfo.allPurchasedProductIdentifiers.isEmpty) {
        AppLogging.subscriptions('💰   (none found)');
      } else {
        for (final productId in customerInfo.allPurchasedProductIdentifiers) {
          AppLogging.subscriptions('💰   • $productId');
        }
      }

      AppLogging.subscriptions(
        '💰 ───────────────────────────────────────────────',
      );
      _updateStateFromCustomerInfo(customerInfo);

      final hasTransactions =
          customerInfo.nonSubscriptionTransactions.isNotEmpty;
      final hasEntitlements = customerInfo.entitlements.all.values.any(
        (e) => e.isActive,
      );
      final hasPurchasedProducts =
          customerInfo.allPurchasedProductIdentifiers.isNotEmpty;

      AppLogging.subscriptions('💰 RESTORE RESULT ANALYSIS:');
      AppLogging.subscriptions(
        '💰   hasNonSubscriptionTransactions: $hasTransactions',
      );
      AppLogging.subscriptions('💰   hasActiveEntitlements: $hasEntitlements');
      AppLogging.subscriptions(
        '💰   hasPurchasedProducts: $hasPurchasedProducts',
      );
      AppLogging.subscriptions('💰   Returning: $hasTransactions');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      AppLogging.subscriptions('💰 RESTORE PURCHASES - END');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );

      return hasTransactions;
    } on PlatformException catch (e) {
      AppLogging.subscriptions('💰 ❌ RESTORE ERROR (PlatformException):');
      AppLogging.subscriptions('💰   Code: ${e.code}');
      AppLogging.subscriptions('💰   Message: ${e.message}');
      AppLogging.subscriptions('💰   Details: ${e.details}');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      return false;
    } catch (e, stackTrace) {
      AppLogging.subscriptions('💰 ❌ RESTORE ERROR (Exception):');
      AppLogging.subscriptions('💰   Type: ${e.runtimeType}');
      AppLogging.subscriptions('💰   Error: $e');
      AppLogging.subscriptions('💰   Stack: $stackTrace');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      return false;
    }
  }

  /// Log in user (for cross-device syncing)
  /// This associates the RevenueCat customer with a specific user ID (e.g., Firebase UID)
  /// which ensures purchases are tracked consistently across app reinstalls and devices.
  Future<bool> logIn(String userId) async {
    AppLogging.subscriptions(
      '💰 ═══════════════════════════════════════════════',
    );
    AppLogging.subscriptions('💰 REVENUECAT LOGIN - START');
    AppLogging.subscriptions(
      '💰 ═══════════════════════════════════════════════',
    );
    AppLogging.subscriptions('💰 User ID to log in: $userId');
    AppLogging.subscriptions('💰 isInitialized: $_isInitialized');

    if (!_isInitialized) {
      AppLogging.subscriptions('💰 ❌ LOGIN FAILED: RevenueCat not initialized');
      return false;
    }

    try {
      // Get current customer ID before login
      final currentInfo = await Purchases.getCustomerInfo();
      AppLogging.subscriptions(
        '💰 Current customer ID: ${currentInfo.originalAppUserId}',
      );

      // Check if already logged in as this user
      if (currentInfo.originalAppUserId == userId) {
        AppLogging.subscriptions('💰 ✅ Already logged in as this user');
        AppLogging.subscriptions(
          '💰 ═══════════════════════════════════════════════',
        );
        return true;
      }

      AppLogging.subscriptions('💰 Calling Purchases.logIn($userId)...');
      final result = await Purchases.logIn(userId);

      AppLogging.subscriptions('💰 ✅ Login successful');
      AppLogging.subscriptions(
        '💰   New customer ID: ${result.customerInfo.originalAppUserId}',
      );
      AppLogging.subscriptions('💰   Created new customer: ${result.created}');
      AppLogging.subscriptions(
        '💰   nonSubscriptionTransactions: ${result.customerInfo.nonSubscriptionTransactions.length}',
      );
      AppLogging.subscriptions(
        '💰   allPurchasedProductIdentifiers: ${result.customerInfo.allPurchasedProductIdentifiers}',
      );

      _updateStateFromCustomerInfo(result.customerInfo);

      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      AppLogging.subscriptions('💰 REVENUECAT LOGIN - END');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      return true;
    } catch (e, stackTrace) {
      AppLogging.subscriptions('💰 ❌ LOGIN ERROR: $e');
      AppLogging.subscriptions('💰 Stack: $stackTrace');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      return false;
    }
  }

  /// Log out user
  Future<void> logOut() async {
    AppLogging.subscriptions('💰 Logging out from RevenueCat...');
    if (!_isInitialized) {
      AppLogging.subscriptions(
        '💰 ❌ LOGOUT FAILED: RevenueCat not initialized',
      );
      return;
    }

    try {
      final customerInfo = await Purchases.logOut();
      AppLogging.subscriptions(
        '💰 ✅ Logged out, now using: ${customerInfo.originalAppUserId}',
      );
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      AppLogging.subscriptions('💰 ❌ Error logging out: $e');
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
      AppLogging.subscriptions(
        '💰 RevenueCat environment: sandbox (debug build)',
      );
      AppLogging.subscriptions(
        '💰 Customer ID: ${customerInfo.originalAppUserId}',
      );
      return kDebugMode;
    } catch (e) {
      AppLogging.subscriptions('💰 Error checking sandbox mode: $e');
      return false;
    }
  }

  /// Debug: Get available products for testing
  Future<List<StoreProduct>> debugGetProducts() async {
    if (!_isInitialized) return [];
    try {
      AppLogging.subscriptions('💰 Fetching products from RevenueCat');
      final products = await Purchases.getProducts(
        RevenueCatConfig.allProductIds,
        productCategory: ProductCategory.nonSubscription,
      );
      for (final product in products) {
        AppLogging.subscriptions(
          '💰 Product: ${product.identifier} - ${product.priceString}',
        );
      }
      return products;
    } catch (e) {
      AppLogging.subscriptions('💰 Error getting products: $e');
      return [];
    }
  }

  /// Debug: Get current offerings for testing
  Future<Offerings?> debugGetOfferings() async {
    if (!_isInitialized) return null;
    try {
      final offerings = await Purchases.getOfferings();
      AppLogging.subscriptions(
        '💰 Current offering: ${offerings.current?.identifier}',
      );
      if (offerings.current != null) {
        for (final package in offerings.current!.availablePackages) {
          AppLogging.subscriptions(
            '💰 Package: ${package.identifier} - ${package.storeProduct.priceString}',
          );
        }
      }
      return offerings;
    } catch (e) {
      AppLogging.subscriptions('💰 Error getting offerings: $e');
      return null;
    }
  }

  /// Debug: Print customer info for testing
  Future<void> debugPrintCustomerInfo() async {
    if (!_isInitialized) return;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      AppLogging.subscriptions('💰 === Customer Info ===');
      AppLogging.subscriptions(
        '💰 App User ID: ${customerInfo.originalAppUserId}',
      );
      AppLogging.subscriptions(
        '💰 Non-subscription transactions: ${customerInfo.nonSubscriptionTransactions.length}',
      );
      for (final transaction in customerInfo.nonSubscriptionTransactions) {
        AppLogging.subscriptions(
          '💰   - ${transaction.productIdentifier} (${transaction.purchaseDate})',
        );
      }
      AppLogging.subscriptions(
        '💰 Entitlements: ${customerInfo.entitlements.all.keys}',
      );
      AppLogging.subscriptions('💰 ======================');
    } catch (e) {
      AppLogging.subscriptions('💰 Error getting customer info: $e');
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
