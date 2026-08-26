// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Provider surface for the Teams fleet inventory.
//
// Reads are cache-first then cloud. The emitted value is a SNAPSHOT
// rather than a bare list: a list cannot express "these are cached rows
// from 40 minutes ago", which the offline contract requires and which
// the fleet UI needs in order to render a last-synced badge. Making the
// UI reconstruct that from side providers is exactly what this avoids.
//
// The authorisation gate is NOT `currentUserLicenseOrgIdsProvider`.
// That provider yields an empty set both before its first Firestore
// snapshot and on stream error, so it cannot tell "offline" from "not a
// member" - gating cached reads on it would blank valid data on every
// cold start and permanently while offline. It is correct for
// entitlement decisions and wrong for this. Offline authorisation comes
// from the cache's own per-(uid, orgId) authorisation record instead.
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../models/license_org_fleet_device.dart';
import '../services/cache/license_org_cache.dart';
import '../services/org/license_org_fleet_repository.dart';
import 'auth_providers.dart';

/// How long a cached fleet is considered fresh. Past this the snapshot
/// is still SERVED, but flagged stale so the UI can show its age.
/// Staleness governs the badge, never visibility.
const Duration kLicenseOrgFleetCacheTtl = Duration(hours: 1);

/// Statuses carried in a fleet snapshot and in the local cache.
///
/// The snapshot holds the UNION so the active and retired views are
/// derivations of one fetch. Anything omitted here is invisible to
/// every Teams surface, so a future status must be added deliberately.
const Set<FleetDeviceStatus> kFleetCachedStatuses = {
  FleetDeviceStatus.active,
  FleetDeviceStatus.retired,
};

/// Where the devices in a snapshot came from.
enum FleetSnapshotSource { cloud, cache }

/// A fleet read result plus the sync state needed to render it honestly.
class LicenseOrgFleetSnapshot {
  final List<LicenseOrgFleetDevice> devices;

  /// Whether [devices] came from an authoritative cloud read or from
  /// the local cache.
  final FleetSnapshotSource source;

  /// When these rows were last authoritative. Null when nothing has
  /// ever been synced for this org.
  final DateTime? syncedAt;

  /// True when serving cached rows older than [kLicenseOrgFleetCacheTtl].
  final bool isStale;

  /// True while a cloud read is in flight behind an already-emitted
  /// value.
  ///
  /// This is not redundant with `AsyncValue.isLoading`: the stream emits
  /// cached rows immediately, so the AsyncValue has already resolved to
  /// data while the network read is still outstanding.
  final bool isRefreshing;

  /// True when the authoritative read did not succeed.
  ///
  /// Load-bearing: an empty [devices] means "this org has no radios"
  /// ONLY when this is false. Without it a failed read is indistinguishable
  /// from a genuinely empty fleet, and the UI states "no radios yet" about
  /// an org whose radios it simply could not fetch. A missing composite
  /// index produces exactly that, permanently.
  final bool loadFailed;

  const LicenseOrgFleetSnapshot({
    required this.devices,
    required this.source,
    required this.syncedAt,
    required this.isStale,
    required this.isRefreshing,
    this.loadFailed = false,
  });

  /// The value every fail-closed path emits. Never null, never an error
  /// state, so consumers never branch on null.
  static const LicenseOrgFleetSnapshot empty = LicenseOrgFleetSnapshot(
    devices: <LicenseOrgFleetDevice>[],
    source: FleetSnapshotSource.cloud,
    syncedAt: null,
    isStale: false,
    isRefreshing: false,
  );

  LicenseOrgFleetSnapshot copyWith({bool? isRefreshing, bool? loadFailed}) {
    return LicenseOrgFleetSnapshot(
      devices: devices,
      source: source,
      syncedAt: syncedAt,
      isStale: isStale,
      loadFailed: loadFailed ?? this.loadFailed,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

/// Pure staleness predicate, so the rule is testable without a clock.
bool isFleetSnapshotStale({
  required DateTime? syncedAt,
  required DateTime now,
  Duration ttl = kLicenseOrgFleetCacheTtl,
}) {
  if (syncedAt == null) return true;
  final age = now.difference(syncedAt);
  if (age.isNegative) return false;
  return age > ttl;
}

/// Clock seam. Overridden in tests so staleness boundaries are exact.
final fleetClockProvider = Provider<DateTime Function()>(
  (ref) =>
      () => DateTime.now().toUtc(),
);

/// Mirrors the feature gate so tests can flip it without touching
/// dotenv.
final licenseOrgFleetEnabledProvider = Provider<bool>(
  (ref) => AppFeatureFlags.isLicenseOrgFleetEnabled,
);

/// Injection point for the fleet repository.
final licenseOrgFleetRepositoryProvider = Provider<LicenseOrgFleetRepository>(
  (ref) => FirestoreLicenseOrgFleetRepository(),
);

/// Owns the cache lifecycle and the account-transition purge.
final licenseOrgCacheProvider = Provider<LicenseOrgCache>((ref) {
  final cache = LicenseOrgCache();
  ref.onDispose(() => unawaited(cache.close()));

  // Purge the departing account's rows on a real uid change. Rows are
  // uid-keyed so another account could not read them anyway; this is
  // defence in depth and keeps a departed account's data off the
  // device.
  //
  // The first emission is skipped so a cold start with an
  // already-signed-in user does not wipe valid offline cache - the same
  // reasoning as the entitlement cache handler in
  // external_purchase_providers.dart.
  //
  // `linkWithCredential` PRESERVES the uid, so the anonymous ->
  // permanent upgrade is correctly not a change and the cache survives
  // it. That is why this keys on uid rather than firing on any auth
  // event.
  String? lastSeenUid;
  ref.listen<User?>(currentUserProvider, (previous, next) {
    final nextUid = next?.uid;
    if (lastSeenUid != null && lastSeenUid != nextUid) {
      AppLogging.groupLicensing(
        '[LicenseOrgFleet] account changed - purging departing uid cache',
      );
      unawaited(cache.purgeUid(lastSeenUid!));
    }
    lastSeenUid = nextUid;
  }, fireImmediately: true);

  return cache;
});

/// Fleet for [licenseOrgId], cache-first then cloud.
///
/// Emission sequence on a normal read:
///   1. cached rows (if this uid previously authorised this org),
///      marked `isRefreshing: true`
///   2. the authoritative cloud result, `isRefreshing: false`
///
/// Fail-closed paths emit [LicenseOrgFleetSnapshot.empty] once and stop.
final licenseOrgFleetProvider = StreamProvider.family
    .autoDispose<LicenseOrgFleetSnapshot, String>((ref, licenseOrgId) async* {
      if (!ref.watch(licenseOrgFleetEnabledProvider)) {
        yield LicenseOrgFleetSnapshot.empty;
        return;
      }

      final user = ref.watch(currentUserProvider);
      if (user == null || user.uid.isEmpty) {
        yield LicenseOrgFleetSnapshot.empty;
        return;
      }
      if (user.isAnonymous) {
        // Guest mode is license-org-blind, matching every other
        // licensing surface.
        yield LicenseOrgFleetSnapshot.empty;
        return;
      }
      if (!isValidLicenseOrgId(licenseOrgId)) {
        yield LicenseOrgFleetSnapshot.empty;
        return;
      }

      final uid = user.uid;
      final cache = ref.watch(licenseOrgCacheProvider);
      final repository = ref.watch(licenseOrgFleetRepositoryProvider);
      final now = ref.watch(fleetClockProvider);

      // --- 1. cached rows -------------------------------------------------
      CachedFleet cached = CachedFleet.none;
      try {
        cached = await cache.readOrgFleet(
          uid: uid,
          licenseOrgId: licenseOrgId,
          statuses: kFleetCachedStatuses,
        );
      } catch (e) {
        // A broken cache must not block the cloud read.
        AppLogging.groupLicensing(
          '[LicenseOrgFleet] cache read failed (error class: '
          '${e.runtimeType})',
        );
      }

      LicenseOrgFleetSnapshot cachedSnapshot(bool refreshing) {
        if (!cached.authorised) {
          return LicenseOrgFleetSnapshot.empty.copyWith(
            isRefreshing: refreshing,
          );
        }
        return LicenseOrgFleetSnapshot(
          devices: cached.devices,
          source: FleetSnapshotSource.cache,
          syncedAt: cached.syncedAt,
          isStale: isFleetSnapshotStale(syncedAt: cached.syncedAt, now: now()),
          isRefreshing: refreshing,
        );
      }

      yield cachedSnapshot(true);

      // --- 2. authoritative cloud read ------------------------------------
      //
      // Fetches BOTH statuses in one query rather than one per view.
      // `replaceOrgFleet` deletes every row for (uid, org) before
      // inserting, so a status-filtered fetch would make the active and
      // retired caches wipe each other on alternate reads. Fetching the
      // union keeps the cache coherent, costs one Firestore query
      // instead of two, and lets the active/retired lists be pure
      // derivations rather than separate data paths.
      final result = await repository.fetchFleet(
        licenseOrgId,
        statuses: kFleetCachedStatuses,
      );

      switch (result) {
        case FleetRemoteData(devices: final devices):
          final syncedAt = now();
          try {
            await cache.replaceOrgFleet(
              uid: uid,
              licenseOrgId: licenseOrgId,
              devices: devices,
              syncedAt: syncedAt,
            );
          } catch (e) {
            // Failing to persist costs the next offline read, not this
            // one.
            AppLogging.groupLicensing(
              '[LicenseOrgFleet] cache write failed (error class: '
              '${e.runtimeType})',
            );
          }
          yield LicenseOrgFleetSnapshot(
            devices: devices,
            source: FleetSnapshotSource.cloud,
            syncedAt: syncedAt,
            isStale: false,
            isRefreshing: false,
          );

        case FleetAccessDenied():
          // The server was explicit. The offline copy must not outlive
          // that answer.
          try {
            await cache.purgeOrg(uid: uid, licenseOrgId: licenseOrgId);
          } catch (e) {
            AppLogging.groupLicensing(
              '[LicenseOrgFleet] cache purge failed (error class: '
              '${e.runtimeType})',
            );
          }
          yield LicenseOrgFleetSnapshot.empty;

        case FleetRemoteUnavailable():
          // Transient. Keep serving what we had rather than blanking a
          // fleet the user is still authorised to see - but mark the
          // read as failed so an empty result is never presented as
          // "this org has no radios".
          yield cachedSnapshot(false).copyWith(loadFailed: true);
      }
    });
