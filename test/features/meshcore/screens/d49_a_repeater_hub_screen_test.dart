// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-A + D49-B: `MeshCoreRepeaterHubScreen` widget pins.
//
// Pinned invariants:
//   - App-bar title formats with the repeater's name.
//   - Three tool tiles render: Status, CLI, Settings.
//   - The Settings tile is wrapped in IgnorePointer (the "Coming
//     soon" placeholder state until D49-C).
//   - The Status tile (D49-A) is active.
//   - The CLI tile (D49-B) is active and pushes the CLI screen.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_repeater_hub_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

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
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: MeshCoreRepeaterHubScreen(contact: contact),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('hub renders the canonical title + three tool tiles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    expect(
      find.text(_l10n.meshcoreRepeaterAdminHubTitle('TestRepeater')),
      findsOneWidget,
    );
    expect(
      find.text(_l10n.meshcoreRepeaterAdminHubToolsHeader),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-hub-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-hub-cli')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-hub-settings')),
      findsOneWidget,
    );
  });

  testWidgets('Settings tile is wrapped in IgnorePointer (Coming soon)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    final tile = find.byKey(const ValueKey('meshcore-repeater-hub-settings'));
    final ignoring = tester
        .widgetList<IgnorePointer>(
          find.ancestor(of: tile, matching: find.byType(IgnorePointer)),
        )
        .where((w) => w.ignoring)
        .toList();
    expect(
      ignoring,
      isNotEmpty,
      reason: 'settings tile should still be IgnorePointer-wrapped until D49-C',
    );
  });

  testWidgets('Status and CLI tiles are active (no ignoring ancestor)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    for (final keyId in const [
      'meshcore-repeater-hub-status',
      'meshcore-repeater-hub-cli',
    ]) {
      final tile = find.byKey(ValueKey(keyId));
      final ignore = find.ancestor(
        of: tile,
        matching: find.byType(IgnorePointer),
      );
      for (final w in tester.widgetList<IgnorePointer>(ignore)) {
        expect(
          w.ignoring,
          isFalse,
          reason: '$keyId must not be under an ignoring IgnorePointer',
        );
      }
    }
  });
}
