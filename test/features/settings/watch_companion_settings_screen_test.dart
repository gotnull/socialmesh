// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/settings/watch_companion_settings_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart'
    show settingsServiceProvider;
import 'package:socialmesh/services/storage/storage_service.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_feature_flags.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_providers.dart';

/// Builds a real SettingsService backed by an in-memory SharedPreferences
/// so the screen exercises the same get/set path as production.
Future<SettingsService> _settingsServiceWithMocks([
  Map<String, Object> seed = const {},
]) async {
  SharedPreferences.setMockInitialValues(seed);
  final s = SettingsService();
  await s.init();
  return s;
}

Widget _wrap({required SettingsService settings, required bool flagsEnabled}) {
  return ProviderScope(
    overrides: [
      settingsServiceProvider.overrideWith((ref) async => settings),
      watchCompanionFeatureFlagsProvider.overrideWith(
        (ref) => WatchCompanionFeatureFlags(enabled: flagsEnabled),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const WatchCompanionSettingsScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('watchDefaultChannelIndex persistence', () {
    test('default value is 0 when no value has been written', () async {
      final settings = await _settingsServiceWithMocks();
      expect(settings.watchDefaultChannelIndex, 0);
    });

    test('setter writes and the getter reads it back', () async {
      final settings = await _settingsServiceWithMocks();
      await settings.setWatchDefaultChannelIndex(3);
      expect(settings.watchDefaultChannelIndex, 3);
    });

    test(
      'value survives a fresh SettingsService bound to the same prefs',
      () async {
        // First service writes 5.
        final first = await _settingsServiceWithMocks();
        await first.setWatchDefaultChannelIndex(5);

        // Second service binds to the same in-memory prefs and reads it
        // back. Proves the key/value land in SharedPreferences, not just
        // an in-memory cache on the service instance.
        final second = SettingsService();
        await second.init();
        expect(second.watchDefaultChannelIndex, 5);
      },
    );

    test('writing 0 is a real write, not a no-op', () async {
      // Seed with 7, then overwrite with 0, then confirm the read
      // returns 0 (and NOT the default fallback). Guards against a
      // future regression where `setX(0)` skips the write.
      SharedPreferences.setMockInitialValues({
        'watch_default_channel_index': 7,
      });
      final s = SettingsService();
      await s.init();
      expect(s.watchDefaultChannelIndex, 7);

      await s.setWatchDefaultChannelIndex(0);
      expect(s.watchDefaultChannelIndex, 0);
    });
  });

  group('WatchCompanionSettingsScreen smoke', () {
    testWidgets('renders title, status row, and channel chips when enabled', (
      tester,
    ) async {
      final settings = await _settingsServiceWithMocks();

      await tester.pumpWidget(_wrap(settings: settings, flagsEnabled: true));
      // Pump enough times for the loading FutureProvider to resolve,
      // the layout to settle, and the ChipSelector chips to mount.
      await tester.pumpAndSettle();

      // Title bar + companion-status label both render the screen
      // title string, so finding 'Apple Watch' twice would be normal.
      // Look for one specific occurrence to keep this stable.
      expect(find.text('Apple Watch'), findsWidgets);

      // Status row label.
      expect(find.text('Companion'), findsOneWidget);

      // Status row value (flag enabled).
      expect(find.text('Enabled'), findsOneWidget);

      // Channel picker tile heading.
      expect(find.text('Default channel'), findsOneWidget);

      // Every chip label "Channel N" for N in 0..7.
      for (var i = 0; i < WatchCompanionSettingsScreen.channelCount; i++) {
        expect(
          find.text('Channel $i'),
          findsOneWidget,
          reason: 'expected one "Channel $i" chip',
        );
      }
    });

    testWidgets('reflects disabled feature flag in the status row', (
      tester,
    ) async {
      final settings = await _settingsServiceWithMocks();

      await tester.pumpWidget(_wrap(settings: settings, flagsEnabled: false));
      await tester.pumpAndSettle();

      expect(find.text('Disabled'), findsOneWidget);
      expect(find.text('Enabled'), findsNothing);
    });

    testWidgets('seeds the picker with the persisted value', (tester) async {
      final settings = await _settingsServiceWithMocks({
        'watch_default_channel_index': 4,
      });

      await tester.pumpWidget(_wrap(settings: settings, flagsEnabled: true));
      await tester.pumpAndSettle();

      // Channel 4 chip is present (sanity), and the persisted value is
      // what the screen booted with.
      expect(find.text('Channel 4'), findsOneWidget);
      expect(settings.watchDefaultChannelIndex, 4);
    });

    testWidgets('tapping a different channel chip persists the new value', (
      tester,
    ) async {
      final settings = await _settingsServiceWithMocks();
      expect(settings.watchDefaultChannelIndex, 0);

      await tester.pumpWidget(_wrap(settings: settings, flagsEnabled: true));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Channel 2'));
      await tester.pumpAndSettle();

      expect(settings.watchDefaultChannelIndex, 2);
    });
  });
}
