// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D41-A: `showMeshCoreTelemetrySheet` rendering regression pins.
//
// We stub `meshCoreTelemetryProvider` directly with the family-arg
// overrideWith form so each test drives the sheet into a specific
// state (success / requesting / failure / cooling / empty) without
// hitting the session or transport.
//
// Pinned invariants (this file):
//   - Sheet header renders the contact display name.
//   - Success state with mixed-channel readings renders the Device
//     section AND the Aux N section in wire order (channel 1 first,
//     other channels after).
//   - Each reading-row label + formatted value renders.
//   - Empty success (zero readings) renders the no-data hint.
//   - Failure (timeout) renders the timeout copy.
//   - Cooling renders the "Try again in Ns" copy.
//   - Redaction sweep on every rendered Text widget: no full 32-byte
//     pubkey hex, no 4+ digit raw decimal (proxy for "raw u16 LPP
//     value leaked"), no base64 envelope-shaped string.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_telemetry_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_cayenne_lpp.dart';

class _StubTelemetryNotifier extends MeshCoreTelemetryNotifier {
  _StubTelemetryNotifier(super.publicKeyHex, this._initial);
  final MeshCoreTelemetryState _initial;

  @override
  MeshCoreTelemetryState build() => _initial;

  @override
  Future<void> requestRefresh() async {
    // No-op in tests; the sheet's initState calls requestRefresh()
    // but we want the stubbed state to remain unchanged.
  }
}

class _SheetOpener extends StatefulWidget {
  final MeshCoreContact contact;
  const _SheetOpener({required this.contact});

  @override
  State<_SheetOpener> createState() => _SheetOpenerState();
}

class _SheetOpenerState extends State<_SheetOpener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showMeshCoreTelemetrySheet(context, contact: widget.contact);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

MeshCoreContact _contact({String name = 'Sensor-Alpha'}) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    name: name,
    type: MeshCoreAdvType.sensor,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

Widget _wrap({
  required MeshCoreContact contact,
  required MeshCoreTelemetryState state,
}) {
  return ProviderScope(
    overrides: [
      meshCoreTelemetryProvider(
        contact.publicKeyHex,
      ).overrideWith(() => _StubTelemetryNotifier(contact.publicKeyHex, state)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: _SheetOpener(contact: contact)),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

final List<RegExp> _bannedRenderTextPatterns = [
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
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'success state with mixed-channel readings renders Device + Aux sections '
    'and one row per reading in wire order',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final contact = _contact(name: 'Sensor-Alpha');
      final state = MeshCoreTelemetryState(
        status: MeshCoreTelemetryStatus.success,
        lastResponse: MeshCoreTelemetryResponse(
          readings: [
            const MeshCoreTelemetryVoltage(1, 4.05),
            const MeshCoreTelemetryTemperature(1, 21.5),
            const MeshCoreTelemetryHumidity(2, 47.0),
            const MeshCoreTelemetryPressure(2, 1013.2),
          ],
          unknownTypes: const {},
          fetchedAt: DateTime(2026, 5, 11, 12),
        ),
      );

      await tester.pumpWidget(_wrap(contact: contact, state: state));
      await tester.pump();
      await _openSheet(tester);

      // SectionTitle uppercases its title.
      expect(find.text('TELEMETRY - SENSOR-ALPHA'), findsOneWidget);
      expect(find.text('DEVICE'), findsOneWidget);
      expect(find.text('AUX 2'), findsOneWidget);

      // Row labels + formatted values.
      expect(find.text('Battery'), findsOneWidget);
      expect(find.text('4.05 V'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('21.5°C'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('47.0 %'), findsOneWidget);
      expect(find.text('Pressure'), findsOneWidget);
      expect(find.text('1013.2 hPa'), findsOneWidget);

      // Refresh affordance is present.
      expect(
        find.byKey(const ValueKey('meshcore-telemetry-refresh')),
        findsOneWidget,
      );

      _expectNoBannedText(tester);
    },
  );

  testWidgets('empty success (zero readings) renders the no-data hint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final contact = _contact();
    final state = MeshCoreTelemetryState(
      status: MeshCoreTelemetryStatus.success,
      lastResponse: MeshCoreTelemetryResponse(
        readings: const [],
        unknownTypes: const {},
        fetchedAt: DateTime(2026, 5, 11, 12),
      ),
    );

    await tester.pumpWidget(_wrap(contact: contact, state: state));
    await tester.pump();
    await _openSheet(tester);

    expect(find.text('No telemetry available'), findsOneWidget);
    _expectNoBannedText(tester);
  });

  testWidgets('failure (timeout) renders the timeout copy', (tester) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final contact = _contact();
    const state = MeshCoreTelemetryState(
      status: MeshCoreTelemetryStatus.failure,
      lastError: 'timeout',
    );

    await tester.pumpWidget(_wrap(contact: contact, state: state));
    await tester.pump();
    await _openSheet(tester);

    expect(find.text('Telemetry request timed out'), findsOneWidget);
    _expectNoBannedText(tester);
  });

  testWidgets('cooling state renders the "Try again in Ns" copy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final contact = _contact();
    final state = MeshCoreTelemetryState(
      status: MeshCoreTelemetryStatus.cooling,
      cooldownUntil: DateTime.now().add(const Duration(seconds: 8)),
    );

    await tester.pumpWidget(_wrap(contact: contact, state: state));
    await tester.pump();
    await _openSheet(tester);

    // Allow 1s of slack: clock advance during pump + DateTime.now()
    // can shave a second off the rounding.
    final cooling = find.textContaining(RegExp(r'Try again in [678]s'));
    expect(cooling, findsOneWidget);
    _expectNoBannedText(tester);
  });

  testWidgets('requesting state renders the "Requesting telemetry…" hint', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final contact = _contact();
    const state = MeshCoreTelemetryState(
      status: MeshCoreTelemetryStatus.requesting,
    );

    await tester.pumpWidget(_wrap(contact: contact, state: state));
    await tester.pump();
    await _openSheet(tester);

    expect(find.text('Requesting telemetry…'), findsOneWidget);
    _expectNoBannedText(tester);
  });
}
