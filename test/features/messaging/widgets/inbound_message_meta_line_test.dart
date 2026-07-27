// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the compact inbound metadata line: time · transport · hops · SNR.
//
//   - viaMqtt == false → "RF" token before the hop count
//   - viaMqtt == true  → "MQTT" token
//   - viaMqtt == null  → no transport token (historical rows must not be
//     mislabelled RF)
//   - hop text uses proper singular/plural per locale
//   - semantics announce "Message received via ..." instead of the raw
//     separator string

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/widgets/inbound_message_meta_line.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: locale,
    home: Scaffold(body: child),
  );
}

Message _inbound({bool? viaMqtt, int? hopCount, double? rxSnr}) => Message(
  id: 'm1',
  from: 0x1001,
  to: 0xFFFFFFFF,
  channel: 0,
  text: 'hello',
  received: true,
  timestamp: DateTime(2026, 7, 26, 23, 51),
  viaMqtt: viaMqtt,
  hopCount: hopCount,
  rxSnr: rxSnr,
);

String _metaText(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  expect(texts, hasLength(1));
  return texts.single;
}

void main() {
  testWidgets('RF metadata in Portuguese: RF · 4 saltos · SNR', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InboundMessageMetaLine(
          message: _inbound(viaMqtt: false, hopCount: 4, rxSnr: 9.0),
        ),
        locale: const Locale('pt'),
      ),
    );
    final text = _metaText(tester);
    expect(text, contains('RF · 4 saltos · SNR 9.0 dB'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('MQTT metadata in Portuguese uses singular hop', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InboundMessageMetaLine(message: _inbound(viaMqtt: true, hopCount: 1)),
        locale: const Locale('pt'),
      ),
    );
    final text = _metaText(tester);
    expect(text, contains('MQTT · 1 salto'));
    expect(text, isNot(contains('saltos')));
  });

  testWidgets('English RF metadata with plural hops', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InboundMessageMetaLine(
          message: _inbound(viaMqtt: false, hopCount: 4, rxSnr: 9.0),
        ),
      ),
    );
    expect(_metaText(tester), contains('RF · 4 hops · SNR 9.0 dB'));
  });

  testWidgets('English MQTT metadata with singular hop', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InboundMessageMetaLine(message: _inbound(viaMqtt: true, hopCount: 1)),
      ),
    );
    expect(_metaText(tester), contains('MQTT · 1 hop'));
  });

  testWidgets('unknown transport shows no transport token', (tester) async {
    await tester.pumpWidget(
      _wrap(
        InboundMessageMetaLine(
          message: _inbound(viaMqtt: null, hopCount: 4, rxSnr: 9.0),
        ),
        locale: const Locale('pt'),
      ),
    );
    final text = _metaText(tester);
    expect(text, isNot(contains('RF')));
    expect(text, isNot(contains('MQTT')));
    expect(text, contains('4 saltos'));
  });

  testWidgets('semantics announce the delivery path, not raw separators', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        InboundMessageMetaLine(message: _inbound(viaMqtt: false, hopCount: 4)),
        locale: const Locale('pt'),
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('Mensagem recebida por RF, 4 saltos.*')),
      findsOneWidget,
    );
  });

  testWidgets('English semantics: Message received via MQTT, 1 hop', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        InboundMessageMetaLine(message: _inbound(viaMqtt: true, hopCount: 1)),
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp('Message received via MQTT, 1 hop.*')),
      findsOneWidget,
    );
  });
}
