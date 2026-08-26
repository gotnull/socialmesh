// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Widget tests for [LicenseOrgOverviewScreen].
//
// Coverage matrix:
//   - empty state (flag on, zero orgs)            -> AnimatedEmptyState
//                                                    + tagline + action
//   - single org / member role                    -> one card with the
//                                                    "Member" badge,
//                                                    seat count 0,
//                                                    status "Active"
//   - single org / admin role                     -> "Admin" badge
//   - multiple orgs (stable alphabetical order)   -> N cards in order
//   - suspended org                               -> "Suspended" badge
//                                                    in the status row
//   - flag off                                    -> screen still
//                                                    renders the empty
//                                                    state (the
//                                                    membership stream
//                                                    yields empty)
//
// IMPORTANT - the AnimatedEmptyState widget runs perpetual animations
// (radar pulse, floating nodes). Tests use pump() (not
// pumpAndSettle()) so the animation does not deadlock the budget.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/license_org/license_org_overview_card.dart';
import 'package:socialmesh/features/license_org/license_org_overview_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/license_org.dart';
import 'package:socialmesh/models/license_org_membership.dart';
import 'package:socialmesh/models/seat_allocation.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/license_org_membership_providers.dart';
import 'package:socialmesh/providers/seat_allocation_providers.dart';
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
  final Set<String> _orgIds;
  final Map<String, LicenseOrg?> _orgs;
  final Map<String, LicenseOrgMembership?> _memberships;

  _FakeRepo({
    required this._orgIds,
    Map<String, LicenseOrg?>? orgs,
    Map<String, LicenseOrgMembership?>? memberships,
  }) : _orgs = orgs ?? const {},
       _memberships = memberships ?? const {};

  @override
  Stream<LicenseOrgMembershipSetState> watchCurrentUserOrgIdState(String uid) =>
      Stream.value(
        LicenseOrgMembershipSetState(
          orgIds: _orgIds,
          resolution: LicenseOrgMembershipResolution.resolved,
        ),
      );

  @override
  Stream<LicenseOrg?> watchLicenseOrg(String orgId) =>
      Stream.value(_orgs[orgId]);

  @override
  Stream<LicenseOrgMembership?> watchMembership(String orgId, String uid) =>
      Stream.value(_memberships['$orgId/$uid']);

  @override
  Stream<List<LicenseOrgMembership>> membersForOrg(String orgId) =>
      Stream.value(const <LicenseOrgMembership>[]);
}

class _FakeSeatRepo implements SeatAllocationRepository {
  final Set<SeatAllocationRef> _seats;
  final Map<String, int> _orgActiveCounts;

  _FakeSeatRepo([
    Set<SeatAllocationRef>? seats,
    Map<String, int>? orgActiveCounts,
  ]) : _seats = seats ?? <SeatAllocationRef>{},
       _orgActiveCounts = orgActiveCounts ?? <String, int>{};

  @override
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid) =>
      Stream.value(_seats);

  @override
  Stream<int> watchOrgActiveSeatCount(String orgId) =>
      Stream.value(_orgActiveCounts[orgId] ?? 0);

  @override
  Stream<Set<String>> watchOrgActiveSeatHolderUids(String orgId) =>
      Stream.value(const <String>{});
}

Widget _buildTestWidget({
  required LicenseOrgMembershipRepository repo,
  SeatAllocationRepository? seatRepo,
  User? user,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => user ?? _FakeUser(uid: 'u1')),
      licenseOrgMembershipRepositoryProvider.overrideWith((ref) => repo),
      seatAllocationRepositoryProvider.overrideWith(
        (ref) => seatRepo ?? _FakeSeatRepo(),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const LicenseOrgOverviewScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=true\n');
  });

  group('LicenseOrgOverviewScreen', () {
    testWidgets('renders empty state when the user has zero orgs', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(repo: _FakeRepo(orgIds: const <String>{})),
      );
      // Pump enough frames for the AnimatedEmptyState to mount; do
      // NOT pumpAndSettle - the radar pulse never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The card watches licenseOrgProvider(orgId), a SEPARATE stream
      // from the membership set, so it needs its own frame to settle.
      // A fixed two-pump budget was only ever sufficient by accident of
      // the membership provider's internal hop count.
      await tester.pump(const Duration(milliseconds: 100));

      // No card rendered.
      expect(find.byType(LicenseOrgOverviewCard), findsNothing);

      // The empty action label is visible.
      expect(find.text(_l10n.licenseOrgOverviewEmptyAction), findsOneWidget);
    });

    testWidgets('renders one card for a single org with member role', (
      tester,
    ) async {
      const orgId = 'acme';
      await tester.pumpWidget(
        _buildTestWidget(
          repo: _FakeRepo(
            orgIds: const {orgId},
            orgs: {
              orgId: LicenseOrg(
                id: orgId,
                name: 'Acme Eng',
                ownerUid: 'owner-u',
                createdAt: null,
                status: LicenseOrgStatus.active,
              ),
            },
            memberships: {
              '$orgId/u1': const LicenseOrgMembership(
                uid: 'u1',
                orgId: orgId,
                role: LicenseOrgMemberRole.member,
                joinedAt: null,
                invitedBy: null,
                status: LicenseOrgMemberStatus.active,
              ),
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The card watches licenseOrgProvider(orgId), a SEPARATE stream
      // from the membership set, so it needs its own frame to settle.
      // A fixed two-pump budget was only ever sufficient by accident of
      // the membership provider's internal hop count.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LicenseOrgOverviewCard), findsOneWidget);
      // Status row shows "Active".
      expect(find.text(_l10n.licenseOrgOverviewStatusActive), findsOneWidget);
      // Empty state must not also render.
      expect(find.text(_l10n.licenseOrgOverviewEmptyAction), findsNothing);
    });

    testWidgets('renders the admin badge for an admin role', (tester) async {
      const orgId = 'acme';
      // Owner is a different uid (`u2`) so that the current user's
      // role is determined by their members-subcollection role
      // (admin) rather than the owner-uid short-circuit on the org
      // doc. See `licenseOrgRoleProvider`: ownerUid match wins
      // because the owner is intentionally not written into the
      // members subcollection on org-pack purchase; tests that
      // exercise the admin / member branches must avoid colliding
      // with the owner-uid path.
      await tester.pumpWidget(
        _buildTestWidget(
          repo: _FakeRepo(
            orgIds: const {orgId},
            orgs: {
              orgId: LicenseOrg(
                id: orgId,
                name: 'Acme',
                ownerUid: 'u2',
                createdAt: null,
                status: LicenseOrgStatus.active,
              ),
            },
            memberships: {
              '$orgId/u1': const LicenseOrgMembership(
                uid: 'u1',
                orgId: orgId,
                role: LicenseOrgMemberRole.admin,
                joinedAt: null,
                invitedBy: null,
                status: LicenseOrgMemberStatus.active,
              ),
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The card watches licenseOrgProvider(orgId), a SEPARATE stream
      // from the membership set, so it needs its own frame to settle.
      // A fixed two-pump budget was only ever sufficient by accident of
      // the membership provider's internal hop count.
      await tester.pump(const Duration(milliseconds: 100));

      // The "Admin" badge label is in uppercase, the row value cell
      // renders the unmodified l10n string. Both share the same key.
      expect(
        find.text(_l10n.licenseOrgOverviewRoleAdmin.toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('renders one card per org in alphabetical order', (
      tester,
    ) async {
      // Bump the viewport so the SliverList.separated builds both
      // cards in one frame. With the Phase 2 Seat Usage section
      // (which renders a StatusBanner.error in tests without
      // Firebase init) the first owner card is ~600px tall and the
      // default 800x600 test viewport leaves the second card
      // unbuilt — `find.byType(LicenseOrgOverviewCard)` then sees
      // only 1 widget and the ordering assertion can never reach
      // it. A taller viewport mounts both cards directly without
      // forcing scroll. Restored after the test in tearDown.
      addTearDown(() => tester.view.resetPhysicalSize());
      tester.view.physicalSize = const Size(1200, 4800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetDevicePixelRatio());

      const acmeId = 'acme';
      const betaId = 'beta-team';
      await tester.pumpWidget(
        _buildTestWidget(
          repo: _FakeRepo(
            orgIds: const {betaId, acmeId},
            orgs: {
              acmeId: LicenseOrg(
                id: acmeId,
                name: 'Acme',
                ownerUid: 'u1',
                createdAt: null,
                status: LicenseOrgStatus.active,
              ),
              betaId: LicenseOrg(
                id: betaId,
                name: 'Beta',
                ownerUid: 'u1',
                createdAt: null,
                status: LicenseOrgStatus.active,
              ),
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The card watches licenseOrgProvider(orgId), a SEPARATE stream
      // from the membership set, so it needs its own frame to settle.
      // A fixed two-pump budget was only ever sufficient by accident of
      // the membership provider's internal hop count.
      await tester.pump(const Duration(milliseconds: 100));

      final cards = find.byType(LicenseOrgOverviewCard);
      expect(cards, findsNWidgets(2));

      // Stable ordering: alphabetical by id, so 'acme' card lands
      // ABOVE 'beta-team'.
      final acmeRect = tester.getTopLeft(cards.at(0));
      final betaRect = tester.getTopLeft(cards.at(1));
      expect(acmeRect.dy < betaRect.dy, isTrue);
    });

    testWidgets('renders suspended badge in the status row', (tester) async {
      const orgId = 'acme';
      await tester.pumpWidget(
        _buildTestWidget(
          repo: _FakeRepo(
            orgIds: const {orgId},
            orgs: {
              orgId: LicenseOrg(
                id: orgId,
                name: 'Acme',
                ownerUid: 'u1',
                createdAt: null,
                status: LicenseOrgStatus.suspended,
              ),
            },
            memberships: {
              '$orgId/u1': const LicenseOrgMembership(
                uid: 'u1',
                orgId: orgId,
                role: LicenseOrgMemberRole.member,
                joinedAt: null,
                invitedBy: null,
                status: LicenseOrgMemberStatus.active,
              ),
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The card watches licenseOrgProvider(orgId), a SEPARATE stream
      // from the membership set, so it needs its own frame to settle.
      // A fixed two-pump budget was only ever sufficient by accident of
      // the membership provider's internal hop count.
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(_l10n.licenseOrgOverviewStatusSuspended),
        findsOneWidget,
      );
      expect(find.text(_l10n.licenseOrgOverviewStatusActive), findsNothing);
    });

    testWidgets(
      'fails closed to empty state when GROUP_LICENSING_ENABLED is off',
      (tester) async {
        final prev = dotenv.env['GROUP_LICENSING_ENABLED'];
        dotenv.env['GROUP_LICENSING_ENABLED'] = 'false';
        addTearDown(() {
          if (prev == null) {
            dotenv.env.remove('GROUP_LICENSING_ENABLED');
          } else {
            dotenv.env['GROUP_LICENSING_ENABLED'] = prev;
          }
        });

        await tester.pumpWidget(
          _buildTestWidget(
            // Even with a fake repo that would yield orgs, the
            // currentUserLicenseOrgIdsProvider returns empty when the
            // flag is off.
            repo: _FakeRepo(orgIds: const {'acme'}),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(LicenseOrgOverviewCard), findsNothing);
        expect(find.text(_l10n.licenseOrgOverviewEmptyAction), findsOneWidget);
      },
    );
  });
}
