// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Riverpod wiring for group / community licensing org membership.
//
// Provider graph (read top-down):
//
//   licenseOrgMembershipRepositoryProvider  <- data layer (Firestore by default)
//        |
//        v
//   currentUserLicenseOrgIdsProvider        <- Set<String> of license orgs
//                                              the current user actively
//                                              belongs to, gated by the
//                                              feature flag AND auth state.
//                                              Empty when flag off / guest
//                                              / anonymous.
//
// IMPORTANT - "license orgs" here are the namespace used by group /
// community licensing (collection: `license_orgs/`). They are
// DISTINCT from enterprise multi-tenancy orgs at
// `orgs/{orgId}/members/{uid}` driven by
// `backend/functions/src/org/createOrg.ts`. The two systems have
// different access models (many-orgs-per-user via collection group
// queries here, vs. one-org-per-user via custom claims there) and
// must not share Firestore paths, roles, custom claims, or security
// rules.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/logging.dart';
import '../services/org/license_org_membership_repository.dart';
import 'auth_providers.dart';

/// Injection point for [LicenseOrgMembershipRepository]. Tests
/// override this with a fake repo; production reads from Firestore.
final licenseOrgMembershipRepositoryProvider =
    Provider<LicenseOrgMembershipRepository>((ref) {
      return FirestoreLicenseOrgMembershipRepository();
    });

/// Set of license org ids the current user is an active owner /
/// admin / member of. Yields an empty set when any precondition
/// fails:
///
///   - `AppFeatureFlags.isGroupLicensingEnabled` is false
///   - current user is null (signed out)
///   - current user is anonymous (guest)
///   - current user has an empty uid
///   - the underlying repository stream errors
///
/// This is the only public entry point for "what license orgs does
/// this user belong to?". Future slices that grant org-owned
/// entitlements watch this provider; no other code path should
/// construct a [LicenseOrgMembershipRepository] directly.
final currentUserLicenseOrgIdsProvider = StreamProvider<Set<String>>((
  ref,
) async* {
  if (!AppFeatureFlags.isGroupLicensingEnabled) {
    AppLogging.groupLicensing(
      '[LicenseOrgMembership] feature flag disabled - yielding empty',
    );
    yield const <String>{};
    return;
  }

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    yield const <String>{};
    return;
  }
  if (user.isAnonymous) {
    AppLogging.groupLicensing(
      '[LicenseOrgMembership] anonymous user - yielding empty '
      '(guest mode is license-org-blind)',
    );
    yield const <String>{};
    return;
  }
  if (user.uid.isEmpty) {
    yield const <String>{};
    return;
  }

  final repo = ref.watch(licenseOrgMembershipRepositoryProvider);

  // Yield empty immediately so subscribers do not block on the first
  // Firestore snapshot - matches the offline-first contract used by
  // externalEntitlementsProvider.
  yield const <String>{};

  try {
    await for (final ids in repo.watchCurrentUserOrgIds(user.uid)) {
      yield ids;
    }
  } catch (e) {
    AppLogging.groupLicensing(
      '[LicenseOrgMembership] repository stream threw - failing closed '
      '(error class: ${e.runtimeType})',
    );
    yield const <String>{};
  }
});

/// Convenience checker: does the current user belong to license org
/// [orgId]?
///
/// Returns `false` whenever [currentUserLicenseOrgIdsProvider] is in
/// a loading or error state, so callers never branch on null.
final isCurrentUserInLicenseOrgProvider = Provider.family<bool, String>((
  ref,
  orgId,
) {
  final async = ref.watch(currentUserLicenseOrgIdsProvider);
  return async.maybeWhen(
    data: (ids) => ids.contains(orgId),
    orElse: () => false,
  );
});

/// Imperative refresh hook for diagnostics. Invalidates the stream
/// provider; the next subscriber re-evaluates flag + auth state and
/// re-subscribes to the repository.
void debugRefreshLicenseOrgMembership(WidgetRef ref) {
  AppLogging.groupLicensing('[LicenseOrgMembership] debugRefresh requested');
  ref.invalidate(currentUserLicenseOrgIdsProvider);
}
