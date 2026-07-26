// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The protocol service force-disconnects after a run of undecodable
// `FromRadio` frames, on the theory that the link is carrying garbage. The
// run has to be broken by a frame that decodes, otherwise the counter is
// cumulative for the lifetime of the service: ten bad frames spread across
// hours of healthy traffic trip the threshold, and because reconnect
// succeeds the disconnect repeats every ten frames forever.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Minimal transport that records disconnect calls. BLE-shaped, so
/// `requiresFraming` is false and packets reach the decoder unwrapped.
class _CountingTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();

  int disconnectCallCount = 0;

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

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
  Future<void> disconnect() async {
    disconnectCallCount++;
  }

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
    await _stateController.close();
  }
}

/// Bytes that always fail to decode as a `FromRadio`: an invalid tag.
const List<int> _undecodableFrame = [0x07];

/// A well-formed `FromRadio` carrying a NodeInfo record.
List<int> _validFrame(int nodeNum) =>
    (pb.FromRadio()
          ..id = nodeNum
          ..nodeInfo = (pb.NodeInfo()
            ..num = nodeNum
            ..user = (pb.User()
              ..id = '!${nodeNum.toRadixString(16)}'
              ..longName = 'Healthy Node'
              ..shortName = 'HLTH')))
        .writeToBuffer();

Future<void> _withProtocol(
  Future<void> Function(ProtocolService protocol, _CountingTransport transport)
  body,
) async {
  final tempDir = await Directory.systemTemp.createTemp('parse_failures');
  try {
    final dedupeStore = MeshPacketDedupeStore(
      dbPathOverride: p.join(tempDir.path, 'dedupe.db'),
    );
    await dedupeStore.init();
    final transport = _CountingTransport();
    final protocol = ProtocolService(transport, dedupeStore: dedupeStore);
    try {
      await body(protocol, transport);
    } finally {
      await transport.dispose();
    }
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

  group('consecutive parse-failure disconnect threshold', () {
    test('a decode that lands clears the run', () async {
      await _withProtocol((protocol, transport) async {
        // Nine failures, one good frame, nine more failures. No window of
        // ten consecutive failures exists, so the link must stay up.
        for (var i = 0; i < 9; i++) {
          await protocol.handleIncomingPacket(_undecodableFrame);
        }
        await protocol.handleIncomingPacket(_validFrame(0x1234));
        for (var i = 0; i < 9; i++) {
          await protocol.handleIncomingPacket(_undecodableFrame);
        }

        expect(
          transport.disconnectCallCount,
          0,
          reason: 'a successful decode must reset the failure run',
        );
      });
    });

    test('ten consecutive failures still force a disconnect', () async {
      await _withProtocol((protocol, transport) async {
        for (var i = 0; i < 10; i++) {
          await protocol.handleIncomingPacket(_undecodableFrame);
        }

        expect(transport.disconnectCallCount, 1);
      });
    });

    test(
      'a frame with a malformed UTF-8 name is not a parse failure',
      () async {
        await _withProtocol((protocol, transport) async {
          // The CVE-2026-42566 payload shape. Invalid UTF-8 in a string field
          // must decode to replacement characters rather than counting toward
          // the disconnect threshold, otherwise a NodeDB sync carrying enough
          // poisoned records would tear the link down on its own.
          final frame = pb.FromRadio()
            ..id = 1
            ..nodeInfo = (pb.NodeInfo()
              ..num = 0xDEADBEEF
              ..user = (pb.User()..longName = 'ZZZZ'));
          final bytes = frame.writeToBuffer().toList();
          final needle = utf8.encode('ZZZZ');
          final at = _indexOf(bytes, needle);
          expect(at, greaterThanOrEqualTo(0));
          bytes.setRange(at, at + needle.length, [0xC3, 0x28, 0x41, 0x42]);

          for (var i = 0; i < 20; i++) {
            await protocol.handleIncomingPacket(bytes);
          }

          expect(transport.disconnectCallCount, 0);
        });
      },
    );
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var hit = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return i;
  }
  return -1;
}
