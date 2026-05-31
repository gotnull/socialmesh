// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Regression tests for the remote-admin LoRa re-enable bug.
///
/// Disabling TX on a remote node makes it stop transmitting, so it can no
/// longer answer a fresh getConfig. Without read-modify-write against a cached
/// base, re-saving (e.g. to re-enable TX) would clobber region / preset /
/// advanced fields and brick remote access. These tests verify:
/// - a remote LoRa config response populates the per-node cache,
/// - setLoRaConfig to a remote target clones that cache (preserving fields the
///   UI does not expose),
/// - the from-scratch fallback still works with no cache,
/// - a remote setLoRaConfig refreshes the per-node cache.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _CapturingTransport implements DeviceTransport {
  final List<List<int>> sentBytes = [];

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  bool get isConnected => true;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

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
  Future<void> send(List<int> data) async {
    sentBytes.add(data);
  }

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Future<void> dispose() async {}

  config_pb.Config_LoRaConfig get lastSentLora {
    final toRadio = pb.ToRadio.fromBuffer(sentBytes.last);
    final adminMsg = admin.AdminMessage.fromBuffer(
      toRadio.packet.decoded.payload,
    );
    return adminMsg.setConfig.lora;
  }

  void clear() => sentBytes.clear();
}

const _myNodeNum = 0xAABBCCDD;
const _remoteNodeNum = 0x12345678;

Future<void> _primeNodeNum(ProtocolService protocol) async {
  final fromRadio = pb.FromRadio()
    ..myInfo = (pb.MyNodeInfo()..myNodeNum = _myNodeNum);
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

/// Inject a LoRa GetConfigResponse as if it came from [fromNodeNum].
Future<void> _injectLoraResponse(
  ProtocolService protocol,
  int fromNodeNum,
  config_pb.Config_LoRaConfig lora,
) async {
  final adminMsg = admin.AdminMessage()
    ..getConfigResponse = (config_pb.Config()..lora = lora);
  final data = pb.Data()
    ..portnum = pn.PortNum.ADMIN_APP
    ..payload = adminMsg.writeToBuffer();
  final packet = pb.MeshPacket()
    ..from = fromNodeNum
    ..to = _myNodeNum
    ..decoded = data
    ..id = 4242;
  final fromRadio = pb.FromRadio()..packet = packet;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

void main() {
  late _CapturingTransport transport;
  late ProtocolService protocol;

  setUp(() async {
    transport = _CapturingTransport();
    protocol = ProtocolService(transport);
    await _primeNodeNum(protocol);
    protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
  });

  tearDown(() {
    protocol.dispose();
  });

  group('setLoRaConfig read-modify-write (remote admin)', () {
    test('remote LoRa response populates the per-node cache', () async {
      await _injectLoraResponse(
        protocol,
        _remoteNodeNum,
        config_pb.Config_LoRaConfig()
          ..region = config_pbenum.Config_LoRaConfig_RegionCode.EU_868
          ..paFanDisabled = true,
      );

      final cached = protocol.remoteLoraConfig(_remoteNodeNum);
      expect(cached, isNotNull);
      expect(cached!.region, config_pbenum.Config_LoRaConfig_RegionCode.EU_868);
      expect(cached.paFanDisabled, isTrue);
      // Remote response must NOT pollute the local cache.
      expect(protocol.currentLoraConfig, isNull);
    });

    test('remote save preserves fields the UI does not expose', () async {
      // Node reported its config while TX was still on.
      await _injectLoraResponse(
        protocol,
        _remoteNodeNum,
        config_pb.Config_LoRaConfig()
          ..region = config_pbenum.Config_LoRaConfig_RegionCode.EU_868
          ..modemPreset =
              config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE
          ..channelNum = 5
          // Not exposed by setLoRaConfig — must survive the save.
          ..paFanDisabled = true
          ..txEnabled = false,
      );

      transport.clear();
      // Re-enable TX, passing back the repopulated form values.
      await protocol.setLoRaConfig(
        region: config_pbenum.Config_LoRaConfig_RegionCode.EU_868,
        modemPreset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE,
        hopLimit: 3,
        txEnabled: true,
        txPower: 0,
        channelNum: 5,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final sent = transport.lastSentLora;
      expect(sent.paFanDisabled, isTrue, reason: 'unexposed field preserved');
      expect(sent.region, config_pbenum.Config_LoRaConfig_RegionCode.EU_868);
      expect(
        sent.modemPreset,
        config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE,
      );
      expect(sent.txEnabled, isTrue, reason: 're-enable applied on top');
    });

    test('remote save without a cached base builds from scratch', () async {
      await protocol.setLoRaConfig(
        region: config_pbenum.Config_LoRaConfig_RegionCode.US,
        modemPreset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
        hopLimit: 3,
        txEnabled: true,
        txPower: 0,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final sent = transport.lastSentLora;
      expect(sent.paFanDisabled, isFalse);
      expect(sent.region, config_pbenum.Config_LoRaConfig_RegionCode.US);
      expect(sent.txEnabled, isTrue);
    });

    test('remote setLoRaConfig refreshes the per-node cache', () async {
      await _injectLoraResponse(
        protocol,
        _remoteNodeNum,
        config_pb.Config_LoRaConfig()
          ..region = config_pbenum.Config_LoRaConfig_RegionCode.EU_868
          ..txEnabled = true,
      );

      await protocol.setLoRaConfig(
        region: config_pbenum.Config_LoRaConfig_RegionCode.EU_868,
        modemPreset: config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST,
        hopLimit: 3,
        txEnabled: false,
        txPower: 0,
        target: const AdminTarget.remote(_remoteNodeNum),
      );

      final cached = protocol.remoteLoraConfig(_remoteNodeNum);
      expect(cached, isNotNull);
      expect(cached!.txEnabled, isFalse, reason: 'cache reflects last sent');
    });
  });
}
