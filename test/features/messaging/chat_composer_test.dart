// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/widgets/chat_composer.dart';
import 'package:socialmesh/services/protocol/text_message_payload_budget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TextEditingController controller;
  late FocusNode focusNode;
  late bool sendCalled;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
    sendCalled = false;
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Widget buildSubject({
    VoidCallback? onSend,
    int maxLength = 500,
    ChatComposerBudgetResolver? budgetResolver,
    ChatComposerBudgetLabelBuilder? budgetLabelBuilder,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChatComposer(
          controller: controller,
          focusNode: focusNode,
          onSend: onSend ?? () => sendCalled = true,
          hintText: 'Message',
          maxLength: maxLength,
          sendTooltip: 'Send (Ctrl/Cmd+Enter)',
          budgetResolver: budgetResolver,
          budgetLabelBuilder: budgetLabelBuilder,
        ),
      ),
    );
  }

  group('ChatComposer', () {
    testWidgets('renders TextField and disabled Send button when empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(TextField), findsOneWidget);
      // Send button is always visible but disabled when empty.
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Send button is always visible, enabled when text entered', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      // Always visible — even with no text.
      expect(find.byIcon(Icons.send), findsOneWidget);

      // Type text — the ListenableBuilder should rebuild.
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Send button remains visible but disabled when text cleared', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      expect(find.byIcon(Icons.send), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      // Button stays visible but is disabled (faded).
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('Send button disabled for whitespace-only input', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();

      // Whitespace-only is treated as empty — button visible but disabled.
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('TextField is multiline with correct configuration', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.keyboardType, TextInputType.multiline);
      expect(textField.textInputAction, TextInputAction.newline);
      expect(textField.minLines, 1);
      expect(textField.maxLines, 6);
    });

    testWidgets('Enter key does NOT trigger send (inserts newline)', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      // Focus and type text.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      // Press plain Enter — should NOT send.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(sendCalled, isFalse);
    });

    testWidgets('Ctrl+Enter triggers send callback', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Focus and type text.
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      // Ctrl+Enter.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(sendCalled, isTrue);
    });

    testWidgets('Meta+Enter (Cmd on macOS) triggers send callback', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'world');
      await tester.pump();

      // Cmd+Enter.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(sendCalled, isTrue);
    });

    testWidgets('Tapping Send button invokes onSend callback', (tester) async {
      await tester.pumpWidget(buildSubject());

      // Enter text so the button appears.
      await tester.enterText(find.byType(TextField), 'message');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sendCalled, isTrue);
    });

    testWidgets(
      'Send callback can clear controller and button becomes disabled',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            onSend: () {
              sendCalled = true;
              controller.clear();
            },
          ),
        );

        await tester.enterText(find.byType(TextField), 'clear me');
        await tester.pump();
        expect(controller.text, 'clear me');
        expect(find.byIcon(Icons.send), findsOneWidget);

        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        expect(sendCalled, isTrue);
        expect(controller.text, isEmpty);
        // Button stays visible but is disabled after clearing.
        expect(find.byIcon(Icons.send), findsOneWidget);
      },
    );

    testWidgets('hint text is displayed when field is empty', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Message'), findsOneWidget);
    });

    testWidgets('send tooltip is shown on long-press of send button', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      // Make the button visible first.
      await tester.enterText(find.byType(TextField), 'tooltip test');
      await tester.pump();

      await tester.longPress(find.byIcon(Icons.send));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Send (Ctrl/Cmd+Enter)'), findsWidgets);
    });

    testWidgets('leading widget is rendered when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatComposer(
              controller: controller,
              focusNode: focusNode,
              onSend: () {},
              hintText: 'Message',
              leading: const Icon(Icons.bolt, key: Key('leading-icon')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('leading-icon')), findsOneWidget);
    });

    testWidgets('no leading widget means no bolt icon rendered', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.bolt), findsNothing);
    });

    testWidgets('maxLength is forwarded to the TextField', (tester) async {
      await tester.pumpWidget(buildSubject());

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLength, 500);
    });

    testWidgets('numpadEnter with Ctrl triggers send', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'numpad test');
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(sendCalled, isTrue);
    });

    testWidgets('numpadEnter without modifier does NOT send', (tester) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'numpad no mod');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.numpadEnter);
      await tester.pump();

      expect(sendCalled, isFalse);
    });

    testWidgets('shows a live byte counter for raw draft bytes', (
      tester,
    ) async {
      final sizer = TextMessagePayloadSizer.standard();

      await tester.pumpWidget(
        buildSubject(
          maxLength: sizer.maxUtf8Bytes,
          budgetResolver: sizer.measure,
          budgetLabelBuilder: (_, budget) =>
              '${budget.utf8Bytes}/${budget.maxUtf8Bytes} bytes',
        ),
      );

      expect(find.byKey(const Key('chat-composer-byte-counter')), findsNothing);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'hello ');
      await tester.pump();

      expect(find.text('6/228 bytes'), findsOneWidget);
    });

    testWidgets('send stays disabled when the draft exceeds the byte budget', (
      tester,
    ) async {
      final sizer = TextMessagePayloadSizer.standard();

      await tester.pumpWidget(
        buildSubject(
          maxLength: sizer.maxUtf8Bytes,
          budgetResolver: sizer.measure,
          budgetLabelBuilder: (_, budget) =>
              '${budget.utf8Bytes}/${budget.maxUtf8Bytes} bytes',
        ),
      );

      // Programmatic sets bypass input formatters, mirroring an existing
      // draft that lands over budget when the budget tightens (reply
      // context added, recipient PKI key learned).
      controller.text = '🙂' * 58;
      await tester.pump();

      expect(find.text('232/228 bytes'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(sendCalled, isFalse);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(sendCalled, isFalse);
    });

    testWidgets('typed input cannot exceed the byte budget', (tester) async {
      final sizer = TextMessagePayloadSizer.standard();

      await tester.pumpWidget(
        buildSubject(
          maxLength: sizer.maxUtf8Bytes,
          budgetResolver: sizer.measure,
          budgetLabelBuilder: (_, budget) =>
              '${budget.utf8Bytes}/${budget.maxUtf8Bytes} bytes',
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();

      final atLimit = 'a' * sizer.maxUtf8Bytes;
      await tester.enterText(find.byType(TextField), atLimit);
      await tester.pump();

      expect(controller.text, atLimit);

      // One more multi-byte character would cross the byte ceiling even
      // though the character count is still under maxLength.
      await tester.enterText(find.byType(TextField), '$atLimitä');
      await tester.pump();

      expect(controller.text, atLimit);

      // Deleting from an over-budget draft must still be possible.
      controller.text = '🙂' * 58;
      await tester.pump();
      final shrunk = '🙂' * 57;
      await tester.enterText(find.byType(TextField), shrunk);
      await tester.pump();

      expect(controller.text, shrunk);
    });

    testWidgets(
      'side buttons stay top aligned when the byte counter is visible',
      (tester) async {
        final sizer = TextMessagePayloadSizer.standard();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatComposer(
                controller: controller,
                focusNode: focusNode,
                onSend: () {},
                hintText: 'Message',
                maxLength: sizer.maxUtf8Bytes,
                budgetResolver: sizer.measure,
                budgetLabelBuilder: (_, budget) =>
                    '${budget.utf8Bytes}/${budget.maxUtf8Bytes} bytes',
                leading: Container(
                  key: const Key('leading-button'),
                  width: 40,
                  height: 40,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(TextField));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pump();

        expect(
          find.byKey(const Key('chat-composer-byte-counter')),
          findsOneWidget,
        );

        final textFieldRect = tester.getRect(find.byType(TextField));
        final leadingRect = tester.getRect(
          find.byKey(const Key('leading-button')),
        );
        final sendButtonRect = tester.getRect(
          find.ancestor(
            of: find.byIcon(Icons.send),
            matching: find.byType(AnimatedContainer),
          ),
        );

        expect(
          leadingRect.top,
          moreOrLessEquals(textFieldRect.top, epsilon: 0.1),
        );
        expect(
          sendButtonRect.top,
          moreOrLessEquals(textFieldRect.top, epsilon: 0.1),
        );
      },
    );
  });
}
