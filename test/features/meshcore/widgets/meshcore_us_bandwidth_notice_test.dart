// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The radio settings sheet shows the US sub-500 kHz notice only when the
// live params match a US preset narrower than 500 kHz.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_radio_settings_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

final _l10n = AppLocalizationsEn();

MeshCoreSelfInfo _selfInfo({
  required int freqKhz,
  required int bandwidthHz,
  required int spreadingFactor,
  int txPowerDbm = 20,
}) => MeshCoreSelfInfo(
  advType: 1,
  txPowerDbm: txPowerDbm,
  maxLoraTxPower: 22,
  pubKey: Uint8List.fromList(List.generate(32, (i) => 0x40 + (i % 16))),
  freqKhz: freqKhz,
  bandwidthHz: bandwidthHz,
  spreadingFactor: spreadingFactor,
  codingRate: 5,
  nodeName: 'UsNode',
  rawPayload: Uint8List(0),
);

Future<void> _openSheet(WidgetTester tester, MeshCoreSelfInfo info) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showMeshCoreRadioSettingsSheet(
                  context: ctx,
                  currentSelfInfo: info,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _closeSheet(WidgetTester tester) async {
  final navState = tester.state<NavigatorState>(find.byType(Navigator).last);
  while (navState.canPop()) {
    navState.pop();
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

final _noticeTitle = find.text(
  _l10n.meshcoreRadioSettingsUsBandwidthNoticeTitle,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows on the USA/Canada preset (62.5 kHz)', (tester) async {
    await _openSheet(
      tester,
      _selfInfo(freqKhz: 910525, bandwidthHz: 62500, spreadingFactor: 7),
    );
    expect(_noticeTitle, findsOneWidget);
    expect(
      find.text(_l10n.meshcoreRadioSettingsUsBandwidthNoticeBody),
      findsOneWidget,
    );
    await _closeSheet(tester);
  });

  testWidgets('hidden once the bandwidth is set to 500 kHz', (tester) async {
    await _openSheet(
      tester,
      _selfInfo(freqKhz: 910525, bandwidthHz: 62500, spreadingFactor: 7),
    );
    await tester.tap(find.text('500'));
    await tester.pump();
    expect(_noticeTitle, findsNothing);
    await _closeSheet(tester);
  });

  testWidgets('hidden on the Australia preset in the same band', (
    tester,
  ) async {
    await _openSheet(
      tester,
      _selfInfo(freqKhz: 915800, bandwidthHz: 250000, spreadingFactor: 10),
    );
    expect(_noticeTitle, findsNothing);
    await _closeSheet(tester);
  });

  testWidgets('hidden on a custom 915 MHz config', (tester) async {
    await _openSheet(
      tester,
      _selfInfo(freqKhz: 915000, bandwidthHz: 125000, spreadingFactor: 9),
    );
    expect(_noticeTitle, findsNothing);
    await _closeSheet(tester);
  });

  test('copy states the rule without categorical claims', () {
    final body = _l10n.meshcoreRadioSettingsUsBandwidthNoticeBody;
    expect(body, contains('Part 15.247'));
    expect(body, contains('500 kHz'));
    expect(
      RegExp(
        r'illegal|not legal|unlawful|all US|every US|must use 500',
        caseSensitive: false,
      ).hasMatch(body),
      isFalse,
    );
  });
}
