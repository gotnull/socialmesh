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

/// Streams the set of license org ids a given uid is an active owner
/// / admin / member of. Implementations MUST fail closed: any error
/// path must emit an empty set rather than rethrow.
abstract class LicenseOrgMembershipRepository {
  /// Emits the current org-id set on subscribe, then re-emits on every
  /// underlying change. Empty set on null / empty uid.
  Stream<Set<String>> watchCurrentUserOrgIds(String uid);
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
  Stream<Set<String>> watchCurrentUserOrgIds(String uid) {
    if (uid.isEmpty) return Stream.value(const <String>{});

    final controller = StreamController<Set<String>>();
    Set<String> ownedIds = const {};
    Set<String> memberIds = const {};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? ownedSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? memberSub;

    void emit() {
      if (controller.isClosed) return;
      controller.add({...ownedIds, ...memberIds});
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
          AppLogging.purchase(
            '[LicenseOrgMembershipRepo] parent license_org fetch failed - '
            'skipping id (error class: ${e.runtimeType})',
          );
          continue;
        }
      }
      memberIds = next;
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
              emit();
            },
            onError: (Object e) {
              AppLogging.purchase(
                '[LicenseOrgMembershipRepo] owned-orgs stream error - '
                'failing closed (error class: ${e.runtimeType})',
              );
              ownedIds = const {};
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
              AppLogging.purchase(
                '[LicenseOrgMembershipRepo] member-orgs stream error - '
                'failing closed (error class: ${e.runtimeType})',
              );
              memberIds = const {};
              emit();
            },
          );

      // Emit an initial empty set so subscribers do not block waiting
      // for the first Firestore snapshot.
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
}
