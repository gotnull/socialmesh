// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/settings/power_config_screen.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

final _l10n = AppLocalizationsEn();

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService({this.cachedConfig}) : super(_FakeTransport());

  config_pb.Config_PowerConfig? cachedConfig;
  final List<config_pb.Config_PowerConfig> savedConfigs = [];
  final StreamController<config_pb.Config_PowerConfig> _ctrl =
      StreamController<config_pb.Config_PowerConfig>.broadcast();

  @override
  config_pb.Config_PowerConfig? get currentPowerConfig => cachedConfig;

  @override
  Stream<config_pb.Config_PowerConfig> get powerConfigStream => _ctrl.stream;

  @override
  bool get isConnected => false; // skip the get-config-from-device branch

  @override
  Future<void> getConfig(
    admin.AdminMessage_ConfigType configType, {
    AdminTarget? target,
  }) async {
    // No-op in tests; cached config is what the screen will apply.
  }

  @override
  Future<void> setPowerConfig({
    required bool isPowerSaving,
    required int waitBluetoothSecs,
    required int sdsSecs,
    required int lsSecs,
    required int minWakeSecs,
    int onBatteryShutdownAfterSecs = 0,
    double adcMultiplierOverride = 0.0,
    AdminTarget? target,
  }) async {
    savedConfigs.add(
      config_pb.Config_PowerConfig()
        ..isPowerSaving = isPowerSaving
        ..waitBluetoothSecs = waitBluetoothSecs
        ..sdsSecs = sdsSecs
        ..lsSecs = lsSecs
        ..minWakeSecs = minWakeSecs
        ..onBatteryShutdownAfterSecs = onBatteryShutdownAfterSecs
        ..adcMultiplierOverride = adcMultiplierOverride,
    );
  }

  Future<void> closeStreams() async {
    await _ctrl.close();
  }
}

class _FakeTransport extends DeviceTransport {
  @override
  TransportType get type => TransportType.ble;
  @override
  bool get requiresFraming => false;
  @override
  bool get requiresWakeSequence => false;
  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;
  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;
  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();
  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;
  @override
  Stream<List<int>> get dataStream => const Stream.empty();
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();
  @override
  Future<void> connect(DeviceInfo device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> enableNotifications() async {}
  @override
  Future<void> pollOnce() async {}
  @override
  Future<void> send(List<int> data) async {}
  @override
  Future<int?> readRssi() async => null;
  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

Widget _wrap({required _FakeProtocolService protocol}) {
  return ProviderScope(
    overrides: [protocolServiceProvider.overrideWithValue(protocol)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const PowerConfigScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('loaded valid value: shows in field, hint visible, no error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(
      cachedConfig: config_pb.Config_PowerConfig()..adcMultiplierOverride = 3.2,
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(_wrap(protocol: protocol));
    await _settle(tester);

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, '3.20');
    expect(find.text(_l10n.powerConfigAdcMultiplierHint), findsOneWidget);
    expect(find.text(_l10n.powerConfigAdcMultiplierRangeError), findsNothing);
  });

  testWidgets('DIY below-2.0 value (1.72) loads cleanly with no error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // A DIY node with a non-standard voltage divider reports a ratio below the
    // old 2.0-6.0 recommendation. The firmware accepts any positive value, so
    // the UI must show it without an error.
    final protocol = _FakeProtocolService(
      cachedConfig: config_pb.Config_PowerConfig()
        ..adcMultiplierOverride = 1.72,
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(_wrap(protocol: protocol));
    await _settle(tester);

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller!.text, '1.72');
    expect(find.text(_l10n.powerConfigAdcMultiplierRangeError), findsNothing);
    expect(find.text(_l10n.powerConfigAdcMultiplierHint), findsOneWidget);
  });

  testWidgets('typing a DIY value (1.73) is accepted and saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Start with override already enabled and a valid value so the field
    // is mounted from first frame.
    final protocol = _FakeProtocolService(
      cachedConfig: config_pb.Config_PowerConfig()..adcMultiplierOverride = 3.2,
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(_wrap(protocol: protocol));
    await _settle(tester);

    // Enter the reporter's below-2.0 DIY ratio.
    await tester.enterText(find.byType(TextFormField), '1.73');
    await _settle(tester);

    // No error, hint stays visible.
    expect(find.text(_l10n.powerConfigAdcMultiplierRangeError), findsNothing);
    expect(find.text(_l10n.powerConfigAdcMultiplierHint), findsOneWidget);

    // Save persists the value.
    await tester.tap(find.text(_l10n.powerConfigSave));
    await _settle(tester);
    expect(protocol.savedConfigs, hasLength(1));
    expect(
      protocol.savedConfigs.first.adcMultiplierOverride,
      closeTo(1.73, 1e-5),
    );
  });

  testWidgets('typing zero surfaces inline error and blocks save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(
      cachedConfig: config_pb.Config_PowerConfig()..adcMultiplierOverride = 3.2,
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(_wrap(protocol: protocol));
    await _settle(tester);

    // 0 means "use the firmware default", which contradicts override-on, so it
    // is rejected while the override is enabled.
    await tester.enterText(find.byType(TextFormField), '0');
    await _settle(tester);

    expect(find.text(_l10n.powerConfigAdcMultiplierRangeError), findsOneWidget);

    // Tap Save — should be a silent no-op because the button is disabled.
    await tester.tap(find.text(_l10n.powerConfigSave));
    await _settle(tester);
    expect(protocol.savedConfigs, isEmpty);
  });

  testWidgets('correcting an invalid value clears error and allows save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(
      cachedConfig: config_pb.Config_PowerConfig()..adcMultiplierOverride = 3.2,
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(_wrap(protocol: protocol));
    await _settle(tester);

    // Invalid (not > 0) first.
    await tester.enterText(find.byType(TextFormField), '0');
    await _settle(tester);
    expect(find.text(_l10n.powerConfigAdcMultiplierRangeError), findsOneWidget);

    // Correct it to a valid DIY ratio.
    await tester.enterText(find.byType(TextFormField), '1.72');
    await _settle(tester);

    expect(find.text(_l10n.powerConfigAdcMultiplierRangeError), findsNothing);
    expect(find.text(_l10n.powerConfigAdcMultiplierHint), findsOneWidget);

    // Save now persists the corrected value.
    await tester.tap(find.text(_l10n.powerConfigSave));
    await _settle(tester);

    expect(protocol.savedConfigs, hasLength(1));
    expect(
      protocol.savedConfigs.first.adcMultiplierOverride,
      closeTo(1.72, 1e-5),
    );
  });

  testWidgets('locale-aware: comma decimal "3,75" is accepted as 3.75', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(
      cachedConfig: config_pb.Config_PowerConfig()..adcMultiplierOverride = 3.2,
    );
    addTearDown(protocol.closeStreams);

    await tester.pumpWidget(_wrap(protocol: protocol));
    await _settle(tester);

    await tester.enterText(find.byType(TextFormField), '3,75');
    await _settle(tester);

    expect(find.text(_l10n.powerConfigAdcMultiplierRangeError), findsNothing);

    await tester.tap(find.text(_l10n.powerConfigSave));
    await _settle(tester);

    expect(protocol.savedConfigs, hasLength(1));
    expect(protocol.savedConfigs.first.adcMultiplierOverride, 3.75);
  });

  testWidgets(
    'empty field hides the error (but Save still blocked by override on)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final protocol = _FakeProtocolService(
        cachedConfig: config_pb.Config_PowerConfig()
          ..adcMultiplierOverride = 3.2,
      );
      addTearDown(protocol.closeStreams);

      await tester.pumpWidget(_wrap(protocol: protocol));
      await _settle(tester);

      // Type invalid value, then clear.
      await tester.enterText(find.byType(TextFormField), '0');
      await _settle(tester);
      expect(
        find.text(_l10n.powerConfigAdcMultiplierRangeError),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextFormField), '');
      await _settle(tester);

      expect(find.text(_l10n.powerConfigAdcMultiplierRangeError), findsNothing);
      expect(find.text(_l10n.powerConfigAdcMultiplierHint), findsOneWidget);
    },
  );
}
