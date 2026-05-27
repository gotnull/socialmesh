// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Riverpod wiring for the License Org Overview screen
// (lib/features/license_org/license_org_overview_screen.dart).
//
// Spec: docs/engineering/LICENSE_ORG_OVERVIEW_SCREEN.md.
//
// Provider graph (read top-down):
//
//   currentUserLicenseOrgIdsProvider      <- shipped slice 2; Set<String>
//        |
//        v (per org id)
//   licenseOrgProvider.family(orgId)      <- LicenseOrg? from
//                                            license_orgs/{orgId};
//                                            null on missing /
//                                            malformed / stream error
//   currentUserLicenseOrgMembershipProvider.family(orgId)
//                                         <- LicenseOrgMembership?
//                                            from license_orgs/{orgId}/
//                                            members/{currentUid};
//                                            null on missing / guest
//   licenseOrgRoleProvider.family(orgId)  <- pure derivation from the
//                                            membership doc
//   licenseOrgRedeemedSeatCountProvider.family(orgId)
//                                         <- pure count of the current
//                                            user's active seats for
//                                            orgId from
//                                            currentUserSeatAllocationsProvider
//
// All four NEW providers fail closed:
//   - flag off / signed out / anonymous user / empty uid -> null or 0
//   - Firestore stream error -> null (logged at the repository layer)
//
// IMPORTANT - reads the licensing namespace (`license_orgs/`), NOT the
// enterprise multi-tenancy `orgs/` namespace
// (backend/functions/src/org/createOrg.ts). The two systems must NOT
// share Firestore paths or roles.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/license_org.dart';
import '../models/license_org_membership.dart';
import 'auth_providers.dart';
import 'license_org_membership_providers.dart';
import 'seat_allocation_providers.dart';

/// Streams the [LicenseOrg] doc for [orgId]. Yields null when the flag
/// is off, the doc is missing, the wire is malformed, or the
/// underlying stream errors.
///
/// Suspended orgs are yielded (the model carries [LicenseOrg.status])
/// so the UI can render a "Suspended" badge instead of disappearing
/// the card silently. Callers that need access-grant semantics should
/// check [LicenseOrg.isAccessActive].
final licenseOrgProvider = StreamProvider.family<LicenseOrg?, String>((
  ref,
  orgId,
) async* {
  if (!AppFeatureFlags.isGroupLicensingEnabled) {
    yield null;
    return;
  }
  if (orgId.isEmpty) {
    yield null;
    return;
  }

  final repo = ref.watch(licenseOrgMembershipRepositoryProvider);
  yield null;
  yield* repo.watchLicenseOrg(orgId);
});

/// Streams the membership row for the current user inside [orgId].
/// Yields null when the flag is off, the user is signed out / anonymous,
/// the doc is missing, or the underlying stream errors.
final currentUserLicenseOrgMembershipProvider =
    StreamProvider.family<LicenseOrgMembership?, String>((ref, orgId) async* {
      if (!AppFeatureFlags.isGroupLicensingEnabled) {
        yield null;
        return;
      }
      if (orgId.isEmpty) {
        yield null;
        return;
      }
      final user = ref.watch(currentUserProvider);
      if (user == null || user.isAnonymous || user.uid.isEmpty) {
        yield null;
        return;
      }

      final repo = ref.watch(licenseOrgMembershipRepositoryProvider);
      yield null;
      yield* repo.watchMembership(orgId, user.uid);
    });

/// Pure derivation: the role the current user holds in [orgId].
/// Returns [LicenseOrgMemberRole.unknown] when the membership is
/// loading, errored, missing, or the user is signed out.
///
/// Owner detection runs first: the org doc carries an `ownerUid`
/// field set by the Stripe webhook at purchase time, and the owner
/// is intentionally NOT written into the members subcollection (they
/// do not consume a seat). Without this short-circuit the owner would
/// fall through to `unknown` and lose access to owner-only surfaces
/// (Invite member button, mint seat code, member revoke, etc.).
final licenseOrgRoleProvider = Provider.family<LicenseOrgMemberRole, String>((
  ref,
  orgId,
) {
  final user = ref.watch(currentUserProvider);
  if (user != null && !user.isAnonymous && user.uid.isNotEmpty) {
    final orgAsync = ref.watch(licenseOrgProvider(orgId));
    final org = orgAsync.maybeWhen(data: (o) => o, orElse: () => null);
    if (org != null && org.ownerUid == user.uid) {
      return LicenseOrgMemberRole.owner;
    }
  }
  final async = ref.watch(currentUserLicenseOrgMembershipProvider(orgId));
  return async.maybeWhen(
    data: (membership) => membership?.role ?? LicenseOrgMemberRole.unknown,
    orElse: () => LicenseOrgMemberRole.unknown,
  );
});

/// Pure derivation: count of active seats the current user holds in
/// [orgId]. Counts only the current user's seats; the org-wide
/// redeemed count lives in the admin-only members sheet (deferred).
///
/// Returns 0 when the seat allocations provider is loading, errored,
/// or the user holds no seats in this org.
final licenseOrgRedeemedSeatCountProvider = Provider.family<int, String>((
  ref,
  orgId,
) {
  final async = ref.watch(currentUserSeatAllocationsProvider);
  return async.maybeWhen(
    data: (seats) => seats.where((s) => s.orgId == orgId).length,
    orElse: () => 0,
  );
});
