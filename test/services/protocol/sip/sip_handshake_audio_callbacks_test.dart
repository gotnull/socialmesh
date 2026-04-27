// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for the audio-cue callbacks added to [SipHandshakeManager]:
///
///   - [onHandshakeFailed]   — fires from `_failSession` for real
///                             failures (timeout / nonce mismatch /
///                             …) but NOT for user-initiated cancels.
///   - [onHandshakeDeclined] — fires when state transitions to
///                             [SipHandshakeState.declined] from
///                             either side (local declineHandshake
///                             tap OR inbound HS_DECLINE handling).
///
/// These callbacks are the only protocol-layer hook the SIP Play
/// SFX service needs. Decoupled from the audio backend so the
/// manager remains pure.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';

SipHandshakeManager _newManager({int localNodeId = 0xAAAA}) {
  final mgr = SipHandshakeManager(
    replayCache: SipReplayCache(),
    localNodeId: localNodeId,
  );
  mgr.isDmAvailable = true;
  return mgr;
}

void main() {
  group('SipHandshakeManager.onHandshakeFailed', () {
    test('fires on timeout (real failure)', () {
      FakeAsync().run((fake) {
        final mgr = _newManager();
        final failures = <int>[];
        mgr.onHandshakeFailed = failures.add;

        final hello = mgr.initiateHandshake(0xBEEF);
        expect(hello, isNotNull);

        // Drive past the wire-handshake timeout — _cleanExpired will
        // call _failSession with reason='timeout' on the next
        // initiateHandshake call (or session-expiry timer).
        fake.elapse(SipConstants.handshakeTimeout + const Duration(seconds: 1));
        // initiateHandshake calls _cleanExpired, which fails any
        // timed-out sessions with reason='timeout'.
        mgr.initiateHandshake(0xBEEF, overrideCooldown: true);

        expect(
          failures,
          contains(0xBEEF),
          reason: 'timeout failure must invoke onHandshakeFailed',
        );
      });
    });

    test(
      'does NOT fire when reason is "cancelled" (Block / cancelHandshake)',
      () {
        // Block flow calls cancelHandshake → _failSession('cancelled').
        // The user already chose silent action — playing a failure SFX
        // would be wrong.
        final mgr = _newManager();
        final failures = <int>[];
        mgr.onHandshakeFailed = failures.add;

        mgr.initiateHandshake(0xBEEF);
        mgr.cancelHandshake(0xBEEF);

        expect(
          failures,
          isEmpty,
          reason:
              'cancelled reason must be suppressed so Block / explicit '
              'cancels stay silent',
        );
      },
    );

    test('hook exception is caught (never breaks the manager)', () {
      final mgr = _newManager();
      mgr.onHandshakeFailed = (_) => throw StateError('boom');

      // Drive a normal failure path. The throwing hook must not
      // bubble; manager state remains consistent.
      FakeAsync().run((fake) {
        mgr.initiateHandshake(0xBEEF);
        fake.elapse(SipConstants.handshakeTimeout + const Duration(seconds: 1));
        // No exception escapes — initiate sweeps cleanExpired which
        // calls the throwing hook internally.
        mgr.initiateHandshake(0xBEEF, overrideCooldown: true);
      });
    });
  });

  group('SipHandshakeManager.onHandshakeDeclined', () {
    test('fires when local user calls declineHandshake on a pending '
        'inbound handshake', () {
      // Cooperative pattern — initiator B sends HS_HELLO to manager A;
      // A queues a pending request; A taps Decline; the hook fires.
      const nodeA = 0x1111;
      const nodeB = 0x2222;
      final replay = SipReplayCache();
      final mgrA = SipHandshakeManager(replayCache: replay, localNodeId: nodeA)
        ..isDmAvailable = true;
      final mgrB = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: nodeB,
      )..isDmAvailable = true;

      final declined = <int>[];
      mgrA.onHandshakeDeclined = declined.add;

      final helloFromB = mgrB.initiateHandshake(nodeA);
      expect(helloFromB, isNotNull);
      mgrA.handleHello(nodeB, helloFromB!);

      final declineFrame = mgrA.declineHandshake(nodeB);
      expect(declineFrame, isNotNull);
      expect(declined, equals([nodeB]));
    });

    test('fires when inbound HS_DECLINE arrives (peer rejected our '
        'outbound handshake)', () {
      // Local A initiates → remote B declines. A's manager calls
      // handleDecline; the hook must fire on A's side.
      const nodeA = 0xAAAA;
      const nodeB = 0xBBBB;
      final replay = SipReplayCache();
      final mgrA = SipHandshakeManager(replayCache: replay, localNodeId: nodeA)
        ..isDmAvailable = true;
      final mgrB = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: nodeB,
      )..isDmAvailable = true;

      final declinedA = <int>[];
      mgrA.onHandshakeDeclined = declinedA.add;

      // A initiates → B receives → B declines → A handles HS_DECLINE.
      final helloFromA = mgrA.initiateHandshake(nodeB);
      expect(helloFromA, isNotNull);
      mgrB.handleHello(nodeA, helloFromA!);
      final declineFromB = mgrB.declineHandshake(nodeA);
      expect(declineFromB, isNotNull);
      mgrA.handleDecline(nodeB, declineFromB!);

      expect(
        declinedA,
        equals([nodeB]),
        reason:
            'inbound HS_DECLINE must invoke onHandshakeDeclined on '
            'the originator side',
      );
    });

    test('hook exception is caught (never breaks declineHandshake)', () {
      const nodeA = 0x1111;
      const nodeB = 0x2222;
      final mgrA = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: nodeA,
      )..isDmAvailable = true;
      final mgrB = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: nodeB,
      )..isDmAvailable = true;

      mgrA.onHandshakeDeclined = (_) => throw StateError('boom');

      final helloFromB = mgrB.initiateHandshake(nodeA);
      mgrA.handleHello(nodeB, helloFromB!);

      // Throwing hook must not propagate — declineHandshake should
      // still return a valid frame for transmission.
      final declineFrame = mgrA.declineHandshake(nodeB);
      expect(declineFrame, isNotNull);
    });
  });
}
