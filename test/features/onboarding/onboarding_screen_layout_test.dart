// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Every onboarding page must fit, or scroll, on the smallest supported
// phone at each in-app text size (Default, Large, Extra Large). A page
// that renders past its bounds paints the overflow stripe instead of
// its copy.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/onboarding/onboarding_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final scale in const [1.0, 1.15, 1.3]) {
    testWidgets('onboarding pages fit an iPhone SE at text scale $scale', (
      tester,
    ) async {
      // iPhone SE (2nd and 3rd generation): 375 x 667 points.
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme(AccentColors.magenta),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: 'page 1');

      final pageView = find.byType(PageView);
      expect(pageView, findsOneWidget);
      final pageCount = tester
          .widget<PageView>(pageView)
          .childrenDelegate
          .estimatedChildCount;

      for (var page = 2; page <= (pageCount ?? 0); page++) {
        await tester.drag(pageView, const Offset(-400, 0));
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull, reason: 'page $page');
      }

      // Tear down so the typewriter and brain animation timers stop.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
