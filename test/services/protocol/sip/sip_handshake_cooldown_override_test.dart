// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins the post-failure cooldown override added so the user can
/// explicitly retry a failed/timedOut handshake without waiting the
/// full 120-second throttle window.
///
/// The cooldown's purpose is to throttle automatic retransmits and
/// double-tap accidents. It must NOT lock the user out of a
/// deliberate retry from the SIP Hub or Mesh Explorer "Could not
/// connect" tile.
library;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

SipHandshakeManager _newManager({int localNodeId = 0xAAAA}) {
  final mgr = SipHandshakeManager(
    replayCache: SipReplayCache(),
    localNodeId: localNodeId,
  );
  mgr.isDmAvailable = true;
  return mgr;
}

void main() {
  group('SipHandshakeManager.initiateHandshake — cooldown override', () {
    test('default behaviour: cooldown still blocks within the window', () {
      // Mid-window retry without the override flag must still be
      // throttled — preserves the original behaviour for any caller
      // that hasn't opted in.
      FakeAsync().run((fake) {
        final mgr = _newManager();

        // Drive a handshake to the failed state via the wire-timeout
        // path: initiate, then advance past handshakeTimeout so the
        // session-expiry timer fires and _failSession sets the
        // cooldown.
        final first = mgr.initiateHandshake(0xBEEF);
        expect(first, isNotNull);
        fake.elapse(SipConstants.handshakeTimeout + const Duration(seconds: 1));
        expect(mgr.isInCooldown(0xBEEF), isTrue);

        // No-override retry within the cooldown window: blocked.
        final retry = mgr.initiateHandshake(0xBEEF);
        expect(
          retry,
          isNull,
          reason: 'cooldown must still throttle non-override retries',
        );
      });
    });

    test('overrideCooldown: explicit user retry succeeds within the '
        'cooldown window', () {
      FakeAsync().run((fake) {
        final mgr = _newManager();

        final first = mgr.initiateHandshake(0xBEEF);
        expect(first, isNotNull);
        fake.elapse(SipConstants.handshakeTimeout + const Duration(seconds: 1));
        expect(
          mgr.isInCooldown(0xBEEF),
          isTrue,
          reason: 'failure path must engage the cooldown',
        );

        final retry = mgr.initiateHandshake(0xBEEF, overrideCooldown: true);
        expect(
          retry,
          isNotNull,
          reason:
              'explicit user retry must produce a fresh HS_HELLO frame '
              'even within the throttle window',
        );
        expect(retry!.msgType, equals(SipMessageType.hsHello));

        // After the override consumed the cooldown entry, the peer
        // is no longer flagged as cooling down.
        expect(
          mgr.isInCooldown(0xBEEF),
          isFalse,
          reason:
              'overriding the cooldown must clear the entry so the '
              'next failure starts a fresh window',
        );

        // The override path also took us back to helloSent — the
        // session is live again.
        expect(mgr.getState(0xBEEF), SipHandshakeState.helloSent);
      });
    });

    test('overrideCooldown does NOT bypass other gates '
        '(in-progress session, dm-unavailable)', () {
      // The override only crosses the cooldown gate. An already-
      // tracked in-progress session must still block — otherwise we
      // could clobber a live HS_CHALLENGE waiting for response.
      final mgr = _newManager();
      final first = mgr.initiateHandshake(0xBEEF);
      expect(first, isNotNull);
      // Session is now `helloSent` and tracked in `_sessions`.
      final retry = mgr.initiateHandshake(0xBEEF, overrideCooldown: true);
      expect(
        retry,
        isNull,
        reason:
            'overrideCooldown must not bypass the duplicate-session '
            'guard — the override is for the cooldown specifically',
      );

      // dm-unavailable is also independent of the override.
      final mgr2 = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0x1234,
      );
      mgr2.isDmAvailable = false;
      expect(
        mgr2.initiateHandshake(0xBEEF, overrideCooldown: true),
        isNull,
        reason: 'dm-unavailable gate is independent of the cooldown gate',
      );
    });

    test('overrideCooldown is a no-op when not in cooldown', () {
      final mgr = _newManager();
      // Fresh peer, no prior failure — the override flag should
      // simply have no effect.
      final hello = mgr.initiateHandshake(0xCAFE, overrideCooldown: true);
      expect(hello, isNotNull);
      expect(mgr.getState(0xCAFE), SipHandshakeState.helloSent);
    });
  });
}
