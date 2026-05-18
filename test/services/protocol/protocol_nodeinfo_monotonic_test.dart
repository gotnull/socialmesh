// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression: a NodeInfo carrying an older `lastHeard` than what we
// already know must not rewind MeshNode.lastHeard. The firmware emits
// NodeInfo from its NodeDB on sync, and that stored value can be
// older than a fresh packet we just received. Without the monotonic
// guard inside _handleNodeInfo, NodeDex's entry.lastSeen (set at
// discovery from node.firstHeard/lastHeard) ends up newer than
// node.lastHeard, breaking the "encounter <= heard" invariant.

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
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

Future<void> _deliver(ProtocolService protocol, pb.FromRadio fromRadio) async {
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

pb.FromRadio _nodeInfoAt({required int nodeNum, required DateTime lastHeard}) {
  return pb.FromRadio(
    nodeInfo: pb.NodeInfo(
      num: nodeNum,
      lastHeard: lastHeard.millisecondsSinceEpoch ~/ 1000,
      user: pb.User()
        ..longName = 'Andre Heyer - Brake'
        ..shortName = 'AH',
    ),
  );
}

void main() {
  const nodeNum = 0xBA9B8863;
  // Pin both timestamps well after _minPlausibleEpoch (2020-01-01) and
  // before "now" so the plausibility branch is taken. Use local time
  // (not utc) because the protocol layer reconstructs via
  // DateTime.fromMillisecondsSinceEpoch, which returns local.
  final fresh = DateTime(2026, 5, 18, 7, 44);
  final stale = DateTime(2026, 5, 18, 5, 5);

  test('NodeInfo with stale lastHeard cannot rewind a fresher value', () async {
    final protocol = ProtocolService(_FakeTransport());

    // Seed: a NodeInfo establishes the node with lastHeard at the
    // fresh time (analogous to a live packet that arrived and was
    // captured into the NodeDB).
    await _deliver(protocol, _nodeInfoAt(nodeNum: nodeNum, lastHeard: fresh));
    expect(protocol.nodes[nodeNum]?.lastHeard, fresh);

    // Replay: a second NodeInfo arrives carrying an OLDER lastHeard
    // (the firmware's NodeDB still has its old stored value). The
    // monotonic guard must keep the fresh value.
    await _deliver(protocol, _nodeInfoAt(nodeNum: nodeNum, lastHeard: stale));
    expect(
      protocol.nodes[nodeNum]?.lastHeard,
      fresh,
      reason:
          'NodeInfo with lastHeard=$stale must not rewind existing '
          'lastHeard=$fresh',
    );

    await protocol.dispose();
  });

  test('NodeInfo with newer lastHeard advances the existing value', () async {
    final protocol = ProtocolService(_FakeTransport());

    await _deliver(protocol, _nodeInfoAt(nodeNum: nodeNum, lastHeard: stale));
    expect(protocol.nodes[nodeNum]?.lastHeard, stale);

    await _deliver(protocol, _nodeInfoAt(nodeNum: nodeNum, lastHeard: fresh));
    expect(protocol.nodes[nodeNum]?.lastHeard, fresh);

    await protocol.dispose();
  });
}
