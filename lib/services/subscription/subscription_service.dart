// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/logging.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/revenuecat_config.dart';
import '../../models/subscription_models.dart';

/// Result of a purchase attempt
enum PurchaseResult { success, canceled, error }

/// Key for storing store-confirmed products in SharedPreferences
const String _storeConfirmedProductsKey = 'store_confirmed_products';

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

  /// Products that were confirmed owned by the store but couldn't be synced to RevenueCat
  /// (e.g., due to PaymentPendingError or anonymous user issues)
  /// These are preserved across refreshes AND app restarts to prevent losing unlock status
  final Set<String> _storeConfirmedProducts = {};

  /// Set when the most recent restore encountered PaymentPendingError —
  /// the store believes a purchase exists but RevenueCat has not accepted
  /// its receipt. Typical Android case: Google Play returns the purchase
  /// in queryPurchaseHistory but /v1/receipts returns 400 with
  /// PaymentPendingError. UI reads this flag to distinguish a "nothing to
  /// restore" outcome from a "store has a pending receipt" outcome so the
  /// user sees a helpful message instead of the misleading "none" state.
  bool _lastRestoreHadPendingPayment = false;

  /// Current purchase state
  PurchaseState get currentState => _currentState;

  /// True when the most recent `restorePurchases()` call encountered
  /// PaymentPendingError. Reset at the start of every restore attempt.
  bool get lastRestoreHadPendingPayment => _lastRestoreHadPendingPayment;

  /// Stream of purchase state changes
  Stream<PurchaseState> get stateStream => _stateController.stream;

  /// Whether RevenueCat SDK is initialized
  bool get isInitialized => _isInitialized;

  /// Load store-confirmed products from persistent storage
  Future<void> _loadStoreConfirmedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedProducts = prefs.getStringList(_storeConfirmedProductsKey);
      if (savedProducts != null && savedProducts.isNotEmpty) {
        _storeConfirmedProducts.addAll(savedProducts);
        AppLogging.subscriptions(
          '💰 Loaded store-confirmed products from storage: $_storeConfirmedProducts',
        );
      }
    } catch (e) {
      AppLogging.subscriptions(
        '💰 ⚠️ Error loading store-confirmed products: $e',
      );
    }
  }

  /// Save store-confirmed products to persistent storage
  Future<void> _saveStoreConfirmedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _storeConfirmedProductsKey,
        _storeConfirmedProducts.toList(),
      );
      AppLogging.subscriptions(
        '💰 Saved store-confirmed products to storage: $_storeConfirmedProducts',
      );
    } catch (e) {
      AppLogging.subscriptions(
        '💰 ⚠️ Error saving store-confirmed products: $e',
      );
    }
  }

  /// Add a store-confirmed product and persist it
  Future<void> _addStoreConfirmedProduct(String productId) async {
    _storeConfirmedProducts.add(productId);
    await _saveStoreConfirmedProducts();
  }

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

      // Enable debug logging in debug mode (not verbose — verbose dumps
      // full product JSON on every BillingClient query, flooding logcat).
      if (kDebugMode) {
        AppLogging.subscriptions('💰 Setting LogLevel.debug for debug mode...');
        await Purchases.setLogLevel(LogLevel.debug);
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

      // Load store-confirmed products from persistent storage
      // (products confirmed by Google Play but not synced to RevenueCat)
      AppLogging.subscriptions('💰 Loading store-confirmed products...');
      await _loadStoreConfirmedProducts();

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
    // IMPORTANT: Also include store-confirmed products that couldn't sync to RevenueCat
    final combinedPurchasedIds = {
      ...purchasedIds,
      ...entitlementProductIds,
      ...allPurchased,
      ..._storeConfirmedProducts, // Preserve store-confirmed products
    };

    if (_storeConfirmedProducts.isNotEmpty) {
      AppLogging.subscriptions(
        '💰 Store-confirmed products (preserved): $_storeConfirmedProducts',
      );
    }
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
  ///
  /// Error handling follows RevenueCat's official recommendations:
  /// - purchaseCancelledError (1): User cancelled, safe to ignore
  /// - storeProblemError (2): Store issue, RevenueCat auto-retries, user can retry
  /// - productAlreadyPurchasedError (6): Sync purchases to recognize ownership
  /// - invalidReceiptError (8): StoreKit race condition, sync after delay
  /// - networkError (10): Retryable by the user
  /// - paymentPendingError (20): Inform user purchase is pending
  Future<PurchaseResult> purchaseProduct(String productId) async {
    AppLogging.subscriptions('💳 purchaseProduct($productId) called');
    if (!_isInitialized) {
      AppLogging.subscriptions('💳 ❌ Not initialized');
      return PurchaseResult.error;
    }

    try {
      final products = await Purchases.getProducts([
        productId,
      ], productCategory: ProductCategory.nonSubscription);
      if (products.isEmpty) {
        AppLogging.subscriptions('💳 Product not found: $productId');
        return PurchaseResult.error;
      }

      AppLogging.subscriptions('💳 Attempting purchase...');
      final result = await Purchases.purchase(
        PurchaseParams.storeProduct(products.first),
      );
      AppLogging.subscriptions('💳 ✅ Purchase successful');
      _updateStateFromCustomerInfo(result.customerInfo);
      return PurchaseResult.success;
    } on PlatformException catch (e) {
      // Use RevenueCat's official helper to get strongly-typed error codes
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      AppLogging.subscriptions(
        '💳 PlatformException: code=${e.code}, errorCode=$errorCode, message=${e.message}',
      );

      // Handle StoreKit INVALID_RECEIPT bug (error code 7712)
      // This occurs when StoreKit hasn't updated the receipt yet but the transaction completed.
      // The fix is to wait briefly and sync purchases since the store owns the product.
      if (_isInvalidReceiptError(e)) {
        AppLogging.subscriptions(
          '💳 ⚠️ StoreKit INVALID_RECEIPT bug detected (7712) - transaction completed but receipt not ready',
        );
        return _handleInvalidReceiptError(productId);
      }

      // Handle errors using RevenueCat's recommended patterns
      switch (errorCode) {
        // User cancelled - safe to ignore
        case PurchasesErrorCode.purchaseCancelledError:
          AppLogging.subscriptions('💳 User cancelled purchase');
          return PurchaseResult.canceled;

        // Product already owned - sync to recognize ownership
        case PurchasesErrorCode.productAlreadyPurchasedError:
          AppLogging.subscriptions(
            '💳 Product already owned by store, syncing...',
          );
          return _handleAlreadyOwned(productId);

        // Store problem - RevenueCat auto-retries, user can retry too
        case PurchasesErrorCode.storeProblemError:
          AppLogging.subscriptions(
            '💳 Store problem (RevenueCat will auto-retry). User can retry.',
          );
          return PurchaseResult.error;

        // Network error - receipt validation failed but transaction may
        // have completed. Wait briefly for iOS networking to recover
        // (stale QUIC connections after App Store sheet), then sync.
        case PurchasesErrorCode.networkError:
          AppLogging.subscriptions(
            '💳 Network error - attempting recovery via syncPurchases...',
          );
          return _handleNetworkErrorRecovery(productId);

        // Payment pending - inform user
        case PurchasesErrorCode.paymentPendingError:
          AppLogging.subscriptions(
            '💳 Payment pending - purchase started but awaiting completion.',
          );
          // Add to store-confirmed as payment will eventually complete
          await _addStoreConfirmedProduct(productId);
          return PurchaseResult.success; // Optimistic - payment will complete

        // Invalid receipt - StoreKit race condition
        case PurchasesErrorCode.invalidReceiptError:
          AppLogging.subscriptions(
            '💳 Invalid receipt error - attempting recovery...',
          );
          return _handleInvalidReceiptError(productId);

        // All other errors
        default:
          // Also check message for ITEM_ALREADY_OWNED (Android specific)
          if (e.message?.contains('ITEM_ALREADY_OWNED') == true) {
            AppLogging.subscriptions(
              '💳 ITEM_ALREADY_OWNED detected in message, syncing...',
            );
            return _handleAlreadyOwned(productId);
          }
          AppLogging.subscriptions('💳 Purchase error: $errorCode - $e');
          return PurchaseResult.error;
      }
    } on PurchasesErrorCode catch (e) {
      // Direct PurchasesErrorCode thrown (less common path)
      AppLogging.subscriptions('💳 PurchasesErrorCode thrown directly: $e');
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        AppLogging.subscriptions('💳 User cancelled purchase');
        return PurchaseResult.canceled;
      } else if (e == PurchasesErrorCode.productAlreadyPurchasedError) {
        AppLogging.subscriptions(
          '💳 Product already owned (PurchasesErrorCode), syncing...',
        );
        return _handleAlreadyOwned(productId);
      } else if (e == PurchasesErrorCode.paymentPendingError) {
        AppLogging.subscriptions('💳 Payment pending');
        await _addStoreConfirmedProduct(productId);
        return PurchaseResult.success;
      } else {
        AppLogging.subscriptions('💳 Purchase error: $e');
        return PurchaseResult.error;
      }
    } catch (e) {
      final errorStr = e.toString();
      AppLogging.subscriptions('💳 General catch error: $errorStr');

      // Also check for INVALID_RECEIPT in generic exceptions
      if (errorStr.contains('INVALID_RECEIPT') ||
          errorStr.contains('7712') ||
          errorStr.contains('missing in the receipt')) {
        AppLogging.subscriptions(
          '💳 ⚠️ StoreKit INVALID_RECEIPT bug detected in generic exception',
        );
        return _handleInvalidReceiptError(productId);
      }

      AppLogging.subscriptions('💳 Purchase error: $e');
      return PurchaseResult.error;
    }
  }

  /// Check if an exception is the StoreKit INVALID_RECEIPT bug (error 7712)
  bool _isInvalidReceiptError(PlatformException e) {
    final message = e.message ?? '';
    final details = e.details?.toString() ?? '';
    return message.contains('INVALID_RECEIPT') ||
        message.contains('7712') ||
        message.contains('missing in the receipt') ||
        details.contains('INVALID_RECEIPT') ||
        details.contains('7712');
  }

  /// Handle the StoreKit INVALID_RECEIPT bug (error 7712)
  /// This is a known StoreKit race condition where the receipt isn't updated
  /// before RevenueCat tries to validate it, even though the transaction completed.
  /// Solution: Wait briefly and sync purchases since the store owns the product.
  /// Uses syncPurchases() instead of restorePurchases() to avoid OS sign-in prompts.
  Future<PurchaseResult> _handleInvalidReceiptError(String productId) async {
    AppLogging.subscriptions('💳 _handleInvalidReceiptError($productId)');
    AppLogging.subscriptions(
      '💳 Waiting 2 seconds for StoreKit receipt to update...',
    );

    // Wait for StoreKit to update the receipt
    await Future<void>.delayed(const Duration(seconds: 2));

    // Use syncPurchases (not restorePurchases) to avoid OS-level sign-in prompts
    // This programmatically syncs the receipt with RevenueCat backend
    AppLogging.subscriptions(
      '💳 Calling syncPurchases() after delay (no OS prompts)...',
    );
    try {
      await Purchases.syncPurchases();
      AppLogging.subscriptions('💳 syncPurchases() completed');

      // Refresh customer info to get updated state
      final customerInfo = await Purchases.getCustomerInfo();
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      AppLogging.subscriptions('💳 syncPurchases() error: $e');
    }

    if (_currentState.hasPurchased(productId)) {
      AppLogging.subscriptions(
        '💳 ✅ Product $productId now recognized after INVALID_RECEIPT recovery',
      );
      return PurchaseResult.success;
    }

    // If sync didn't work, the purchase exists in the store but RevenueCat
    // can't sync it. Force-add it to store-confirmed products.
    AppLogging.subscriptions(
      '💳 ⚠️ Product still not in RevenueCat after sync, adding to store-confirmed',
    );
    await _addStoreConfirmedProduct(productId);

    final newIds = {..._currentState.purchasedProductIds, productId};
    _updateState(_currentState.copyWith(purchasedProductIds: newIds));

    AppLogging.subscriptions(
      '💳 ✅ Manually added $productId after INVALID_RECEIPT recovery',
    );
    return PurchaseResult.success;
  }

  /// Handle network errors during purchase.
  ///
  /// The App Store transaction typically completes before the receipt is
  /// sent to RevenueCat. When the QUIC connection goes stale (common after
  /// the App Store payment sheet backgrounds the app), the receipt POST
  /// fails with `-1005 "The network connection was lost."`.
  ///
  /// Recovery: wait for iOS networking to settle, then sync purchases
  /// to pick up the completed transaction.
  Future<PurchaseResult> _handleNetworkErrorRecovery(String productId) async {
    AppLogging.subscriptions(
      '💳 _handleNetworkErrorRecovery($productId) — waiting for network...',
    );

    // Brief delay for iOS to tear down the stale QUIC connection and
    // establish a fresh one.
    await Future<void>.delayed(const Duration(seconds: 2));

    try {
      await Purchases.syncPurchases();
      AppLogging.subscriptions(
        '💳 syncPurchases() completed after network recovery',
      );

      final customerInfo = await Purchases.getCustomerInfo();
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      AppLogging.subscriptions('💳 syncPurchases() failed during recovery: $e');
    }

    if (_currentState.hasPurchased(productId)) {
      AppLogging.subscriptions(
        '💳 ✅ Product $productId recovered after network error',
      );
      return PurchaseResult.success;
    }

    // Transaction may not have completed (user cancelled at App Store
    // before payment went through). Report error so the UI shows the
    // failure message and the user can retry.
    AppLogging.subscriptions(
      '💳 ❌ Product $productId not found after network recovery — '
      'transaction may not have completed',
    );
    return PurchaseResult.error;
  }

  /// Handle the case where a product is already owned by the store
  /// but not recognized by RevenueCat
  Future<PurchaseResult> _handleAlreadyOwned(String productId) async {
    AppLogging.subscriptions('💳 _handleAlreadyOwned($productId)');

    // Use syncPurchases (not restorePurchases) to avoid OS-level sign-in prompts
    // The user just authenticated with the store, so we don't need another sign-in
    AppLogging.subscriptions(
      '💳 Calling syncPurchases() to sync with store (no OS prompts)...',
    );
    try {
      await Purchases.syncPurchases();
      AppLogging.subscriptions('💳 syncPurchases() completed');

      // Refresh customer info to get updated state
      final customerInfo = await Purchases.getCustomerInfo();
      _updateStateFromCustomerInfo(customerInfo);
    } catch (e) {
      AppLogging.subscriptions('💳 syncPurchases() error: $e');
    }

    // Check if the product is now recognized
    if (_currentState.hasPurchased(productId)) {
      AppLogging.subscriptions(
        '💳 ✅ Product $productId now recognized after sync',
      );
      return PurchaseResult.success;
    }

    // If restore didn't work, the purchase exists in Google Play but
    // RevenueCat can't sync it (likely because user is signed out/anonymous,
    // or there's a PaymentPendingError).
    // Force-add it to store-confirmed products so it persists across refreshes AND app restarts.
    AppLogging.subscriptions(
      '💳 ⚠️ Product $productId still not recognized after restore',
    );
    AppLogging.subscriptions(
      '💳 Store confirmed ownership - adding to persistent store-confirmed set',
    );

    // Add to store-confirmed products (persists across refreshes AND app restarts)
    await _addStoreConfirmedProduct(productId);
    AppLogging.subscriptions(
      '💳 Store-confirmed products: $_storeConfirmedProducts',
    );

    // Add the product to the current state
    final newIds = {..._currentState.purchasedProductIds, productId};
    _updateState(_currentState.copyWith(purchasedProductIds: newIds));

    AppLogging.subscriptions('💳 ✅ Manually added $productId to state');
    AppLogging.subscriptions(
      '💳 Current state: ${_currentState.purchasedProductIds}',
    );

    return PurchaseResult.success;
  }

  /// Fallback handler for restore errors - tries to get cached customer info
  /// Used when restorePurchases() fails with retryable errors
  Future<bool> _handleRestoreFallback() async {
    AppLogging.subscriptions('💰 ⚠️ Falling back to getCustomerInfo()...');
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // IMPORTANT: Update state so Riverpod gets the current entitlements
      _updateStateFromCustomerInfo(customerInfo);

      final hasActiveEntitlements = customerInfo.entitlements.all.values.any(
        (e) => e.isActive,
      );
      final hasPurchasedProducts =
          customerInfo.allPurchasedProductIdentifiers.isNotEmpty;
      // Also check store-confirmed products
      final hasStoreConfirmed = _storeConfirmedProducts.isNotEmpty;

      AppLogging.subscriptions('💰 ⚠️ Fallback getCustomerInfo succeeded');
      AppLogging.subscriptions(
        '💰 ⚠️ hasActiveEntitlements: $hasActiveEntitlements',
      );
      AppLogging.subscriptions(
        '💰 ⚠️ hasPurchasedProducts: $hasPurchasedProducts',
      );
      AppLogging.subscriptions('💰 ⚠️ hasStoreConfirmed: $hasStoreConfirmed');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      return hasActiveEntitlements || hasPurchasedProducts || hasStoreConfirmed;
    } catch (fallbackError) {
      AppLogging.subscriptions(
        '💰 ❌ Fallback getCustomerInfo also failed: $fallbackError',
      );
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      return false;
    }
  }

  /// Programmatically sync the device store's purchase tokens with RevenueCat
  /// without invoking the OS restore prompt. Safe to call at any time;
  /// callers should not depend on its return value for entitlement decisions
  /// (use the resulting [currentState] / [stateStream] instead).
  ///
  /// On Android with Play Billing 8 this is the recommended call to make
  /// before/after [logIn] so anonymous-tied tokens get re-sent under the
  /// identified RC customer. Returns false on error so the bootstrap flow
  /// can decide whether to surface anything; never throws.
  Future<bool> syncPurchases() async {
    if (!_isInitialized) {
      AppLogging.subscriptions(
        '💰 syncPurchases skipped — RevenueCat not initialized',
      );
      return false;
    }
    try {
      AppLogging.subscriptions('💰 syncPurchases — START');
      await Purchases.syncPurchases();
      final customerInfo = await Purchases.getCustomerInfo();
      _updateStateFromCustomerInfo(customerInfo);
      AppLogging.subscriptions(
        '💰 syncPurchases — DONE customerId=${customerInfo.originalAppUserId} '
        'products=${customerInfo.allPurchasedProductIdentifiers}',
      );
      return true;
    } catch (e, stackTrace) {
      AppLogging.subscriptions('💰 ❌ syncPurchases error: $e');
      AppLogging.subscriptions('💰 Stack: $stackTrace');
      return false;
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

    // Reset pending-payment flag at the start of every attempt so the UI
    // only reacts to the outcome of THIS restore, not a stale prior one.
    _lastRestoreHadPendingPayment = false;

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
      AppLogging.subscriptions(
        '💰   storeConfirmedProducts: $_storeConfirmedProducts',
      );

      // Return true if ANY purchases were found from any source
      // Include store-confirmed products that may not be synced to RevenueCat
      final hasStoreConfirmed = _storeConfirmedProducts.isNotEmpty;
      final hasPurchases =
          hasTransactions ||
          hasEntitlements ||
          hasPurchasedProducts ||
          hasStoreConfirmed;
      AppLogging.subscriptions('💰   Final hasPurchases: $hasPurchases');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );
      AppLogging.subscriptions('💰 RESTORE PURCHASES - END');
      AppLogging.subscriptions(
        '💰 ═══════════════════════════════════════════════',
      );

      return hasPurchases;
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      AppLogging.subscriptions('💰 ❌ RESTORE ERROR (PlatformException):');
      AppLogging.subscriptions('💰   Code: ${e.code}, ErrorCode: $errorCode');
      AppLogging.subscriptions('💰   Message: ${e.message}');
      AppLogging.subscriptions('💰   Details: ${e.details}');

      // Handle errors using RevenueCat's recommended patterns
      switch (errorCode) {
        // Payment pending - fall back to getCustomerInfo
        case PurchasesErrorCode.paymentPendingError:
          AppLogging.subscriptions(
            '💰 ⚠️ PaymentPendingError detected (old pending purchase)',
          );
          _lastRestoreHadPendingPayment = true;
          return _handleRestoreFallback();

        // Network error - retryable, but try fallback first
        case PurchasesErrorCode.networkError:
          AppLogging.subscriptions(
            '💰 ⚠️ Network error - trying cached customer info...',
          );
          return _handleRestoreFallback();

        // Store problem - RevenueCat auto-retries, try fallback
        case PurchasesErrorCode.storeProblemError:
          AppLogging.subscriptions(
            '💰 ⚠️ Store problem - trying cached customer info...',
          );
          return _handleRestoreFallback();

        default:
          AppLogging.subscriptions(
            '💰 ═══════════════════════════════════════════════',
          );
          return false;
      }
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
