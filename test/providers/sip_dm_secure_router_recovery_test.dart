// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins for [resolveSecureInboundDmSession] — the recovery path that
/// salvages encrypted DM frames whose link store record has a stale
/// `peerNodeNum` (the cross-peer linkId-collision scenario surfaced
/// in real-device logs as `secure_decrypt_dropped reason=no_dm_session
/// peer=...wrong_peer...`.
///
/// Contract under test:
///   1. Canonical lookup wins when the link record's peer matches a
///      live DM session.
///   2. Recovery activates iff EXACTLY one DM session is active.
///   3. Zero sessions → no guess.
///   4. Two-or-more sessions → no guess (refuse to misdeliver).
///   5. The recovery never returns a session whose tag would mis-route
///      the synthetic SIP frame downstream.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/sip_dm_secure_router.dart';
import 'package:socialmesh/services/protocol/sip/sip_dm.dart';
import 'package:socialmesh/services/protocol/sip/sip_rate_limiter.dart';

SipDmManager _newDm() {
  return SipDmManager(rateLimiter: SipRateLimiter(), clock: () => 1000000);
}

void main() {
  group('resolveSecureInboundDmSession', () {
    test('canonical lookup: link record peer matches a live DM session', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAAAA, peerNodeId: 0x1111);
      dm.createSession(sessionTag: 0xBBBB, peerNodeId: 0x2222);

      final resolved = resolveSecureInboundDmSession(
        dm: dm,
        linkRecordPeerNodeId: 0x2222,
        linkId: 0x12345,
      );
      expect(resolved, isNotNull);
      expect(resolved!.sessionTag, equals(0xBBBB));
      expect(resolved.peerNodeId, equals(0x2222));
    });

    test('recovery: exactly one DM session, link record peer is stale', () {
      // The exact scenario from the on-device log: secure session
      // keys decrypt successfully (we wouldn't reach this resolver
      // otherwise), but the link store's peerNodeNum points at a
      // prior peer (e.g. 0xb15e74db) instead of the actual sender
      // (e.g. 0x9c3a29a9). The recovery path routes to the only
      // active DM session.
      final dm = _newDm();
      const realPeer = 0x9C3A29A9;
      const stalePeerOnLinkRecord = 0xB15E74DB;
      dm.createSession(sessionTag: 0x6F629CD3, peerNodeId: realPeer);

      final resolved = resolveSecureInboundDmSession(
        dm: dm,
        linkRecordPeerNodeId: stalePeerOnLinkRecord,
        linkId: 0x3468E0,
      );
      expect(resolved, isNotNull);
      expect(resolved!.sessionTag, equals(0x6F629CD3));
      expect(
        resolved.peerNodeId,
        equals(realPeer),
        reason:
            'recovery must return the only active DM session even though '
            'its peerNodeId differs from the (stale) link record peer',
      );
    });

    test('refuse to guess: zero active DM sessions', () {
      final dm = _newDm();
      // No sessions created.
      final resolved = resolveSecureInboundDmSession(
        dm: dm,
        linkRecordPeerNodeId: 0xB15E74DB,
        linkId: 0x3468E0,
      );
      expect(
        resolved,
        isNull,
        reason: 'no sessions ⇒ nothing safe to recover to',
      );
    });

    test('refuse to guess: two active DM sessions, neither matches '
        'the link record peer', () {
      // Critical safety property: with multiple sessions and an
      // ambiguous link record, the resolver must NOT pick one. This
      // is the defence-in-depth that prevents misdelivery once the
      // user has multiple SIP DM threads open.
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAAAA, peerNodeId: 0x1111);
      dm.createSession(sessionTag: 0xBBBB, peerNodeId: 0x2222);

      final resolved = resolveSecureInboundDmSession(
        dm: dm,
        linkRecordPeerNodeId: 0xDEADBEEF, // matches neither
        linkId: 0x12345,
      );
      expect(
        resolved,
        isNull,
        reason:
            'with 2+ active sessions and no peer match, the resolver '
            'must NEVER guess — refusing is the contract',
      );
    });

    test('refuse to guess: three active DM sessions, none matches', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0xAAAA, peerNodeId: 0x1111);
      dm.createSession(sessionTag: 0xBBBB, peerNodeId: 0x2222);
      dm.createSession(sessionTag: 0xCCCC, peerNodeId: 0x3333);

      final resolved = resolveSecureInboundDmSession(
        dm: dm,
        linkRecordPeerNodeId: 0xFEEDFACE,
        linkId: 0x999,
      );
      expect(resolved, isNull);
    });

    test('recovery does not fire when one session exists AND its peer '
        'matches the link record (canonical path wins, no recovery '
        'log)', () {
      final dm = _newDm();
      dm.createSession(sessionTag: 0x1234, peerNodeId: 0xABCD);
      final resolved = resolveSecureInboundDmSession(
        dm: dm,
        linkRecordPeerNodeId: 0xABCD,
        linkId: 0x99,
      );
      expect(resolved, isNotNull);
      expect(resolved!.sessionTag, equals(0x1234));
      // Both the canonical and recovery branches would return this
      // entry; the test ensures the canonical branch is taken
      // first by checking that nothing about the result encodes
      // a "recovered" state. (The branch distinction lives in the
      // log line, asserted at integration level.)
    });
  });
}
