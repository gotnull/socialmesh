// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-A - `MeshCoreRadioStatsCard` widget regression pins.
//
// Pinned invariants:
//   - Disconnected state renders the "No active MeshCore session"
//     placeholder.
//   - Connected + waiting state renders the "Waiting for first
//     reading" placeholder when no snapshot has landed yet.
//   - Connected + fresh state renders all five rows with formatted
//     dBm / dB / Duration values.
//   - Connected + stale state renders the stale hint and greys out
//     the InfoTable.
//   - Airtime reset note always renders alongside live values.
//   - Rendered text never leaks raw payload bytes, full pubkeys,
//     channel names, MMFs, or `[mrrp]` envelope content.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_radio_stats_card.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

class _StubNotifier extends MeshCoreRadioStatsNotifier {
  _StubNotifier(this._initial);
  final MeshCoreRadioStatsSnapshot _initial;

  @override
  MeshCoreRadioStatsSnapshot build() => _initial;
}

Widget _wrap(MeshCoreRadioStatsSnapshot snapshot) {
  return ProviderScope(
    overrides: [
      meshCoreRadioStatsProvider.overrideWith(() => _StubNotifier(snapshot)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MeshCoreRadioStatsCard()),
    ),
  );
}

MeshCoreRadioStats _stats({
  int noise = -110,
  int rssi = -83,
  int snrQuarter = 30,
  Duration tx = const Duration(seconds: 42),
  Duration rx = const Duration(minutes: 78, seconds: 0),
  DateTime? fetchedAt,
}) {
  return MeshCoreRadioStats(
    noiseFloorDbm: noise,
    lastRssiDbm: rssi,
    lastSnrQuarter: snrQuarter,
    txAirtime: tx,
    rxAirtime: rx,
    fetchedAt: fetchedAt ?? DateTime(2026, 5, 10, 12),
  );
}

/// Banned patterns that MUST NEVER appear in any rendered text node.
final List<RegExp> _bannedRenderTextPatterns = [
  RegExp(r'\[mrrp\]'),
  RegExp(r'\[/mrrp\]'),
  RegExp(r'02:[0-9a-f]{12}:'),
  RegExp(r'01:[0-9a-f]{2}:'),
  // 32-byte hex pubkey (any case).
  RegExp(r'[0-9a-fA-F]{64}'),
  // Long base64-ish runs (envelope content).
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
  testWidgets('disconnected: renders the "No active MeshCore session" '
      'placeholder', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(const MeshCoreRadioStatsSnapshot.disconnected()),
    );
    await tester.pump();

    expect(find.text('COMPANION RADIO'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-no-session')),
      findsOneWidget,
    );
    expect(find.text('No active MeshCore session'), findsOneWidget);
    // No row labels render in the disconnected state.
    expect(find.text('Noise floor'), findsNothing);
    expect(find.text('Last RSSI'), findsNothing);
    _expectNoBannedText(tester);
  });

  testWidgets('connected + waiting: renders the "Waiting for first '
      'reading" placeholder when no snapshot has landed', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        const MeshCoreRadioStatsSnapshot(
          latest: null,
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-fetching')),
      findsOneWidget,
    );
    expect(find.text('Waiting for first reading…'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-stale-hint')),
      findsNothing,
    );
    _expectNoBannedText(tester);
  });

  testWidgets('connected + fresh: renders all five rows with formatted '
      'dBm / dB / Duration values plus the airtime reset note', (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        MeshCoreRadioStatsSnapshot(
          latest: _stats(
            noise: -110,
            rssi: -83,
            snrQuarter: 30, // 7.5 dB
            tx: const Duration(seconds: 42),
            rx: const Duration(hours: 1, minutes: 18),
          ),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    // Row labels.
    expect(find.text('Noise floor'), findsOneWidget);
    expect(find.text('Last RSSI'), findsOneWidget);
    expect(find.text('Last SNR'), findsOneWidget);
    expect(find.text('TX airtime'), findsOneWidget);
    expect(find.text('RX airtime'), findsOneWidget);

    // Formatted values.
    expect(find.text('-110 dBm'), findsOneWidget);
    expect(find.text('-83 dBm'), findsOneWidget);
    expect(find.text('7.5 dB'), findsOneWidget);
    expect(find.text('42 s'), findsOneWidget);
    expect(find.text('1 h 18 m'), findsOneWidget);

    // Reset note.
    expect(
      find.text('Airtime totals reset only on a radio power cycle.'),
      findsOneWidget,
    );

    // No stale hint when the data is fresh.
    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-stale-hint')),
      findsNothing,
    );

    _expectNoBannedText(tester);
  });

  testWidgets('connected + stale: renders the stale hint above the '
      '(greyed) InfoTable', (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        MeshCoreRadioStatsSnapshot(
          latest: _stats(),
          isStale: true,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-stale-hint')),
      findsOneWidget,
    );
    expect(find.text('Stale data, reconnecting…'), findsOneWidget);
    // Rows still render - they are greyed by Opacity, not removed.
    expect(find.text('Noise floor'), findsOneWidget);
    _expectNoBannedText(tester);
  });

  testWidgets(
    'duration formatter renders sub-minute / minute+second / hour+minute '
    'shapes correctly',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          MeshCoreRadioStatsSnapshot(
            latest: _stats(
              tx: const Duration(seconds: 42), // → "42 s"
              rx: const Duration(minutes: 5, seconds: 17), // → "5 m 17 s"
            ),
            isStale: false,
            isConnected: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('42 s'), findsOneWidget);
      expect(find.text('5 m 17 s'), findsOneWidget);
    },
  );
}
