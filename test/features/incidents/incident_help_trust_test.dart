// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PR-11: Help Circle trust model. Trust = explicit per-peer opt-in (persisted);
// same-channel / seen / has-pubkey is NOT trusted. Completed SIP Handshake is
// an optional additional source.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/incidents/providers/incident_help_trust_provider.dart';
import 'package:socialmesh/services/protocol/sip/sip_handshake.dart';
import 'package:socialmesh/services/protocol/sip/sip_replay_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Help Circle store', () {
    test(
      'trust adds (with display metadata) and persists across reload',
      () async {
        final c1 = ProviderContainer();
        addTearDown(c1.dispose);
        await c1.read(incidentHelpTrustProvider.notifier).reload();
        await c1
            .read(incidentHelpTrustProvider.notifier)
            .trust(42, displayName: 'Bravo', nowMs: 1000);

        final stored = c1.read(incidentHelpTrustProvider);
        expect(stored.single.nodeId, 42);
        expect(stored.single.displayName, 'Bravo');
        expect(c1.read(incidentHelpTrustedIdsProvider), {42});

        // A fresh container reloads the persisted circle.
        final c2 = ProviderContainer();
        addTearDown(c2.dispose);
        await c2.read(incidentHelpTrustProvider.notifier).reload();
        expect(c2.read(incidentHelpTrustedIdsProvider), {42});
      },
    );

    test('untrust takes effect on the predicate without a reload', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(incidentHelpTrustProvider.notifier);
      await notifier.trust(7, displayName: 'X');
      expect(notifier.isTrusted(7), isTrue);

      await notifier.untrust(7);
      // The predicate and id-set view flip from in-memory state alone - no
      // reload() / disk round-trip required (drives immediate de-trust of new
      // inbound + outbound eligibility).
      expect(notifier.isTrusted(7), isFalse);
      expect(c.read(incidentHelpTrustedIdsProvider), isEmpty);
    });

    test('trust is idempotent and keeps the original addedAt', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final n = c.read(incidentHelpTrustProvider.notifier);
      await n.trust(5, displayName: 'A', nowMs: 100);
      await n.trust(5, displayName: 'A2', nowMs: 200); // refresh name only
      final list = c.read(incidentHelpTrustProvider);
      expect(list, hasLength(1));
      expect(list.single.addedAtMs, 100);
      expect(list.single.displayName, 'A2');
    });
  });

  group('incidentHelpTrustGate', () {
    test('node in the circle is trusted (no handshake needed)', () {
      expect(
        incidentHelpTrustGate(circle: {42}, handshake: null, nodeId: 42),
        isTrue,
      );
    });

    test('node not in the circle, no handshake -> not trusted', () {
      // Models same-channel / seen / has-pubkey: none of these are trust.
      expect(
        incidentHelpTrustGate(circle: const {}, handshake: null, nodeId: 42),
        isFalse,
      );
    });

    test('completed SIP Handshake is an accepted optional source', () async {
      final initiator = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0xAAAA,
      )..isDmAvailable = true;
      final responder = SipHandshakeManager(
        replayCache: SipReplayCache(),
        localNodeId: 0xBBBB,
      )..isDmAvailable = true;
      const nodeA = 0xAAAA, nodeB = 0xBBBB;

      final hello = initiator.initiateHandshake(nodeB)!;
      responder.handleHello(nodeA, hello);
      final challenge = responder.acceptHandshake(nodeA)!;
      final response = (await initiator.handleChallenge(nodeB, challenge))!;
      final accept = (await responder.handleResponse(nodeA, response))!;
      initiator.handleAccept(nodeB, accept);

      // Not in circle, but handshake-accepted -> trusted.
      expect(
        incidentHelpTrustGate(
          circle: const {},
          handshake: initiator,
          nodeId: nodeB,
        ),
        isTrue,
      );
      // An unrelated node with neither circle nor handshake -> not trusted.
      expect(
        incidentHelpTrustGate(
          circle: const {},
          handshake: initiator,
          nodeId: 0x9999,
        ),
        isFalse,
      );
    });
  });

  group('trust is directional (one-sided vs mutual)', () {
    // Trust is evaluated against the LOCAL device's Help Circle. Inbound on a
    // device uses that device's own circle; outbound eligibility uses the
    // sender's circle. A adding B does not make A trusted on B.
    const a = 0xAAAA, b = 0xBBBB;

    test('one-sided: A added B, B did not add A', () {
      final aCircle = {b}; // A trusts B
      const bCircle = <int>{}; // B trusts nobody

      // A's outbound: B is eligible from A's perspective.
      expect(
        incidentHelpTrustGate(circle: aCircle, handshake: null, nodeId: b),
        isTrue,
      );
      // B's inbound: A is NOT trusted, so B drops A's help request.
      expect(
        incidentHelpTrustGate(circle: bCircle, handshake: null, nodeId: a),
        isFalse,
      );
    });

    test('mutual: A and B added each other -> trusted both directions', () {
      final aCircle = {b};
      final bCircle = {a};

      expect(
        incidentHelpTrustGate(circle: aCircle, handshake: null, nodeId: b),
        isTrue,
      );
      expect(
        incidentHelpTrustGate(circle: bCircle, handshake: null, nodeId: a),
        isTrue,
      );
    });

    test('removal flips inbound trust off (B removes A)', () {
      // After B removes A, B's circle no longer contains A.
      const bCircleAfterRemoval = <int>{};
      expect(
        incidentHelpTrustGate(
          circle: bCircleAfterRemoval,
          handshake: null,
          nodeId: a,
        ),
        isFalse,
      );
    });
  });
}
