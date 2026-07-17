// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for the composer formatting toolbar: reveal-on-focus,
// selection wrapping/toggling, collapsed-cursor insertion, maxLength
// refusal, invalid-selection no-op, and the insert-link sheet flow.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/chat_composer.dart';
import 'package:socialmesh/core/widgets/chat_formatting_toolbar.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Widget buildSubject({
    bool enableFormattingToolbar = true,
    int maxLength = 200,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: ChatComposer(
          controller: controller,
          focusNode: focusNode,
          onSend: () {},
          hintText: 'Message',
          maxLength: maxLength,
          enableFormattingToolbar: enableFormattingToolbar,
        ),
      ),
    );
  }

  Future<void> focusComposer(WidgetTester tester) async {
    focusNode.requestFocus();
    await tester.pumpAndSettle();
  }

  void select(int start, int end) {
    controller.selection = TextSelection(baseOffset: start, extentOffset: end);
  }

  group('toolbar visibility', () {
    testWidgets('absent when the flag is off', (tester) async {
      await tester.pumpWidget(buildSubject(enableFormattingToolbar: false));
      await focusComposer(tester);
      expect(find.byIcon(Icons.format_bold), findsNothing);
    });

    testWidgets('hidden until the field has focus, then reveals', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      expect(find.byIcon(Icons.format_bold), findsNothing);

      await focusComposer(tester);
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
      expect(find.byIcon(Icons.format_strikethrough), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
    });
  });

  group('formatting actions', () {
    testWidgets('bold wraps the selection and keeps it selected', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'hello world');
      await focusComposer(tester);
      select(6, 11);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.format_bold));
      await tester.pump();

      expect(controller.text, 'hello **world**');
      expect(
        controller.text.substring(
          controller.selection.start,
          controller.selection.end,
        ),
        '**world**',
      );
    });

    testWidgets('bold toggles off an already-wrapped selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'hello **world**');
      await focusComposer(tester);
      select(8, 13); // inner "world"
      await tester.pump();

      await tester.tap(find.byIcon(Icons.format_bold));
      await tester.pump();

      expect(controller.text, 'hello world');
    });

    testWidgets('collapsed cursor inserts a delimiter pair around the cursor', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'hello ');
      await focusComposer(tester);
      select(6, 6);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.code));
      await tester.pump();

      expect(controller.text, 'hello ``');
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, 7);
    });

    testWidgets('mutation exceeding maxLength is refused', (tester) async {
      await tester.pumpWidget(buildSubject(maxLength: 12));
      await tester.enterText(find.byType(TextField), 'hello world');
      await focusComposer(tester);
      select(6, 11);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.format_bold));
      await tester.pump();

      // 'hello **world**' would be 15 > 12: refuse, leave text untouched.
      expect(controller.text, 'hello world');
    });

    testWidgets('invalid selection leaves the text untouched', (tester) async {
      // Drive the toolbar standalone: inside the composer a focused
      // TextField always normalizes the selection to a valid one, so the
      // defensive guard is only reachable without an attached field.
      controller.text = 'hello world';
      controller.selection = const TextSelection.collapsed(offset: -1);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ChatFormattingToolbar(
              controller: controller,
              focusNode: focusNode,
              maxLength: 200,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.format_bold), warnIfMissed: false);
      await tester.pump();

      expect(controller.text, 'hello world');
    });
  });

  group('link flow', () {
    testWidgets('link button opens the sheet and wraps the selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'hello world');
      await focusComposer(tester);
      select(6, 11);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.link));
      await tester.pumpAndSettle();

      // The sheet's URL field is the newest TextField on screen.
      await tester.enterText(
        find.byType(TextField).last,
        'https://example.com',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insert'));
      await tester.pumpAndSettle();

      expect(controller.text, 'hello [world](https://example.com)');
    });

    testWidgets('link button unwraps an already-linked selection', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      const linked = '[world](https://example.com)';
      await tester.enterText(find.byType(TextField), linked);
      await focusComposer(tester);
      select(0, linked.length);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.link));
      await tester.pumpAndSettle();

      expect(controller.text, 'world');
      expect(find.text('Insert'), findsNothing);
    });

    testWidgets('cancel leaves the text untouched', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.enterText(find.byType(TextField), 'hello world');
      await focusComposer(tester);
      select(6, 11);
      await tester.pump();

      await tester.tap(find.byIcon(Icons.link));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.text, 'hello world');
    });
  });
}
