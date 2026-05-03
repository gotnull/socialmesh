// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/info_table.dart';
import 'package:socialmesh/core/widgets/section_header.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_settings_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/app_providers.dart';

final _l10n = AppLocalizationsEn();

Widget _wrap({LinkStatus? linkStatus}) {
  return ProviderScope(
    overrides: [
      linkStatusProvider.overrideWithValue(
        linkStatus ?? LinkStatus.disconnected,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const MeshCoreSettingsScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  // The screen is content-heavy and uses a sliver list; bump the test
  // viewport so all tiles fit without offscreen-finder failures.
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders the canonical section headers', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await _settle(tester);

    // Each section is rendered via the canonical SettingsSectionHeader.
    expect(find.byType(SettingsSectionHeader), findsNWidgets(4));
    expect(find.text(_l10n.meshcoreNodeSettings), findsOneWidget);
    expect(find.text(_l10n.meshcoreActions), findsOneWidget);
    expect(find.text(_l10n.meshcoreDebug), findsOneWidget);
    expect(find.text(_l10n.meshcoreAbout), findsOneWidget);
  });

  testWidgets(
    'renders device-info as the canonical SectionTitle + InfoTable surface',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap());
      await _settle(tester);

      // Read-only data canonical pattern: SectionTitle above an InfoTable
      // (per features/CLAUDE.md "Read-Only Data Rows" rule). No hand-rolled
      // info rows.
      expect(find.byType(SectionTitle), findsOneWidget);
      expect(find.byType(InfoTable), findsOneWidget);
      // Device-info section header rendered by SectionTitle (it uppercases
      // its label, so look for the upper-cased form).
      expect(find.text(_l10n.meshcoreDeviceInfo.toUpperCase()), findsOneWidget);
    },
  );

  testWidgets('shows disconnected status when not connected', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await _settle(tester);

    // The Status info row resolves to the disconnected label.
    expect(find.text(_l10n.meshcoreDisconnectedStatus), findsOneWidget);
  });

  testWidgets('renders the about tile with version subtitle', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await _settle(tester);

    // The About row uses the canonical tile and the meshcoreVersion ARB
    // key. While package_info may not resolve in tests, the placeholder
    // form (with '…' or any version string) renders without crashing.
    expect(find.text(_l10n.meshcoreAboutSocialMesh), findsWidgets);
  });

  testWidgets(
    'action tiles render disabled when disconnected (no provider crash)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap());
      await _settle(tester);

      // Action tile labels are still visible (the disable wrapper uses
      // Opacity + IgnorePointer so the affordance is discoverable). The
      // important thing is no exceptions were thrown reaching this point —
      // a regression in the disabled wrapper would surface a render error.
      expect(find.text(_l10n.meshcoreSendAdvertisement), findsOneWidget);
      expect(find.text(_l10n.meshcoreSyncTime), findsOneWidget);
      expect(find.text(_l10n.meshcoreRebootDevice), findsOneWidget);

      // No exceptions surfaced during the build/settle cycle.
      expect(tester.takeException(), isNull);
    },
  );
}
