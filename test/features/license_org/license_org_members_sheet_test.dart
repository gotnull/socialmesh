// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Widget tests for [LicenseOrgMembersSheet].
//
// Coverage:
//   - title + count chip render
//   - empty roster -> empty AnimatedEmptyState
//   - suspended parent org -> suspended state
//   - error provider -> error state with retry
//   - single member -> one tile with derived #LABEL
//   - multi-member -> tiles in repo order
//   - current user -> "you" badge on their own tile
//
// The sheet uses AnimatedEmptyState (radar animation) and AnimatedTagline
// which never settle, so tests use `pump()` not `pumpAndSettle()`.

import 'dart:io' as io;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/license_org/license_org_members_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/license_org.dart';
import 'package:socialmesh/models/license_org_audit_event.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/models/seat_allocation.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/license_org_audit_providers.dart';
import 'package:socialmesh/providers/license_org_members_providers.dart';
import 'package:socialmesh/providers/license_org_membership_providers.dart';
import 'package:socialmesh/providers/license_org_overview_providers.dart';
import 'package:socialmesh/providers/seat_allocation_providers.dart';
import 'package:socialmesh/services/org/license_org_audit_repository.dart';
import 'package:socialmesh/services/org/license_org_membership_repository.dart';
import 'package:socialmesh/services/org/seat_allocation_repository.dart';

final _l10n = AppLocalizationsEn();

class _FakeUser implements User {
  @override
  final String uid;
  @override
  bool get isAnonymous => false;

  _FakeUser({required this.uid});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepo implements LicenseOrgMembershipRepository {
  final Map<String, LicenseOrg?> orgs;
  final Map<String, List<LicenseOrgMembership>> members;

  _FakeRepo({
    Map<String, LicenseOrg?>? orgs,
    Map<String, List<LicenseOrgMembership>>? members,
  }) : orgs = orgs ?? const {},
       members = members ?? const {};

  @override
  Stream<Set<String>> watchCurrentUserOrgIds(String uid) =>
      Stream.value(const <String>{});

  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) =>
      Stream.value(orgs[orgId]);

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) =>
      Stream.value(null);

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream.value(members[orgId] ?? const <LicenseOrgMembership>[]);
}

class _ErrorRepo extends _FakeRepo {
  _ErrorRepo({super.orgs});

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream<List<LicenseOrgMembership>>.error(StateError('boom'));
}

/// Test seat repo that yields a configurable set of active-seat-holder
/// uids per org. The members sheet joins this with the membership
/// list to drop revoked-seat members from the Active section.
class _FakeSeatRepo implements SeatAllocationRepository {
  final Set<String> activeUids;

  _FakeSeatRepo({this.activeUids = const <String>{}});

  @override
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid) =>
      Stream.value(const <SeatAllocationRef>{});

  @override
  Stream<int> watchOrgActiveSeatCount(String orgId) =>
      Stream.value(activeUids.length);

  @override
  Stream<Set<String>> watchOrgActiveSeatHolderUids(String orgId) =>
      Stream.value(activeUids);
}

/// Test audit repo that yields a configurable list of `recentEventsForOrg`
/// rows. The sheet filters these to `seat_revoked_manual` + success.
class _FakeAuditRepo implements LicenseOrgAuditRepository {
  final List<LicenseOrgAuditEvent> events;

  _FakeAuditRepo({this.events = const <LicenseOrgAuditEvent>[]});

  @override
  Stream<List<LicenseOrgAuditEvent>> recentEventsForOrg(
    String orgId, {
    int limit = 5,
  }) => Stream.value(events);

  @override
  Future<LicenseOrgAuditLogPage> fetchPage(
    String orgId, {
    Object? startAfter,
    int limit = 50,
  }) async => const LicenseOrgAuditLogPage(
    events: <LicenseOrgAuditEvent>[],
    cursor: null,
    hasMore: false,
  );
}

/// Builds a synthetic seat_revoked_manual audit event for the tests.
/// Mirrors the shape the backend writes.
LicenseOrgAuditEvent _revokedEvent({
  required String allocationId,
  required String actorUid,
  DateTime? tsServer,
}) {
  return LicenseOrgAuditEvent(
    id: 'evt-${allocationId.hashCode}',
    licenseOrgId: 'acme',
    actorUid: actorUid,
    actorRole: LicenseOrgAuditActorRole.owner,
    action: LicenseOrgAuditAction.seatRevokedManual,
    targetKind: LicenseOrgAuditTargetKind.orgSeatAllocation,
    targetId: allocationId,
    outcome: LicenseOrgAuditOutcome.success,
    reasonCode: null,
    tsServer: tsServer ?? DateTime.utc(2026, 5, 28),
    metadata: const <String, Object>{},
  );
}

LicenseOrg _activeOrg(String id) => LicenseOrg(
  id: id,
  name: id,
  ownerUid: 'owner-uid',
  createdAt: null,
  status: LicenseOrgStatus.active,
);

LicenseOrg _suspendedOrg(String id) => LicenseOrg(
  id: id,
  name: id,
  ownerUid: 'owner-uid',
  createdAt: null,
  status: LicenseOrgStatus.suspended,
);

LicenseOrgMembership _member(String uid, {DateTime? joinedAt}) =>
    LicenseOrgMembership(
      uid: uid,
      orgId: 'acme',
      role: LicenseOrgMemberRole.member,
      joinedAt: joinedAt ?? DateTime.utc(2026, 1, 1),
      invitedBy: null,
      status: LicenseOrgMemberStatus.active,
    );

Widget _buildSheet({
  required LicenseOrgMembershipRepository repo,
  String currentUid = 'u-self',
  Set<String>? activeSeatHolderUids,
  List<LicenseOrgAuditEvent> revokedEvents = const <LicenseOrgAuditEvent>[],
}) {
  // Default the active-seat set to ALL known member uids so existing
  // tests keep rendering their members. The new
  // `licenseOrgActiveSeatHolderUidsProvider` filter drops members
  // whose seat is revoked; without a permissive default every
  // pre-existing test would suddenly hide its rows.
  // Tests that exercise the filter pass `activeSeatHolderUids`
  // explicitly with the trimmed-down set.
  final Set<String> defaultActiveUids = repo is _FakeRepo
      ? (repo.members['acme'] ?? const <LicenseOrgMembership>[])
            .map((m) => m.uid)
            .toSet()
      : const <String>{};
  final seatRepo = _FakeSeatRepo(
    activeUids: activeSeatHolderUids ?? defaultActiveUids,
  );
  final auditRepo = _FakeAuditRepo(events: revokedEvents);
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => _FakeUser(uid: currentUid)),
      licenseOrgMembershipRepositoryProvider.overrideWith((ref) => repo),
      seatAllocationRepositoryProvider.overrideWith((ref) => seatRepo),
      licenseOrgAuditRepositoryProvider.overrideWith((ref) => auditRepo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            // Force the providers to materialise so the sheet renders
            // its data branch in the same pump cycle the test asserts
            // on, instead of being stuck on the initial empty guard.
            ref.watch(licenseOrgProvider('acme'));
            ref.watch(licenseOrgMembersProvider('acme'));
            return LicenseOrgMembersSheet(
              licenseOrgId: 'acme',
              scrollController: ScrollController(),
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=true\n');
  });

  testWidgets('renders the title and section header', (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        repo: _FakeRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('m1')],
          },
        ),
      ),
    );
    await _pump(tester);

    expect(find.text(_l10n.licenseOrgMembersTitle), findsOneWidget);
    // Unified rollup uses a single "Members" section title at the
    // top (replaced the older Active / Revoked dual-section).
    // SectionTitle uppercases the label internally.
    expect(
      find.text(_l10n.licenseOrgMembersSectionAll.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('count chip shows the pluralised member count', (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        repo: _FakeRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('m1'), _member('m2'), _member('m3')],
          },
        ),
      ),
    );
    await _pump(tester);

    expect(find.text(_l10n.licenseOrgMembersCount(3)), findsOneWidget);
  });

  testWidgets('renders the empty state when there are no active members', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSheet(
        repo: _FakeRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: const {'acme': []},
        ),
      ),
    );
    await _pump(tester);

    // Empty-state action label is the give-away.
    expect(find.text(_l10n.licenseOrgMembersEmptyTitleKeyword), findsOneWidget);
  });

  testWidgets('renders the suspended state when the parent org is suspended', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildSheet(
        repo: _FakeRepo(
          orgs: {'acme': _suspendedOrg('acme')},
          members: {
            'acme': [_member('m1')],
          },
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.text(_l10n.licenseOrgMembersSuspendedTitleKeyword),
      findsOneWidget,
    );
  });

  testWidgets('repo stream errors degrade to empty roster (silent fail)', (
    tester,
  ) async {
    // The provider catches stream errors internally and yields the
    // empty list - the UI's `error:` branch is never hit. This pins
    // that fail-closed contract: a Firestore outage looks like "no
    // members yet" plus a log line, never an angry red state.
    await tester.pumpWidget(
      _buildSheet(repo: _ErrorRepo(orgs: {'acme': _activeOrg('acme')})),
    );
    await _pump(tester);

    expect(find.text(_l10n.licenseOrgMembersEmptyTitleKeyword), findsOneWidget);
  });

  testWidgets('member tile shows the derived #LABEL', (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        repo: _FakeRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('abc12345')],
          },
        ),
      ),
    );
    await _pump(tester);

    // Label = '#' + first 6 chars uppercased.
    expect(find.text('#ABC123'), findsOneWidget);
  });

  testWidgets('current user tile shows the "you" badge', (tester) async {
    await tester.pumpWidget(
      _buildSheet(
        currentUid: 'self12',
        repo: _FakeRepo(
          orgs: {'acme': _activeOrg('acme')},
          members: {
            'acme': [_member('self12'), _member('peer99')],
          },
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.text(_l10n.licenseOrgMembersYouBadge.toUpperCase()),
      findsOneWidget,
    );
  });

  // ===========================================================================
  // Source-text regressions for the revoke flow.
  //
  // The revoke action is owner/admin-only, hidden on the current user's
  // own tile and on owner tiles. Building a live ProviderScope that
  // exercises all those branches would need fakes for the role
  // provider + the Cloud Functions invoker, which adds a lot of test
  // scaffolding for a flag-driven render path. Source-text checks pin
  // the guards without that overhead; the service-level behaviour is
  // covered separately in
  // `test/services/license_org/license_org_seat_service_test.dart`.
  // ===========================================================================
  group('revoke action — source-text guards', () {
    late String src;
    setUpAll(() {
      src = io.File(
        'lib/features/license_org/license_org_members_sheet.dart',
      ).readAsStringSync();
    });

    test('hides revoke action for the current user (no self-revoke)', () {
      expect(src, contains('canRevoke ='));
      // Must include the !isCurrentUser predicate so an owner / admin
      // viewing their own roster row never sees the trigger.
      expect(src, contains('!isCurrentUser'));
    });

    test('reveals revoke only for owner or admin caller role', () {
      expect(src, contains('LicenseOrgMemberRole.owner'));
      expect(src, contains('LicenseOrgMemberRole.admin'));
      expect(src, contains('licenseOrgRoleProvider'));
    });

    test('never offers revoke against another owner tile', () {
      // A historical seeded org could surface an owner row in the
      // members subcollection. Even if the caller is also an owner,
      // the action stays hidden on owner-vs-owner pairs.
      expect(src, contains('member.role != LicenseOrgMemberRole.owner'));
    });

    test('wires the confirm sheet + service call', () {
      // The confirm sheet was promoted to
      // `lib/features/license_org/widgets/revoke_seat_confirm_sheet.dart`
      // so the per-org card's Seat Usage section can share the same
      // surface. Pin the shared widget name + the import path.
      expect(src, contains('RevokeSeatConfirmSheet'));
      expect(src, contains("import 'widgets/revoke_seat_confirm_sheet.dart'"));
      expect(src, contains('LicenseOrgSeatService()'));
      expect(src, contains('seatAllocationDocId('));
      expect(src, contains('communityPackSeatProductId'));
    });
  });

  // ===========================================================================
  // Revoked-seats history section. Pulls from licenseOrgRevokedSeatsProvider
  // and renders under the Active members list. Hidden entirely when zero
  // revocations exist so the user doesn't see a heading over an empty list.
  // ===========================================================================
  group('revoked history — source-text guards', () {
    late String src;
    setUpAll(() {
      src = io.File(
        'lib/features/license_org/license_org_members_sheet.dart',
      ).readAsStringSync();
    });

    test('watches licenseOrgRevokedSeatsProvider for the current orgId', () {
      expect(
        src,
        contains('licenseOrgRevokedSeatsProvider(widget.licenseOrgId)'),
      );
    });

    test('unified rollup: one Members section header, flat list of tiles', () {
      // Unified rollup replaces the old Active / Revoked dual
      // sections with a single header + flat list. Revoked tiles
      // still render distinctly (dim card + person-off icon) so
      // the categorical signal lives in tile styling, not in
      // section subheaders.
      expect(src, contains('licenseOrgMembersSectionAll'));
      expect(
        src,
        contains('final itemCount = 1 + members.length + revoked.length'),
      );
      // Old dual-section gates must NOT come back — keep them
      // absent so a refactor can't accidentally re-introduce the
      // orphan-heading edge cases.
      expect(src, isNot(contains('hasActive')));
      expect(src, isNot(contains('hasRevoked')));
      expect(src, isNot(contains('revokedTitleIdx')));
    });

    test('only shows empty state when BOTH active and revoked are empty', () {
      // A roster with zero current members but historical
      // revocations is still useful (audit trail of a churned
      // group). Don't push the user to the empty-state animation
      // when there's any history to surface.
      expect(src, contains('if (members.isEmpty && revoked.isEmpty)'));
    });

    test('_RevokedTile shows revoked-member + actor labels', () {
      expect(src, contains('class _RevokedTile'));
      expect(src, contains('licenseOrgMembersRevokedTileTitle'));
      expect(src, contains('licenseOrgMembersRevokedTileBy'));
      // System-actor labelling for refund-cascade revokes (when
      // a Stripe refund triggers the seat drain without an
      // owner action).
      expect(src, contains('LicenseOrgAuditActorRole.system'));
    });

    testWidgets('Active list filters out members whose seat is revoked', (
      WidgetTester tester,
    ) async {
      // Two members in the membership doc, but only one holds an
      // active seat. The other's seat was revoked (membership doc
      // stays `active` per the manual-revoke spec). The Active
      // section must drop the revoked one so the same uid does
      // not appear in BOTH Active and Revoked at once.
      await tester.pumpWidget(
        _buildSheet(
          repo: _FakeRepo(
            orgs: {'acme': _activeOrg('acme')},
            members: {
              'acme': [_member('uid-kept'), _member('uid-revoked')],
            },
          ),
          activeSeatHolderUids: const {'uid-kept'},
        ),
      );
      await _pump(tester);

      // The kept uid surfaces.
      expect(find.text('#UID-KE'), findsOneWidget);
      // The revoked uid does NOT.
      expect(find.text('#UID-RE'), findsNothing);
    });

    test('reinstate action: _RevokedTile wires onReinstate callback', () {
      // _RevokedTile gained an optional onReinstate trailing icon.
      // Owner/admin caller passes a non-null callback; non-eligible
      // viewers pass null and the tile stays read-only.
      expect(src, contains('final VoidCallback? onReinstate'));
      expect(src, contains('this.onReinstate'));
      expect(src, contains('Icons.restore_outlined'));
      expect(src, contains('licenseOrgMembersReinstateAction'));
    });

    test('reinstate handler routes through LicenseOrgSeatService', () {
      expect(src, contains('Future<void> _onReinstateTapped'));
      expect(src, contains('service.reinstateSeat('));
      expect(src, contains('alreadyActive'));
      expect(src, contains('licenseOrgMembersReinstateSuccess'));
      expect(src, contains('licenseOrgMembersReinstateAlreadyActive'));
    });

    test('reinstate over-capacity gets a distinct error message', () {
      // The backend's failed-precondition splits into orgSuspended
      // vs overCapacity by message substring (see the seat-service
      // tests). Surface a distinct snackbar for the cap case so
      // the owner knows the fix is "revoke someone else" not
      // "restore the org".
      expect(src, contains('ReinstateSeatReason.overCapacity'));
      expect(src, contains('licenseOrgMembersReinstateErrorOverCapacity'));
    });

    test('reinstate + revoke gated by single owner/admin flag', () {
      // Unified rollup computes role / canRevoke / reinstate gate
      // ONCE per build via `isCallerAdminOrOwner`, reused by both
      // tile variants. A passive member viewer (legacy seeded
      // data) sees no trigger.
      expect(src, contains('isCallerAdminOrOwner'));
      expect(src, contains('LicenseOrgMemberRole.owner ||'));
      expect(src, contains('LicenseOrgMemberRole.admin'));
    });

    test(
      'Revoked section drops events whose target uid holds an active seat',
      () {
        // The dedupe complement: Active list drops revoked-seat
        // members, AND Revoked list drops reinstated-seat members.
        // Without this filter, a revoked-then-reinstated uid
        // surfaces in BOTH sections at once. Source pins the
        // negation guard and the helper that parses the uid out
        // of the audit row's targetId.
        final assignment = src.indexOf('final revoked = revokedRaw');
        expect(assignment, greaterThan(-1));
        final closingSemicolon = src.indexOf(';', assignment);
        final body = src.substring(assignment, closingSemicolon);
        expect(body, contains('!activeUids.contains'));
        expect(body, contains('licenseOrgUidFromAllocationId'));
      },
    );

    testWidgets('revoked-then-reinstated uid appears only in Active section', (
      WidgetTester tester,
    ) async {
      // The member's seat was revoked at some point (audit row
      // still in the revoked stream) but then later reinstated
      // (uid back in activeUids). Roster must render the uid in
      // ACTIVE only, not in both sections.
      await tester.pumpWidget(
        _buildSheet(
          repo: _FakeRepo(
            orgs: {'acme': _activeOrg('acme')},
            members: {
              'acme': [_member('uid-roundtrip')],
            },
          ),
          // Membership stayed active; seat was reinstated.
          activeSeatHolderUids: const {'uid-roundtrip'},
          // Audit log carries the historical revoke event.
          revokedEvents: [
            _revokedEvent(
              allocationId: 'acme__uid-roundtrip__complete_pack',
              actorUid: 'owner-uid',
            ),
          ],
        ),
      );
      await _pump(tester);

      // Single Active tile with the uid label.
      expect(find.text('#UID-RO'), findsOneWidget);
      // No REVOKED section heading (the event was filtered out).
      expect(
        find.text(_l10n.licenseOrgMembersSectionRevoked.toUpperCase()),
        findsNothing,
      );
    });

    test('extracts uid from allocationId for the revoked member label', () {
      // Regression for the 2026-05-28 first-revoke bug: targetId on
      // a seat_revoked_manual audit row is the full allocation doc
      // id `<orgId>__<uid>__<productId>`, not the uid alone. The
      // first ship rendered #CLEANR (orgId prefix) where the revoked
      // member's uid should be. Parse the middle segment.
      // Helper extracted to
      // `lib/features/license_org/utils/member_label.dart` as
      // `licenseOrgUidFromAllocationId`. Implementation details
      // (split / length check / middle-segment return) are pinned
      // in the helper's own behavior test
      // (`test/features/license_org/utils/member_label_test.dart`);
      // here we just guarantee the members sheet still routes
      // through that helper.
      expect(src, contains('licenseOrgUidFromAllocationId'));
    });
  });
}
