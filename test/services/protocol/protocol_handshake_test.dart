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

// Nonces the official Meshtastic clients (iOS app, ref:
// meshtastic-ios/Meshtastic/Accessory/Accessory Manager/AccessoryManager.swift
// lines 117-118) use for the two-phase handshake. The firmware replays any
// packets buffered in its phoneQueue in response to the second nonce.
const int _nonceInitialConfig = 69420;
const int _nonceQueueDrain = 69421;

class _FakeTransport extends DeviceTransport {
  _FakeTransport();

  bool connected = true;
  final List<List<int>> sent = <List<int>>[];
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  DeviceConnectionState get state => connected
      ? DeviceConnectionState.connected
      : DeviceConnectionState.disconnected;

  @override
  bool get isConnected => connected;

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
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {
    sent.add(List<int>.of(data));
  }

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _dataController.close();
  }
}

List<int> _configCompleteFrame(int nonce) {
  final frame = pb.FromRadio()..configCompleteId = nonce;
  return frame.writeToBuffer();
}

List<int> _textMessageFrame({
  required int packetId,
  required int fromNode,
  String text = 'queued while offline',
}) {
  final payload = pb.Data()
    ..portnum = pn.PortNum.TEXT_MESSAGE_APP
    ..payload = utf8.encode(text);
  final packet = pb.MeshPacket()
    ..from = fromNode
    ..to = 0xFFFFFFFF
    ..channel = 0
    ..id = packetId
    ..decoded = payload;
  return (pb.FromRadio()..packet = packet).writeToBuffer();
}

Iterable<int> _sentWantConfigNonces(_FakeTransport transport) sync* {
  for (final bytes in transport.sent) {
    try {
      final toRadio = pb.ToRadio.fromBuffer(bytes);
      if (toRadio.hasWantConfigId()) {
        yield toRadio.wantConfigId;
      }
    } catch (_) {
      // Not a ToRadio frame — skip.
    }
  }
}

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('protocol_handshake');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<ProtocolService> _freshProtocol(
  String dir,
  _FakeTransport transport,
) async {
  final dedupeStore = MeshPacketDedupeStore(
    dbPathOverride: p.join(
      dir,
      'dedupe_store_${DateTime.now().microsecondsSinceEpoch}.db',
    ),
  );
  await dedupeStore.init();
  return ProtocolService(transport, dedupeStore: dedupeStore);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'first configCompleteId triggers queue-drain wantConfigId with drain nonce',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _FakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        try {
          await protocol.sendInitialConfigRequestForTest();
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceInitialConfig),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          final nonces = _sentWantConfigNonces(transport).toList();
          expect(
            nonces,
            contains(_nonceQueueDrain),
            reason:
                'queue-drain wantConfigId (69421) must be sent after '
                'first configCompleteId',
          );
          expect(
            nonces.where((n) => n == _nonceQueueDrain).length,
            1,
            reason: 'queue-drain request must be sent exactly once',
          );
          expect(
            protocol.configurationComplete,
            isTrue,
            reason: 'first config completion flips the connected flag',
          );
        } finally {
          protocol.stop();
        }
      });
    },
  );

  test(
    'second configCompleteId (drain nonce) does not trigger a third request',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _FakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        try {
          await protocol.sendInitialConfigRequestForTest();
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceInitialConfig),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceQueueDrain),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // The drain ack must never provoke another wantConfigId frame; the
          // only wantConfigIds on the wire are the initial one (sent by the
          // test seam) and the single drain request.
          final nonces = _sentWantConfigNonces(transport).toList();
          expect(
            nonces.where((n) => n == _nonceQueueDrain).length,
            1,
            reason: 'drain completion must not trigger another drain request',
          );
          expect(nonces.where((n) => n == _nonceInitialConfig).length, 1);
        } finally {
          protocol.stop();
        }
      });
    },
  );

  test(
    'unexpected extra configCompleteId is ignored (no loop, no extra sends)',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _FakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        try {
          await protocol.sendInitialConfigRequestForTest();
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceInitialConfig),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceQueueDrain),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          final nonceCountAfterHandshake = _sentWantConfigNonces(
            transport,
          ).length;

          // Stray repeated completions (spurious nonce, double drain, etc.)
          await protocol.handleIncomingPacket(_configCompleteFrame(0xDEADBEEF));
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceQueueDrain),
          );
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceInitialConfig),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          expect(
            _sentWantConfigNonces(transport).length,
            nonceCountAfterHandshake,
            reason:
                'unexpected configCompleteIds must not produce extra '
                'wantConfigId frames',
          );
        } finally {
          protocol.stop();
        }
      });
    },
  );

  test(
    'stop() resets handshake state so next session re-runs two-phase flow',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _FakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        try {
          await protocol.sendInitialConfigRequestForTest();
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceInitialConfig),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceQueueDrain),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          protocol.stop();
          expect(protocol.configurationComplete, isFalse);
          transport.sent.clear();

          // Without a fresh _requestConfiguration() call the state machine is
          // back in `idle`, so a stray configCompleteId from the old session
          // must not resurrect the drain path.
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceInitialConfig),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          expect(
            _sentWantConfigNonces(transport).toList(),
            isEmpty,
            reason: 'idle phase must not honour a config completion',
          );
        } finally {
          protocol.stop();
        }
      });
    },
  );

  // Regression: post-config admin requests must be deferred to phase 2.
  // If they fire alongside the queue-drain wantConfigId in phase 1, they
  // contend with the firmware's NodeDB stream for BLE bandwidth and
  // reliably stall the iOS NOTIFY path on T1000-E / Heltec firmware.
  // Symptom: the user sees only their own node for ~180s until the
  // data-health watchdog refreshes BLE notifications.
  //
  // We verify this through an observable proxy: phase 1 must fire the
  // queue-drain wantConfigId AND nothing else on the wire (no admin
  // mesh packets) before phase 2 completes.
  test('phase-1 fires only the queue-drain wantConfigId — admin requests are '
      'deferred until phase-2 completes', () async {
    await _withTempDirectory((dir) async {
      final transport = _FakeTransport();
      final protocol = await _freshProtocol(dir, transport);
      try {
        await protocol.sendInitialConfigRequestForTest();
        transport.sent.clear(); // discard the initial wantConfigId frame

        // Complete phase 1.
        await protocol.handleIncomingPacket(
          _configCompleteFrame(_nonceInitialConfig),
        );
        // Allow microtasks + the small Future.delayed inside
        // _requestPostConfigData to run if it had been called.
        await Future<void>.delayed(const Duration(milliseconds: 80));

        // Only the queue-drain wantConfigId must have been sent. If
        // _requestPostConfigData fired in phase 1, additional admin
        // packets would already be on the wire by now.
        final phase1Frames = List<List<int>>.of(transport.sent);
        expect(
          phase1Frames.length,
          1,
          reason:
              'Phase 1 must send exactly one frame (the queue-drain '
              'wantConfigId); admin requests must be deferred. '
              'Sent: ${phase1Frames.length} frames.',
        );
        expect(
          _sentWantConfigNonces(transport),
          contains(_nonceQueueDrain),
          reason: 'Phase 1 must fire the queue-drain request',
        );

        // Phase-1 already unblocks the UI / start() — assert it.
        expect(
          protocol.configurationComplete,
          isTrue,
          reason: 'configurationComplete flips on phase 1',
        );
      } finally {
        protocol.stop();
      }
    });
  });

  // Regression: defensive nonce handling. Older / forked firmware that
  // doesn't echo the wantConfigId in configCompleteId would have
  // hard-failed with the original strict-equality gate. We accept any
  // nonce in the matching phase, log the discrepancy, and proceed.
  test('phase-1 accepts a non-matching nonce defensively (firmware that does '
      'not echo wantConfigId)', () async {
    await _withTempDirectory((dir) async {
      final transport = _FakeTransport();
      final protocol = await _freshProtocol(dir, transport);
      try {
        await protocol.sendInitialConfigRequestForTest();

        // Firmware sends back a different nonce than we asked for.
        await protocol.handleIncomingPacket(_configCompleteFrame(0xCAFEBABE));
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(
          protocol.configurationComplete,
          isTrue,
          reason:
              'Phase 1 must complete defensively even when the firmware '
              'does not echo wantConfigId',
        );
        expect(
          _sentWantConfigNonces(transport),
          contains(_nonceQueueDrain),
          reason:
              'Queue-drain request must still be sent after defensive '
              'phase-1 completion',
        );
      } finally {
        protocol.stop();
      }
    });
  });

  test(
    'queued packets replayed during drain are ingested and deduped',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _FakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        final messages = <Message>[];
        final sub = protocol.messageStream.listen(messages.add);
        try {
          await protocol.sendInitialConfigRequestForTest();
          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceInitialConfig),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          // Firmware replays two queued text messages after the drain request.
          await protocol.handleIncomingPacket(
            _textMessageFrame(packetId: 901, fromNode: 0xA1),
          );
          await protocol.handleIncomingPacket(
            _textMessageFrame(packetId: 902, fromNode: 0xA1),
          );
          await Future<void>.delayed(const Duration(milliseconds: 30));

          await protocol.handleIncomingPacket(
            _configCompleteFrame(_nonceQueueDrain),
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));

          expect(messages.length, 2);

          // Duplicate replay (same packet IDs) must still be deduped.
          await protocol.handleIncomingPacket(
            _textMessageFrame(packetId: 901, fromNode: 0xA1),
          );
          await Future<void>.delayed(const Duration(milliseconds: 20));
          expect(messages.length, 2);
        } finally {
          await sub.cancel();
          protocol.stop();
        }
      });
    },
  );
}
