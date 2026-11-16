// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodes/widgets/status_message_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  Future<List<String>> pumpSheet(
    WidgetTester tester, {
    String initial = '',
  }) async {
    final saved = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatusMessageSheet(initialStatus: initial, onSave: saved.add),
        ),
      ),
    );
    await tester.pump();
    return saved;
  }

  bool saveEnabled(WidgetTester tester) {
    final save = find.ancestor(
      of: find.text(l10n.commonSave),
      matching: find.byWidgetPredicate(
        (w) => w is ButtonStyleButton || w is InkWell,
      ),
    );
    final widget = tester.widget(save.first);
    return switch (widget) {
      ButtonStyleButton(:final onPressed) => onPressed != null,
      InkWell(:final onTap) => onTap != null,
      _ => false,
    };
  }

  testWidgets('prefills the current status and enables Save only on an edit', (
    tester,
  ) async {
    await pumpSheet(tester, initial: 'On air');
    expect(find.text(l10n.nodeDetailStatusMessageTitle), findsOneWidget);
    expect(find.text('On air'), findsOneWidget);
    expect(saveEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField), 'Back soon');
    await tester.pump();
    expect(saveEnabled(tester), isTrue);
  });

  testWidgets('saves the edited text, including an empty one', (tester) async {
    final saved = await pumpSheet(tester, initial: 'On air');
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text(l10n.commonSave));
    await tester.pump();
    expect(saved, ['']);
  });

  testWidgets('limits the status to 80 bytes of UTF-8', (tester) async {
    await pumpSheet(tester);
    // 30 three-byte characters would be 90 bytes.
    await tester.enterText(find.byType(TextField), '€' * 30);
    await tester.pump();
    final text = tester
        .widget<TextField>(find.byType(TextField))
        .controller!
        .text;
    expect(utf8.encode(text).length, lessThanOrEqualTo(kStatusMessageMaxBytes));
    expect(text, '€' * 26);
  });
}
