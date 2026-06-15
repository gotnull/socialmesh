// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for the remote fixed-position coordinate-entry sheet (PR-2).
//
// Coverage:
//   - a node with no reported position opens blank; manual lat/lon/alt
//     entry round-trips out through the returned FixedPositionInput;
//   - a node with a reported position pre-fills the fields;
//   - out-of-range coordinates are rejected (the sheet does not resolve).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodes/widgets/fixed_position_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

class _Host extends StatelessWidget {
  const _Host({
    required this.onResult,
    this.initialLatitude,
    this.initialLongitude,
    this.initialAltitude,
  });

  final void Function(FixedPositionInput?) onResult;
  final double? initialLatitude;
  final double? initialLongitude;
  final int? initialAltitude;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () async {
              final result = await FixedPositionSheet.show(
                context,
                nodeName: 'Tower 1',
                initialLatitude: initialLatitude,
                initialLongitude: initialLongitude,
                initialAltitude: initialAltitude,
              );
              onResult(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, Widget host) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: host,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'manual coordinate entry works for a node with no reported position',
    (tester) async {
      FixedPositionInput? result;
      var called = false;
      await _pump(
        tester,
        _Host(
          onResult: (r) {
            result = r;
            called = true;
          },
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();

      // Three coordinate fields, all blank (no reported position).
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(3));

      await tester.enterText(fields.at(0), '40.5');
      await tester.enterText(fields.at(1), '-74.25');
      await tester.enterText(fields.at(2), '150');

      await tester.tap(find.text('Set position'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(result, isNotNull);
      expect(result!.latitude, 40.5);
      expect(result!.longitude, -74.25);
      expect(result!.altitude, 150);
    },
  );

  testWidgets('reported position pre-fills the sheet', (tester) async {
    await _pump(
      tester,
      _Host(
        onResult: (_) {},
        initialLatitude: 37.7749,
        initialLongitude: -122.4194,
        initialAltitude: 12,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    // Fields pre-populated from the node's reported position.
    expect(find.text('37.774900'), findsOneWidget);
    expect(find.text('-122.419400'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('out-of-range coordinates are rejected (sheet stays open)', (
    tester,
  ) async {
    var called = false;
    await _pump(tester, _Host(onResult: (_) => called = true));

    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '200'); // latitude out of range
    await tester.enterText(fields.at(1), '10');
    await tester.tap(find.text('Set position'));
    await tester.pumpAndSettle();

    // Validation failed: the sheet did not resolve, so no result delivered.
    expect(called, isFalse);
    expect(find.text('Set position'), findsOneWidget);
  });
}
