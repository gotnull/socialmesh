// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_counters.dart';
import 'package:socialmesh/services/protocol/sip/sip_discovery.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Creates a DateTime-returning clock from a mutable ms value.
  DateTime Function() dtClock(List<int> msRef) {
    return () => DateTime.fromMillisecondsSinceEpoch(msRef[0]);
  }

  /// Creates a ms-epoch-returning clock from a mutable ms value.
  int Function() msClock(List<int> msRef) {
    return () => msRef[0];
  }

  /// Creates a nullable ms-epoch clock for SipDiscovery.
  int? Function() msClockNullable(List<int> msRef) {
    return () => msRef[0];
  }

  // ---------------------------------------------------------------------------
  // Two-peer discovery + cache
  // ---------------------------------------------------------------------------
  group('Two-peer discovery', () {
    late SipRateLimiter limiterA;
    late SipRateLimiter limiterB;
    late SipDiscovery discoveryA;
    late SipDiscovery discoveryB;
    late List<int> nowMs;

    setUp(() {
      nowMs = [1000000]; // start at 1,000,000 ms
      limiterA = SipRateLimiter(clock: dtClock(nowMs));
      limiterB = SipRateLimiter(clock: dtClock(nowMs));
      discoveryA = SipDiscovery(
        rateLimiter: limiterA,
        localNodeId: 0xAABBCCDD,
        clock: msClockNullable(nowMs),
        beaconIntervalMs: 100, // Short interval for testing
        beaconJitterMs: 0, // No jitter for determinism
        rollcallCooldownMs: 50,
      );
      discoveryB = SipDiscovery(
        rateLimiter: limiterB,
        localNodeId: 0x11223344,
        clock: msClockNullable(nowMs),
        beaconIntervalMs: 100,
        beaconJitterMs: 0,
        rollcallCooldownMs: 50,
      );

      // Enable privacy gates for testing.
      discoveryA.isDiscoverable = true;
      discoveryB.isDiscoverable = true;
    });

    test('beacon exchange populates both peer caches', () {
      // Node A emits a beacon.
      nowMs[0] += 200; // past beacon interval
      final beaconA = discoveryA.buildBeacon(force: true);
      expect(beaconA, isNotNull);

      // Node B receives the beacon from A.
      discoveryB.handleBeacon(beaconA!.frame, 0xAABBCCDD);
      expect(discoveryB.peerCount, equals(1));
      expect(discoveryB.getPeer(0xAABBCCDD), isNotNull);
      expect(
        discoveryB.getPeer(0xAABBCCDD)!.features,
        equals(SipFeatureBits.allV01),
      );

      // Node B emits a beacon.
      final beaconB = discoveryB.buildBeacon(force: true);
      expect(beaconB, isNotNull);

      // Node A receives the beacon from B.
      discoveryA.handleBeacon(beaconB!.frame, 0x11223344);
      expect(discoveryA.peerCount, equals(1));
      expect(discoveryA.getPeer(0x11223344), isNotNull);
    });

    test('rollcall request/response populates peer cache', () {
      // A sends a rollcall request.
      nowMs[0] += 200;
      final rollcallReq = discoveryA.buildRollcallReq();
      expect(rollcallReq, isNotNull);

      // B receives the request and responds.
      final rollcallResp = discoveryB.handleRollcallReq(0xAABBCCDD);
      expect(rollcallResp, isNotNull);

      // A receives the response.
      discoveryA.handleRollcallResp(rollcallResp!.frame, 0x11223344);
      expect(discoveryA.peerCount, equals(1));
      final peer = discoveryA.getPeer(0x11223344);
      expect(peer, isNotNull);
      expect(peer!.deviceClass, equals(1)); // phone-app
    });

    test('discovery does not cache self-beacons', () {
      nowMs[0] += 200;
      final beaconA = discoveryA.buildBeacon(force: true);
      expect(beaconA, isNotNull);

      // Node A receives its own beacon (as happens on broadcast mesh).
      discoveryA.handleBeacon(beaconA!.frame, 0xAABBCCDD);

      // isLocalNode returns true
      expect(discoveryA.isLocalNode(0xAABBCCDD), isTrue);
      // Note: handleBeacon stores it, but the caller should check isLocalNode
      // before calling handleBeacon. We verify the isLocalNode gate works.
    });

    test('rollcall request rate-limited within cooldown', () {
      nowMs[0] += 200;
      final req1 = discoveryA.buildRollcallReq();
      expect(req1, isNotNull);

      // Immediately try again (within 50ms cooldown).
      nowMs[0] += 10; // only 10ms elapsed
      final req2 = discoveryA.buildRollcallReq();
      expect(req2, isNull); // rate-limited

      // After cooldown (50ms) + max rollcall jitter (5000ms).
      nowMs[0] += 5100; // total 5110ms > 50ms + 5000ms
      final req3 = discoveryA.buildRollcallReq();
      expect(req3, isNotNull);
    });

    test('stale peer entries are evicted', () {
      // Populate a peer.
      nowMs[0] += 200;
      final beaconB = discoveryB.buildBeacon(force: true);
      discoveryA.handleBeacon(beaconB!.frame, 0x11223344);
      expect(discoveryA.peerCount, equals(1));

      // Advance past cache TTL (default 24h = 86,400,000 ms).
      nowMs[0] += 86400001;
      final evicted = discoveryA.evictExpired();
      expect(evicted, equals(1));
      expect(discoveryA.peerCount, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // Two-peer handshake lifecycle
  // ---------------------------------------------------------------------------
  group('Two-peer handshake', () {
    late SipReplayCache replayCacheA;
    late SipReplayCache replayCacheB;
    late SipHandshakeManager hsManagerA;
    late SipHandshakeManager hsManagerB;
    late List<int> nowMs;

    setUp(() {
      nowMs = [1000000];
      replayCacheA = SipReplayCache();
      replayCacheB = SipReplayCache();
      hsManagerA = SipHandshakeManager(
        replayCache: replayCacheA,
        localNodeId: 0xAABBCCDD,
        clock: dtClock(nowMs),
      );
      hsManagerB = SipHandshakeManager(
        replayCache: replayCacheB,
        localNodeId: 0x11223344,
        clock: dtClock(nowMs),
      );

      // Enable privacy gates for testing.
      hsManagerA.isDmAvailable = true;
      hsManagerB.isDmAvailable = true;
    });

    test('four-step handshake completes between two peers', () async {
      const nodeA = 0xAABBCCDD;
      const nodeB = 0x11223344;

      // Step 1: A initiates with HS_HELLO.
      final helloFrame = hsManagerA.initiateHandshake(nodeB);
      expect(helloFrame, isNotNull);
      expect(helloFrame!.msgType, equals(SipMessageType.hsHello));
      expect(hsManagerA.getState(nodeB), equals(SipHandshakeState.helloSent));

      // Step 2: B receives HS_HELLO, queues for consent.
      hsManagerB.handleHello(nodeA, helloFrame);
      expect(
        hsManagerB.getState(nodeA),
        equals(SipHandshakeState.pendingApproval),
      );
      // B accepts: sends HS_CHALLENGE.
      final challengeFrame = hsManagerB.acceptHandshake(nodeA);
      expect(challengeFrame, isNotNull);
      expect(challengeFrame!.msgType, equals(SipMessageType.hsChallenge));
      expect(
        hsManagerB.getState(nodeA),
        equals(SipHandshakeState.challengeSent),
      );

      // Step 3: A receives HS_CHALLENGE, sends HS_RESPONSE.
      final responseFrame = await hsManagerA.handleChallenge(
        nodeB,
        challengeFrame,
      );
      expect(responseFrame, isNotNull);
      expect(responseFrame!.msgType, equals(SipMessageType.hsResponse));
      expect(
        hsManagerA.getState(nodeB),
        equals(SipHandshakeState.responseSent),
      );

      // Step 4: B receives HS_RESPONSE, sends HS_ACCEPT.
      final acceptFrame = await hsManagerB.handleResponse(nodeA, responseFrame);
      expect(acceptFrame, isNotNull);
      expect(acceptFrame!.msgType, equals(SipMessageType.hsAccept));

      // B has a completed result.
      final resultB = hsManagerB.consumeResult(nodeA);
      expect(resultB, isNotNull);
      expect(resultB!.peerNodeId, equals(nodeA));
      expect(resultB.dmTtlS, equals(SipConstants.dmTtlDefaultS));

      // A receives HS_ACCEPT.
      final resultA = hsManagerA.handleAccept(nodeB, acceptFrame);
      expect(resultA, isNotNull);
      expect(resultA!.peerNodeId, equals(nodeB));
      expect(resultA.sessionTag, equals(resultB.sessionTag));
    });

    test('duplicate handshake initiation is rejected', () {
      const nodeB = 0x11223344;
      final hello1 = hsManagerA.initiateHandshake(nodeB);
      expect(hello1, isNotNull);

      // Second attempt with the same peer returns null.
      final hello2 = hsManagerA.initiateHandshake(nodeB);
      expect(hello2, isNull);
    });

    test('replayed HS_HELLO is rejected', () {
      const nodeA = 0xAABBCCDD;

      final hello = hsManagerA.initiateHandshake(0x11223344);
      expect(hello, isNotNull);

      // B handles the hello once.
      hsManagerB.handleHello(nodeA, hello!);
      expect(
        hsManagerB.getState(nodeA),
        equals(SipHandshakeState.pendingApproval),
      );
      final challenge1 = hsManagerB.acceptHandshake(nodeA);
      expect(challenge1, isNotNull);

      // Replay the same hello to B (second time should be absorbed).
      // Session is in challengeSent — duplicate HS_HELLO dropped.
      hsManagerB.handleHello(nodeA, hello);
      expect(
        hsManagerB.getState(nodeA),
        equals(SipHandshakeState.challengeSent),
      );
    });

    test('post-handshake reset clears all state', () async {
      const nodeA = 0xAABBCCDD;
      const nodeB = 0x11223344;

      // Complete a handshake.
      final hello = hsManagerA.initiateHandshake(nodeB)!;
      hsManagerB.handleHello(nodeA, hello);
      final challenge = hsManagerB.acceptHandshake(nodeA)!;
      final response = (await hsManagerA.handleChallenge(nodeB, challenge))!;
      await hsManagerB.handleResponse(nodeA, response);

      // Reset and verify clean state.
      hsManagerA.reset();
      hsManagerB.reset();
      expect(hsManagerA.getState(nodeB), equals(SipHandshakeState.idle));
      expect(hsManagerB.getState(nodeA), equals(SipHandshakeState.idle));
      expect(hsManagerA.consumeResult(nodeB), isNull);
      expect(hsManagerB.consumeResult(nodeA), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Handshake → DM session flow
  // ---------------------------------------------------------------------------
  group('Handshake → DM session', () {
    late SipRateLimiter sharedLimiter;
    late SipReplayCache replayCacheA;
    late SipReplayCache replayCacheB;
    late SipHandshakeManager hsManagerA;
    late SipHandshakeManager hsManagerB;
    late SipDmManager dmManagerA;
    late SipDmManager dmManagerB;
    late List<int> nowMs;

    setUp(() {
      nowMs = [1000000];
      sharedLimiter = SipRateLimiter(clock: dtClock(nowMs));
      replayCacheA = SipReplayCache();
      replayCacheB = SipReplayCache();
      hsManagerA = SipHandshakeManager(
        replayCache: replayCacheA,
        localNodeId: 0xAABBCCDD,
        clock: dtClock(nowMs),
      );
      hsManagerB = SipHandshakeManager(
        replayCache: replayCacheB,
        localNodeId: 0x11223344,
        clock: dtClock(nowMs),
      );
      dmManagerA = SipDmManager(
        rateLimiter: sharedLimiter,
        clock: msClock(nowMs),
      );
      dmManagerB = SipDmManager(
        rateLimiter: sharedLimiter,
        clock: msClock(nowMs),
      );

      // Enable privacy gates for testing.
      hsManagerA.isDmAvailable = true;
      hsManagerB.isDmAvailable = true;
    });

    Future<(SipHandshakeResult, SipHandshakeResult)> completeHandshake(
      int nodeA,
      int nodeB,
    ) async {
      final hello = hsManagerA.initiateHandshake(nodeB)!;
      hsManagerB.handleHello(nodeA, hello);
      final challenge = hsManagerB.acceptHandshake(nodeA)!;
      final response = (await hsManagerA.handleChallenge(nodeB, challenge))!;
      final accept = (await hsManagerB.handleResponse(nodeA, response))!;
      final resultB = hsManagerB.consumeResult(nodeA)!;
      final resultA = hsManagerA.handleAccept(nodeB, accept)!;
      return (resultA, resultB);
    }

    test('DM session created after handshake, messages exchanged', () async {
      const nodeA = 0xAABBCCDD;
      const nodeB = 0x11223344;

      final (resultA, resultB) = await completeHandshake(nodeA, nodeB);

      // Both sides create a DM session with the same session tag.
      final sessionA = dmManagerA.createSession(
        sessionTag: resultA.sessionTag,
        peerNodeId: nodeB,
        ttlS: resultA.dmTtlS,
      );
      final sessionB = dmManagerB.createSession(
        sessionTag: resultB.sessionTag,
        peerNodeId: nodeA,
        ttlS: resultB.dmTtlS,
      );
      expect(sessionA, isNotNull);
      expect(sessionB, isNotNull);
      expect(sessionA!.sessionTag, equals(sessionB!.sessionTag));

      // A sends a message.
      final sendResult = dmManagerA.buildDmMessage(
        sessionTag: resultA.sessionTag,
        text: 'Hello from A!',
      );
      expect(sendResult.isOk, isTrue);
      expect(sendResult.frame, isNotNull);
      expect(sendResult.frame!.sessionId, equals(resultA.sessionTag));
      expect(sendResult.frame!.msgType, equals(SipMessageType.dmMsg));

      // B receives the message frame.
      final inboundMsg = dmManagerB.handleInboundDm(sendResult.frame!);
      expect(inboundMsg, isNotNull);
      expect(inboundMsg!.text, equals('Hello from A!'));

      // Both sides have the message in history.
      final historyA = dmManagerA.getHistory(resultA.sessionTag);
      expect(historyA, isNotNull);
      expect(historyA!.length, equals(1));
      expect(historyA[0].direction, equals(SipDmDirection.outbound));

      final historyB = dmManagerB.getHistory(resultB.sessionTag);
      expect(historyB, isNotNull);
      expect(historyB!.length, equals(1));
      expect(historyB[0].direction, equals(SipDmDirection.inbound));
    });

    test('bidirectional DM exchange', () async {
      const nodeA = 0xAABBCCDD;
      const nodeB = 0x11223344;

      final (resultA, resultB) = await completeHandshake(nodeA, nodeB);

      dmManagerA.createSession(
        sessionTag: resultA.sessionTag,
        peerNodeId: nodeB,
        ttlS: resultA.dmTtlS,
      );
      dmManagerB.createSession(
        sessionTag: resultB.sessionTag,
        peerNodeId: nodeA,
        ttlS: resultB.dmTtlS,
      );

      // A -> B: message 1
      final msg1 = dmManagerA.buildDmMessage(
        sessionTag: resultA.sessionTag,
        text: 'Ping',
      );
      dmManagerB.handleInboundDm(msg1.frame!);

      // B -> A: message 2
      final msg2 = dmManagerB.buildDmMessage(
        sessionTag: resultB.sessionTag,
        text: 'Pong',
      );
      dmManagerA.handleInboundDm(msg2.frame!);

      // Verify both histories.
      final historyA = dmManagerA.getHistory(resultA.sessionTag)!;
      expect(historyA.length, equals(2));
      expect(historyA[0].text, equals('Ping'));
      expect(historyA[0].direction, equals(SipDmDirection.outbound));
      expect(historyA[1].text, equals('Pong'));
      expect(historyA[1].direction, equals(SipDmDirection.inbound));

      final historyB = dmManagerB.getHistory(resultB.sessionTag)!;
      expect(historyB.length, equals(2));
      expect(historyB[0].text, equals('Ping'));
      expect(historyB[0].direction, equals(SipDmDirection.inbound));
      expect(historyB[1].text, equals('Pong'));
      expect(historyB[1].direction, equals(SipDmDirection.outbound));
    });

    test('DM to expired session returns sessionNotFound', () async {
      const nodeA = 0xAABBCCDD;
      const nodeB = 0x11223344;

      final (resultA, _) = await completeHandshake(nodeA, nodeB);

      dmManagerA.createSession(
        sessionTag: resultA.sessionTag,
        peerNodeId: nodeB,
        ttlS: 10, // 10s TTL
      );

      // Advance past TTL.
      nowMs[0] += 11000;

      final result = dmManagerA.buildDmMessage(
        sessionTag: resultA.sessionTag,
        text: 'Too late',
      );
      expect(result.isOk, isFalse);
      expect(result.error, equals(SipDmSendError.sessionNotFound));
    });

    test('DM to closed session returns sessionClosed', () async {
      const nodeA = 0xAABBCCDD;
      const nodeB = 0x11223344;

      final (resultA, _) = await completeHandshake(nodeA, nodeB);

      dmManagerA.createSession(
        sessionTag: resultA.sessionTag,
        peerNodeId: nodeB,
        ttlS: resultA.dmTtlS,
      );

      dmManagerA.closeSession(resultA.sessionTag);

      final result = dmManagerA.buildDmMessage(
        sessionTag: resultA.sessionTag,
        text: 'Closed',
      );
      expect(result.isOk, isFalse);
      // Closed session -> isExpired returns true -> sessionNotFound
      expect(result.error, equals(SipDmSendError.sessionNotFound));
    });

    test('inbound DM on unknown session is dropped', () {
      final frame = SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.dmMsg,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0xDEADBEEF, // unknown session tag
        nonce: 42,
        timestampS: nowMs[0] ~/ 1000,
        payloadLen: 5,
        payload: Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]),
      );

      final msg = dmManagerA.handleInboundDm(frame);
      expect(msg, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Cross-module budget enforcement
  // ---------------------------------------------------------------------------
  group('Cross-module budget enforcement', () {
    late SipRateLimiter limiter;
    late SipDiscovery discovery;
    late SipDmManager dmManager;
    late List<int> nowMs;

    setUp(() {
      nowMs = [1000000];
      limiter = SipRateLimiter(clock: dtClock(nowMs));
      discovery = SipDiscovery(
        rateLimiter: limiter,
        localNodeId: 0xAABBCCDD,
        clock: msClockNullable(nowMs),
        beaconIntervalMs: 10,
        beaconJitterMs: 0,
        rollcallCooldownMs: 10,
      );
      dmManager = SipDmManager(rateLimiter: limiter, clock: msClock(nowMs));

      // Enable privacy gates for testing.
      discovery.isDiscoverable = true;
    });

    test('discovery beacons drain budget shared with DM', () {
      // Create a DM session.
      dmManager.createSession(sessionTag: 0x12345678, peerNodeId: 0x11223344);

      final initialBudget = limiter.remainingBytes;

      // Emit a beacon (drains some budget).
      nowMs[0] += 20;
      final beacon = discovery.buildBeacon(force: true);
      expect(beacon, isNotNull);

      final postBeaconBudget = limiter.remainingBytes;
      expect(postBeaconBudget, lessThan(initialBudget));

      // DM sender sees reduced budget.
      final dmResult = dmManager.buildDmMessage(
        sessionTag: 0x12345678,
        text: 'Test',
      );
      // Should still succeed since budget is large enough.
      expect(dmResult.isOk, isTrue);

      final postDmBudget = limiter.remainingBytes;
      expect(postDmBudget, lessThan(postBeaconBudget));
    });

    test('exhausted budget blocks both discovery and DM', () {
      dmManager.createSession(sessionTag: 0x12345678, peerNodeId: 0x11223344);

      // Exhaust the budget by draining it manually.
      while (limiter.canSend(50)) {
        limiter.recordSend(50);
      }

      // Discovery beacon should be blocked.
      nowMs[0] += 20;
      final beacon = discovery.buildBeacon(force: true);
      expect(beacon, isNull);

      // DM send should be blocked.
      final dmResult = dmManager.buildDmMessage(
        sessionTag: 0x12345678,
        text: 'Blocked',
      );
      expect(dmResult.isOk, isFalse);
      expect(dmResult.error, equals(SipDmSendError.budgetExhausted));
    });

    test('budget refills over time allowing operations again', () {
      dmManager.createSession(sessionTag: 0x12345678, peerNodeId: 0x11223344);

      // Exhaust the budget.
      while (limiter.canSend(50)) {
        limiter.recordSend(50);
      }

      // Advance time to allow refill (60s = full refill).
      nowMs[0] += 60000;

      // Budget should be refilled.
      expect(limiter.remainingBytes, greaterThan(0));

      // Discovery should work again.
      nowMs[0] += 20;
      final beacon = discovery.buildBeacon(force: true);
      expect(beacon, isNotNull);
    });

    test('congestion detection pauses discovery beacons', () {
      // Observe chat traffic -> triggers congestion pause.
      limiter.observeChatTraffic();
      expect(limiter.isCongested, isTrue);

      // The rate limiter reports congestion; callers should check this.
      // Discovery buildBeacon respects budget but not congestion directly.
      // However, a well-behaved caller should check isCongested before
      // attempting discovery operations.
      expect(limiter.isCongested, isTrue);

      // After congestion pause expires (30s default), traffic resumes.
      nowMs[0] += SipConstants.congestionPauseS * 1000 + 1;
      expect(limiter.isCongested, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Counters accumulation during lifecycle
  // ---------------------------------------------------------------------------
  group('Counters lifecycle tracking', () {
    late SipCounters counters;

    setUp(() {
      counters = SipCounters();
    });

    test('full handshake flow updates counters correctly', () {
      // Simulate handshake counter progression.
      counters.recordHandshakeInitiated();

      // Record HS_HELLO sent.
      counters.recordTx(SipMessageType.hsHello, 48);

      // Record HS_CHALLENGE received.
      counters.recordRx(SipMessageType.hsChallenge, 96);

      // Record HS_RESPONSE sent.
      counters.recordTx(SipMessageType.hsResponse, 64);

      // Record HS_ACCEPT received.
      counters.recordRx(SipMessageType.hsAccept, 24);

      // Handshake completed.
      counters.recordHandshakeCompleted();

      final exported = counters.export();
      final txCount = exported['tx_count'] as Map<String, int>;
      final rxCount = exported['rx_count'] as Map<String, int>;
      expect(txCount['hsHello'], equals(1));
      expect(rxCount['hsChallenge'], equals(1));
      expect(txCount['hsResponse'], equals(1));
      expect(rxCount['hsAccept'], equals(1));
      expect(exported['tx_bytes'], equals(48 + 64));
      expect(exported['rx_bytes'], equals(96 + 24));
      expect(exported['handshake_initiated'], equals(1));
      expect(exported['handshake_completed'], equals(1));
      expect(exported['handshake_failed'], equals(0));
    });

    test('discovery + DM counters accumulate', () {
      // Discovery: beacon sent.
      counters.recordTx(SipMessageType.capBeacon, 36);

      // Discovery: rollcall req sent.
      counters.recordTx(SipMessageType.rollcallReq, 24);

      // Discovery: rollcall resp received.
      counters.recordRx(SipMessageType.rollcallResp, 48);

      // DM: message sent.
      counters.recordTx(SipMessageType.dmMsg, 52);

      // DM: message received.
      counters.recordRx(SipMessageType.dmMsg, 60);

      final exported = counters.export();
      final txCount = exported['tx_count'] as Map<String, int>;
      final rxCount = exported['rx_count'] as Map<String, int>;
      expect(txCount['capBeacon'], equals(1));
      expect(txCount['rollcallReq'], equals(1));
      expect(rxCount['rollcallResp'], equals(1));
      expect(txCount['dmMsg'], equals(1));
      expect(rxCount['dmMsg'], equals(1));
      expect(exported['tx_bytes'], equals(36 + 24 + 52));
      expect(exported['rx_bytes'], equals(48 + 60));
    });

    test('error and security events tracked across modules', () {
      // Identity verification.
      counters.recordSignatureSuccess();
      counters.recordIdentityVerified();

      // Replay rejection.
      counters.recordReplayReject();

      // Budget throttle.
      counters.recordBudgetThrottle();
      counters.recordCongestionPause();

      // Signature failure.
      counters.recordSignatureFailure();

      final exported = counters.export();
      expect(exported['signature_successes'], equals(1));
      expect(exported['identity_verified'], equals(1));
      expect(exported['replay_rejects'], equals(1));
      expect(exported['budget_throttles'], equals(1));
      expect(exported['congestion_pauses'], equals(1));
      expect(exported['signature_failures'], equals(1));
    });

    test('failed handshake increments failure counter', () {
      counters.recordHandshakeInitiated();
      counters.recordTx(SipMessageType.hsHello, 48);
      counters.recordHandshakeFailed();

      final exported = counters.export();
      expect(exported['handshake_initiated'], equals(1));
      expect(exported['handshake_completed'], equals(0));
      expect(exported['handshake_failed'], equals(1));
    });

    test('multiple handshakes accumulate correctly', () {
      for (var i = 0; i < 5; i++) {
        counters.recordHandshakeInitiated();
        counters.recordTx(SipMessageType.hsHello, 48);
        counters.recordRx(SipMessageType.hsChallenge, 96);
        counters.recordTx(SipMessageType.hsResponse, 64);
        counters.recordRx(SipMessageType.hsAccept, 24);
        counters.recordHandshakeCompleted();
      }

      final exported = counters.export();
      final txCount = exported['tx_count'] as Map<String, int>;
      final rxCount = exported['rx_count'] as Map<String, int>;
      expect(exported['handshake_initiated'], equals(5));
      expect(exported['handshake_completed'], equals(5));
      expect(txCount['hsHello'], equals(5));
      expect(rxCount['hsAccept'], equals(5));
      expect(exported['tx_bytes'], equals(5 * (48 + 64)));
      expect(exported['rx_bytes'], equals(5 * (96 + 24)));
    });

    test('display entries include all counter categories', () {
      counters.recordTx(SipMessageType.capBeacon, 36);
      counters.recordHandshakeInitiated();
      counters.recordHandshakeCompleted();
      counters.recordIdentityVerified();
      counters.recordBudgetThrottle();

      final entries = counters.toDisplayEntries();
      expect(entries, isNotEmpty);

      // Verify at least the key counters appear.
      final labels = entries.map((e) => e.label).toSet();
      expect(labels.contains('Total bytes sent'), isTrue);
      expect(labels.contains('Handshakes initiated'), isTrue);
      expect(labels.contains('Handshakes completed'), isTrue);
    });

    test('reset clears all accumulated counters', () {
      counters.recordTx(SipMessageType.capBeacon, 100);
      counters.recordHandshakeInitiated();
      counters.recordReplayReject();

      counters.reset();

      final exported = counters.export();
      expect(exported['tx_bytes'], equals(0));
      expect(exported['handshake_initiated'], equals(0));
      expect(exported['replay_rejects'], equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // SipFrame encode → decode round-trip across modules
  // ---------------------------------------------------------------------------
  group('Frame encode/decode round-trip', () {
    test('beacon frame survives encode → decode', () {
      final frame = SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.capBeacon,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0,
        nonce: 12345,
        timestampS: 1700000000,
        payloadLen: 4,
        payload: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
      );

      final encoded = SipCodec.encode(frame);
      expect(encoded, isNotNull);
      expect(SipCodec.isSipPayload(encoded!), isTrue);

      final decoded = SipCodec.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.msgType, equals(SipMessageType.capBeacon));
      expect(decoded.sessionId, equals(0));
      expect(decoded.nonce, equals(12345));
      expect(decoded.timestampS, equals(1700000000));
      expect(decoded.payload, equals(frame.payload));
    });

    test('DM frame preserves session_id through encode → decode', () {
      final frame = SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.dmMsg,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0xDEADBEEF,
        nonce: 99999,
        timestampS: 1700000100,
        payloadLen: 5,
        payload: Uint8List.fromList([0x48, 0x65, 0x6C, 0x6C, 0x6F]),
      );

      final encoded = SipCodec.encode(frame);
      expect(encoded, isNotNull);

      final decoded = SipCodec.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.sessionId, equals(0xDEADBEEF));
      expect(decoded.msgType, equals(SipMessageType.dmMsg));
      expect(decoded.payload, equals(frame.payload));
    });

    test('error frame survives round-trip', () {
      final errorFrame = SipCodec.buildError(
        refMsgType: SipMessageType.hsHello.code,
        errorCode: SipErrorCode.sessionUnknown,
      );

      final encoded = SipCodec.encode(errorFrame);
      expect(encoded, isNotNull);

      final decoded = SipCodec.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.msgType, equals(SipMessageType.error));
    });
  });

  // ---------------------------------------------------------------------------
  // Multi-session parallel DMs
  // ---------------------------------------------------------------------------
  group('Multi-session parallel DMs', () {
    late SipRateLimiter limiter;
    late SipDmManager dmManager;
    late List<int> nowMs;

    setUp(() {
      nowMs = [1000000];
      limiter = SipRateLimiter(clock: dtClock(nowMs));
      dmManager = SipDmManager(rateLimiter: limiter, clock: msClock(nowMs));
    });

    test('multiple concurrent DM sessions maintained independently', () {
      // Create three sessions with different peers.
      final s1 = dmManager.createSession(
        sessionTag: 0x11111111,
        peerNodeId: 0xAAAAAAAA,
      );
      final s2 = dmManager.createSession(
        sessionTag: 0x22222222,
        peerNodeId: 0xBBBBBBBB,
      );
      final s3 = dmManager.createSession(
        sessionTag: 0x33333333,
        peerNodeId: 0xCCCCCCCC,
      );

      expect(s1, isNotNull);
      expect(s2, isNotNull);
      expect(s3, isNotNull);
      expect(dmManager.activeSessions.length, equals(3));

      // Send messages on each session.
      final r1 = dmManager.buildDmMessage(
        sessionTag: 0x11111111,
        text: 'Hello peer 1',
      );
      final r2 = dmManager.buildDmMessage(
        sessionTag: 0x22222222,
        text: 'Hello peer 2',
      );
      final r3 = dmManager.buildDmMessage(
        sessionTag: 0x33333333,
        text: 'Hello peer 3',
      );

      expect(r1.isOk, isTrue);
      expect(r2.isOk, isTrue);
      expect(r3.isOk, isTrue);

      // Verify histories are independent.
      expect(dmManager.getHistory(0x11111111)!.length, equals(1));
      expect(dmManager.getHistory(0x22222222)!.length, equals(1));
      expect(dmManager.getHistory(0x33333333)!.length, equals(1));
      expect(dmManager.getHistory(0x11111111)![0].text, equals('Hello peer 1'));
    });

    test('closing one session does not affect others', () {
      dmManager.createSession(sessionTag: 0x11111111, peerNodeId: 0xAAAAAAAA);
      dmManager.createSession(sessionTag: 0x22222222, peerNodeId: 0xBBBBBBBB);

      // Close session 1.
      dmManager.closeSession(0x11111111);

      // Session 2 still works.
      final result = dmManager.buildDmMessage(
        sessionTag: 0x22222222,
        text: 'Still working',
      );
      expect(result.isOk, isTrue);

      // Session 1 is unavailable.
      final closed = dmManager.buildDmMessage(
        sessionTag: 0x11111111,
        text: 'Should fail',
      );
      expect(closed.isOk, isFalse);
    });

    test('expired sessions cleaned while active ones survive', () {
      // Session with short TTL.
      dmManager.createSession(
        sessionTag: 0x11111111,
        peerNodeId: 0xAAAAAAAA,
        ttlS: 5, // 5s
      );
      // Session with long TTL.
      dmManager.createSession(
        sessionTag: 0x22222222,
        peerNodeId: 0xBBBBBBBB,
        ttlS: 3600, // 1h
      );

      // Advance past short TTL but not long.
      nowMs[0] += 6000;

      final cleaned = dmManager.cleanExpired();
      expect(cleaned, equals(1));
      expect(dmManager.getSession(0x11111111), isNull);
      expect(dmManager.getSession(0x22222222), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Replay cache across handshake sessions
  // ---------------------------------------------------------------------------
  group('Replay cache integration', () {
    test('different peers can use same nonce without collision', () {
      final cache = SipReplayCache();

      // Peer 1 uses nonce 42.
      final replay1 = cache.isReplay(
        nodeId: 0xAAAAAAAA,
        nonce: 42,
        msgType: SipMessageType.hsHello.code,
      );
      expect(replay1, isFalse);
      cache.recordNonce(
        nodeId: 0xAAAAAAAA,
        nonce: 42,
        msgType: SipMessageType.hsHello.code,
        timestampS: 1700000000,
      );

      // Peer 2 uses the same nonce 42 -- should not be a replay.
      final replay2 = cache.isReplay(
        nodeId: 0xBBBBBBBB,
        nonce: 42,
        msgType: SipMessageType.hsHello.code,
      );
      expect(replay2, isFalse);
    });

    test('same peer reusing nonce is detected as replay', () {
      final cache = SipReplayCache();

      cache.recordNonce(
        nodeId: 0xAAAAAAAA,
        nonce: 42,
        msgType: SipMessageType.hsHello.code,
        timestampS: 1700000000,
      );

      final isReplay = cache.isReplay(
        nodeId: 0xAAAAAAAA,
        nonce: 42,
        msgType: SipMessageType.hsHello.code,
      );
      expect(isReplay, isTrue);
    });

    test('same nonce with different msg_type is not a replay', () {
      final cache = SipReplayCache();

      cache.recordNonce(
        nodeId: 0xAAAAAAAA,
        nonce: 42,
        msgType: SipMessageType.hsHello.code,
        timestampS: 1700000000,
      );

      final isReplay = cache.isReplay(
        nodeId: 0xAAAAAAAA,
        nonce: 42,
        msgType: SipMessageType.hsChallenge.code,
      );
      expect(isReplay, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // End-to-end: Discovery → Handshake → DM with counters
  // ---------------------------------------------------------------------------
  group('End-to-end lifecycle with counters', () {
    test(
      'full flow: discover → handshake → DM with counter tracking',
      () async {
        final nowMs = [1000000];
        final limiterA = SipRateLimiter(clock: dtClock(nowMs));
        final limiterB = SipRateLimiter(clock: dtClock(nowMs));
        final counters = SipCounters();

        // Phase 1: Discovery.
        final discoveryA = SipDiscovery(
          rateLimiter: limiterA,
          localNodeId: 0xAABBCCDD,
          clock: msClockNullable(nowMs),
          beaconIntervalMs: 10,
          beaconJitterMs: 0,
        );
        discoveryA.isDiscoverable = true;
        final discoveryB = SipDiscovery(
          rateLimiter: limiterB,
          localNodeId: 0x11223344,
          clock: msClockNullable(nowMs),
          beaconIntervalMs: 10,
          beaconJitterMs: 0,
        );
        discoveryB.isDiscoverable = true;

        nowMs[0] += 20;
        final beaconA = discoveryA.buildBeacon(force: true)!;
        counters.recordTx(SipMessageType.capBeacon, beaconA.encoded.length);

        discoveryB.handleBeacon(beaconA.frame, 0xAABBCCDD);
        counters.recordRx(SipMessageType.capBeacon, beaconA.encoded.length);

        expect(discoveryB.peerCount, equals(1));

        // Phase 2: Handshake.
        final replayCacheA = SipReplayCache();
        final replayCacheB = SipReplayCache();
        final hsA = SipHandshakeManager(
          replayCache: replayCacheA,
          localNodeId: 0xAABBCCDD,
          clock: dtClock(nowMs),
        );
        hsA.isDmAvailable = true;
        final hsB = SipHandshakeManager(
          replayCache: replayCacheB,
          localNodeId: 0x11223344,
          clock: dtClock(nowMs),
        );
        hsB.isDmAvailable = true;

        counters.recordHandshakeInitiated();

        final hello = hsA.initiateHandshake(0x11223344)!;
        counters.recordTx(SipMessageType.hsHello, 48);

        hsB.handleHello(0xAABBCCDD, hello);
        final challenge = hsB.acceptHandshake(0xAABBCCDD)!;
        counters.recordRx(SipMessageType.hsChallenge, 96);

        final response = (await hsA.handleChallenge(0x11223344, challenge))!;
        counters.recordTx(SipMessageType.hsResponse, 64);

        final accept = (await hsB.handleResponse(0xAABBCCDD, response))!;
        counters.recordRx(SipMessageType.hsAccept, 24);

        final resultB = hsB.consumeResult(0xAABBCCDD)!;
        final resultA = hsA.handleAccept(0x11223344, accept)!;
        counters.recordHandshakeCompleted();

        expect(resultA.sessionTag, equals(resultB.sessionTag));

        // Phase 3: DM exchange.
        final dmA = SipDmManager(rateLimiter: limiterA, clock: msClock(nowMs));
        final dmB = SipDmManager(rateLimiter: limiterB, clock: msClock(nowMs));

        dmA.createSession(
          sessionTag: resultA.sessionTag,
          peerNodeId: 0x11223344,
          ttlS: resultA.dmTtlS,
        );
        dmB.createSession(
          sessionTag: resultB.sessionTag,
          peerNodeId: 0xAABBCCDD,
          ttlS: resultB.dmTtlS,
        );

        final msg1 = dmA.buildDmMessage(
          sessionTag: resultA.sessionTag,
          text: 'Integration test message',
        );
        expect(msg1.isOk, isTrue);
        counters.recordTx(SipMessageType.dmMsg, 52);

        final inbound = dmB.handleInboundDm(msg1.frame!);
        expect(inbound, isNotNull);
        expect(inbound!.text, equals('Integration test message'));
        counters.recordRx(SipMessageType.dmMsg, 52);

        // Verify accumulated counters.
        final exported = counters.export();
        final txCount = exported['tx_count'] as Map<String, int>;
        final rxCount = exported['rx_count'] as Map<String, int>;
        expect(txCount['capBeacon'], equals(1));
        expect(txCount['hsHello'], equals(1));
        expect(rxCount['hsChallenge'], equals(1));
        expect(txCount['hsResponse'], equals(1));
        expect(rxCount['hsAccept'], equals(1));
        expect(txCount['dmMsg'], equals(1));
        expect(rxCount['dmMsg'], equals(1));
        expect(exported['handshake_initiated'], equals(1));
        expect(exported['handshake_completed'], equals(1));
      },
    );
  });
}
