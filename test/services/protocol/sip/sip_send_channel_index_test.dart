// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Connected fake transport that records every outbound payload.
class _RecordingFakeTransport extends DeviceTransport {
  final List<List<int>> sent = <List<int>>[];
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
  DeviceConnectionState get state => DeviceConnectionState.connected;

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
  Future<void> send(List<int> data) async {
    sent.add(List<int>.from(data));
  }

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _dataController.close();
  }
}

Future<void> _primeMyNodeNum(ProtocolService protocol, int nodeNum) async {
  final myInfo = pb.MyNodeInfo()..myNodeNum = nodeNum;
  final fromRadio = pb.FromRadio()..myInfo = myInfo;
  await protocol.handleIncomingPacket(fromRadio.writeToBuffer());
  await Future<void>.delayed(Duration.zero);
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('canvas_channel_index');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

/// Extract the MeshPacket from the most recent send (which is a serialized
/// `ToRadio` envelope, since the fake transport does not frame).
pb.MeshPacket _lastMeshPacket(_RecordingFakeTransport transport) {
  expect(transport.sent, isNotEmpty, reason: 'transport.send was never called');
  final toRadio = pb.ToRadio.fromBuffer(transport.sent.last);
  expect(toRadio.hasPacket(), isTrue, reason: 'ToRadio did not carry a packet');
  return toRadio.packet;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // SIP magic 0x53 0x4D ('SM') so _logOutgoingMrrpPacket attempts a decode
  // and (correctly) returns early without throwing on this synthetic payload.
  final sipShapedPayload = Uint8List.fromList(<int>[
    0x53,
    0x4D,
    0,
    0,
    0,
    0,
    0,
    0,
  ]);

  group('sendSipPacket channelIndex plumbing', () {
    test('omitting channelIndex preserves channel 0 (primary)', () async {
      await _withTempDirectory((dir) async {
        final dedupe = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupe.init();
        final transport = _RecordingFakeTransport();
        final protocol = ProtocolService(transport, dedupeStore: dedupe);
        try {
          await _primeMyNodeNum(protocol, 0x42);

          final ok = await protocol.sendSipPacket(sipShapedPayload);

          expect(ok, isTrue);
          final packet = _lastMeshPacket(transport);
          // Channel 0 is the default; userPayload only sets the field when
          // non-zero, so reading the field returns 0 either way.
          expect(packet.channel, 0);
          expect(packet.to, 0xFFFFFFFF);
          expect(packet.from, 0x42);
        } finally {
          protocol.stop();
          await dedupe.dispose();
        }
      });
    });

    test('explicit channelIndex=3 reaches MeshPacket.channel', () async {
      await _withTempDirectory((dir) async {
        final dedupe = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupe.init();
        final transport = _RecordingFakeTransport();
        final protocol = ProtocolService(transport, dedupeStore: dedupe);
        try {
          await _primeMyNodeNum(protocol, 0x42);

          final ok = await protocol.sendSipPacket(
            sipShapedPayload,
            channelIndex: 3,
          );

          expect(ok, isTrue);
          final packet = _lastMeshPacket(transport);
          expect(packet.channel, 3);
        } finally {
          protocol.stop();
          await dedupe.dispose();
        }
      });
    });

    test('channel boundary 7 is accepted and propagated', () async {
      await _withTempDirectory((dir) async {
        final dedupe = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupe.init();
        final transport = _RecordingFakeTransport();
        final protocol = ProtocolService(transport, dedupeStore: dedupe);
        try {
          await _primeMyNodeNum(protocol, 0x42);

          final ok = await protocol.sendSipPacket(
            sipShapedPayload,
            channelIndex: 7,
          );

          expect(ok, isTrue);
          expect(_lastMeshPacket(transport).channel, 7);
        } finally {
          protocol.stop();
          await dedupe.dispose();
        }
      });
    });

    test('out-of-range channelIndex (negative) is rejected silently', () async {
      await _withTempDirectory((dir) async {
        final dedupe = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupe.init();
        final transport = _RecordingFakeTransport();
        final protocol = ProtocolService(transport, dedupeStore: dedupe);
        try {
          await _primeMyNodeNum(protocol, 0x42);

          final ok = await protocol.sendSipPacket(
            sipShapedPayload,
            channelIndex: -1,
          );

          expect(ok, isFalse);
          expect(transport.sent, isEmpty);
        } finally {
          protocol.stop();
          await dedupe.dispose();
        }
      });
    });

    test('out-of-range channelIndex (8) is rejected silently', () async {
      await _withTempDirectory((dir) async {
        final dedupe = MeshPacketDedupeStore(
          dbPathOverride: p.join(dir, 'dedupe.db'),
        );
        await dedupe.init();
        final transport = _RecordingFakeTransport();
        final protocol = ProtocolService(transport, dedupeStore: dedupe);
        try {
          await _primeMyNodeNum(protocol, 0x42);

          final ok = await protocol.sendSipPacket(
            sipShapedPayload,
            channelIndex: 8,
          );

          expect(ok, isFalse);
          expect(transport.sent, isEmpty);
        } finally {
          protocol.stop();
          await dedupe.dispose();
        }
      });
    });
  });
}
