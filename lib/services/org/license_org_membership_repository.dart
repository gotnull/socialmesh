// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Data layer for group / community licensing org membership.
//
// The repository's only public contract is "stream the set of license
// org ids the given uid currently belongs to". It returns ids only;
// org doc hydration (name, owner, created-at) is deliberately not
// exposed here because no downstream consumer needs it in this
// groundwork slice and exposing more would invite premature coupling.
//
// Fail-closed everywhere: missing rows, malformed data, suspended
// orgs, and Firestore errors all degrade to "this id does not
// belong to the current user" rather than throw into the provider
// stream. See docs/engineering/GROUP_LICENSING_FOUNDATION.md.
//
// IMPORTANT - this reads from the `license_orgs/` namespace, NOT the
// enterprise multi-tenancy `orgs/` namespace owned by
// backend/functions/src/org/createOrg.ts. The two collections must
// not share Firestore paths, roles, custom claims, or security rules.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/logging.dart';
import '../../models/license_org.dart';
import '../../models/license_org_membership.dart';

/// How far the membership query has got.
///
/// A boolean would conflate [pending] with [failed], and those need
/// different surfaces: pending is a spinner, failed needs an
/// explanation and a retry. Collapsing them would leave a screen
/// showing "Checking..." forever after a hard failure, with no
/// recovery affordance and nothing to indicate anything is wrong -
/// which is worse than a wrong empty state, because it is a dead end.
enum LicenseOrgMembershipResolution {
  /// No answer yet: the synchronous sentinel, or a query still in
  /// flight. Also the terminal state for the auth / feature gates,
  /// which never consult the server at all - surfaces must handle
  /// signed-out, anonymous and flag-off explicitly rather than falling
  /// through to this.
  pending,

  /// Every underlying query answered. [LicenseOrgMembershipSetState.orgIds]
  /// is authoritative, and an empty set here genuinely means "belongs
  /// to no organisations".
  resolved,

  /// At least one underlying query failed. The ids still fail closed to
  /// empty, but that empty set is not an answer.
  failed,
}

/// Combine the per-query resolutions into the union's resolution.
///
/// Failure dominates: if either query failed, the union can only ever
/// be a subset, so reporting it as authoritative would understate the
/// user's memberships. Otherwise both must have answered.
LicenseOrgMembershipResolution _combine(
  LicenseOrgMembershipResolution owned,
  LicenseOrgMembershipResolution member,
) {
  if (owned == LicenseOrgMembershipResolution.failed ||
      member == LicenseOrgMembershipResolution.failed) {
    return LicenseOrgMembershipResolution.failed;
  }
  if (owned == LicenseOrgMembershipResolution.resolved &&
      member == LicenseOrgMembershipResolution.resolved) {
    return LicenseOrgMembershipResolution.resolved;
  }
  return LicenseOrgMembershipResolution.pending;
}

/// The org-id set plus whether it is an authoritative answer yet.
///
/// Exists because an empty set alone is ambiguous. The stream emits
/// `{}` synchronously on subscribe so nothing blocks on a Firestore
/// round trip, which means a consumer seeing `{}` cannot tell
/// "you belong to no organisations" from "we have not asked yet" or
/// "the query failed". Entitlement code does not care - both mean
/// grant nothing - but a user-facing surface that renders
/// "You're not in any organisation" on the sentinel would be stating
/// something demonstrably false during normal startup.
///
/// This is metadata ABOUT the same single membership source, not a
/// second source of membership truth. There is exactly one authority
/// with two projections: [orgIds] for access decisions and
/// [hasResolvedRemote] for honest presentation.
class LicenseOrgMembershipSetState {
  /// Org ids the user is an active owner / admin / member of.
  ///
  /// Fails closed identically in every error path, exactly as before:
  /// an error yields the empty set, never a retained stale set.
  final Set<String> orgIds;

  /// How far the underlying queries got. See
  /// [LicenseOrgMembershipResolution].
  final LicenseOrgMembershipResolution resolution;

  const LicenseOrgMembershipSetState({
    required this.orgIds,
    required this.resolution,
  });

  /// The synchronous sentinel: nothing known yet.
  static const LicenseOrgMembershipSetState unresolved =
      LicenseOrgMembershipSetState(
        orgIds: <String>{},
        resolution: LicenseOrgMembershipResolution.pending,
      );

  /// A query failed. Ids still fail closed to empty, but a surface must
  /// offer recovery rather than sit in a spinner.
  static const LicenseOrgMembershipSetState failed =
      LicenseOrgMembershipSetState(
        orgIds: <String>{},
        resolution: LicenseOrgMembershipResolution.failed,
      );

  /// True only when [orgIds] is an authoritative answer.
  ///
  /// The one predicate a surface may use to decide whether an empty set
  /// can be rendered as "you belong to no organisations".
  bool get hasResolvedRemote =>
      resolution == LicenseOrgMembershipResolution.resolved;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LicenseOrgMembershipSetState &&
          resolution == other.resolution &&
          orgIds.length == other.orgIds.length &&
          orgIds.containsAll(other.orgIds);

  @override
  int get hashCode => Object.hash(resolution, Object.hashAllUnordered(orgIds));

  @override
  String toString() =>
      'LicenseOrgMembershipSetState(count: ${orgIds.length}, '
      'resolution: ${resolution.name})';
}

/// Streams the set of license org ids a given uid is an active owner
/// / admin / member of. Implementations MUST fail closed: any error
/// path must emit an empty set rather than rethrow.
abstract class LicenseOrgMembershipRepository {
  /// Emits the current org-id set plus its resolution state on
  /// subscribe, then re-emits on every underlying change. Empty and
  /// unresolved on null / empty uid.
  ///
  /// The id-set semantics are unchanged from the original
  /// `Stream<Set<String>>` contract - same values, same timing, same
  /// fail-closed error behaviour. Only the resolution metadata is new.
  Stream<LicenseOrgMembershipSetState> watchCurrentUserOrgIdState(String uid);

  /// Streams the [LicenseOrg] doc at `license_orgs/{orgId}`. Emits
  /// null when the doc is missing, malformed, suspended, or on any
  /// underlying error. Used by the Overview screen for read-only org
  /// metadata (name, status, ownerUid, createdAt).
  Stream<LicenseOrg?> watchLicenseOrg(String orgId);

  /// Streams the per-user membership row at
  /// `license_orgs/{orgId}/members/{uid}`. Emits null when the doc is
  /// missing, malformed, or on any underlying error.
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid);

  /// Streams the full active-member roster for [orgId], ordered by
  /// joinedAt ascending. Revoked / invited rows are filtered out at
  /// the repository layer so consumers never need to apply the
  /// status filter themselves. Empty list on missing org, suspended
  /// org, or any underlying error.
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId);
}

/// Firestore-backed implementation.
///
/// Reads two sources and unions them:
///   1. `license_orgs.where(ownerUid == uid).where(status == 'active')`
///   2. `collectionGroup('members').where(uid == uid).where(status == 'active')`
///      then, per matched member row, a defensive parent-org fetch
///      that drops the id when the parent org is missing or not
///      `status == 'active'`.
///
/// The parent-org fetch is what prevents a membership in a suspended
/// org from leaking through. It also catches inconsistent-write
/// windows where the member row landed before the org doc was
/// created.
///
/// Collection group query safety: this query matches `members`
/// subcollections under ANY parent path - including the enterprise
/// multi-tenancy `orgs/{orgId}/members/{uid}` namespace. Two layers
/// drop enterprise rows that happen to land in the query:
///   1. The `status == 'active'` filter (enterprise member docs do
///      not carry a `status` field).
///   2. The parent-org fetch against `license_orgs/{orgId}` - if the
///      orgId only exists under `orgs/`, the fetch returns no doc
///      and the id is dropped.
class FirestoreLicenseOrgMembershipRepository
    implements LicenseOrgMembershipRepository {
  final FirebaseFirestore _firestore;

  FirestoreLicenseOrgMembershipRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<LicenseOrgMembershipSetState> watchCurrentUserOrgIdState(String uid) {
    if (uid.isEmpty) {
      return Stream.value(LicenseOrgMembershipSetState.unresolved);
    }

    final controller = StreamController<LicenseOrgMembershipSetState>();
    Set<String> ownedIds = const {};
    Set<String> memberIds = const {};
    // Resolution is tracked per underlying query and combined. A user
    // can own one org and be a member of another, so the answer is only
    // authoritative once BOTH have reported - treating either alone as
    // resolved would let an empty owned-set be presented as "no
    // organisations" while the membership query was still in flight.
    //
    // A failure in EITHER query poisons the union: the remaining query
    // can only ever produce a subset, so reporting it as authoritative
    // would understate the user's memberships.
    var ownedResolution = LicenseOrgMembershipResolution.pending;
    var memberResolution = LicenseOrgMembershipResolution.pending;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? memberSub;

    void emit() {
      if (controller.isClosed) return;
      controller.add(
        LicenseOrgMembershipSetState(
          orgIds: {...ownedIds, ...memberIds},
          resolution: _combine(ownedResolution, memberResolution),
        ),
      );
    }

    Future<void> handleMemberSnapshot(
      QuerySnapshot<Map<String, dynamic>> snap,
    ) async {
      final next = <String>{};
      for (final doc in snap.docs) {
        final membership = LicenseOrgMembership.fromFirestore(doc);
        if (membership == null) continue;
        if (!membership.isAccessActive) continue;
        try {
          final orgDoc = await _firestore
              .collection('license_orgs')
              .doc(membership.orgId)
              .get();
          final org = LicenseOrg.fromFirestore(orgDoc);
          if (org == null || !org.isAccessActive) continue;
          next.add(membership.orgId);
        } catch (e) {
          AppLogging.groupLicensing(
            '[LicenseOrgMembershipRepo] parent license_org fetch failed - '
            'skipping id (error class: ${e.runtimeType})',
          );
          continue;
        }
      }
      memberIds = next;
      memberResolution = LicenseOrgMembershipResolution.resolved;
      emit();
    }

    controller.onListen = () {
      ownedSub = _firestore
          .collection('license_orgs')
          .where('ownerUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen(
            (snap) {
              ownedIds = snap.docs
                  .map(LicenseOrg.fromFirestore)
                  .where((o) => o != null && o.isAccessActive)
                  .map((o) => o!.id)
                  .toSet();
              ownedResolution = LicenseOrgMembershipResolution.resolved;
              emit();
            },
            onError: (Object e) {
              AppLogging.groupLicensing(
                '[LicenseOrgMembershipRepo] owned-orgs stream error - '
                'failing closed (error class: ${e.runtimeType})',
              );
              ownedIds = const {};
              // Ids still fail closed exactly as before. Resolution
              // drops too: after a failure we no longer hold an
              // authoritative answer, so a surface must not render the
              // empty set as a confident "no organisations".
              ownedResolution = LicenseOrgMembershipResolution.failed;
              emit();
            },
          );

      memberSub = _firestore
          .collectionGroup('members')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .snapshots()
          .listen(
            (snap) {
              // Fire-and-forget the async per-doc validation. New
              // snapshots supersede in-flight ones because the
              // controller's last `add` wins for any subscriber.
              unawaited(handleMemberSnapshot(snap));
            },
            onError: (Object e) {
              AppLogging.groupLicensing(
                '[LicenseOrgMembershipRepo] member-orgs stream error - '
                'failing closed (error class: ${e.runtimeType})',
              );
              memberIds = const {};
              memberResolution = LicenseOrgMembershipResolution.failed;
              emit();
            },
          );

      // Emit an initial empty, UNRESOLVED state so subscribers do not
      // block waiting for the first Firestore snapshot. Consumers that
      // only need access decisions read the ids and fail closed;
      // consumers that render text must check hasResolvedRemote before
      // claiming the user belongs to nothing.
      emit();
    };

    controller.onCancel = () async {
      await ownedSub?.cancel();
      await memberSub?.cancel();
      ownedSub = null;
      memberSub = null;
    };

    return controller.stream;
  }

  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) {
    if (orgId.isEmpty) return Stream.value(null);

    final controller = StreamController<LicenseOrg?>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;

    controller.onListen = () {
      sub = _firestore
          .collection('license_orgs')
          .doc(orgId)
          .snapshots()
          .listen(
            (snap) {
              if (controller.isClosed) return;
              if (!snap.exists) {
                controller.add(null);
                return;
              }
              controller.add(LicenseOrg.fromFirestore(snap));
            },
            onError: (Object e) {
              AppLogging.groupLicensing(
                '[LicenseOrgMembershipRepo] watchLicenseOrg stream error - '
                'failing closed (error class: ${e.runtimeType})',
              );
              if (controller.isClosed) return;
              controller.add(null);
            },
          );
    };

    controller.onCancel = () async {
      await sub?.cancel();
      sub = null;
    };

    return controller.stream;
  }

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) {
    if (orgId.isEmpty || uid.isEmpty) return Stream.value(null);

    final controller = StreamController<LicenseOrgMembership?>();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? sub;

    controller.onListen = () {
      sub = _firestore
          .collection('license_orgs')
          .doc(orgId)
          .collection('members')
          .doc(uid)
          .snapshots()
          .listen(
            (snap) {
              if (controller.isClosed) return;
              if (!snap.exists) {
                controller.add(null);
                return;
              }
              controller.add(LicenseOrgMembership.fromFirestore(snap));
            },
            onError: (Object e) {
              AppLogging.groupLicensing(
                '[LicenseOrgMembershipRepo] watchMembership stream error - '
                'failing closed (error class: ${e.runtimeType})',
              );
              if (controller.isClosed) return;
              controller.add(null);
            },
          );
    };

    controller.onCancel = () async {
      await sub?.cancel();
      sub = null;
    };

    return controller.stream;
  }

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) {
    if (orgId.isEmpty) return Stream.value(const <LicenseOrgMembership>[]);

    final controller = StreamController<List<LicenseOrgMembership>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;

    controller.onListen = () {
      sub = _firestore
          .collection('license_orgs')
          .doc(orgId)
          .collection('members')
          .where('status', isEqualTo: 'active')
          .orderBy('joinedAt')
          .snapshots()
          .listen(
            (snap) {
              if (controller.isClosed) return;
              final result = <LicenseOrgMembership>[];
              for (final doc in snap.docs) {
                final m = LicenseOrgMembership.fromFirestore(doc);
                if (m == null) continue;
                if (!m.isAccessActive) continue;
                result.add(m);
              }
              controller.add(result);
            },
            onError: (Object e) {
              AppLogging.groupLicensing(
                '[LicenseOrgMembershipRepo] membersForOrg stream error - '
                'failing closed (error class: ${e.runtimeType})',
              );
              if (controller.isClosed) return;
              controller.add(const <LicenseOrgMembership>[]);
            },
          );
    };

    controller.onCancel = () async {
      await sub?.cancel();
      sub = null;
    };

    return controller.stream;
  }
}
