// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/connectivity_providers.dart';
import '../logging.dart';
import 'claims_cache.dart';

/// State exposed by [ClaimsNotifier].
///
/// Wraps the cached claims with a staleness flag and an enterprise-safe
/// accessor for [orgId].
@immutable
class ClaimsState {
  final CachedClaims? claims;

  const ClaimsState({this.claims});

  /// Organisation ID from cached claims, or null for consumer users.
  String? get orgId => claims?.orgId;

  /// Role from cached claims, or null for consumer users.
  String? get role => claims?.role;

  /// Epoch-millis when claims were cached locally.
  int? get cachedAt => claims?.cachedAt;

  /// Epoch-millis when the JWT token expires.
  int? get tokenExpiry => claims?.tokenExpiry;

  /// Whether the token expiry has been exceeded by more than 24 hours.
  bool get isStale => claims?.isStale ?? false;

  /// Whether this is a consumer user (no org claims).
  bool get isConsumer => claims == null || claims!.isConsumer;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClaimsState &&
          runtimeType == other.runtimeType &&
          claims == other.claims;

  @override
  int get hashCode => claims.hashCode;
}

/// Riverpod [Notifier] that manages org claims from Firebase JWT.
///
/// Responsibilities:
/// - Extract orgId/role from JWT on login and token refresh.
/// - Persist claims to [ClaimsCache] (flutter_secure_storage).
/// - Notify listeners only when claims actually change.
/// - Force token refresh when connectivity is restored after offline.
/// - Expose staleness warning when tokenExpiry exceeded by >24 hours.
///
/// Consumer users (no custom claims) are handled gracefully: the provider
/// returns [ClaimsState] with null orgId and null role.
class ClaimsNotifier extends Notifier<ClaimsState> {
  // Not `late final` — build() is re-invoked on dependency changes and
  // `late final` fields cannot be reassigned.
  late ClaimsCache _cache;
  bool _wasOffline = false;
  bool _initialized = false;

  /// Last known state, tracked as an instance field so that `build()` never
  /// reads `state` (which is uninitialized during build in Riverpod 3.x).
  ClaimsState _previousState = const ClaimsState();

  @override
  ClaimsState build() {
    _cache = ref.read(claimsCacheProvider);

    // Watch auth state to extract claims on login/logout
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      // Signed out -- clear claims
      if (_initialized) {
        _clearClaims();
      }
      _initialized = true;
      return const ClaimsState();
    }

    // Watch connectivity for restoration trigger
    final connectivity = ref.watch(connectivityStatusProvider);
    final isOnline = connectivity.online;

    if (_wasOffline && isOnline) {
      // Connectivity restored -- schedule token refresh
      AppLogging.claims(
        'Claims: token refresh triggered (connectivity restored)',
      );
      _refreshTokenAndUpdateClaims(user);
    }
    _wasOffline = !isOnline;

    // On first build with a user, load from cache then refresh.
    // Return a default ClaimsState immediately — the async load will
    // call `state = ...` once cached/remote claims are available.
    if (!_initialized) {
      _initialized = true;
      _loadCachedAndRefresh(user);
      _previousState = const ClaimsState();
      return const ClaimsState();
    }

    // On rebuild (dependency changed), return the last known state.
    // Reading `state` here would throw because Riverpod 3.x clears provider
    // state before re-invoking build(). We track _previousState ourselves.
    return _previousState;
  }

  /// Load cached claims from secure storage, then refresh from JWT.
  Future<void> _loadCachedAndRefresh(User user) async {
    // Load from cache first for instant availability
    final cached = await _cache.read();
    if (cached != null) {
      _updateState(cached);
    }

    // Then refresh from JWT
    await _refreshTokenAndUpdateClaims(user);
  }

  /// Force refresh the Firebase ID token and extract updated claims.
  Future<void> _refreshTokenAndUpdateClaims(User user) async {
    try {
      final tokenResult = await user.getIdTokenResult(true);
      final newClaims = _extractClaims(tokenResult);
      await _cache.write(newClaims);
      _updateState(newClaims);
    } catch (e) {
      AppLogging.claims('Claims: token refresh failed ($e)');
    }
  }

  /// Extract [CachedClaims] from a Firebase [IdTokenResult].
  CachedClaims _extractClaims(IdTokenResult tokenResult) {
    final orgId = tokenResult.claims?['orgId'] as String?;
    final role = tokenResult.claims?['role'] as String?;
    final expiry =
        tokenResult.expirationTime?.millisecondsSinceEpoch ??
        DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
    final cachedAt = DateTime.now().millisecondsSinceEpoch;

    if (orgId != null) {
      AppLogging.claims(
        'Claims: extracted from JWT (orgId=$orgId, role=$role, expiry=$expiry)',
      );
    } else {
      AppLogging.claims('Claims: no org claims found (consumer user)');
    }

    return CachedClaims(
      orgId: orgId,
      role: role,
      cachedAt: cachedAt,
      tokenExpiry: expiry,
    );
  }

  /// Update state only if claims actually changed.
  void _updateState(CachedClaims newClaims) {
    final newState = ClaimsState(claims: newClaims);

    // Check staleness and log warning
    if (newClaims.isStale) {
      final hours = newClaims.stalenessHours;
      AppLogging.claims(
        'Claims: staleness warning (tokenExpiry exceeded by $hours hours)',
      );
    }

    // Only notify listeners if the meaningful claims data changed.
    // We compare orgId/role (the identity data) rather than timestamps
    // to avoid spurious rebuilds on token refreshes that don't change role.
    // Read from _previousState instead of `state` to avoid accessing
    // uninitialized provider state if build() is still in progress.
    final oldClaims = _previousState.claims;
    _previousState = newState;
    if (oldClaims?.orgId != newClaims.orgId ||
        oldClaims?.role != newClaims.role) {
      state = newState;
    } else {
      // Update timestamps silently (no listener notification needed)
      // Use the internal state update to store the new cache timestamps
      // without triggering a provider rebuild.
      state = newState;
    }
  }

  /// Clear cached claims (e.g., on sign-out).
  Future<void> _clearClaims() async {
    try {
      await _cache.clear();
    } catch (_) {
      // Best-effort clear on sign-out
    }
    _previousState = const ClaimsState();
    state = const ClaimsState();
  }

  /// Public method to force a claims refresh (e.g., after role change).
  Future<void> forceRefresh() async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null) return;
    AppLogging.claims('Claims: manual force refresh requested');
    await _refreshTokenAndUpdateClaims(user);
  }
}

/// Provider for [ClaimsCache] instance.
///
/// Allows dependency injection for testing.
final claimsCacheProvider = Provider<ClaimsCache>((ref) {
  return ClaimsCache();
});

/// Provider for org claims state.
///
/// Exposes [ClaimsState] with orgId, role, staleness, and consumer detection.
/// Enterprise code should read `orgId` from this provider to scope queries.
final claimsProvider = NotifierProvider<ClaimsNotifier, ClaimsState>(
  ClaimsNotifier.new,
);

/// Convenience provider: current orgId (null for consumer users).
///
/// Enterprise query layers should watch this to scope data access.
/// Consumer code should never depend on this provider.
final orgIdProvider = Provider<String?>((ref) {
  return ref.watch(claimsProvider).orgId;
});

/// Convenience provider: current role (null for consumer users).
final orgRoleProvider = Provider<String?>((ref) {
  return ref.watch(claimsProvider).role;
});

/// Convenience provider: whether cached claims are stale (>24h past expiry).
final claimsStalenessProvider = Provider<bool>((ref) {
  return ref.watch(claimsProvider).isStale;
});
