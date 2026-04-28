// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the peer-driven HS_CHALLENGE re-emit added after a field
/// "Could not connect" report where a single dropped CHALLENGE wedged
/// both sides in `challengeSent` / `helloSent` until the 60 s timeout
/// pushed them into a 120 s cooldown.
///
/// The fix uses the peer's continuing HS_HELLO retransmits as a
/// loss-detection signal: when we sit in [SipHandshakeState.challengeSent]
/// and the peer is still HELLO-retransmitting against the same
/// client_nonce, our previous CHALLENGE never arrived. Re-send the
/// cached frame on the same rate-limited path. Throttled to one re-emit
/// every 4 s per session so multi-hop rebroadcast can't trigger a
/// flurry. No new session, no fresh nonce, no expiry/cooldown reset —
/// the handshake stays the same attempt.
library;

import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_messages_hs.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

/// Build a manager wired to the ambient `package:clock` instance. Inside
/// [FakeAsync.run] this resolves to the simulated time, so the throttle's
/// elapsed-time math and the post-failure cooldown clear advance with
/// `fake.elapse`. Outside FakeAsync it falls through to wall-clock.
SipHandshakeManager _newManager({int localNodeId = 0xBBBB}) {
  final mgr = SipHandshakeManager(
    replayCache: SipReplayCache(),
    localNodeId: localNodeId,
    clock: () => clock.now(),
  );
  mgr.isDmAvailable = true;
  return mgr;
}

/// Build a HS_HELLO frame with a controllable client_nonce and wrapper
/// nonce. The peer's HELLO retransmit cadence reuses the SAME frame
/// (identical wrapper nonce) — and so does the multi-hop rebroadcast
/// path — so re-emit detection must work on payload `clientNonce` alone,
/// not the wrapper nonce.
SipFrame _makeHello({
  required Uint8List clientNonce,
  required int wrapperNonce,
  int targetNodeId = 0xBBBB,
}) {
  final payload = SipHsMessages.encodeHello(
    SipHsHello(
      targetNodeId: targetNodeId,
      clientNonce: clientNonce,
      clientEphemeralPub: Uint8List.fromList(List.generate(32, (i) => i + 32)),
      requestedFeatures: SipFeatureBits.allV01,
    ),
  );
  if (payload == null) {
    throw StateError('encodeHello returned null in test fixture');
  }
  return SipFrame(
    versionMajor: SipConstants.sipVersionMajor,
    versionMinor: SipConstants.sipVersionMinor,
    msgType: SipMessageType.hsHello,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: 0,
    nonce: wrapperNonce,
    timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    payloadLen: payload.length,
    payload: payload,
  );
}

Uint8List _nonce(int seed) =>
    Uint8List.fromList(List.generate(16, (i) => (i + seed) & 0xFF));

void main() {
  group('SipHandshakeManager — peer-driven HS_CHALLENGE re-emit', () {
    test('dropped challenge + duplicate HELLO re-emits the same frame', () {
      final mgr = _newManager();

      final reemits = <SipFrame>[];
      mgr.onChallengeReemit = (_, frame) => reemits.add(frame);

      const peer = 0xAAAA;
      final clientNonce = _nonce(1);

      // Peer's HS_HELLO arrives, user accepts → CHALLENGE built and cached.
      mgr.handleHello(
        peer,
        _makeHello(clientNonce: clientNonce, wrapperNonce: 1),
      );
      final challenge = mgr.acceptHandshake(peer);
      expect(challenge, isNotNull);
      expect(mgr.getState(peer), SipHandshakeState.challengeSent);
      expect(reemits, isEmpty, reason: 'no re-emit on the original send');

      // Original CHALLENGE is dropped on the radio. Peer keeps
      // HELLO-retransmitting against the same client_nonce → re-emit
      // fires with the cached frame, byte-identical to the original.
      mgr.handleHello(
        peer,
        _makeHello(clientNonce: clientNonce, wrapperNonce: 2),
      );

      expect(reemits, hasLength(1));
      expect(reemits.single.msgType, SipMessageType.hsChallenge);
      expect(
        reemits.single.nonce,
        challenge!.nonce,
        reason: 're-emit must reuse the original wrapper nonce',
      );
      expect(
        reemits.single.timestampS,
        challenge.timestampS,
        reason: 're-emit must reuse the original timestamp',
      );
      expect(
        reemits.single.payload,
        equals(challenge.payload),
        reason:
            're-emit must reuse the original payload (server_nonce, '
            'echoed_client_nonce, server_ephemeral_pub, expires_in_s)',
      );
      expect(
        identical(reemits.single, challenge),
        isTrue,
        reason: 're-emit returns the exact cached frame instance',
      );
      expect(
        mgr.getState(peer),
        SipHandshakeState.challengeSent,
        reason: 're-emit must NOT advance or reset the session state',
      );
    });

    test('re-emit is throttled within the 4 s minimum interval', () {
      FakeAsync().run((fake) {
        final mgr = _newManager();

        var reemitCount = 0;
        mgr.onChallengeReemit = (_, _) => reemitCount++;

        const peer = 0xAAAA;
        final clientNonce = _nonce(2);

        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 1),
        );
        expect(mgr.acceptHandshake(peer), isNotNull);

        // First duplicate HELLO: re-emit fires.
        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 2),
        );
        expect(reemitCount, 1);

        // Three more in quick succession — all suppressed by the 4 s
        // throttle, so a multi-hop echo can't burn airtime.
        fake.elapse(const Duration(milliseconds: 500));
        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 3),
        );
        fake.elapse(const Duration(seconds: 1));
        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 4),
        );
        fake.elapse(const Duration(seconds: 2));
        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 5),
        );
        expect(
          reemitCount,
          1,
          reason: 'all duplicates inside the 4 s window must be throttled',
        );

        // Total elapsed since first re-emit: 3.5 s — still inside the
        // 4 s window. One more tick past the threshold and the next
        // duplicate is allowed through.
        fake.elapse(const Duration(milliseconds: 600));
        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 6),
        );
        expect(
          reemitCount,
          2,
          reason: 'duplicate after the throttle window must re-emit',
        );
      });
    });

    test('duplicate HELLO with a different client_nonce does NOT re-emit', () {
      // The peer started a fresh handshake attempt under a new nonce —
      // our cached CHALLENGE is bound to the previous attempt and would
      // fail the echoed_client_nonce check on the peer side. Falls
      // through to the existing duplicate-HELLO ignore branch.
      final mgr = _newManager();

      var reemitCount = 0;
      mgr.onChallengeReemit = (_, _) => reemitCount++;

      const peer = 0xAAAA;
      mgr.handleHello(
        peer,
        _makeHello(clientNonce: _nonce(3), wrapperNonce: 1),
      );
      expect(mgr.acceptHandshake(peer), isNotNull);

      // Different client_nonce simulates a fresh attempt by the peer.
      mgr.handleHello(
        peer,
        _makeHello(clientNonce: _nonce(99), wrapperNonce: 2),
      );
      expect(
        reemitCount,
        0,
        reason: 'fresh attempt under a new nonce must NOT trigger re-emit',
      );
      expect(
        mgr.getState(peer),
        SipHandshakeState.challengeSent,
        reason: 'session for the original attempt must remain intact',
      );
    });

    test('duplicate HELLO after the local side advanced does NOT re-emit', () {
      // Once the responder receives HS_RESPONSE the session terminates
      // (state = accepted, removed from `_sessions`). Late HELLO
      // duplicates from a multi-hop echo must NOT trigger a re-emit —
      // the handshake is done.
      FakeAsync().run((fake) {
        final initiator = _newManager(localNodeId: 0xAAAA);
        final responder = _newManager(localNodeId: 0xBBBB);

        var reemitCount = 0;
        responder.onChallengeReemit = (_, _) => reemitCount++;

        const nodeA = 0xAAAA;
        const nodeB = 0xBBBB;

        // Drive the full handshake to completion on the responder side.
        final hello = initiator.initiateHandshake(nodeB);
        responder.handleHello(nodeA, hello!);
        final challenge = responder.acceptHandshake(nodeA);
        SipFrame? response;
        initiator
            .handleChallenge(nodeB, challenge!)
            .then((frame) => response = frame);
        fake.flushMicrotasks();
        expect(response, isNotNull);
        responder.handleResponse(nodeA, response!);
        fake.flushMicrotasks();
        expect(
          responder.getState(nodeA),
          SipHandshakeState.accepted,
          reason: 'sanity: handshake completed end-to-end',
        );

        // Late HELLO duplicate (e.g. multi-hop rebroadcast) — must hit
        // the "already completed" branch, NOT the re-emit branch.
        final clientNonce = SipHsMessages.decodeHello(
          hello.payload,
        )!.clientNonce;
        responder.handleHello(
          nodeA,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 99),
        );
        expect(
          reemitCount,
          0,
          reason: 're-emit must not fire after the session is accepted',
        );
      });
    });

    test('re-emit does NOT reset session expiry', () {
      // The session-expiry timer is the sole authority on the
      // 60 s wire-bound handshake timeout. Re-emits driven by peer
      // duplicates must not push that timer out — otherwise a stuck
      // session could survive arbitrarily long, defeating the
      // post-failure cooldown that protects airtime.
      FakeAsync().run((fake) {
        final mgr = _newManager();
        mgr.onChallengeReemit = (_, _) {};

        const peer = 0xAAAA;
        final clientNonce = _nonce(4);

        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 1),
        );
        expect(mgr.acceptHandshake(peer), isNotNull);

        // Re-emit at t=10s and t=30s (both within the throttle limits
        // and the timeout window).
        fake.elapse(const Duration(seconds: 10));
        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 2),
        );
        fake.elapse(const Duration(seconds: 20));
        mgr.handleHello(
          peer,
          _makeHello(clientNonce: clientNonce, wrapperNonce: 3),
        );

        // Session must still be alive — we are at t=30s.
        expect(mgr.getState(peer), SipHandshakeState.challengeSent);
        expect(mgr.isInCooldown(peer), isFalse);

        // Drive across the 60 s expiry boundary. Re-emits must not
        // have pushed the timer out.
        fake.elapse(
          SipConstants.handshakeTimeout - const Duration(seconds: 29),
        );

        expect(
          mgr.getState(peer),
          isNot(SipHandshakeState.challengeSent),
          reason: 're-emits must not extend the session-expiry timer',
        );
        expect(
          mgr.isInCooldown(peer),
          isTrue,
          reason: 'failure path must apply the post-failure cooldown',
        );
      });
    });

    test(
      'cooldown after re-emit-then-timeout matches the un-modified path',
      () {
        // Pin: the re-emit must not interfere with the 120 s per-peer
        // cooldown applied by `_failSession`. A re-emit followed by a
        // timeout must end up with the same cooldown an un-touched
        // session would have, otherwise field operators could lose the
        // throttle that protects them from tight retry loops.
        FakeAsync().run((fake) {
          final mgr = _newManager();
          mgr.onChallengeReemit = (_, _) {};

          const peer = 0xAAAA;
          final clientNonce = _nonce(5);

          mgr.handleHello(
            peer,
            _makeHello(clientNonce: clientNonce, wrapperNonce: 1),
          );
          expect(mgr.acceptHandshake(peer), isNotNull);

          // Trigger a peer-driven re-emit, then let the session-expiry
          // timer fire. The expiry → `_failSession` path is what stamps
          // the cooldown.
          fake.elapse(const Duration(seconds: 10));
          mgr.handleHello(
            peer,
            _makeHello(clientNonce: clientNonce, wrapperNonce: 2),
          );
          fake.elapse(SipConstants.handshakeTimeout);

          expect(
            mgr.isInCooldown(peer),
            isTrue,
            reason: 'expiry-driven failure must engage the cooldown',
          );
          expect(
            mgr.initiateHandshake(peer),
            isNull,
            reason:
                'cooldown must block re-initiate exactly as on a session '
                'that never re-emitted',
          );

          // Sit comfortably past the cooldown window from any reasonable
          // reference point (expiry fires partway through the previous
          // elapse, so a `handshakeCooldownPerPeer + 10 s` step clears
          // the gate without being timing-fragile).
          fake.elapse(
            SipConstants.handshakeCooldownPerPeer + const Duration(seconds: 10),
          );
          expect(
            mgr.isInCooldown(peer),
            isFalse,
            reason:
                'cooldown must clear once the 120 s window has fully '
                'elapsed',
          );
        });
      },
    );
  });

  group('SipHandshakeManager — re-emit frame integrity', () {
    test('re-emit preserves server_nonce and echoed_client_nonce', () {
      // The cached CHALLENGE binds to (server_nonce, client_nonce) of
      // the original attempt. Re-emit must not regenerate either —
      // otherwise the initiator's handleChallenge would reject on
      // nonce mismatch.
      final mgr = _newManager();

      SipFrame? captured;
      mgr.onChallengeReemit = (_, frame) => captured = frame;

      const peer = 0xAAAA;
      final clientNonce = _nonce(6);

      mgr.handleHello(
        peer,
        _makeHello(clientNonce: clientNonce, wrapperNonce: 1),
      );
      final original = mgr.acceptHandshake(peer);
      expect(original, isNotNull);

      mgr.handleHello(
        peer,
        _makeHello(clientNonce: clientNonce, wrapperNonce: 2),
      );
      expect(captured, isNotNull);

      final originalChallenge = SipHsMessages.decodeChallenge(
        original!.payload,
      );
      final reemitChallenge = SipHsMessages.decodeChallenge(captured!.payload);
      expect(reemitChallenge, isNotNull);
      expect(
        reemitChallenge!.serverNonce,
        equals(originalChallenge!.serverNonce),
      );
      expect(
        reemitChallenge.echoedClientNonce,
        equals(originalChallenge.echoedClientNonce),
      );
      expect(
        reemitChallenge.serverEphemeralPub,
        equals(originalChallenge.serverEphemeralPub),
      );
      expect(reemitChallenge.expiresInS, originalChallenge.expiresInS);
    });

    test('re-emitted CHALLENGE drives the initiator forward end-to-end', () {
      // Integration shape: a dropped first CHALLENGE (we never feed it
      // to the initiator) followed by a peer-driven re-emit must let
      // the initiator complete handshake exactly as it would have on
      // the first try. Pins the wire-format invariants: the cached
      // frame is a valid CHALLENGE for the SAME session.
      FakeAsync().run((fake) {
        final initiator = _newManager(localNodeId: 0xAAAA);
        final responder = _newManager(localNodeId: 0xBBBB);

        SipFrame? reemitted;
        responder.onChallengeReemit = (_, frame) => reemitted = frame;

        const nodeA = 0xAAAA;
        const nodeB = 0xBBBB;

        final hello = initiator.initiateHandshake(nodeB);
        expect(hello, isNotNull);
        responder.handleHello(nodeA, hello!);
        final firstChallenge = responder.acceptHandshake(nodeA);
        expect(firstChallenge, isNotNull);
        // Drop firstChallenge — initiator never sees it.

        // Initiator HELLO retransmit fires (matching client_nonce).
        responder.handleHello(nodeA, hello);
        expect(reemitted, isNotNull);

        // Initiator now consumes the re-emitted CHALLENGE.
        SipFrame? response;
        initiator
            .handleChallenge(nodeB, reemitted!)
            .then((frame) => response = frame);
        fake.flushMicrotasks();
        expect(response, isNotNull);
        expect(response!.msgType, SipMessageType.hsResponse);

        // Responder accepts the response → handshake completes.
        SipFrame? accept;
        responder
            .handleResponse(nodeA, response!)
            .then((frame) => accept = frame);
        fake.flushMicrotasks();
        expect(accept, isNotNull);
        expect(accept!.msgType, SipMessageType.hsAccept);

        final result = initiator.handleAccept(nodeB, accept!);
        expect(result, isNotNull);
        expect(result!.peerNodeId, nodeB);
      });
    });
  });
}
