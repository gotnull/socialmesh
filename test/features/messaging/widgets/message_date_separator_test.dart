// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the chat calendar-day separator: boundary detection is purely a
// local-calendar-day comparison, and the label degrades from Today /
// Yesterday through weekday names to a full date.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/widgets/message_date_separator.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('showsMessageDateSeparator', () {
    test('first row always gets a separator', () {
      expect(showsMessageDateSeparator(null, DateTime(2026, 8, 3, 9)), isTrue);
    });

    test('same local day is suppressed', () {
      expect(
        showsMessageDateSeparator(
          DateTime(2026, 8, 3, 0, 1),
          DateTime(2026, 8, 3, 23, 59),
        ),
        isFalse,
      );
    });

    test('crossing local midnight shows a separator', () {
      expect(
        showsMessageDateSeparator(
          DateTime(2026, 8, 2, 23, 59),
          DateTime(2026, 8, 3, 0, 1),
        ),
        isTrue,
      );
    });

    test('year and month boundaries show a separator', () {
      expect(
        showsMessageDateSeparator(
          DateTime(2026, 7, 31, 12),
          DateTime(2026, 8, 1, 12),
        ),
        isTrue,
      );
      expect(
        showsMessageDateSeparator(
          DateTime(2025, 12, 31, 12),
          DateTime(2026, 1, 1, 12),
        ),
        isTrue,
      );
    });
  });

  group('messageDateSeparatorLabel', () {
    Future<String> label(
      WidgetTester tester,
      DateTime timestamp,
      DateTime now,
    ) async {
      late String result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              result = messageDateSeparatorLabel(context, timestamp, now: now);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return result;
    }

    final now = DateTime(2026, 8, 3, 14, 30);

    testWidgets('same day reads Today', (tester) async {
      expect(await label(tester, DateTime(2026, 8, 3, 1), now), 'Today');
    });

    testWidgets('previous day reads Yesterday', (tester) async {
      expect(
        await label(tester, DateTime(2026, 8, 2, 23, 59), now),
        'Yesterday',
      );
    });

    testWidgets('inside the trailing week reads the weekday name', (
      tester,
    ) async {
      // 2026-07-30 is a Thursday, four days before the reference Monday.
      expect(await label(tester, DateTime(2026, 7, 30, 9), now), 'Thursday');
    });

    testWidgets('a week or more ago reads a full date', (tester) async {
      final text = await label(tester, DateTime(2026, 7, 27, 9), now);
      expect(text, contains('2026'));
      expect(text, contains('Jul'));
      expect(text, contains('27'));
    });
  });

  group('MessageDateSeparator widget', () {
    testWidgets('renders a single centred label chip', (tester) async {
      await tester.pumpWidget(
        _wrap(MessageDateSeparator(timestamp: DateTime(2020, 2, 14, 10))),
      );
      expect(find.text('Feb 14, 2020'), findsOneWidget);
    });
  });
}
