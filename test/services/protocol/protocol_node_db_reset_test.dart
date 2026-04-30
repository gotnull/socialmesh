// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Regression coverage for the post-`nodeDbReset` rehydration path.
///
/// The bug it pins: in the TCP-style scenario where the underlying
/// transport stays connected through `nodeDbReset` (the radio clears
/// its NodeDB in place rather than rebooting + dropping the link),
/// the previous implementation cleared the local nodes cache and
/// then waited for peers to passively re-broadcast — leaving the
/// Nodes screen at `Nodes (0)` for an unbounded window with no
/// indication that anything would ever recover.
///
/// The fix sends a fresh `wantConfigId` immediately after the local
/// cache clear, so the firmware replays its config bundle (including
/// the local NodeInfo + any peers it still has cached) into our
/// existing data subscription. Transport-agnostic by design — on
/// BLE the transport disconnects almost immediately and
/// `_requestConfiguration`'s internal `_transport.isConnected` guard
/// no-ops the call, leaving the BLE reconnect path's existing
/// `resetForReconnect` + `protocol.start()` cycle to do the rehydration.
///
/// IMPORTANT NON-GOAL: this fix MUST NOT manufacture a transport
/// disconnect/reconnect to mask the issue. Doing so would create
/// avoidable reconnect races. The test below verifies that the
/// transport stays connected throughout — only a `ToRadio` with
/// `wantConfigId` should appear on the wire.

const int _nonceInitialConfig = 69420;

class _RecordingFakeTransport extends DeviceTransport {
  _RecordingFakeTransport();

  bool connected = true;
  bool disconnectCalled = false;
  final List<List<int>> sent = <List<int>>[];
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.network;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode =>
      TransportReconnectMode.directEndpoint;

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
    disconnectCalled = true;
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

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('protocol_nodedbreset');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<ProtocolService> _freshProtocol(
  String dir,
  _RecordingFakeTransport transport,
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

/// Walk every captured `ToRadio` send and yield the `wantConfigId`
/// nonces. Admin-message sends decode as ToRadio with `packet` set
/// (no `wantConfigId`) — those are skipped automatically by the
/// `hasWantConfigId()` check.
Iterable<int> _sentWantConfigNonces(_RecordingFakeTransport transport) sync* {
  for (final bytes in transport.sent) {
    try {
      final toRadio = pb.ToRadio.fromBuffer(bytes);
      if (toRadio.hasWantConfigId()) {
        yield toRadio.wantConfigId;
      }
    } catch (_) {
      // Not a ToRadio frame.
    }
  }
}

/// Count `ToRadio` frames carrying an admin packet (used to verify
/// the `nodeDbReset` admin packet itself was sent).
int _countAdminSends(_RecordingFakeTransport transport) {
  var count = 0;
  for (final bytes in transport.sent) {
    try {
      final toRadio = pb.ToRadio.fromBuffer(bytes);
      if (toRadio.hasPacket()) count++;
    } catch (_) {
      // Skip.
    }
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('nodeDbReset on a still-connected transport requests a fresh '
      'wantConfigId so the app re-fetches the radio\'s post-reset state '
      'instead of waiting indefinitely on passive peer rebroadcasts', () async {
    await _withTempDirectory((dir) async {
      final transport = _RecordingFakeTransport();
      final protocol = await _freshProtocol(dir, transport);
      try {
        // Seed the protocol with a `myNodeNum` (required precondition
        // for `nodeDbReset` to dispatch — the admin packet uses it as
        // the source).
        final myInfoFrame = pb.FromRadio(
          myInfo: pb.MyNodeInfo(myNodeNum: 0xA6960864),
        );
        await protocol.handleIncomingPacket(myInfoFrame.writeToBuffer());

        // Sanity: only the seeded MyNodeInfo went through, no sends yet.
        expect(transport.sent, isEmpty);

        await protocol.nodeDbReset();
        // Allow the 500ms post-send delay + the awaited
        // `_requestConfiguration` to complete.
        await Future<void>.delayed(const Duration(milliseconds: 700));

        // 1. The transport must still be connected — the fix is
        //    explicitly transport-agnostic and must NOT manufacture
        //    a disconnect/reconnect to mask the issue.
        expect(
          transport.connected,
          isTrue,
          reason:
              'TCP-style transport must remain connected through '
              'nodeDbReset — a forced disconnect would create '
              'reconnect races.',
        );
        expect(
          transport.disconnectCalled,
          isFalse,
          reason:
              'No transport.disconnect() should be invoked as part '
              'of the post-nodeDbReset rehydration.',
        );

        // 2. The admin packet (`nodeDbReset` itself) was sent.
        expect(
          _countAdminSends(transport),
          greaterThanOrEqualTo(1),
          reason: 'nodeDbReset admin packet should still be sent on the wire.',
        );

        // 3. A fresh `wantConfigId` was queued so the firmware
        //    replays its config bundle into our existing data
        //    subscription. Without this, the app sits at Nodes (0)
        //    for the duration of the radio's organic re-broadcast
        //    cadence.
        final nonces = _sentWantConfigNonces(transport).toList();
        expect(
          nonces,
          contains(_nonceInitialConfig),
          reason:
              'Expected initial wantConfigId nonce ($_nonceInitialConfig) '
              'on the wire after nodeDbReset to re-request the radio\'s '
              'config + nodeInfo bundle.',
        );
      } finally {
        protocol.stop();
        await transport.dispose();
      }
    });
  });

  test(
    'nodeDbReset targeting a remote node does NOT trigger a local '
    're-fetch (admin replies for remote targets do not carry our config)',
    () async {
      await _withTempDirectory((dir) async {
        final transport = _RecordingFakeTransport();
        final protocol = await _freshProtocol(dir, transport);
        try {
          final myInfoFrame = pb.FromRadio(
            myInfo: pb.MyNodeInfo(myNodeNum: 0xA6960864),
          );
          await protocol.handleIncomingPacket(myInfoFrame.writeToBuffer());

          // Send to a different node id (remote admin).
          await protocol.nodeDbReset(target: const AdminTarget.remote(0xDEAD));
          await Future<void>.delayed(const Duration(milliseconds: 700));

          final nonces = _sentWantConfigNonces(transport).toList();
          expect(
            nonces,
            isEmpty,
            reason:
                'Remote nodeDbReset must not request our own config '
                'refresh — the admin packet is destined for the peer, our '
                'local NodeDB is unaffected.',
          );
        } finally {
          protocol.stop();
          await transport.dispose();
        }
      });
    },
  );

  test('nodeDbReset gracefully no-ops the re-fetch when transport is '
      'disconnected (BLE-reboot case)', () async {
    // Models the BLE reboot path: nodeDbReset's admin packet goes
    // out, the radio reboots, the transport drops the link, and by
    // the time `_requestConfiguration` runs the transport is no
    // longer connected. The path must NOT throw — the BLE
    // reconnect's `resetForReconnect` + `protocol.start()` does the
    // re-fetch on its own.
    await _withTempDirectory((dir) async {
      final transport = _RecordingFakeTransport();
      final protocol = await _freshProtocol(dir, transport);
      try {
        final myInfoFrame = pb.FromRadio(
          myInfo: pb.MyNodeInfo(myNodeNum: 0xA6960864),
        );
        await protocol.handleIncomingPacket(myInfoFrame.writeToBuffer());

        // Synthesize a disconnect mid-reset by flipping the flag
        // before the post-send delay completes.
        unawaited(() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          transport.connected = false;
        }());

        // Should complete without throwing even though the transport
        // drops mid-flight.
        await protocol.nodeDbReset();
        await Future<void>.delayed(const Duration(milliseconds: 700));

        final nonces = _sentWantConfigNonces(transport).toList();
        expect(
          nonces,
          isEmpty,
          reason:
              'When the transport drops during the reset window, '
              'the wantConfigId is correctly skipped — the BLE '
              'reconnect path will re-handshake.',
        );
      } finally {
        protocol.stop();
        await transport.dispose();
      }
    });
  });
}
