// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pins the SIP v0.2 target_node_id privacy boundary at the
// ProtocolService layer for ALL five handshake frame types: a frame
// whose target is another node must be dropped before any state
// mutation (no pendingApproval queueing, no handshake state change),
// exactly as docs/sip/SIP_V0_2_TARGET_NODE_ID_PLAN.md S5.2 requires.
// The manager-layer re-check is covered by sip_handshake_test.dart;
// this suite drives full wire frames through handleIncomingPacket so a
// future handshake frame type added without the drop point fails here.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/generated/meshtastic/mesh.pb.dart' as pb;
import 'package:socialmesh/generated/meshtastic/portnums.pbenum.dart' as pn;
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_discovery.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';

class _SilentTransport implements DeviceTransport {
  final StreamController<List<int>> _data = StreamController.broadcast();

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
  bool get isConnected => true;

  @override
  Stream<DeviceConnectionState> get stateStream => const Stream.empty();

  @override
  Stream<List<int>> get dataStream => _data.stream;

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
  Future<void> dispose() async {
    await _data.close();
  }
}

const _myNodeNum = 0xAAAA;
const _peerNodeNum = 0xBBBB;
const _otherNodeNum = 0xCCCC;
var _packetId = 9000;

Future<void> _injectSipFrame(
  ProtocolService protocol,
  SipFrame frame, {
  required int from,
}) async {
  final wire = SipCodec.encode(frame);
  expect(wire, isNotNull, reason: 'Frame must encode to wire bytes.');
  await protocol.handleIncomingPacket(
    pb.FromRadio(
      packet: pb.MeshPacket(
        from: from,
        to: 0xFFFFFFFF,
        id: _packetId++,
        decoded: pb.Data(portnum: pn.PortNum.PRIVATE_APP, payload: wire!),
      ),
    ).writeToBuffer(),
  );
  // Packet processing continues past handleIncomingPacket's return.
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SilentTransport transport;
  late ProtocolService protocol;
  late SipHandshakeManager receiverHandshake;

  setUp(() async {
    // The correctly-targeted control HELLO reaches the notification
    // preference checks, which read SharedPreferences.
    SharedPreferences.setMockInitialValues({});
    transport = _SilentTransport();
    protocol = ProtocolService(transport);
    await protocol.handleIncomingPacket(
      pb.FromRadio(
        myInfo: pb.MyNodeInfo(myNodeNum: _myNodeNum),
      ).writeToBuffer(),
    );

    final rateLimiter = SipRateLimiter();
    protocol.attachSipRateLimiter(rateLimiter);
    protocol.attachSipDiscovery(
      SipDiscovery(rateLimiter: rateLimiter, localNodeId: _myNodeNum),
    );
    receiverHandshake = SipHandshakeManager(
      replayCache: SipReplayCache(),
      localNodeId: _myNodeNum,
    )..isDmAvailable = true;
    protocol.attachSipHandshake(receiverHandshake);
  });

  tearDown(() async {
    protocol.dispose();
    await transport.dispose();
  });

  test('HS_HELLO targeting another node never reaches pendingApproval; '
      'one targeting us does (harness control)', () async {
    // Peer initiates a handshake aimed at a third node; we overhear it.
    final peer = SipHandshakeManager(
      replayCache: SipReplayCache(),
      localNodeId: _peerNodeNum,
    )..isDmAvailable = true;
    final overheardHello = peer.initiateHandshake(_otherNodeNum);
    expect(overheardHello, isNotNull);

    await _injectSipFrame(protocol, overheardHello!, from: _peerNodeNum);
    expect(
      receiverHandshake.pendingRequestNodeIds,
      isEmpty,
      reason:
          'An overheard HS_HELLO must be dropped silently: no '
          'pendingApproval entry, no consent UI.',
    );
    expect(receiverHandshake.getState(_peerNodeNum), SipHandshakeState.idle);

    // Control: the same pipeline delivers a correctly-targeted HELLO.
    final peer2 = SipHandshakeManager(
      replayCache: SipReplayCache(),
      localNodeId: _peerNodeNum,
    )..isDmAvailable = true;
    final directHello = peer2.initiateHandshake(_myNodeNum);
    expect(directHello, isNotNull);

    await _injectSipFrame(protocol, directHello!, from: _peerNodeNum);
    expect(
      receiverHandshake.pendingRequestNodeIds,
      contains(_peerNodeNum),
      reason:
          'The control frame proves the harness exercises the real '
          'dispatch pipeline, so the drop assertions above are live.',
    );
  });

  test('overheard HS_CHALLENGE / HS_RESPONSE / HS_ACCEPT / HS_DECLINE '
      'never mutate handshake state', () async {
    // Drive a complete handshake between two third-party managers to
    // mint authentic frames of every remaining type, all targeting
    // nodes other than us.
    final initiator = SipHandshakeManager(
      replayCache: SipReplayCache(),
      localNodeId: _peerNodeNum,
    )..isDmAvailable = true;
    final responder = SipHandshakeManager(
      replayCache: SipReplayCache(),
      localNodeId: _otherNodeNum,
    )..isDmAvailable = true;

    final hello = initiator.initiateHandshake(_otherNodeNum)!;
    responder.handleHello(_peerNodeNum, hello);
    final challenge = responder.acceptHandshake(_peerNodeNum)!;
    final response = (await initiator.handleChallenge(
      _otherNodeNum,
      challenge,
    ))!;
    final accept = (await responder.handleResponse(_peerNodeNum, response))!;

    // A separate pair mints an HS_DECLINE.
    final initiator2 = SipHandshakeManager(
      replayCache: SipReplayCache(),
      localNodeId: _peerNodeNum,
    )..isDmAvailable = true;
    final responder2 = SipHandshakeManager(
      replayCache: SipReplayCache(),
      localNodeId: _otherNodeNum,
    )..isDmAvailable = true;
    responder2.handleHello(
      _peerNodeNum,
      initiator2.initiateHandshake(_otherNodeNum)!,
    );
    final decline = responder2.declineHandshake(_peerNodeNum)!;

    for (final (frame, from) in [
      (challenge, _otherNodeNum),
      (response, _peerNodeNum),
      (accept, _otherNodeNum),
      (decline, _otherNodeNum),
    ]) {
      await _injectSipFrame(protocol, frame, from: from);
    }

    expect(receiverHandshake.pendingRequestNodeIds, isEmpty);
    expect(receiverHandshake.getState(_peerNodeNum), SipHandshakeState.idle);
    expect(receiverHandshake.getState(_otherNodeNum), SipHandshakeState.idle);
  });
}
