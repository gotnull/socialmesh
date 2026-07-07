// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/features/device/firmware_update_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/firmware_providers.dart';
import 'package:socialmesh/services/firmware/device_hardware_catalog.dart';
import 'package:socialmesh/services/firmware/firmware_models.dart';

// DFU button connection gate.
//
// The button's visibility comes from DB-backed node metadata
// (nodesProvider), which survives disconnects; the DFU flow itself
// consumes connectedDeviceProvider. Before the gate, a disconnected
// user saw an enabled button whose tap fired the haptic and then
// silently returned - "didn't do anything but vibrating". The button
// must disable (with an explanatory caption) while no device is
// connected, and a failed release check must surface the error banner
// instead of the benign no-update card.

const _kNodeNum = 0x1234;
const _kT1000eHwModel = 71; // TRACKER_T1000_E - nRF52840, supports DFU

class _FakeMyNodeNum extends MyNodeNumNotifier {
  @override
  int? build() => _kNodeNum;
}

class _FakeNodes extends NodesNotifier {
  @override
  Map<int, MeshNode> build() => {
    _kNodeNum: MeshNode(
      nodeNum: _kNodeNum,
      longName: 'Test Tracker',
      shortName: 'TT',
      hwModelId: _kT1000eHwModel,
      firmwareVersion: '2.7.25.104df5f',
    ),
  };
}

class _FakeConnectedDevice extends ConnectedDeviceNotifier {
  final DeviceInfo? device;
  _FakeConnectedDevice(this.device);

  @override
  DeviceInfo? build() => device;
}

class _FakeRelease extends FirmwareReleaseNotifier {
  final FirmwareRelease? release;
  final Object? error;
  _FakeRelease({this.release, this.error});

  @override
  Future<FirmwareRelease?> build() async {
    if (error != null) throw error!;
    return release;
  }
}

final _newerRelease = FirmwareRelease(
  version: '2.7.26.54e0d8d',
  tagName: 'v2.7.26.54e0d8d',
  releaseDate: DateTime.utc(2026, 6, 30),
  releaseNotes: 'Notes',
  pageUrl: 'https://example.com/release',
  assets: const [],
);

DeviceInfo _bleDevice() =>
    DeviceInfo(id: 'AA:BB:CC:DD:EE:FF', name: 'TT', type: TransportType.ble);

Widget _wrap({
  required DeviceInfo? connectedDevice,
  FirmwareRelease? release,
  Object? releaseError,
}) {
  return ProviderScope(
    overrides: [
      myNodeNumProvider.overrideWith(_FakeMyNodeNum.new),
      nodesProvider.overrideWith(_FakeNodes.new),
      connectedDeviceProvider.overrideWith(
        () => _FakeConnectedDevice(connectedDevice),
      ),
      firmwareReleaseProvider.overrideWith(
        () => _FakeRelease(release: release, error: releaseError),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const FirmwareUpdateScreen(),
    ),
  );
}

Future<void> _pumpSettled(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  // Let the async release future and localization load resolve.
  await tester.pumpAndSettle();
}

Finder _dfuButton(WidgetTester tester) {
  final l10n = AppLocalizations.of(
    tester.element(find.byType(FirmwareUpdateScreen)),
  );
  return find.widgetWithText(FilledButton, l10n.firmwareDfuStartUpdate);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // architectureFromHwModel resolves through the bundled hardware
    // catalog; without it the T1000-E falls back to unknown and the
    // DFU button never renders.
    DeviceHardwareCatalog.instance.resetForTesting();
    await DeviceHardwareCatalog.instance.load();
  });

  testWidgets('disconnected: button rendered but disabled with hint', (
    tester,
  ) async {
    await _pumpSettled(
      tester,
      _wrap(connectedDevice: null, release: _newerRelease),
    );

    final buttonFinder = _dfuButton(tester);
    await tester.scrollUntilVisible(buttonFinder, 200);
    final button = tester.widget<FilledButton>(buttonFinder);
    expect(
      button.onPressed,
      isNull,
      reason:
          'Without a live connection the DFU flow has no device address; '
          'an enabled button here is the silent no-op the tester reported.',
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(FirmwareUpdateScreen)),
    );
    expect(find.text(l10n.firmwareDfuConnectRequired), findsOneWidget);
  });

  testWidgets('connected: button enabled, no hint', (tester) async {
    await _pumpSettled(
      tester,
      _wrap(connectedDevice: _bleDevice(), release: _newerRelease),
    );

    final buttonFinder = _dfuButton(tester);
    await tester.scrollUntilVisible(buttonFinder, 200);
    final button = tester.widget<FilledButton>(buttonFinder);
    expect(button.onPressed, isNotNull);

    final l10n = AppLocalizations.of(
      tester.element(find.byType(FirmwareUpdateScreen)),
    );
    expect(find.text(l10n.firmwareDfuConnectRequired), findsNothing);
  });

  testWidgets('release check failure surfaces the error banner', (
    tester,
  ) async {
    await _pumpSettled(
      tester,
      _wrap(connectedDevice: _bleDevice(), releaseError: Exception('HTTP 403')),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(FirmwareUpdateScreen)),
    );
    expect(
      find.text(l10n.firmwareUpdateCheckFailed),
      findsOneWidget,
      reason:
          'A failed check must be distinguishable from "no update '
          'available" - this banner used to be dead code because the '
          'service swallowed every error into null.',
    );
    expect(find.byType(StatusBanner), findsWidgets);
  });
}
