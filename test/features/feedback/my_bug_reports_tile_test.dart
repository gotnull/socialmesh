// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socialmesh/features/feedback/bug_report_repository.dart';
import 'package:socialmesh/features/feedback/my_bug_reports_tile.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/auth_providers.dart';

class _FakeUser extends Mock implements User {}

BugReport _report({required int unreadFounderReplies}) {
  final now = DateTime(2026, 9, 8);
  return BugReport(
    id: 'r1',
    description: 'cannot connect',
    createdAt: now,
    responses: [
      for (var i = 0; i < unreadFounderReplies; i++)
        BugReportResponse(
          id: 'f$i',
          from: 'founder',
          message: 'reply $i',
          createdAt: now,
        ),
      BugReportResponse(
        id: 'read',
        from: 'founder',
        message: 'already read',
        createdAt: now,
        readByUser: true,
      ),
      BugReportResponse(
        id: 'mine',
        from: 'user',
        message: 'thanks',
        createdAt: now,
      ),
    ],
  );
}

Widget _harness({
  required User? user,
  required List<BugReport> reports,
  required List<String> pushedRoutes,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(user),
      myBugReportsProvider.overrideWith((ref) => Stream.value(reports)),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) {
        pushedRoutes.add(settings.name ?? '');
        return MaterialPageRoute(builder: (_) => const SizedBox());
      },
      home: const Scaffold(body: MyBugReportsTile()),
    ),
  );
}

void main() {
  testWidgets('signed out: dimmed row that routes to /account', (tester) async {
    final pushed = <String>[];
    await tester.pumpWidget(
      _harness(user: null, reports: const [], pushedRoutes: pushed),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsTileMyBugReportsTitle), findsOneWidget);
    expect(find.text(l10n.settingsTileMyBugReportsNotSignedIn), findsOneWidget);
    expect(find.byType(Opacity), findsOneWidget);

    await tester.tap(find.text(l10n.settingsTileMyBugReportsTitle));
    await tester.pumpAndSettle();
    expect(pushed, ['/account']);
  });

  testWidgets('signed in with nothing unread: no badge, routes to reports', (
    tester,
  ) async {
    final pushed = <String>[];
    await tester.pumpWidget(
      _harness(
        user: _FakeUser(),
        reports: [_report(unreadFounderReplies: 0)],
        pushedRoutes: pushed,
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.settingsTileMyBugReportsSubtitle), findsOneWidget);
    expect(find.byType(Opacity), findsNothing);
    expect(find.text('0'), findsNothing);

    await tester.tap(find.text(l10n.settingsTileMyBugReportsTitle));
    await tester.pumpAndSettle();
    expect(pushed, ['/my-bug-reports']);
  });

  testWidgets('signed in: badge counts only unread founder replies', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        user: _FakeUser(),
        reports: [
          _report(unreadFounderReplies: 2),
          _report(unreadFounderReplies: 1),
        ],
        pushedRoutes: <String>[],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
  });
}
