// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Regression tests for messaging + sync parity issues:
// - Push message channel normalisation (Report A: missing PrimaryChannel msgs)
// - Timestamp validation (Report B: historical msgs shown as "just now")
// - Conversation key correctness for broadcast / channel / DM messages

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/messaging/message_utils.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/transport/background_message_processor.dart';
import 'package:socialmesh/core/transport.dart';

// =============================================================================
// Helpers
// =============================================================================

int _testDbSeq = 0;
final _testPid = pid;

// Chronological-fallback sentinel: 2020-01-01 UTC. The chat decode path
// (ProtocolService + BackgroundMessageProcessor) stamps packets with
// missing or implausible rxTime to this value so they sink to the top of
// the conversation instead of out-sorting freshly sent local messages.
// Mirrors `_minPlausibleEpoch` (1577836800) in both services.
final DateTime _chronologicalSentinel = DateTime.fromMillisecondsSinceEpoch(
  1577836800 * 1000,
);

String _uniqueTestDbPath(String prefix) {
  final dir = Directory.systemTemp.path;
  return p.join(dir, '${prefix}_${_testPid}_${_testDbSeq++}.db');
}

/// Build a FromRadio protobuf carrying a TEXT_MESSAGE_APP payload.
List<int> _buildTextPacket({
  required int from,
  required int to,
  required String text,
  int packetId = 1,
  int channel = 0,
  int rxTime = 0,
}) {
  final packet = pb.MeshPacket(
    from: from,
    to: to,
    id: packetId,
    channel: channel,
    decoded: pb.Data(
      portnum: pn.PortNum.TEXT_MESSAGE_APP,
      payload: utf8.encode(text),
    ),
  );
  if (rxTime > 0) {
    packet.rxTime = rxTime;
  }
  final fromRadio = pb.FromRadio(id: 1, packet: packet);
  return fromRadio.writeToBuffer();
}

// Fake transport for BackgroundMessageProcessor tests.
class _FakeTransport implements DeviceTransport {
  final _dataCtrl = StreamController<List<int>>.broadcast();

  void emitData(List<int> data) => _dataCtrl.add(data);

  @override
  Stream<List<int>> get dataStream => _dataCtrl.stream;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  bool get isConnected => true;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

  @override
  Future<void> dispose() async => _dataCtrl.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // ---------------------------------------------------------------------------
  // Push message channel normalisation (Report A fix)
  // ---------------------------------------------------------------------------

  group('parsePushMessagePayload channel normalisation', () {
    test('broadcast message with missing channel defaults to 0', () {
      final payload = <String, dynamic>{
        'fromNode': '100',
        'toNode': '4294967295', // 0xFFFFFFFF
        'text': 'Hello mesh',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final msg = parsePushMessagePayload(payload);
      expect(msg, isNotNull);
      expect(msg!.isBroadcast, isTrue);
      // Channel must be 0 (PrimaryChannel), not null.
      expect(msg.channel, 0);
    });

    test('broadcast message with explicit channel preserves it', () {
      final payload = <String, dynamic>{
        'fromNode': '100',
        'toNode': '4294967295',
        'text': 'Secondary channel',
        'channel': '2',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final msg = parsePushMessagePayload(payload);
      expect(msg, isNotNull);
      expect(msg!.channel, 2);
    });

    test('DM message with missing channel stays null', () {
      final payload = <String, dynamic>{
        'fromNode': '100',
        'toNode': '200',
        'text': 'Private message',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final msg = parsePushMessagePayload(payload);
      expect(msg, isNotNull);
      expect(msg!.isBroadcast, isFalse);
      // DM channel can remain null (it's not used for channel filtering).
      expect(msg.channel, isNull);
    });

    test(
      'normalised broadcast appears in PrimaryChannel conversation key',
      () async {
        final db = MessageDatabase(testDbPath: _uniqueTestDbPath('conv_key'));
        await db.init();

        final payload = <String, dynamic>{
          'fromNode': '999',
          'toNode': '4294967295',
          'text': 'Push broadcast',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        final msg = parsePushMessagePayload(payload)!;
        await db.saveMessage(msg);

        // Must land in channel:0, not in a dm: key.
        final rows = await db.loadConversation('channel:0');
        expect(rows.any((m) => m.text == 'Push broadcast'), isTrue);

        final dmRows = await db.loadConversation('dm:999:4294967295');
        expect(dmRows, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Timestamp validation (Report B fix)
  // ---------------------------------------------------------------------------

  group('timestamp plausibility (BackgroundMessageProcessor)', () {
    late _FakeTransport transport;
    late MessageDatabase msgDb;
    late MeshPacketDedupeStore dedupeStore;
    late String tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('ts_test_').path;
      transport = _FakeTransport();
      msgDb = MessageDatabase(testDbPath: p.join(tempDir, 'msg.db'));
      await msgDb.init();
      dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(tempDir, 'dedupe.db'),
      );
      await dedupeStore.init();
    });

    tearDown(() async {
      await transport.dispose();
      dedupeStore.dispose();
      BackgroundMessageProcessor.instance.dispose();
      try {
        final dir = Directory(tempDir);
        if (await dir.exists()) await dir.delete(recursive: true);
      } catch (_) {}
    });

    test('plausible rxTime is preserved', () async {
      final processor = BackgroundMessageProcessor.instance;
      processor.initForTest(messageDb: msgDb, dedupeStore: dedupeStore);
      processor.start(transport);
      processor.processingEnabled = true;

      // 2024-06-15 12:00:00 UTC — plausible
      const rxTime = 1718452800;

      transport.emitData(
        _buildTextPacket(
          from: 0xAA,
          to: 0xFFFFFFFF,
          text: 'Past message',
          packetId: 10,
          rxTime: rxTime,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final msgs = await msgDb.loadConversation('channel:0');
      expect(msgs, isNotEmpty);
      // Timestamp must match the rxTime, not DateTime.now().
      expect(
        msgs.first.timestamp,
        DateTime.fromMillisecondsSinceEpoch(rxTime * 1000),
      );
    });

    test('rxTime before 2020 sinks to chronological sentinel', () async {
      final processor = BackgroundMessageProcessor.instance;
      processor.initForTest(messageDb: msgDb, dedupeStore: dedupeStore);
      processor.start(transport);
      processor.processingEnabled = true;

      // Epoch 100 — clearly a device-uptime value, not a real timestamp.
      const rxTime = 100;

      transport.emitData(
        _buildTextPacket(
          from: 0xBB,
          to: 0xFFFFFFFF,
          text: 'Uptime message',
          packetId: 20,
          rxTime: rxTime,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final msgs = await msgDb.loadConversation('channel:0');
      expect(msgs, isNotEmpty);
      expect(msgs.first.timestamp, _chronologicalSentinel);
    });

    test('rxTime = 0 sinks to chronological sentinel', () async {
      final processor = BackgroundMessageProcessor.instance;
      processor.initForTest(messageDb: msgDb, dedupeStore: dedupeStore);
      processor.start(transport);
      processor.processingEnabled = true;

      transport.emitData(
        _buildTextPacket(
          from: 0xCC,
          to: 0xFFFFFFFF,
          text: 'No-clock message',
          packetId: 30,
          rxTime: 0,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 250));

      final msgs = await msgDb.loadConversation('channel:0');
      expect(msgs, isNotEmpty);
      expect(msgs.first.timestamp, _chronologicalSentinel);
    });

    test(
      'future rxTime beyond tolerance sinks to chronological sentinel',
      () async {
        final processor = BackgroundMessageProcessor.instance;
        processor.initForTest(messageDb: msgDb, dedupeStore: dedupeStore);
        processor.start(transport);
        processor.processingEnabled = true;

        // 2 days into the future — beyond the 1-day tolerance.
        final futureEpoch =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 172800;

        transport.emitData(
          _buildTextPacket(
            from: 0xDD,
            to: 0xFFFFFFFF,
            text: 'Future message',
            packetId: 40,
            rxTime: futureEpoch,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));

        final msgs = await msgDb.loadConversation('channel:0');
        expect(msgs, isNotEmpty);
        expect(msgs.first.timestamp, _chronologicalSentinel);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Conversation key correctness for channel / DM messages
  // ---------------------------------------------------------------------------

  group('conversation key regression', () {
    test('Primary Channel broadcast uses channel:0, not dm:', () {
      final msg = Message(
        from: 0x12345678,
        to: 0xFFFFFFFF,
        text: 'Broadcast',
        channel: 0,
        received: true,
      );
      expect(msg.isBroadcast, isTrue);
      expect(MessageDatabase.conversationKey(msg), 'channel:0');
    });

    test('Secondary channel broadcast uses correct key', () {
      final msg = Message(
        from: 0x12345678,
        to: 0xFFFFFFFF,
        text: 'Secondary',
        channel: 3,
        received: true,
      );
      expect(MessageDatabase.conversationKey(msg), 'channel:3');
    });

    test('DM uses sorted dm: key', () {
      final msg = Message(from: 200, to: 100, text: 'Hello', received: true);
      expect(msg.isBroadcast, isFalse);
      expect(MessageDatabase.conversationKey(msg), 'dm:100:200');
    });

    test('broadcast message with null channel defaults to channel:0', () {
      final msg = Message(
        from: 0x12345678,
        to: 0xFFFFFFFF,
        text: 'Null channel',
        channel: null,
        received: true,
      );
      // conversation_key should still be channel:0 (COALESCE behaviour).
      expect(MessageDatabase.conversationKey(msg), 'channel:0');
    });
  });

  // ---------------------------------------------------------------------------
  // Message model / UI filter alignment
  // ---------------------------------------------------------------------------

  group('message UI filter alignment', () {
    test('channel filter matches broadcast on channel 0', () {
      final msg = Message(
        from: 0x11,
        to: 0xFFFFFFFF,
        text: 'Test',
        channel: 0,
        received: true,
      );
      // Simulates the UI filter from MessagingScreen.
      final matches = msg.channel == 0 && msg.isBroadcast;
      expect(matches, isTrue);
    });

    test('channel filter excludes DM on channel 0', () {
      final msg = Message(
        from: 0x11,
        to: 0x22,
        text: 'DM on 0',
        channel: 0,
        received: true,
      );
      final matches = msg.channel == 0 && msg.isBroadcast;
      expect(matches, isFalse);
    });

    test('channel filter excludes broadcast with null channel', () {
      final msg = Message(
        from: 0x11,
        to: 0xFFFFFFFF,
        text: 'Null ch',
        channel: null,
        received: true,
      );
      // Without normalisation, this message would be invisible.
      final matches = msg.channel == 0 && msg.isBroadcast;
      expect(matches, isFalse);
    });

    test('notification path uses isBroadcast, not channel index', () {
      // Verify that isBroadcast is based on `to`, not channel.
      final broadcastMsg = Message(
        from: 0x11,
        to: 0xFFFFFFFF,
        text: 'Broadcast',
        channel: null,
        received: true,
      );
      expect(broadcastMsg.isBroadcast, isTrue);

      final dmMsg = Message(
        from: 0x11,
        to: 0x22,
        text: 'DM',
        channel: 0,
        received: true,
      );
      expect(dmMsg.isBroadcast, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Reconnect does not reset existing timestamps
  // ---------------------------------------------------------------------------

  group('reconnect timestamp stability', () {
    test('re-persisting a message preserves original timestamp', () async {
      final db = MessageDatabase(testDbPath: _uniqueTestDbPath('reconnect_ts'));
      await db.init();

      final originalTime = DateTime(2024, 6, 15, 12, 0);
      final msg = Message(
        id: 'stable-id',
        from: 0xAA,
        to: 0xFFFFFFFF,
        text: 'Hello',
        timestamp: originalTime,
        channel: 0,
        received: true,
      );

      await db.saveMessage(msg);

      // Simulate reconnect: same message re-saved with same id but timestamp
      // should remain the original.
      final sameMsg = msg.copyWith(timestamp: originalTime);
      await db.saveMessage(sameMsg);

      final loaded = await db.loadConversation('channel:0');
      expect(loaded.length, 1);
      expect(loaded.first.timestamp, originalTime);
    });
  });
}
