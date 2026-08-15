// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The NodeDex shell owns the bottom bar that replaced the drawer's map
// link. Rendering it needs the whole NodeDex provider graph plus a map
// engine, so what is pinned here is the tab contract the shell and its
// callers share. The lazy-build behaviour (an unvisited tab is never
// constructed) and the switching itself are verified on device.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/screens/nodedex_shell_screen.dart';

void main() {
  group('NodeDexTab', () {
    test('bar order is Dex, Map, Groups', () {
      expect(NodeDexTab.values, [
        NodeDexTab.dex,
        NodeDexTab.map,
        NodeDexTab.groups,
      ]);
    });

    test('defaults to the Dex view', () {
      const shell = NodeDexShellScreen();
      expect(shell.initialTab, NodeDexTab.dex);
    });

    test('can be opened straight onto another view', () {
      const shell = NodeDexShellScreen(initialTab: NodeDexTab.map);
      expect(shell.initialTab, NodeDexTab.map);
    });
  });
}
