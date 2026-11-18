// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/social.dart';

void main() {
  group('LinkedNodeInfo', () {
    test('fromJson reads every field', () {
      final info = LinkedNodeInfo.fromJson({
        'nodeId': 0x1234abcd,
        'longName': 'Base Station',
        'shortName': 'BASE',
        'avatarColor': 0xFF00AA00,
      });

      expect(info.nodeId, 0x1234abcd);
      expect(info.longName, 'Base Station');
      expect(info.shortName, 'BASE');
      expect(info.avatarColor, 0xFF00AA00);
    });

    test('toJson omits null fields and round trips', () {
      const info = LinkedNodeInfo(nodeId: 42, shortName: 'AB');

      final json = info.toJson();

      expect(json, {'nodeId': 42, 'shortName': 'AB'});
      final restored = LinkedNodeInfo.fromJson(json);
      expect(restored.nodeId, 42);
      expect(restored.shortName, 'AB');
      expect(restored.longName, isNull);
      expect(restored.avatarColor, isNull);
    });

    test('displayName prefers long name, then short name, then hex id', () {
      expect(
        const LinkedNodeInfo(
          nodeId: 255,
          longName: 'Long',
          shortName: 'S',
        ).displayName,
        'Long',
      );
      expect(
        const LinkedNodeInfo(nodeId: 255, shortName: 'S').displayName,
        'S',
      );
      expect(const LinkedNodeInfo(nodeId: 255).displayName, '!ff');
    });

    test('avatarName prefers short name, then long name initial, then hex', () {
      expect(
        const LinkedNodeInfo(
          nodeId: 255,
          longName: 'long',
          shortName: 'SN',
        ).avatarName,
        'SN',
      );
      expect(
        const LinkedNodeInfo(nodeId: 255, longName: 'long').avatarName,
        'L',
      );
      expect(const LinkedNodeInfo(nodeId: 0xab).avatarName, 'A');
    });

    test('equality is based on node id only', () {
      const a = LinkedNodeInfo(nodeId: 7, longName: 'One');
      const b = LinkedNodeInfo(nodeId: 7, longName: 'Two');
      const c = LinkedNodeInfo(nodeId: 8, longName: 'One');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('PublicProfile', () {
    test('creates with required fields', () {
      final profile = PublicProfile(id: 'user-1', displayName: 'Test User');

      expect(profile.id, 'user-1');
      expect(profile.displayName, 'Test User');
      expect(profile.avatarUrl, isNull);
      expect(profile.bio, isNull);
      expect(profile.callsign, isNull);
      expect(profile.primaryNodeId, isNull);
      expect(profile.linkedNodeIds, isEmpty);
      expect(profile.linkedNodeMetadata, isEmpty);
      expect(profile.followerCount, 0);
      expect(profile.followingCount, 0);
      expect(profile.postCount, 0);
      expect(profile.isVerified, false);
    });

    test('creates with all fields', () {
      final profile = PublicProfile(
        id: 'user-1',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.jpg',
        bio: 'Test bio',
        callsign: 'KD6-3.7',
        primaryNodeId: 42,
        linkedNodeIds: const [42, 43],
        followerCount: 100,
        followingCount: 50,
        postCount: 25,
        isVerified: true,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(profile.avatarUrl, 'https://example.com/avatar.jpg');
      expect(profile.bio, 'Test bio');
      expect(profile.callsign, 'KD6-3.7');
      expect(profile.primaryNodeId, 42);
      expect(profile.linkedNodeIds, [42, 43]);
      expect(profile.followerCount, 100);
      expect(profile.followingCount, 50);
      expect(profile.postCount, 25);
      expect(profile.isVerified, true);
    });

    test('hasNodeLinked and getLinkedNodeInfo read the linked node data', () {
      const info = LinkedNodeInfo(nodeId: 42, longName: 'Base Station');
      final profile = PublicProfile(
        id: 'user-1',
        displayName: 'Test User',
        linkedNodeIds: const [42],
        linkedNodeMetadata: const {42: info},
      );

      expect(profile.hasNodeLinked(42), isTrue);
      expect(profile.hasNodeLinked(43), isFalse);
      expect(profile.getLinkedNodeInfo(42)?.longName, 'Base Station');
      expect(profile.getLinkedNodeInfo(43), isNull);
    });

    test('equality based on id', () {
      final profile1 = PublicProfile(id: 'user-1', displayName: 'Name 1');

      final profile2 = PublicProfile(id: 'user-1', displayName: 'Name 2');

      final profile3 = PublicProfile(id: 'user-2', displayName: 'Name 1');

      expect(profile1, equals(profile2));
      expect(profile1, isNot(equals(profile3)));
    });
  });
}
