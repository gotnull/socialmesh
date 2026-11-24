// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_nodes_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

class _StubContactsNotifier extends MeshCoreContactsNotifier {
  _StubContactsNotifier(this._seed, {this.storageFull = false});
  final List<MeshCoreContact> _seed;
  final bool storageFull;
  @override
  MeshCoreContactsState build() => MeshCoreContactsState(
    contacts: List.unmodifiable(_seed),
    storageFull: storageFull,
  );
}

MeshCoreContact _contact(String name, int firstByte) => MeshCoreContact(
  publicKey: Uint8List.fromList(
    List.generate(32, (i) => (firstByte + i) & 0xFF),
  ),
  name: name,
  type: MeshCoreAdvType.chat,
  pathLength: 0,
  path: Uint8List(0),
  lastSeen: DateTime(2026, 11, 24, 15),
);

Widget _wrap({
  LinkStatus? linkStatus,
  List<MeshCoreContact>? contacts,
  bool storageFull = false,
}) {
  return ProviderScope(
    overrides: [
      if (contacts != null)
        meshCoreContactsProvider.overrideWith(
          () => _StubContactsNotifier(contacts, storageFull: storageFull),
        ),
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

  testWidgets('a search with no matches keeps the search field and clears '
      'from the empty state', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(contacts: [_contact('TerryDev2', 0x79), _contact('Brunswick', 1)]),
    );
    await _settle(tester);
    expect(find.text('TerryDev2'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await _settle(tester);
    expect(find.byType(AnimatedEmptyState), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MeshCoreNodesScreen)),
    );
    await tester.tap(find.text(l10n.meshcoreContactsFilteredEmptyAction));
    await _settle(tester);
    expect(find.text('TerryDev2'), findsOneWidget);
    expect(find.text('Brunswick'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Contact cards start delayed animations; unmount and let them lapse.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a full contact list shows the warning banner', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(contacts: [_contact('Coburg Hill', 0x30)], storageFull: true),
    );
    await _settle(tester);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(MeshCoreNodesScreen)),
    );
    expect(find.text(l10n.meshcoreContactsStorageFullTitle), findsOneWidget);
    expect(find.text(l10n.meshcoreContactsStorageFullBody), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
