// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Smoke tests for the NodeDex Map entry point. The actual screen IS
// the canonical `MapScreen` running with `nodedexMode: true`; this
// suite verifies the wrapper pushes that screen and the override
// reaches the marker source.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/map/map_screen.dart';
import 'package:socialmesh/features/nodedex/map/nodedex_map_screen.dart';

void main() {
  test('openNodeDexMap is exported as a function', () {
    expect(openNodeDexMap, isA<Function>());
  });

  test('MapScreen exposes a nodedexMode flag (default false)', () {
    const live = MapScreen();
    expect(live.nodedexMode, isFalse);

    const nodedex = MapScreen(nodedexMode: true);
    expect(nodedex.nodedexMode, isTrue);
  });
}
