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

// The alert-bell send option: `sendMessageWithPreTracking(includeAlertBell:
// true)` prefixes ASCII BEL (0x07) to the WIRE payload so buzzer-equipped
// radios ring (External Notification module convention), while the Message
// emitted to the UI stream keeps the clean text. A raw control character in
// rendered text crashes Flutter's native paragraph builder, so the split
// between wire payload and display text is the invariant under test.

const int _myNodeNum = 0xa6960864;
const int _peer = 0x5aad5ed6;
const int _bell = 0x07;

class _RecordingTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  final List<List<int>> sentBytes = [];

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
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

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
    sentBytes.add(List<int>.from(data));
  }

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _dataController.close();
    await _stateController.close();
  }
}

List<int> _frameMyNodeInfo(int nodeNum) {
  final frame = pb.FromRadio()..myInfo = (pb.MyNodeInfo()..myNodeNum = nodeNum);
  return frame.writeToBuffer();
}

pb.ToRadio _decodeToRadio(List<int> bytes) => pb.ToRadio.fromBuffer(bytes);

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('send_alert_bell');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<({ProtocolService protocol, _RecordingTransport transport})> _setup(
  String dir,
) async {
  final dedupeStore = MeshPacketDedupeStore(
    dbPathOverride: p.join(dir, 'dedupe.db'),
  );
  await dedupeStore.init();
  final transport = _RecordingTransport();
  final protocol = ProtocolService(transport, dedupeStore: dedupeStore);

  await protocol.handleIncomingPacket(_frameMyNodeInfo(_myNodeNum));
  protocol.debugForceReadinessForTesting(OperationalReadiness.ready);

  // Wait out the boot-time admin chatter (syncTime ~50ms, requestPosition
  // ~300ms) so sentBytes only carries the frames under test.
  await Future<void>.delayed(const Duration(milliseconds: 350));
  transport.sentBytes.clear();

  return (protocol: protocol, transport: transport);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'includeAlertBell sends exactly BEL on the wire, never in Message.text',
    () async {
      await _withTempDirectory((dir) async {
        final setup = await _setup(dir);
        final protocol = setup.protocol;
        final transport = setup.transport;

        final emitted = <Message>[];
        final sub = protocol.messageStream.listen(emitted.add);

        await protocol.sendMessageWithPreTracking(
          text: '🔔',
          to: _peer,
          channel: 0,
          wantAck: true,
          onPacketIdGenerated: (_) {},
          includeAlertBell: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(transport.sentBytes, isNotEmpty);
        final frame = _decodeToRadio(transport.sentBytes.first);
        expect(frame.packet.decoded.portnum, pn.PortNum.TEXT_MESSAGE_APP);
        expect(
          frame.packet.decoded.payload,
          [_bell],
          reason:
              'The wire payload must be EXACTLY the ASCII BEL character, '
              "byte-identical to the official clients' quick-message bell.",
        );

        expect(emitted, isNotEmpty);
        expect(
          emitted.first.text.codeUnits,
          isNot(contains(_bell)),
          reason:
              'Message.text renders in a Text() widget; a raw control '
              'character there crashes the native paragraph builder.',
        );
        expect(
          emitted.first.text,
          '🔔',
          reason: 'The display text is the safe local stand-in for the bell.',
        );

        await sub.cancel();
        protocol.stop();
        await transport.dispose();
      });
    },
  );

  test('the bell byte is absent by default', () async {
    await _withTempDirectory((dir) async {
      final setup = await _setup(dir);
      final protocol = setup.protocol;
      final transport = setup.transport;

      await protocol.sendMessageWithPreTracking(
        text: 'plain',
        to: _peer,
        channel: 0,
        wantAck: true,
        onPacketIdGenerated: (_) {},
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(transport.sentBytes, isNotEmpty);
      final frame = _decodeToRadio(transport.sentBytes.first);
      expect(frame.packet.decoded.payload, utf8.encode('plain'));

      protocol.stop();
      await transport.dispose();
    });
  });
}
