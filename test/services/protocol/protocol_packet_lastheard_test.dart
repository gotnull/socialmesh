// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression tests for the NodeDex reconnect-replay bug where buffered
// MeshPackets and NodeInfo records replayed during phone reconnect were
// stamping `node.lastHeard = DateTime.now()`, falsely marking 30-minute-
// old nodes as "just heard" and inflating NodeDex encounter statistics.
//
// Authoritative timestamp source per Meshtastic-iOS parity:
//   - NodeInfo records use `nodeInfo.lastHeard` (uint32 seconds, set by
//     the device when it last received a packet from the node).
//   - MeshPackets use `packet.rxTime` (uint32 seconds, set by firmware on
//     receive before delivery to the phone over BLE).
// `DateTime.now()` is used only as a fallback when the device lacks a
// time source (rxTime == 0 or implausible drift).

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

List<int> _buildNodeInfoFromRadio({
  required int nodeNum,
  required int lastHeardEpochSeconds,
  String longName = 'Test',
  String shortName = 'tst',
}) {
  final nodeInfo = pb.NodeInfo(
    num: nodeNum,
    lastHeard: lastHeardEpochSeconds,
    user: pb.User()
      ..longName = longName
      ..shortName = shortName,
  );
  return pb.FromRadio(nodeInfo: nodeInfo).writeToBuffer();
}

List<int> _buildPositionPacket({
  required int from,
  required int rxTimeEpochSeconds,
  required int latitudeI,
  required int longitudeI,
  int packetId = 1,
}) {
  final position = pb.Position(latitudeI: latitudeI, longitudeI: longitudeI);
  final packet = pb.MeshPacket(
    from: from,
    to: 0xFFFFFFFF,
    id: packetId,
    decoded: pb.Data(
      portnum: pn.PortNum.POSITION_APP,
      payload: position.writeToBuffer(),
    ),
  );
  if (rxTimeEpochSeconds > 0) {
    packet.rxTime = rxTimeEpochSeconds;
  }
  return pb.FromRadio(id: 1, packet: packet).writeToBuffer();
}

List<int> _buildTextPacket({
  required int from,
  required int rxTimeEpochSeconds,
  String text = 'hi',
  int packetId = 1,
}) {
  final packet = pb.MeshPacket(
    from: from,
    to: 0xFFFFFFFF,
    id: packetId,
    decoded: pb.Data(
      portnum: pn.PortNum.TEXT_MESSAGE_APP,
      payload: List<int>.from(text.codeUnits),
    ),
  );
  if (rxTimeEpochSeconds > 0) {
    packet.rxTime = rxTimeEpochSeconds;
  }
  return pb.FromRadio(id: 1, packet: packet).writeToBuffer();
}

void main() {
  group('NodeInfo replay uses nodeInfo.lastHeard, not DateTime.now()', () {
    test(
      '30-minute-old NodeInfo preserves the device-reported timestamp',
      () async {
        final protocol = ProtocolService(_FakeTransport());
        addTearDown(protocol.dispose);

        final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final thirtyMinutesAgoEpoch = nowEpoch - (30 * 60);

        await protocol.handleIncomingPacket(
          _buildNodeInfoFromRadio(
            nodeNum: 0xABCD,
            lastHeardEpochSeconds: thirtyMinutesAgoEpoch,
          ),
        );

        final node = protocol.nodes[0xABCD];
        expect(node, isNotNull);
        expect(
          node!.lastHeard?.millisecondsSinceEpoch,
          thirtyMinutesAgoEpoch * 1000,
          reason: 'Stale NodeInfo must surface the firmware lastHeard, not now',
        );

        final ageSeconds = DateTime.now().difference(node.lastHeard!).inSeconds;
        expect(
          ageSeconds,
          greaterThanOrEqualTo(30 * 60 - 5),
          reason: 'Reconstructed lastHeard must reflect ~30-minute age',
        );
      },
    );

    test(
      'NodeInfo without lastHeard preserves prior value (no fabricated now)',
      () async {
        final protocol = ProtocolService(_FakeTransport());
        addTearDown(protocol.dispose);

        // Seed with a known stale lastHeard.
        final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final oneHourAgoEpoch = nowEpoch - (60 * 60);
        await protocol.handleIncomingPacket(
          _buildNodeInfoFromRadio(
            nodeNum: 0xBEEF,
            lastHeardEpochSeconds: oneHourAgoEpoch,
          ),
        );
        final priorLastHeard = protocol.nodes[0xBEEF]?.lastHeard;
        expect(priorLastHeard, isNotNull);

        // Second NodeInfo without lastHeard set (e.g. firmware that has the
        // node in its NodeDB but never received a packet from it).
        await protocol.handleIncomingPacket(
          _buildNodeInfoFromRadio(
            nodeNum: 0xBEEF,
            lastHeardEpochSeconds: 0,
            longName: 'UpdatedName',
          ),
        );

        final node = protocol.nodes[0xBEEF];
        expect(node?.longName, 'UpdatedName');
        expect(
          node?.lastHeard,
          priorLastHeard,
          reason:
              'Missing nodeInfo.lastHeard must not overwrite prior lastHeard with now',
        );
      },
    );
  });

  group('MeshPacket replay uses packet.rxTime, not DateTime.now()', () {
    test('Stale rxTime sets node.lastHeard to that exact moment', () async {
      final protocol = ProtocolService(_FakeTransport());
      addTearDown(protocol.dispose);

      // Seed the node first so the packet handler updates an existing
      // node rather than creating a placeholder.
      final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final twoHoursAgoEpoch = nowEpoch - (2 * 60 * 60);
      await protocol.handleIncomingPacket(
        _buildNodeInfoFromRadio(
          nodeNum: 0xCAFE,
          lastHeardEpochSeconds: twoHoursAgoEpoch,
        ),
      );

      // Now feed a buffered position packet whose rxTime says it was
      // received 30 minutes ago — this is the reconnect-replay scenario.
      final thirtyMinutesAgoEpoch = nowEpoch - (30 * 60);
      await protocol.handleIncomingPacket(
        _buildPositionPacket(
          from: 0xCAFE,
          rxTimeEpochSeconds: thirtyMinutesAgoEpoch,
          latitudeI: 374000000,
          longitudeI: -1220000000,
          packetId: 42,
        ),
      );

      final node = protocol.nodes[0xCAFE];
      expect(node, isNotNull);
      // Position update advances lastHeard from -2h to -30m (monotonic
      // forward), but it must be -30m and NOT now.
      expect(
        node!.lastHeard?.millisecondsSinceEpoch,
        thirtyMinutesAgoEpoch * 1000,
        reason: 'Buffered packet must keep its rxTime, not get stamped as now',
      );

      final ageSeconds = DateTime.now().difference(node.lastHeard!).inSeconds;
      expect(
        ageSeconds,
        greaterThanOrEqualTo(30 * 60 - 5),
        reason: 'Replay packet age must reflect ~30-minute rxTime',
      );
    });

    test(
      'Monotonic guard: older rxTime does not move stored lastHeard backwards',
      () async {
        final protocol = ProtocolService(_FakeTransport());
        addTearDown(protocol.dispose);

        // Seed with a 5-minute-old NodeInfo lastHeard.
        final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final fiveMinutesAgoEpoch = nowEpoch - (5 * 60);
        await protocol.handleIncomingPacket(
          _buildNodeInfoFromRadio(
            nodeNum: 0x1234,
            lastHeardEpochSeconds: fiveMinutesAgoEpoch,
          ),
        );
        final initialLastHeard = protocol.nodes[0x1234]?.lastHeard;
        expect(initialLastHeard, isNotNull);

        // Feed a MUCH older buffered text packet (1 hour ago).
        final oneHourAgoEpoch = nowEpoch - (60 * 60);
        await protocol.handleIncomingPacket(
          _buildTextPacket(
            from: 0x1234,
            rxTimeEpochSeconds: oneHourAgoEpoch,
            packetId: 99,
          ),
        );

        // Monotonic guard must keep the newer 5-minute-old timestamp;
        // a stale 1-hour-old packet should never rewind the node's age.
        final node = protocol.nodes[0x1234];
        expect(
          node?.lastHeard,
          initialLastHeard,
          reason:
              'Monotonic guard must reject older rxTime and preserve the newer stored value',
        );
      },
    );

    test('Missing rxTime falls back to now (live packet, no clock)', () async {
      final protocol = ProtocolService(_FakeTransport());
      addTearDown(protocol.dispose);

      final beforeIngest = DateTime.now();
      await protocol.handleIncomingPacket(
        _buildPositionPacket(
          from: 0x9999,
          rxTimeEpochSeconds: 0, // No clock on device
          latitudeI: 374000000,
          longitudeI: -1220000000,
          packetId: 7,
        ),
      );
      final afterIngest = DateTime.now();

      final node = protocol.nodes[0x9999];
      expect(node, isNotNull);
      expect(node!.lastHeard, isNotNull);
      // With no firmware clock the only safe fallback is local time.
      expect(
        node.lastHeard!.isAfter(
          beforeIngest.subtract(const Duration(seconds: 1)),
        ),
        isTrue,
      );
      expect(
        node.lastHeard!.isBefore(afterIngest.add(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
