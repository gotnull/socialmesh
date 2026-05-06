// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D25 — `MeshCoreHamburgerMenuButton` route-aware behaviour.
//
// Pre-D25 the button always tried to open the shell drawer. On
// pushed routes (Settings, Device Info, …) the shell's `Scaffold`
// is below the navigator stack, so `openDrawer()` silently no-ops
// and a tap visibly does nothing. Splitting behaviour by route
// depth: hamburger + drawer at the root, back arrow + pop on
// pushed routes — fixes the dead-tap without touching any of the
// six callsites.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/navigation/meshcore_shell.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

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
        leading: const MeshCoreHamburgerMenuButton(),
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
        leading: const MeshCoreHamburgerMenuButton(),
        title: const Text('Pushed'),
      ),
      body: const Center(child: Text('pushed-body')),
    );
  }
}

Widget _wrap({required Widget child}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('on root route renders hamburger and opens shell drawer', (
    tester,
  ) async {
    final counter = _DrawerOpenCounter();

    await tester.pumpWidget(
      _wrap(child: _RootHostScaffold(openCounter: counter)),
    );
    await tester.pumpAndSettle();

    // Icon is the menu glyph (hamburger).
    final iconFinder = find.byIcon(Icons.menu);
    expect(iconFinder, findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);

    // Tap fires the drawer-open path.
    await tester.tap(iconFinder);
    await tester.pumpAndSettle();
    expect(counter.count, equals(1));
    expect(find.text('shell-drawer-content'), findsOneWidget);
  });

  testWidgets('on pushed route renders back arrow and pops the route', (
    tester,
  ) async {
    final counter = _DrawerOpenCounter();

    await tester.pumpWidget(
      _wrap(child: _RootHostScaffold(openCounter: counter)),
    );
    await tester.pumpAndSettle();

    // Push to the pushed route.
    await tester.tap(find.text('go-to-pushed'));
    await tester.pumpAndSettle();
    expect(find.text('pushed-body'), findsOneWidget);

    // Pushed leading is back arrow, NOT hamburger.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(
      find.byIcon(Icons.menu),
      findsNothing,
      reason: 'pushed-route leading must be a back arrow, not a hamburger',
    );

    // Tap pops back to root, drawer is NOT opened (counter
    // unchanged).
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('pushed-body'), findsNothing);
    expect(find.text('Root'), findsOneWidget);
    expect(
      counter.count,
      equals(0),
      reason: 'back-arrow tap must never open the drawer',
    );

    // Sanity: after popping, the root hamburger is back and still
    // opens the drawer.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(counter.count, equals(1));
  });

  testWidgets('tooltip text differs between root and pushed routes', (
    tester,
  ) async {
    final counter = _DrawerOpenCounter();

    await tester.pumpWidget(
      _wrap(child: _RootHostScaffold(openCounter: counter)),
    );
    await tester.pumpAndSettle();

    // Root: tooltip is the localized menu hint (we don't pin the
    // exact ARB string here so a future re-translation doesn't
    // brittle the test — just assert the icon-button has SOME
    // tooltip, and that it differs from the pushed-route one).
    final rootButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.menu),
        matching: find.byType(IconButton),
      ),
    );
    final rootTooltip = rootButton.tooltip;
    expect(rootTooltip, isNotNull);
    expect(rootTooltip, isNotEmpty);

    // Push and re-read.
    await tester.tap(find.text('go-to-pushed'));
    await tester.pumpAndSettle();
    final pushedButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.arrow_back),
        matching: find.byType(IconButton),
      ),
    );
    expect(pushedButton.tooltip, isNotNull);
    expect(pushedButton.tooltip, isNotEmpty);
    expect(
      pushedButton.tooltip,
      isNot(equals(rootTooltip)),
      reason: 'back-arrow tooltip should not be the menu tooltip',
    );
  });
}
