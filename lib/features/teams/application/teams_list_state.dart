// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Presentation read-model for the Teams list.
//
// Teams owns NO organisational data. It is a composition over the
// existing licensing authorities:
//
//   currentUserLicenseOrgMembershipStateProvider  <- membership truth
//   isOnlineProvider                              <- presentation context only
//
// Connectivity never determines membership. It only chooses which copy
// to show while membership is still `pending`, so a healthy launch says
// "checking" rather than either lying about emptiness or claiming to be
// offline.
//
// See docs/teams/PHASE-1-DESIGN.md.

import '../../../services/org/license_org_membership_repository.dart';

/// What the Teams list should render.
///
/// A sealed hierarchy rather than a flags bag so the impossible states
/// cannot be constructed. In particular [TeamsUnavailable] carries NO
/// org ids: when one underlying query fails, the surviving half is a
/// potentially incomplete union, and rendering it as a list would
/// present a partial answer as a complete one. The type makes that
/// mistake unrepresentable rather than relying on the widget to
/// remember.
sealed class TeamsListState {
  const TeamsListState();
}

/// The product surface is switched off for this build.
class TeamsDisabled extends TeamsListState {
  const TeamsDisabled();
}

/// Signed out, or signed in anonymously. Teams needs a durable account
/// because membership is keyed by uid and an anonymous uid does not
/// survive a reinstall.
class TeamsAccountRequired extends TeamsListState {
  const TeamsAccountRequired();
}

/// Membership has not resolved yet and the device is online, so the
/// answer is probably moments away. Renders as progress, never as
/// "you have no teams".
class TeamsChecking extends TeamsListState {
  const TeamsChecking();
}

/// Membership has not resolved and the device is offline. We genuinely
/// cannot know, and say so.
class TeamsOfflineUnknown extends TeamsListState {
  const TeamsOfflineUnknown();
}

/// A membership query failed. Distinct from [TeamsChecking] because it
/// is terminal until something retries - a spinner here would be a dead
/// end with no recovery affordance.
class TeamsUnavailable extends TeamsListState {
  const TeamsUnavailable();
}

/// An authoritative answer: this account belongs to no organisations.
/// The only state that may say so.
class TeamsEmpty extends TeamsListState {
  const TeamsEmpty();
}

/// An authoritative, complete list.
class TeamsLoaded extends TeamsListState {
  /// Org ids, sorted for a stable render order.
  final List<String> orgIds;

  const TeamsLoaded(this.orgIds);
}

/// Derive the list state from the membership authority plus context.
///
/// Precedence matters and is deliberate:
///
///   1. feature gate     - the surface should not exist
///   2. account          - membership is meaningless without a durable uid
///   3. failed           - before any emptiness reasoning, because a
///                         failed union may be non-empty yet incomplete
///   4. pending          - split by connectivity for copy only
///   5. resolved         - the only branch permitted to assert emptiness
///
/// [isOnline] is consulted in exactly one place: choosing between the
/// two `pending` presentations.
TeamsListState deriveTeamsListState({
  required bool featureEnabled,
  required bool hasDurableAccount,
  required LicenseOrgMembershipSetState membership,
  required bool isOnline,
}) {
  if (!featureEnabled) return const TeamsDisabled();
  if (!hasDurableAccount) return const TeamsAccountRequired();

  switch (membership.resolution) {
    case LicenseOrgMembershipResolution.failed:
      // Deliberately drops any ids the surviving query produced. A
      // partial union presented as a list is a false completeness
      // claim; the user is better served by an honest retry.
      return const TeamsUnavailable();

    case LicenseOrgMembershipResolution.pending:
      return isOnline ? const TeamsChecking() : const TeamsOfflineUnknown();

    case LicenseOrgMembershipResolution.resolved:
      if (membership.orgIds.isEmpty) return const TeamsEmpty();
      final sorted = membership.orgIds.toList()..sort();
      return TeamsLoaded(sorted);
  }
}
