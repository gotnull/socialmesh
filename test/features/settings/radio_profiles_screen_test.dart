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

// The connected radio shares [_radioA]'s data and its own leftover dataset
// was deleted, so it has no directory: the state a sharing radio is in once
// its stored entry is removed.
const _connectedSharing = RadioScopeInfo(
  key: 'node-4d39f3ef',
  label: 'MGrT_5949',
  sizeBytes: 0,
  isCurrent: false,
  isConnected: true,
  isStored: false,
  sharesWith: 'node-a6960864',
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

  testWidgets(
    'lists the connected radio under in use while it shares another dataset',
    (tester) async {
      await _pumpScreen(tester, [_radioA, _connectedSharing, _radioB]);

      expect(find.text('MGrT_5949'), findsOneWidget);
      expect(find.textContaining('Meshtastic 0864'), findsWidgets);
      // The connected radio is the one drawn as a radio; the dataset it
      // stores into is not, or the screen would claim another radio is
      // connected.
      expect(find.byIcon(Icons.router), findsOneWidget);
      // Both in-use rows are undeletable; only the third radio can go, and
      // the sharing radio's only action is to stop sharing.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.call_split), findsOneWidget);
    },
  );

  group('moving a radio\'s data to another radio', () {
    const otherWithData = RadioScopeInfo(
      key: 'node-0c0ffee0',
      label: 'Old Base',
      sizeBytes: 2097152,
      isCurrent: false,
    );

    testWidgets('the radio sharing an old radio can take its data', (
      tester,
    ) async {
      await _pumpScreen(tester, [_radioA, _connectedSharing]);

      // Only the old radio offers the move; the connected one never does.
      expect(find.byIcon(Icons.drive_file_move_outline), findsOneWidget);
      await tester.tap(find.byIcon(Icons.drive_file_move_outline));
      await tester.pumpAndSettle();
      expect(find.text('Move data to'), findsOneWidget);

      await tester.tap(find.text('MGrT_5949').last);
      await tester.pumpAndSettle();
      expect(find.text('Move radio data?'), findsOneWidget);
      expect(
        find.textContaining(
          'stored for Meshtastic 0864 will belong to MGrT_5949',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a radio with data of its own is offered, one sharing a '
        'third radio is not', (tester) async {
      const sharingThird = RadioScopeInfo(
        key: 'node-0000dddd',
        label: 'Shares B',
        sizeBytes: 4096,
        isCurrent: false,
        sharesWith: 'node-b0b0beef',
      );
      await _pumpScreen(tester, [
        _radioA,
        otherWithData,
        _radioB,
        sharingThird,
      ]);

      await tester.tap(find.byIcon(Icons.drive_file_move_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('Old Base'), findsNWidgets(2));
      expect(find.text('Fake Radio B'), findsNWidgets(2));
      expect(find.text('Shares B'), findsOneWidget);
    });

    testWidgets('says why when no radio can take the data', (tester) async {
      await _pumpScreen(tester, [_radioA, _unidentified]);

      await tester.tap(find.byIcon(Icons.drive_file_move_outline));
      await tester.pumpAndSettle();

      expect(find.text('Move data to'), findsNothing);
      expect(
        find.textContaining('Connect the new radio first'),
        findsOneWidget,
      );
    });

    testWidgets('labels data set aside by a move', (tester) async {
      const aside = RadioScopeInfo(
        key: 'aside-0000bbbb-1793750000000',
        label: 'MGrT_5949',
        sizeBytes: 184320,
        isCurrent: false,
      );
      await _pumpScreen(tester, [_radioA, aside]);

      expect(
        find.textContaining("Stored before another radio's data moved"),
        findsOneWidget,
      );
      // Kept or deleted, never shared or moved on.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.drive_file_move_outline), findsOneWidget);
    });
  });
}
