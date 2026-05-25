// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Local cache for external entitlements. Offline-first contract: once
// an entitlement has been confirmed by the backend, it stays unlocked
// even if the app cold-starts on a flight without network. The cache
// is the source of truth for the UI; the network refresh is a
// reconciliation step that runs in the background.
//
// Cache shape on disk: a single JSON list under one preferences key,
// rather than one key per productId. This keeps reads atomic and
// avoids partial-update windows where the user briefly sees one pack
// unlocked but a sibling pack still locked during a refresh.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../models/seat_allocation.dart';
import 'external_entitlement.dart';

class ExternalEntitlementCache {
  static const String _prefsKey = 'external_purchase.entitlements_cache';
  static const String _refreshedAtKey =
      'external_purchase.entitlements_refreshed_at';

  final SharedPreferences _prefs;

  ExternalEntitlementCache(this._prefs);

  /// Read the cached entitlements. Returns an empty list if the cache
  /// has never been populated or fails to decode.
  ///
  /// A decode failure clears the cache - a corrupted blob would
  /// otherwise stick around silently. Better to lose the cache and
  /// re-fetch from the backend than serve a half-parsed list.
  List<ExternalEntitlement> read() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ExternalEntitlement.fromJson)
          .toList();
    } catch (e) {
      AppLogging.purchase(
        '[ExternalEntitlementCache] Decode failed: $e - clearing cache',
      );
      _prefs.remove(_prefsKey);
      return const [];
    }
  }

  /// Replace the cached entitlements with the supplied list.
  ///
  /// Persists the refresh timestamp so the UI can show "last verified
  /// X minutes ago" and the service can decide whether a network
  /// refresh is overdue.
  Future<void> write(List<ExternalEntitlement> entitlements) async {
    final json = entitlements.map((e) => e.toJson()).toList();
    await _prefs.setString(_prefsKey, jsonEncode(json));
    await _prefs.setString(
      _refreshedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
    final orgCount = entitlements
        .where((e) => e.ownerKind == OwnerKind.org)
        .length;
    if (orgCount > 0) {
      final userCount = entitlements.length - orgCount;
      AppLogging.purchase(
        '[ExternalEntitlementCache] Wrote ${entitlements.length} entitlements '
        '($userCount user-owned, $orgCount org-owned - org rows require '
        'matching membership + seat allocation to grant)',
      );
    } else {
      AppLogging.purchase(
        '[ExternalEntitlementCache] Wrote ${entitlements.length} entitlements',
      );
    }
  }

  /// Last successful network refresh time, or null if never refreshed.
  DateTime? lastRefreshedAt() {
    final raw = _prefs.getString(_refreshedAtKey);
    if (raw == null) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Wipe the cache. Used on sign-out so a returning user doesn't see
  /// the previous account's entitlements before the next refresh
  /// completes.
  Future<void> clear() async {
    await _prefs.remove(_prefsKey);
    await _prefs.remove(_refreshedAtKey);
    AppLogging.purchase('[ExternalEntitlementCache] Cleared');
  }

  /// Active product ids derived from the cache. The provider layer
  /// joins this with the store-side `purchasedProductIds` to compute
  /// effective access.
  ///
  /// Ownership rules:
  ///   - User-owned rows ([OwnerKind.user]) always admit when active.
  ///   - Org-owned rows ([OwnerKind.org]) admit ONLY when BOTH:
  ///     - the row's `orgId` is in [ownedOrgIds] (the current user is
  ///       a member of the owning license-org), AND
  ///     - the `(orgId, productId)` pair is in [ownedSeats] (the user
  ///       has been allocated a seat for this specific product).
  ///
  /// The dual check is defence in depth: a stale seat row for a
  /// license-org the user is no longer a member of must NOT grant
  /// access. Both sources flow from independent providers
  /// (`currentUserLicenseOrgIdsProvider` and
  /// `currentUserSeatAllocationsProvider`); their intersection here
  /// is what closes the loop.
  ///
  /// Both args default to empty so existing call sites continue to
  /// drop org rows (fail-closed). The
  /// `externalEntitlementsProvider` wires in the real values.
  Set<String> activeProductIds({
    Set<String> ownedOrgIds = const {},
    Set<SeatAllocationRef> ownedSeats = const {},
  }) {
    return read()
        .where((e) => e.isActive)
        .where(
          (e) => switch (e.ownerKind) {
            OwnerKind.user => true,
            OwnerKind.org => () {
              final orgId = e.orgId;
              if (orgId == null || orgId.isEmpty) return false;
              if (!ownedOrgIds.contains(orgId)) return false;
              return ownedSeats.contains(
                SeatAllocationRef(orgId: orgId, productId: e.productId),
              );
            }(),
          },
        )
        .map((e) => e.productId)
        .toSet();
  }
}
