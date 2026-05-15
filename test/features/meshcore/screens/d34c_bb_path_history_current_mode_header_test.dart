// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-Bb: path history sheet current-mode header pins.
//
// Pinned invariants:
//   - The header renders the localized current routing label
//     (auto N-hops, Flood, Direct, "<n> hops (forced)", etc.).
//   - The "Clear override" icon-button is hidden when
//     `pathOverride == null` (auto mode).
//   - The "Clear override" icon-button is visible when
//     `pathOverride != null` (Force Flood / Force Direct).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_path_history_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact({
  int firstByte = 0xAA,
  int pathLength = 5,
  int? pathOverride,
  String name = 'TestPeer',
}) {
  final pubKey = Uint8List(32);
  pubKey[0] = firstByte;
  return MeshCoreContact(
    publicKey: pubKey,
    name: name,
    type: MeshCoreAdvType.chat,
    pathLength: pathLength,
    path: Uint8List.fromList(List.generate(pathLength, (i) => i + 1)),
    lastSeen: DateTime(2026, 5, 15, 12),
    pathOverride: pathOverride,
    pathOverrideBytes: pathOverride != null ? Uint8List(0) : null,
  );
}

class _StubContactsNotifier extends MeshCoreContactsNotifier {
  _StubContactsNotifier(this._seed);
  final List<MeshCoreContact> _seed;
  @override
  MeshCoreContactsState build() =>
      MeshCoreContactsState(contacts: List.unmodifiable(_seed));
}

Widget _wrap({required MeshCoreContact target}) {
  return ProviderScope(
    overrides: [
      meshCoreContactsProvider.overrideWith(
        () => _StubContactsNotifier([target]),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const ValueKey('open'),
              onPressed: () =>
                  showMeshCorePathHistorySheet(ctx, contact: target),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders the localized current-path label (auto mode)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(pathLength: 5);
    await tester.pumpWidget(_wrap(target: target));
    await tester.pump();
    await _openSheet(tester);

    // Prefix label appears (separate text span -- the RichText renders
    // two spans; assert the prefix is on screen).
    expect(
      find.text(_l10n.meshcorePathHistoryCurrentModePrefix),
      findsOneWidget,
    );
    // Localized path label for an unforced 5-hop path.
    expect(find.text(_l10n.meshcorePathHops(5)), findsOneWidget);
  });

  testWidgets('Clear-override button is hidden when no override is active', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(pathLength: 5);
    await tester.pumpWidget(_wrap(target: target));
    await tester.pump();
    await _openSheet(tester);

    expect(
      find.byKey(const ValueKey('meshcore-path-history-clear-override')),
      findsNothing,
    );
  });

  testWidgets(
    'Clear-override button + Flood-forced label render when override is set',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final target = _contact(pathLength: 5, pathOverride: -1);
      await tester.pumpWidget(_wrap(target: target));
      await tester.pump();
      await _openSheet(tester);

      expect(find.text(_l10n.meshcorePathFloodForced), findsOneWidget);
      expect(
        find.byKey(const ValueKey('meshcore-path-history-clear-override')),
        findsOneWidget,
      );
    },
  );

  testWidgets('forced-direct override surfaces the Direct (forced) label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(pathLength: 5, pathOverride: 0);
    await tester.pumpWidget(_wrap(target: target));
    await tester.pump();
    await _openSheet(tester);

    expect(find.text(_l10n.meshcorePathDirectForced), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meshcore-path-history-clear-override')),
      findsOneWidget,
    );
  });

  testWidgets(
    'N-hop forced override surfaces the localized hops-forced label',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final target = _contact(pathLength: 5, pathOverride: 3);
      await tester.pumpWidget(_wrap(target: target));
      await tester.pump();
      await _openSheet(tester);

      expect(find.text(_l10n.meshcorePathHopsForced(3)), findsOneWidget);
      expect(
        find.byKey(const ValueKey('meshcore-path-history-clear-override')),
        findsOneWidget,
      );
    },
  );
}
