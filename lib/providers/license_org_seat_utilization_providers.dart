// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Provider for the per-org Seat Usage section on the License Org
// Overview card. Wraps [LicenseOrgSeatService.getSeatUtilization]
// in a Riverpod 3.x AsyncNotifier.family — one notifier instance per
// orgId, keyed for cache reuse across rebuilds.
//
// Invalidated by the revoke / reinstate flows on success (so the
// section refreshes immediately without a full provider tree
// rebuild). Future automations (auto-revoke after N days idle) will
// also invalidate this provider so the section always reflects the
// live seat state.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../services/license_org/license_org_seat_service.dart';

/// Immutable snapshot the Seat Usage UI reads. `null` means the
/// callable failed; the UI renders an error state and the empty list
/// keeps downstream `byMember` consumers null-safe.
class LicenseOrgSeatUtilizationState {
  final int capacity;
  final int active;
  final List<SeatUtilizationMember> byMember;
  final bool failed;

  const LicenseOrgSeatUtilizationState({
    required this.capacity,
    required this.active,
    required this.byMember,
    required this.failed,
  });

  static const empty = LicenseOrgSeatUtilizationState(
    capacity: 0,
    active: 0,
    byMember: <SeatUtilizationMember>[],
    failed: false,
  );

  static const failure = LicenseOrgSeatUtilizationState(
    capacity: 0,
    active: 0,
    byMember: <SeatUtilizationMember>[],
    failed: true,
  );
}

/// Per-org Seat Usage notifier. Riverpod 3.x family pattern: the
/// notifier itself is a plain [AsyncNotifier] carrying [orgId] as a
/// constructor field; the family factory threads it via
/// `LicenseOrgSeatUtilizationNotifier.new`.
class LicenseOrgSeatUtilizationNotifier
    extends AsyncNotifier<LicenseOrgSeatUtilizationState> {
  final String orgId;

  LicenseOrgSeatUtilizationNotifier(this.orgId);

  @override
  Future<LicenseOrgSeatUtilizationState> build() async {
    if (!AppFeatureFlags.isGroupLicensingEnabled) {
      return LicenseOrgSeatUtilizationState.empty;
    }
    if (orgId.isEmpty) {
      return LicenseOrgSeatUtilizationState.empty;
    }
    final service = LicenseOrgSeatService();
    final result = await service.getSeatUtilization(licenseOrgId: orgId);
    return switch (result) {
      GetSeatUtilizationSuccess s => LicenseOrgSeatUtilizationState(
        capacity: s.capacity,
        active: s.active,
        byMember: s.byMember,
        failed: false,
      ),
      GetSeatUtilizationFailure f => () {
        AppLogging.groupLicensing(
          '[licenseOrgSeatUtilizationProvider] failed: ${f.message}',
        );
        return LicenseOrgSeatUtilizationState.failure;
      }(),
    };
  }

  /// Re-fetch the snapshot. Called by the revoke / reinstate flows on
  /// success so the Seat Usage section reflects the change without
  /// waiting for a navigation round-trip.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final licenseOrgSeatUtilizationProvider =
    AsyncNotifierProvider.family<
      LicenseOrgSeatUtilizationNotifier,
      LicenseOrgSeatUtilizationState,
      String
    >(LicenseOrgSeatUtilizationNotifier.new);
