// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// PKI key-mismatch detection on inbound DMs. A PKI-encrypted DM carries
// the sender's current public key; when it differs from the stored
// baseline, the new key is adopted (so outbound delivery self-heals and
// contact sync pushes the current key to the radio) and the node is
// flagged so DM surfaces can warn instead of letting sends die as opaque
// MAX_RETRANSMIT failures. A fresh NodeInfo or owner-response key
// confirms the baseline and clears the flag.

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _FakeTransport implements DeviceTransport {
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
  bool get isConnected => false;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

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
  Future<void> send(List<int> data) async {}

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Future<void> dispose() async {}
}

class _CapturingTransport extends _FakeTransport {
  final List<List<int>> sent = [];

  @override
  Future<void> send(List<int> data) async {
    sent.add(List<int>.from(data));
  }
}

const int _myNodeNum = 0x1001;
const int _peerNodeNum = 0x2002;

final List<int> _keyA = List<int>.generate(32, (i) => i);
final List<int> _keyB = List<int>.generate(32, (i) => 255 - i);

List<int> _myInfoBytes() =>
    pb.FromRadio(myInfo: pb.MyNodeInfo(myNodeNum: _myNodeNum)).writeToBuffer();

List<int> _nodeInfoBytes({List<int>? publicKey}) {
  final user = pb.User()
    ..longName = 'Peer'
    ..shortName = 'PEER';
  if (publicKey != null) {
    user.publicKey = publicKey;
  }
  return pb.FromRadio(
    nodeInfo: pb.NodeInfo(num: _peerNodeNum, user: user),
  ).writeToBuffer();
}

List<int> _pkiDmBytes({
  required List<int> messageKey,
  required int packetId,
  int to = _myNodeNum,
  bool pkiEncrypted = true,
  String text = 'hello',
}) {
  final packet = pb.MeshPacket(
    from: _peerNodeNum,
    to: to,
    id: packetId,
    pkiEncrypted: pkiEncrypted,
    publicKey: messageKey,
    decoded: pb.Data(
      portnum: pn.PortNum.TEXT_MESSAGE_APP,
      payload: List<int>.from(text.codeUnits),
    ),
  );
  return pb.FromRadio(id: packetId, packet: packet).writeToBuffer();
}

Future<ProtocolService> _protocolWithPeer({List<int>? baselineKey}) async {
  final protocol = ProtocolService(_FakeTransport());
  await protocol.handleIncomingPacket(_myInfoBytes());
  await protocol.handleIncomingPacket(_nodeInfoBytes(publicKey: baselineKey));
  return protocol;
}

void main() {
  group('PKI DM key-mismatch detection', () {
    test('NodeInfo stores the public key baseline', () async {
      final protocol = await _protocolWithPeer(baselineKey: _keyA);
      addTearDown(protocol.dispose);

      final node = protocol.nodes[_peerNodeNum];
      expect(node, isNotNull);
      expect(node!.hasPublicKey, isTrue);
      expect(node.publicKey, _keyA);
    });

    test('DM key differing from the stored baseline flags the node', () async {
      final protocol = await _protocolWithPeer(baselineKey: _keyA);
      addTearDown(protocol.dispose);

      await protocol.handleIncomingPacket(
        _pkiDmBytes(messageKey: _keyB, packetId: 10),
      );

      final node = protocol.nodes[_peerNodeNum];
      expect(node, isNotNull);
      expect(node!.keyMismatch, isTrue);
      expect(
        node.publicKey,
        _keyB,
        reason: 'the changed key is adopted so outbound delivery self-heals',
      );
      expect(
        node.pendingPublicKey,
        _keyA,
        reason: 'the superseded key is kept for diagnostics',
      );
    });

    test('DM key matching the stored baseline does not flag', () async {
      final protocol = await _protocolWithPeer(baselineKey: _keyA);
      addTearDown(protocol.dispose);

      await protocol.handleIncomingPacket(
        _pkiDmBytes(messageKey: _keyA, packetId: 11),
      );

      final node = protocol.nodes[_peerNodeNum];
      expect(node!.keyMismatch, isFalse);
      expect(node.pendingPublicKey, isNull);
    });

    test('first PKI DM adopts the key when no baseline exists', () async {
      final protocol = await _protocolWithPeer(baselineKey: null);
      addTearDown(protocol.dispose);

      await protocol.handleIncomingPacket(
        _pkiDmBytes(messageKey: _keyA, packetId: 12),
      );

      final node = protocol.nodes[_peerNodeNum];
      expect(node!.keyMismatch, isFalse);
      expect(node.hasPublicKey, isTrue);
      expect(node.publicKey, _keyA);
    });

    test('broadcast PKI packet never flags (DMs only)', () async {
      final protocol = await _protocolWithPeer(baselineKey: _keyA);
      addTearDown(protocol.dispose);

      await protocol.handleIncomingPacket(
        _pkiDmBytes(messageKey: _keyB, packetId: 13, to: 0xFFFFFFFF),
      );

      final node = protocol.nodes[_peerNodeNum];
      expect(node!.keyMismatch, isFalse);
    });

    test('non-PKI DM never flags even with a key attached', () async {
      final protocol = await _protocolWithPeer(baselineKey: _keyA);
      addTearDown(protocol.dispose);

      await protocol.handleIncomingPacket(
        _pkiDmBytes(messageKey: _keyB, packetId: 14, pkiEncrypted: false),
      );

      final node = protocol.nodes[_peerNodeNum];
      expect(node!.keyMismatch, isFalse);
    });

    test(
      'fresh NodeInfo key replaces the baseline and clears the flag',
      () async {
        final protocol = await _protocolWithPeer(baselineKey: _keyA);
        addTearDown(protocol.dispose);

        await protocol.handleIncomingPacket(
          _pkiDmBytes(messageKey: _keyB, packetId: 15),
        );
        expect(protocol.nodes[_peerNodeNum]!.keyMismatch, isTrue);

        await protocol.handleIncomingPacket(_nodeInfoBytes(publicKey: _keyB));

        final node = protocol.nodes[_peerNodeNum];
        expect(node!.keyMismatch, isFalse);
        expect(node.pendingPublicKey, isNull);
        expect(
          node.publicKey,
          _keyB,
          reason: 'NodeInfo key becomes the baseline',
        );
      },
    );

    test(
      'NodeInfo without a key preserves an existing mismatch flag',
      () async {
        final protocol = await _protocolWithPeer(baselineKey: _keyA);
        addTearDown(protocol.dispose);

        await protocol.handleIncomingPacket(
          _pkiDmBytes(messageKey: _keyB, packetId: 16),
        );
        expect(protocol.nodes[_peerNodeNum]!.keyMismatch, isTrue);

        await protocol.handleIncomingPacket(_nodeInfoBytes(publicKey: null));

        final node = protocol.nodes[_peerNodeNum];
        expect(node!.keyMismatch, isTrue);
        expect(node.publicKey, _keyB, reason: 'adopted key stays the baseline');
      },
    );

    test('matching DM after a NodeInfo baseline refresh stays clear', () async {
      final protocol = await _protocolWithPeer(baselineKey: _keyA);
      addTearDown(protocol.dispose);

      await protocol.handleIncomingPacket(
        _pkiDmBytes(messageKey: _keyB, packetId: 17),
      );
      await protocol.handleIncomingPacket(_nodeInfoBytes(publicKey: _keyB));
      await protocol.handleIncomingPacket(
        _pkiDmBytes(messageKey: _keyB, packetId: 18),
      );

      final node = protocol.nodes[_peerNodeNum];
      expect(node!.keyMismatch, isFalse);
      expect(node.pendingPublicKey, isNull);
    });
  });

  group('requestNodeInfo key-exchange payload', () {
    test('carries our public key and targets the peer channel', () async {
      final transport = _CapturingTransport();
      final protocol = ProtocolService(transport);
      addTearDown(protocol.dispose);

      await protocol.handleIncomingPacket(_myInfoBytes());
      // Own NodeInfo populates the cached user config, including our key.
      final myKey = List<int>.generate(32, (i) => 100 + i);
      await protocol.handleIncomingPacket(
        pb.FromRadio(
          nodeInfo: pb.NodeInfo(
            num: _myNodeNum,
            user: pb.User()
              ..id = '!00001001'
              ..longName = 'Me'
              ..shortName = 'ME'
              ..publicKey = myKey,
          ),
        ).writeToBuffer(),
      );
      // Peer last heard on secondary channel index 2.
      await protocol.handleIncomingPacket(
        pb.FromRadio(
          nodeInfo: pb.NodeInfo(
            num: _peerNodeNum,
            channel: 2,
            user: pb.User()
              ..longName = 'Peer'
              ..shortName = 'PEER',
          ),
        ).writeToBuffer(),
      );

      transport.sent.clear();
      await protocol.requestNodeInfo(_peerNodeNum);

      // Side-effect sends (time sync, position requests) may interleave;
      // pick out the NODEINFO_APP request specifically.
      final requests = transport.sent
          .map(pb.ToRadio.fromBuffer)
          .where(
            (t) =>
                t.hasPacket() &&
                t.packet.hasDecoded() &&
                t.packet.decoded.portnum == pn.PortNum.NODEINFO_APP,
          )
          .toList();
      expect(requests, hasLength(1));
      final packet = requests.single.packet;
      expect(packet.to, _peerNodeNum);
      expect(packet.wantAck, isTrue);
      expect(packet.channel, 2, reason: 'must ride the peer channel');
      expect(packet.decoded.wantResponse, isTrue);
      final sentUser = pb.User.fromBuffer(packet.decoded.payload);
      expect(
        sentUser.publicKey,
        myKey,
        reason: 'key exchange requires our public key in the payload',
      );
    });
  });

  group('RoutingError fixSuggestion copy', () {
    test('maxRetransmit and timeout name the real causes, not congestion', () {
      for (final error in [RoutingError.maxRetransmit, RoutingError.timeout]) {
        final suggestion = error.fixSuggestion;
        expect(suggestion, isNotNull);
        expect(suggestion, contains('out of range'));
        expect(suggestion, contains('encryption key'));
        expect(suggestion, contains('Request User Info'));
      }
    });
  });
}
