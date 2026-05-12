// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D44 - MeshCore Tools "App Debug Log" tile.
//
// The viewer itself (`AppLogScreen`) and its ring buffer
// (`AppLogger`) were already shipped in `lib/features/debug/`. D44
// adds a single Tools tile that surfaces the existing screen from
// the MeshCore flow.
//
// Pinned invariants:
//   - The tile renders with the canonical title + subtitle when the
//     Tools screen is in its connected state.
//   - Tapping the tile pushes `AppLogScreen` onto the navigator.
//   - The existing Frame Log tile remains reachable (D28 regression).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/debug/app_log_screen.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_tools_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_message_providers.dart';

final _l10n = AppLocalizationsEn();

/// Inert conversations notifier (mirrors the D22 / Tools-screen test
/// scaffold) so the test binding doesn't trip on the live notifier's
/// `Timer.periodic` heartbeat.
class _InertConversations extends MeshCoreConversationsNotifier {
  @override
  MeshCoreConversationsState build() =>
      const MeshCoreConversationsState.initial();
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      linkStatusProvider.overrideWithValue(
        const LinkStatus(
          protocol: LinkProtocol.meshcore,
          status: LinkConnectionStatus.connected,
          deviceName: 'TestDevice',
        ),
      ),
      meshCoreConversationsProvider.overrideWith(_InertConversations.new),
    ],
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
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'App Debug Log tile renders with canonical D44 title + subtitle',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap());
      await _settle(tester);

      expect(find.text(_l10n.meshcoreAppDebugLogTool), findsOneWidget);
      expect(find.text(_l10n.meshcoreAppDebugLogToolSubtitle), findsOneWidget);
      // D28 Frame Log tile must still surface (no regression on the
      // adjacent debug-tools row).
      expect(find.text(_l10n.meshcoreFrameLogTool), findsOneWidget);
    },
  );

  testWidgets('tapping App Debug Log pushes the shared AppLogScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await _settle(tester);

    // AppLogScreen should not be on the route stack yet.
    expect(find.byType(AppLogScreen), findsNothing);

    await tester.tap(find.text(_l10n.meshcoreAppDebugLogTool));
    await _settle(tester);
    await _settle(tester);

    // AppLogScreen now in the tree.
    expect(find.byType(AppLogScreen), findsOneWidget);
  });
}
