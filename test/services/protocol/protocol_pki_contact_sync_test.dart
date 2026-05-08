// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/admin.pb.dart' as admin;
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/mesh.pbenum.dart' as pbenum;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Regression coverage for the PKI failsafe wiring:
///   1) inbound `MeshPacket.publicKey` is captured onto the originating MeshNode
///   2) outbound DMs auto-attach `pki_encrypted=true` + `publicKey` when the
///      recipient's pubkey is already in the local nodeDB
///   3) every PKI-encrypted DM is followed by exactly one local
///      `AdminMessage.addContact` admin packet, deduped per session.
///
/// Mirrors `meshtastic-ios/Meshtastic/Accessory/Accessory Manager/AccessoryManager+ToRadio.swift`
/// (`addContactFromURL`, ~line 145; post-PKI-DM trigger ~line 333) and
/// `meshtastic-ios/Meshtastic/CoreData/UpdateCoreData.swift:413-415`.

const int _myNodeNum = 0xa6960864;
const int _peerWithKey = 0x5aad5ed6;
const int _peerWithoutKey = 0xb15e74db;

final List<int> _peerPubkey = List<int>.unmodifiable(
  List<int>.generate(32, (i) => i + 1),
);
final List<int> _peerPubkeyAlt = List<int>.unmodifiable(
  List<int>.generate(32, (i) => 0x80 + i),
);

class _RecordingTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  DeviceConnectionState _state = DeviceConnectionState.connected;
  final List<List<int>> sentBytes = [];

  /// Zero-indexed counter of `send()` invocations on this transport.
  /// Lets tests target a specific call deterministically (e.g. fail
  /// the second send to simulate a contact-sync transport error while
  /// keeping the DM send healthy).
  int sendCallIndex = 0;

  /// If non-null, the send call at the matching [sendCallIndex] throws.
  /// One-shot — automatically resets to null after firing.
  int? failOnSendCallIndex;

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => _state;

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
    _state = DeviceConnectionState.disconnected;
    _stateController.add(_state);
  }

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {
    final idx = sendCallIndex++;
    if (failOnSendCallIndex == idx) {
      failOnSendCallIndex = null;
      throw Exception('simulated transport failure on send #$idx');
    }
    sentBytes.add(List<int>.from(data));
  }

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _dataController.close();
    await _stateController.close();
  }

  void simulateDisconnect() {
    _state = DeviceConnectionState.disconnected;
    _stateController.add(_state);
  }
}

List<int> _frameMyNodeInfo(int nodeNum) {
  final frame = pb.FromRadio()..myInfo = (pb.MyNodeInfo()..myNodeNum = nodeNum);
  return frame.writeToBuffer();
}

List<int> _frameNodeInfo({
  required int nodeNum,
  required String longName,
  required String shortName,
  List<int>? publicKey,
}) {
  final user = pb.User()
    ..id = '!${nodeNum.toRadixString(16).padLeft(8, '0')}'
    ..longName = longName
    ..shortName = shortName;
  if (publicKey != null && publicKey.isNotEmpty) user.publicKey = publicKey;

  final nodeInfo = pb.NodeInfo()
    ..num = nodeNum
    ..user = user;

  final frame = pb.FromRadio()..nodeInfo = nodeInfo;
  return frame.writeToBuffer();
}

/// Frames an arbitrary inbound MeshPacket header (used to test inbound
/// `MeshPacket.publicKey` capture).
List<int> _frameMeshPacketWithPublicKey({
  required int from,
  required int to,
  required int packetId,
  required List<int> publicKey,
}) {
  final data = pb.Data()
    ..portnum = pn.PortNum.TEXT_MESSAGE_APP
    ..payload = const [0x68, 0x69]; // "hi"
  final packet = pb.MeshPacket()
    ..from = from
    ..to = to
    ..id = packetId
    ..pkiEncrypted = true
    ..publicKey = publicKey
    ..decoded = data;
  final frame = pb.FromRadio()..packet = packet;
  return frame.writeToBuffer();
}

/// Decodes a captured ToRadio frame (no framing because [_RecordingTransport]
/// reports `requiresFraming=false`).
pb.ToRadio _decodeToRadio(List<int> bytes) => pb.ToRadio.fromBuffer(bytes);

Future<void> _withTempDirectory(Future<void> Function(String path) body) async {
  final tempDir = await Directory.systemTemp.createTemp('pki_contact_sync');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<({ProtocolService protocol, _RecordingTransport transport})>
_setupServiceWithPeer(
  String dir, {
  bool peerHasPubkey = true,
  int peerNodeNum = _peerWithKey,
  String peerLongName = 'Meshtastic 5ed6',
  String peerShortName = '5ed6',
}) async {
  final dedupeStore = MeshPacketDedupeStore(
    dbPathOverride: p.join(dir, 'dedupe.db'),
  );
  await dedupeStore.init();
  final transport = _RecordingTransport();
  final protocol = ProtocolService(transport, dedupeStore: dedupeStore);

  // Seed _myNodeNum so sendMessage's "device not ready" guard passes.
  await protocol.handleIncomingPacket(_frameMyNodeInfo(_myNodeNum));
  // Bypass the new readiness gate — this test injects packets directly
  // rather than running the full two-phase handshake.
  protocol.debugForceReadinessForTesting(OperationalReadiness.ready);

  // Seed the destination peer in the local nodeDB.
  await protocol.handleIncomingPacket(
    _frameNodeInfo(
      nodeNum: peerNodeNum,
      longName: peerLongName,
      shortName: peerShortName,
      publicKey: peerHasPubkey ? _peerPubkey : null,
    ),
  );

  // Seed a second peer that does NOT have a pubkey, used to verify
  // non-PKI fallback.
  await protocol.handleIncomingPacket(
    _frameNodeInfo(
      nodeNum: _peerWithoutKey,
      longName: 'Meshtastic 74db',
      shortName: '74db',
    ),
  );

  // `_handleMyNodeInfo` schedules an early `syncTime()` admin send at
  // ~50 ms and a `requestPosition` admin send at ~300 ms. Wait past the
  // longer one so the boot-time outbound chatter has fully flushed before
  // the test starts asserting on `sentBytes`.
  await Future<void>.delayed(const Duration(milliseconds: 350));
  transport.sentBytes.clear();
  transport.sendCallIndex = 0;

  return (protocol: protocol, transport: transport);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'inbound MeshPacket.publicKey is captured onto the originating MeshNode',
    () async {
      await _withTempDirectory((dir) async {
        final setup = await _setupServiceWithPeer(dir, peerHasPubkey: false);
        final protocol = setup.protocol;
        final transport = setup.transport;

        // Sanity: peer was seeded WITHOUT a pubkey.
        final initial = protocol.nodes[_peerWithKey];
        expect(initial, isNotNull);
        expect(initial!.publicKey, anyOf(isNull, isEmpty));

        // Now feed an inbound MeshPacket from that peer carrying a header
        // pubkey (mirrors a PKI-encrypted broadcast from the peer).
        await protocol.handleIncomingPacket(
          _frameMeshPacketWithPublicKey(
            from: _peerWithKey,
            to: _myNodeNum,
            packetId: 1234,
            publicKey: _peerPubkey,
          ),
        );

        final updated = protocol.nodes[_peerWithKey];
        expect(updated, isNotNull);
        expect(updated!.publicKey, isNotNull);
        expect(updated.publicKey, _peerPubkey);
        expect(updated.hasPublicKey, isTrue);

        protocol.stop();
        await transport.dispose();
      });
    },
  );

  test(
    'inbound MeshPacket.publicKey overwrites a stale stored pubkey',
    () async {
      await _withTempDirectory((dir) async {
        final setup = await _setupServiceWithPeer(dir);
        final protocol = setup.protocol;
        final transport = setup.transport;

        // Feed an inbound PKI packet with a DIFFERENT pubkey for the same
        // peer and assert the cache rotates to the new key.
        await protocol.handleIncomingPacket(
          _frameMeshPacketWithPublicKey(
            from: _peerWithKey,
            to: _myNodeNum,
            packetId: 4242,
            publicKey: _peerPubkeyAlt,
          ),
        );

        final updated = protocol.nodes[_peerWithKey];
        expect(updated!.publicKey, _peerPubkeyAlt);

        protocol.stop();
        await transport.dispose();
      });
    },
  );

  test('PKI DM auto-attaches pubkey when destNode has one + triggers exactly '
      'one contact-sync admin packet', () async {
    await _withTempDirectory((dir) async {
      final setup = await _setupServiceWithPeer(dir);
      final protocol = setup.protocol;
      final transport = setup.transport;

      await protocol.sendMessage(
        text: 'hi 5ed6',
        to: _peerWithKey,
        channel: 0,
        wantAck: true,
      );

      // The contact-sync send is fire-and-forget — give the microtask
      // queue a turn to flush.
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        transport.sentBytes.length,
        2,
        reason:
            'Expected exactly 2 outbound frames: the PKI DM, then the '
            'addContact admin failsafe.',
      );

      // Frame 1: the PKI-encrypted DM.
      final dmFrame = _decodeToRadio(transport.sentBytes[0]);
      expect(dmFrame.packet.to, _peerWithKey);
      expect(dmFrame.packet.pkiEncrypted, isTrue);
      expect(dmFrame.packet.publicKey, _peerPubkey);
      expect(dmFrame.packet.decoded.portnum, pn.PortNum.TEXT_MESSAGE_APP);

      // Frame 2: the local addContact admin packet.
      final adminFrame = _decodeToRadio(transport.sentBytes[1]);
      expect(adminFrame.packet.from, _myNodeNum);
      expect(adminFrame.packet.to, _myNodeNum);
      expect(adminFrame.packet.channel, 0);
      expect(adminFrame.packet.wantAck, isTrue);
      expect(
        adminFrame.packet.priority,
        pbenum.MeshPacket_Priority.RELIABLE,
        reason: 'iOS contract: addContact local admin uses RELIABLE',
      );
      expect(adminFrame.packet.decoded.portnum, pn.PortNum.ADMIN_APP);

      final adminMsg = admin.AdminMessage.fromBuffer(
        adminFrame.packet.decoded.payload,
      );
      expect(adminMsg.hasAddContact(), isTrue);
      expect(adminMsg.addContact.nodeNum, _peerWithKey);
      expect(adminMsg.addContact.user.publicKey, _peerPubkey);
      expect(adminMsg.addContact.user.longName, 'Meshtastic 5ed6');
      expect(adminMsg.addContact.user.shortName, '5ed6');
      expect(adminMsg.addContact.manuallyVerified, isFalse);
      expect(adminMsg.addContact.shouldIgnore, isFalse);

      protocol.stop();
      await transport.dispose();
    });
  });

  test('second PKI DM to the same peer in the same session sends no '
      'duplicate contact-sync', () async {
    await _withTempDirectory((dir) async {
      final setup = await _setupServiceWithPeer(dir);
      final protocol = setup.protocol;
      final transport = setup.transport;

      await protocol.sendMessage(
        text: 'first',
        to: _peerWithKey,
        channel: 0,
        wantAck: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await protocol.sendMessage(
        text: 'second',
        to: _peerWithKey,
        channel: 0,
        wantAck: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // 2 DMs + 1 contact-sync (deduped) = 3 frames total.
      expect(
        transport.sentBytes.length,
        3,
        reason: 'Per-session dedup must ensure only one addContact per peer.',
      );

      final adminCount = transport.sentBytes
          .where(
            (bytes) =>
                _decodeToRadio(bytes).packet.decoded.portnum ==
                pn.PortNum.ADMIN_APP,
          )
          .length;
      expect(adminCount, 1);

      protocol.stop();
      await transport.dispose();
    });
  });

  test('non-PKI DM (recipient has no pubkey) sends no contact-sync', () async {
    await _withTempDirectory((dir) async {
      final setup = await _setupServiceWithPeer(dir);
      final protocol = setup.protocol;
      final transport = setup.transport;

      await protocol.sendMessage(
        text: 'hi 74db',
        to: _peerWithoutKey,
        channel: 0,
        wantAck: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(transport.sentBytes.length, 1);
      final frame = _decodeToRadio(transport.sentBytes[0]);
      expect(frame.packet.pkiEncrypted, isFalse);
      expect(frame.packet.publicKey, isEmpty);
      expect(frame.packet.decoded.portnum, pn.PortNum.TEXT_MESSAGE_APP);

      protocol.stop();
      await transport.dispose();
    });
  });

  test(
    'broadcast (to=0xFFFFFFFF) sends no contact-sync regardless of nodeDB',
    () async {
      await _withTempDirectory((dir) async {
        final setup = await _setupServiceWithPeer(dir);
        final protocol = setup.protocol;
        final transport = setup.transport;

        await protocol.sendMessage(
          text: 'broadcast probe',
          to: 0xFFFFFFFF,
          channel: 0,
          wantAck: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(transport.sentBytes.length, 1);
        final frame = _decodeToRadio(transport.sentBytes[0]);
        expect(frame.packet.pkiEncrypted, isFalse);
        expect(frame.packet.to, 0xFFFFFFFF);

        protocol.stop();
        await transport.dispose();
      });
    },
  );

  test('self-sync skipped when destination == myNodeNum', () async {
    await _withTempDirectory((dir) async {
      final setup = await _setupServiceWithPeer(dir);
      final protocol = setup.protocol;
      final transport = setup.transport;

      await protocol.syncContactToDevice(
        nodeNum: _myNodeNum,
        publicKey: _peerPubkey,
        longName: 'Self',
        shortName: 'Self',
      );

      expect(
        transport.sentBytes,
        isEmpty,
        reason: 'syncContactToDevice must skip when nodeNum == _myNodeNum',
      );

      protocol.stop();
      await transport.dispose();
    });
  });

  test(
    'transport disconnect clears the contact-sync cache so reconnect re-syncs',
    () async {
      await _withTempDirectory((dir) async {
        final setup = await _setupServiceWithPeer(dir);
        final protocol = setup.protocol;
        final transport = setup.transport;

        await protocol.sendMessage(
          text: 'first',
          to: _peerWithKey,
          channel: 0,
          wantAck: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(transport.sentBytes.length, 2);

        // Replicate what the production transport-state listener does on
        // disconnect. The listener is wired inside `start()` which the
        // test bypasses — this debug seam mirrors that exact effect so
        // the post-disconnect re-sync path is covered without driving a
        // full reconnect handshake.
        protocol.debugSimulateTransportDisconnectForContactSync();
        transport.sentBytes.clear();

        await protocol.sendMessage(
          text: 'after reconnect',
          to: _peerWithKey,
          channel: 0,
          wantAck: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // After cache clear, the next PKI DM must trigger a fresh sync.
        expect(
          transport.sentBytes.length,
          2,
          reason:
              'After disconnect, the cache must be empty so a PKI DM '
              'fires a fresh addContact.',
        );
        final adminFrame = _decodeToRadio(transport.sentBytes[1]);
        expect(adminFrame.packet.decoded.portnum, pn.PortNum.ADMIN_APP);
        final adminMsg = admin.AdminMessage.fromBuffer(
          adminFrame.packet.decoded.payload,
        );
        expect(adminMsg.hasAddContact(), isTrue);

        protocol.stop();
        await transport.dispose();
      });
    },
  );

  test('contact-sync transport failure does not fail the DM', () async {
    await _withTempDirectory((dir) async {
      final setup = await _setupServiceWithPeer(dir);
      final protocol = setup.protocol;
      final transport = setup.transport;

      // After setup, sendCallIndex was reset to 0. Send #0 (the DM) must
      // succeed; send #1 (the unawaited contact sync) must throw. The
      // DM must still resolve cleanly with a packetId — the sync error
      // is swallowed by `syncContactToDevice`'s catch.
      transport.failOnSendCallIndex = 1;

      final packetId = await protocol.sendMessage(
        text: 'hi',
        to: _peerWithKey,
        channel: 0,
        wantAck: true,
      );

      // Give the unawaited contact-sync time to fire and throw.
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(packetId, isPositive);
      expect(
        transport.sentBytes.length,
        1,
        reason:
            'Only the DM was successfully captured. The contact sync send '
            'threw on send #1 and was swallowed.',
      );
      final dmFrame = _decodeToRadio(transport.sentBytes[0]);
      expect(dmFrame.packet.decoded.portnum, pn.PortNum.TEXT_MESSAGE_APP);
      expect(dmFrame.packet.pkiEncrypted, isTrue);

      protocol.stop();
      await transport.dispose();
    });
  });

  test('admin envelope matches iOS spec (local admin, ADMIN_APP, '
      'wantAck=true, priority=RELIABLE, channel=0)', () async {
    await _withTempDirectory((dir) async {
      final setup = await _setupServiceWithPeer(dir);
      final protocol = setup.protocol;
      final transport = setup.transport;

      await protocol.syncContactToDevice(
        nodeNum: _peerWithKey,
        publicKey: _peerPubkey,
        longName: 'Meshtastic 5ed6',
        shortName: '5ed6',
      );

      expect(transport.sentBytes.length, 1);
      final frame = _decodeToRadio(transport.sentBytes[0]);
      expect(frame.packet.from, _myNodeNum);
      expect(frame.packet.to, _myNodeNum);
      expect(frame.packet.channel, 0);
      expect(frame.packet.wantAck, isTrue);
      expect(frame.packet.priority, pbenum.MeshPacket_Priority.RELIABLE);
      expect(frame.packet.decoded.portnum, pn.PortNum.ADMIN_APP);

      protocol.stop();
      await transport.dispose();
    });
  });
}
