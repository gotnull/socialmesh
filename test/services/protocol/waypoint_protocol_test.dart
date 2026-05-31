// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the WAYPOINT_APP wire behaviour:
//   - sendWaypoint broadcasts a Waypoint proto on PortNum.WAYPOINT_APP with
//     wantAck, to == 0xFFFFFFFF, and the right field values.
//   - delete-for-everyone sets expire == 1.
//   - the receive path republishes a MeshWaypointEvent with decoded fields,
//     and flags expire == 1 as a delete.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _CapturingTransport extends DeviceTransport {
  final List<List<int>> sent = [];

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
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();

  @override
  Stream<List<int>> get dataStream => const Stream<List<int>>.empty();

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
  Future<void> send(List<int> data) async => sent.add(data);

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {}
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('waypoint_protocol');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

pb.Waypoint _decodeSentWaypoint(List<int> bytes) {
  final toRadio = pb.ToRadio.fromBuffer(bytes);
  expect(toRadio.hasPacket(), isTrue);
  final packet = toRadio.packet;
  expect(packet.to, 0xFFFFFFFF);
  expect(packet.wantAck, isTrue);
  expect(packet.decoded.portnum, pn.PortNum.WAYPOINT_APP);
  return pb.Waypoint.fromBuffer(packet.decoded.payload);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<ProtocolService> build(
    String dir,
    _CapturingTransport transport,
  ) async {
    final dedupeStore = MeshPacketDedupeStore(
      dbPathOverride: p.join(dir, 'dedupe_store.db'),
    );
    await dedupeStore.init();
    return ProtocolService(transport, dedupeStore: dedupeStore);
  }

  test(
    'sendWaypoint broadcasts a WAYPOINT_APP packet with correct fields',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _CapturingTransport();
        final protocol = await build(dir, transport);

        await protocol.sendWaypoint(
          id: 0x1234,
          latitude: 37.7749,
          longitude: -122.4194,
          name: 'Camp',
          description: 'Base',
          icon: 0x1F4CD,
          expire: 1700000000,
          lockedTo: 0xABCD,
        );

        expect(transport.sent, hasLength(1));
        final w = _decodeSentWaypoint(transport.sent.single);
        expect(w.id, 0x1234);
        expect(w.latitudeI, (37.7749 * 1e7).round());
        expect(w.longitudeI, (-122.4194 * 1e7).round());
        expect(w.name, 'Camp');
        expect(w.description, 'Base');
        expect(w.icon, 0x1F4CD);
        expect(w.expire, 1700000000);
        expect(w.lockedTo, 0xABCD);

        protocol.stop();
      });
    },
  );

  test('delete-for-everyone sets expire == 1', () async {
    await _withTempDirectory((dir) async {
      final transport = _CapturingTransport();
      final protocol = await build(dir, transport);

      await protocol.sendWaypoint(
        id: 99,
        latitude: 1.0,
        longitude: 2.0,
        expire: 1,
      );

      final w = _decodeSentWaypoint(transport.sent.single);
      expect(w.expire, 1);

      protocol.stop();
    });
  });

  test('sendWaypoint self-echoes onto waypointStream', () async {
    await _withTempDirectory((dir) async {
      final transport = _CapturingTransport();
      final protocol = await build(dir, transport);

      final events = <MeshWaypointEvent>[];
      final sub = protocol.waypointStream.listen(events.add);

      await protocol.sendWaypoint(
        id: 7,
        latitude: 10.0,
        longitude: 20.0,
        name: 'Echo',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(events, hasLength(1));
      expect(events.single.id, 7);
      expect(events.single.name, 'Echo');
      expect(events.single.isDelete, isFalse);

      await sub.cancel();
      protocol.stop();
    });
  });

  test(
    'incoming WAYPOINT_APP packet republishes a MeshWaypointEvent',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _CapturingTransport();
        final protocol = await build(dir, transport);

        final events = <MeshWaypointEvent>[];
        final sub = protocol.waypointStream.listen(events.add);

        final waypoint = pb.Waypoint()
          ..id = 555
          ..latitudeI = (51.5 * 1e7).round()
          ..longitudeI = (-0.12 * 1e7).round()
          ..name = 'Remote'
          ..icon = 0x1F4CD;
        final data = pb.Data()
          ..portnum = pn.PortNum.WAYPOINT_APP
          ..payload = waypoint.writeToBuffer();
        final packet = pb.MeshPacket()
          ..from = 0x77
          ..to = 0xFFFFFFFF
          ..id = 1
          ..decoded = data;
        final frame = pb.FromRadio()..packet = packet;

        await protocol.handleIncomingPacket(frame.writeToBuffer());
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(events, hasLength(1));
        final e = events.single;
        expect(e.id, 555);
        expect(e.fromNodeNum, 0x77);
        expect(e.name, 'Remote');
        expect(e.icon, 0x1F4CD);
        expect(e.isDelete, isFalse);
        expect(e.latitude, closeTo(51.5, 1e-5));
        expect(e.longitude, closeTo(-0.12, 1e-5));

        await sub.cancel();
        protocol.stop();
      });
    },
  );

  test('incoming waypoint with expire == 1 is flagged as a delete', () async {
    await _withTempDirectory((dir) async {
      final transport = _CapturingTransport();
      final protocol = await build(dir, transport);

      final events = <MeshWaypointEvent>[];
      final sub = protocol.waypointStream.listen(events.add);

      final waypoint = pb.Waypoint()
        ..id = 321
        ..latitudeI = 0
        ..longitudeI = 0
        ..expire = 1;
      final data = pb.Data()
        ..portnum = pn.PortNum.WAYPOINT_APP
        ..payload = waypoint.writeToBuffer();
      final packet = pb.MeshPacket()
        ..from = 0x88
        ..to = 0xFFFFFFFF
        ..id = 2
        ..decoded = data;
      final frame = pb.FromRadio()..packet = packet;

      await protocol.handleIncomingPacket(frame.writeToBuffer());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(events, hasLength(1));
      expect(events.single.id, 321);
      expect(events.single.isDelete, isTrue);

      await sub.cancel();
      protocol.stop();
    });
  });
}
