// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_nodes_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';

Widget _wrap({LinkStatus? linkStatus}) {
  return ProviderScope(
    overrides: [
      linkStatusProvider.overrideWithValue(
        linkStatus ??
            const LinkStatus(
              protocol: LinkProtocol.meshcore,
              status: LinkConnectionStatus.connected,
              deviceName: 'TestDevice',
            ),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const MeshCoreNodesScreen(),
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

  testWidgets('renders the canonical AnimatedEmptyState when nodes are empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await _settle(tester);

    // The standalone Nodes tab renders the canonical AnimatedEmptyState
    // when the contact roster is empty. Pin that the canonical primitive
    // renders and that no exceptions surface.
    expect(find.byType(AnimatedEmptyState), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
