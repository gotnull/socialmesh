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
      'wrong-length key shows expected-vs-actual error and suppresses the valid-state badge',
      (tester) async {
        // Regression for the create-channel wizard bug: privacy level
        // expects 16 bytes (Private/AES-128) but the controller holds a
        // 1-byte "AQ==" key (the default-PSK marker). Continue gets
        // disabled with no explanation because the badge previously
        // misleadingly displayed "Default (Simple)" in a green-valid
        // styling. The fix surfaces a wrong-length error that names
        // both the expected and actual byte counts.
        final controller = TextEditingController(text: 'AQ==');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(
            ChannelKeyField(
              controller: controller,
              keyBase64: 'AQ==',
              onKeyChanged: (_) {},
              expectedKeyBytes: 16,
            ),
          ),
        );

        // The localized error names "16" (expected) and "1" (actual).
        expect(
          find.textContaining('16').hitTestable(),
          findsWidgets,
          reason: 'wrong-length error must reference the expected byte count',
        );
        expect(
          find.textContaining('1 entered'),
          findsOneWidget,
          reason: 'wrong-length error must reference the actual byte count',
        );

        // The valid-state badge (would say "Default (Simple)" for 1 byte
        // or "AES-128" for 16 bytes) must NOT render.
        expect(find.text('Default (Simple)'), findsNothing);
        expect(find.text('AES-128'), findsNothing);
      },
    );

    testWidgets('matching-length key shows the correct badge and no error', (
      tester,
    ) async {
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

      expect(find.text('AES-128'), findsOneWidget);
      expect(find.textContaining('1 entered'), findsNothing);
    });

    testWidgets('AES-256 expected with AES-128 key shows wrong-length error', (
      tester,
    ) async {
      // 16-byte key while expectedKeyBytes is 32 (Maximum/AES-256).
      const seed16 = 'AQIDBAUGBwgJCgsMDQ4PEA==';
      final controller = TextEditingController(text: seed16);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _host(
          ChannelKeyField(
            controller: controller,
            keyBase64: seed16,
            onKeyChanged: (_) {},
            expectedKeyBytes: 32,
          ),
        ),
      );

      expect(find.textContaining('32'), findsWidgets);
      expect(find.textContaining('16 entered'), findsOneWidget);
      expect(find.text('AES-128'), findsNothing);
      expect(find.text('AES-256'), findsNothing);
    });

    testWidgets(
      'external controller mutation re-validates against expected size',
      (tester) async {
        // Mirrors the wizard flow: user lands on Advanced with a wrong
        // size, then the wizard regenerates the key (via _generateKey)
        // and the field must update its badge/error to match the new
        // bytes without the user touching the field.
        final controller = TextEditingController(text: 'AQ==');
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _host(
            ChannelKeyField(
              controller: controller,
              keyBase64: 'AQ==',
              onKeyChanged: (_) {},
              expectedKeyBytes: 16,
            ),
          ),
        );

        expect(find.textContaining('1 entered'), findsOneWidget);

        // External write replaces the wrong-size key with a correct one.
        controller.text = 'AQIDBAUGBwgJCgsMDQ4PEA==';
        await tester.pumpAndSettle();

        expect(find.textContaining('1 entered'), findsNothing);
        expect(find.text('AES-128'), findsOneWidget);
      },
    );

    testWidgets(
      'Generate replaces a wrong-size key with a correct one and clears the error',
      (tester) async {
        final controller = TextEditingController(text: 'AQ==');
        addTearDown(controller.dispose);
        String? lastNotified;

        await tester.pumpWidget(
          _host(
            ChannelKeyField(
              controller: controller,
              keyBase64: 'AQ==',
              onKeyChanged: (k) => lastNotified = k,
              expectedKeyBytes: 16,
            ),
          ),
        );

        expect(find.textContaining('1 entered'), findsOneWidget);

        await tester.tap(find.text('Generate'));
        await tester.pumpAndSettle();

        final decoded = ChannelKeyUtils.base64ToKey(controller.text);
        expect(decoded, isNotNull);
        expect(decoded!.length, 16);
        expect(lastNotified, controller.text);
        expect(find.textContaining('1 entered'), findsNothing);
        expect(find.text('AES-128'), findsOneWidget);
      },
    );

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
