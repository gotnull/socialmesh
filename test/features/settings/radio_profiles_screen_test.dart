// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The Radio Data screen is the only surface that shows what each radio has
// stored, and the only way to delete it. These tests pin the two rules that
// make it safe: the radio in use is listed but cannot be deleted, and every
// other radio can.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/radio_scope.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/settings/radio_profiles_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/radio_scope_providers.dart';

const _radioA = RadioScopeInfo(
  key: 'node-a6960864',
  label: 'Meshtastic 0864',
  sizeBytes: 1441792,
  isCurrent: true,
);

const _radioB = RadioScopeInfo(
  key: 'node-b0b0beef',
  label: 'Fake Radio B',
  sizeBytes: 24576,
  isCurrent: false,
);

const _unidentified = RadioScopeInfo(
  key: 'dev-4f9dc5ee',
  label: null,
  sizeBytes: 4096,
  isCurrent: false,
);

/// [settle] must be false for the empty state: [AnimatedEmptyState] cycles
/// its icons and taglines forever, so `pumpAndSettle` never returns.
Future<void> _pumpScreen(
  WidgetTester tester,
  List<RadioScopeInfo> scopes, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [radioScopeListProvider.overrideWith((ref) async => scopes)],
      child: MaterialApp(
        theme: ThemeData.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RadioProfilesScreen(),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('lists the radio in use without a delete action', (tester) async {
    await _pumpScreen(tester, [_radioA]);

    expect(find.text('Meshtastic 0864'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('offers delete for every radio except the one in use', (
    tester,
  ) async {
    await _pumpScreen(tester, [_radioA, _radioB, _unidentified]);

    expect(find.text('Meshtastic 0864'), findsOneWidget);
    expect(find.text('Fake Radio B'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
  });

  testWidgets('shows a radio that never reported its identity', (tester) async {
    await _pumpScreen(tester, [_unidentified]);

    // No label and no node number: the row falls back to the generic name
    // rather than exposing the internal scope key.
    expect(find.text('dev-4f9dc5ee'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('renders the node id and size for an identified radio', (
    tester,
  ) async {
    await _pumpScreen(tester, [_radioB]);

    expect(find.textContaining('!b0b0beef'), findsOneWidget);
    expect(find.textContaining('24.0 KB'), findsOneWidget);
  });

  testWidgets('asks for confirmation before deleting', (tester) async {
    await _pumpScreen(tester, [_radioA, _radioB]);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // The sheet names the radio so a mis-tap is visible before it commits.
    expect(find.textContaining('Fake Radio B'), findsWidgets);
  });

  testWidgets('shows the empty state when nothing is stored', (tester) async {
    await _pumpScreen(tester, const [], settle: false);

    expect(find.byType(AnimatedEmptyState), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
