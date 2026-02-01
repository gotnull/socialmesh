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

class _FakeTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
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

List<int> _buildSignalPacket({
  required int packetId,
  required int fromNode,
  required Map<String, dynamic> payload,
}) {
  final data = pb.Data()
    ..portnum = pn.PortNum.PRIVATE_APP
    ..payload = utf8.encode(jsonEncode(payload));

  final packet = pb.MeshPacket()
    ..from = fromNode
    ..to = 0xFFFFFFFF
    ..id = packetId
    ..decoded = data;

  final frame = pb.FromRadio()..packet = packet;
  return frame.writeToBuffer();
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('protocol_signals');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('signalStream emits packet for valid JSON payload', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final received = <MeshSignalPacket>[];
      final sub = protocol.signalStream.listen(received.add);
      try {
        final payload = {'id': 'mesh-1', 'c': 'hello', 't': 30};
        final packet = _buildSignalPacket(
          packetId: 123,
          fromNode: 0x10,
          payload: payload,
        );
        await protocol.handleIncomingPacket(packet);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(received.length, equals(1));
        expect(received.first.signalId, equals('mesh-1'));
        expect(received.first.content, equals('hello'));
        expect(received.first.ttlMinutes, equals(30));
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });

  test('signalStream ignores invalid JSON payload', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final received = <MeshSignalPacket>[];
      final sub = protocol.signalStream.listen(received.add);
      try {
        final packet = pb.MeshPacket()
          ..from = 0x10
          ..to = 0xFFFFFFFF
          ..id = 124
          ..decoded = (pb.Data()
            ..portnum = pn.PortNum.PRIVATE_APP
            ..payload = utf8.encode('not json'));

        final frame = pb.FromRadio()..packet = packet;
        await protocol.handleIncomingPacket(frame.writeToBuffer());
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(received, isEmpty);
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });
}
