// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The onboarding flow pushes RegionSelectionScreen(isInitialSetup: true)
// and awaits its pop. The onboarding coordinator has no region phase, so
// the picker itself must apply the region and pop; anything else strands
// the user on "Applying..." behind a screen that blocks back navigation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/device/region_selection_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/help_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

import '../onboarding/_onboarding_test_harness.dart';

class _RecordingRegionConfigNotifier extends RegionConfigNotifier {
  final List<RegionCode> applied = [];
  Object? failWith;

  @override
  RegionConfigState build() => const RegionConfigState();

  @override
  Future<void> applyRegion(
    RegionCode region, {
    String reason = 'user_action',
  }) async {
    applied.add(region);
    final error = failWith;
    if (error != null) throw error;
    state = state.copyWith(
      regionChoice: region,
      applyStatus: RegionApplyStatus.applied,
    );
  }
}

Future<({SettingsService settings, ValueNotifier<bool> popped})>
_pumpInitialSetupPicker(
  WidgetTester tester,
  _RecordingRegionConfigNotifier regionNotifier,
) async {
  final settings = SettingsService();
  await settings.init();
  final popped = ValueNotifier<bool>(false);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(
          FakeOnboardingProtocolService(initialRegion: RegionCode.UNSET),
        ),
        settingsServiceProvider.overrideWithValue(AsyncData(settings)),
        isLinkConnectedProvider.overrideWithValue(true),
        helpAnimationsEnabledProvider.overrideWithValue(false),
        regionConfigProvider.overrideWith(() => regionNotifier),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme(AccentColors.magenta),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const RegionSelectionScreen(isInitialSetup: true),
                ),
              );
              popped.value = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (settings: settings, popped: popped);
}

Future<void> _selectAndConfirm(WidgetTester tester, String regionName) async {
  await tester.tap(find.text(regionName));
  await tester.pump();
  await tester.tap(find.byKey(regionSelectionApplyButtonKey));
  await tester.pumpAndSettle();
  // The confirm sheet sits on top of the picker; its primary action is
  // the last "Continue" in the tree.
  await tester.tap(find.text('Continue').last);
  await tester.pumpAndSettle();
}

void main() {
  // The first-visit help tour would overlay the picker; skip it.
  setUp(
    () => SharedPreferences.setMockInitialValues({'help_skip_future': true}),
  );

  testWidgets('initial setup applies the chosen region and pops', (
    tester,
  ) async {
    final regionNotifier = _RecordingRegionConfigNotifier();
    final harness = await _pumpInitialSetupPicker(tester, regionNotifier);

    await _selectAndConfirm(tester, 'United States');

    expect(regionNotifier.applied, [RegionCode.US]);
    expect(harness.settings.regionConfigured, isTrue);
    expect(harness.popped.value, isTrue);
    expect(find.byType(RegionSelectionScreen), findsNothing);
  });

  testWidgets('initial setup apply failure unlocks the picker for a retry', (
    tester,
  ) async {
    final regionNotifier = _RecordingRegionConfigNotifier()
      ..failWith = StateError('write failed');
    final harness = await _pumpInitialSetupPicker(tester, regionNotifier);

    await _selectAndConfirm(tester, 'United States');

    expect(regionNotifier.applied, [RegionCode.US]);
    expect(harness.settings.regionConfigured, isFalse);
    expect(harness.popped.value, isFalse);
    final button = tester.widget<ElevatedButton>(
      find.byKey(regionSelectionApplyButtonKey),
    );
    expect(button.onPressed, isNotNull);

    // Let the snackbar and reboot countdown run out before teardown.
    await tester.pump(const Duration(minutes: 5));
  });
}
