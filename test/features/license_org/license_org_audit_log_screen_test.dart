// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Widget tests for [LicenseOrgAuditLogScreen]. Coverage:
//
//   - Empty state (zero events from repo)         -> AnimatedEmptyState
//   - Three success events                         -> 3 rows, no "Load more"
//   - 50 events with hasMore                       -> "Load more" visible
//   - "Load more" tap                              -> appends next page,
//                                                     repo.fetchPageCallCount
//                                                     increments
//   - Outcome chip-selector counts                 -> chip labels show
//                                                     correct counts
//
// The AnimatedEmptyState runs perpetual animations, so tests use
// pump() (not pumpAndSettle()) so the budget never deadlocks.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/license_org/license_org_audit_log_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/license_org_audit_event.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/license_org_audit_providers.dart';
import 'package:socialmesh/services/org/license_org_audit_repository.dart';

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

class _StubRepo implements LicenseOrgAuditRepository {
  final List<LicenseOrgAuditEvent> events;
  int fetchPageCallCount = 0;

  _StubRepo(this.events);

  @override
  Stream<List<LicenseOrgAuditEvent>> recentEventsForOrg(
    String orgId, {
    int limit = 5,
  }) => Stream.value(events.take(limit).toList(growable: false));

  @override
  Future<LicenseOrgAuditLogPage> fetchPage(
    String orgId, {
    Object? startAfter,
    int limit = 50,
  }) async {
    fetchPageCallCount++;
    final start = startAfter is int ? startAfter : 0;
    final slice = events.skip(start).take(limit).toList(growable: false);
    final nextIndex = start + slice.length;
    return LicenseOrgAuditLogPage(
      events: slice,
      cursor: slice.isEmpty ? null : nextIndex,
      hasMore: nextIndex < events.length,
    );
  }
}

LicenseOrgAuditEvent _event(
  String id, {
  LicenseOrgAuditAction action = LicenseOrgAuditAction.memberJoined,
  LicenseOrgAuditOutcome outcome = LicenseOrgAuditOutcome.success,
}) => LicenseOrgAuditEvent(
  id: id,
  licenseOrgId: 'acme',
  action: action,
  targetKind: LicenseOrgAuditTargetKind.licenseOrgMembership,
  targetId: 'target-$id',
  actorUid: 'actor-uid-$id',
  actorRole: LicenseOrgAuditActorRole.admin,
  outcome: outcome,
  reasonCode: null,
  tsServer: DateTime.utc(2026, 5, 26, 12, 0),
  metadata: const {},
);

Widget _buildTestWidget({
  required LicenseOrgAuditRepository repo,
  String orgId = 'acme',
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith((ref) => _FakeUser(uid: 'u1')),
      licenseOrgAuditRepositoryProvider.overrideWith((ref) => repo),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: LicenseOrgAuditLogScreen(orgId: orgId),
    ),
  );
}

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'GROUP_LICENSING_ENABLED=true\n');
  });

  group('LicenseOrgAuditLogScreen', () {
    testWidgets('renders empty state when repo returns zero events', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildTestWidget(repo: _StubRepo(const <LicenseOrgAuditEvent>[])),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Filter chip-selector is not visible in the empty state.
      expect(find.text(_l10n.licenseOrgAuditLogLoadMore), findsNothing);
      // The end-of-feed marker also doesn't appear (whole list is hidden).
      expect(find.text(_l10n.licenseOrgAuditLogEndOfFeed), findsNothing);
    });

    testWidgets(
      'renders three rows and end-of-feed when repo returns three events',
      (tester) async {
        final repo = _StubRepo([_event('e1'), _event('e2'), _event('e3')]);
        await tester.pumpWidget(_buildTestWidget(repo: repo));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(_l10n.licenseOrgAuditLogEndOfFeed), findsOneWidget);
        expect(find.text(_l10n.licenseOrgAuditLogLoadMore), findsNothing);
        // Filter chip "All (3)" rendered.
        expect(
          find.text(_l10n.licenseOrgAuditFilterAllWithCount(3)),
          findsOneWidget,
        );
        expect(repo.fetchPageCallCount, 1);
      },
    );

    testWidgets('renders Load more button when first page has hasMore', (
      tester,
    ) async {
      final events = List.generate(120, (i) => _event('e$i'));
      final repo = _StubRepo(events);
      await tester.pumpWidget(_buildTestWidget(repo: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // ListView is lazy - scroll the inner list to materialize the
      // footer item that hosts the Load-more / End-of-feed marker.
      await tester.scrollUntilVisible(
        find.text(_l10n.licenseOrgAuditLogLoadMore),
        500,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text(_l10n.licenseOrgAuditLogLoadMore), findsOneWidget);
      expect(find.text(_l10n.licenseOrgAuditLogEndOfFeed), findsNothing);
      expect(repo.fetchPageCallCount, 1);
    });

    testWidgets('Load more tap appends next page', (tester) async {
      final events = List.generate(120, (i) => _event('e$i'));
      final repo = _StubRepo(events);
      await tester.pumpWidget(_buildTestWidget(repo: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.scrollUntilVisible(
        find.text(_l10n.licenseOrgAuditLogLoadMore),
        500,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text(_l10n.licenseOrgAuditLogLoadMore));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.fetchPageCallCount, 2);
      // After 2 pages, 100/120 events loaded, still hasMore.
      expect(
        find.text(_l10n.licenseOrgAuditFilterAllWithCount(100)),
        findsOneWidget,
      );
    });

    testWidgets('chip counts split success/rejected events', (tester) async {
      final repo = _StubRepo([
        _event('e1'),
        _event('e2', outcome: LicenseOrgAuditOutcome.rejected),
        _event('e3'),
      ]);
      await tester.pumpWidget(_buildTestWidget(repo: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text(_l10n.licenseOrgAuditFilterAllWithCount(3)),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.licenseOrgAuditFilterSuccessWithCount(2)),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.licenseOrgAuditFilterRejectedWithCount(1)),
        findsOneWidget,
      );
    });

    testWidgets('action picker filters list + updates outcome chip counts', (
      tester,
    ) async {
      final repo = _StubRepo([
        _event('e1', action: LicenseOrgAuditAction.memberJoined),
        _event('e2', action: LicenseOrgAuditAction.memberJoined),
        _event(
          'e3',
          action: LicenseOrgAuditAction.memberInvited,
          outcome: LicenseOrgAuditOutcome.rejected,
        ),
        _event('e4', action: LicenseOrgAuditAction.seatCodeMinted),
      ]);
      await tester.pumpWidget(_buildTestWidget(repo: repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Baseline: All actions => All (4), Success (3), Rejected (1).
      expect(find.text(_l10n.licenseOrgAuditActionFilterAll), findsOneWidget);
      expect(
        find.text(_l10n.licenseOrgAuditFilterAllWithCount(4)),
        findsOneWidget,
      );

      // Open the action picker by tapping the filter row.
      await tester.tap(find.text(_l10n.licenseOrgAuditActionFilterLabel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.text(_l10n.licenseOrgAuditActionFilterSheetTitle),
        findsOneWidget,
      );

      // Pick "Member joined". Picker rows have stable keys so the
      // tap doesn't collide with audit-list rows that also display
      // the same action label.
      await tester.tap(
        find.byKey(const Key('audit-action-picker-row-memberJoined')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // List should now contain 2 member-joined rows; chip counts:
      // All (2), Success (2), Rejected (0).
      expect(
        find.text(_l10n.licenseOrgAuditFilterAllWithCount(2)),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.licenseOrgAuditFilterSuccessWithCount(2)),
        findsOneWidget,
      );
      expect(
        find.text(_l10n.licenseOrgAuditFilterRejectedWithCount(0)),
        findsOneWidget,
      );
      // Filter row reflects the selection.
      expect(find.text(_l10n.licenseOrgAuditActionMemberJoined), findsWidgets);
    });
  });
}
