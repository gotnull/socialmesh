// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_channels_screen.dart';
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
      home: const MeshCoreChannelsScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  // D-Q4: the channel sort-mode AsyncNotifier schedules a microtask
  // via SharedPreferences.getInstance(); a couple of extra pumps let
  // it resolve before the test tear-down so we don't trip the
  // pending-timer assertion.
  await tester.pump(const Duration(milliseconds: 50));
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

    expect(find.text(_l10n.meshcoreDisconnectedTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders the canonical AnimatedEmptyState when connected and channel list is empty',
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

      // The hand-rolled GradientBorderContainer empty state has been
      // replaced with the canonical AnimatedEmptyState. Pin the canonical
      // primitive renders, and that no exceptions surface.
      expect(find.byType(AnimatedEmptyState), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
