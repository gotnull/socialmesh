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
import 'package:socialmesh/services/storage/conversation_read_position.dart';
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

  @override
  Stream<Message> get messageStream => const Stream.empty();
}

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'conv_timeline_${_testPid}_${_testDbSeq++}.db');
}

Future<({ProviderContainer container, MessageDatabase storage})>
_createHarness({MessageDatabase? storage, int myNodeNum = 10}) async {
  SharedPreferences.setMockInitialValues({});

  final messageStorage =
      storage ?? MessageDatabase(testDbPath: _uniqueTestDbPath());
  await messageStorage.init();

  final container = ProviderContainer(
    overrides: [
      messageStorageProvider.overrideWithValue(AsyncValue.data(messageStorage)),
      protocolServiceProvider.overrideWithValue(_TestProtocolService()),
    ],
  );

  container.read(myNodeNumProvider.notifier).state = myNodeNum;
  await container.read(messagesProvider.notifier).storageReady;

  return (container: container, storage: messageStorage);
}

Future<void> _seedDmConversation(
  MessageDatabase storage, {
  required int count,
  int myNodeNum = 10,
  int peerNodeNum = 20,
}) async {
  final base = DateTime(2026, 4, 12, 8, 0);
  final messages = <Message>[];
  for (var index = 0; index < count; index++) {
    final label = 'message-${index.toString().padLeft(3, '0')}';
    messages.add(
      Message(
        id: label,
        from: peerNodeNum,
        to: myNodeNum,
        text: label,
        timestamp: base.add(Duration(minutes: index)),
        packetId: 1000 + index,
        received: true,
        senderLongName: 'Peer Node',
        senderShortName: 'PEER',
        senderAvatarColor: 0xFF3366FF,
      ),
    );
  }
  await storage.saveMessages(messages);
}

ConversationReadPosition _savedPosition({
  required String anchorMessageId,
  required int anchorIndex,
  bool wasNearLatest = false,
}) {
  return ConversationReadPosition(
    conversationKey: 'dm:10:20',
    anchorMessageId: anchorMessageId,
    anchorTimestamp: DateTime(
      2026,
      4,
      12,
      8,
      0,
    ).add(Duration(minutes: anchorIndex)),
    anchorAlignment: 0.82,
    wasNearLatest: wasNearLatest,
    updatedAt: DateTime(2026, 4, 12, 10, 0),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('restore chooses latest when saved state says near latest', () async {
    final h = await _createHarness();
    addTearDown(h.container.dispose);

    await _seedDmConversation(h.storage, count: 30);
    await h.storage.saveConversationReadPosition(
      _savedPosition(
        anchorMessageId: 'message-028',
        anchorIndex: 28,
        wasNearLatest: true,
      ),
    );

    final query = const ConversationTimelineQuery.direct(
      peerNodeNum: 20,
      myNodeNum: 10,
    );
    final target = await h.container
        .read(conversationTimelineControllerProvider.notifier)
        .resolveInitialRestoreTarget(query);

    expect(target.kind, ConversationRestoreKind.latest);
    expect(target.messageId, isNull);
    expect(target.hasNewerMessages, isFalse);
  });

  test(
    'restore chooses the saved anchor when user was reading history',
    () async {
      final h = await _createHarness();
      addTearDown(h.container.dispose);

      await _seedDmConversation(h.storage, count: 30);
      await h.storage.saveConversationReadPosition(
        _savedPosition(anchorMessageId: 'message-012', anchorIndex: 12),
      );

      final query = const ConversationTimelineQuery.direct(
        peerNodeNum: 20,
        myNodeNum: 10,
      );
      final target = await h.container
          .read(conversationTimelineControllerProvider.notifier)
          .resolveInitialRestoreTarget(query);

      expect(target.kind, ConversationRestoreKind.anchor);
      expect(target.messageId, 'message-012');
      expect(target.hasNewerMessages, isTrue);
    },
  );

  test('restore paginates older history until the anchor is found', () async {
    final h = await _createHarness();
    addTearDown(h.container.dispose);

    await _seedDmConversation(h.storage, count: 140);
    await h.storage.saveConversationReadPosition(
      _savedPosition(anchorMessageId: 'message-018', anchorIndex: 18),
    );

    final query = const ConversationTimelineQuery.direct(
      peerNodeNum: 20,
      myNodeNum: 10,
    );
    await h.container
        .read(conversationTimelineControllerProvider.notifier)
        .ensureInitialized(query);

    final initialState = h.container.read(
      conversationTimelineStateProvider(query),
    );
    expect(initialState, isNotNull);
    final initialValue = initialState?.asData?.value;
    expect(initialValue, isNotNull);
    expect(initialValue!.rawMessages, hasLength(80));
    expect(initialValue.containsMessageId('message-018'), isFalse);

    final target = await h.container
        .read(conversationTimelineControllerProvider.notifier)
        .resolveInitialRestoreTarget(query);
    final restoredState = h.container.read(
      conversationTimelineStateProvider(query),
    );
    final restoredValue = restoredState?.asData?.value;

    expect(target.kind, ConversationRestoreKind.anchor);
    expect(target.messageId, 'message-018');
    expect(restoredValue, isNotNull);
    expect(restoredValue!.containsMessageId('message-018'), isTrue);
    expect(restoredValue.rawMessages.length, greaterThan(80));
  });

  test(
    'restore falls back to the nearest earlier message when anchor is missing',
    () async {
      final h = await _createHarness();
      addTearDown(h.container.dispose);

      await _seedDmConversation(h.storage, count: 40);
      await h.storage.saveConversationReadPosition(
        ConversationReadPosition(
          conversationKey: 'dm:10:20',
          anchorMessageId: 'missing-anchor',
          anchorTimestamp: DateTime(2026, 4, 12, 8, 20, 30),
          anchorAlignment: 0.8,
          wasNearLatest: false,
          updatedAt: DateTime(2026, 4, 12, 10, 0),
        ),
      );

      final query = const ConversationTimelineQuery.direct(
        peerNodeNum: 20,
        myNodeNum: 10,
      );
      final target = await h.container
          .read(conversationTimelineControllerProvider.notifier)
          .resolveInitialRestoreTarget(query);

      expect(target.kind, ConversationRestoreKind.fallback);
      expect(target.messageId, 'message-020');
      expect(target.hasNewerMessages, isTrue);
    },
  );

  test(
    'saving a read position does not change unread message counts',
    () async {
      final h = await _createHarness();
      addTearDown(h.container.dispose);

      await _seedDmConversation(h.storage, count: 6);
      final unreadBefore = h.container.read(unreadMessagesCountProvider);

      final query = const ConversationTimelineQuery.direct(
        peerNodeNum: 20,
        myNodeNum: 10,
      );
      await h.container
          .read(conversationTimelineControllerProvider.notifier)
          .saveReadPosition(
            query,
            _savedPosition(anchorMessageId: 'message-003', anchorIndex: 3),
          );

      final unreadAfter = h.container.read(unreadMessagesCountProvider);
      expect(unreadAfter, unreadBefore);
    },
  );
}
