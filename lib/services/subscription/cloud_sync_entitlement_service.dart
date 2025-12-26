import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';

/// Entitlement states for cloud sync feature
enum CloudSyncEntitlementState {
  /// User has active subscription
  active,

  /// User is in grace period (billing issue but still has access)
  gracePeriod,

  /// User is grandfathered (used cloud sync before cutoff)
  grandfathered,

  /// Subscription expired, read-only access
  expired,

  /// Never subscribed, no access
  none,
}

/// Result of entitlement check
class CloudSyncEntitlement {
  final CloudSyncEntitlementState state;
  final DateTime? expiresAt;
  final DateTime? gracePeriodEndsAt;
  final String? productId;
  final bool canWrite;
  final bool canRead;

  const CloudSyncEntitlement({
    required this.state,
    this.expiresAt,
    this.gracePeriodEndsAt,
    this.productId,
    required this.canWrite,
    required this.canRead,
  });

  /// No access at all
  static const none = CloudSyncEntitlement(
    state: CloudSyncEntitlementState.none,
    canWrite: false,
    canRead: false,
  );

  /// Full access (active, grace period, or grandfathered)
  bool get hasFullAccess =>
      state == CloudSyncEntitlementState.active ||
      state == CloudSyncEntitlementState.gracePeriod ||
      state == CloudSyncEntitlementState.grandfathered;

  /// Read-only access (expired but was previously subscribed)
  bool get hasReadOnlyAccess =>
      state == CloudSyncEntitlementState.expired && canRead;

  @override
  String toString() =>
      'CloudSyncEntitlement(state: $state, canWrite: $canWrite, canRead: $canRead)';
}

/// Service to manage cloud sync entitlements
/// Combines RevenueCat subscription status with Firebase grandfathering
class CloudSyncEntitlementService {
  static const String _entitlementId = 'Socialmesh Pro';
  static const String _cacheKey = 'cloud_sync_entitlement_cache';
  static const String _cacheTimestampKey = 'cloud_sync_entitlement_timestamp';

  /// Cutoff date for grandfathering - users who used cloud sync before this date
  /// get permanent free access
  static final DateTime grandfatherCutoffDate = DateTime(2025, 2, 1);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CloudSyncEntitlement _cachedEntitlement = CloudSyncEntitlement.none;
  StreamSubscription<DocumentSnapshot>? _firestoreSubscription;
  StreamSubscription<User?>? _authSubscription;

  final _entitlementController =
      StreamController<CloudSyncEntitlement>.broadcast();

  /// Stream of entitlement changes
  Stream<CloudSyncEntitlement> get entitlementStream =>
      _entitlementController.stream;

  /// Current cached entitlement
  CloudSyncEntitlement get currentEntitlement => _cachedEntitlement;

  CloudSyncEntitlementService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  /// Initialize the service and start listening for changes
  Future<void> initialize() async {
    AppLogging.subscriptions('☁️ CloudSyncEntitlementService initializing...');

    // Load cached entitlement first for instant UI
    await _loadCachedEntitlement();

    // Listen to RevenueCat customer info changes
    Purchases.addCustomerInfoUpdateListener(_onCustomerInfoUpdate);

    // Listen to Firebase Auth changes
    _authSubscription = _auth.authStateChanges().listen(
      _onAuthStateChange,
      onError: (error) {
        AppLogging.subscriptions('☁️ Auth state listener error: $error');
      },
    );

    // Do initial refresh
    await refreshEntitlement();

    AppLogging.subscriptions(
      '☁️ CloudSyncEntitlementService initialized: $_cachedEntitlement',
    );
  }

  /// Refresh entitlement from all sources
  Future<CloudSyncEntitlement> refreshEntitlement() async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.subscriptions('☁️ No user signed in, no cloud sync access');
      _updateEntitlement(CloudSyncEntitlement.none);
      return _cachedEntitlement;
    }

    try {
      // Check grandfathering status first (Firebase)
      final grandfathered = await _checkGrandfathered(user.uid);
      if (grandfathered) {
        AppLogging.subscriptions('☁️ User is grandfathered, full access');
        _updateEntitlement(
          const CloudSyncEntitlement(
            state: CloudSyncEntitlementState.grandfathered,
            canWrite: true,
            canRead: true,
          ),
        );
        return _cachedEntitlement;
      }

      // Check RevenueCat subscription
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = _resolveEntitlementFromCustomerInfo(customerInfo);

      _updateEntitlement(entitlement);
      return _cachedEntitlement;
    } catch (e) {
      AppLogging.subscriptions('☁️ Error refreshing entitlement: $e');
      // Return cached on error
      return _cachedEntitlement;
    }
  }

  /// Check if user is grandfathered based on their cloud sync usage history
  Future<bool> _checkGrandfathered(String uid) async {
    try {
      // First check user_entitlements collection
      final entitlementDoc = await _firestore
          .collection('user_entitlements')
          .doc(uid)
          .get();

      if (entitlementDoc.exists) {
        final data = entitlementDoc.data()!;
        if (data['cloud_sync'] == 'grandfathered') {
          return true;
        }
      }

      // Check if user used cloud sync before cutoff
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final cloudSyncUsedAt = data['cloud_sync_used_at'] as Timestamp?;
        if (cloudSyncUsedAt != null &&
            cloudSyncUsedAt.toDate().isBefore(grandfatherCutoffDate)) {
          // Mark as grandfathered for future checks
          await _markAsGrandfathered(uid);
          return true;
        }
      }

      return false;
    } catch (e) {
      AppLogging.subscriptions('☁️ Error checking grandfathered status: $e');
      return false;
    }
  }

  /// Mark user as grandfathered in Firestore
  Future<void> _markAsGrandfathered(String uid) async {
    try {
      await _firestore.collection('user_entitlements').doc(uid).set({
        'cloud_sync': 'grandfathered',
        'source': 'legacy',
        'expires_at': null,
        'revenuecat_app_user_id': uid,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      AppLogging.subscriptions('☁️ Marked user as grandfathered: $uid');
    } catch (e) {
      AppLogging.subscriptions('☁️ Error marking grandfathered: $e');
    }
  }

  /// Resolve entitlement from RevenueCat CustomerInfo
  CloudSyncEntitlement _resolveEntitlementFromCustomerInfo(
    CustomerInfo customerInfo,
  ) {
    // Extensive debug logging for troubleshooting
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('☁️ [ENTITLEMENT] Resolving entitlement from CustomerInfo...');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint(
      '☁️ [ENTITLEMENT] Looking for entitlement ID: "$_entitlementId"',
    );
    debugPrint(
      '☁️ [ENTITLEMENT] Customer ID: ${customerInfo.originalAppUserId}',
    );
    debugPrint(
      '☁️ [ENTITLEMENT] All entitlement keys: ${customerInfo.entitlements.all.keys.toList()}',
    );
    debugPrint(
      '☁️ [ENTITLEMENT] Active entitlement keys: ${customerInfo.entitlements.active.keys.toList()}',
    );
    debugPrint(
      '☁️ [ENTITLEMENT] Active subscriptions: ${customerInfo.activeSubscriptions}',
    );
    debugPrint(
      '☁️ [ENTITLEMENT] All purchased products: ${customerInfo.allPurchasedProductIdentifiers}',
    );

    // List all entitlements with details
    for (final entry in customerInfo.entitlements.all.entries) {
      debugPrint('');
      debugPrint('   📋 Entitlement "${entry.key}":');
      debugPrint('      - isActive: ${entry.value.isActive}');
      debugPrint('      - productIdentifier: ${entry.value.productIdentifier}');
      debugPrint('      - willRenew: ${entry.value.willRenew}');
      debugPrint('      - periodType: ${entry.value.periodType}');
      debugPrint('      - expirationDate: ${entry.value.expirationDate}');
      debugPrint('      - isSandbox: ${entry.value.isSandbox}');
      debugPrint(
        '      - billingIssueDetectedAt: ${entry.value.billingIssueDetectedAt}',
      );
    }

    final entitlement = customerInfo.entitlements.all[_entitlementId];

    if (entitlement == null) {
      debugPrint('');
      debugPrint('❌ [ENTITLEMENT] No "$_entitlementId" entitlement found!');
      debugPrint(
        '   Available keys: ${customerInfo.entitlements.all.keys.toList()}',
      );
      debugPrint(
        '   TIP: Check RevenueCat dashboard that entitlement Identifier matches exactly',
      );
      AppLogging.subscriptions('☁️ No $_entitlementId entitlement found');
      return CloudSyncEntitlement.none;
    }

    debugPrint('');
    debugPrint('✅ [ENTITLEMENT] Found "$_entitlementId" entitlement!');
    debugPrint('   - isActive: ${entitlement.isActive}');
    debugPrint('   - productIdentifier: ${entitlement.productIdentifier}');

    if (entitlement.isActive) {
      // Check if in billing retry / grace period
      final billingIssue = entitlement.billingIssueDetectedAt != null;

      if (billingIssue) {
        debugPrint(
          '⚠️ [ENTITLEMENT] Subscription in grace period (billing issue detected)',
        );
        AppLogging.subscriptions('☁️ Subscription in grace period');
        return CloudSyncEntitlement(
          state: CloudSyncEntitlementState.gracePeriod,
          expiresAt: entitlement.expirationDate != null
              ? DateTime.parse(entitlement.expirationDate!)
              : null,
          productId: entitlement.productIdentifier,
          canWrite: true,
          canRead: true,
        );
      }

      debugPrint('✅ [ENTITLEMENT] Subscription is ACTIVE!');
      AppLogging.subscriptions('☁️ Subscription active');
      return CloudSyncEntitlement(
        state: CloudSyncEntitlementState.active,
        expiresAt: entitlement.expirationDate != null
            ? DateTime.parse(entitlement.expirationDate!)
            : null,
        productId: entitlement.productIdentifier,
        canWrite: true,
        canRead: true,
      );
    }

    // Entitlement exists but not active - expired
    // Allow read-only access for previously subscribed users
    if (entitlement.expirationDate != null) {
      debugPrint(
        '⚠️ [ENTITLEMENT] Subscription EXPIRED, granting read-only access',
      );
      AppLogging.subscriptions('☁️ Subscription expired, read-only access');
      return CloudSyncEntitlement(
        state: CloudSyncEntitlementState.expired,
        expiresAt: DateTime.parse(entitlement.expirationDate!),
        productId: entitlement.productIdentifier,
        canWrite: false,
        canRead: true, // Allow reading their synced data
      );
    }

    debugPrint(
      '❌ [ENTITLEMENT] Entitlement not active and no expiration date, returning none',
    );
    return CloudSyncEntitlement.none;
  }

  void _onCustomerInfoUpdate(CustomerInfo customerInfo) {
    AppLogging.subscriptions('☁️ RevenueCat customer info updated');
    // Re-resolve entitlement (grandfathering check is cached)
    final entitlement = _resolveEntitlementFromCustomerInfo(customerInfo);

    // Only update if not grandfathered (grandfathered takes precedence)
    if (_cachedEntitlement.state != CloudSyncEntitlementState.grandfathered) {
      _updateEntitlement(entitlement);
    }
  }

  void _onAuthStateChange(User? user) {
    if (user == null) {
      AppLogging.subscriptions('☁️ User signed out, clearing entitlement');
      _updateEntitlement(CloudSyncEntitlement.none);
      _firestoreSubscription?.cancel();
    } else {
      // Refresh on sign in
      refreshEntitlement();
      _listenToFirestoreEntitlement(user.uid);
    }
  }

  void _listenToFirestoreEntitlement(String uid) {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = _firestore
        .collection('user_entitlements')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data()!;
              final status = data['cloud_sync'] as String?;

              if (status == 'grandfathered') {
                _updateEntitlement(
                  const CloudSyncEntitlement(
                    state: CloudSyncEntitlementState.grandfathered,
                    canWrite: true,
                    canRead: true,
                  ),
                );
              }
              // Other states are handled by RevenueCat
            }
          },
          onError: (error) {
            // Handle Firestore errors gracefully (permissions, network, etc.)
            AppLogging.subscriptions(
              '☁️ Firestore entitlement listener error: $error',
            );
            // Don't crash - just continue with RevenueCat-only entitlements
          },
        );
  }

  void _updateEntitlement(CloudSyncEntitlement entitlement) {
    if (_cachedEntitlement.state != entitlement.state) {
      AppLogging.subscriptions(
        '☁️ Entitlement changed: ${_cachedEntitlement.state} -> ${entitlement.state}',
      );
    }
    _cachedEntitlement = entitlement;
    _entitlementController.add(entitlement);
    _cacheEntitlement(entitlement);
  }

  Future<void> _loadCachedEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (cached != null && timestamp != null) {
        // Cache valid for 1 hour
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (cacheAge < const Duration(hours: 1).inMilliseconds) {
          _cachedEntitlement = _deserializeEntitlement(cached);
          AppLogging.subscriptions(
            '☁️ Loaded cached entitlement: $_cachedEntitlement',
          );
        }
      }
    } catch (e) {
      AppLogging.subscriptions('☁️ Error loading cached entitlement: $e');
    }
  }

  Future<void> _cacheEntitlement(CloudSyncEntitlement entitlement) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, _serializeEntitlement(entitlement));
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogging.subscriptions('☁️ Error caching entitlement: $e');
    }
  }

  String _serializeEntitlement(CloudSyncEntitlement entitlement) {
    return entitlement.state.name;
  }

  CloudSyncEntitlement _deserializeEntitlement(String cached) {
    final state = CloudSyncEntitlementState.values.firstWhere(
      (s) => s.name == cached,
      orElse: () => CloudSyncEntitlementState.none,
    );

    return CloudSyncEntitlement(
      state: state,
      canWrite:
          state == CloudSyncEntitlementState.active ||
          state == CloudSyncEntitlementState.gracePeriod ||
          state == CloudSyncEntitlementState.grandfathered,
      canRead: state != CloudSyncEntitlementState.none,
    );
  }

  /// Dispose resources
  void dispose() {
    Purchases.removeCustomerInfoUpdateListener(_onCustomerInfoUpdate);
    _authSubscription?.cancel();
    _firestoreSubscription?.cancel();
    _entitlementController.close();
  }
}
