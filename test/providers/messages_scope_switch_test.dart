// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Switching radio scope (for example turning on data sharing with another
// radio) reopens the message store as a new instance. The in-memory list
// must be reloaded from that store, not left empty until the next launch.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
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

  @override
  Stream<Message> get messageStream => const Stream.empty();
}

int _dbSeq = 0;

Future<MessageDatabase> _storeWith(String id) async {
  final path = p.join(
    Directory.systemTemp.path,
    'msg_scope_switch_${pid}_${_dbSeq++}.db',
  );
  final store = MessageDatabase(testDbPath: path);
  await store.init();
  await store.saveMessage(
    Message(id: id, from: 10, to: 20, text: id, timestamp: DateTime(2026, 10)),
  );
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => databaseFactory = databaseFactoryFfi);

  test('a radio scope switch reloads messages from the new store', () async {
    SharedPreferences.setMockInitialValues({});
    final radioX = await _storeWith('stored-for-x');
    final radioT = await _storeWith('stored-for-t');
    final protocol = _TestProtocolService();

    final container = ProviderContainer(
      overrides: [
        messageStorageProvider.overrideWithValue(AsyncValue.data(radioX)),
        protocolServiceProvider.overrideWithValue(protocol),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(messagesProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(messagesProvider.notifier).storageReady;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(messagesProvider).map((m) => m.id), ['stored-for-x']);

    container.updateOverrides([
      messageStorageProvider.overrideWithValue(AsyncValue.data(radioT)),
      protocolServiceProvider.overrideWithValue(protocol),
    ]);
    container.read(messagesProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(container.read(messagesProvider).map((m) => m.id), ['stored-for-t']);
  });
}
