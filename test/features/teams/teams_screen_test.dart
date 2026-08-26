// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Teams screen rendering + the PR3 containment guarantee.
//
// The state matrix itself is covered by teams_list_state_test.dart as a
// pure function. These tests check that each state reaches the screen
// as the right surface, and - most importantly - that no Fleet
// enrolment, assignment, health or provisioning affordance exists
// anywhere in the tree even with every flag on.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/teams/application/teams_list_state.dart';
import 'package:socialmesh/features/teams/application/teams_providers.dart';
import 'package:socialmesh/features/teams/presentation/teams_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

late AppLocalizations _l10n;

Widget _app(TeamsListState state) {
  return ProviderScope(
    overrides: [teamsListStateProvider.overrideWithValue(state)],
    child: MaterialApp(
      theme: AppTheme.darkTheme(AccentColors.magenta),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TeamsScreen(),
    ),
  );
}

void main() {
  setUpAll(() async {
    _l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  group('states reach the screen as the right surface', () {
    testWidgets('disabled shows the flag notice', (tester) async {
      await tester.pumpWidget(_app(const TeamsDisabled()));
      await tester.pump();
      expect(find.text(_l10n.teamsDisabledBody), findsOneWidget);
    });

    testWidgets('account required explains why, without claiming emptiness', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TeamsAccountRequired()));
      await tester.pump();

      expect(find.text(_l10n.teamsAccountRequiredTitle), findsOneWidget);
      expect(find.text(_l10n.teamsAccountRequiredBody), findsOneWidget);
      expect(find.byType(AnimatedEmptyState), findsNothing);
    });

    testWidgets('checking shows progress, never an empty claim', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TeamsChecking()));
      await tester.pump();

      expect(find.text(_l10n.teamsCheckingLabel), findsOneWidget);
      expect(find.byType(AnimatedEmptyState), findsNothing);
      expect(find.text(_l10n.teamsEmptyTagline), findsNothing);
    });

    testWidgets('offline says why it cannot answer', (tester) async {
      await tester.pumpWidget(_app(const TeamsOfflineUnknown()));
      await tester.pump();

      expect(find.text(_l10n.teamsOfflineTitle), findsOneWidget);
      expect(find.text(_l10n.teamsOfflineBody), findsOneWidget);
      // Must not offer Retry: retrying while offline cannot help.
      expect(find.text(_l10n.teamsRetryAction), findsNothing);
      expect(find.byType(AnimatedEmptyState), findsNothing);
    });

    testWidgets('unavailable offers a retry rather than a dead end', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TeamsUnavailable()));
      await tester.pump();

      expect(find.text(_l10n.teamsUnavailableTitle), findsOneWidget);
      expect(find.text(_l10n.teamsUnavailableBody), findsOneWidget);
      expect(find.text(_l10n.teamsRetryAction), findsOneWidget);
      expect(
        find.byType(AnimatedEmptyState),
        findsNothing,
        reason: 'a failure is not an empty list',
      );
    });

    testWidgets('only the resolved-empty state uses the empty surface', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const TeamsEmpty()));
      await tester.pump();
      expect(find.byType(AnimatedEmptyState), findsOneWidget);
    });
  });

  group('long-string locales and small screens do not overflow', () {
    // Flutter throws a RenderFlex/overflow exception during layout, and
    // flutter_test surfaces that as a test failure - so pumping each
    // state at a constrained width IS the assertion. This is stronger
    // than eyeballing one screenshot per locale, and it re-runs on every
    // change.
    //
    // de/fr/uk are the locales with the longest Teams copy; 320x568 is
    // narrower and shorter than any iPhone this app supports, so passing
    // here means the real devices have headroom.
    const longLocales = [Locale('de'), Locale('fr'), Locale('uk')];

    const statesWithCopy = <TeamsListState>[
      TeamsDisabled(),
      TeamsAccountRequired(),
      TeamsChecking(),
      TeamsOfflineUnknown(),
      TeamsUnavailable(),
      TeamsEmpty(),
    ];

    for (final locale in longLocales) {
      for (final state in statesWithCopy) {
        testWidgets(
          '${locale.languageCode} / ${state.runtimeType} lays out cleanly',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);

            await tester.pumpWidget(
              ProviderScope(
                overrides: [teamsListStateProvider.overrideWithValue(state)],
                child: MaterialApp(
                  locale: locale,
                  theme: AppTheme.darkTheme(AccentColors.magenta),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: const TeamsScreen(),
                ),
              ),
            );
            await tester.pump();

            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('largest text scale does not overflow the busiest state', (
      tester,
    ) async {
      // The failed state is the busiest: icon + title + body + button.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teamsListStateProvider.overrideWithValue(const TeamsUnavailable()),
          ],
          child: MaterialApp(
            locale: const Locale('de'),
            theme: AppTheme.darkTheme(AccentColors.magenta),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: const TeamsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('no PR3 functionality leaks forward', () {
    // The Fleet backend already exists and is reachable from the app's
    // dependency graph, so this is a real risk rather than a
    // theoretical one. Every Teams state is swept.
    const forbidden = <String>[
      'Enrol',
      'Enroll',
      'Assign',
      'Retire',
      'Provision',
      'Health',
      'Fleet device',
      'Add radio',
    ];

    const allStates = <TeamsListState>[
      TeamsDisabled(),
      TeamsAccountRequired(),
      TeamsChecking(),
      TeamsOfflineUnknown(),
      TeamsUnavailable(),
      TeamsEmpty(),
    ];

    for (final state in allStates) {
      testWidgets('${state.runtimeType} exposes no fleet action', (
        tester,
      ) async {
        await tester.pumpWidget(_app(state));
        await tester.pump();

        for (final word in forbidden) {
          expect(
            find.textContaining(word, findRichText: true),
            findsNothing,
            reason:
                '"$word" must not be reachable until PR3 - the Fleet '
                'backend shipping in PR1 makes this leak plausible',
          );
        }
      });
    }

    testWidgets('no FloatingActionButton anywhere', (tester) async {
      // A FAB is the shape an "Add radio" affordance would most likely
      // take, and is banned by the repo conventions regardless.
      for (final state in allStates) {
        await tester.pumpWidget(_app(state));
        await tester.pump();
        expect(find.byType(FloatingActionButton), findsNothing);
      }
    });
  });
}
