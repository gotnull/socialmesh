// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Teams provider surface.
//
// Teams is a PRESENTATION composition. It introduces no repository, no
// persistence and no second notion of organisation membership - every
// provider here derives from an existing authority:
//
//   currentUserLicenseOrgMembershipStateProvider  membership truth
//   isOnlineProvider                              copy selection only
//   AppFeatureFlags.isTeamsEnabled                product visibility
//
// See docs/teams/PHASE-1-DESIGN.md.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connectivity_providers.dart';
import '../../../providers/license_org_membership_providers.dart';
import '../../../services/org/license_org_membership_repository.dart';
import 'teams_list_state.dart';

/// Mirrors the product visibility gate so tests can flip it without
/// touching dotenv.
final teamsEnabledProvider = Provider<bool>(
  (ref) => AppFeatureFlags.isTeamsEnabled,
);

/// True when the signed-in account is durable enough to hold
/// membership. Anonymous uids do not survive a reinstall, and every
/// licensing surface already excludes them.
final teamsHasDurableAccountProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null && !user.isAnonymous && user.uid.isNotEmpty;
});

/// What the Teams list should render.
final teamsListStateProvider = Provider<TeamsListState>((ref) {
  final membership = ref
      .watch(currentUserLicenseOrgMembershipStateProvider)
      .maybeWhen(
        data: (state) => state,
        // Loading / error on the AsyncValue itself is the same
        // situation as an unresolved stream: no answer yet.
        orElse: () => LicenseOrgMembershipSetState.unresolved,
      );

  return deriveTeamsListState(
    featureEnabled: ref.watch(teamsEnabledProvider),
    hasDurableAccount: ref.watch(teamsHasDurableAccountProvider),
    membership: membership,
    isOnline: ref.watch(isOnlineProvider),
  );
});

/// Re-resolve membership after a failure.
///
/// Invalidates the AUTHORITY rather than any Teams-local copy, so the
/// same provider transitions failed -> pending -> resolved/failed and
/// every consumer (not just Teams) sees the retry. Teams deliberately
/// holds no `isRetrying` flag of its own; there is nothing here to get
/// out of sync.
void retryTeamsMembership(WidgetRef ref) {
  ref.invalidate(currentUserLicenseOrgMembershipStateProvider);
}
