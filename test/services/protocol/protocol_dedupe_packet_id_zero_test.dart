// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Documents the intentional dedupe behaviour around `packetId == 0`.
///
/// Real on-air Meshtastic packets always carry a non-zero ID (firmware
/// reserves `0` for "unset"). If a malformed packet or firmware bug
/// delivers `packetId == 0`, the second such packet from the same
/// sender on the same channel inside the 90-min TTL is dropped — by
/// design. Bypassing dedupe on `packetId == 0` would let a malformed-
/// packet flood replay endlessly.
class _FakeTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

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
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

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
    await _dataController.close();
  }
}

List<int> _buildTextMessage({
  required int packetId,
  required int fromNode,
  int channel = 1,
  String text = 'hello',
}) {
  final payload = pb.Data()
    ..portnum = pn.PortNum.TEXT_MESSAGE_APP
    ..payload = utf8.encode(text);
  final packet = pb.MeshPacket()
    ..from = fromNode
    ..to = 0xFFFFFFFF
    ..channel = channel
    ..id = packetId
    ..decoded = payload;

  final frame = pb.FromRadio()..packet = packet;
  return frame.writeToBuffer();
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('dedupe_zero');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('second TEXT_MESSAGE_APP with packetId==0 from same sender on '
      'same channel is dropped (documents intentional behaviour)', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        final first = _buildTextMessage(
          packetId: 0,
          fromNode: 0x55,
          text: 'first',
        );
        final second = _buildTextMessage(
          packetId: 0,
          fromNode: 0x55,
          text: 'second',
        );

        await protocol.handleIncomingPacket(first);
        await protocol.handleIncomingPacket(second);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(
          messages.length,
          1,
          reason:
              'packetId==0 dedupe is intentional — protects against '
              'malformed-packet replay floods',
        );
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });

  test(
    'a future packet with a different packetId is NOT incorrectly deduped',
    () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();
        final protocol = ProtocolService(
          _FakeTransport(),
          dedupeStore: dedupeStore,
        );

        final messages = <Message>[];
        final sub = protocol.messageStream.listen(messages.add);

        try {
          // First packet has packetId 0 (e.g. malformed). Second packet
          // has a real, distinct packetId — must not collide.
          await protocol.handleIncomingPacket(
            _buildTextMessage(packetId: 0, fromNode: 0x55, text: 'a'),
          );
          await protocol.handleIncomingPacket(
            _buildTextMessage(packetId: 12345, fromNode: 0x55, text: 'b'),
          );
          await protocol.handleIncomingPacket(
            _buildTextMessage(packetId: 0xFFFFFFFE, fromNode: 0x55, text: 'c'),
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(messages.length, 3);
          expect(messages.map((m) => m.text), containsAll(['a', 'b', 'c']));
        } finally {
          await sub.cancel();
          protocol.stop();
          await dedupeStore.dispose();
        }
      });
    },
  );

  test('different senders with packetId==0 do not collide', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        await protocol.handleIncomingPacket(
          _buildTextMessage(packetId: 0, fromNode: 0x55, text: 'from-A'),
        );
        await protocol.handleIncomingPacket(
          _buildTextMessage(packetId: 0, fromNode: 0x66, text: 'from-B'),
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(messages.length, 2);
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });

  test(
    'different channels with packetId==0 from same sender do not collide',
    () async {
      await _withTempDirectory((dir) async {
        final dedupeStore = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupeStore.init();
        final protocol = ProtocolService(
          _FakeTransport(),
          dedupeStore: dedupeStore,
        );

        final messages = <Message>[];
        final sub = protocol.messageStream.listen(messages.add);

        try {
          await protocol.handleIncomingPacket(
            _buildTextMessage(
              packetId: 0,
              fromNode: 0x55,
              channel: 0,
              text: 'ch0',
            ),
          );
          await protocol.handleIncomingPacket(
            _buildTextMessage(
              packetId: 0,
              fromNode: 0x55,
              channel: 1,
              text: 'ch1',
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 30));

          expect(messages.length, 2);
        } finally {
          await sub.cancel();
          protocol.stop();
          await dedupeStore.dispose();
        }
      });
    },
  );
}
