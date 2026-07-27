// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the Quick Responses sheet layout:
//
//   - every reply is a distinct full-width tappable row
//   - no reply label is truncated with an ellipsis (long labels wrap)
//   - survives a 320 dp viewport and 2.0 text scale without overflow
//   - alert-bell action row and reply tiles expose button semantics

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/widgets/quick_responses_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/canned_response.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('pt')}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: child),
  );
}

List<CannedResponse> _ptResponses() => [
  CannedResponse(id: 'bell', text: '\u{1F514} Símbolo da campainha de alerta'),
  CannedResponse(id: 'yes', text: 'Sim'),
  CannedResponse(id: 'no', text: 'Não'),
];

void main() {
  Future<void> pumpSheet(
    WidgetTester tester, {
    List<CannedResponse>? responses,
    ValueChanged<String>? onSelect,
    VoidCallback? onSendAlertBell,
    Locale locale = const Locale('pt'),
  }) async {
    await tester.pumpWidget(
      _wrap(
        QuickResponsesSheet(
          responses: responses ?? _ptResponses(),
          onSelect: onSelect ?? (_) {},
          onSendAlertBell: onSendAlertBell ?? () {},
        ),
        locale: locale,
      ),
    );
  }

  testWidgets('long reply labels are never ellipsized', (tester) async {
    await pumpSheet(tester);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(
        text.overflow,
        isNot(TextOverflow.ellipsis),
        reason: 'reply "${text.data}" must wrap, not truncate',
      );
      expect(text.maxLines, isNull, reason: '"${text.data}" must wrap freely');
    }
    expect(
      find.text('\u{1F514} Símbolo da campainha de alerta'),
      findsOneWidget,
    );
  });

  testWidgets('Sim and Não are separate tappable controls', (tester) async {
    final selected = <String>[];
    await pumpSheet(tester, onSelect: selected.add);

    expect(find.widgetWithText(InkWell, 'Sim'), findsOneWidget);
    expect(find.widgetWithText(InkWell, 'Não'), findsOneWidget);

    await tester.tap(find.text('Sim'));
    await tester.pump();
    await tester.tap(find.text('Não'));
    await tester.pump();
    expect(selected, ['Sim', 'Não']);
  });

  testWidgets('alert-bell action fires its own callback, not a reply', (
    tester,
  ) async {
    var bellSent = false;
    final selected = <String>[];
    await pumpSheet(
      tester,
      onSelect: selected.add,
      onSendAlertBell: () => bellSent = true,
    );

    await tester.tap(find.text('Enviar campainha de alerta'));
    await tester.pump();
    expect(bellSent, isTrue);
    expect(selected, isEmpty);
  });

  testWidgets('no overflow at 320 dp width with 2.0 text scale in '
      'Portuguese', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await pumpSheet(tester);
    expect(tester.takeException(), isNull);
    // The sheet must stay scrollable when scaled content exceeds its
    // height budget: the first reply tile starts below the fold here.
    await tester.scrollUntilVisible(
      find.text('\u{1F514} Símbolo da campainha de alerta'),
      60,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.text('\u{1F514} Símbolo da campainha de alerta'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at 320 dp width with 1.5 text scale in '
      'English', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await pumpSheet(
      tester,
      locale: const Locale('en'),
      responses: [
        CannedResponse(id: 'bell', text: '\u{1F514} Alert bell character'),
        CannedResponse(id: 'yes', text: 'Yes'),
        CannedResponse(id: 'no', text: 'No'),
      ],
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Send alert bell', skipOffstage: false), findsOneWidget);
  });

  testWidgets('reply tiles and bell row expose button semantics', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(find.bySemanticsLabel('Resposta rápida: Sim'), findsOneWidget);
    expect(find.bySemanticsLabel('Resposta rápida: Não'), findsOneWidget);
    expect(find.bySemanticsLabel('Enviar campainha de alerta'), findsOneWidget);
  });

  testWidgets('empty list shows the configure hint', (tester) async {
    await pumpSheet(tester, responses: []);
    expect(tester.takeException(), isNull);
    expect(
      find.textContaining('Nenhuma resposta rápida configurada'),
      findsOneWidget,
    );
  });
}
