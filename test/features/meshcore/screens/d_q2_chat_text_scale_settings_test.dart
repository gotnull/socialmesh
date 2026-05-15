// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q2: settings-tile + ChipSelector smoke pins for the per-app
// chat text-scale preference.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/chip_selector.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/meshcore_chat_text_scale_provider.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_chat_text_scale_store.dart';

final _l10n = AppLocalizationsEn();

/// A minimal harness that mirrors the chat-appearance section's
/// chip-selector wiring without pulling in the full MeshCoreSettings
/// screen (which depends on many providers we don't need for this
/// pin).
class _TextScaleHarness extends ConsumerWidget {
  const _TextScaleHarness();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scaleAsync = ref.watch(meshCoreChatTextScaleProvider);
    final scale = scaleAsync.value ?? kMeshCoreChatTextScaleDefault;
    final notifier = ref.read(meshCoreChatTextScaleProvider.notifier);
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ChipSelector<double>(
            key: const ValueKey('meshcore-chat-text-scale'),
            value: scale,
            onChanged: (v) => notifier.setScale(v),
            options: [
              for (final step in const [0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.8])
                ChipOption<double>(
                  value: step,
                  label: '${step}x',
                  icon: Icons.text_fields_rounded,
                  color: Colors.amber,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('chip selector renders all 7 steps', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: _TextScaleHarness()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    for (final step in const [0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.8]) {
      expect(find.text('${step}x'), findsOneWidget);
    }
  });

  testWidgets('tapping a chip updates the provider state + persists', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: _TextScaleHarness()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('meshcore-chat-text-scale'))),
    );
    expect(
      container.read(meshCoreChatTextScaleProvider).value,
      kMeshCoreChatTextScaleDefault,
    );

    await tester.tap(find.text('1.5x'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(container.read(meshCoreChatTextScaleProvider).value, 1.5);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('meshcore_chat_text_scale'), 1.5);
  });

  testWidgets('hydrates from a persisted out-of-range value (clamps)', (
    tester,
  ) async {
    // Forward-compat: if a future schema stored 4.0, the chip
    // selector should reflect the clamped 1.8 value.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'meshcore_chat_text_scale': 4.0,
    });
    await tester.pumpWidget(const ProviderScope(child: _TextScaleHarness()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('meshcore-chat-text-scale'))),
    );
    expect(
      container.read(meshCoreChatTextScaleProvider).value,
      kMeshCoreChatTextScaleMax,
    );
  });

  testWidgets('label text resolves from the en ARB key (sanity)', (
    tester,
  ) async {
    expect(_l10n.meshcoreChatAppearanceSectionTitle, 'Chat appearance');
    expect(_l10n.meshcoreChatTextScaleLabel, 'Chat text size');
  });
}
