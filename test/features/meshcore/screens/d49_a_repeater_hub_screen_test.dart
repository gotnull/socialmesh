// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-A: `MeshCoreRepeaterHubScreen` widget pins.
//
// Pinned invariants:
//   - App-bar title formats with the repeater's name.
//   - Three tool tiles render: Status, CLI, Settings.
//   - The CLI + Settings tiles are wrapped in IgnorePointer (the
//     "Coming soon" placeholder state).
//   - The Status tile is reachable by ValueKey.

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

  testWidgets('CLI and Settings tiles are wrapped in IgnorePointer', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    for (final keyId in const [
      'meshcore-repeater-hub-cli',
      'meshcore-repeater-hub-settings',
    ]) {
      final tile = find.byKey(ValueKey(keyId));
      // At least one IgnorePointer ancestor must be active. Flutter
      // wraps other widgets in IgnorePointer internally so this is
      // a "some ignoring=true" assertion, not exact-count.
      final ignoring = tester
          .widgetList<IgnorePointer>(
            find.ancestor(of: tile, matching: find.byType(IgnorePointer)),
          )
          .where((w) => w.ignoring)
          .toList();
      expect(
        ignoring,
        isNotEmpty,
        reason:
            '$keyId should have at least one ignoring IgnorePointer ancestor '
            '(Coming soon state)',
      );
    }
  });

  testWidgets('Status tile is NOT wrapped in IgnorePointer (active)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    final tile = find.byKey(const ValueKey('meshcore-repeater-hub-status'));
    final ignore = find.ancestor(
      of: tile,
      matching: find.byType(IgnorePointer),
    );
    // Flutter may wrap other widgets in IgnorePointer internally, so
    // assert by behaviour: every IgnorePointer ancestor must be
    // inactive (ignoring == false).
    for (final w in tester.widgetList<IgnorePointer>(ignore)) {
      expect(w.ignoring, isFalse);
    }
  });
}
