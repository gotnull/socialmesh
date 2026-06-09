// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression tests for the "relayed node shows the next hop's signal" bug.
// rxRssi/rxSnr (and the firmware's NodeInfo.snr) describe the link to the
// immediate transmitter, so they may only be attributed to a node on a
// direct (0-hop, non-MQTT) reception. When the latest reception is relayed
// or via MQTT the metrics belong to the next hop, not the source node, and
// must be cleared so the UI shows nothing rather than a meaningless value.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _FakeTransport implements DeviceTransport {
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

  @override
  bool get isConnected => false;

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
  Future<void> send(List<int> data) async {}

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
}

// A valid (non-Apple-Park, non-zero) coordinate so the position handler
// creates/updates the node.
const _latI = 374000000;
const _lngI = -1220000000;

List<int> _buildPositionPacket({
  required int from,
  required int packetId,
  // hopStart > 0 with hopLimit == hopStart => 0 hops (direct).
  // hopStart > hopLimit => relayed.
  required int hopStart,
  required int hopLimit,
  int? rxRssi,
  double? rxSnr,
  bool viaMqtt = false,
  required int rxTimeEpochSeconds,
}) {
  final position = pb.Position(latitudeI: _latI, longitudeI: _lngI);
  final packet = pb.MeshPacket(
    from: from,
    to: 0xFFFFFFFF,
    id: packetId,
    hopStart: hopStart,
    hopLimit: hopLimit,
    decoded: pb.Data(
      portnum: pn.PortNum.POSITION_APP,
      payload: position.writeToBuffer(),
    ),
  );
  if (rxRssi != null) packet.rxRssi = rxRssi;
  if (rxSnr != null) packet.rxSnr = rxSnr;
  if (viaMqtt) packet.viaMqtt = true;
  if (rxTimeEpochSeconds > 0) packet.rxTime = rxTimeEpochSeconds;
  return pb.FromRadio(packet: packet).writeToBuffer();
}

List<int> _buildNodeInfoFromRadio({
  required int nodeNum,
  required double snr,
  int? hopsAway,
  bool viaMqtt = false,
  required int lastHeardEpochSeconds,
}) {
  final nodeInfo = pb.NodeInfo(
    num: nodeNum,
    lastHeard: lastHeardEpochSeconds,
    snr: snr,
    user: pb.User()
      ..longName = 'Test'
      ..shortName = 'tst',
  );
  if (hopsAway != null) nodeInfo.hopsAway = hopsAway;
  if (viaMqtt) nodeInfo.viaMqtt = true;
  return pb.FromRadio(nodeInfo: nodeInfo).writeToBuffer();
}

void main() {
  group('MeshPacket signal attribution', () {
    test('direct packet (0 hops) stores rssi/snr on the node', () async {
      final protocol = ProtocolService(_FakeTransport());
      addTearDown(protocol.dispose);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await protocol.handleIncomingPacket(
        _buildPositionPacket(
          from: 0xA001,
          packetId: 1,
          hopStart: 3,
          hopLimit: 3, // 0 hops -> direct
          rxRssi: -50,
          rxSnr: 10.0,
          rxTimeEpochSeconds: now,
        ),
      );

      final node = protocol.nodes[0xA001];
      expect(node, isNotNull);
      expect(node!.rssi, -50);
      expect(node.snr, 10);
    });

    test('relayed packet (>0 hops) does not attribute rssi/snr', () async {
      final protocol = ProtocolService(_FakeTransport());
      addTearDown(protocol.dispose);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await protocol.handleIncomingPacket(
        _buildPositionPacket(
          from: 0xA002,
          packetId: 1,
          hopStart: 3,
          hopLimit: 1, // 2 hops -> relayed
          rxRssi: -50,
          rxSnr: 10.0,
          rxTimeEpochSeconds: now,
        ),
      );

      final node = protocol.nodes[0xA002];
      expect(node, isNotNull);
      expect(node!.rssi, isNull);
      expect(node.snr, isNull);
    });

    test('relayed packet clears a prior direct rssi/snr', () async {
      final protocol = ProtocolService(_FakeTransport());
      addTearDown(protocol.dispose);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // 1. Direct reception sets the signal.
      await protocol.handleIncomingPacket(
        _buildPositionPacket(
          from: 0xA003,
          packetId: 1,
          hopStart: 3,
          hopLimit: 3,
          rxRssi: -55,
          rxSnr: 8.0,
          rxTimeEpochSeconds: now,
        ),
      );
      expect(protocol.nodes[0xA003]?.rssi, -55);
      expect(protocol.nodes[0xA003]?.snr, 8);

      // 2. A later relayed reception must clear it (it's the relay's signal).
      await protocol.handleIncomingPacket(
        _buildPositionPacket(
          from: 0xA003,
          packetId: 2,
          hopStart: 3,
          hopLimit: 1,
          rxRssi: -40,
          rxSnr: 12.0,
          rxTimeEpochSeconds: now + 1,
        ),
      );

      final node = protocol.nodes[0xA003];
      expect(node, isNotNull);
      expect(node!.rssi, isNull);
      expect(node.snr, isNull);
    });

    test('MQTT packet (0 hops) does not attribute rssi/snr', () async {
      final protocol = ProtocolService(_FakeTransport());
      addTearDown(protocol.dispose);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await protocol.handleIncomingPacket(
        _buildPositionPacket(
          from: 0xA004,
          packetId: 1,
          hopStart: 3,
          hopLimit: 3, // 0 hops, but...
          rxRssi: -50,
          rxSnr: 10.0,
          viaMqtt: true, // ...arrived via MQTT
          rxTimeEpochSeconds: now,
        ),
      );

      final node = protocol.nodes[0xA004];
      expect(node, isNotNull);
      expect(node!.rssi, isNull);
      expect(node.snr, isNull);
    });
  });

  group('NodeInfo.snr attribution', () {
    test('direct NodeInfo (hops_away absent => 0) stores snr', () async {
      final protocol = ProtocolService(_FakeTransport());
      addTearDown(protocol.dispose);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await protocol.handleIncomingPacket(
        _buildNodeInfoFromRadio(
          nodeNum: 0xB001,
          snr: 12.5,
          // hops_away omitted -> proto3 default 0 -> direct
          lastHeardEpochSeconds: now,
        ),
      );

      final node = protocol.nodes[0xB001];
      expect(node, isNotNull);
      expect(node!.snr, 12);
    });

    test('relayed NodeInfo (hops_away > 0) does not store snr', () async {
      final protocol = ProtocolService(_FakeTransport());
      addTearDown(protocol.dispose);

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await protocol.handleIncomingPacket(
        _buildNodeInfoFromRadio(
          nodeNum: 0xB002,
          snr: 12.5,
          hopsAway: 3,
          lastHeardEpochSeconds: now,
        ),
      );

      final node = protocol.nodes[0xB002];
      expect(node, isNotNull);
      expect(node!.snr, isNull);
    });
  });
}
