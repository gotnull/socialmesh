// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/animations.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';
import 'package:socialmesh/core/widgets/status_banner.dart';
import 'package:socialmesh/features/settings/canned_message_module_config_screen.dart';
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

  module_pb.ModuleConfig_CannedMessageConfig? cachedConfig;
  final StreamController<module_pb.ModuleConfig_CannedMessageConfig>
  _configCtrl =
      StreamController<module_pb.ModuleConfig_CannedMessageConfig>.broadcast();
  final StreamController<String> _textCtrl =
      StreamController<String>.broadcast();

  @override
  module_pb.ModuleConfig_CannedMessageConfig? get currentCannedMessageConfig =>
      cachedConfig;

  @override
  Stream<module_pb.ModuleConfig_CannedMessageConfig>
  get cannedMessageConfigStream => _configCtrl.stream;

  @override
  Stream<String> get cannedMessageTextStream => _textCtrl.stream;

  @override
  bool get isConnected => false; // skip the get-config-from-device branch

  @override
  Future<void> getModuleConfig(
    admin.AdminMessage_ModuleConfigType moduleType, {
    AdminTarget? target,
  }) async {}

  Future<void> closeStreams() async {
    await _configCtrl.close();
    await _textCtrl.close();
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

Future<void> _pumpScreen(
  WidgetTester tester,
  module_pb.ModuleConfig_CannedMessageConfig config,
) async {
  tester.view.physicalSize = const Size(1080, 8000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final protocol = _FakeProtocolService(cachedConfig: config);
  addTearDown(protocol.closeStreams);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [protocolServiceProvider.overrideWithValue(protocol)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: const CannedMessageModuleConfigScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

ThemedSwitch _switchFor(WidgetTester tester, String title) =>
    tester.widget<ThemedSwitch>(
      find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(SettingsTile),
        ),
        matching: find.byType(ThemedSwitch),
      ),
    );

void main() {
  testWidgets('manual preset shows every section on the shared primitives', (
    tester,
  ) async {
    await _pumpScreen(tester, module_pb.ModuleConfig_CannedMessageConfig());

    // Options, device messages, preset, control type, GPIO, key mapping.
    expect(find.byType(SettingsSectionHeader), findsNWidgets(6));
    // Enabled, send bell, rotary, up/down.
    expect(find.byType(SettingsTile), findsNWidgets(4));
    // Messages, presets, GPIO pickers, key mapping.
    expect(find.byType(FieldGroupCard), findsNWidgets(4));
    expect(find.byType(StatusBanner), findsOneWidget);
  });

  testWidgets('a hardware preset hides the manual control sections', (
    tester,
  ) async {
    await _pumpScreen(tester, module_pb.ModuleConfig_CannedMessageConfig());

    await tester.tap(find.text(_l10n.cannedModulePresetRak));
    await tester.pump();

    expect(find.byType(SettingsSectionHeader), findsNWidgets(3));
    expect(find.text(_l10n.cannedModuleSectionGpio), findsNothing);
    expect(find.text(_l10n.cannedModuleSectionKeyMapping), findsNothing);
    expect(find.byType(SettingsTile), findsNWidgets(2));
  });

  testWidgets('rotary and up/down lock each other', (tester) async {
    await _pumpScreen(
      tester,
      module_pb.ModuleConfig_CannedMessageConfig()..rotary1Enabled = true,
    );

    final rotary = _switchFor(tester, _l10n.cannedModuleControlRotary);
    final upDown = _switchFor(tester, _l10n.cannedModuleControlUpDown);
    expect(rotary.value, isTrue);
    expect(rotary.onChanged, isNotNull);
    expect(upDown.onChanged, isNull);
  });
}
