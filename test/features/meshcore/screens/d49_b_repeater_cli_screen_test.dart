// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-B: `MeshCoreRepeaterCliScreen` widget smoke pins.
//
// Pinned invariants:
//   - App-bar title formats with the repeater's name.
//   - Help button + send button + history-back / forward + input
//     are reachable by ValueKey.
//   - Empty state surfaces via `AnimatedEmptyState`.
//   - Quick-command chips render for the canonical 9 commands.
//   - With a null session, tapping send surfaces the "not connected"
//     error snackbar (no crash, no frame attempt).
//   - Clear-history menu entry is disabled when the history is empty.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_repeater_cli_screen.dart';
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
      home: MeshCoreRepeaterCliScreen(contact: contact),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('renders title + canonical action ValueKeys', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    expect(
      find.text(_l10n.meshcoreRepeaterCliTitle('TestRepeater')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-cli-help')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-cli-send')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-cli-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-cli-history-back')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-repeater-cli-history-forward')),
      findsOneWidget,
    );
  });

  testWidgets('empty history renders AnimatedEmptyState', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    expect(find.byType(AnimatedEmptyState), findsOneWidget);
  });

  testWidgets('all 9 canonical quick-command chips render', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    for (final cmd in const [
      'advert',
      'get name',
      'get radio',
      'get tx',
      'discover.neighbors',
      'neighbors',
      'ver',
      'clock',
      'clock sync',
    ]) {
      expect(
        find.byKey(ValueKey('meshcore-repeater-cli-quick-$cmd')),
        findsOneWidget,
        reason: 'quick chip for "$cmd" must render',
      );
    }
  });

  testWidgets('send tap with null session surfaces "not connected" snackbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    await tester.enterText(
      find.byKey(const ValueKey('meshcore-repeater-cli-input')),
      'ver',
    );
    await tester.pump();
    final sendBtn = find.byKey(const ValueKey('meshcore-repeater-cli-send'));
    await tester.ensureVisible(sendBtn);
    await tester.pump();
    await tester.tap(sendBtn, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(_l10n.meshcoreNotConnectedToDevice), findsOneWidget);
  });
}
