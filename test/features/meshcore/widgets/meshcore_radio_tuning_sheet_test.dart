// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_radio_tuning_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _NullTransport implements MeshCoreTransport {
  @override
  Stream<Uint8List> get rawRxStream => const Stream.empty();

  @override
  Future<void> sendRaw(Uint8List data) async {}

  @override
  bool get isConnected => true;
}

/// Session whose CLI answers like a RAK4631 on v1.18.0.
class _FakeSession extends MeshCoreSession {
  _FakeSession(this.replies) : super(_NullTransport());

  final Map<String, String?> replies;
  final List<String> sent = [];

  @override
  bool get isActive => true;

  @override
  Future<String?> runCliCommand(
    String command, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    sent.add(command);
    return replies.containsKey(command) ? replies[command] : 'OK';
  }
}

Map<String, String?> _radio() => {
  'get cad': '> off',
  'get int.thresh': '> 0',
  'get agc.reset.interval': '> 0',
  'get txdelay': '> 0.5',
  'get direct.txdelay': '> 0.1999999',
};

Future<void> _open(WidgetTester tester, _FakeSession session) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [meshCoreSessionProvider.overrideWithValue(session)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMeshCoreRadioTuningSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  testWidgets('shows the values read from the radio', (tester) async {
    final session = _FakeSession(_radio());
    await _open(tester, session);

    expect(session.sent, _radio().keys.toList());
    expect(find.text('Radio Tuning'), findsWidgets);
    expect(
      tester.widget<TextFormField>(_field('Direct packets')).controller!.text,
      '0.2',
    );
    expect(
      tester.widget<TextFormField>(_field('Flood packets')).controller!.text,
      '0.5',
    );
  });

  testWidgets('applies only what changed', (tester) async {
    final session = _FakeSession(_radio());
    await _open(tester, session);

    await tester.enterText(_field('Interference threshold (dB)'), '14');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(session.sent.skip(5), ['set int.thresh 14']);
    expect(find.text('Radio tuning applied'), findsOneWidget);
  });

  testWidgets('a rejected setting names it and keeps the sheet open', (
    tester,
  ) async {
    final session = _FakeSession({
      ..._radio(),
      'set txdelay 1.5': 'Error, must be 0-2',
    });
    await _open(tester, session);

    await tester.enterText(_field('Flood packets'), '1.5');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(
      find.text('Flood packets was not applied: Error, must be 0-2'),
      findsOneWidget,
    );
    expect(find.text('Apply'), findsOneWidget);
  });

  testWidgets('out-of-range input is caught before anything is sent', (
    tester,
  ) async {
    final session = _FakeSession(_radio());
    await _open(tester, session);

    await tester.enterText(_field('Gain reset interval (seconds)'), '10');
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Use a multiple of 4'), findsOneWidget);
    expect(session.sent.length, 5);
  });

  testWidgets('a failed read shows why and offers nothing to apply', (
    tester,
  ) async {
    final session = _FakeSession({..._radio(), 'get cad': null});
    await _open(tester, session);

    expect(find.byType(StatusBanner), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
}
