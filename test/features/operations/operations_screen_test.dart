// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget rendering tests for OperationsScreen.
//
// Scope is intentionally narrow: this verifies the screen renders the
// disabled-flag branch correctly. Data-path coverage (active list,
// completed list, dedupe, persistence, navigation contract) lives in
// `operations_notifier_test.dart` because sqflite + AsyncNotifier loads
// don't compose cleanly with flutter_test's `pump` event loop, and the
// notifier-level tests already exercise every state transition with
// stronger assertions than a widget test could provide.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/features/operations/application/operations_providers.dart';
import 'package:socialmesh/features/operations/data/operations_database.dart';
import 'package:socialmesh/features/operations/presentation/operations_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _appFromContainer(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AppTheme.darkTheme(AccentColors.magenta),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets(
    'OperationsScreen renders the disabled banner when the feature flag '
    'is off and never shows the active/completed list sections',
    (tester) async {
      final database = OperationsDatabase(testDbPath: inMemoryDatabasePath);
      addTearDown(database.close);

      final container = ProviderContainer(
        overrides: [
          operationsEnabledProvider.overrideWithValue(false),
          operationsDatabaseProvider.overrideWithValue(database),
          operationsTracerouteEventProvider.overrideWith(
            (ref) => const Stream.empty(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _appFromContainer(container, const OperationsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Disabled body copy from app_en.arb.
      expect(
        find.text('Operations are not enabled in this build.'),
        findsOneWidget,
      );
      // Section headers from the data path are not rendered.
      expect(find.text('ACTIVE'), findsNothing);
      expect(find.text('COMPLETED'), findsNothing);
      // No catalog content surfaces, even though catalog operations
      // exist in the static catalog list.
      expect(find.text('First Contact'), findsNothing);
      expect(find.text('Signal Hunter'), findsNothing);
      expect(find.text('Pathfinder'), findsNothing);

      // Sanity-check the underlying state: the notifier returned
      // OperationsState.disabled() so neither catalog nor progress
      // surfaces leaked through the gate.
      final state = container.read(operationsProvider).requireValue;
      expect(state.enabled, isFalse);
      expect(state.catalog, isEmpty);
      expect(state.progress, isEmpty);
    },
  );
}
