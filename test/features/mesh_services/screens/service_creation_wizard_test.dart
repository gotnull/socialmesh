// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/screens/service_creation_wizard.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/haptic_service.dart';

class _NoopHapticService extends HapticService {
  _NoopHapticService(super.ref);

  @override
  Future<void> trigger(HapticType type) async {}
}

void main() {
  Widget buildTestApp() {
    return ProviderScope(
      overrides: [
        hapticServiceProvider.overrideWith((ref) => _NoopHapticService(ref)),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ServiceCreationWizard(),
      ),
    );
  }

  testWidgets('wizard uses capability, preset, review flow only', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Intent'), findsOneWidget);
    expect(find.text('Template'), findsOneWidget);
    expect(find.text('Preview'), findsOneWidget);
    expect(find.text('Post an update'), findsOneWidget);
    expect(find.text('Who'), findsNothing);
    expect(find.text('Who can see it?'), findsNothing);
    expect(find.text('Approved contacts only'), findsNothing);
  });

  testWidgets('review step no longer shows audience summary', (tester) async {
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Post an update'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Before you write'), findsOneWidget);
    expect(find.text('You\'re sharing'), findsOneWidget);
    expect(find.text('Audience'), findsNothing);
  });
}
