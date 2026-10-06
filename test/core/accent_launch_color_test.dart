// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The saved accent is read before the first frame so the title screen
// renders in the user's accent rather than flashing the default.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';

void main() {
  setUp(() => AccentColorNotifier.launchColor = null);

  test('preload picks up the saved accent', () async {
    SharedPreferences.setMockInitialValues({
      'accent_color': AccentColors.green.toARGB32(),
    });

    await AccentColorNotifier.preloadLaunchColor();

    expect(AccentColorNotifier.launchColor, AccentColors.green);
  });

  test('preload leaves the launch colour unset when none is saved', () async {
    SharedPreferences.setMockInitialValues({});

    await AccentColorNotifier.preloadLaunchColor();

    expect(AccentColorNotifier.launchColor, isNull);
  });

  test('a saved accent survives a round trip through the notifier', () async {
    SharedPreferences.setMockInitialValues({});
    const chosen = Color(0xFF22C55E);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('accent_color', chosen.toARGB32());

    await AccentColorNotifier.preloadLaunchColor();

    expect(AccentColorNotifier.launchColor, chosen);
  });
}
