// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

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
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/storage/message_database.dart';

/// Regression tests for the `_messageSubscription` null-discipline bug
/// (commits 78b6a52b → 7bc1dc8e). The invariant: when `ref.onDispose`
/// fires between `build()` re-runs, the subscription field MUST be set
/// to `null` after cancel. Otherwise the `_subscribeToStreams` skip-
/// guard sees a cancelled-but-non-null subscription and stops re-
/// wiring, permanently breaking incoming-message processing on the
/// broadcast stream (broadcast streams don't buffer — missed events
/// are lost forever).
class _FakeTransport extends DeviceTransport {
  final StreamController<DeviceConnectionState> _stateCtrl =
      StreamController<DeviceConnectionState>.broadcast();

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

  @override
  Stream<DeviceConnectionState> get stateStream => _stateCtrl.stream;

  @override
  Stream<List<int>> get dataStream => const Stream<List<int>>.empty();

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
    await _stateCtrl.close();
  }
}

/// Test protocol that exposes a controllable broadcast `messageStream`
/// without instantiating the real Meshtastic decoder. Lets the test
/// push synthetic Message instances at well-defined points in the
/// lifecycle.
class _ControllableProtocolService extends ProtocolService {
  _ControllableProtocolService() : super(_FakeTransport());

  final StreamController<Message> _ctrl = StreamController<Message>.broadcast();

  @override
  Stream<Message> get messageStream => _ctrl.stream;

  void emit(Message m) => _ctrl.add(m);

  Future<void> closeStream() => _ctrl.close();

  bool get hasListener => _ctrl.hasListener;
}

int _testDbSeq = 0;
final int _testPid = pid;

String _uniqueDbPath() {
  return p.join(
    Directory.systemTemp.path,
    'msg_lifecycle_${_testPid}_${_testDbSeq++}.db',
  );
}

Message _msg(int packetId, {int from = 0x42, String text = 'hi'}) {
  return Message(
    id: 'pkt-${from.toRadixString(16)}-${packetId.toRadixString(16)}',
    from: from,
    to: 0xFFFFFFFF,
    channel: 1,
    text: text,
    timestamp: DateTime.now(),
    sent: false,
    received: true,
    packetId: packetId,
  );
}

Future<MessageDatabase> _buildStorage() async {
  final storage = MessageDatabase(testDbPath: _uniqueDbPath());
  await storage.init();
  return storage;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'global ingestion survives a chat-screen consumer being disposed',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await _buildStorage();
      final protocol = _ControllableProtocolService();

      final container = ProviderContainer(
        overrides: [
          messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
          protocolServiceProvider.overrideWithValue(protocol),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(protocol.closeStream);

      // Force the notifier to build and load storage.
      container.read(messagesProvider.notifier);
      await container.read(messagesProvider.notifier).storageReady;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        protocol.hasListener,
        isTrue,
        reason: 'global notifier should hold the receive subscription',
      );

      // Simulate a chat-screen consumer subscribing then unsubscribing.
      final sub = container.listen<List<Message>>(messagesProvider, (_, _) {});
      sub.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Global subscription must still be alive — receive ingestion is
      // session-scoped, not screen-scoped.
      expect(
        protocol.hasListener,
        isTrue,
        reason: 'screen consumer disposal must not cancel global ingestion',
      );

      // And new messages still flow.
      protocol.emit(_msg(0x101, text: 'after-dispose'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final msgs = container.read(messagesProvider);
      expect(msgs.any((m) => m.text == 'after-dispose'), isTrue);
    },
  );

  test('messages flow through after build() runs and storage resolves '
      '(regression for null-discipline bug 78b6a52b/7bc1dc8e)', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await _buildStorage();
    final protocol = _ControllableProtocolService();

    final container = ProviderContainer(
      overrides: [
        messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
        protocolServiceProvider.overrideWithValue(protocol),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(protocol.closeStream);

    // Trigger build + storage load.
    container.read(messagesProvider.notifier);
    await container.read(messagesProvider.notifier).storageReady;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(protocol.hasListener, isTrue);

    // First message — should land.
    protocol.emit(_msg(0x201, text: 'first'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      container.read(messagesProvider).any((m) => m.text == 'first'),
      isTrue,
    );

    // Second message — exercises the same listener after the load
    // completer is satisfied.  The original bug would have left the
    // subscription cancelled-but-non-null, breaking this path.
    protocol.emit(_msg(0x202, text: 'second'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      container.read(messagesProvider).any((m) => m.text == 'second'),
      isTrue,
      reason: 'subscription must remain functional across stream events',
    );

    // _addMessageToState must update lastInsertAt for failure-class
    // C disambiguation.
    expect(container.read(messagesProvider.notifier).lastInsertAt, isNotNull);
  });

  test(
    'multiple messages flow through the same listener back-to-back '
    '(no skip-guard / null-discipline regression on repeated events)',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = await _buildStorage();
      final protocol = _ControllableProtocolService();

      final container = ProviderContainer(
        overrides: [
          messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
          protocolServiceProvider.overrideWithValue(protocol),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(protocol.closeStream);

      container.read(messagesProvider.notifier);
      await container.read(messagesProvider.notifier).storageReady;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Burst three messages through the listener. The bug fixed in
      // 7bc1dc8e would have left the listener cancelled-but-non-null
      // after a build/dispose cycle, dropping every subsequent event
      // silently because broadcast streams don't buffer.
      protocol.emit(_msg(0x301, text: 'one'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      protocol.emit(_msg(0x302, text: 'two'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      protocol.emit(_msg(0x303, text: 'three'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final msgs = container.read(messagesProvider);
      expect(msgs.any((m) => m.text == 'one'), isTrue);
      expect(msgs.any((m) => m.text == 'two'), isTrue);
      expect(
        msgs.any((m) => m.text == 'three'),
        isTrue,
        reason: 'broadcast listener must remain functional across events',
      );
    },
  );

  test('lastInsertAt is null until the first message is processed', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await _buildStorage();
    final protocol = _ControllableProtocolService();

    final container = ProviderContainer(
      overrides: [
        messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
        protocolServiceProvider.overrideWithValue(protocol),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(protocol.closeStream);

    container.read(messagesProvider.notifier);
    await container.read(messagesProvider.notifier).storageReady;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(container.read(messagesProvider.notifier).lastInsertAt, isNull);

    protocol.emit(_msg(0x401, text: 'first-insert'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(container.read(messagesProvider.notifier).lastInsertAt, isNotNull);
  });

  test('restart simulation — re-creating the notifier reloads persisted '
      'channel messages from storage before processing live stream', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await _buildStorage();
    final protocol = _ControllableProtocolService();

    // First lifetime: ingest one message, persist it via the notifier.
    final container1 = ProviderContainer(
      overrides: [
        messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
        protocolServiceProvider.overrideWithValue(protocol),
      ],
    );
    container1.read(messagesProvider.notifier);
    await container1.read(messagesProvider.notifier).storageReady;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    protocol.emit(_msg(0x501, text: 'pre-restart'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      container1.read(messagesProvider).any((m) => m.text == 'pre-restart'),
      isTrue,
    );
    container1.dispose();

    // Second lifetime: fresh container, same storage. Persisted
    // message must reappear after _loadFromStorage completes.
    final protocol2 = _ControllableProtocolService();
    final container2 = ProviderContainer(
      overrides: [
        messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
        protocolServiceProvider.overrideWithValue(protocol2),
      ],
    );
    addTearDown(container2.dispose);
    addTearDown(protocol2.closeStream);

    container2.read(messagesProvider.notifier);
    await container2.read(messagesProvider.notifier).storageReady;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      container2.read(messagesProvider).any((m) => m.text == 'pre-restart'),
      isTrue,
      reason: 'persisted channel messages must survive a notifier restart',
    );
  });
}
