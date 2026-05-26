// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Riverpod wiring for the License Org Members sheet (slice N+4).
// See docs/engineering/LICENSE_ORG_ROSTER.md.
//
// Provider graph (top-down):
//
//   licenseOrgMembershipRepositoryProvider (existing)
//        |
//        v
//   licenseOrgMembersProvider.family(orgId) - List<LicenseOrgMembership>
//        |
//        v
//   licenseOrgMemberCountProvider.family(orgId) - int
//
// All providers fail closed: flag off / signed out / anonymous user /
// suspended org / repository stream error all degrade to an empty
// list (0 count). The repo layer also defence-in-depth filters
// `status: 'active'` so revoked / invited rows never reach the UI.
//
// IMPORTANT - reads the licensing namespace (`license_orgs/`), NOT
// enterprise multi-tenancy.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../models/license_org.dart';
import '../models/license_org_membership.dart';
import 'auth_providers.dart';
import 'license_org_membership_providers.dart';
import 'license_org_overview_providers.dart';

/// Streams the active-member roster for [orgId], ordered by joinedAt
/// ascending. Yields an empty list when:
///   - the group-licensing flag is off
///   - the current user is signed out or anonymous
///   - the org doc is missing or suspended (defence in depth; the
///     security rule also blocks the read in that case)
///   - the repository stream errors
///
/// Suspended-org guard is enforced HERE (not in the repo) so callers
/// that want the raw roster for an admin debug surface in the future
/// can bypass the gate. The mobile sheet always goes through this
/// provider.
final licenseOrgMembersProvider =
    StreamProvider.family<List<LicenseOrgMembership>, String>((
      ref,
      orgId,
    ) async* {
      if (!AppFeatureFlags.isGroupLicensingEnabled) {
        yield const <LicenseOrgMembership>[];
        return;
      }
      if (orgId.isEmpty) {
        yield const <LicenseOrgMembership>[];
        return;
      }
      final user = ref.watch(currentUserProvider);
      if (user == null || user.isAnonymous || user.uid.isEmpty) {
        yield const <LicenseOrgMembership>[];
        return;
      }

      // Defence-in-depth suspended-org guard. The rules block the
      // read anyway, but yielding [] here keeps the UI rendering
      // explanatory copy without round-tripping through an
      // AsyncError state.
      final orgAsync = ref.watch(licenseOrgProvider(orgId));
      final org = orgAsync.maybeWhen(data: (o) => o, orElse: () => null);
      if (org != null && org.status != LicenseOrgStatus.active) {
        yield const <LicenseOrgMembership>[];
        return;
      }

      final repo = ref.watch(licenseOrgMembershipRepositoryProvider);
      yield const <LicenseOrgMembership>[];

      try {
        await for (final members in repo.membersForOrg(orgId)) {
          yield members;
        }
      } catch (e) {
        AppLogging.groupLicensing(
          '[LicenseOrgMembers] stream threw - failing closed '
          '(error class: ${e.runtimeType})',
        );
        yield const <LicenseOrgMembership>[];
      }
    });

/// Pure derivation: number of active members in [orgId]. Returns 0
/// while the underlying provider is loading or errored.
final licenseOrgMemberCountProvider = Provider.family<int, String>((
  ref,
  orgId,
) {
  return ref
      .watch(licenseOrgMembersProvider(orgId))
      .maybeWhen(data: (members) => members.length, orElse: () => 0);
});
