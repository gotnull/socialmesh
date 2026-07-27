// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the duplicate-merge policy for message transport metadata.
///
/// Policy: the first locally observed delivery path wins. A duplicate copy
/// of a packet can only fill in missing (unknown) receive metadata on the
/// stored message - it must never rewrite a known RF delivery to MQTT or
/// vice versa.
library;

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
}

int _testDbSeq = 0;
final _testPid = pid;

String _uniqueTestDbPath() => p.join(
  Directory.systemTemp.path,
  'transport_merge_${_testPid}_${_testDbSeq++}.db',
);

Future<({ProviderContainer container, MessageDatabase storage})>
_createTestHarness({int myNodeNum = 20}) async {
  SharedPreferences.setMockInitialValues({});

  final storage = MessageDatabase(testDbPath: _uniqueTestDbPath());
  await storage.init();

  final container = ProviderContainer(
    overrides: [
      messageStorageProvider.overrideWithValue(AsyncValue.data(storage)),
      protocolServiceProvider.overrideWithValue(_TestProtocolService()),
    ],
  );

  final notifier = container.read(messagesProvider.notifier);
  await notifier.storageReady;
  notifier.state = [];
  container.read(myNodeNumProvider.notifier).state = myNodeNum;

  return (container: container, storage: storage);
}

Message _packetCopy({
  required int packetId,
  required int fromNode,
  bool? viaMqtt,
  int? hopCount,
  double? rxSnr,
  DateTime? timestamp,
}) => Message(
  id: Message.deterministicId(packetId: packetId, fromNode: fromNode),
  from: fromNode,
  to: 0xFFFFFFFF,
  text: 'merge test',
  timestamp: timestamp ?? DateTime(2026, 7, 26, 12, 0),
  channel: 0,
  received: true,
  packetId: packetId,
  viaMqtt: viaMqtt,
  hopCount: hopCount,
  rxSnr: rxSnr,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    databaseFactory = databaseFactoryFfi;
  });

  test('duplicate with known transport upgrades an unknown stored copy '
      'in state and storage', () async {
    final h = await _createTestHarness();
    final notifier = h.container.read(messagesProvider.notifier);

    // First copy arrived without receive metadata (e.g. push-delivered).
    notifier.addMessage(_packetCopy(packetId: 501, fromNode: 0x2001));
    // The real decoded packet arrives second and is deduped.
    notifier.addMessage(
      _packetCopy(
        packetId: 501,
        fromNode: 0x2001,
        viaMqtt: false,
        hopCount: 4,
        rxSnr: 9.0,
      ),
    );

    final merged = h.container
        .read(messagesProvider)
        .firstWhere((m) => m.packetId == 501);
    expect(merged.viaMqtt, isFalse);
    expect(merged.hopCount, 4);
    expect(merged.rxSnr, 9.0);

    // Persisted copy carries the merged metadata too.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final persisted = (await h.storage.loadMessages()).firstWhere(
      (m) => m.packetId == 501,
    );
    expect(persisted.viaMqtt, isFalse);
    expect(persisted.hopCount, 4);

    h.container.dispose();
  });

  test('a later MQTT copy must not overwrite a known RF delivery', () async {
    final h = await _createTestHarness();
    final notifier = h.container.read(messagesProvider.notifier);

    notifier.addMessage(
      _packetCopy(packetId: 502, fromNode: 0x2002, viaMqtt: false, hopCount: 2),
    );
    notifier.addMessage(
      _packetCopy(packetId: 502, fromNode: 0x2002, viaMqtt: true, hopCount: 5),
    );

    final stored = h.container
        .read(messagesProvider)
        .firstWhere((m) => m.packetId == 502);
    expect(stored.viaMqtt, isFalse, reason: 'first observed path wins');
    expect(stored.hopCount, 2, reason: 'existing metadata is never rewritten');

    h.container.dispose();
  });

  test('a later RF copy must not overwrite a known MQTT delivery', () async {
    final h = await _createTestHarness();
    final notifier = h.container.read(messagesProvider.notifier);

    notifier.addMessage(
      _packetCopy(packetId: 503, fromNode: 0x2003, viaMqtt: true, hopCount: 1),
    );
    notifier.addMessage(
      _packetCopy(packetId: 503, fromNode: 0x2003, viaMqtt: false, hopCount: 0),
    );

    final stored = h.container
        .read(messagesProvider)
        .firstWhere((m) => m.packetId == 503);
    expect(stored.viaMqtt, isTrue, reason: 'first observed path wins');

    h.container.dispose();
  });

  test('duplicate without metadata leaves the stored copy untouched', () async {
    final h = await _createTestHarness();
    final notifier = h.container.read(messagesProvider.notifier);

    notifier.addMessage(
      _packetCopy(packetId: 504, fromNode: 0x2004, viaMqtt: true, hopCount: 3),
    );
    notifier.addMessage(_packetCopy(packetId: 504, fromNode: 0x2004));

    final stored = h.container
        .read(messagesProvider)
        .firstWhere((m) => m.packetId == 504);
    expect(stored.viaMqtt, isTrue);
    expect(stored.hopCount, 3);
    expect(
      h.container.read(messagesProvider).where((m) => m.packetId == 504),
      hasLength(1),
      reason: 'merge must not resurrect the duplicate as a second row',
    );

    h.container.dispose();
  });
}
