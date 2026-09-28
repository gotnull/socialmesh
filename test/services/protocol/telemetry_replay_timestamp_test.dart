// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The radio buffers packets it hears while no phone is attached and
// replays them on connect with their original rxTime. Every telemetry
// variant must stamp the node's metricsTimestamp from that rxTime so the
// history loggers file the sample at its true time, never at the moment
// the phone reconnected.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/generated/meshtastic/telemetry.pb.dart' as telemetry;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _SilentFakeTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.network;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode =>
      TransportReconnectMode.directEndpoint;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  bool get isConnected => true;

  @override
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();

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
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _dataController.close();
  }
}

const _myNodeNum = 0xA6960864;
const _peerNodeNum = 0x1234ABCD;
var _packetId = 500;

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('telemetry_replay');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<ProtocolService> _freshProtocol(
  String dir,
  _SilentFakeTransport transport,
) async {
  final dedupeStore = MeshPacketDedupeStore(
    dbPathOverride: p.join(
      dir,
      'dedupe_store_${DateTime.now().microsecondsSinceEpoch}.db',
    ),
  );
  await dedupeStore.init();
  final protocol = ProtocolService(transport, dedupeStore: dedupeStore);

  await protocol.handleIncomingPacket(
    pb.FromRadio(myInfo: pb.MyNodeInfo(myNodeNum: _myNodeNum)).writeToBuffer(),
  );
  // Seed the peer so telemetry handlers (which only update known nodes)
  // have an entry to update.
  await protocol.handleIncomingPacket(
    pb.FromRadio(
      nodeInfo: pb.NodeInfo(
        num: _peerNodeNum,
        user: pb.User(id: '!1234abcd', longName: 'Peer', shortName: 'PEER'),
      ),
    ).writeToBuffer(),
  );
  return protocol;
}

Future<MeshNode> _ingestTelemetry(
  ProtocolService protocol,
  telemetry.Telemetry telem, {
  int? rxTime,
}) async {
  final updates = <MeshNode>[];
  final sub = protocol.nodeStream.listen((node) {
    if (node.nodeNum == _peerNodeNum) updates.add(node);
  });
  final packet = pb.MeshPacket(
    from: _peerNodeNum,
    to: _myNodeNum,
    id: _packetId++,
    decoded: pb.Data(
      portnum: pn.PortNum.TELEMETRY_APP,
      payload: telem.writeToBuffer(),
    ),
  );
  if (rxTime != null) packet.rxTime = rxTime;
  await protocol.handleIncomingPacket(
    pb.FromRadio(packet: packet).writeToBuffer(),
  );
  // Packet processing continues past handleIncomingPacket's return (the
  // dedupe-store check is asynchronous), so give the telemetry merge a
  // moment to emit before detaching.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await sub.cancel();
  expect(updates, isNotEmpty, reason: 'Telemetry must emit a node update.');
  return updates.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'replayed device metrics keep the packet rxTime as sample time',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _SilentFakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        try {
          final heardAt = DateTime.now().subtract(
            const Duration(days: 1, hours: 16),
          );
          final rxEpoch = heardAt.millisecondsSinceEpoch ~/ 1000;

          final replayed = await _ingestTelemetry(
            protocol,
            telemetry.Telemetry(
              deviceMetrics: telemetry.DeviceMetrics(
                batteryLevel: 64,
                voltage: 3.84,
                channelUtilization: 0.7,
                airUtilTx: 1.8,
              ),
            ),
            rxTime: rxEpoch,
          );
          expect(
            replayed.metricsTimestamp,
            DateTime.fromMillisecondsSinceEpoch(rxEpoch * 1000),
            reason:
                'A buffered packet is filed at the time the radio heard it.',
          );
          expect(replayed.deviceMetricsFromNodeDb, isFalse);

          // A live packet with a current rxTime moves the sample time forward.
          final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final live = await _ingestTelemetry(
            protocol,
            telemetry.Telemetry(
              deviceMetrics: telemetry.DeviceMetrics(
                batteryLevel: 91,
                voltage: 4.07,
              ),
            ),
            rxTime: nowEpoch,
          );
          expect(
            live.metricsTimestamp,
            DateTime.fromMillisecondsSinceEpoch(nowEpoch * 1000),
          );
        } finally {
          protocol.stop();
          await transport.dispose();
        }
      });
    },
  );

  test('every telemetry variant stamps the sample time', () async {
    await _withTempDirectory((dir) async {
      final transport = _SilentFakeTransport();
      final protocol = await _freshProtocol(dir, transport);
      try {
        final base = DateTime.now().subtract(const Duration(hours: 6));
        var offset = 0;
        Future<void> expectStamped(telemetry.Telemetry telem) async {
          final rxEpoch =
              base.add(Duration(minutes: offset++)).millisecondsSinceEpoch ~/
              1000;
          final node = await _ingestTelemetry(protocol, telem, rxTime: rxEpoch);
          expect(
            node.metricsTimestamp,
            DateTime.fromMillisecondsSinceEpoch(rxEpoch * 1000),
            reason: '${telem.whichVariant()} must stamp metricsTimestamp.',
          );
        }

        await expectStamped(
          telemetry.Telemetry(
            environmentMetrics: telemetry.EnvironmentMetrics(temperature: 21.5),
          ),
        );
        await expectStamped(
          telemetry.Telemetry(
            airQualityMetrics: telemetry.AirQualityMetrics(pm25Standard: 12),
          ),
        );
        await expectStamped(
          telemetry.Telemetry(
            powerMetrics: telemetry.PowerMetrics(ch1Voltage: 12.6),
          ),
        );
        await expectStamped(
          telemetry.Telemetry(
            localStats: telemetry.LocalStats(channelUtilization: 5.0),
          ),
        );
      } finally {
        protocol.stop();
        await transport.dispose();
      }
    });
  });

  test('a packet without rxTime is stamped at the wall clock', () async {
    await _withTempDirectory((dir) async {
      final transport = _SilentFakeTransport();
      final protocol = await _freshProtocol(dir, transport);
      try {
        final before = DateTime.now();
        final node = await _ingestTelemetry(
          protocol,
          telemetry.Telemetry(
            deviceMetrics: telemetry.DeviceMetrics(batteryLevel: 50),
          ),
        );
        final after = DateTime.now();
        expect(node.metricsTimestamp, isNotNull);
        expect(node.metricsTimestamp!.isBefore(before), isFalse);
        expect(node.metricsTimestamp!.isAfter(after), isFalse);
      } finally {
        protocol.stop();
        await transport.dispose();
      }
    });
  });
}
