// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pure-helper tests for the SIP Play capability gate. The router's
// `sendPlay` consults `evaluatePlaySendCapability` to decide whether
// an outbound play frame should be transmitted; the helper splits
// the gate by action so a stale discovery cap cache (peer
// passively-discovered with `features=0x1`, never advertised
// `dmPlayV1`) cannot block lifecycle responses to an inbound offer.
//
// Regression for the field-test bug where Accept / Decline on an
// inbound offer surfaced "This conversation has ended." because the
// router was applying the offer-strict cap gate to response actions.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/sip_dm_secure_router.dart';
import 'package:socialmesh/services/protocol/sip/play/sip_play_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';

SipDmManager _newDm() {
  return SipDmManager(rateLimiter: SipRateLimiter(), clock: () => 1000000);
}

SipDmHistoryEntry _inboundPlayEntry({
  required Uint8List payload,
  int timestampMs = 1000000,
}) {
  return SipDmHistoryEntry(
    text: '',
    timestampMs: timestampMs,
    direction: SipDmDirection.inbound,
    contentType: SipDmContentType.play,
    payload: payload,
  );
}

SipDmHistoryEntry _outboundPlayEntry({
  required Uint8List payload,
  int timestampMs = 1000000,
}) {
  return SipDmHistoryEntry(
    text: '',
    timestampMs: timestampMs,
    direction: SipDmDirection.outbound,
    contentType: SipDmContentType.play,
    payload: payload,
  );
}

SipDmHistoryEntry _inboundTextEntry({int timestampMs = 1000000}) {
  return SipDmHistoryEntry(
    text: 'hi',
    timestampMs: timestampMs,
    direction: SipDmDirection.inbound,
  );
}

void main() {
  group('evaluatePlaySendCapability — initiating offer (strict)', () {
    test('peer unknown → blocked with blockedPeerUnknown', () {
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.offer,
        peerKnown: false,
        peerSupportsDmPlayV1: false,
        sessionWitnessedInboundPlay: false,
      );
      expect(decision.allowed, isFalse);
      expect(
        decision.reason,
        equals(SipPlaySendCapabilityReason.blockedPeerUnknown),
      );
    });

    test('peer known, no dmPlayV1 → blocked with blockedNoCapability', () {
      // The user's reported scenario: features=0x1 from passive
      // discovery, no CAP_RESP advertising dmPlayV1 yet.
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.offer,
        peerKnown: true,
        peerSupportsDmPlayV1: false,
        sessionWitnessedInboundPlay: false,
      );
      expect(decision.allowed, isFalse);
      expect(
        decision.reason,
        equals(SipPlaySendCapabilityReason.blockedNoCapability),
      );
    });

    test(
      'peer known, no dmPlayV1, but session has inbound play → still blocked '
      '(initiating offer is strict; session evidence does not promote)',
      () {
        // Even though the peer demonstrably produced play frames
        // (we see them in session history), launching a NEW offer
        // remains gated on discovery capability — the user spec is
        // explicit: "Outbound new offer to peer with no dmPlay
        // capability -> still blocked."
        final decision = evaluatePlaySendCapability(
          action: SipPlayAction.offer,
          peerKnown: true,
          peerSupportsDmPlayV1: false,
          sessionWitnessedInboundPlay: true,
        );
        expect(decision.allowed, isFalse);
        expect(
          decision.reason,
          equals(SipPlaySendCapabilityReason.blockedNoCapability),
        );
      },
    );

    test('peer supports dmPlayV1 → allowed with initiating reason', () {
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.offer,
        peerKnown: true,
        peerSupportsDmPlayV1: true,
        sessionWitnessedInboundPlay: false,
      );
      expect(decision.allowed, isTrue);
      expect(
        decision.reason,
        equals(SipPlaySendCapabilityReason.initiatingOfferRequiresCapability),
      );
    });
  });

  group('evaluatePlaySendCapability — lifecycle response (session-aware)', () {
    test('decline + stale discovery + session has inbound play → allowed by '
        'session evidence (THE CORE BUG FIX)', () {
      // Repro of the user-reported regression: the peer sent us a
      // dmPlay offer (so it's in session.messages as inbound play),
      // but the discovery cap cache only ever observed
      // features=0x1, so peer.supportsDmPlayV1 is false. The router
      // must allow the decline anyway — the user has a pending UI
      // bubble they need to be able to dismiss.
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.decline,
        peerKnown: true,
        peerSupportsDmPlayV1: false,
        sessionWitnessedInboundPlay: true,
      );
      expect(decision.allowed, isTrue);
      expect(
        decision.reason,
        equals(
          SipPlaySendCapabilityReason.lifecycleResponseAllowedBySessionEvidence,
        ),
      );
    });

    test('accept + stale discovery + session has inbound play → allowed by '
        'session evidence', () {
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.accept,
        peerKnown: true,
        peerSupportsDmPlayV1: false,
        sessionWitnessedInboundPlay: true,
      );
      expect(decision.allowed, isTrue);
      expect(
        decision.reason,
        equals(
          SipPlaySendCapabilityReason.lifecycleResponseAllowedBySessionEvidence,
        ),
      );
    });

    test('resign + session evidence → allowed by session evidence', () {
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.resign,
        peerKnown: false, // even peer-unknown is fine for resign
        peerSupportsDmPlayV1: false,
        sessionWitnessedInboundPlay: true,
      );
      expect(decision.allowed, isTrue);
      expect(
        decision.reason,
        equals(
          SipPlaySendCapabilityReason.lifecycleResponseAllowedBySessionEvidence,
        ),
      );
    });

    test('move + session evidence → allowed by session evidence', () {
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.move,
        peerKnown: true,
        peerSupportsDmPlayV1: false,
        sessionWitnessedInboundPlay: true,
      );
      expect(decision.allowed, isTrue);
      expect(
        decision.reason,
        equals(
          SipPlaySendCapabilityReason.lifecycleResponseAllowedBySessionEvidence,
        ),
      );
    });

    test('accept + no session evidence + peer supports dmPlayV1 → allowed by '
        'discovery capability fallback', () {
      // Self-initiated game flow: we sent the outbound offer, peer
      // sent inbound accept, but at this very instant there's still
      // no inbound dmPlay yet (e.g. pre-accept move attempt is a
      // future invariant violation, but the helper must not block
      // legitimate paths). Discovery cap cache shows dmPlayV1 →
      // allow.
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.accept,
        peerKnown: true,
        peerSupportsDmPlayV1: true,
        sessionWitnessedInboundPlay: false,
      );
      expect(decision.allowed, isTrue);
      expect(
        decision.reason,
        equals(
          SipPlaySendCapabilityReason
              .lifecycleResponseAllowedByDiscoveryCapability,
        ),
      );
    });

    test('accept + no session evidence + no discovery capability → blocked '
        '(neither signal proves the peer can decode play frames)', () {
      final decision = evaluatePlaySendCapability(
        action: SipPlayAction.accept,
        peerKnown: true,
        peerSupportsDmPlayV1: false,
        sessionWitnessedInboundPlay: false,
      );
      expect(decision.allowed, isFalse);
      expect(
        decision.reason,
        equals(SipPlaySendCapabilityReason.blockedNoCapability),
      );
    });
  });

  group('sessionHasInboundPlay', () {
    test('empty session → false', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAAAA, peerNodeId: 0x1111);
      final session = dm.getSession(0xAAAA)!;
      expect(sessionHasInboundPlay(session), isFalse);
    });

    test('only outbound play → false', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAAAA, peerNodeId: 0x1111);
      final session = dm.getSession(0xAAAA)!;
      session.messages.add(
        _outboundPlayEntry(payload: Uint8List.fromList([1, 1, 0, 0xAA, 0, 0])),
      );
      expect(sessionHasInboundPlay(session), isFalse);
    });

    test('only inbound text → false', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAAAA, peerNodeId: 0x1111);
      final session = dm.getSession(0xAAAA)!;
      session.messages.add(_inboundTextEntry());
      expect(sessionHasInboundPlay(session), isFalse);
    });

    test('one inbound play → true', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAAAA, peerNodeId: 0x1111);
      final session = dm.getSession(0xAAAA)!;
      session.messages.add(
        _inboundPlayEntry(payload: Uint8List.fromList([1, 1, 0, 0xAA, 0, 0])),
      );
      expect(sessionHasInboundPlay(session), isTrue);
    });

    test('inbound play among other entries → true', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAAAA, peerNodeId: 0x1111);
      final session = dm.getSession(0xAAAA)!;
      session.messages
        ..add(
          _outboundPlayEntry(payload: Uint8List.fromList([1, 1, 0, 0, 0, 0])),
        )
        ..add(_inboundTextEntry())
        ..add(
          _inboundPlayEntry(payload: Uint8List.fromList([1, 1, 0, 0xAA, 0, 0])),
        );
      expect(sessionHasInboundPlay(session), isTrue);
    });
  });
}
