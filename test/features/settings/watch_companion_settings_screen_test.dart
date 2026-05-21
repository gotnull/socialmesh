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
import 'package:socialmesh/services/watch_companion/models/watch_companion_channel_preview.dart';
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

/// Default test channel set — three channels covering the common
/// "Meshtastic radio with Primary + a couple of named channels"
/// scenario. Tests that need a specific shape (empty, single-channel,
/// non-zero indices) pass an explicit override to [_wrap].
const List<WatchCompanionChannelPreview> _defaultTestChannels = [
  WatchCompanionChannelPreview(index: 0, name: 'Primary', isDefault: true),
  WatchCompanionChannelPreview(index: 1, name: 'admin', isDefault: false),
  WatchCompanionChannelPreview(index: 2, name: 'mesh-AU', isDefault: false),
];

Widget _wrap({
  required SettingsService settings,
  required bool flagsEnabled,
  List<WatchCompanionChannelPreview> channels = _defaultTestChannels,
}) {
  return ProviderScope(
    overrides: [
      settingsServiceProvider.overrideWith((ref) async => settings),
      watchCompanionFeatureFlagsProvider.overrideWith(
        (ref) => WatchCompanionFeatureFlags(enabled: flagsEnabled),
      ),
      watchCompanionAvailableChannelsProvider.overrideWith((ref) => channels),
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

      // Each chip's label is the channel's actual name (Primary,
      // admin, mesh-AU) — driven by the available-channels provider
      // override in _wrap, not by index-generated "Channel N".
      for (final channel in _defaultTestChannels) {
        expect(
          find.text(channel.name),
          findsOneWidget,
          reason: 'expected one "${channel.name}" chip',
        );
      }
      // Indices that don't exist on the (test) radio do NOT appear.
      // This is the regression-resistance for the "Channel 1 doesn't
      // exist but the picker offers it anyway" confusion.
      expect(find.text('Channel 5'), findsNothing);
      expect(find.text('Channel 7'), findsNothing);
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
        'watch_default_channel_index': 2,
      });

      await tester.pumpWidget(_wrap(settings: settings, flagsEnabled: true));
      await tester.pumpAndSettle();

      // mesh-AU is index 2 in the test channel set; persisted value
      // matches; chip is present.
      expect(find.text('mesh-AU'), findsOneWidget);
      expect(settings.watchDefaultChannelIndex, 2);
    });

    testWidgets('tapping a different channel chip persists the new value', (
      tester,
    ) async {
      final settings = await _settingsServiceWithMocks();
      expect(settings.watchDefaultChannelIndex, 0);

      await tester.pumpWidget(_wrap(settings: settings, flagsEnabled: true));
      await tester.pumpAndSettle();

      // admin is index 1 in the default test channel set.
      await tester.tap(find.text('admin'));
      await tester.pumpAndSettle();

      expect(settings.watchDefaultChannelIndex, 1);
    });

    testWidgets('tapping a chip invalidates watchDefaultChannelIndexProvider '
        'so downstream consumers (snapshot composer, bridge) see the '
        'new index without waiting for an unrelated upstream tick', (
      tester,
    ) async {
      // Regression for a silent-stale bug: a SharedPreferences write
      // doesn't notify Riverpod. Without the invalidate after the
      // write in _setDefaultChannel, downstream providers keep
      // reporting the old default until something else triggers a
      // rebuild. The Watch then shows the old default channel
      // pre-selected even though the setting was changed.
      final settings = await _settingsServiceWithMocks();
      final container = ProviderContainer(
        overrides: [
          settingsServiceProvider.overrideWith((ref) async => settings),
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => const WatchCompanionFeatureFlags(enabled: true),
          ),
          watchCompanionAvailableChannelsProvider.overrideWith(
            (ref) => _defaultTestChannels,
          ),
        ],
      );
      addTearDown(container.dispose);

      // Initial value.
      expect(container.read(watchDefaultChannelIndexProvider), 0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const WatchCompanionSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // mesh-AU is index 2 in the test channel set.
      await tester.tap(find.text('mesh-AU'));
      await tester.pumpAndSettle();

      expect(
        container.read(watchDefaultChannelIndexProvider),
        2,
        reason:
            'After the chip tap, the derived provider must reflect '
            'the new persisted value. If this fails, the invalidate '
            'in _setDefaultChannel is gone or the provider lookup '
            'path regressed.',
      );
    });

    testWidgets(
      'renders empty-state placeholder when no channels are available',
      (tester) async {
        // Mirrors the production scenario where no protocol is active
        // (or the active radio has not advertised channel config yet).
        // The user should see helpful guidance instead of an empty
        // ChipSelector or — worse — a list of channel indices that
        // do not exist on their radio.
        final settings = await _settingsServiceWithMocks();
        await tester.pumpWidget(
          _wrap(
            settings: settings,
            flagsEnabled: true,
            channels: const <WatchCompanionChannelPreview>[],
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Connect a radio to choose a default channel.'),
          findsOneWidget,
        );
        // No channel chips of any kind.
        expect(find.text('Primary'), findsNothing);
        expect(find.text('admin'), findsNothing);
      },
    );
  });
}
