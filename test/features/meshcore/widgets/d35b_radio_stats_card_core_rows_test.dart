// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-B-A: `MeshCoreRadioStatsCard` CORE-row extension regression pins.
//
// Pinned invariants (this file):
//   - When CORE data has landed alongside RADIO data, the card
//     renders Uptime + Firmware TX queue rows.
//   - Error-flags row is hidden when the value is exactly 0.
//   - Error-flags row appears as 0xNNNN (4-character zero-padded
//     uppercase hex) when the value is non-zero.
//   - The error-flags helper note appears only when the row appears.
//   - The card NEVER renders a battery row from the CORE response
//     (battery is owned by `meshCoreBatteryProvider`).
//   - The reset note copy mentions both airtime AND uptime.
//   - Banned-pattern sweep on every rendered Text widget:
//     no [mrrp], no MMF, no 64-char hex, no base64 envelope.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_radio_stats_card.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

class _StubRadioNotifier extends MeshCoreRadioStatsNotifier {
  _StubRadioNotifier(this._initial);
  final MeshCoreRadioStatsSnapshot _initial;
  @override
  MeshCoreRadioStatsSnapshot build() => _initial;
}

class _StubCoreNotifier extends MeshCoreCoreStatsNotifier {
  _StubCoreNotifier(this._initial);
  final MeshCoreCoreStatsSnapshot _initial;
  @override
  MeshCoreCoreStatsSnapshot build() => _initial;
}

Widget _wrap({
  required MeshCoreRadioStatsSnapshot radio,
  required MeshCoreCoreStatsSnapshot core,
}) {
  return ProviderScope(
    overrides: [
      meshCoreRadioStatsProvider.overrideWith(() => _StubRadioNotifier(radio)),
      meshCoreCoreStatsProvider.overrideWith(() => _StubCoreNotifier(core)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MeshCoreRadioStatsCard()),
    ),
  );
}

MeshCoreRadioStats _radio() {
  return MeshCoreRadioStats(
    noiseFloorDbm: -110,
    lastRssiDbm: -83,
    lastSnrQuarter: 30,
    txAirtime: const Duration(seconds: 42),
    rxAirtime: const Duration(hours: 1, minutes: 18),
    fetchedAt: DateTime(2026, 5, 11, 12),
  );
}

MeshCoreCoreStats _core({
  int batteryMv = 4012,
  Duration uptime = const Duration(hours: 4, minutes: 12),
  int errorFlags = 0,
  int queueLength = 2,
  DateTime? fetchedAt,
}) {
  return MeshCoreCoreStats(
    batteryMillivolts: batteryMv,
    uptime: uptime,
    errorFlags: errorFlags,
    queueLength: queueLength,
    fetchedAt: fetchedAt ?? DateTime(2026, 5, 11, 12),
  );
}

/// Banned patterns that MUST NEVER appear in any rendered text node.
final List<RegExp> _bannedRenderTextPatterns = [
  RegExp(r'\[mrrp\]'),
  RegExp(r'\[/mrrp\]'),
  RegExp(r'02:[0-9a-f]{12}:'),
  RegExp(r'01:[0-9a-f]{2}:'),
  RegExp(r'[0-9a-fA-F]{64}'),
  RegExp(r'[A-Za-z0-9+/_-]{32,}={0,2}'),
];

void _expectNoBannedText(WidgetTester tester) {
  final allTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  for (final pat in _bannedRenderTextPatterns) {
    for (final t in allTexts) {
      expect(
        pat.hasMatch(t),
        isFalse,
        reason: 'banned pattern $pat matched rendered text "$t"',
      );
    }
  }
}

void main() {
  testWidgets('CORE rows: Uptime + Firmware TX queue render alongside the '
      'RADIO rows when CORE data is present and error flags == 0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        radio: MeshCoreRadioStatsSnapshot(
          latest: _radio(),
          isStale: false,
          isConnected: true,
        ),
        core: MeshCoreCoreStatsSnapshot(
          latest: _core(
            uptime: const Duration(hours: 4, minutes: 12),
            queueLength: 2,
            errorFlags: 0,
          ),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    // RADIO rows still render (D35-A regression spot-check).
    expect(find.text('Noise floor'), findsOneWidget);
    expect(find.text('Last RSSI'), findsOneWidget);

    // CORE rows.
    expect(find.text('Uptime'), findsOneWidget);
    expect(find.text('4 h 12 m'), findsWidgets);
    expect(find.text('Firmware TX queue'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Error-flags row hidden when zero.
    expect(find.text('Firmware error flags'), findsNothing);
    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-error-flags-helper')),
      findsNothing,
    );

    // Reset note now mentions uptime alongside airtime.
    expect(
      find.text('Airtime and uptime reset only on a radio power cycle.'),
      findsOneWidget,
    );

    _expectNoBannedText(tester);
  });

  testWidgets('error-flags row visible as 0xNNNN when non-zero, helper '
      'text appears below', (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        radio: MeshCoreRadioStatsSnapshot(
          latest: _radio(),
          isStale: false,
          isConnected: true,
        ),
        core: MeshCoreCoreStatsSnapshot(
          latest: _core(errorFlags: 0x0042),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Firmware error flags'), findsOneWidget);
    expect(find.text('0x0042'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-error-flags-helper')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Firmware-internal flags. Include this value when filing a support report.',
      ),
      findsOneWidget,
    );
    _expectNoBannedText(tester);
  });

  testWidgets('error-flags hex zero-pads to 4 uppercase hex chars '
      '(e.g. 0xFFFF for the all-set case)', (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        radio: MeshCoreRadioStatsSnapshot(
          latest: _radio(),
          isStale: false,
          isConnected: true,
        ),
        core: MeshCoreCoreStatsSnapshot(
          latest: _core(errorFlags: 0xFFFF),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('0xFFFF'), findsOneWidget);
    _expectNoBannedText(tester);
  });

  testWidgets('Companion Radio card NEVER renders a battery row from CORE '
      'data - battery stays in the dedicated battery surface', (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        radio: MeshCoreRadioStatsSnapshot(
          latest: _radio(),
          isStale: false,
          isConnected: true,
        ),
        core: MeshCoreCoreStatsSnapshot(
          // Use a deliberately distinctive battery voltage so any
          // accidental render of "4012" or "4012 mV" jumps out.
          latest: _core(batteryMv: 4012),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    // No battery row label.
    expect(find.text('Battery'), findsNothing);
    expect(find.textContaining('mV'), findsNothing);
    // The raw battery integer must not appear as a row value either.
    final allTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();
    expect(
      allTexts.any((t) => t.contains('4012')),
      isFalse,
      reason: 'CORE battery_mv must NOT leak into the Companion Radio card',
    );
    _expectNoBannedText(tester);
  });

  testWidgets('CORE waiting state: when CORE has not landed yet, RADIO '
      'rows still render and CORE-only rows are absent', (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        radio: MeshCoreRadioStatsSnapshot(
          latest: _radio(),
          isStale: false,
          isConnected: true,
        ),
        core: const MeshCoreCoreStatsSnapshot(
          latest: null,
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    // RADIO rows present.
    expect(find.text('Noise floor'), findsOneWidget);
    // CORE-only rows absent.
    expect(find.text('Uptime'), findsNothing);
    expect(find.text('Firmware TX queue'), findsNothing);
    expect(find.text('Firmware error flags'), findsNothing);
    _expectNoBannedText(tester);
  });
}
