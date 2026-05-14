// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

// Confirms the localization keys the scanner capability gate depends on
// exist in `app_en.arb`. The scanner screen itself has a large provider
// dependency graph; the gate composes [GlassScaffold.body] + an
// [AnimatedEmptyState] using these l10n keys. If a key were removed the
// widget would not build - this test catches that regression cheaply
// without spinning up the full screen.
void main() {
  testWidgets('scanner unsupported keys resolve in English', (tester) async {
    late AppLocalizations l10n;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(l10n.scannerUnsupportedBleTitle.isNotEmpty, isTrue);
    expect(l10n.scannerUnsupportedBleDescription.isNotEmpty, isTrue);
    expect(l10n.scannerUnsupportedBleAction.isNotEmpty, isTrue);
    expect(l10n.scannerUnsupportedSerialTitle.isNotEmpty, isTrue);
    expect(l10n.scannerUnsupportedSerialDescription.isNotEmpty, isTrue);
    expect(l10n.scannerWebDashboardTitle.isNotEmpty, isTrue);
    expect(l10n.scannerWebDashboardDescription.isNotEmpty, isTrue);
  });

  testWidgets('AnimatedEmptyState renders the dashboard explainer', (
    tester,
  ) async {
    const description = 'A short explainer for the web dashboard';
    const title = 'Dashboard mode';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedEmptyState(
            config: AnimatedEmptyStateConfig(
              icons: const [Icons.cloud_outlined, Icons.devices_other_outlined],
              taglines: const [description],
              titlePrefix: '',
              titleKeyword: title,
              titleSuffix: '',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text(title), findsOneWidget);
  });
}
