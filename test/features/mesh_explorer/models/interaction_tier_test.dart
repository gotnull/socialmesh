// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_explorer/models/interaction_tier.dart';

void main() {
  group('InteractionTier', () {
    test('anonymous tier can view board but not profile or DM', () {
      const tier = InteractionTier.anonymous;
      expect(tier.canViewProfile, isFalse);
      expect(tier.canViewBoard, isTrue);
      expect(tier.canDm, isFalse);
      expect(tier.canPin, isFalse);
      expect(tier.hasPersistentRecord, isFalse);
    });

    test('handshaked tier can view board and has persistent record', () {
      const tier = InteractionTier.handshaked;
      expect(tier.canViewProfile, isFalse);
      expect(tier.canViewBoard, isTrue);
      expect(tier.canDm, isFalse);
      expect(tier.canPin, isFalse);
      expect(tier.hasPersistentRecord, isTrue);
    });

    test('identified tier can view profile and board', () {
      const tier = InteractionTier.identified;
      expect(tier.canViewProfile, isTrue);
      expect(tier.canViewBoard, isTrue);
      expect(tier.canDm, isTrue);
      expect(tier.canPin, isTrue);
      expect(tier.hasPersistentRecord, isTrue);
    });

    test('pinned tier has most capabilities but canPin is false', () {
      const tier = InteractionTier.pinned;
      expect(tier.canViewProfile, isTrue);
      expect(tier.canViewBoard, isTrue);
      expect(tier.canDm, isTrue);
      expect(tier.canPin, isFalse); // already pinned
      expect(tier.hasPersistentRecord, isTrue);
    });

    test('tiers are ordered by trust level', () {
      expect(InteractionTier.anonymous.index, 0);
      expect(InteractionTier.handshaked.index, 1);
      expect(InteractionTier.identified.index, 2);
      expect(InteractionTier.pinned.index, 3);
    });
  });
}
