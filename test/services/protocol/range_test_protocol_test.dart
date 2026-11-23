// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the RANGE_TEST_APP receive path: a packet from another radio
// republishes as a RangeTestPacketEvent carrying the firmware's sequence
// number and the RF reading, an MQTT-delivered packet carries no RF reading,
// and the connected radio's own packets are not reported.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _SilentTransport extends DeviceTransport {
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
  Future<void> send(List<int> data) async {}
  @override
  Future<int?> readRssi() async => null;
  @override
  Future<void> dispose() async {}
}

List<int> _rangeTestFrame({
  required int from,
  required int id,
  String text = 'seq 7',
  double? snr,
  int? rssi,
  bool viaMqtt = false,
}) {
  final data = pb.Data()
    ..portnum = pn.PortNum.RANGE_TEST_APP
    ..payload = utf8.encode(text);
  final packet = pb.MeshPacket()
    ..from = from
    ..to = 0xFFFFFFFF
    ..id = id
    ..hopLimit = 0
    ..decoded = data;
  if (snr != null) packet.rxSnr = snr;
  if (rssi != null) packet.rxRssi = rssi;
  if (viaMqtt) packet.viaMqtt = true;
  return (pb.FromRadio()..packet = packet).writeToBuffer();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<void> run(
    Future<void> Function(ProtocolService p, List<RangeTestPacketEvent> e) body,
  ) async {
    final dir = await Directory.systemTemp.createTemp('range_test_protocol');
    final dedupeStore = MeshPacketDedupeStore(
      dbPathOverride: p.join(dir.path, 'dedupe.db'),
    );
    await dedupeStore.init();
    final protocol = ProtocolService(
      _SilentTransport(),
      dedupeStore: dedupeStore,
    );
    final events = <RangeTestPacketEvent>[];
    final sub = protocol.rangeTestPacketStream.listen(events.add);
    try {
      await body(protocol, events);
    } finally {
      await sub.cancel();
      protocol.stop();
      await dedupeStore.dispose();
      await dir.delete(recursive: true);
    }
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('an RF packet carries its sequence and signal', () async {
    await run((protocol, events) async {
      await protocol.handleIncomingPacket(
        _rangeTestFrame(from: 0x51, id: 9, snr: -7.25, rssi: -104),
      );
      await settle();

      expect(events, hasLength(1));
      final e = events.single;
      expect(e.senderNodeNum, 0x51);
      expect(e.packetId, 9);
      expect(e.payload, 'seq 7');
      expect(e.sequence, 7);
      expect(e.rxSnr, -7.25);
      expect(e.rxRssi, -104);
      expect(e.viaMqtt, isFalse);
    });
  });

  test('a packet through MQTT has no RF reading', () async {
    await run((protocol, events) async {
      await protocol.handleIncomingPacket(
        _rangeTestFrame(from: 0x52, id: 10, snr: 6, rssi: -60, viaMqtt: true),
      );
      await settle();

      expect(events.single.viaMqtt, isTrue);
      expect(events.single.rxSnr, isNull);
      expect(events.single.rxRssi, isNull);
    });
  });

  test('a packet from the connected radio is not reported', () async {
    await run((protocol, events) async {
      final myInfo = pb.FromRadio()
        ..myInfo = (pb.MyNodeInfo()..myNodeNum = 0x99);
      await protocol.handleIncomingPacket(myInfo.writeToBuffer());
      await protocol.handleIncomingPacket(
        _rangeTestFrame(from: 0x99, id: 11, snr: 5, rssi: -50),
      );
      await settle();

      expect(events, isEmpty);
    });
  });

  group('parseSequence', () {
    test('reads the firmware payload', () {
      expect(RangeTestPacketEvent.parseSequence('seq 1'), 1);
      expect(RangeTestPacketEvent.parseSequence('seq 4294967295'), 4294967295);
      expect(RangeTestPacketEvent.parseSequence(' seq 12\n'), 12);
    });

    test('is null for any other text', () {
      expect(RangeTestPacketEvent.parseSequence('hello'), isNull);
      expect(RangeTestPacketEvent.parseSequence('seq'), isNull);
      expect(RangeTestPacketEvent.parseSequence('seq -3'), isNull);
      expect(RangeTestPacketEvent.parseSequence('seq 3 extra'), isNull);
    });
  });
}
