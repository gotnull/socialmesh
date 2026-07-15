// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Regression coverage for offline-composed messages orphaned by an app
// restart. The offline queue is in-memory only, so a persisted `pending`
// bubble whose queue entry died with the process must surface as `failed`
// (retry affordance) on the next load instead of looking queued forever.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/messaging/offline_queue_service.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/message_database.dart';

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

  @override
  Stream<Message> get messageStream => const Stream.empty();
}

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() {
  final dir = Directory.systemTemp.path;
  return p.join(dir, 'pending_restart_${_testPid}_${_testDbSeq++}.db');
}

Message _outbound(String id, MessageStatus status) => Message(
  id: id,
  from: 20,
  to: 0xFFFFFFFF,
  text: 'msg-$id',
  timestamp: DateTime.now(),
  channel: 1,
  sent: true,
  status: status,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    // OfflineQueueService is a singleton shared across tests.
    OfflineQueueService().clear();
  });

  Future<ProviderContainer> containerWith(MessageDatabase storage) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
        protocolServiceProvider.overrideWithValue(_TestProtocolService()),
      ],
    );
    await container.read(messagesProvider.notifier).storageReady;
    return container;
  }

  test(
    'orphaned pending outbound messages load as failed with error',
    () async {
      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
      await storage.init();
      await storage.saveMessage(_outbound('stuck', MessageStatus.pending));
      await storage.saveMessage(_outbound('retrying', MessageStatus.retrying));
      await storage.saveMessage(_outbound('done', MessageStatus.delivered));

      final container = await containerWith(storage);
      addTearDown(container.dispose);

      final state = container.read(messagesProvider);
      final stuck = state.firstWhere((m) => m.id == 'stuck');
      expect(stuck.status, MessageStatus.failed);
      expect(stuck.errorMessage, isNotNull);
      expect(stuck.errorMessage, isNotEmpty);

      expect(
        state.firstWhere((m) => m.id == 'retrying').status,
        MessageStatus.unconfirmed,
      );
      expect(
        state.firstWhere((m) => m.id == 'done').status,
        MessageStatus.delivered,
      );

      // The conversion must be persisted, not state-only: device
      // reconcile paths re-read storage rows and would resurrect a
      // stale pending row on reconnect.
      final persisted = await storage.loadMessages();
      final persistedStuck = persisted.firstWhere((m) => m.id == 'stuck');
      expect(persistedStuck.status, MessageStatus.failed);
      expect(persistedStuck.errorMessage, isNotNull);
    },
  );

  test('pending inbound rows are not converted', () async {
    final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
    await storage.init();
    final inbound = Message(
      id: 'inbound',
      from: 10,
      to: 20,
      text: 'incoming',
      timestamp: DateTime.now(),
      channel: 0,
      received: true,
      status: MessageStatus.pending,
    );
    await storage.saveMessage(inbound);

    final container = await containerWith(storage);
    addTearDown(container.dispose);

    final state = container.read(messagesProvider);
    expect(
      state.firstWhere((m) => m.id == 'inbound').status,
      MessageStatus.pending,
    );
  });

  test(
    'pending messages still held by the live queue are left alone',
    () async {
      final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
      await storage.init();
      await storage.saveMessage(_outbound('queued', MessageStatus.pending));

      OfflineQueueService().enqueue(
        QueuedMessage(
          id: 'queued',
          text: 'msg-queued',
          to: 0xFFFFFFFF,
          channel: 1,
          wantAck: true,
        ),
      );

      final container = await containerWith(storage);
      addTearDown(container.dispose);

      final state = container.read(messagesProvider);
      expect(
        state.firstWhere((m) => m.id == 'queued').status,
        MessageStatus.pending,
      );
      OfflineQueueService().clear();
    },
  );
}
