// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/animations.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';
import 'package:socialmesh/features/settings/traffic_management_config_screen.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

final _l10n = AppLocalizationsEn();

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService({this.cachedConfig}) : super(_FakeTransport());

  module_pb.ModuleConfig_TrafficManagementConfig? cachedConfig;
  final StreamController<module_pb.ModuleConfig_TrafficManagementConfig> _ctrl =
      StreamController<
        module_pb.ModuleConfig_TrafficManagementConfig
      >.broadcast();

  @override
  module_pb.ModuleConfig_TrafficManagementConfig?
  get currentTrafficManagementConfig => cachedConfig;

  @override
  Stream<module_pb.ModuleConfig_TrafficManagementConfig>
  get trafficManagementConfigStream => _ctrl.stream;

  @override
  bool get isConnected => false; // skip the get-config-from-device branch

  @override
  Future<void> getModuleConfig(
    admin.AdminMessage_ModuleConfigType moduleType, {
    AdminTarget? target,
  }) async {}

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
      home: const TrafficManagementConfigScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  Future<void> pumpScreen(
    WidgetTester tester,
    module_pb.ModuleConfig_TrafficManagementConfig config,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final protocol = _FakeProtocolService(cachedConfig: config);
    addTearDown(protocol.closeStreams);
    await tester.pumpWidget(_wrap(protocol: protocol));
    await _settle(tester);
  }

  testWidgets('all features off: four headers and toggles, no slider cards', (
    tester,
  ) async {
    await pumpScreen(tester, module_pb.ModuleConfig_TrafficManagementConfig());

    expect(find.byType(SettingsSectionHeader), findsNWidgets(4));
    expect(find.text(_l10n.trafficMgmtSectionPositionDedup), findsOneWidget);
    expect(find.text(_l10n.trafficMgmtSectionNodeinfoResponse), findsOneWidget);
    expect(find.text(_l10n.trafficMgmtSectionRateLimit), findsOneWidget);
    expect(find.text(_l10n.trafficMgmtSectionUnknownPackets), findsOneWidget);
    expect(find.byType(SettingsTile), findsNWidgets(4));
    expect(find.byType(ThemedSwitch), findsNWidgets(4));
    expect(find.byType(FieldGroupCard), findsNothing);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('enabled features show their slider cards with radio values', (
    tester,
  ) async {
    // 18000s is the firmware 2.8 default and sits outside the 10-600s slider;
    // the label must still show the radio's real value.
    await pumpScreen(
      tester,
      module_pb.ModuleConfig_TrafficManagementConfig()
        ..positionMinIntervalSecs = 18000
        ..rateLimitWindowSecs = 30
        ..rateLimitMaxPackets = 10,
    );

    expect(find.byType(FieldGroupCard), findsNWidgets(2));
    expect(find.byType(Slider), findsNWidgets(3));
    expect(find.text(_l10n.trafficMgmtMinInterval(18000)), findsOneWidget);
    expect(find.text(_l10n.trafficMgmtWindow(30)), findsOneWidget);
    expect(find.text(_l10n.trafficMgmtMaxPackets(10)), findsOneWidget);
  });

  testWidgets('turning a feature on reveals its slider card', (tester) async {
    await pumpScreen(tester, module_pb.ModuleConfig_TrafficManagementConfig());

    final dedupSwitch = find.descendant(
      of: find.ancestor(
        of: find.text(_l10n.trafficMgmtPositionDedup),
        matching: find.byType(SettingsTile),
      ),
      matching: find.byType(ThemedSwitch),
    );
    tester.widget<ThemedSwitch>(dedupSwitch).onChanged!(true);
    await tester.pump();

    expect(find.byType(FieldGroupCard), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    // Defaults to 60s until the user moves the slider.
    expect(find.text(_l10n.trafficMgmtMinInterval(60)), findsOneWidget);
  });
}
