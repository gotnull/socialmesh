// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/core/widgets/settings_primitives.dart';
import 'package:socialmesh/features/settings/mesh_beacon_config_screen.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/module_config.pb.dart'
    as module_pb;
import 'package:socialmesh/generated/meshtastic/module_config.pbenum.dart'
    as module_pbenum;
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

final _l10n = AppLocalizationsEn();

class _FakeProtocolService extends ProtocolService {
  _FakeProtocolService({this.cachedConfig, this.beacons = const []})
    : super(_FakeTransport());

  module_pb.ModuleConfig_MeshBeaconConfig? cachedConfig;
  final List<MeshBeaconEvent> beacons;
  final StreamController<module_pb.ModuleConfig_MeshBeaconConfig> _configCtrl =
      StreamController<module_pb.ModuleConfig_MeshBeaconConfig>.broadcast();
  final StreamController<MeshBeaconEvent> _beaconCtrl =
      StreamController<MeshBeaconEvent>.broadcast();

  @override
  module_pb.ModuleConfig_MeshBeaconConfig? get currentMeshBeaconConfig =>
      cachedConfig;

  @override
  Stream<module_pb.ModuleConfig_MeshBeaconConfig> get meshBeaconConfigStream =>
      _configCtrl.stream;

  @override
  List<MeshBeaconEvent> get recentMeshBeacons => beacons;

  @override
  Stream<MeshBeaconEvent> get meshBeaconEventStream => _beaconCtrl.stream;

  @override
  bool get isConnected => false; // skip the get-config-from-device branch

  @override
  Future<void> getModuleConfig(
    admin.AdminMessage_ModuleConfigType moduleType, {
    AdminTarget? target,
  }) async {}

  Future<void> closeStreams() async {
    await _configCtrl.close();
    await _beaconCtrl.close();
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
  _FakeProtocolService protocol,
) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(protocol.closeStreams);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [protocolServiceProvider.overrideWithValue(protocol)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: const MeshBeaconConfigScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

ChannelConfig _channel(
  int index, {
  String role = 'SECONDARY',
  List<int>? psk,
}) => ChannelConfig(
  index: index,
  name: 'ch$index',
  psk: psk ?? [index],
  role: role,
);

void main() {
  group('firstFreeChannelIndex', () {
    test('empty channel list yields slot 1', () {
      expect(firstFreeChannelIndex(const []), 1);
    });

    test('skips the primary slot even when it is the only channel', () {
      expect(firstFreeChannelIndex([_channel(0, role: 'PRIMARY')]), 1);
    });

    test('returns the first gap in the slot sequence', () {
      final channels = [_channel(0, role: 'PRIMARY'), _channel(1), _channel(3)];
      expect(firstFreeChannelIndex(channels), 2);
    });

    test('treats a disabled slot as free', () {
      final channels = [
        _channel(0, role: 'PRIMARY'),
        _channel(1),
        _channel(2, role: 'disabled'),
        _channel(3),
      ];
      expect(firstFreeChannelIndex(channels), 2);
    });

    test('returns null when every slot 1..7 is active', () {
      final channels = [
        _channel(0, role: 'PRIMARY'),
        for (var i = 1; i <= kMeshBeaconMaxChannelIndex; i++) _channel(i),
      ];
      expect(firstFreeChannelIndex(channels), isNull);
    });
  });

  group('channelWithPsk', () {
    test('matches on key bytes and ignores the name', () {
      final channels = [
        _channel(0, role: 'PRIMARY', psk: [1]),
        _channel(1, psk: [10, 20, 30]),
      ];
      final match = channelWithPsk(channels, [10, 20, 30]);
      expect(match?.index, 1);
    });

    test('ignores disabled channels', () {
      final channels = [
        _channel(2, role: 'DISABLED', psk: [7, 7]),
      ];
      expect(channelWithPsk(channels, [7, 7]), isNull);
    });

    test('requires identical length', () {
      final channels = [
        _channel(1, psk: [1, 2, 3]),
      ];
      expect(channelWithPsk(channels, [1, 2]), isNull);
      expect(channelWithPsk(channels, [1, 2, 3, 4]), isNull);
    });

    test('returns null when nothing matches', () {
      expect(
        channelWithPsk(
          [
            _channel(1, psk: [1]),
          ],
          [2],
        ),
        isNull,
      );
    });
  });

  group('MeshBeaconConfigScreen layout', () {
    testWidgets('broadcast off: listen, broadcast and an empty inbox', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        _FakeProtocolService(
          cachedConfig: module_pb.ModuleConfig_MeshBeaconConfig(),
        ),
      );

      expect(find.byType(SettingsSectionHeader), findsNWidgets(3));
      expect(find.text(_l10n.meshBeaconSectionOffer), findsNothing);
      expect(find.byType(SettingsTile), findsNWidgets(2));
      expect(
        find.ancestor(
          of: find.text(_l10n.meshBeaconReceivedEmpty),
          matching: find.byType(FieldGroupCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('broadcast on: offer rows, broadcast card and beacon cards', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        _FakeProtocolService(
          cachedConfig: module_pb.ModuleConfig_MeshBeaconConfig()
            ..flags = module_pbenum
                .ModuleConfig_MeshBeaconConfig_Flags
                .FLAG_BROADCAST_ENABLED
                .value,
          beacons: [
            MeshBeaconEvent(
              senderNodeId: 0x00aa0011,
              message: 'Club net Sundays',
              receivedAt: DateTime(2026, 10, 17, 21),
            ),
          ],
        ),
      );

      expect(find.byType(SettingsSectionHeader), findsNWidgets(4));
      // Listen, broadcast, legacy split, and the three offer rows.
      expect(find.byType(SettingsTile), findsNWidgets(6));
      expect(find.text(_l10n.meshBeaconLegacySplit), findsOneWidget);
      // The message and interval card, plus one card per received beacon.
      expect(find.byType(FieldGroupCard), findsNWidgets(2));
      expect(find.text('Club net Sundays'), findsOneWidget);
      expect(find.text(_l10n.meshBeaconReceivedEmpty), findsNothing);
    });
  });
}
