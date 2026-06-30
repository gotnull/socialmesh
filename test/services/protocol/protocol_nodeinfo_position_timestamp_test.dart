// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression: a position carried by a NodeInfo (the radio's NodeDB dump on
// reconnect / app launch) must inherit the node's heard-time, never the local
// wall clock. The firmware emits NodeInfo for every known node on sync, and
// that NodeInfo's embedded Position typically has no GPS/phone time. Before
// the fix, _handleNodeInfo left MeshNode.positionTimestamp null, and the
// telemetry logger then stamped the position-log row with DateTime.now() -
// making a node last heard weeks ago appear in "today / yesterday".

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

// Stafford-ish UK coordinates, deliberately not the Apple Park sentinel that
// _handleNodeInfo filters out.
const int _latI = 527900000;
const int _lngI = -21100000;

pb.FromRadio _nodeInfo({
  required int nodeNum,
  DateTime? lastHeard,
  int positionTimeEpoch = 0,
}) {
  final position = pb.Position(latitudeI: _latI, longitudeI: _lngI);
  if (positionTimeEpoch > 0) {
    position.time = positionTimeEpoch;
  }
  final info = pb.NodeInfo(
    num: nodeNum,
    position: position,
    user: pb.User()
      ..longName = 'Stafford-Butterhill2'
      ..shortName = 'SB2',
  );
  if (lastHeard != null) {
    info.lastHeard = lastHeard.millisecondsSinceEpoch ~/ 1000;
  }
  return pb.FromRadio(nodeInfo: info);
}

void main() {
  const nodeNum = 0x8AB89EC;

  // Construct in local time: the protocol layer reconstructs timestamps via
  // DateTime.fromMillisecondsSinceEpoch, which returns local. Whole-minute
  // values round-trip exactly through the seconds-resolution wire field.
  final heardWeeksAgo = DateTime(2026, 6, 13, 9, 12);

  test('NodeInfo position with no embedded time inherits the heard-time, '
      'never now', () async {
    final protocol = ProtocolService(_FakeTransport());

    await _deliver(
      protocol,
      _nodeInfo(nodeNum: nodeNum, lastHeard: heardWeeksAgo),
    );

    final node = protocol.nodes[nodeNum];
    expect(node, isNotNull);
    expect(
      node!.positionTimestamp,
      heardWeeksAgo,
      reason:
          'A NodeDB-dump position with zeroed GPS/phone time must inherit the '
          "node's lastHeard, not be stamped with the local wall clock.",
    );
    // And it must stay consistent with Last Heard.
    expect(node.positionTimestamp, node.lastHeard);

    await protocol.dispose();
  });

  test('NodeInfo position with a valid embedded time uses that time', () async {
    final protocol = ProtocolService(_FakeTransport());

    // 2026-06-29 10:00 UTC — a real (if older) GPS/phone time on the fix.
    const embeddedEpoch = 1782554400;
    await _deliver(
      protocol,
      _nodeInfo(
        nodeNum: nodeNum,
        lastHeard: heardWeeksAgo,
        positionTimeEpoch: embeddedEpoch,
      ),
    );

    final node = protocol.nodes[nodeNum];
    expect(node, isNotNull);
    expect(
      node!.positionTimestamp,
      DateTime.fromMillisecondsSinceEpoch(embeddedEpoch * 1000),
      reason:
          'An embedded position time must win over the heard-time fallback.',
    );

    await protocol.dispose();
  });

  test('NodeInfo position with no heard-time at all sinks to the '
      'plausible-epoch sentinel, never now', () async {
    final protocol = ProtocolService(_FakeTransport());

    // No lastHeard on the NodeInfo and no prior node -> no heard-time to
    // inherit. The fallback must be the 2020-01-01 sentinel so a clock-less
    // fix cannot masquerade as fresh.
    await _deliver(protocol, _nodeInfo(nodeNum: nodeNum));

    final node = protocol.nodes[nodeNum];
    expect(node, isNotNull);
    expect(
      node!.positionTimestamp,
      ProtocolService.debugChronologicalFallbackSentinel,
      reason:
          'With no heard-time, the position must sink to the plausible-epoch '
          'sentinel rather than DateTime.now().',
    );

    await protocol.dispose();
  });
}
