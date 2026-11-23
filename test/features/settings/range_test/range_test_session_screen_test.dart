// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/units/distance_format.dart';
import 'package:socialmesh/features/settings/range_test/range_test_models.dart';
import 'package:socialmesh/features/settings/range_test/range_test_providers.dart';
import 'package:socialmesh/features/settings/range_test/range_test_session_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/app_providers.dart';

final _l10n = AppLocalizationsEn();

class _FakeRangeTest extends RangeTestNotifier {
  _FakeRangeTest(this.initial);
  final RangeTestState initial;

  @override
  Future<RangeTestState> build() async => initial;
}

RangeTestReading _reading(int packetId, int seq, {double? snr, int? rssi}) =>
    RangeTestReading(
      sessionId: 1,
      receivedAt: DateTime(2026, 11, 24, 9, 0, packetId),
      senderNodeNum: 0x51,
      senderName: 'Home base',
      packetId: packetId,
      sequence: seq,
      payload: 'seq $seq',
      rxSnr: snr,
      rxRssi: rssi,
      viaMqtt: false,
      rxLatitude: null,
      rxLongitude: null,
      rxAltitude: null,
      rxPositionSource: null,
      senderLatitude: null,
      senderLongitude: null,
      distanceMeters: null,
    );

void main() {
  testWidgets('shows the summary, every packet and the gaps', (tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final readings = [
      _reading(1, 1, snr: -4, rssi: -100),
      _reading(2, 2, snr: -6, rssi: -104),
      _reading(3, 5),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rangeTestProvider.overrideWith(
            () => _FakeRangeTest(
              RangeTestState(
                sessions: [
                  RangeTestSession(
                    id: 1,
                    startedAt: DateTime(2026, 11, 24, 9),
                    endedAt: DateTime(2026, 11, 24, 9, 5),
                    readingCount: readings.length,
                  ),
                ],
              ),
            ),
          ),
          rangeTestReadingsProvider.overrideWith((ref, id) async => readings),
          measurementUnitsProvider.overrideWithValue(MeasurementUnits.metric),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData.dark(),
          home: const RangeTestSessionScreen(sessionId: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(_l10n.rangeTestReceivedValue(3, 5, 60)), findsOneWidget);
    expect(find.text('-5.0 dB'), findsOneWidget);
    expect(find.text('-102 dBm'), findsOneWidget);
    expect(find.text('5m'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#5'), findsOneWidget);
    expect(find.text('SNR -- dB · RSSI -- dBm'), findsOneWidget);
    expect(find.text(_l10n.rangeTestMissed(2)), findsOneWidget);
  });
}
