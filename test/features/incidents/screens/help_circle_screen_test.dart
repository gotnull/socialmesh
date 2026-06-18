// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PR-11A: Help Circle management screen - empty state, list rendering, and
// remove action (immediate, no confirm).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/incidents/providers/incident_help_trust_provider.dart';
import 'package:socialmesh/features/incidents/screens/help_circle_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _app() => const ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: HelpCircleScreen(),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty state when no peers are trusted', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('No trusted peers yet'), findsOneWidget);
    // The mutual-trust reality is surfaced, not hidden.
    expect(find.textContaining('both people add each other'), findsOneWidget);
  });

  testWidgets('lists a trusted peer and removes it', (tester) async {
    SharedPreferences.setMockInitialValues({
      kIncidentHelpCirclePrefsKey: jsonEncode([
        {'nodeId': 42, 'displayName': 'Bravo', 'addedAtMs': 1000},
      ]),
    });
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text('In your Help Circle'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from Help Circle'));
    await tester.pumpAndSettle();

    // Removal is destructive: a confirmation must appear first. The confirm
    // button uses the short "Remove" label (the title carries the context) so
    // it never wraps next to "Cancel".
    expect(find.text('Remove from Help Circle?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Peer gone, empty state shown.
    expect(find.text('Bravo'), findsNothing);
    expect(find.text('No trusted peers yet'), findsOneWidget);
  });
}
