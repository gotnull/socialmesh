// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_map_screen.dart';
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
      home: const MeshCoreMapScreen(),
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

  // FlutterMap pulls in tile-loading and platform-channel deps that aren't
  // friendly under flutter_test. The screen has THREE branches, gated on
  // (isConnected, hasMapContent). The first two branches don't render
  // FlutterMap at all — they're pure widget trees — so they're cheap and
  // useful to pin. The third branch (the actual map) is exercised
  // end-to-end on a simulator, not here.

  testWidgets('renders disconnected state when not connected', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(linkStatus: LinkStatus.disconnected));
    await _settle(tester);

    expect(find.text(_l10n.meshcoreDisconnectedMapTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'renders empty-no-location state when connected but no contacts have location',
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

      // Default contacts state is empty → no contacts with location → the
      // empty-no-location branch fires (still no FlutterMap rendered).
      expect(find.text(_l10n.meshcoreNoContactsWithLocation), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
