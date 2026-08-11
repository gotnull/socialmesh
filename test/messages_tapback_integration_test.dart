// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/messaging/conversation_timeline.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/message_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  _TestProtocolService() : super(_FakeTransport());

  final StreamController<Message> controller =
      StreamController<Message>.broadcast();

  @override
  Stream<Message> get messageStream => controller.stream;

  void emit(Message message) => controller.add(message);
}

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'msg_tapback_${_testPid}_${_testDbSeq++}.db');
}

Future<
  ({
    ProviderContainer container,
    _TestProtocolService protocol,
    MessageDatabase storage,
  })
>
_createHarness({
  MessageDatabase? storage,
  int myNodeNum = 20,
  bool clearState = true,
}) async {
  SharedPreferences.setMockInitialValues({});

  final messageStorage =
      storage ?? MessageDatabase(testDbPath: _uniqueTestDbPath());
  await messageStorage.init();

  final protocol = _TestProtocolService();
  final container = ProviderContainer(
    overrides: [
      messageStorageProvider.overrideWithValue(AsyncValue.data(messageStorage)),
      protocolServiceProvider.overrideWithValue(protocol),
    ],
  );

  final notifier = container.read(messagesProvider.notifier);
  await notifier.storageReady;
  if (clearState) {
    notifier.state = [];
  }
  container.read(myNodeNumProvider.notifier).state = myNodeNum;

  return (container: container, protocol: protocol, storage: messageStorage);
}

Message _message({
  required String id,
  required int from,
  required int to,
  required String text,
  required int packetId,
  DateTime? timestamp,
  int? replyId,
  bool isEmoji = false,
}) {
  return Message(
    id: id,
    from: from,
    to: to,
    text: text,
    packetId: packetId,
    replyId: replyId,
    isEmoji: isEmoji,
    received: true,
    timestamp: timestamp ?? DateTime.now(),
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

Future<void> _waitForMessagePersisted(
  MessageDatabase storage,
  String messageId, {
  int nodeA = 10,
  int nodeB = 20,
  String? conversationKey,
  Duration timeout = const Duration(seconds: 2),
}) async {
  final key =
      conversationKey ??
      MessageDatabase.conversationKeyFromParams(nodeA: nodeA, nodeB: nodeB);
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final stored = await storage.loadConversation(key);
    if (stored.any((message) => message.id == messageId)) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError(
    'Message $messageId not persisted within ${timeout.inMilliseconds}ms',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'canonical tapbacks stay out of messagesProvider but appear in the grouped timeline',
    () async {
      final h = await _createHarness();
      addTearDown(h.container.dispose);

      final notifier = h.container.read(messagesProvider.notifier);
      final parent = _message(
        id: 'parent',
        from: 10,
        to: 20,
        text: 'Hello',
        packetId: 100,
      );
      notifier.addMessage(parent);

      h.protocol.emit(
        _message(
          id: 'tapback',
          from: 10,
          to: 20,
          text: '👍',
          packetId: 101,
          replyId: 100,
          isEmoji: true,
        ),
      );
      await _waitForMessagePersisted(h.storage, 'tapback');

      final state = h.container.read(messagesProvider);
      expect(state.map((message) => message.id), ['parent']);

      final stored = await h.storage.loadConversation(
        MessageDatabase.conversationKeyFromParams(nodeA: 10, nodeB: 20),
      );
      expect(stored.map((message) => message.id), contains('tapback'));

      final rows = await _loadDmRows(h.storage);
      expect(rows, hasLength(1));
      expect(rows.single.tapbacks.map((tapback) => tapback.id), ['tapback']);
    },
  );

  test(
    'persisted canonical tapbacks survive restart and remain grouped',
    () async {
      final first = await _createHarness();

      first.container
          .read(messagesProvider.notifier)
          .addMessage(
            _message(
              id: 'parent',
              from: 10,
              to: 20,
              text: 'Hello again',
              packetId: 100,
            ),
          );
      first.protocol.emit(
        _message(
          id: 'tapback',
          from: 10,
          to: 20,
          text: '😂',
          packetId: 101,
          replyId: 100,
          isEmoji: true,
        ),
      );
      await _waitForMessagePersisted(first.storage, 'tapback');
      first.container.dispose();

      final second = await _createHarness(
        storage: first.storage,
        clearState: false,
      );
      addTearDown(second.container.dispose);

      final state = second.container.read(messagesProvider);
      expect(state.map((message) => message.id), ['parent']);

      final rows = await _loadDmRows(second.storage);
      expect(rows.single.tapbacks.map((tapback) => tapback.id), ['tapback']);
    },
  );

  test('standalone emoji messages remain visible', () async {
    final h = await _createHarness();
    addTearDown(h.container.dispose);

    h.protocol.emit(
      _message(
        id: 'standalone',
        from: 10,
        to: 20,
        text: '👍',
        packetId: 100,
        isEmoji: true,
      ),
    );
    await _settle();

    final state = h.container.read(messagesProvider);
    expect(state.map((message) => message.id), ['standalone']);

    final rows = await _loadDmRows(h.storage);
    expect(rows, hasLength(1));
    expect(rows.single.message?.id, 'standalone');
    expect(rows.single.tapbacks, isEmpty);
  });

  test(
    'duplicate canonical tapback replay does not duplicate grouped footer',
    () async {
      final h = await _createHarness();
      addTearDown(h.container.dispose);

      h.container
          .read(messagesProvider.notifier)
          .addMessage(
            _message(
              id: 'parent',
              from: 10,
              to: 20,
              text: 'Dedup parent',
              packetId: 100,
            ),
          );

      final tapback = _message(
        id: 'tapback',
        from: 10,
        to: 20,
        text: '👋',
        packetId: 101,
        replyId: 100,
        isEmoji: true,
      );
      h.protocol.emit(tapback);
      h.protocol.emit(tapback);
      await _waitForMessagePersisted(h.storage, 'tapback');
      await _settle();

      final rows = await _loadDmRows(h.storage);
      expect(rows.single.tapbacks, hasLength(1));
    },
  );

  // Broadcast rooms deliver in bursts and rxTime has one-second
  // resolution, so several members reacting with the same emoji in the
  // same second is normal traffic. The rapid-fire dedupe must key on
  // sender and replyId, not just channel + text + timestamp.
  test(
    'same-second same-emoji tapbacks from different senders all persist',
    () async {
      final h = await _createHarness();
      addTearDown(h.container.dispose);

      final second = DateTime.fromMillisecondsSinceEpoch(
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) * 1000,
      );
      const channelKey = 'channel:0';

      Message broadcast({
        required String id,
        required int from,
        required String text,
        required int packetId,
        int? replyId,
        bool isEmoji = false,
        required DateTime timestamp,
      }) {
        return Message(
          id: id,
          from: from,
          to: 0xFFFFFFFF,
          channel: 0,
          text: text,
          packetId: packetId,
          replyId: replyId,
          isEmoji: isEmoji,
          received: true,
          timestamp: timestamp,
        );
      }

      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(
        broadcast(
          id: 'parent-a',
          from: 10,
          text: 'Room message A',
          packetId: 100,
          timestamp: second.subtract(const Duration(seconds: 40)),
        ),
      );
      notifier.addMessage(
        broadcast(
          id: 'parent-b',
          from: 14,
          text: 'Room message B',
          packetId: 300,
          timestamp: second.subtract(const Duration(seconds: 30)),
        ),
      );

      // Three members react in the same second: two with the same emoji
      // to the same message, one with the same emoji to another message.
      h.protocol.emit(
        broadcast(
          id: 'tap-a',
          from: 11,
          text: '👍',
          packetId: 201,
          replyId: 100,
          isEmoji: true,
          timestamp: second,
        ),
      );
      h.protocol.emit(
        broadcast(
          id: 'tap-b',
          from: 12,
          text: '👍',
          packetId: 202,
          replyId: 100,
          isEmoji: true,
          timestamp: second,
        ),
      );
      h.protocol.emit(
        broadcast(
          id: 'tap-c',
          from: 13,
          text: '👍',
          packetId: 203,
          replyId: 300,
          isEmoji: true,
          timestamp: second,
        ),
      );

      for (final id in ['tap-a', 'tap-b', 'tap-c']) {
        await _waitForMessagePersisted(
          h.storage,
          id,
          conversationKey: channelKey,
        );
      }

      // Tapbacks never surface as standalone bubbles.
      expect(h.container.read(messagesProvider).map((m) => m.id), [
        'parent-a',
        'parent-b',
      ]);

      final rows = buildConversationTimelineRows(
        await h.storage.loadConversation(channelKey),
      );
      final parentA = rows.firstWhere((row) => row.message?.id == 'parent-a');
      final parentB = rows.firstWhere((row) => row.message?.id == 'parent-b');
      expect(parentA.tapbacks.map((tapback) => tapback.id), ['tap-a', 'tap-b']);
      expect(parentB.tapbacks.map((tapback) => tapback.id), ['tap-c']);
    },
  );

  test(
    'cross-path tapback copy with a different id is still deduped',
    () async {
      final h = await _createHarness();
      addTearDown(h.container.dispose);

      final timestamp = DateTime.now();
      const channelKey = 'channel:0';

      h.container
          .read(messagesProvider.notifier)
          .addMessage(
            Message(
              id: 'parent',
              from: 10,
              to: 0xFFFFFFFF,
              channel: 0,
              text: 'Room message',
              packetId: 100,
              received: true,
              timestamp: timestamp.subtract(const Duration(seconds: 30)),
            ),
          );

      h.protocol.emit(
        Message(
          id: 'tap-device',
          from: 11,
          to: 0xFFFFFFFF,
          channel: 0,
          text: '👍',
          packetId: 201,
          replyId: 100,
          isEmoji: true,
          received: true,
          timestamp: timestamp,
        ),
      );
      await _waitForMessagePersisted(
        h.storage,
        'tap-device',
        conversationKey: channelKey,
      );

      // The same physical reaction delivered again through another ingest
      // path: different row id, no packetId, but identical sender,
      // replyId, text, and timestamp.
      h.protocol.emit(
        Message(
          id: 'tap-replay',
          from: 11,
          to: 0xFFFFFFFF,
          channel: 0,
          text: '👍',
          replyId: 100,
          isEmoji: true,
          received: true,
          timestamp: timestamp,
        ),
      );
      await _settle();

      final stored = await h.storage.loadConversation(channelKey);
      expect(
        stored.where((message) => message.isCanonicalTapback).map((m) => m.id),
        ['tap-device'],
      );
    },
  );

  // State only ever holds non-tapback rows, so the content-fingerprint
  // layer can never legitimately match a canonical tapback - a member
  // posting an emoji as a message must not suppress a reaction that
  // happens to use the same emoji.
  test(
    'tapback sharing text with a recent regular message still persists',
    () async {
      final h = await _createHarness();
      addTearDown(h.container.dispose);

      final now = DateTime.now();
      const channelKey = 'channel:0';

      h.container
          .read(messagesProvider.notifier)
          .addMessage(
            Message(
              id: 'parent',
              from: 10,
              to: 0xFFFFFFFF,
              channel: 0,
              text: 'Room message',
              packetId: 100,
              received: true,
              timestamp: now.subtract(const Duration(seconds: 30)),
            ),
          );

      // The same member posts the emoji as a normal message, then reacts
      // with it moments later.
      h.protocol.emit(
        Message(
          id: 'emoji-message',
          from: 11,
          to: 0xFFFFFFFF,
          channel: 0,
          text: '👍',
          packetId: 201,
          isEmoji: true,
          received: true,
          timestamp: now.subtract(const Duration(seconds: 10)),
        ),
      );
      h.protocol.emit(
        Message(
          id: 'tapback',
          from: 11,
          to: 0xFFFFFFFF,
          channel: 0,
          text: '👍',
          packetId: 202,
          replyId: 100,
          isEmoji: true,
          received: true,
          timestamp: now,
        ),
      );
      await _waitForMessagePersisted(
        h.storage,
        'tapback',
        conversationKey: channelKey,
      );

      expect(h.container.read(messagesProvider).map((m) => m.id), [
        'parent',
        'emoji-message',
      ]);
    },
  );
}

Future<List<ConversationTimelineRow>> _loadDmRows(
  MessageDatabase storage,
) async {
  final rawMessages = await storage.loadConversation(
    MessageDatabase.conversationKeyFromParams(nodeA: 10, nodeB: 20),
  );
  return buildConversationTimelineRows(rawMessages);
}
