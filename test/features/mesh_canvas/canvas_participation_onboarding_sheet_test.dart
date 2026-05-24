// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for the MeshCanvas first-run participation onboarding
// sheet.
//
// Spec: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.1 + §10 (test
// matrix - onboarding flow).
//
// Coverage:
//   - sheet renders the intro + three explainer rows + both CTAs;
//   - tapping "Explore locally" persists (true, false, false);
//   - tapping "Join MeshCanvas" persists (true, true, false);
//   - both CTAs dismiss the sheet.
//
// The sheet does NOT depend on canvas database / protocol services,
// so the harness only needs MaterialApp + localizations + a fresh
// SharedPreferences. No protocol stack mocking required.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/mesh_canvas/providers/mesh_canvas_participation_providers.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_participation_onboarding_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

class _OnboardingHostScreen extends StatelessWidget {
  const _OnboardingHostScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open-onboarding'),
            onPressed: () =>
                showCanvasParticipationOnboardingSheet(context: context),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required ProviderContainer container,
}) {
  return tester.pumpWidget(
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
        home: const _OnboardingHostScreen(),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders intro + three explainer rows + both CTAs', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Resolve the notifier so the sheet has a non-loading state.
    await container.read(meshCanvasParticipationProvider.future);

    await _pump(tester, container: container);
    await tester.tap(find.byKey(const ValueKey('open-onboarding')));
    await tester.pumpAndSettle();

    // Title pinned by AppBottomSheet.
    expect(find.text('MeshCanvas'), findsWidgets);
    // Intro line.
    expect(
      find.textContaining(
        'MeshCanvas is a shared pixel canvas',
        findRichText: true,
      ),
      findsOneWidget,
    );
    // Three explainer rows.
    expect(find.text('Local Device Canvas'), findsOneWidget);
    expect(find.text('Mesh canvases'), findsOneWidget);
    expect(find.text('Presence (optional)'), findsOneWidget);
    // Both CTAs are present.
    expect(
      find.byKey(const ValueKey('mesh-canvas-onboarding-explore')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('mesh-canvas-onboarding-join')),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping "Explore locally" persists (true, false, false) and dismisses',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(meshCanvasParticipationProvider.future);

      await _pump(tester, container: container);
      await tester.tap(find.byKey(const ValueKey('open-onboarding')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('mesh-canvas-onboarding-explore')),
      );
      await tester.pumpAndSettle();

      final settings = container
          .read(meshCanvasParticipationProvider)
          .asData!
          .value;
      expect(settings.onboardingSeen, isTrue);
      expect(settings.participationEnabled, isFalse);
      expect(settings.presenceSharingEnabled, isFalse);

      // Sheet dismissed — explore button no longer present.
      expect(
        find.byKey(const ValueKey('mesh-canvas-onboarding-explore')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'tapping "Join MeshCanvas" persists (true, true, false) and dismisses — '
    'sharing must stay off until explicit settings toggle',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(meshCanvasParticipationProvider.future);

      await _pump(tester, container: container);
      await tester.tap(find.byKey(const ValueKey('open-onboarding')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('mesh-canvas-onboarding-join')),
      );
      await tester.pumpAndSettle();

      final settings = container
          .read(meshCanvasParticipationProvider)
          .asData!
          .value;
      expect(settings.onboardingSeen, isTrue);
      expect(settings.participationEnabled, isTrue);
      expect(
        settings.presenceSharingEnabled,
        isFalse,
        reason:
            'Join MeshCanvas must NOT auto-enable presence sharing — that is '
            'a separate explicit toggle (spec §5.5)',
      );

      expect(
        find.byKey(const ValueKey('mesh-canvas-onboarding-join')),
        findsNothing,
      );
    },
  );
}
