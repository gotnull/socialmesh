// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PR-10A: with the Incident Mode flags off (the default in tests -- dotenv is
// not loaded, so AppFeatureFlags.* return false), the Help Mode surfaces are
// inert: the map affordance and the global banner render nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/constants.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_request_affordance.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/incident_help_banner.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _wrap(Widget child) => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Stack(children: [child])),
  ),
);

void main() {
  test('both Incident Mode flags default off in tests', () {
    expect(AppFeatureFlags.isMeshIncidentsEnabled, isFalse);
    expect(AppFeatureFlags.isIncidentHelpRequestEnabled, isFalse);
  });

  testWidgets('map affordance hidden when flags are off (real gate)', (
    tester,
  ) async {
    // No enabledOverride -> uses the real AppFeatureFlags gate (off).
    await tester.pumpWidget(_wrap(const HelpRequestAffordance()));
    expect(find.text('Need help'), findsNothing);
  });

  testWidgets('global banner hidden when flags are off (real gate)', (
    tester,
  ) async {
    // activeHelpRequestsProvider returns const [] when the flags are off, so
    // the banner renders nothing.
    await tester.pumpWidget(_wrap(const IncidentHelpBanner()));
    await tester.pump();
    expect(find.text('Help request active'), findsNothing);
  });
}
