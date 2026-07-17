// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the body / fallback decision for Meshtastic chat bubbles.
//
//   - text == ""           → localized "(unable to display)"
//   - text == "   \t\n"    → same fallback (whitespace-only)
//   - text == "hello"      → LinkifiedText with the body content

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/widgets/message_bubble_body.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  final l10n = AppLocalizationsEn();

  testWidgets('renders localized fallback when text is empty', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MessageBubbleBody(
          text: '',
          bodyStyle: const TextStyle(fontSize: 14),
          fallbackStyle: const TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );

    expect(find.text(l10n.messagingMessageUnableToDisplay), findsOneWidget);
  });

  testWidgets('renders localized fallback when text is whitespace-only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MessageBubbleBody(
          text: '   \t\n  ',
          bodyStyle: const TextStyle(fontSize: 14),
          fallbackStyle: const TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );

    expect(find.text(l10n.messagingMessageUnableToDisplay), findsOneWidget);
  });

  testWidgets('renders the body text when non-empty', (tester) async {
    const body = 'hello mesh';
    await tester.pumpWidget(
      _wrap(
        MessageBubbleBody(
          text: body,
          bodyStyle: const TextStyle(fontSize: 14),
          fallbackStyle: const TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );

    expect(find.text(body), findsOneWidget);
    expect(find.text(l10n.messagingMessageUnableToDisplay), findsNothing);
  });

  testWidgets('renders inline markdown (bold span, no literal asterisks)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        MessageBubbleBody(
          text: 'hello **world**',
          bodyStyle: const TextStyle(fontSize: 14),
          fallbackStyle: const TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );

    final richFinder = find.byWidgetPredicate(
      (w) => w is Text && w.textSpan != null,
    );
    expect(richFinder, findsOneWidget);
    final root = tester.widget<Text>(richFinder).textSpan! as TextSpan;
    final bold = root.children!.cast<TextSpan>().firstWhere(
      (s) => s.text == 'world',
    );
    expect(bold.style?.fontWeight, FontWeight.w700);
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('renders emoji body unchanged', (tester) async {
    const body = '👋';
    await tester.pumpWidget(
      _wrap(
        MessageBubbleBody(
          text: body,
          bodyStyle: const TextStyle(fontSize: 14),
          fallbackStyle: const TextStyle(
            fontSize: 14,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );

    expect(find.text(body), findsOneWidget);
  });
}
