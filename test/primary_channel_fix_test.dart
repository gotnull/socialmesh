// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Tests for the Primary Channel message visibility fix.
//
// Root causes addressed:
// 1. `channel > 0` misclassified Primary Channel (index 0) as a DM,
//    producing wrong conversation keys, wrong notification category,
//    and wrong dedup behaviour.
// 2. `_storageLoadCompleter` completed prematurely when `_storage` was
//    null, allowing stream listeners to add messages before DB load
//    finished — then `state = resetMessages` overwrote them.
// 3. Content dedup must still work when push notifications set
//    `to = localNodeNum` while mesh packets use `to = 0xFFFFFFFF`.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:socialmesh/services/notifications/notification_service.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeTransport extends DeviceTransport {
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

  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;

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
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateCtrl.close();
  }
}

class _TestProtocolService extends ProtocolService {
  final StreamController<Message> controller =
      StreamController<Message>.broadcast();

  _TestProtocolService() : super(_FakeTransport());

  @override
  Stream<Message> get messageStream => controller.stream;

  void emit(Message m) => controller.add(m);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'primary_ch_${_testPid}_${_testDbSeq++}.db');
}

Future<
  ({
    ProviderContainer container,
    _TestProtocolService protocol,
    MessageDatabase storage,
  })
>
_createTestHarness({int myNodeNum = 20}) async {
  SharedPreferences.setMockInitialValues({});

  final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
  await storage.init();

  final testProtocol = _TestProtocolService();

  final container = ProviderContainer(
    overrides: [
      messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
      protocolServiceProvider.overrideWithValue(testProtocol),
    ],
  );

  final notifier = container.read(messagesProvider.notifier);
  await notifier.storageReady;
  notifier.state = [];
  container.read(myNodeNumProvider.notifier).state = myNodeNum;

  return (container: container, protocol: testProtocol, storage: storage);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  // -----------------------------------------------------------------------
  // Conversation key tests
  // -----------------------------------------------------------------------

  group('conversationKey — Primary Channel', () {
    test('broadcast on channel 0 gets conversation key channel:0', () {
      final msg = Message(
        from: 10,
        to: 0xFFFFFFFF, // broadcast
        text: 'hello mesh',
        timestamp: DateTime.now(),
        channel: 0,
        received: true,
      );
      expect(MessageDatabase.conversationKey(msg), 'channel:0');
    });

    test('broadcast on channel 0 with null channel gets channel:0', () {
      // Protobuf default: channel field not set → null, but
      // message.isBroadcast determines it's a channel message.
      final msg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'hello mesh',
        timestamp: DateTime.now(),
        channel: null,
        received: true,
      );
      expect(MessageDatabase.conversationKey(msg), 'channel:0');
    });

    test('broadcast on channel 2 gets channel:2', () {
      final msg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'hello mesh',
        timestamp: DateTime.now(),
        channel: 2,
        received: true,
      );
      expect(MessageDatabase.conversationKey(msg), 'channel:2');
    });

    test('DM on channel 0 gets DM conversation key', () {
      final msg = Message(
        from: 10,
        to: 20,
        text: 'private message',
        timestamp: DateTime.now(),
        channel: 0,
        received: true,
      );
      expect(MessageDatabase.conversationKey(msg), 'dm:10:20');
    });

    test('DM with null channel gets DM conversation key', () {
      final msg = Message(
        from: 10,
        to: 20,
        text: 'private message',
        timestamp: DateTime.now(),
        channel: null,
        received: true,
      );
      expect(MessageDatabase.conversationKey(msg), 'dm:10:20');
    });
  });

  group('conversationKeyFromParams', () {
    test('channel 0 returns channel:0', () {
      expect(
        MessageDatabase.conversationKeyFromParams(channel: 0),
        'channel:0',
      );
    });

    test('channel 3 returns channel:3', () {
      expect(
        MessageDatabase.conversationKeyFromParams(channel: 3),
        'channel:3',
      );
    });

    test('null channel with nodes returns DM key', () {
      expect(
        MessageDatabase.conversationKeyFromParams(nodeA: 5, nodeB: 10),
        'dm:5:10',
      );
    });
  });

  // -----------------------------------------------------------------------
  // Notification classification
  // -----------------------------------------------------------------------

  group('PendingMessageNotification.isChannelMessage', () {
    test(
      'channelIndex 0 (Primary Channel) is classified as channel message',
      () {
        final msg = PendingMessageNotification(
          senderName: 'Test',
          message: 'hello',
          fromNodeNum: 1234,
          channelIndex: 0,
          channelName: 'Primary',
        );
        expect(msg.isChannelMessage, isTrue);
      },
    );

    test('channelIndex 2 is classified as channel message', () {
      final msg = PendingMessageNotification(
        senderName: 'Test',
        message: 'hello',
        fromNodeNum: 1234,
        channelIndex: 2,
        channelName: 'LongFast',
      );
      expect(msg.isChannelMessage, isTrue);
    });

    test('null channelIndex is NOT classified as channel message', () {
      final msg = PendingMessageNotification(
        senderName: 'Test',
        message: 'hello',
        fromNodeNum: 1234,
      );
      expect(msg.isChannelMessage, isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // Content dedup across push / mesh paths
  // -----------------------------------------------------------------------

  group('content dedup — Primary Channel', () {
    test(
      'broadcast message on channel 0 from push, then mesh → deduped',
      () async {
        final h = await _createTestHarness();
        addTearDown(h.container.dispose);

        final now = DateTime.now();

        // Push notification arrives first — channel 0, broadcast.
        final pushMsg = Message(
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Primary channel hello',
          timestamp: now,
          channel: 0,
          received: true,
        );
        h.container.read(messagesProvider.notifier).addMessage(pushMsg);

        expect(
          h.container
              .read(messagesProvider)
              .where((m) => m.text == pushMsg.text)
              .length,
          1,
        );

        // Same message via device protocol (different id, same content).
        final meshMsg = Message(
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Primary channel hello',
          timestamp: now,
          channel: 0,
          received: true,
          packetId: 99,
        );
        expect(meshMsg.id, isNot(equals(pushMsg.id)));

        h.container.read(messagesProvider.notifier).addMessage(meshMsg);

        // Still one copy — content dedup caught it.
        expect(
          h.container
              .read(messagesProvider)
              .where((m) => m.text == pushMsg.text)
              .length,
          1,
        );
      },
    );

    test(
      'DM dedup still works: push to=localNode, mesh to=localNode',
      () async {
        final h = await _createTestHarness(myNodeNum: 20);
        addTearDown(h.container.dispose);

        final now = DateTime.now();

        final pushMsg = Message(
          from: 10,
          to: 20, // local node
          text: 'DM to me',
          timestamp: now,
          channel: null,
          received: true,
        );
        h.container.read(messagesProvider.notifier).addMessage(pushMsg);

        final meshMsg = Message(
          from: 10,
          to: 20,
          text: 'DM to me',
          timestamp: now,
          channel: null,
          received: true,
          packetId: 100,
        );
        h.container.read(messagesProvider.notifier).addMessage(meshMsg);

        expect(
          h.container
              .read(messagesProvider)
              .where((m) => m.text == 'DM to me')
              .length,
          1,
        );
      },
    );

    test('messages on different channels are NOT deduped', () async {
      final h = await _createTestHarness();
      addTearDown(h.container.dispose);

      final now = DateTime.now();

      final ch0Msg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'same text',
        timestamp: now,
        channel: 0,
        received: true,
      );
      h.container.read(messagesProvider.notifier).addMessage(ch0Msg);

      final ch1Msg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'same text',
        timestamp: now,
        channel: 1,
        received: true,
      );
      h.container.read(messagesProvider.notifier).addMessage(ch1Msg);

      // Both should exist — different channels.
      expect(
        h.container
            .read(messagesProvider)
            .where((m) => m.text == 'same text')
            .length,
        2,
      );
    });

    test('DMs from different senders with same text are NOT deduped', () async {
      final h = await _createTestHarness(myNodeNum: 20);
      addTearDown(h.container.dispose);

      final now = DateTime.now();

      // DM to me from node 10.
      final dmA = Message(
        from: 10,
        to: 20,
        text: 'hello',
        timestamp: now,
        channel: null,
        received: true,
      );
      h.container.read(messagesProvider.notifier).addMessage(dmA);

      // DM to me from node 30 — different sender, same text.
      final dmB = Message(
        from: 30,
        to: 20,
        text: 'hello',
        timestamp: now,
        channel: null,
        received: true,
      );
      h.container.read(messagesProvider.notifier).addMessage(dmB);

      // Both should exist — different senders.
      expect(
        h.container
            .read(messagesProvider)
            .where((m) => m.text == 'hello')
            .length,
        2,
      );
    });
  });

  // -----------------------------------------------------------------------
  // Storage persistence for Primary Channel
  // -----------------------------------------------------------------------

  group('storage — Primary Channel persistence', () {
    test(
      'Primary Channel message persisted and loaded with correct key',
      () async {
        final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
        await storage.init();

        final msg = Message(
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Primary channel stored',
          timestamp: DateTime.now(),
          channel: 0,
          received: true,
        );

        await storage.saveMessage(msg);
        final loaded = await storage.loadMessages();

        expect(loaded.any((m) => m.text == 'Primary channel stored'), isTrue);
      },
    );

    test(
      'Primary Channel message loadable via loadConversation("channel:0")',
      () async {
        final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
        await storage.init();

        final msg = Message(
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Load by conv key',
          timestamp: DateTime.now(),
          channel: 0,
          received: true,
        );

        await storage.saveMessage(msg);
        final convMessages = await storage.loadConversation('channel:0');

        expect(convMessages.length, 1);
        expect(convMessages.first.text, 'Load by conv key');
      },
    );
  });

  // -----------------------------------------------------------------------
  // Migrated + live messages coexistence
  // -----------------------------------------------------------------------

  group('migrated + live messages in provider', () {
    test(
      'pre-existing DB messages and new live messages coexist in state',
      () async {
        // Simulate cold start: messages already in DB, then new ones arrive.
        final h = await _createTestHarness();
        addTearDown(h.container.dispose);

        // Directly save a message to storage (simulating migrated row).
        final oldMsg = Message(
          id: 'old-migrated',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'Old migrated message',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          channel: 0,
          received: true,
        );
        await h.storage.saveMessage(oldMsg);

        // Force rehydrate from storage (simulating app restart load).
        final notifier = h.container.read(messagesProvider.notifier);
        await notifier.forceRehydrateAllFromStorage();

        // Verify old message is in state.
        expect(
          h.container.read(messagesProvider).any((m) => m.id == 'old-migrated'),
          isTrue,
        );

        // Now a new live message arrives.
        final newMsg = Message(
          from: 30,
          to: 0xFFFFFFFF,
          text: 'New live message',
          timestamp: DateTime.now(),
          channel: 0,
          received: true,
        );
        notifier.addMessage(newMsg);

        // Both messages should be in state.
        final state = h.container.read(messagesProvider);
        expect(state.any((m) => m.id == 'old-migrated'), isTrue);
        expect(state.any((m) => m.text == 'New live message'), isTrue);
      },
    );
  });

  // -----------------------------------------------------------------------
  // Unread counts for Primary Channel
  // -----------------------------------------------------------------------

  group('unread counts — Primary Channel', () {
    test('unread channel count includes channel 0 messages', () async {
      final h = await _createTestHarness(myNodeNum: 20);
      addTearDown(h.container.dispose);

      final msg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'Unread ch0 message',
        timestamp: DateTime.now(),
        channel: 0,
        received: true,
        read: false,
      );
      h.container.read(messagesProvider.notifier).addMessage(msg);

      final totalUnread = h.container.read(unreadChannelCountProvider);
      expect(totalUnread, 1);

      final perChannel = h.container.read(channelUnreadCountsProvider);
      expect(perChannel[0], 1);
    });

    test('marking channel 0 as read clears unread count', () async {
      final h = await _createTestHarness(myNodeNum: 20);
      addTearDown(h.container.dispose);

      final msg = Message(
        from: 10,
        to: 0xFFFFFFFF,
        text: 'Will be read',
        timestamp: DateTime.now(),
        channel: 0,
        received: true,
        read: false,
      );
      h.container.read(messagesProvider.notifier).addMessage(msg);
      expect(h.container.read(unreadChannelCountProvider), 1);

      h.container.read(messagesProvider.notifier).markChannelAsRead(0);
      expect(h.container.read(unreadChannelCountProvider), 0);
      expect(h.container.read(channelUnreadCountsProvider)[0], isNull);
    });
  });

  // -----------------------------------------------------------------------
  // Trimming stability after migration
  // -----------------------------------------------------------------------

  group('trimming — post-migration stability', () {
    test('saving new message on channel:0 trims oldest beyond limit', () async {
      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
      await storage.init();

      // Insert max messages under channel:0.
      final limit = MessageDatabase.maxMessagesPerConversation;
      for (var i = 0; i < limit; i++) {
        await storage.saveMessage(
          Message(
            id: 'trim-$i',
            from: 10,
            to: 0xFFFFFFFF,
            text: 'Message $i',
            timestamp: DateTime(2025, 1, 1).add(Duration(minutes: i)),
            channel: 0,
            received: true,
          ),
        );
      }

      // Save one more — should trim the oldest.
      await storage.saveMessage(
        Message(
          id: 'trim-new',
          from: 10,
          to: 0xFFFFFFFF,
          text: 'New message',
          timestamp: DateTime(2025, 1, 1).add(Duration(minutes: limit)),
          channel: 0,
          received: true,
        ),
      );

      final ch0 = await storage.loadConversation('channel:0');
      expect(ch0.length, limit);
      // Oldest (trim-0) should be gone.
      expect(ch0.any((m) => m.id == 'trim-0'), isFalse);
      // Newest should be present.
      expect(ch0.any((m) => m.id == 'trim-new'), isTrue);
    });
  });
}
