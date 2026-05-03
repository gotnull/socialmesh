// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_tools_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/app_providers.dart';

final _l10n = AppLocalizationsEn();

Widget _wrap({required LinkStatus linkStatus}) {
  return ProviderScope(
    overrides: [linkStatusProvider.overrideWithValue(linkStatus)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const MeshCoreToolsScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders disconnected state when not connected', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(linkStatus: LinkStatus.disconnected));
    await _settle(tester);

    expect(find.text(_l10n.meshcoreDisconnectedToolsTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'connected: renders canonical SettingsSectionHeader + SettingsTile sections',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          linkStatus: const LinkStatus(
            protocol: LinkProtocol.meshcore,
            status: LinkConnectionStatus.connected,
            deviceName: 'TestDevice',
          ),
        ),
      );
      await _settle(tester);

      // The screen now uses the canonical inner-settings primitives:
      // 3 section headers (Diagnostics / Discovery / Analysis) and at
      // least 5 action tiles. Pin the structural shape so a future
      // regression that re-introduces hand-rolled tool cards fails here.
      expect(find.byType(SettingsSectionHeader), findsNWidgets(3));
      expect(find.byType(SettingsTile), findsAtLeast(5));
      expect(find.text(_l10n.meshcoreDiagnostics), findsOneWidget);
      expect(find.text(_l10n.meshcoreDiscovery), findsOneWidget);
      expect(find.text(_l10n.meshcoreAnalysis), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
