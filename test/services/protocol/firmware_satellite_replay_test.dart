// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Firmware 2.8 replays its cached per-node telemetry records to the phone
// after config completes, as TELEMETRY_APP packets stamped with the node's
// last_heard rather than the time the values were measured. These must
// never become history rows, and must not displace newer metrics.
//
// Fixtures are MeshPackets captured from meshtasticd 2.8.1.8e6a88d (a
// portduino SimRadio) on 10th October 2026: node !00aa0001's device
// telemetry was injected over the simulated air, a later NODEINFO_APP from
// the same node advanced its last_heard, and the radio's replay on the next
// connect was recorded byte for byte.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/generated/meshtastic/telemetry.pb.dart' as telemetry;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/firmware_satellite_replay.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/telemetry_database.dart';

// Replay of !00aa0001's device metrics (64 %, 3.84 V, uptime 6199200 s)
// with rxTime and Telemetry.time 1791629434, the last_heard set by the
// later NODEINFO_APP.
const _replayHex =
    '0d0100aa0015ffffffff22210843121d0d7a18ca6a12160840158fc275401d0000b040'
    '250000a03f28a0affa0235bd62d3a13d7a18ca6a4803580a7803a80101';

// The radio's own device telemetry, delivered live during the same session.
const _liveOwnHex =
    '0d5f9bd24015ffffffff221a084312160d9d18ca6a120f08651d3e0a83402577e4043e'
    '288e0235037266583d9d18ca6a4803580a';

const _replayNode = 0x00aa0001;
const _replayHeardEpoch = 1791629434;
const _myNodeNum = 0x40d29b5f;

List<int> _hex(String s) => [
  for (var i = 0; i < s.length; i += 2)
    int.parse(s.substring(i, i + 2), radix: 16),
];

pb.MeshPacket _captured(String hex) => pb.MeshPacket.fromBuffer(_hex(hex));

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

Future<ProtocolService> _protocol(String dir) async {
  final dedupeStore = MeshPacketDedupeStore(
    dbPathOverride: p.join(
      dir,
      'dedupe_${DateTime.now().microsecondsSinceEpoch}.db',
    ),
  );
  await dedupeStore.init();
  final protocol = ProtocolService(
    _SilentFakeTransport(),
    dedupeStore: dedupeStore,
  );
  await protocol.handleIncomingPacket(
    pb.FromRadio(myInfo: pb.MyNodeInfo(myNodeNum: _myNodeNum)).writeToBuffer(),
  );
  return protocol;
}

// Firmware 2.8 sends other nodes' NodeInfo thin (no device metrics) ahead of
// the replay, carrying the radio's last_heard.
Future<void> _seedThinNodeInfo(ProtocolService protocol, int lastHeard) =>
    protocol.handleIncomingPacket(
      pb.FromRadio(
        nodeInfo: pb.NodeInfo(
          num: _replayNode,
          lastHeard: lastHeard,
          user: pb.User(
            id: '!00aa0001',
            longName: 'MGrX sim',
            shortName: 'MGrX',
          ),
        ),
      ).writeToBuffer(),
    );

Future<MeshNode?> _deliver(
  ProtocolService protocol,
  pb.MeshPacket packet,
) async {
  MeshNode? last;
  final sub = protocol.nodeStream.listen((node) {
    if (node.nodeNum == packet.from) last = node;
  });
  await protocol.handleIncomingPacket(
    pb.FromRadio(packet: packet).writeToBuffer(),
  );
  // The dedupe check is asynchronous; let the telemetry merge emit.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  await sub.cancel();
  return last;
}

pb.MeshPacket _liveDeviceTelemetry({
  required int rxTime,
  required int battery,
  required double voltage,
  required int uptime,
}) => pb.MeshPacket(
  from: _replayNode,
  to: 0xFFFFFFFF,
  id: 0x13572468,
  rxTime: rxTime,
  decoded: pb.Data(
    portnum: pn.PortNum.TELEMETRY_APP,
    payload: telemetry.Telemetry(
      time: rxTime,
      deviceMetrics: telemetry.DeviceMetrics(
        batteryLevel: battery,
        voltage: voltage,
        uptimeSeconds: uptime,
      ),
    ).writeToBuffer(),
  ),
);

Future<void> _withTempDir(Future<void> Function(String dir) body) async {
  final dir = await Directory.systemTemp.createTemp('fw_replay');
  try {
    await body(dir.path);
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('firmwareReplayPacketId', () {
    test('reproduces the ids the 2.8.1 radio assigned', () {
      // Observed replay ids for the same record as last_heard moved; the
      // first was sent before the radio had a clock (rxTime 0).
      const observed = {
        0: 0xb850cc63,
        1791629434: 0xa1d362bd,
        1791629463: 0x8e1c2bca,
        1791629536: 0xabeddf43,
      };
      observed.forEach((rxTime, id) {
        expect(
          firmwareReplayPacketId(
            _replayNode,
            rxTime,
            firmwareReplayKindDeviceMetrics,
          ),
          id,
          reason: 'rxTime $rxTime',
        );
      });
    });

    test('a captured replay is recognised and a live packet is not', () {
      final replay = _captured(_replayHex);
      expect(replay.from, _replayNode);
      expect(replay.rxTime, _replayHeardEpoch);
      expect(
        isFirmwareReplayOfKind(replay, firmwareReplayKindDeviceMetrics),
        isTrue,
      );
      // The same record is not mistaken for another kind.
      expect(
        isFirmwareReplayOfKind(replay, firmwareReplayKindEnvironmentMetrics),
        isFalse,
      );

      final live = _captured(_liveOwnHex);
      expect(
        isFirmwareReplayOfKind(live, firmwareReplayKindDeviceMetrics),
        isFalse,
      );
    });
  });

  group('ProtocolService', () {
    test('a replay fills missing metrics as cached, with no sample time', () {
      return _withTempDir((dir) async {
        final protocol = await _protocol(dir);
        await _seedThinNodeInfo(protocol, _replayHeardEpoch);

        final node = await _deliver(protocol, _captured(_replayHex));

        expect(node, isNotNull);
        expect(node!.batteryLevel, 64);
        expect(node.voltage, closeTo(3.84, 0.001));
        expect(node.uptimeSeconds, 6199200);
        expect(node.deviceMetricsFromNodeDb, isTrue);
        expect(node.metricsTimestamp, isNull);
        expect(
          node.lastHeard,
          DateTime.fromMillisecondsSinceEpoch(_replayHeardEpoch * 1000),
        );
      });
    });

    test('a replay never displaces metrics heard after it', () {
      return _withTempDir((dir) async {
        final protocol = await _protocol(dir);
        await _seedThinNodeInfo(protocol, _replayHeardEpoch);
        final liveAt = _replayHeardEpoch + 120;
        await _deliver(
          protocol,
          _liveDeviceTelemetry(
            rxTime: liveAt,
            battery: 90,
            voltage: 4.04,
            uptime: 6340000,
          ),
        );

        final node = await _deliver(protocol, _captured(_replayHex));

        expect(node!.batteryLevel, 90);
        expect(node.voltage, closeTo(4.04, 0.001));
        expect(node.uptimeSeconds, 6340000);
        expect(node.deviceMetricsFromNodeDb, isFalse);
        expect(
          node.metricsTimestamp,
          DateTime.fromMillisecondsSinceEpoch(liveAt * 1000),
        );
        expect(
          node.lastHeard,
          DateTime.fromMillisecondsSinceEpoch(liveAt * 1000),
        );
      });
    });

    test('a replay from a radio with no clock neither displaces metrics '
        'nor moves lastHeard', () {
      return _withTempDir((dir) async {
        final protocol = await _protocol(dir);
        await _seedThinNodeInfo(protocol, _replayHeardEpoch);
        final liveAt = _replayHeardEpoch - 600;
        await _deliver(
          protocol,
          _liveDeviceTelemetry(
            rxTime: liveAt,
            battery: 90,
            voltage: 4.04,
            uptime: 6340000,
          ),
        );
        final before = protocol.nodes[_replayNode]!.lastHeard;

        // The replay the radio sent before it had a clock: rxTime 0, with
        // the id the firmware derived from it.
        final noClock = _captured(_replayHex)
          ..rxTime = 0
          ..id = 0xb850cc63;
        final node = await _deliver(protocol, noClock);

        expect(node!.batteryLevel, 90);
        expect(node.deviceMetricsFromNodeDb, isFalse);
        expect(node.lastHeard, before);
      });
    });

    test('a replay is not a reception: link metrics and mesh health '
        'are untouched', () {
      return _withTempDir((dir) async {
        final protocol = await _protocol(dir);
        await _seedThinNodeInfo(protocol, _replayHeardEpoch);
        // A direct live reception gives the node an RSSI.
        await _deliver(
          protocol,
          _liveDeviceTelemetry(
              rxTime: _replayHeardEpoch - 60,
              battery: 90,
              voltage: 4.04,
              uptime: 6340000,
            )
            ..hopStart = 3
            ..hopLimit = 3
            ..rxRssi = -71,
        );
        expect(protocol.nodes[_replayNode]!.rssi, -71);

        final receptions = <Object>[];
        final healthSub = protocol.meshTelemetryStream.listen(receptions.add);
        // The firmware sends hop_start 0 when it does not know the node's
        // hop count; as a reception that would read as relayed and clear
        // the node's RSSI.
        final replay = _captured(_replayHex)
          ..hopStart = 0
          ..hopLimit = 0;
        await _deliver(protocol, replay);
        await healthSub.cancel();

        expect(protocol.nodes[_replayNode]!.rssi, -71);
        expect(receptions, isEmpty);
      });
    });

    test('a replay from a radio with no clock does not mark an unknown-age '
        'node as heard now', () {
      return _withTempDir((dir) async {
        final protocol = await _protocol(dir);
        // A radio with no clock sends NodeInfo without a usable last_heard.
        await _seedThinNodeInfo(protocol, 0);
        expect(protocol.nodes[_replayNode]!.lastHeard, isNull);

        final noClock = _captured(_replayHex)
          ..rxTime = 0
          ..id = 0xb850cc63;
        await _deliver(protocol, noClock);

        final lastHeard = protocol.nodes[_replayNode]!.lastHeard;
        expect(
          lastHeard == null || lastHeard.isBefore(DateTime(2021)),
          isTrue,
          reason: 'lastHeard $lastHeard',
        );
      });
    });

    test('a replay for a node the app does not know creates no node', () {
      return _withTempDir((dir) async {
        final protocol = await _protocol(dir);

        await _deliver(protocol, _captured(_replayHex));

        expect(protocol.nodes[_replayNode], isNull);
      });
    });

    test('a replayed environment record is not applied', () {
      return _withTempDir((dir) async {
        final protocol = await _protocol(dir);
        await _seedThinNodeInfo(protocol, _replayHeardEpoch);

        // The 2.8.1 portduino build keeps no environment records, so this
        // packet is built from the firmware's replay rules (id from
        // makeReplayPacketId with the environment_metrics kind, rxTime and
        // Telemetry.time both last_heard) rather than captured.
        final replay = pb.MeshPacket(
          from: _replayNode,
          to: 0xFFFFFFFF,
          id: firmwareReplayPacketId(
            _replayNode,
            _replayHeardEpoch,
            firmwareReplayKindEnvironmentMetrics,
          ),
          rxTime: _replayHeardEpoch,
          decoded: pb.Data(
            portnum: pn.PortNum.TELEMETRY_APP,
            payload: telemetry.Telemetry(
              time: _replayHeardEpoch,
              environmentMetrics: telemetry.EnvironmentMetrics(
                temperature: 21.5,
                relativeHumidity: 48,
              ),
            ).writeToBuffer(),
          ),
        );
        await _deliver(protocol, replay);

        final node = protocol.nodes[_replayNode]!;
        expect(node.temperature, isNull);
        expect(node.humidity, isNull);
        expect(node.metricsTimestamp, isNull);
      });
    });

    test('live telemetry is still stamped as a sample', () {
      return _withTempDir((dir) async {
        final protocol = await _protocol(dir);
        await _seedThinNodeInfo(protocol, _replayHeardEpoch);
        final liveAt = _replayHeardEpoch + 60;

        final node = await _deliver(
          protocol,
          _liveDeviceTelemetry(
            rxTime: liveAt,
            battery: 71,
            voltage: 3.95,
            uptime: 6200000,
          ),
        );

        expect(node!.batteryLevel, 71);
        expect(node.deviceMetricsFromNodeDb, isFalse);
        expect(
          node.metricsTimestamp,
          DateTime.fromMillisecondsSinceEpoch(liveAt * 1000),
        );
      });
    });
  });

  test('a replay reaching the history logger writes no row', () {
    return _withTempDir((dir) async {
      SharedPreferences.setMockInitialValues({});
      final storage = TelemetryDatabase(testDbPath: inMemoryDatabasePath);
      await storage.init();
      final protocol = await _protocol(dir);
      final container = ProviderContainer(
        overrides: [
          telemetryStorageProvider.overrideWith((ref) async => storage),
          protocolServiceProvider.overrideWithValue(protocol),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(telemetryLoggerProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(telemetryStorageProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(telemetryLoggerProvider), isTrue);

      await _seedThinNodeInfo(protocol, _replayHeardEpoch);
      await _deliver(protocol, _captured(_replayHex));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await storage.getDeviceMetrics(_replayNode), isEmpty);

      // A live reading afterwards logs at its own receive time.
      final liveAt = _replayHeardEpoch + 300;
      await _deliver(
        protocol,
        _liveDeviceTelemetry(
          rxTime: liveAt,
          battery: 88,
          voltage: 4.02,
          uptime: 6340000,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final rows = await storage.getDeviceMetrics(_replayNode);
      expect(rows, hasLength(1));
      expect(rows.single.batteryLevel, 88);
      expect(
        rows.single.timestamp,
        DateTime.fromMillisecondsSinceEpoch(liveAt * 1000),
      );
    });
  });
}
