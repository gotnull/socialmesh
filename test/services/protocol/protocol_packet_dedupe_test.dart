import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/models/mesh_models.dart';
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
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout}) =>
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

List<int> _buildTextMessage({
  required int packetId,
  required int fromNode,
  int channel = 1,
  String text = 'hello',
}) {
  final payload = pb.Data()
    ..portnum = pn.PortNum.TEXT_MESSAGE_APP
    ..payload = utf8.encode(text);
  final packet = pb.MeshPacket()
    ..from = fromNode
    ..to = 0xFFFFFFFF
    ..channel = channel
    ..id = packetId
    ..decoded = payload;

  final frame = pb.FromRadio()..packet = packet;
  return frame.writeToBuffer();
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('packet_dedupe');
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

  test('duplicate packet is dropped', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe_store.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        final packet = _buildTextMessage(packetId: 101, fromNode: 0x10);
        await protocol.handleIncomingPacket(packet);
        await Future.delayed(const Duration(milliseconds: 20));
        expect(messages.length, 1);

        // Repeat same packet
        await protocol.handleIncomingPacket(packet);
        await Future.delayed(const Duration(milliseconds: 20));
        expect(messages.length, 1);
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });

  test('different packet ids create separate messages', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe_store.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        final packetOne = _buildTextMessage(packetId: 201, fromNode: 0x20);
        final packetTwo = _buildTextMessage(packetId: 202, fromNode: 0x20);
        await protocol.handleIncomingPacket(packetOne);
        await protocol.handleIncomingPacket(packetTwo);
        await Future.delayed(const Duration(milliseconds: 50));
        expect(messages.length, 2);
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });
}
