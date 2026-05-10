// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D35-PACKETS-A: collapsible Packet counters subsection regression
// pins.
//
// Pinned invariants:
//   - Header renders, default collapsed.
//   - Collapsed state hides all 7 row labels.
//   - Tapping the header expands and renders all 7 rows with
//     thousands-grouped count formatting.
//   - Tapping again collapses; rows hidden.
//   - When session is disconnected, the section header is suppressed
//     (we hide the entire section in the disconnected state to avoid
//     a useless toggle).
//   - D35-A RADIO rows still render alongside.
//   - D35-B-A CORE rows still render alongside.
//   - D35-B-A error-flags row still renders when non-zero.
//   - Banned-pattern sweep on every rendered Text widget.

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

class _StubPacketsNotifier extends MeshCorePacketsStatsNotifier {
  _StubPacketsNotifier(this._initial);
  final MeshCorePacketsStatsSnapshot _initial;
  @override
  MeshCorePacketsStatsSnapshot build() => _initial;
}

Widget _wrap({
  required MeshCoreRadioStatsSnapshot radio,
  required MeshCoreCoreStatsSnapshot core,
  MeshCorePacketsStatsSnapshot? packets,
}) {
  return ProviderScope(
    overrides: [
      meshCoreRadioStatsProvider.overrideWith(() => _StubRadioNotifier(radio)),
      meshCoreCoreStatsProvider.overrideWith(() => _StubCoreNotifier(core)),
      meshCorePacketsStatsProvider.overrideWith(
        () => _StubPacketsNotifier(
          packets ?? const MeshCorePacketsStatsSnapshot.disconnected(),
        ),
      ),
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

MeshCoreCoreStats _core({int errorFlags = 0}) {
  return MeshCoreCoreStats(
    batteryMillivolts: 4012,
    uptime: const Duration(hours: 4, minutes: 12),
    errorFlags: errorFlags,
    queueLength: 2,
    fetchedAt: DateTime(2026, 5, 11, 12),
  );
}

MeshCorePacketsStats _packets({
  int rx = 1247,
  int tx = 892,
  int sentFlood = 34,
  int sentDirect = 858,
  int recvFlood = 412,
  int recvDirect = 830,
  int recvErrors = 3,
}) {
  return MeshCorePacketsStats(
    packetsReceived: rx,
    packetsSent: tx,
    sentFlood: sentFlood,
    sentDirect: sentDirect,
    recvFlood: recvFlood,
    recvDirect: recvDirect,
    recvErrors: recvErrors,
    fetchedAt: DateTime(2026, 5, 11, 12),
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
  testWidgets('Packet counters header renders by default and section is '
      'collapsed (all 7 row labels absent)', (tester) async {
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
          latest: _core(),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    // Header visible.
    expect(find.text('Packet counters'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-packets-header')),
      findsOneWidget,
    );

    // No row labels yet (collapsed).
    expect(find.text('Packets received'), findsNothing);
    expect(find.text('Packets sent'), findsNothing);
    expect(find.text('Sent flood'), findsNothing);
    expect(find.text('Sent direct'), findsNothing);
    expect(find.text('Received flood'), findsNothing);
    expect(find.text('Received direct'), findsNothing);
    expect(find.text('Reception errors'), findsNothing);

    _expectNoBannedText(tester);
  });

  testWidgets('tapping the header expands the section and all 7 rows '
      'render with thousands-grouped count formatting', (tester) async {
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
          latest: _core(),
          isStale: false,
          isConnected: true,
        ),
        packets: MeshCorePacketsStatsSnapshot(
          latest: _packets(),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('meshcore-radio-stats-packets-header')),
    );
    await tester.pump();

    // Row labels.
    expect(find.text('Packets received'), findsOneWidget);
    expect(find.text('Packets sent'), findsOneWidget);
    expect(find.text('Sent flood'), findsOneWidget);
    expect(find.text('Sent direct'), findsOneWidget);
    expect(find.text('Received flood'), findsOneWidget);
    expect(find.text('Received direct'), findsOneWidget);
    expect(find.text('Reception errors'), findsOneWidget);

    // Formatted counts (thousands grouping).
    expect(find.text('1,247'), findsOneWidget);
    expect(find.text('892'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.text('858'), findsOneWidget);
    expect(find.text('412'), findsOneWidget);
    expect(find.text('830'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    _expectNoBannedText(tester);
  });

  testWidgets('tapping the header again collapses the section', (tester) async {
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
          latest: _core(),
          isStale: false,
          isConnected: true,
        ),
        packets: MeshCorePacketsStatsSnapshot(
          latest: _packets(),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    final header = find.byKey(
      const ValueKey('meshcore-radio-stats-packets-header'),
    );
    await tester.tap(header);
    await tester.pump();
    expect(find.text('Packets received'), findsOneWidget);

    // Tap again -> collapse.
    await tester.tap(header);
    await tester.pump();
    expect(find.text('Packets received'), findsNothing);
    expect(find.text('Packets sent'), findsNothing);
  });

  testWidgets('disconnected: the Packet counters section is hidden '
      'entirely (no header, no rows)', (tester) async {
    tester.view.physicalSize = const Size(440, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(
        radio: const MeshCoreRadioStatsSnapshot.disconnected(),
        core: const MeshCoreCoreStatsSnapshot.disconnected(),
      ),
    );
    await tester.pump();

    expect(find.text('Packet counters'), findsNothing);
    expect(
      find.byKey(const ValueKey('meshcore-radio-stats-packets-header')),
      findsNothing,
    );
  });

  testWidgets('D35-A RADIO rows still render alongside the new section', (
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
          latest: _core(),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    // D35-A regression spot.
    expect(find.text('Noise floor'), findsOneWidget);
    expect(find.text('Last RSSI'), findsOneWidget);
    expect(find.text('Last SNR'), findsOneWidget);
    expect(find.text('TX airtime'), findsOneWidget);
    expect(find.text('RX airtime'), findsOneWidget);
  });

  testWidgets('D35-B-A CORE rows still render alongside the new section', (
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
          latest: _core(),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    // D35-B-A regression spot.
    expect(find.text('Uptime'), findsOneWidget);
    expect(find.text('Firmware TX queue'), findsOneWidget);
  });

  testWidgets('D35-B-A error-flags row still renders when non-zero', (
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
          latest: _core(errorFlags: 0x0042),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Firmware error flags'), findsOneWidget);
    expect(find.text('0x0042'), findsOneWidget);
  });

  testWidgets('large counter (>= 1,000,000) renders with two thousands '
      'separators', (tester) async {
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
          latest: _core(),
          isStale: false,
          isConnected: true,
        ),
        packets: MeshCorePacketsStatsSnapshot(
          latest: _packets(rx: 1234567),
          isStale: false,
          isConnected: true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('meshcore-radio-stats-packets-header')),
    );
    await tester.pump();

    expect(find.text('1,234,567'), findsOneWidget);
  });
}
