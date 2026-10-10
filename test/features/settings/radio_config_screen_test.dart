// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/animations.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';
import 'package:socialmesh/features/settings/radio_config_screen.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

final _l10n = AppLocalizationsEn();

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService(this.cachedConfig, this.firmware, this.remote)
    : super(_FakeTransport());

  final config_pb.Config_LoRaConfig cachedConfig;
  final String? firmware;
  final bool remote;

  @override
  int? get myNodeNum => 0x1234;

  @override
  Map<int, MeshNode> get nodes => {
    0x1234: MeshNode(
      nodeNum: 0x1234,
      firmwareVersion: remote ? '2.8.0' : firmware,
    ),
    if (remote) 0x5678: MeshNode(nodeNum: 0x5678, firmwareVersion: firmware),
  };

  @override
  config_pb.Config_LoRaConfig? remoteLoraConfig(int nodeNum) => cachedConfig;
  final StreamController<config_pb.Config_LoRaConfig> _ctrl =
      StreamController<config_pb.Config_LoRaConfig>.broadcast();

  @override
  config_pb.Config_LoRaConfig? get currentLoraConfig => cachedConfig;

  @override
  Stream<config_pb.Config_LoRaConfig> get loraConfigStream => _ctrl.stream;

  @override
  bool get isConnected => false; // skip the get-config-from-device branch

  @override
  Future<void> getConfig(
    admin.AdminMessage_ConfigType configType, {
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

Future<void> _pumpScreen(
  WidgetTester tester,
  config_pb.Config_LoRaConfig config, {
  String? firmware,
  bool remote = false,
}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  final protocol = _FakeProtocolService(config, firmware, remote);
  addTearDown(protocol.closeStreams);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        protocolServiceProvider.overrideWithValue(protocol),
        remoteAdminTargetProvider.overrideWith((ref) => remote ? 0x5678 : null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: const RadioConfigScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

config_pb.Config_LoRaConfig _preset(
  Config_LoRaConfig_RegionCode region,
  Config_LoRaConfig_ModemPreset preset,
) => config_pb.Config_LoRaConfig()
  ..region = region
  ..usePreset = true
  ..modemPreset = preset;

final _noticeTitle = find.text(_l10n.radioConfigUsBandwidthNoticeTitle);
final _noticeBody = find.text(
  _l10n.radioConfigUsBandwidthNoticeBody(_l10n.radioConfigPresetLongTurbo),
);

// Phrases that would overstate the Part 15.247 point. The notice and the
// help pages describe one rule path; they never rule a configuration out.
final _categorical = RegExp(
  r'illegal|not legal|unlawful|all US|every US|always require|'
  r'Long ?Fast is|250 kHz is|must use 500',
  caseSensitive: false,
);

void main() {
  group('FEM LNA', () {
    for (final remote in [false, true]) {
      for (final mode in Config_LoRaConfig_FEM_LNA_Mode.values) {
        testWidgets('reported $mode on ${remote ? 'remote' : 'local'} radio', (
          tester,
        ) async {
          await _pumpScreen(
            tester,
            _preset(
              Config_LoRaConfig_RegionCode.ANZ,
              Config_LoRaConfig_ModemPreset.LONG_FAST,
            )..femLnaMode = mode,
            remote: remote,
          );
          final tile = find.ancestor(
            of: find.text(_l10n.radioConfigFemLna),
            matching: find.byType(SettingsTile),
          );
          final toggle = find.descendant(
            of: tile,
            matching: find.byType(ThemedSwitch),
          );
          final control = tester.widget<ThemedSwitch>(toggle);
          expect(control.value, mode == Config_LoRaConfig_FEM_LNA_Mode.ENABLED);
          if (mode == Config_LoRaConfig_FEM_LNA_Mode.NOT_PRESENT) {
            expect(control.onChanged, isNull);
            expect(
              find.text(_l10n.radioConfigFemLnaNotPresent),
              findsOneWidget,
            );
          } else {
            expect(control.onChanged, isNotNull);
            await tester.tap(toggle);
            await tester.pump();
            expect(tester.widget<ThemedSwitch>(toggle).value, !control.value);
          }
          expect(tester.takeException(), isNull);
        });
      }

      for (final firmware in [
        null,
        '2.7.19',
        '2.7.20.abc123',
        '2.8.0-beta.1',
      ]) {
        testWidgets('omitted zero mode on $firmware, remote=$remote', (
          tester,
        ) async {
          final config = config_pb.Config_LoRaConfig.fromBuffer(
            (_preset(
              Config_LoRaConfig_RegionCode.ANZ,
              Config_LoRaConfig_ModemPreset.LONG_FAST,
            )).writeToBuffer(),
          );
          expect(config.hasFemLnaMode(), isFalse);
          await _pumpScreen(tester, config, firmware: firmware, remote: remote);
          final toggle = find.descendant(
            of: find.ancestor(
              of: find.text(_l10n.radioConfigFemLna),
              matching: find.byType(SettingsTile),
            ),
            matching: find.byType(ThemedSwitch),
          );
          final supported = firmware != null && firmware != '2.7.19';
          expect(tester.widget<ThemedSwitch>(toggle).value, isFalse);
          expect(
            tester.widget<ThemedSwitch>(toggle).onChanged != null,
            supported,
          );
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('US sub-500 kHz notice', () {
    testWidgets('shows for US on Long Fast', (tester) async {
      await _pumpScreen(
        tester,
        _preset(
          Config_LoRaConfig_RegionCode.US,
          Config_LoRaConfig_ModemPreset.LONG_FAST,
        ),
      );
      expect(_noticeTitle, findsOneWidget);
      expect(_noticeBody, findsOneWidget);
    });

    testWidgets('shows for US on a custom bandwidth below 500 kHz', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        config_pb.Config_LoRaConfig()
          ..region = Config_LoRaConfig_RegionCode.US
          ..usePreset = false
          ..bandwidth = 125,
      );
      expect(_noticeTitle, findsOneWidget);
    });

    testWidgets('hidden for US on Long Turbo', (tester) async {
      await _pumpScreen(
        tester,
        _preset(
          Config_LoRaConfig_RegionCode.US,
          Config_LoRaConfig_ModemPreset.LONG_TURBO,
        ),
      );
      expect(_noticeTitle, findsNothing);
    });

    testWidgets('hidden for other regions on Long Fast', (tester) async {
      await _pumpScreen(
        tester,
        _preset(
          Config_LoRaConfig_RegionCode.EU_868,
          Config_LoRaConfig_ModemPreset.LONG_FAST,
        ),
      );
      expect(_noticeTitle, findsNothing);
    });

    testWidgets('appears and clears as the user picks presets', (tester) async {
      await _pumpScreen(
        tester,
        _preset(
          Config_LoRaConfig_RegionCode.US,
          Config_LoRaConfig_ModemPreset.LONG_TURBO,
        ),
      );
      expect(_noticeTitle, findsNothing);

      await tester.tap(find.text(_l10n.radioConfigPresetLongFast));
      await tester.pump();
      expect(_noticeTitle, findsOneWidget);

      await tester.tap(find.text(_l10n.radioConfigPresetLongTurbo));
      await tester.pump();
      expect(_noticeTitle, findsNothing);
    });
  });

  group('regulatory copy', () {
    test('notice states the rule without categorical claims', () {
      final body = _l10n.radioConfigUsBandwidthNoticeBody(
        _l10n.radioConfigPresetLongTurbo,
      );
      expect(body, contains('Part 15.247'));
      expect(body, contains('500 kHz'));
      expect(body, contains('Long Turbo'));
      expect(body, contains('new US nodes'));
      expect(_categorical.hasMatch(body), isFalse, reason: body);
      expect(
        _categorical.hasMatch(_l10n.radioConfigUsBandwidthNoticeTitle),
        isFalse,
      );
    });

    test('help pages describe the 500 kHz rule without categorical claims', () {
      for (final path in [
        'assets/help/safety/radio-regulations.md',
        'assets/help/device/radio-parameters.md',
      ]) {
        final text = File(path).readAsStringSync();
        expect(_categorical.hasMatch(text), isFalse, reason: path);
      }
      final regs = File('assets/help/safety/radio-regulations.md')
          .readAsStringSync();
      expect(regs, contains('Part 15.247'));
      expect(regs, contains('Long Turbo (500 kHz)'));
      expect(regs, isNot(contains('must use spread spectrum')));
      expect(regs, isNot(contains('automatically applies the correct')));
    });
  });
}
