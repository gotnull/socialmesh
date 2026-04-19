// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_explorer/models/interaction_tier.dart';
import 'package:socialmesh/features/mesh_explorer/models/mesh_explorer_peer.dart';

void main() {
  group('AnonymousPeer', () {
    test('has anonymous tier', () {
      final peer = AnonymousPeer(
        nodeId: 0xAABBCCDD,
        ambientId: 0x12345678,
        lastSeenMs: 1000,
        features: 0x03,
      );

      expect(peer.tier, InteractionTier.anonymous);
      expect(peer.serviceCount, 0);
      expect(peer.nodeId, 0xAABBCCDD);
      expect(peer.hopCount, isNull);
    });

    test('service count matches mrrpServiceIds length', () {
      final peer = AnonymousPeer(
        nodeId: 1,
        ambientId: 2,
        lastSeenMs: 1000,
        features: 0,
        mrrpServiceIds: [0x01, 0x03],
      );

      expect(peer.serviceCount, 2);
    });

    test('hopCount can be set explicitly', () {
      final peer = AnonymousPeer(
        nodeId: 1,
        ambientId: 2,
        hopCount: 3,
        lastSeenMs: 1000,
        features: 0,
      );

      expect(peer.hopCount, 3);
    });
  });

  group('IdentifiedPeer', () {
    test('can be identified tier', () {
      final peer = IdentifiedPeer(
        nodeId: 0x11223344,
        displayName: 'Alice',
        sigilSeed: 42,
        tier: InteractionTier.identified,
        lastSeenMs: 2000,
      );

      expect(peer.tier, InteractionTier.identified);
      expect(peer.displayName, 'Alice');
      expect(peer.serviceCount, 0);
      expect(peer.hopCount, isNull);
    });

    test('can be pinned tier', () {
      final peer = IdentifiedPeer(
        nodeId: 0x11223344,
        sigilSeed: 42,
        tier: InteractionTier.pinned,
        lastSeenMs: 3000,
        mrrpServiceIds: [0x02],
      );

      expect(peer.tier, InteractionTier.pinned);
      expect(peer.serviceCount, 1);
    });

    test('displayName can be null', () {
      final peer = IdentifiedPeer(
        nodeId: 1,
        sigilSeed: 2,
        tier: InteractionTier.handshaked,
        lastSeenMs: 1000,
      );

      expect(peer.displayName, isNull);
    });
  });

  group('MeshExplorerPeer sealed hierarchy', () {
    test('can switch on peer type', () {
      final MeshExplorerPeer anonymous = AnonymousPeer(
        nodeId: 1,
        ambientId: 2,
        lastSeenMs: 1000,
        features: 0,
      );

      final MeshExplorerPeer identified = IdentifiedPeer(
        nodeId: 3,
        sigilSeed: 4,
        tier: InteractionTier.identified,
        lastSeenMs: 2000,
      );

      final anonResult = switch (anonymous) {
        AnonymousPeer() => 'anonymous',
        IdentifiedPeer() => 'identified',
      };

      final idResult = switch (identified) {
        AnonymousPeer() => 'anonymous',
        IdentifiedPeer() => 'identified',
      };

      expect(anonResult, 'anonymous');
      expect(idResult, 'identified');
    });
  });
}
