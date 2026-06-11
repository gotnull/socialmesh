// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the telemetry ingestion sanitization contract: proto float fields
// can carry NaN or Infinity from misbehaving peer firmware, and nothing
// non-finite may escape into the node stream. A non-finite sample is
// treated as absent, so the node's prior finite value is retained.

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
var _packetId = 100;

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('telemetry_sanitize');
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
  telemetry.Telemetry telem,
) async {
  final updates = <MeshNode>[];
  final sub = protocol.nodeStream.listen((node) {
    if (node.nodeNum == _peerNodeNum) updates.add(node);
  });
  await protocol.handleIncomingPacket(
    pb.FromRadio(
      packet: pb.MeshPacket(
        from: _peerNodeNum,
        to: _myNodeNum,
        id: _packetId++,
        decoded: pb.Data(
          portnum: pn.PortNum.TELEMETRY_APP,
          payload: telem.writeToBuffer(),
        ),
      ),
    ).writeToBuffer(),
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
    'non-finite device metrics are dropped and prior values retained',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _SilentFakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        try {
          final good = await _ingestTelemetry(
            protocol,
            telemetry.Telemetry(
              deviceMetrics: telemetry.DeviceMetrics(
                batteryLevel: 80,
                voltage: 4.1,
                channelUtilization: 12.5,
                airUtilTx: 3.5,
              ),
            ),
          );
          expect(good.voltage, closeTo(4.1, 0.0001));

          final afterBad = await _ingestTelemetry(
            protocol,
            telemetry.Telemetry(
              deviceMetrics: telemetry.DeviceMetrics(
                batteryLevel: 81,
                voltage: double.infinity,
                channelUtilization: double.nan,
                airUtilTx: 4.0,
              ),
            ),
          );
          expect(afterBad.batteryLevel, 81);
          expect(
            afterBad.voltage,
            closeTo(4.1, 0.0001),
            reason:
                'Infinity voltage must be treated as absent, keeping the '
                'prior finite sample.',
          );
          expect(
            afterBad.channelUtilization,
            closeTo(12.5, 0.0001),
            reason: 'NaN channel utilization must not replace the prior value.',
          );
          expect(afterBad.airUtilTx, closeTo(4.0, 0.0001));
        } finally {
          protocol.stop();
          await transport.dispose();
        }
      });
    },
  );

  test(
    'non-finite environment and power metrics never escape nodeStream',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _SilentFakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        try {
          final env = await _ingestTelemetry(
            protocol,
            telemetry.Telemetry(
              environmentMetrics: telemetry.EnvironmentMetrics(
                temperature: double.nan,
                relativeHumidity: 55.0,
                barometricPressure: double.negativeInfinity,
                windSpeed: double.nan,
              ),
            ),
          );
          expect(env.temperature, isNull);
          expect(env.humidity, closeTo(55.0, 0.0001));
          expect(env.barometricPressure, isNull);
          expect(env.windSpeed, isNull);

          final pwr = await _ingestTelemetry(
            protocol,
            telemetry.Telemetry(
              powerMetrics: telemetry.PowerMetrics(
                ch1Voltage: double.nan,
                ch2Voltage: 3.3,
              ),
            ),
          );
          expect(pwr.ch1Voltage, isNull);
          expect(pwr.ch2Voltage, closeTo(3.3, 0.0001));

          // Every double field that did flow through must be finite.
          for (final value in <double?>[
            env.temperature,
            env.humidity,
            env.barometricPressure,
            env.windSpeed,
            pwr.ch1Voltage,
            pwr.ch2Voltage,
            pwr.voltage,
          ]) {
            expect(value == null || value.isFinite, isTrue);
          }
        } finally {
          protocol.stop();
          await transport.dispose();
        }
      });
    },
  );
}
