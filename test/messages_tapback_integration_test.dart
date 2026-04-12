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
      await _settle();

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
      await _settle();
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
      await _settle();

      final rows = await _loadDmRows(h.storage);
      expect(rows.single.tapbacks, hasLength(1));
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
