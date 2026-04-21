// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

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

  final StreamController<MessageDeliveryUpdate> testDelivery =
      StreamController<MessageDeliveryUpdate>.broadcast();

  @override
  Stream<Message> get messageStream => const Stream.empty();

  @override
  Stream<MessageDeliveryUpdate> get deliveryStream => testDelivery.stream;

  void emit(MessageDeliveryUpdate update) => testDelivery.add(update);
}

int _seq = 0;
String _uniqueDb() =>
    p.join(Directory.systemTemp.path, 'msg_realack_${pid}_${_seq++}.db');

Future<
  ({
    ProviderContainer container,
    MessageDatabase storage,
    _TestProtocolService protocol,
  })
>
_makeHarness() async {
  SharedPreferences.setMockInitialValues({});
  final storage = MessageDatabase(testDbPath: _uniqueDb());
  await storage.init();
  final protocol = _TestProtocolService();
  final container = ProviderContainer(
    overrides: [
      messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
      protocolServiceProvider.overrideWithValue(protocol),
    ],
  );
  await container.read(messageStorageProvider.future);
  // Force MessagesNotifier to initialize and subscribe to deliveryStream.
  container.read(messagesProvider);
  return (container: container, storage: storage, protocol: protocol);
}

Future<void> _pump(ProviderContainer container) async {
  // Let stream subscriptions flush through the event loop.
  await Future<void>.delayed(const Duration(milliseconds: 10));
}

Message _pendingDm({required String id, required int packetId}) => Message(
  id: id,
  from: 0x11111111,
  to: 0x22222222,
  text: 'hi',
  status: MessageStatus.pending,
  packetId: packetId,
);

Message _pendingBroadcast({required String id, required int packetId}) =>
    Message(
      id: id,
      from: 0x11111111,
      to: 0xFFFFFFFF,
      text: 'hi all',
      status: MessageStatus.pending,
      packetId: packetId,
      channel: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('implicit mesh ack marks DM delivered with realAck=false', () async {
    final h = await _makeHarness();
    final notifier = h.container.read(messagesProvider.notifier);
    final msg = _pendingDm(id: 'm1', packetId: 101);
    notifier.addMessage(msg);
    notifier.trackPacket(101, 'm1');

    h.protocol.emit(
      MessageDeliveryUpdate(packetId: 101, delivered: true, realAck: false),
    );
    await _pump(h.container);

    final out = h.container
        .read(messagesProvider)
        .firstWhere((m) => m.id == 'm1');
    expect(out.status, MessageStatus.delivered);
    expect(out.realAck, isFalse);
    h.container.dispose();
  });

  test('explicit recipient ack marks DM delivered with realAck=true', () async {
    final h = await _makeHarness();
    final notifier = h.container.read(messagesProvider.notifier);
    notifier.addMessage(_pendingDm(id: 'm2', packetId: 202));
    notifier.trackPacket(202, 'm2');

    h.protocol.emit(
      MessageDeliveryUpdate(packetId: 202, delivered: true, realAck: true),
    );
    await _pump(h.container);

    final out = h.container
        .read(messagesProvider)
        .firstWhere((m) => m.id == 'm2');
    expect(out.status, MessageStatus.delivered);
    expect(out.realAck, isTrue);
    h.container.dispose();
  });

  test(
    'weak→strong: implicit ack then explicit ack upgrades realAck false→true',
    () async {
      final h = await _makeHarness();
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(_pendingDm(id: 'm3', packetId: 303));
      notifier.trackPacket(303, 'm3');

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 303, delivered: true, realAck: false),
      );
      await _pump(h.container);
      expect(
        h.container
            .read(messagesProvider)
            .firstWhere((m) => m.id == 'm3')
            .realAck,
        isFalse,
      );

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 303, delivered: true, realAck: true),
      );
      await _pump(h.container);

      final out = h.container
          .read(messagesProvider)
          .firstWhere((m) => m.id == 'm3');
      expect(out.status, MessageStatus.delivered);
      expect(out.realAck, isTrue);
      h.container.dispose();
    },
  );

  test(
    'strong ack cannot be downgraded by a subsequent implicit ack',
    () async {
      final h = await _makeHarness();
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(_pendingDm(id: 'm4', packetId: 404));
      notifier.trackPacket(404, 'm4');

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 404, delivered: true, realAck: true),
      );
      await _pump(h.container);
      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 404, delivered: true, realAck: false),
      );
      await _pump(h.container);

      final out = h.container
          .read(messagesProvider)
          .firstWhere((m) => m.id == 'm4');
      expect(out.status, MessageStatus.delivered);
      expect(out.realAck, isTrue);
      h.container.dispose();
    },
  );

  test(
    'late failure after implicit ack does not downgrade delivered state',
    () async {
      final h = await _makeHarness();
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(_pendingDm(id: 'm5', packetId: 505));
      notifier.trackPacket(505, 'm5');

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 505, delivered: true, realAck: false),
      );
      await _pump(h.container);
      h.protocol.emit(
        MessageDeliveryUpdate(
          packetId: 505,
          delivered: false,
          realAck: false,
          error: RoutingError.timeout,
        ),
      );
      await _pump(h.container);

      final out = h.container
          .read(messagesProvider)
          .firstWhere((m) => m.id == 'm5');
      expect(out.status, MessageStatus.delivered);
      expect(out.realAck, isFalse);
      h.container.dispose();
    },
  );

  test(
    'routing failure on pending DM yields failed status and leaves realAck null',
    () async {
      final h = await _makeHarness();
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(_pendingDm(id: 'm6', packetId: 606));
      notifier.trackPacket(606, 'm6');

      h.protocol.emit(
        MessageDeliveryUpdate(
          packetId: 606,
          delivered: false,
          realAck: false,
          error: RoutingError.noRoute,
        ),
      );
      await _pump(h.container);

      final out = h.container
          .read(messagesProvider)
          .firstWhere((m) => m.id == 'm6');
      expect(out.status, MessageStatus.failed);
      expect(out.realAck, isNull);
      h.container.dispose();
    },
  );

  test(
    'broadcast never gains realAck=true even if routing ack carries realAck',
    () async {
      // Defensive: broadcast sends normally use wantAck=false and so never
      // enter the tracking map. This test exercises the belt-and-braces DM
      // gate in _handleDeliveryUpdate: even if a stray realAck=true update
      // arrives for a broadcast, realAck must stay null.
      final h = await _makeHarness();
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(_pendingBroadcast(id: 'b1', packetId: 707));
      notifier.trackPacket(707, 'b1');

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 707, delivered: true, realAck: true),
      );
      await _pump(h.container);

      final out = h.container
          .read(messagesProvider)
          .firstWhere((m) => m.id == 'b1');
      expect(out.status, MessageStatus.delivered);
      expect(out.realAck, isNull, reason: 'broadcasts must not carry realAck');
      h.container.dispose();
    },
  );

  test(
    'TTL sweep evicts implicit-acked entry when no explicit ack arrives',
    () async {
      final h = await _makeHarness();
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(_pendingDm(id: 't1', packetId: 808));
      notifier.trackPacket(808, 't1');

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 808, delivered: true, realAck: false),
      );
      await _pump(h.container);

      // Force sweep with a clock 10 minutes in the future — well past the
      // 5-minute upgrade window.
      final future = DateTime.now().add(const Duration(minutes: 10));
      notifier.debugSweepExpiredImplicitAcks(now: future);

      // A subsequent explicit ack now finds no tracking entry and is logged
      // as an untracked packet — realAck stays at false.
      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 808, delivered: true, realAck: true),
      );
      await _pump(h.container);

      final out = h.container
          .read(messagesProvider)
          .firstWhere((m) => m.id == 't1');
      expect(out.status, MessageStatus.delivered);
      expect(out.realAck, isFalse);
      h.container.dispose();
    },
  );

  test(
    'explicit ack arriving before TTL sweep still upgrades realAck',
    () async {
      final h = await _makeHarness();
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(_pendingDm(id: 't2', packetId: 909));
      notifier.trackPacket(909, 't2');

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 909, delivered: true, realAck: false),
      );
      await _pump(h.container);

      // Sweep with a clock only 1 minute in the future — inside the window.
      final inWindow = DateTime.now().add(const Duration(minutes: 1));
      notifier.debugSweepExpiredImplicitAcks(now: inWindow);

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 909, delivered: true, realAck: true),
      );
      await _pump(h.container);

      final out = h.container
          .read(messagesProvider)
          .firstWhere((m) => m.id == 't2');
      expect(out.realAck, isTrue);
      h.container.dispose();
    },
  );

  test(
    'explicit ack clears both tracking maps so sweep has nothing to do',
    () async {
      final h = await _makeHarness();
      final notifier = h.container.read(messagesProvider.notifier);
      notifier.addMessage(_pendingDm(id: 't3', packetId: 1010));
      notifier.trackPacket(1010, 't3');

      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 1010, delivered: true, realAck: true),
      );
      await _pump(h.container);

      // A far-future sweep is a no-op — entries were cleared on explicit ack.
      final far = DateTime.now().add(const Duration(hours: 1));
      notifier.debugSweepExpiredImplicitAcks(now: far);

      // Late duplicate explicit ack lands as untracked — state unchanged.
      h.protocol.emit(
        MessageDeliveryUpdate(packetId: 1010, delivered: true, realAck: true),
      );
      await _pump(h.container);

      final out = h.container
          .read(messagesProvider)
          .firstWhere((m) => m.id == 't3');
      expect(out.status, MessageStatus.delivered);
      expect(out.realAck, isTrue);
      h.container.dispose();
    },
  );
}
