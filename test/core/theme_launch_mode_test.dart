// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The saved theme mode is read before the first frame so a light theme
// user does not see the dark default on a cold start.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';

void main() {
  setUp(() => ThemeModeNotifier.launchMode = null);

  test('the first theme mode is the saved one', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.light.index,
    });

    await ThemeModeNotifier.preloadLaunchMode();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  test('without a saved mode the app starts dark', () async {
    SharedPreferences.setMockInitialValues({});

    await ThemeModeNotifier.preloadLaunchMode();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(themeModeProvider), ThemeMode.dark);
  });

  test('an out-of-range saved index is ignored', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 9});

    await ThemeModeNotifier.preloadLaunchMode();

    expect(ThemeModeNotifier.launchMode, isNull);
  });
}
