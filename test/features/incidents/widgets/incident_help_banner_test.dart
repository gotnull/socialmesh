// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/incidents/fixtures/incident_mode_fixtures.dart';
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/providers/mesh_incident_providers.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/incident_help_banner.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _app(List<IncidentProjection> active) {
  return ProviderScope(
    overrides: [activeHelpRequestsProvider.overrideWith((ref) async => active)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: Column(children: [IncidentHelpBanner()])),
    ),
  );
}

void main() {
  testWidgets('renders nothing when there are no active requests', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Help request active'), findsNothing);
  });

  testWidgets('shows banner and opens the responder inbox on tap', (
    tester,
  ) async {
    await tester.pumpWidget(_app([IncidentModeFixtures.activeWithResponder()]));
    await tester.pumpAndSettle();

    expect(find.text('Help request active'), findsOneWidget);
    expect(find.text('1 active help request'), findsOneWidget);

    await tester.tap(find.text('Help request active'));
    await tester.pumpAndSettle();

    // Responder inbox opened.
    expect(find.text('Help requests'), findsOneWidget);
  });
}
