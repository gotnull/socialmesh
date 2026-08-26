// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Data layer for the Teams fleet inventory.
// Firestore collection: `license_org_fleet_devices/{fleetDeviceId}`.
//
// The contract deliberately does NOT fail closed to an empty list the
// way the membership repository does. A fleet read has three
// materially different outcomes and collapsing them loses the one
// distinction the offline contract depends on:
//
//   FleetRemoteData        - authoritative success
//   FleetAccessDenied      - the server said no; purge the offline copy
//   FleetRemoteUnavailable - transient; keep serving the offline copy
//
// Only `permission-denied` is treated as authoritative. Everything
// else, including unrecognised codes, is transient. Retaining data
// that should have been dropped self-corrects on the next successful
// sync; destroying the only offline copy on a misclassified transient
// error does not.
//
// Reads are one-shot `get()` per call, NOT a `snapshots()` listener.
// Fleet metadata changes only when an admin acts, so a listener would
// re-bill the full snapshot on every app foreground and reconnect
// while adding nothing. The provider's cache TTL is what bounds read
// volume.
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/logging.dart';
import '../../models/license_org_fleet_device.dart';

/// Firestore collection holding fleet device records.
const String kLicenseOrgFleetCollection = 'license_org_fleet_devices';

/// Outcome of a single fleet read.
sealed class FleetRemoteResult {
  const FleetRemoteResult();
}

/// Authoritative success. [devices] is the complete current fleet for
/// the requested org and status set.
class FleetRemoteData extends FleetRemoteResult {
  final List<LicenseOrgFleetDevice> devices;

  const FleetRemoteData(this.devices);
}

/// The server refused the read. Membership was revoked, or the org is
/// no longer active. Callers must drop any cached copy: the offline
/// data must not outlive an explicit denial.
class FleetAccessDenied extends FleetRemoteResult {
  const FleetAccessDenied();
}

/// The read could not be completed for a reason that says nothing
/// about authorisation. Callers must KEEP any cached copy.
///
/// [codeClass] is the Firebase error code, retained for logging only.
/// It is never a user-facing string.
class FleetRemoteUnavailable extends FleetRemoteResult {
  final String codeClass;

  const FleetRemoteUnavailable(this.codeClass);
}

/// Streams fleet device records for one license org.
abstract class LicenseOrgFleetRepository {
  /// One-shot read of [licenseOrgId]'s fleet.
  ///
  /// [statuses] is a parameter rather than a hardcoded predicate so
  /// retired records stay reachable. Baking `status == active` in would
  /// soft-delete them into permanent invisibility.
  Future<FleetRemoteResult> fetchFleet(
    String licenseOrgId, {
    Set<FleetDeviceStatus> statuses = const {FleetDeviceStatus.active},
  });
}

/// Firestore-backed implementation.
class FirestoreLicenseOrgFleetRepository implements LicenseOrgFleetRepository {
  final FirebaseFirestore _firestore;

  FirestoreLicenseOrgFleetRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<FleetRemoteResult> fetchFleet(
    String licenseOrgId, {
    Set<FleetDeviceStatus> statuses = const {FleetDeviceStatus.active},
  }) async {
    if (licenseOrgId.isEmpty) return const FleetRemoteData([]);
    if (statuses.isEmpty) return const FleetRemoteData([]);

    try {
      // The licenseOrgId filter is load-bearing for security as well as
      // correctness: `firestore.rules` authorises on
      // resource.data.licenseOrgId, so an unscoped query is rejected
      // outright rather than silently returning another org's rows.
      final snapshot = await _firestore
          .collection(kLicenseOrgFleetCollection)
          .where('licenseOrgId', isEqualTo: licenseOrgId)
          .where('status', whereIn: statuses.map((s) => s.toWire()).toList())
          .orderBy('updatedAt', descending: true)
          .get();

      final devices = <LicenseOrgFleetDevice>[];
      for (final doc in snapshot.docs) {
        final device = LicenseOrgFleetDevice.fromFirestore(doc);
        // One malformed document must not blank the whole fleet.
        if (device == null) continue;
        // Defence in depth against a rule regression: never surface a
        // row that claims a different org than the one requested.
        if (device.licenseOrgId != licenseOrgId) continue;
        devices.add(device);
      }

      return FleetRemoteData(List<LicenseOrgFleetDevice>.unmodifiable(devices));
    } on FirebaseException catch (e) {
      return _classify(e.code);
    } catch (e) {
      // An unrecognised failure is transient by default. Purging is
      // destructive and must require an explicit denial.
      AppLogging.groupLicensing(
        '[LicenseOrgFleetRepo] non-Firebase read failure - treating as '
        'transient (error class: ${e.runtimeType})',
      );
      return const FleetRemoteUnavailable('unknown');
    }
  }

  /// Maps a Firebase error code to a result.
  ///
  /// `permission-denied` is the ONLY authoritative denial. `not-found`
  /// was considered and deliberately excluded: for a list query it is
  /// effectively unreachable, and treating a rare unexplained code as
  /// grounds to destroy the user's only offline copy is the wrong
  /// default.
  static FleetRemoteResult _classify(String code) {
    if (code == 'permission-denied') {
      AppLogging.groupLicensing(
        '[LicenseOrgFleetRepo] read denied by rules - purging cached copy',
      );
      return const FleetAccessDenied();
    }
    AppLogging.groupLicensing(
      '[LicenseOrgFleetRepo] read unavailable (code: $code) - '
      'retaining cached copy',
    );
    return FleetRemoteUnavailable(code);
  }
}
