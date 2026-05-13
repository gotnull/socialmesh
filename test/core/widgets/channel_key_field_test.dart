// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression coverage for the Create-Channel wizard bug where a
// manually-typed encryption key on step 3 was lost when the user
// tapped Continue without first tapping the inline check button.
//
// The fix lifts the TextEditingController into the parent so the
// parent can commit the controller text before navigation. These
// tests pin three properties of that contract:
//
//   1. External controller is the source of truth; parent rebuilds
//      passing the same keyBase64 must NOT overwrite a typed value.
//   2. Typing in Edit mode mutates the parent-owned controller live,
//      so a parent-side commit reads the latest text without the
//      user tapping the inline check first.
//   3. Generate button propagates a new key through the controller
//      AND through onKeyChanged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/channel_key_field.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/utils/encoding.dart';

Widget _host(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('ChannelKeyField with external controller', () {
    testWidgets(
      'parent rebuild with same keyBase64 prop does not overwrite typed text',
      (tester) async {
        final controller = TextEditingController(text: 'AAAA');
        addTearDown(controller.dispose);

        Widget build() => _host(
          ChannelKeyField(
            controller: controller,
            keyBase64: 'AAAA',
            onKeyChanged: (_) {},
            expectedKeyBytes: 16,
          ),
        );

        await tester.pumpWidget(build());

        // Enter edit mode and type a different value into the
        // parent-owned controller directly — simulates what happens
        // while the user is editing the field.
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        const typed = 'AQIDBAUGBwgJCgsMDQ4PEA==';
        controller.text = typed;
        await tester.pumpAndSettle();

        // Parent rebuilds — passing the SAME keyBase64 prop it started
        // with. The widget's didUpdateWidget must not clobber the
        // controller, because the controller is parent-owned.
        await tester.pumpWidget(build());

        expect(controller.text, typed);
      },
    );

    testWidgets(
      'typing in Edit mode mutates the parent-owned controller live',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(
            ChannelKeyField(
              controller: controller,
              keyBase64: '',
              onKeyChanged: (_) {},
              expectedKeyBytes: 16,
            ),
          ),
        );

        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();

        const typed = 'AQIDBAUGBwgJCgsMDQ4PEA==';
        await tester.enterText(find.byType(TextField), typed);
        await tester.pump();

        // Parent can read controller.text right now — without the
        // user tapping the inline check button. This is the wizard's
        // _commitEncryptionKeyFromController contract.
        expect(controller.text, typed);
      },
    );

    testWidgets('Generate updates the controller and notifies the parent', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      String? lastNotified;

      await tester.pumpWidget(
        _host(
          ChannelKeyField(
            controller: controller,
            keyBase64: '',
            onKeyChanged: (k) => lastNotified = k,
            expectedKeyBytes: 16,
          ),
        ),
      );

      await tester.tap(find.text('Generate'));
      await tester.pumpAndSettle();

      expect(controller.text, isNotEmpty);
      expect(lastNotified, controller.text);

      final decoded = ChannelKeyUtils.base64ToKey(controller.text);
      expect(decoded, isNotNull);
      expect(decoded!.length, 16);
    });

    testWidgets(
      'parent-owned controller seeded with a value displays the masked key',
      (tester) async {
        // 16-byte AES-128 key, canonical base64.
        const seed = 'AQIDBAUGBwgJCgsMDQ4PEA==';
        final controller = TextEditingController(text: seed);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(
            ChannelKeyField(
              controller: controller,
              keyBase64: seed,
              onKeyChanged: (_) {},
              expectedKeyBytes: 16,
            ),
          ),
        );

        // Masked dots rendered, not the raw key.
        expect(find.textContaining('•'), findsOneWidget);
        expect(find.text(seed), findsNothing);

        // Tap Show — key becomes visible.
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();
        expect(find.text(seed), findsOneWidget);
      },
    );
  });
}
