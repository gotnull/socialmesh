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
    required Set<String> orgIds,
    Map<String, LicenseOrg?>? orgs,
    Map<String, LicenseOrgMembership?>? memberships,
  }) : _orgIds = orgIds,
       _orgs = orgs ?? const {},
       _memberships = memberships ?? const {};

  @override
  Stream<Set<String>> watchCurrentUserOrgIds(String uid) =>
      Stream.value(_orgIds);

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

  _FakeSeatRepo([Set<SeatAllocationRef>? seats])
    : _seats = seats ?? <SeatAllocationRef>{};

  @override
  Stream<Set<SeatAllocationRef>> watchCurrentUserSeats(String uid) =>
      Stream.value(_seats);
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

      expect(find.byType(LicenseOrgOverviewCard), findsOneWidget);
      // Status row shows "Active".
      expect(find.text(_l10n.licenseOrgOverviewStatusActive), findsOneWidget);
      // Empty state must not also render.
      expect(find.text(_l10n.licenseOrgOverviewEmptyAction), findsNothing);
    });

    testWidgets('renders the admin badge for an admin role', (tester) async {
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
