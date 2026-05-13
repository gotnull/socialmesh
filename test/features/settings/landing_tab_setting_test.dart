// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/services/storage/storage_service.dart';

/// Sprint 5 — landing tab configuration (Section I).
///
/// Covers the SharedPreferences round-trip + source pins that:
/// - `MainShellIndexNotifier.build()` reads `defaultLandingTab` and
///   clamps to the valid `0..3` range.
/// - The settings UI renders the picker as a `ChipSelector<int>` in a
///   dedicated "Navigation" section, separated from the Large-mesh and
///   Notifications sections so it stays reachable regardless of other
///   gating.
void main() {
  group('SettingsService — defaultLandingTab', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to 2 (Nodes) for fresh installs', () async {
      final service = SettingsService();
      await service.init();
      expect(service.defaultLandingTab, 2);
    });

    test('persists across SettingsService instances', () async {
      final first = SettingsService();
      await first.init();
      await first.setDefaultLandingTab(3);

      final second = SettingsService();
      await second.init();
      expect(second.defaultLandingTab, 3);
    });

    test('round-trips every legal tab index', () async {
      for (final idx in const [0, 1, 2, 3]) {
        final service = SettingsService();
        await service.init();
        await service.setDefaultLandingTab(idx);

        final reload = SettingsService();
        await reload.init();
        expect(reload.defaultLandingTab, idx);
      }
    });
  });

  group('MainShellIndexNotifier wires the setting', () {
    final shellFile = File('lib/features/navigation/main_shell.dart');
    late String source;

    setUpAll(() {
      expect(shellFile.existsSync(), true);
      source = shellFile.readAsStringSync();
    });

    test('build() reads defaultLandingTab + clamps to 0..3', () {
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains('settings?.defaultLandingTab ?? _legacyDefault'),
        true,
        reason:
            'Provider must consult the new SettingsService getter and fall '
            'back to the legacy default (2 = Nodes) on bootstrap.',
      );
      expect(
        flat.contains('stored.clamp(0, 3);'),
        true,
        reason:
            'Stale persisted indices (e.g. from a hypothetical future build '
            'with more tabs) must clamp to the valid range, not crash the '
            'bottom nav.',
      );
    });

    test('legacy default constant is 2 (Nodes tab)', () {
      expect(
        source.contains('static const int _legacyDefault = 2; // Nodes tab'),
        true,
        reason:
            'The historical app behaviour is "start on Nodes" — fresh '
            'installs and upgraders without a stored value must see no '
            'change in landing tab.',
      );
    });
  });

  group('Settings screen wires the picker', () {
    final settingsFile = File('lib/features/settings/settings_screen.dart');
    late String source;

    setUpAll(() {
      expect(settingsFile.existsSync(), true);
      source = settingsFile.readAsStringSync();
    });

    test('picker lives in a dedicated "Navigation" section', () {
      expect(
        source.contains('settingsSectionNavigation'),
        true,
        reason:
            'Picker must live in its own Navigation section, not buried '
            'inside Large-mesh or Notifications.',
      );
      expect(source.contains('settingsTileLandingTabTitle'), true);
      expect(source.contains('settingsTileLandingTabSubtitle'), true);
    });

    test('uses ChipSelector<int> (canonical inner-settings primitive)', () {
      expect(
        source.contains('ChipSelector<int>'),
        true,
        reason:
            'Per CLAUDE.md canonical inner-settings pattern, single-select '
            'pickers use ChipSelector — never SegmentedButton.',
      );
      // All four tab values must be wired.
      for (final v in const ['value: 0', 'value: 1', 'value: 2', 'value: 3']) {
        expect(
          source.contains(v),
          true,
          reason: 'ChipOption for $v must be present in the picker.',
        );
      }
    });

    test('chip onChanged persists + logs + rebuilds', () {
      expect(source.contains('settingsService.setDefaultLandingTab('), true);
      expect(
        source.contains("'[Settings] defaultLandingTab="),
        true,
        reason:
            'Picker must emit an AppLogging.settings marker so the change '
            'is visible in the in-app log viewer.',
      );
    });
  });
}
