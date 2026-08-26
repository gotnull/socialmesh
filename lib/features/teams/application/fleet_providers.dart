// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Fleet views + mutation controller.
//
// Everything here derives from ONE authority, `licenseOrgFleetProvider`,
// which fetches the active+retired union in a single query and caches
// it. The active and retired lists are pure derivations of that
// snapshot - no second query, no second cache, no duplicated filtering
// rule that could drift from the repository's.
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/license_org_fleet_device.dart';
import '../../../models/license_org_membership.dart';
import '../../../providers/connectivity_providers.dart';
import '../../../providers/license_org_overview_providers.dart';
import '../../../providers/license_org_fleet_providers.dart';
import '../../../services/license_org/license_org_fleet_service.dart';

/// Injection point for the fleet mutation service.
final licenseOrgFleetServiceProvider = Provider<LicenseOrgFleetService>(
  (ref) => LicenseOrgFleetService(),
);

/// Devices currently in service, newest change first.
///
/// The snapshot's own ordering (updatedAt desc) is preserved rather than
/// re-sorted, so a device an admin just touched surfaces at the top.
final activeFleetProvider =
    Provider.family<List<LicenseOrgFleetDevice>, String>((ref, licenseOrgId) {
      return ref
          .watch(licenseOrgFleetProvider(licenseOrgId))
          .maybeWhen(
            data: (snapshot) => snapshot.devices
                .where((d) => d.status == FleetDeviceStatus.active)
                .toList(growable: false),
            orElse: () => const <LicenseOrgFleetDevice>[],
          );
    });

/// Retired devices, kept retrievable rather than deleted.
///
/// Deliberately a separate view rather than a flag on the main list:
/// mixing retired hardware into the working inventory is how an
/// operator loses track of what is actually in service.
final retiredFleetProvider =
    Provider.family<List<LicenseOrgFleetDevice>, String>((ref, licenseOrgId) {
      return ref
          .watch(licenseOrgFleetProvider(licenseOrgId))
          .maybeWhen(
            data: (snapshot) => snapshot.devices
                .where((d) => d.status == FleetDeviceStatus.retired)
                .toList(growable: false),
            orElse: () => const <LicenseOrgFleetDevice>[],
          );
    });

/// A single device by its canonical id, or null when absent.
///
/// Reads the same snapshot rather than issuing a document fetch, so a
/// detail screen opened from the list cannot disagree with the row that
/// launched it.
final fleetDeviceByIdProvider =
    Provider.family<
      LicenseOrgFleetDevice?,
      ({String licenseOrgId, String fleetDeviceId})
    >((ref, key) {
      return ref
          .watch(licenseOrgFleetProvider(key.licenseOrgId))
          .maybeWhen(
            data: (snapshot) {
              for (final device in snapshot.devices) {
                if (device.id == key.fleetDeviceId) return device;
              }
              return null;
            },
            orElse: () => null,
          );
    });

/// In-flight state for a fleet mutation.
///
/// `AsyncValue<void>` rather than a bespoke enum so the UI gets loading
/// and error handling for free, and so a failure carries the typed
/// [FleetMutationFailure] as its error rather than a string.
///
/// Riverpod 3.x family pattern used across this repo: a plain [Notifier]
/// carrying the family argument as a constructor field, wired up with
/// `NotifierProvider.family`.
class FleetMutationController extends Notifier<AsyncValue<void>> {
  final String licenseOrgId;

  FleetMutationController(this.licenseOrgId);

  @override
  AsyncValue<void> build() => const AsyncData(null);

  LicenseOrgFleetService get _service =>
      ref.read(licenseOrgFleetServiceProvider);

  Future<FleetMutationResult> enroll({
    required FleetTransport transport,
    required String rawIdentity,
    String? label,
    String? purpose,
    List<String>? tags,
    String? notes,
    String? lastKnownHardware,
    String? lastKnownFirmware,
  }) {
    return _run(
      () => _service.enroll(
        licenseOrgId: licenseOrgId,
        transport: transport,
        rawIdentity: rawIdentity,
        label: label,
        purpose: purpose,
        tags: tags,
        notes: notes,
        lastKnownHardware: lastKnownHardware,
        lastKnownFirmware: lastKnownFirmware,
      ),
    );
  }

  Future<FleetMutationResult> updateMetadata({
    required FleetTransport transport,
    required String rawIdentity,
    String? label,
    String? purpose,
    List<String>? tags,
    String? notes,
  }) {
    return _run(
      () => _service.update(
        licenseOrgId: licenseOrgId,
        transport: transport,
        rawIdentity: rawIdentity,
        label: label,
        purpose: purpose,
        tags: tags,
        notes: notes,
      ),
    );
  }

  Future<FleetMutationResult> assign({
    required FleetTransport transport,
    required String rawIdentity,
    required FleetAssignmentKind assignment,
    String? assignedUid,
  }) {
    return _run(
      () => _service.assign(
        licenseOrgId: licenseOrgId,
        transport: transport,
        rawIdentity: rawIdentity,
        assignment: assignment,
        assignedUid: assignedUid,
      ),
    );
  }

  Future<FleetMutationResult> retire({
    required FleetTransport transport,
    required String rawIdentity,
  }) {
    return _run(
      () => _service.retire(
        licenseOrgId: licenseOrgId,
        transport: transport,
        rawIdentity: rawIdentity,
      ),
    );
  }

  Future<FleetMutationResult> _run(
    Future<FleetMutationResult> Function() action,
  ) async {
    state = const AsyncLoading();
    final result = await action();

    switch (result) {
      case FleetMutationSuccess():
        state = const AsyncData(null);
        // Invalidate ONLY on success. A permission refusal, a retired
        // device or a dropped connection changed nothing server-side,
        // so re-fetching would spend a query to redraw the identical
        // list - and on a transient failure it would swap a good
        // snapshot for whatever the retry happens to return.
        ref.invalidate(licenseOrgFleetProvider(licenseOrgId));
      case FleetMutationFailure():
        // Deliberately NO invalidate. The failure carries the typed
        // result as its error so the UI can pick copy per reason.
        state = AsyncError(result, StackTrace.current);
    }
    return result;
  }
}

final fleetMutationControllerProvider =
    NotifierProvider.family<FleetMutationController, AsyncValue<void>, String>(
      FleetMutationController.new,
    );

/// Why the admin cannot currently change the fleet.
///
/// Deliberately separate from anything about READING the fleet. A user
/// may legitimately be looking at cached rows from two hours ago while
/// being unable to enrol, assign or retire - "I can see this data" and
/// "I can safely mutate it" are different questions, and blurring them
/// is how an app ends up queueing writes it never sends.
enum FleetWriteBlock {
  /// Writes are available.
  none,

  /// Fleet mutations are online-only in PR1. Showing the action enabled
  /// and failing on tap would be worse: the refusal is knowable before
  /// the admin commits to it.
  offline,

  /// The caller is a member, not an owner or admin.
  notAdmin,
}

/// Whether fleet mutations should be offered, and why not.
///
/// PRESENTATION GUIDANCE ONLY. The server re-checks role, org status and
/// the fleet capability on every callable; this exists so the UI does
/// not offer an action it already knows will be refused.
final fleetWriteBlockProvider = Provider.family<FleetWriteBlock, String>((
  ref,
  licenseOrgId,
) {
  final role = ref.watch(licenseOrgRoleProvider(licenseOrgId));
  final isAdmin =
      role == LicenseOrgMemberRole.owner || role == LicenseOrgMemberRole.admin;
  if (!isAdmin) return FleetWriteBlock.notAdmin;

  // Checked after role so a plain member offline is told the more
  // durable reason - connectivity will come back, their role will not.
  if (!ref.watch(isOnlineProvider)) return FleetWriteBlock.offline;

  return FleetWriteBlock.none;
});
