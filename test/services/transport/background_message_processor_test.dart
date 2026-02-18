// SPDX-License-Identifier: GPL-3.0-or-later
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
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/transport/background_message_processor.dart';

// =============================================================================
// Fake DeviceTransport for tests
// =============================================================================

class _FakeTransport implements DeviceTransport {
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  bool get isConnected => true;

  @override
  bool get requiresFraming => false;

  void emitData(List<int> data) => _dataController.add(data);

  @override
  Future<void> dispose() async {
    _stateController.close();
    _dataController.close();
  }

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {}

  void setConnectionParameters({required int mtuSize}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// Helper: build a FromRadio protobuf with a text message
// =============================================================================

List<int> buildTextMessagePacket({
  required int from,
  required int to,
  required String text,
  int packetId = 1,
  int channel = 0,
}) {
  final fromRadio = pb.FromRadio(
    id: 1,
    packet: pb.MeshPacket(
      from: from,
      to: to,
      id: packetId,
      channel: channel,
      decoded: pb.Data(
        portnum: pn.PortNum.TEXT_MESSAGE_APP,
        payload: utf8.encode(text),
      ),
    ),
  );
  return fromRadio.writeToBuffer();
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late String tempDir;
  late _FakeTransport transport;
  late MessageDatabase msgDb;
  late MeshPacketDedupeStore dedupeStore;

  String uniqueDbPath(String name) => p.join(tempDir, name);

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('bg_msg_test_').path;
    transport = _FakeTransport();

    msgDb = MessageDatabase(testDbPath: uniqueDbPath('msg.db'));
    await msgDb.init();

    dedupeStore = MeshPacketDedupeStore(
      dbPathOverride: uniqueDbPath('dedupe.db'),
    );
    await dedupeStore.init();
  });

  tearDown(() async {
    await transport.dispose();
    dedupeStore.dispose();
    // Clean up the processor singleton state between tests.
    BackgroundMessageProcessor.instance.dispose();
    try {
      final dir = Directory(tempDir);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('BackgroundMessageProcessor', () {
    test('decodes FromRadio text message and persists to database', () async {
      final processor = BackgroundMessageProcessor.instance;
      processor.initForTest(messageDb: msgDb, dedupeStore: dedupeStore);
      processor.start(transport);
      processor.processingEnabled = true;

      // Emit a text message packet.
      const senderNode = 0x12345678;
      const destNode = 0xFFFFFFFF;
      const msgText = 'Hello from the mesh!';

      transport.emitData(
        buildTextMessagePacket(
          from: senderNode,
          to: destNode,
          text: msgText,
          packetId: 42,
          channel: 0,
        ),
      );

      // Allow microtask (_processPacketAsync) to complete.
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Verify the message was persisted.
      expect(processor.persistedMessageIds, isNotEmpty);
      expect(processor.messageDb, isNotNull);

      // Load the persisted message from the database.
      // Channel 0 = primary channel, DM = to == 0xFFFFFFFF with channel 0.
      // The MessageDatabase.saveMessage computes conversation_key internally.
      // Query by a broad match to find the saved message.
      final allConvos = await msgDb.loadConversation('channel:0');
      // Also try DM format.
      final smallerNode = senderNode < destNode ? senderNode : destNode;
      final largerNode = senderNode < destNode ? destNode : senderNode;
      final dmMessages = await msgDb.loadConversation(
        'dm:$smallerNode:$largerNode',
      );
      final allMessages = [...allConvos, ...dmMessages];

      expect(allMessages, isNotEmpty);
      final saved = allMessages.first;
      expect(saved.from, senderNode);
      expect(saved.text, msgText);
      expect(saved.received, true);
    });

    test('duplicate detection skips already-persisted message', () async {
      final processor = BackgroundMessageProcessor.instance;
      processor.initForTest(messageDb: msgDb, dedupeStore: dedupeStore);
      processor.start(transport);
      processor.processingEnabled = true;

      const senderNode = 0xAABBCCDD;
      const destNode = 0xFFFFFFFF;
      const msgText = 'Duplicate test message';
      const packetId = 99;

      final packet = buildTextMessagePacket(
        from: senderNode,
        to: destNode,
        text: msgText,
        packetId: packetId,
        channel: 1,
      );

      // Emit the same packet twice.
      transport.emitData(packet);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      transport.emitData(packet);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Only one message should have been persisted.
      expect(processor.persistedMessageIds.length, 1);
    });

    test('non-text packets are buffered for foreground processing', () async {
      final processor = BackgroundMessageProcessor.instance;
      processor.initForTest(messageDb: msgDb, dedupeStore: dedupeStore);
      processor.start(transport);
      processor.processingEnabled = true;

      // Build a FromRadio with nodeInfo (not a text message).
      final fromRadio = pb.FromRadio(id: 2, nodeInfo: pb.NodeInfo(num: 12345));
      transport.emitData(fromRadio.writeToBuffer());

      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Should be buffered as a pending packet.
      expect(processor.pendingPackets, hasLength(1));
      expect(processor.persistedMessageIds, isEmpty);

      // Drain and verify.
      final drained = processor.drainPendingPackets();
      expect(drained, hasLength(1));
      expect(processor.pendingPackets, isEmpty);
    });
  });
}
