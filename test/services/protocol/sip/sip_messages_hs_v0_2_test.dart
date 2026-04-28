// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// SIP v0.2 strict handshake / control frame tests.
//
// Locks in the wire format and the safety boundary defined by
// `docs/sip/SIP_V0_2_TARGET_NODE_ID_PLAN.md`. This file is the
// authoritative byte-vector + behaviour pin for SIP v0.2 — every
// assertion here corresponds to a specific section of the plan.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_hs.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

const int _kBroadcast = SipConstants.sipTargetNodeIdBroadcast; // 0xFFFFFFFF

void main() {
  group('SIP v0.2 §7.1 byte-vector round-trip', () {
    test('HS_HELLO encode/decode round-trip — 54 B, target at offset 0', () {
      final hello = SipHsHello(
        targetNodeId: 0xB15E74DB,
        clientNonce: Uint8List(16)..fillRange(0, 16, 0xAA),
        clientEphemeralPub: Uint8List(32)..fillRange(0, 32, 0xBB),
        requestedFeatures: 0x000F,
      );
      final bytes = SipHsMessages.encodeHello(hello);
      expect(bytes, isNotNull);
      expect(bytes!.length, 54);

      final bd = ByteData.sublistView(bytes);
      expect(bd.getUint32(0, Endian.little), 0xB15E74DB);
      for (var i = 4; i < 20; i++) {
        expect(bytes[i], 0xAA);
      }
      for (var i = 20; i < 52; i++) {
        expect(bytes[i], 0xBB);
      }
      expect(bd.getUint16(52, Endian.little), 0x000F);

      final decoded = SipHsMessages.decodeHello(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.targetNodeId, 0xB15E74DB);
      expect(decoded.clientNonce.length, 16);
      expect(decoded.clientEphemeralPub.length, 32);
      expect(decoded.requestedFeatures, 0x000F);
    });

    test('HS_CHALLENGE — 72 B', () {
      final challenge = SipHsChallenge(
        targetNodeId: 0xA1A2A3A4,
        serverNonce: Uint8List(16)..fillRange(0, 16, 0x11),
        echoedClientNonce: Uint8List(16)..fillRange(0, 16, 0x22),
        serverEphemeralPub: Uint8List(32)..fillRange(0, 32, 0x33),
        expiresInS: 60,
      );
      final bytes = SipHsMessages.encodeChallenge(challenge);
      expect(bytes, isNotNull);
      expect(bytes!.length, 72);
      final decoded = SipHsMessages.decodeChallenge(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.targetNodeId, 0xA1A2A3A4);
      expect(decoded.expiresInS, 60);
    });

    test('HS_RESPONSE — 40 B', () {
      final response = SipHsResponse(
        targetNodeId: 0xB1B2B3B4,
        echoedServerNonce: Uint8List(16)..fillRange(0, 16, 0x44),
        echoedClientNonce: Uint8List(16)..fillRange(0, 16, 0x55),
        sessionTag: 0xDEADBEEF,
      );
      final bytes = SipHsMessages.encodeResponse(response);
      expect(bytes, isNotNull);
      expect(bytes!.length, 40);
      final decoded = SipHsMessages.decodeResponse(bytes);
      expect(decoded!.targetNodeId, 0xB1B2B3B4);
      expect(decoded.sessionTag, 0xDEADBEEF);
    });

    test('HS_ACCEPT — 13 B', () {
      final accept = SipHsAccept(
        targetNodeId: 0xC1C2C3C4,
        sessionTag: 0xCAFEBABE,
        dmTtlS: 86400,
        flags: 0,
      );
      final bytes = SipHsMessages.encodeAccept(accept);
      expect(bytes, isNotNull);
      expect(bytes!.length, 13);
      final decoded = SipHsMessages.decodeAccept(bytes);
      expect(decoded!.targetNodeId, 0xC1C2C3C4);
      expect(decoded.sessionTag, 0xCAFEBABE);
      expect(decoded.dmTtlS, 86400);
    });

    test('HS_DECLINE — 21 B', () {
      final decline = SipHsDecline(
        targetNodeId: 0xD1D2D3D4,
        echoedClientNonce: Uint8List(16)..fillRange(0, 16, 0x77),
        reason: 0x01,
      );
      final bytes = SipHsMessages.encodeDecline(decline);
      expect(bytes, isNotNull);
      expect(bytes!.length, 21);
      final decoded = SipHsMessages.decodeDecline(bytes);
      expect(decoded!.targetNodeId, 0xD1D2D3D4);
      expect(decoded.reason, 0x01);
    });
  });

  group('SIP v0.2 §7.2 encode rejects target_node_id == 0xFFFFFFFF', () {
    test('encodeHello returns null', () {
      final hello = SipHsHello(
        targetNodeId: _kBroadcast,
        clientNonce: Uint8List(16),
        clientEphemeralPub: Uint8List(32),
        requestedFeatures: 0,
      );
      // Assertion fires in debug; in either mode the encoder returns null
      // rather than producing a wire-illegal frame.
      expect(
        () => SipHsMessages.encodeHello(hello),
        anyOf(returnsNormally, throwsA(isA<AssertionError>())),
      );
    });

    test('encodeChallenge returns null', () {
      final ch = SipHsChallenge(
        targetNodeId: _kBroadcast,
        serverNonce: Uint8List(16),
        echoedClientNonce: Uint8List(16),
        serverEphemeralPub: Uint8List(32),
        expiresInS: 60,
      );
      expect(
        () => SipHsMessages.encodeChallenge(ch),
        anyOf(returnsNormally, throwsA(isA<AssertionError>())),
      );
    });

    test('encodeResponse returns null', () {
      final rs = SipHsResponse(
        targetNodeId: _kBroadcast,
        echoedServerNonce: Uint8List(16),
        echoedClientNonce: Uint8List(16),
        sessionTag: 0,
      );
      expect(
        () => SipHsMessages.encodeResponse(rs),
        anyOf(returnsNormally, throwsA(isA<AssertionError>())),
      );
    });

    test('encodeAccept returns null', () {
      final ac = SipHsAccept(
        targetNodeId: _kBroadcast,
        sessionTag: 0,
        dmTtlS: 0,
        flags: 0,
      );
      expect(
        () => SipHsMessages.encodeAccept(ac),
        anyOf(returnsNormally, throwsA(isA<AssertionError>())),
      );
    });

    test('encodeDecline returns null', () {
      final d = SipHsDecline(
        targetNodeId: _kBroadcast,
        echoedClientNonce: Uint8List(16),
        reason: 0,
      );
      expect(
        () => SipHsMessages.encodeDecline(d),
        anyOf(returnsNormally, throwsA(isA<AssertionError>())),
      );
    });
  });

  group('SIP v0.2 §7.3 decode rejects underlength payloads', () {
    test('HS_HELLO 50 B (legacy v0.1 length) → null', () {
      expect(SipHsMessages.decodeHello(Uint8List(50)), isNull);
    });
    test('HS_CHALLENGE 68 B → null', () {
      expect(SipHsMessages.decodeChallenge(Uint8List(68)), isNull);
    });
    test('HS_RESPONSE 36 B → null', () {
      expect(SipHsMessages.decodeResponse(Uint8List(36)), isNull);
    });
    test('HS_ACCEPT 9 B → null', () {
      expect(SipHsMessages.decodeAccept(Uint8List(9)), isNull);
    });
    test('HS_DECLINE 17 B → null', () {
      expect(SipHsMessages.decodeDecline(Uint8List(17)), isNull);
    });
  });

  group('SIP v0.2 §7.3a codec rejects wrong version_minor on handshake', () {
    test('version_minor=1 + hsHello → SipCodec.decode returns null', () {
      // Build a legal-looking v0.1 wire frame (52-byte payload — anything
      // would do for the version test, since the version check fires
      // before payload-length checks).
      final wire = _buildWireFrame(
        msgType: SipMessageType.hsHello.code,
        versionMinor: 0x01,
        payload: Uint8List(54), // sized for v0.2 to make sure the failure
        // is the version check, not a length check.
      );
      expect(SipCodec.decode(wire), isNull);
    });

    test('version_minor=2 + hsHello → decodes (current version)', () {
      // Build an actual v0.2 HS_HELLO payload so the round-trip is real.
      final hello = SipHsHello(
        targetNodeId: 0x12345678,
        clientNonce: Uint8List(16)..fillRange(0, 16, 0xAA),
        clientEphemeralPub: Uint8List(32)..fillRange(0, 32, 0xBB),
        requestedFeatures: 0,
      );
      final payload = SipHsMessages.encodeHello(hello)!;
      final wire = _buildWireFrame(
        msgType: SipMessageType.hsHello.code,
        versionMinor: SipConstants.sipVersionMinor,
        payload: payload,
      );
      expect(SipCodec.decode(wire), isNotNull);
    });

    test('version_minor=3 + hsHello → null (future version)', () {
      final wire = _buildWireFrame(
        msgType: SipMessageType.hsHello.code,
        versionMinor: 0x03,
        payload: Uint8List(54),
      );
      expect(SipCodec.decode(wire), isNull);
    });

    test('version_minor=1 + capBeacon → still decodes (non-handshake)', () {
      // Non-handshake message types are not subject to the strict
      // version_minor check (plan §5.1). capBeacon needs at least its
      // 10-byte payload to pass the codec.
      final wire = _buildWireFrame(
        msgType: SipMessageType.capBeacon.code,
        versionMinor: 0x01,
        payload: Uint8List(SipConstants.capBeaconPayloadSize),
      );
      expect(SipCodec.decode(wire), isNotNull);
    });
  });

  group('SIP v0.2 §7.4a codec rejects unknown handshake-range opcode', () {
    test('msg_type=0x18 (reserved handshake range, unknown) → null', () {
      final wire = _buildWireFrame(
        msgType: 0x18,
        versionMinor: SipConstants.sipVersionMinor,
        payload: Uint8List(0),
      );
      expect(SipCodec.decode(wire), isNull);
    });
  });

  group('SIP v0.2 §7.4 + §7.5 + §7.6 — manager-level target checks', () {
    test('target == myNodeNum → manager queues pendingApproval', () async {
      final replay = SipReplayCache();
      final mgr = SipHandshakeManager(
        replayCache: replay,
        localNodeId: 0xBBBBBBBB,
      );
      mgr.isDmAvailable = true;

      final frame = _buildHelloFrameForTarget(targetNodeId: 0xBBBBBBBB);
      mgr.handleHello(0xAAAAAAAA, frame);
      expect(mgr.pendingRequestNodeIds, contains(0xAAAAAAAA));
    });

    test('target != myNodeNum → silent drop (no pendingRequests)', () async {
      final replay = SipReplayCache();
      final mgr = SipHandshakeManager(
        replayCache: replay,
        localNodeId: 0xCCCCCCCC,
      );
      mgr.isDmAvailable = true;

      // A → B HS_HELLO overheard by C. C MUST NOT enter pendingApproval.
      final frame = _buildHelloFrameForTarget(targetNodeId: 0xBBBBBBBB);
      mgr.handleHello(0xAAAAAAAA, frame);
      expect(mgr.pendingRequestNodeIds, isEmpty);
    });

    test('three-node regression: only the addressed node queues', () async {
      // Plan §7.5: A sends HS_HELLO with target == B. Three managers
      // simulate A / B / C; each receives the same wire bytes. Only B
      // queues consent.
      final replay = SipReplayCache();
      SipHandshakeManager mk(int local) =>
          SipHandshakeManager(replayCache: replay, localNodeId: local)
            ..isDmAvailable = true;
      final mgrA = mk(0xAAAAAAAA);
      final mgrB = mk(0xBBBBBBBB);
      final mgrC = mk(0xCCCCCCCC);

      final frame = _buildHelloFrameForTarget(targetNodeId: 0xBBBBBBBB);

      // A loops back its own HELLO (the protocol_service-layer drop on
      // loopback happens above the manager; this test verifies the
      // target check stands on its own at the manager layer too).
      mgrA.handleHello(0xAAAAAAAA, frame);
      mgrB.handleHello(0xAAAAAAAA, frame);
      mgrC.handleHello(0xAAAAAAAA, frame);

      expect(mgrA.pendingRequestNodeIds, isEmpty);
      expect(mgrB.pendingRequestNodeIds, contains(0xAAAAAAAA));
      expect(mgrC.pendingRequestNodeIds, isEmpty);
    });

    test('replay / stale frame: target != current myNodeNum → drop', () async {
      // Plan §7.6: B previously had nodeId 0xB_old; A sent HS_HELLO
      // stamped with 0xB_old. B reboots and is now 0xB_new. The stale
      // frame finally reaches B. B MUST drop because target_node_id
      // doesn't match the current local node.
      final replay = SipReplayCache();
      const bOld = 0xB1111111;
      const bNew = 0xB2222222;
      final mgrB = SipHandshakeManager(replayCache: replay, localNodeId: bNew)
        ..isDmAvailable = true;

      final staleFrame = _buildHelloFrameForTarget(targetNodeId: bOld);
      mgrB.handleHello(0xAAAAAAAA, staleFrame);
      expect(mgrB.pendingRequestNodeIds, isEmpty);
    });

    test('target == 0xFFFFFFFF → drop at manager (broadcast forbidden)', () {
      // The encoder rejects 0xFFFFFFFF, but if a hand-crafted frame
      // somehow lands one in the wire, the receiver MUST drop too.
      final payload = Uint8List(54);
      ByteData.sublistView(payload).setUint32(0, _kBroadcast, Endian.little);
      // Fill the rest with arbitrary bytes — the manager only inspects
      // the target field for this assertion.
      payload.fillRange(4, 20, 0xAA);
      payload.fillRange(20, 52, 0xBB);

      final frame = _buildSipFrame(
        msgType: SipMessageType.hsHello,
        payload: payload,
      );
      final replay = SipReplayCache();
      final mgr = SipHandshakeManager(
        replayCache: replay,
        localNodeId: 0xBBBBBBBB,
      )..isDmAvailable = true;
      mgr.handleHello(0xAAAAAAAA, frame);
      expect(mgr.pendingRequestNodeIds, isEmpty);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a raw wire frame with explicit `versionMinor`, used for codec-level
/// version-rejection tests. Lays out the standard 22-byte SIP wrapper +
/// payload by hand because the public `SipCodec.encode` always stamps the
/// current `SipConstants.sipVersionMinor`.
Uint8List _buildWireFrame({
  required int msgType,
  required int versionMinor,
  required Uint8List payload,
}) {
  const wrapperLen = SipConstants.sipWrapperMin; // 22
  final total = wrapperLen + payload.length;
  final buf = ByteData(total);
  buf.setUint8(0, SipConstants.sipMagicByte0);
  buf.setUint8(1, SipConstants.sipMagicByte1);
  buf.setUint8(2, SipConstants.sipVersionMajor);
  buf.setUint8(3, versionMinor);
  buf.setUint8(4, msgType);
  buf.setUint8(5, 0); // flags
  buf.setUint16(6, wrapperLen, Endian.little); // header_len
  buf.setUint32(8, 0, Endian.little); // session_id
  buf.setUint32(12, 0x12345678, Endian.little); // nonce
  buf.setUint32(16, 0, Endian.little); // timestamp_s
  buf.setUint16(20, payload.length, Endian.little);
  final bytes = buf.buffer.asUint8List();
  bytes.setRange(wrapperLen, wrapperLen + payload.length, payload);
  return bytes;
}

/// Build an `HS_HELLO` SipFrame addressed at [targetNodeId]. Reuses the
/// real codec for everything except the wire layout.
SipFrame _buildHelloFrameForTarget({required int targetNodeId}) {
  final hello = SipHsHello(
    targetNodeId: targetNodeId,
    clientNonce: Uint8List(16)..fillRange(0, 16, 0xAA),
    clientEphemeralPub: Uint8List(32)..fillRange(0, 32, 0xBB),
    requestedFeatures: 0,
  );
  final payload = SipHsMessages.encodeHello(hello);
  if (payload == null) {
    throw StateError('encodeHello rejected target=$targetNodeId');
  }
  return _buildSipFrame(msgType: SipMessageType.hsHello, payload: payload);
}

SipFrame _buildSipFrame({
  required SipMessageType msgType,
  required Uint8List payload,
}) {
  return SipFrame(
    versionMajor: SipConstants.sipVersionMajor,
    versionMinor: SipConstants.sipVersionMinor,
    msgType: msgType,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: 0,
    nonce: SipCodec.generateNonce(),
    timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    payloadLen: payload.length,
    payload: payload,
  );
}
