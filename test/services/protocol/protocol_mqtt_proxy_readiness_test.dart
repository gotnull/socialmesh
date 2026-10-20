// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

// Broker downlinks relayed by the MQTT client proxy are best-effort live
// traffic. Sending them while the config handshake is still running starves
// the handshake on BLE, so the radio never reaches ready. They are dropped
// until readiness is `ready`.

const int _myNodeNum = 0xa6960864;

class _RecordingTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
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
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;
  @override
  Stream<List<int>> get dataStream => _dataController.stream;
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();
  @override
  Future<void> connect(DeviceInfo device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> enableNotifications() async {}
  @override
  Future<void> pollOnce() async {}
  @override
  Future<void> send(List<int> data) async {
    sentBytes.add(List<int>.from(data));
  }

  @override
  Future<int?> readRssi() async => null;
  @override
  Future<void> dispose() async {
    await _dataController.close();
    await _stateController.close();
  }
}

int _proxyFrames(_RecordingTransport transport) => transport.sentBytes
    .map(pb.ToRadio.fromBuffer)
    .where((frame) => frame.hasMqttClientProxyMessage())
    .length;

pb.MqttClientProxyMessage _downlink() => pb.MqttClientProxyMessage()
  ..topic = 'msh/2/e/LongFast/!deadbeef'
  ..data = [1, 2, 3];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('broker downlinks are dropped until the handshake is ready', () async {
    final tempDir = await Directory.systemTemp.createTemp('mqtt_proxy_ready');
    addTearDown(() => tempDir.delete(recursive: true));
    final dedupeStore = MeshPacketDedupeStore(
      dbPathOverride: p.join(tempDir.path, 'dedupe.db'),
    );
    await dedupeStore.init();
    final transport = _RecordingTransport();
    final protocol = ProtocolService(transport, dedupeStore: dedupeStore);
    await protocol.handleIncomingPacket(
      (pb.FromRadio()..myInfo = (pb.MyNodeInfo()..myNodeNum = _myNodeNum))
          .writeToBuffer(),
    );

    for (final state in [
      OperationalReadiness.linkConnected,
      OperationalReadiness.handshakePhase1,
      OperationalReadiness.handshakePhase2,
    ]) {
      protocol.debugForceReadinessForTesting(state);
      await protocol.sendMqttClientProxyMessage(_downlink());
      expect(_proxyFrames(transport), 0, reason: 'relayed during $state');
    }

    protocol.debugForceReadinessForTesting(OperationalReadiness.ready);
    await protocol.sendMqttClientProxyMessage(_downlink());
    expect(_proxyFrames(transport), 1);
  });
}
