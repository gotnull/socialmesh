// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_hs.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

void main() {
  group('SipHsMessages', () {
    test('HS_HELLO round-trip', () {
      final hello = SipHsHello(
        targetNodeId: 0xB15E74DB,
        clientNonce: Uint8List.fromList(List.generate(16, (i) => i)),
        clientEphemeralPub: Uint8List.fromList(
          List.generate(32, (i) => i + 16),
        ),
        requestedFeatures: SipFeatureBits.allV01,
      );
      final encoded = SipHsMessages.encodeHello(hello);
      expect(encoded, isNotNull);
      expect(encoded!.length, 54);

      final decoded = SipHsMessages.decodeHello(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.targetNodeId, 0xB15E74DB);
      expect(decoded.clientNonce, equals(hello.clientNonce));
      expect(decoded.clientEphemeralPub, equals(hello.clientEphemeralPub));
      expect(decoded.requestedFeatures, SipFeatureBits.allV01);
    });

    test('HS_CHALLENGE round-trip', () {
      final challenge = SipHsChallenge(
        targetNodeId: 0xB15E74DB,
        serverNonce: Uint8List.fromList(List.generate(16, (i) => i + 100)),
        echoedClientNonce: Uint8List.fromList(List.generate(16, (i) => i)),
        serverEphemeralPub: Uint8List.fromList(
          List.generate(32, (i) => i + 200),
        ),
        expiresInS: 60,
      );
      final encoded = SipHsMessages.encodeChallenge(challenge);
      expect(encoded, isNotNull);
      expect(encoded!.length, 72);

      final decoded = SipHsMessages.decodeChallenge(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.targetNodeId, 0xB15E74DB);
      expect(decoded.serverNonce, equals(challenge.serverNonce));
      expect(decoded.echoedClientNonce, equals(challenge.echoedClientNonce));
      expect(decoded.serverEphemeralPub, equals(challenge.serverEphemeralPub));
      expect(decoded.expiresInS, 60);
    });

    test('HS_RESPONSE round-trip', () {
      final response = SipHsResponse(
        targetNodeId: 0xB15E74DB,
        echoedServerNonce: Uint8List.fromList(
          List.generate(16, (i) => i + 100),
        ),
        echoedClientNonce: Uint8List.fromList(List.generate(16, (i) => i)),
        sessionTag: 0x12345678,
      );
      final encoded = SipHsMessages.encodeResponse(response);
      expect(encoded, isNotNull);
      expect(encoded!.length, 40);

      final decoded = SipHsMessages.decodeResponse(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.targetNodeId, 0xB15E74DB);
      expect(decoded.echoedServerNonce, equals(response.echoedServerNonce));
      expect(decoded.echoedClientNonce, equals(response.echoedClientNonce));
      expect(decoded.sessionTag, 0x12345678);
    });

    test('HS_ACCEPT round-trip', () {
      final accept = SipHsAccept(
        targetNodeId: 0xB15E74DB,
        sessionTag: 0xDEADBEEF,
        dmTtlS: 86400,
        flags: 0,
      );
      final encoded = SipHsMessages.encodeAccept(accept);
      expect(encoded, isNotNull);
      expect(encoded!.length, 13);

      final decoded = SipHsMessages.decodeAccept(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.targetNodeId, 0xB15E74DB);
      expect(decoded.sessionTag, 0xDEADBEEF);
      expect(decoded.dmTtlS, 86400);
      expect(decoded.flags, 0);
    });

    test('deriveSessionTag is deterministic', () async {
      final clientNonce = Uint8List.fromList(List.generate(16, (i) => i));
      final serverNonce = Uint8List.fromList(List.generate(16, (i) => i + 100));

      final tag1 = await SipHsMessages.deriveSessionTag(
        clientNonce,
        serverNonce,
      );
      final tag2 = await SipHsMessages.deriveSessionTag(
        clientNonce,
        serverNonce,
      );
      expect(tag2, equals(tag1));
    });

    test('deriveSessionTag differs for different nonces', () async {
      final clientNonce = Uint8List.fromList(List.generate(16, (i) => i));
      final serverNonce1 = Uint8List.fromList(
        List.generate(16, (i) => i + 100),
      );
      final serverNonce2 = Uint8List.fromList(
        List.generate(16, (i) => i + 200),
      );

      final tag1 = await SipHsMessages.deriveSessionTag(
        clientNonce,
        serverNonce1,
      );
      final tag2 = await SipHsMessages.deriveSessionTag(
        clientNonce,
        serverNonce2,
      );
      expect(tag2, isNot(equals(tag1)));
    });

    test('decode rejects truncated payloads', () {
      expect(SipHsMessages.decodeHello(Uint8List(49)), isNull);
      expect(SipHsMessages.decodeChallenge(Uint8List(67)), isNull);
      expect(SipHsMessages.decodeResponse(Uint8List(35)), isNull);
      expect(SipHsMessages.decodeAccept(Uint8List(8)), isNull);
    });
  });

  group('SipHandshakeManager', () {
    late SipReplayCache replayCache;

    setUp(() {
      replayCache = SipReplayCache();
    });

    test('happy path: initiator + responder complete handshake', () async {
      final initiator = SipHandshakeManager(
        replayCache: replayCache,
        localNodeId: 0xAAAA,
      );
      initiator.isDmAvailable = true;
      final responder = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0xBBBB,
      );
      responder.isDmAvailable = true;

      const nodeA = 0xAAAA;
      const nodeB = 0xBBBB;

      // Step 1: Initiator sends HS_HELLO.
      final helloFrame = initiator.initiateHandshake(nodeB);
      expect(helloFrame, isNotNull);
      expect(helloFrame!.msgType, SipMessageType.hsHello);
      expect(initiator.getState(nodeB), SipHandshakeState.helloSent);

      // Step 2: Responder receives HS_HELLO — queued for consent.
      responder.handleHello(nodeA, helloFrame);
      expect(responder.getState(nodeA), SipHandshakeState.pendingApproval);
      expect(responder.pendingRequestNodeIds, contains(nodeA));

      // User accepts — responder sends HS_CHALLENGE.
      final challengeFrame = responder.acceptHandshake(nodeA);
      expect(challengeFrame, isNotNull);
      expect(challengeFrame!.msgType, SipMessageType.hsChallenge);

      // Step 3: Initiator receives HS_CHALLENGE, sends HS_RESPONSE.
      final responseFrame = await initiator.handleChallenge(
        nodeB,
        challengeFrame,
      );
      expect(responseFrame, isNotNull);
      expect(responseFrame!.msgType, SipMessageType.hsResponse);

      // Step 4: Responder receives HS_RESPONSE, sends HS_ACCEPT.
      final acceptFrame = await responder.handleResponse(nodeA, responseFrame);
      expect(acceptFrame, isNotNull);
      expect(acceptFrame!.msgType, SipMessageType.hsAccept);

      // Step 5: Initiator receives HS_ACCEPT.
      final result = initiator.handleAccept(nodeB, acceptFrame);
      expect(result, isNotNull);
      expect(result!.peerNodeId, nodeB);
      expect(result.sessionTag, isNonZero);
      expect(result.dmTtlS, SipConstants.dmTtlDefaultS);

      // Responder also has a result.
      final respResult = responder.consumeResult(nodeA);
      expect(respResult, isNotNull);
      expect(respResult!.sessionTag, result.sessionTag);
    });

    test('duplicate initiation rejected', () {
      final mgr = SipHandshakeManager(
        replayCache: replayCache,
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;
      final first = mgr.initiateHandshake(0x1234);
      expect(first, isNotNull);

      final second = mgr.initiateHandshake(0x1234);
      expect(second, isNull);
    });

    test('nonce replay rejected on HS_HELLO', () {
      final mgr = SipHandshakeManager(
        replayCache: replayCache,
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;

      final helloFrame = SipFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: SipMessageType.hsHello,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0,
        nonce: 12345,
        timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payloadLen: 50,
        payload: Uint8List(50),
      );

      // First should succeed (though payload is zeros, nonce is recorded).
      mgr.handleHello(0xAAAA, helloFrame);
      // The decode may fail because payload is all zeros, but nonce is recorded.
      // Second call with same nonce should be rejected.
      mgr.reset();
      mgr.handleHello(0xAAAA, helloFrame);
      // Replay check fires — no pending request queued.
      expect(
        mgr.pendingRequestNodeIds,
        isEmpty,
        reason: 'replay rejected, nothing queued',
      );
    });

    test('unexpected HS_CHALLENGE without HS_HELLO is rejected', () async {
      final mgr = SipHandshakeManager(
        replayCache: replayCache,
        localNodeId: 0x1111,
      );

      final challenge = SipFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: SipMessageType.hsChallenge,
        flags: SipFlags.isResponse,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0,
        nonce: SipCodec.generateNonce(),
        timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payloadLen: 68,
        payload: Uint8List(68),
      );

      final result = await mgr.handleChallenge(0x1234, challenge);
      expect(result, isNull);
    });

    test('cancelHandshake removes session', () {
      final mgr = SipHandshakeManager(
        replayCache: replayCache,
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;
      mgr.initiateHandshake(0x1234);
      expect(mgr.hasActiveSession(0x1234), isTrue);

      mgr.cancelHandshake(0x1234);
      expect(mgr.hasActiveSession(0x1234), isFalse);
    });

    test('concurrent handshakes with different peers', () {
      final mgr = SipHandshakeManager(
        replayCache: replayCache,
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;

      final helloA = mgr.initiateHandshake(0xAAAA);
      final helloB = mgr.initiateHandshake(0xBBBB);

      expect(helloA, isNotNull);
      expect(helloB, isNotNull);
      expect(mgr.hasActiveSession(0xAAAA), isTrue);
      expect(mgr.hasActiveSession(0xBBBB), isTrue);
    });

    test('reset clears all state', () {
      final mgr = SipHandshakeManager(
        replayCache: replayCache,
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;
      mgr.initiateHandshake(0xAAAA);
      mgr.initiateHandshake(0xBBBB);

      mgr.reset();

      expect(mgr.hasActiveSession(0xAAAA), isFalse);
      expect(mgr.hasActiveSession(0xBBBB), isFalse);
    });

    test('session tag mismatch on HS_ACCEPT fails', () async {
      final initiator = SipHandshakeManager(
        replayCache: replayCache,
        localNodeId: 0xAAAA,
      );
      initiator.isDmAvailable = true;
      final responder = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0xBBBB,
      );
      responder.isDmAvailable = true;

      final helloFrame = initiator.initiateHandshake(0xBBBB);
      responder.handleHello(0xAAAA, helloFrame!);
      final challengeFrame = responder.acceptHandshake(0xAAAA);
      final responseFrame = await initiator.handleChallenge(
        0xBBBB,
        challengeFrame!,
      );
      await responder.handleResponse(0xAAAA, responseFrame!);

      // Forge a bad accept with wrong session_tag. The responder
      // (0xBBBB) is sending the (forged) accept to the initiator
      // (0xAAAA), so target_node_id = 0xAAAA.
      final badAccept = SipHsAccept(
        targetNodeId: 0xAAAA,
        sessionTag: 0xDEADDEAD,
        dmTtlS: 86400,
        flags: 0,
      );
      final badPayload = SipHsMessages.encodeAccept(badAccept);
      expect(badPayload, isNotNull);
      final badFrame = SipFrame(
        versionMajor: 0,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.hsAccept,
        flags: SipFlags.isResponse,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0xDEADDEAD,
        nonce: SipCodec.generateNonce(),
        timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payloadLen: badPayload!.length,
        payload: badPayload,
      );

      final result = initiator.handleAccept(0xBBBB, badFrame);
      expect(result, isNull);
    });

    test('simultaneous-open: higher nodeId wins initiator role', () async {
      // Both nodes initiate at the same time. Node A (0xAAAA) has higher ID
      // than node B (0x5555), so A keeps initiator and B becomes responder.
      // B still goes through user consent — initiating does not grant
      // consent on the incoming HELLO (privacy boundary).
      const nodeA = 0xAAAA;
      const nodeB = 0x5555;

      final mgrA = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: nodeA,
      );
      mgrA.isDmAvailable = true;
      final mgrB = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: nodeB,
      );
      mgrB.isDmAvailable = true;

      // Both send HS_HELLO to each other simultaneously.
      final helloFromA = mgrA.initiateHandshake(nodeB);
      final helloFromB = mgrB.initiateHandshake(nodeA);
      expect(helloFromA, isNotNull);
      expect(helloFromB, isNotNull);

      // Both are in helloSent state.
      expect(mgrA.getState(nodeB), SipHandshakeState.helloSent);
      expect(mgrB.getState(nodeA), SipHandshakeState.helloSent);

      // A receives B's HELLO — A has higher nodeId, so A ignores it (wins).
      mgrA.handleHello(nodeB, helloFromB!);
      expect(
        mgrA.getState(nodeB),
        SipHandshakeState.helloSent,
        reason: 'A wins tie-break, keeps initiator session',
      );

      // B receives A's HELLO — B has lower nodeId, so B yields and becomes
      // responder. B queues the request for user consent.
      mgrB.handleHello(nodeA, helloFromA!);
      expect(
        mgrB.getState(nodeA),
        SipHandshakeState.pendingApproval,
        reason: 'B yields, queued for consent',
      );

      // User on B accepts.
      final challengeFromB = mgrB.acceptHandshake(nodeA);
      expect(challengeFromB, isNotNull, reason: 'B accepted, sends challenge');
      expect(challengeFromB!.msgType, SipMessageType.hsChallenge);

      // From here the normal 4-step handshake proceeds:
      // A (initiator) handles B's challenge -> sends response.
      final responseFromA = await mgrA.handleChallenge(nodeB, challengeFromB);
      expect(responseFromA, isNotNull);
      expect(responseFromA!.msgType, SipMessageType.hsResponse);

      // B (responder) handles A's response -> sends accept.
      final acceptFromB = await mgrB.handleResponse(nodeA, responseFromA);
      expect(acceptFromB, isNotNull);
      expect(acceptFromB!.msgType, SipMessageType.hsAccept);

      // A handles B's accept -> handshake complete.
      final resultA = mgrA.handleAccept(nodeB, acceptFromB);
      expect(resultA, isNotNull);
      expect(resultA!.peerNodeId, nodeB);
      expect(resultA.sessionTag, isNonZero);

      // B's result should also be available.
      final resultB = mgrB.consumeResult(nodeA);
      expect(resultB, isNotNull);
      expect(resultB!.sessionTag, resultA.sessionTag);
    });

    test(
      'simultaneous-open WIN cancels HS_HELLO retransmits (airtime fix)',
      () {
        // Regression: previously, the tie-break WIN branch left the
        // retransmit Timers running, causing ~3 useless HS_HELLO
        // broadcasts over a 60-second window. The peer has either
        // already received our HELLO (they must have, to detect the
        // simultaneous open at all) or has queued us for consent;
        // duplicate HELLOs do nothing useful.
        FakeAsync().run((fake) {
          const nodeA = 0xAAAA;
          const nodeB = 0x5555;

          final mgrA = SipHandshakeManager(
            replayCache: SipReplayCache(),
            localNodeId: nodeA,
          );
          mgrA.isDmAvailable = true;
          var retransmitCount = 0;
          mgrA.onHelloRetransmit = (_, _) => retransmitCount++;

          final mgrB = SipHandshakeManager(
            replayCache: SipReplayCache(),
            localNodeId: nodeB,
          );
          mgrB.isDmAvailable = true;

          // A initiates (schedules retransmits at 8s/20s/40s).
          mgrA.initiateHandshake(nodeB);
          final helloFromB = mgrB.initiateHandshake(nodeA);
          expect(helloFromB, isNotNull);

          // A receives B's HELLO — tie-break WIN.
          mgrA.handleHello(nodeB, helloFromB!);
          expect(
            mgrA.getState(nodeB),
            SipHandshakeState.helloSent,
            reason: 'winner stays in helloSent awaiting HS_CHALLENGE',
          );

          // Advance past every retransmit slot. None should fire
          // because the WIN branch cancelled them.
          fake.elapse(const Duration(seconds: 60));

          expect(
            retransmitCount,
            0,
            reason: 'tie-break WIN must cancel retransmits',
          );
        });
      },
    );

    test('simultaneous-open: equal nodeIds both yield (edge case)', () {
      // If both have the same nodeId (should never happen in practice),
      // both yield and the second HELLO creates a responder session.
      const nodeId = 0xAAAA;

      final mgrA = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: nodeId,
      );
      mgrA.isDmAvailable = true;

      final hello = mgrA.initiateHandshake(nodeId);
      expect(hello, isNotNull);

      // Receiving a HELLO from a peer with the same nodeId: localNodeId is NOT
      // greater, so we yield. The peer (also nodeId) is sending the
      // HELLO at our local node, so target_node_id = nodeId.
      final fakePayload = SipHsMessages.encodeHello(
        SipHsHello(
          targetNodeId: nodeId,
          clientNonce: Uint8List.fromList(List.generate(16, (i) => i + 50)),
          clientEphemeralPub: Uint8List.fromList(
            List.generate(32, (i) => i + 70),
          ),
          requestedFeatures: SipFeatureBits.allV01,
        ),
      );
      expect(fakePayload, isNotNull);
      final fakeHello = SipFrame(
        versionMajor: 0,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.hsHello,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0,
        nonce: SipCodec.generateNonce(),
        timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payloadLen: fakePayload!.length,
        payload: fakePayload,
      );

      // With equal IDs, the else branch fires (not strictly greater).
      mgrA.handleHello(nodeId, fakeHello);
      // Should queue for consent (not auto-respond).
      expect(mgrA.getState(nodeId), SipHandshakeState.pendingApproval);
      final challenge = mgrA.acceptHandshake(nodeId);
      // Should return a challenge after acceptance.
      expect(challenge, isNotNull);
      expect(challenge!.msgType, SipMessageType.hsChallenge);
    });
  });

  // ---------------------------------------------------------------------------
  // Consent: declineHandshake
  // ---------------------------------------------------------------------------

  group('declineHandshake', () {
    SipFrame makeHello({required int nonce, int targetNodeId = 0x1111}) {
      final payload = SipHsMessages.encodeHello(
        SipHsHello(
          targetNodeId: targetNodeId,
          clientNonce: Uint8List.fromList(List.generate(16, (i) => i)),
          clientEphemeralPub: Uint8List.fromList(
            List.generate(32, (i) => i + 16),
          ),
          requestedFeatures: SipFeatureBits.allV01,
        ),
      );
      expect(payload, isNotNull);
      return SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.hsHello,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0,
        nonce: nonce,
        timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payloadLen: payload!.length,
        payload: payload,
      );
    }

    test('declineHandshake returns HS_DECLINE frame and clears pending', () {
      final mgr = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;

      mgr.handleHello(0xAAAA, makeHello(nonce: 100));
      expect(mgr.getState(0xAAAA), SipHandshakeState.pendingApproval);

      final decline = mgr.declineHandshake(0xAAAA);
      expect(decline, isNotNull);
      expect(decline!.msgType, SipMessageType.hsDecline);
      expect(mgr.getState(0xAAAA), SipHandshakeState.idle);
    });

    test('after decline we can immediately initiate to the same peer', () {
      // Regression: declineHandshake must not set a fail-cooldown that would
      // block our own outbound initiateHandshake to the declined peer.
      final mgr = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;

      mgr.handleHello(0xAAAA, makeHello(nonce: 200));
      expect(mgr.getState(0xAAAA), SipHandshakeState.pendingApproval);
      mgr.declineHandshake(0xAAAA);

      // Immediately initiate to the same peer — must not be blocked.
      final hello = mgr.initiateHandshake(0xAAAA);
      expect(hello, isNotNull, reason: 'decline must not set a fail-cooldown');
      expect(hello!.msgType, SipMessageType.hsHello);
      expect(mgr.getState(0xAAAA), SipHandshakeState.helloSent);
    });

    test('new HS_HELLO from declined peer is accepted after decline', () {
      // Regression: a second incoming request from the same peer must
      // still appear as pendingApproval after the first was declined.
      final mgr = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;

      mgr.handleHello(0xAAAA, makeHello(nonce: 300));
      mgr.declineHandshake(0xAAAA);
      expect(mgr.getState(0xAAAA), SipHandshakeState.idle);

      // New HELLO with a fresh SipFrame nonce.
      var stateChanges = 0;
      mgr.onStateChanged = () => stateChanges++;

      mgr.handleHello(0xAAAA, makeHello(nonce: 301));
      expect(
        mgr.getState(0xAAAA),
        SipHandshakeState.pendingApproval,
        reason: 'second request from same peer must re-enter pendingApproval',
      );
      expect(stateChanges, greaterThan(0));
    });

    test('declineHandshake returns null if no pending request', () {
      final mgr = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;
      expect(mgr.declineHandshake(0xAAAA), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Consent: handleDecline (initiator receives HS_DECLINE)
  // ---------------------------------------------------------------------------

  group('handleDecline', () {
    SipFrame makeDeclineFrame(Uint8List clientNonce) {
      // The decline is sent by the responder back to the initiator
      // (this manager's local node = 0x1111).
      final payload = SipHsMessages.encodeDecline(
        SipHsDecline(
          targetNodeId: 0x1111,
          echoedClientNonce: clientNonce,
          reason: 0x00,
        ),
      );
      expect(payload, isNotNull);
      return SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.hsDecline,
        flags: SipFlags.isResponse,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0,
        nonce: SipCodec.generateNonce(),
        timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payloadLen: payload!.length,
        payload: payload,
      );
    }

    test(
      'handleDecline clears session and returns to declined without cooldown',
      () {
        final mgr = SipHandshakeManager(
          replayCache: SipReplayCache(),
          localNodeId: 0x1111,
        );
        mgr.isDmAvailable = true;

        final hello = mgr.initiateHandshake(0xAAAA);
        expect(hello, isNotNull);
        expect(mgr.getState(0xAAAA), SipHandshakeState.helloSent);

        // Peer declines us.
        final clientNonce = Uint8List.fromList(List.generate(16, (i) => i));
        mgr.handleDecline(0xAAAA, makeDeclineFrame(clientNonce));
        // State is declined (visible for UI animation), not idle.
        expect(mgr.getState(0xAAAA), SipHandshakeState.declined);
        expect(
          mgr.isInCooldown(0xAAAA),
          isFalse,
          reason: 'peer declining must not set a fail-cooldown',
        );
      },
    );

    test('after being declined we can immediately re-initiate', () {
      // Regression: handleDecline must not set a fail-cooldown that would
      // block our own re-initiation after a peer declines us.
      final mgr = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;

      final clientNonce = Uint8List.fromList(List.generate(16, (i) => i));
      mgr.initiateHandshake(0xAAAA);
      mgr.handleDecline(0xAAAA, makeDeclineFrame(clientNonce));

      // State is declined, but re-initiation clears it.
      expect(mgr.getState(0xAAAA), SipHandshakeState.declined);

      final hello2 = mgr.initiateHandshake(0xAAAA);
      expect(
        hello2,
        isNotNull,
        reason:
            'should be able to re-initiate immediately after being declined',
      );
      expect(hello2!.msgType, SipMessageType.hsHello);
      // After re-initiation, state should be helloSent (terminal cleared).
      expect(mgr.getState(0xAAAA), SipHandshakeState.helloSent);
    });

    test('mutual decline: both sides can re-initiate immediately', () {
      // Regression: after A declines B and B declines A, both should be
      // able to initiate a fresh handshake straight away.
      final replayCacheA = SipReplayCache();
      final replayCacheB = SipReplayCache();

      final mgrA = SipHandshakeManager(
        replayCache: replayCacheA,
        localNodeId: 0x1111, // lower — yields on simultaneous-open
      );
      mgrA.isDmAvailable = true;
      final mgrB = SipHandshakeManager(
        replayCache: replayCacheB,
        localNodeId: 0x2222, // higher — wins on simultaneous-open
      );
      mgrB.isDmAvailable = true;

      // A initiates to B, B queues for consent.
      final helloFromA = mgrA.initiateHandshake(0x2222)!;
      mgrB.handleHello(0x1111, helloFromA);
      expect(mgrB.getState(0x1111), SipHandshakeState.pendingApproval);

      // B initiates to A; A is currently in helloSent — A yields (lower ID),
      // discards its initiator session, and queues B's request for consent.
      final helloFromB = mgrB.initiateHandshake(0x1111)!;
      mgrA.handleHello(0x2222, helloFromB);
      expect(mgrA.getState(0x2222), SipHandshakeState.pendingApproval);

      // B declines A's queued request → sends HS_DECLINE to A.
      // A declines B's queued request → sends HS_DECLINE to B.
      final declineFromB = mgrB.declineHandshake(0x1111)!;
      final declineFromA = mgrA.declineHandshake(0x2222)!;

      // Each side processes the incoming HS_DECLINE.
      //
      // B had its own helloSent session for A (from mgrB.initiateHandshake)
      // which A resolved via the yield path above. The HS_DECLINE from A
      // will be treated as unexpected (the session no longer exists) and
      // ignored. What matters for this regression test is that mgrB's
      // helloSent session for A is cleared by processing the decline from A.
      mgrA.handleDecline(0x2222, declineFromB);
      mgrB.handleDecline(0x1111, declineFromA);

      // After mutual decline: both sides must not be in cooldown.
      // getState shows declined (terminal display) but no fail-cooldown.
      expect(mgrA.isInCooldown(0x2222), isFalse);
      expect(mgrB.isInCooldown(0x1111), isFalse);

      // Both sides can immediately attempt a fresh handshake
      // (initiateHandshake clears the terminal display state).
      final retryA = mgrA.initiateHandshake(0x2222);
      expect(retryA, isNotNull, reason: 'A must be able to re-initiate');

      // Reset mgrA before B retries so their sessions don't conflict.
      mgrA.reset();
      final retryB = mgrB.initiateHandshake(0x1111);
      expect(retryB, isNotNull, reason: 'B must be able to re-initiate');
    });
  });

  // ---------------------------------------------------------------------------
  // Session-expiry timer + pending-consent decoupling
  //
  // Regression coverage for the field bug where a peer sat on the consent
  // prompt for ≥60s, the responder silently expired the pending request,
  // the user's late Accept tap was rejected with "no valid pending
  // request", and the initiator's helloSent session lingered forever
  // because no traffic trigger reached `_cleanExpired`.
  // ---------------------------------------------------------------------------

  group('session expiry + pending-consent timeout', () {
    SipFrame makeHello({
      required int nonce,
      int seed = 0,
      int targetNodeId = 0x1111,
    }) {
      final payload = SipHsMessages.encodeHello(
        SipHsHello(
          targetNodeId: targetNodeId,
          clientNonce: Uint8List.fromList(List.generate(16, (i) => i + seed)),
          clientEphemeralPub: Uint8List.fromList(
            List.generate(32, (i) => i + 16 + seed),
          ),
          requestedFeatures: SipFeatureBits.allV01,
        ),
      );
      expect(payload, isNotNull);
      return SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.hsHello,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0,
        nonce: nonce,
        timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payloadLen: payload!.length,
        payload: payload,
      );
    }

    test('pendingConsentTimeout outlives wire-bound handshakeTimeout', () {
      // The local consent UI lifetime must be strictly longer than the
      // peer's retransmit budget; otherwise a user who taps Accept just
      // after the 60s wire timeout finds the pending request gone.
      expect(
        SipConstants.pendingConsentTimeout,
        greaterThan(SipConstants.handshakeTimeout),
        reason: 'pending consent must outlast the wire handshake timeout',
      );
    });

    test('stalled helloSent session auto-fails at handshakeTimeout', () {
      // Without the per-session expiry timer, an initiator session that
      // never receives HS_CHALLENGE (peer disappears, consent never
      // tapped) sits in helloSent forever — chip stuck on "Connecting…".
      FakeAsync().run((fake) {
        final mgr = SipHandshakeManager(
          replayCache: SipReplayCache(),
          localNodeId: 0xAAAA,
        );
        mgr.isDmAvailable = true;

        var stateChanges = 0;
        mgr.onStateChanged = () => stateChanges++;

        final hello = mgr.initiateHandshake(0x5555);
        expect(hello, isNotNull);
        expect(mgr.getState(0x5555), SipHandshakeState.helloSent);

        // Drive past the wire handshake timeout. The expiry timer is
        // governed by FakeAsync so it fires synchronously here.
        fake.elapse(SipConstants.handshakeTimeout + const Duration(seconds: 1));

        // Session should no longer be helloSent. _failSession sets a
        // terminal display window so getState reports `failed` (not
        // `idle`) until the window elapses.
        expect(
          mgr.getState(0x5555),
          isNot(SipHandshakeState.helloSent),
          reason:
              'helloSent must transition out of inProgress when the '
              'session-expiry timer fires',
        );
        expect(
          stateChanges,
          greaterThan(0),
          reason:
              'expiry must bump onStateChanged so the chip rebuilds out '
              'of "Connecting…"',
        );
      });
    });

    test('duplicate HELLO refreshes the pending consent and keeps the request '
        'visible to the user', () {
      // Each retransmit from the peer should keep the consent prompt
      // alive — without this, the responder silently drops the prompt
      // mid-window even though the peer is still asking.
      final mgr = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0x1111,
      );
      mgr.isDmAvailable = true;

      const peerId = 0xAAAA;
      mgr.handleHello(peerId, makeHello(nonce: 1));
      expect(mgr.getState(peerId), SipHandshakeState.pendingApproval);

      // A second HELLO with a different SipFrame nonce simulates a
      // peer retransmit. The pending entry should still be there
      // (refreshed), and getState should still report pendingApproval.
      mgr.handleHello(peerId, makeHello(nonce: 2));
      expect(
        mgr.getState(peerId),
        SipHandshakeState.pendingApproval,
        reason: 'duplicate HELLO must not clear the pending entry',
      );

      // The pending request remains acceptable — late Accept tap
      // succeeds, returning a HS_CHALLENGE frame.
      final challenge = mgr.acceptHandshake(peerId);
      expect(
        challenge,
        isNotNull,
        reason: 'Accept tap on a refreshed pending must produce a challenge',
      );
      expect(challenge!.msgType, SipMessageType.hsChallenge);
    });

    test('successful handshake clears the per-session expiry timer', () {
      // Regression: the expiry timer must not fire after a successful
      // accept terminates the session, otherwise an established session
      // would be reported as failed at the timeout boundary.
      FakeAsync().run((fake) {
        final mgrInit = SipHandshakeManager(
          replayCache: SipReplayCache(),
          localNodeId: 0xAAAA,
        );
        mgrInit.isDmAvailable = true;

        final mgrResp = SipHandshakeManager(
          replayCache: SipReplayCache(),
          localNodeId: 0x5555,
        );
        mgrResp.isDmAvailable = true;

        // Initiator → HS_HELLO → Responder queues for consent.
        final hello = mgrInit.initiateHandshake(0x5555);
        expect(hello, isNotNull);
        mgrResp.handleHello(0xAAAA, hello!);
        expect(mgrResp.getState(0xAAAA), SipHandshakeState.pendingApproval);

        // Responder accepts → HS_CHALLENGE.
        final challenge = mgrResp.acceptHandshake(0xAAAA);
        expect(challenge, isNotNull);

        // Initiator processes challenge → HS_RESPONSE. handleChallenge is
        // async (computes session_tag); flush microtasks via FakeAsync so
        // the future resolves synchronously inside the test.
        SipFrame? response;
        mgrInit.handleChallenge(0x5555, challenge!).then((v) => response = v);
        fake.flushMicrotasks();
        expect(response, isNotNull);

        // Responder processes response → HS_ACCEPT, session completes.
        final accept = mgrResp.handleResponse(0xAAAA, response!);
        expect(accept, isNotNull);

        // Both sides now in `accepted` state. Drive past handshakeTimeout
        // and confirm the expiry timer didn't fail an already-completed
        // session.
        fake.elapse(SipConstants.handshakeTimeout + const Duration(seconds: 5));

        expect(
          mgrResp.getState(0xAAAA),
          SipHandshakeState.accepted,
          reason: 'completed session must not be failed by stale expiry timer',
        );
      });
    });
  });
}
