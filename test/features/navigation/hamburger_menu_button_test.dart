// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// `HamburgerMenuButton` route-aware behaviour for the Meshtastic shell.
//
// Screens such as Channels and Messages are normally hosted inside
// MainShell, whose Scaffold owns the drawer and the bottom bar. The same
// screens can also be pushed as standalone routes above the shell (a
// notification tap, a deep link). On a pushed route the shell's drawer is
// below the navigator stack, or not built at all while the shell is in
// set-up mode, so a hamburger tap has nothing to open and the screen has
// no bottom bar to leave through. The button therefore renders a back
// arrow that pops on pushed routes, and the hamburger only at the root.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/navigation/main_shell.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/mesh_explorer_providers.dart';
import 'package:socialmesh/providers/whats_new_providers.dart';

class _NoNewPeers extends NewMeshPeerCountNotifier {
  @override
  int build() => 0;
}

class _DrawerOpenCounter {
  int count = 0;
}

class _RootHostScaffold extends StatelessWidget {
  const _RootHostScaffold({required this.openCounter});

  final _DrawerOpenCounter openCounter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      onDrawerChanged: (isOpen) {
        if (isOpen) openCounter.count += 1;
      },
      drawer: const Drawer(child: Center(child: Text('shell-drawer-content'))),
      appBar: AppBar(
        leading: const HamburgerMenuButton(),
        title: const Text('Root'),
      ),
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () {
              Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const _PushedScreen()),
              );
            },
            child: const Text('go-to-pushed'),
          ),
        ),
      ),
    );
  }
}

class _PushedScreen extends StatelessWidget {
  const _PushedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const HamburgerMenuButton(),
        title: const Text('Pushed'),
      ),
      body: const Center(child: Text('pushed-body')),
    );
  }
}

Widget _wrap({required Widget child}) {
  return ProviderScope(
    overrides: [
      newMeshPeerCountProvider.overrideWith(_NoNewPeers.new),
      whatsNewHasUnseenProvider.overrideWithValue(false),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('on the root route renders the hamburger and opens the drawer', (
    tester,
  ) async {
    final counter = _DrawerOpenCounter();

    await tester.pumpWidget(
      _wrap(child: _RootHostScaffold(openCounter: counter)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(counter.count, equals(1));
    expect(find.text('shell-drawer-content'), findsOneWidget);
  });

  testWidgets('on a pushed route renders a back arrow that pops', (
    tester,
  ) async {
    final counter = _DrawerOpenCounter();

    await tester.pumpWidget(
      _wrap(child: _RootHostScaffold(openCounter: counter)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('go-to-pushed'));
    await tester.pumpAndSettle();
    expect(find.text('pushed-body'), findsOneWidget);

    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(
      find.byIcon(Icons.menu),
      findsNothing,
      reason: 'a screen pushed above the shell has no drawer to open',
    );

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('pushed-body'), findsNothing);
    expect(find.text('Root'), findsOneWidget);
    expect(
      counter.count,
      equals(0),
      reason: 'the back arrow must pop, never open the drawer',
    );

    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('back arrow tooltip differs from the menu tooltip', (
    tester,
  ) async {
    final counter = _DrawerOpenCounter();

    await tester.pumpWidget(
      _wrap(child: _RootHostScaffold(openCounter: counter)),
    );
    await tester.pumpAndSettle();

    final rootButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.menu),
        matching: find.byType(IconButton),
      ),
    );
    expect(rootButton.tooltip, isNotNull);
    expect(rootButton.tooltip, isNotEmpty);

    await tester.tap(find.text('go-to-pushed'));
    await tester.pumpAndSettle();
    final pushedButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_back),
        matching: find.byType(IconButton),
      ),
    );
    expect(pushedButton.tooltip, isNotNull);
    expect(pushedButton.tooltip, isNot(equals(rootButton.tooltip)));
  });
}
