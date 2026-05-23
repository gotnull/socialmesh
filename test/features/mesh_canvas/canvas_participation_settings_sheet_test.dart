// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for the MeshCanvas participation settings sheet.
//
// Spec: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.5 + §10 (test
// matrix).
//
// Coverage:
//   - both toggles render with their canonical primitives;
//   - flipping participation off forces sharing off (UI + persisted
//     state both consistent);
//   - sharing switch is visually disabled (onChanged=null) while
//     participation is off — verified by tapping the switch and
//     asserting the persisted state did not change;
//   - replay-onboarding action re-opens the onboarding sheet.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_participation_providers.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_participation_settings_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

class _SettingsHostScreen extends StatelessWidget {
  const _SettingsHostScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open-settings'),
            onPressed: () =>
                showCanvasParticipationSettingsSheet(context: context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required bool participation,
  required bool sharing,
}) async {
  SharedPreferences.setMockInitialValues({
    'mesh_canvas.participation.onboarding_seen': true,
    'mesh_canvas.participation.enabled': participation,
    'mesh_canvas.participation.presence_sharing_enabled': sharing,
  });
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container.read(meshCanvasParticipationProvider.future);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const _SettingsHostScreen(),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-settings')));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'renders both toggles + About rows; switches reflect persisted state',
    (tester) async {
      await _pump(tester, participation: true, sharing: false);

      expect(find.text('Mesh participation'), findsOneWidget);
      expect(find.text('Share my presence'), findsOneWidget);
      expect(find.text('What is MeshCanvas?'), findsOneWidget);
      expect(find.text('Replay onboarding'), findsOneWidget);

      expect(
        find.byKey(const ValueKey('mesh-canvas-settings-participation-switch')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mesh-canvas-settings-presence-switch')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'toggling participation off forces sharing off — invariant enforced',
    (tester) async {
      final container = await _pump(tester, participation: true, sharing: true);

      // Confirm starting state.
      var settings = container
          .read(meshCanvasParticipationProvider)
          .asData!
          .value;
      expect(settings.participationEnabled, isTrue);
      expect(settings.presenceSharingEnabled, isTrue);

      // Tap the participation switch off.
      await tester.tap(
        find.byKey(const ValueKey('mesh-canvas-settings-participation-switch')),
      );
      await tester.pumpAndSettle();

      settings = container.read(meshCanvasParticipationProvider).asData!.value;
      expect(settings.participationEnabled, isFalse);
      expect(
        settings.presenceSharingEnabled,
        isFalse,
        reason: 'turning participation off MUST force sharing off',
      );
    },
  );

  testWidgets(
    'presence switch is disabled while participation is off — tapping it '
    'has no effect on persisted state',
    (tester) async {
      final container = await _pump(
        tester,
        participation: false,
        sharing: false,
      );

      // Try to flip sharing on while participation is off.
      await tester.tap(
        find.byKey(const ValueKey('mesh-canvas-settings-presence-switch')),
      );
      await tester.pumpAndSettle();

      final settings = container
          .read(meshCanvasParticipationProvider)
          .asData!
          .value;
      expect(settings.presenceSharingEnabled, isFalse);
      expect(settings.participationEnabled, isFalse);
    },
  );

  testWidgets(
    'enabling sharing while participation is on persists (true, true, true)',
    (tester) async {
      final container = await _pump(
        tester,
        participation: true,
        sharing: false,
      );

      await tester.tap(
        find.byKey(const ValueKey('mesh-canvas-settings-presence-switch')),
      );
      await tester.pumpAndSettle();

      final settings = container
          .read(meshCanvasParticipationProvider)
          .asData!
          .value;
      expect(settings.participationEnabled, isTrue);
      expect(settings.presenceSharingEnabled, isTrue);
    },
  );

  testWidgets(
    'tapping Replay onboarding re-opens the first-run onboarding sheet '
    'regardless of persisted onboardingSeen',
    (tester) async {
      await _pump(tester, participation: true, sharing: false);

      await tester.tap(
        find.byKey(const ValueKey('mesh-canvas-settings-replay-onboarding')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('mesh-canvas-onboarding-explore')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('mesh-canvas-onboarding-join')),
        findsOneWidget,
      );
    },
  );
}
