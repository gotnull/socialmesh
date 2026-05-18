// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the foreground TEXT_MESSAGE_APP drop rule:
//
//   protocol_service._handleTextMessage MUST drop a packet whose payload
//   sanitises to an empty body, mirroring the background ingest path.
//   Without this rule an empty-text Message row reaches messages.db and
//   the bubble renders as just lock + timestamp (the original symptom
//   that prompted this test file).

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

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

List<int> _buildTextMessageWithRawPayload({
  required int packetId,
  required int fromNode,
  required List<int> rawPayload,
  int channel = 1,
}) {
  final data = pb.Data()
    ..portnum = pn.PortNum.TEXT_MESSAGE_APP
    ..payload = rawPayload;
  final packet = pb.MeshPacket()
    ..from = fromNode
    ..to = 0xFFFFFFFF
    ..channel = channel
    ..id = packetId
    ..decoded = data;
  final frame = pb.FromRadio()..packet = packet;
  return frame.writeToBuffer();
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('text_message_drop');
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

  test('drops payload that sanitises to empty (single null byte)', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe_store.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        final packet = _buildTextMessageWithRawPayload(
          packetId: 401,
          fromNode: 0x40,
          rawPayload: <int>[0x00],
        );
        await protocol.handleIncomingPacket(packet);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(messages, isEmpty);
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });

  test('drops payload of mixed C0/DEL controls only', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe_store.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        final packet = _buildTextMessageWithRawPayload(
          packetId: 402,
          fromNode: 0x41,
          rawPayload: <int>[0x01, 0x02, 0x7F],
        );
        await protocol.handleIncomingPacket(packet);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(messages, isEmpty);
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });

  test('drops payload that sanitises to whitespace only', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe_store.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        // Spaces + tab + newline. The sanitizer preserves these, but the
        // post-sanitization trim() check in _handleTextMessage drops the
        // packet because the body is whitespace-only.
        final packet = _buildTextMessageWithRawPayload(
          packetId: 403,
          fromNode: 0x42,
          rawPayload: <int>[0x20, 0x20, 0x09, 0x0A],
        );
        await protocol.handleIncomingPacket(packet);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(messages, isEmpty);
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });

  test('does not crash on malformed UTF-8 (allowMalformed: true)', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe_store.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        // 0xFF 0xFE 0xFD is invalid UTF-8; allowMalformed yields U+FFFD
        // replacement chars. Result is non-empty, so the message is kept
        // (sanitizer preserves U+FFFD as a printable character).
        final packet = _buildTextMessageWithRawPayload(
          packetId: 404,
          fromNode: 0x43,
          rawPayload: <int>[0xFF, 0xFE, 0xFD],
        );
        await protocol.handleIncomingPacket(packet);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // Either the message was emitted with replacement chars or
        // dropped — the test only asserts no crash and at most one
        // outcome.
        expect(messages.length, lessThanOrEqualTo(1));
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });

  test('valid waving-hand emoji payload persists with text "👋"', () async {
    await _withTempDirectory((dir) async {
      final dedupeStore = MeshPacketDedupeStore(
        dbPathOverride: p.join(dir, 'dedupe_store.db'),
      );
      await dedupeStore.init();
      final protocol = ProtocolService(
        _FakeTransport(),
        dedupeStore: dedupeStore,
      );

      final messages = <Message>[];
      final sub = protocol.messageStream.listen(messages.add);

      try {
        // 👋 = U+1F44B in UTF-8: F0 9F 91 8B
        final packet = _buildTextMessageWithRawPayload(
          packetId: 405,
          fromNode: 0x44,
          rawPayload: Uint8List.fromList(<int>[0xF0, 0x9F, 0x91, 0x8B]),
        );
        await protocol.handleIncomingPacket(packet);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(messages.length, 1);
        expect(messages.single.text, '👋');
      } finally {
        await sub.cancel();
        protocol.stop();
        await dedupeStore.dispose();
      }
    });
  });
}
