// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-A: `MeshCoreRepeaterStatusScreen` widget smoke pins.
//
// Pinned invariants:
//   - App-bar title formats with the repeater's name.
//   - Refresh button is rendered + reachable by ValueKey.
//   - When the session is null, the initial fetch surfaces the
//     "not connected" snackbar instead of a status fetch.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_repeater_status_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact() {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List<int>.generate(32, (i) => i)),
    name: 'TestRepeater',
    type: MeshCoreAdvType.repeater,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 14, 12),
  );
}

Widget _wrap({required MeshCoreContact contact}) {
  return ProviderScope(
    overrides: [meshCoreSessionProvider.overrideWithValue(null)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: MeshCoreRepeaterStatusScreen(contact: contact),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('renders the canonical title + refresh button', (tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    expect(
      find.text(_l10n.meshcoreRepeaterStatusTitle('TestRepeater')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-status-refresh')),
      findsOneWidget,
    );
  });

  testWidgets('null session surfaces the not-connected error snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);
    // Snackbar fires from initState's safePostFrame; let it render.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_l10n.meshcoreNotConnectedToDevice), findsOneWidget);
  });
}
