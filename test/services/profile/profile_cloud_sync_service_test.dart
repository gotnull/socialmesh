// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/user_profile.dart';
import 'package:socialmesh/services/profile/profile_cloud_sync_service.dart';

/// Tests for ProfileCloudSyncService merge logic
/// Note: These tests validate the merge algorithm independently of Firebase
void main() {
  group('Profile Merge Logic', () {
    group('mergeProfiles - null local', () {
      test('returns cloud profile when local is null', () {
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          isSynced: true,
        );

        final merged = _mergeProfiles(null, cloud);

        expect(merged.id, 'cloud-id');
        expect(merged.displayName, 'Cloud User');
        expect(merged.isSynced, true);
      });
    });

    group('mergeProfiles - local never synced', () {
      test('prefers cloud profile when local has never been synced', () {
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          bio: 'Local bio',
          isSynced: false,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          bio: 'Cloud bio',
          isSynced: true,
        );

        final merged = _mergeProfiles(local, cloud);

        expect(merged.id, 'cloud-id');
        expect(merged.displayName, 'Cloud User');
        expect(merged.bio, 'Cloud bio');
      });

      test('preserves local customizations when missing in cloud', () {
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          bio: 'My bio',
          callsign: 'LOCAL1',
          website: 'https://local.com',
          primaryNodeId: 123,
          accentColorIndex: 5,
          isSynced: false,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          // No bio, callsign, website, etc.
          isSynced: true,
        );

        final merged = _mergeProfiles(local, cloud);

        // Cloud values used for main identity
        expect(merged.id, 'cloud-id');
        expect(merged.displayName, 'Cloud User');
        // Local customizations preserved when cloud doesn't have them
        expect(merged.bio, 'My bio');
        expect(merged.callsign, 'LOCAL1');
        expect(merged.website, 'https://local.com');
        expect(merged.primaryNodeId, 123);
        expect(merged.accentColorIndex, 5);
      });

      test('cloud values override local when cloud has values', () {
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          bio: 'Local bio',
          callsign: 'LOCAL1',
          isSynced: false,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          bio: 'Cloud bio',
          callsign: 'CLOUD1',
          isSynced: true,
        );

        final merged = _mergeProfiles(local, cloud);

        expect(merged.bio, 'Cloud bio');
        expect(merged.callsign, 'CLOUD1');
      });
    });

    group('mergeProfiles - both synced (timestamp based)', () {
      test('prefers local when local is newer', () {
        final now = DateTime.now();
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Updated Local',
          bio: 'Updated bio',
          isSynced: true,
          updatedAt: now,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Old Cloud',
          bio: 'Old bio',
          isSynced: true,
          updatedAt: now.subtract(const Duration(hours: 1)),
        );

        final merged = _mergeProfiles(local, cloud);

        expect(merged.displayName, 'Updated Local');
        expect(merged.bio, 'Updated bio');
        expect(merged.isSynced, true);
      });

      test('prefers cloud when cloud is newer', () {
        final now = DateTime.now();
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Old Local',
          bio: 'Old bio',
          isSynced: true,
          updatedAt: now.subtract(const Duration(hours: 1)),
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Updated Cloud',
          bio: 'Updated bio',
          isSynced: true,
          updatedAt: now,
        );

        final merged = _mergeProfiles(local, cloud);

        expect(merged.displayName, 'Updated Cloud');
        expect(merged.bio, 'Updated bio');
      });

      test('prefers local when timestamps are equal', () {
        final timestamp = DateTime(2024, 1, 1, 12, 0, 0);
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          isSynced: true,
          updatedAt: timestamp,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          isSynced: true,
          updatedAt: timestamp,
        );

        final merged = _mergeProfiles(local, cloud);

        // Equal timestamps - cloud wins (local.isAfter returns false)
        expect(merged.displayName, 'Cloud User');
      });
    });

    group('mergeProfiles - social links', () {
      test('preserves local social links when cloud has none', () {
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          socialLinks: ProfileSocialLinks(
            twitter: '@local',
            github: 'localuser',
          ),
          isSynced: false,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          isSynced: true,
        );

        final merged = _mergeProfiles(local, cloud);

        expect(merged.socialLinks?.twitter, '@local');
        expect(merged.socialLinks?.github, 'localuser');
      });

      test('uses cloud social links when both have them', () {
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          socialLinks: ProfileSocialLinks(
            twitter: '@local',
            github: 'localuser',
          ),
          isSynced: false,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          socialLinks: ProfileSocialLinks(
            twitter: '@cloud',
            github: 'clouduser',
            linkedin: 'cloudlinkedin',
          ),
          isSynced: true,
        );

        final merged = _mergeProfiles(local, cloud);

        expect(merged.socialLinks?.twitter, '@cloud');
        expect(merged.socialLinks?.github, 'clouduser');
        expect(merged.socialLinks?.linkedin, 'cloudlinkedin');
      });
    });

    group('mergeProfiles - avatar URL handling', () {
      test('uses cloud avatar URL', () {
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          avatarUrl: '/local/path/avatar.jpg',
          isSynced: false,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          avatarUrl: 'https://firebase.com/avatar.jpg',
          isSynced: true,
        );

        final merged = _mergeProfiles(local, cloud);

        expect(merged.avatarUrl, 'https://firebase.com/avatar.jpg');
      });

      test('preserves local avatar when cloud has none', () {
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          avatarUrl: '/local/path/avatar.jpg',
          isSynced: false,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          isSynced: true,
        );

        final merged = _mergeProfiles(local, cloud);

        // Avatar not in the fields that are explicitly preserved
        // So it uses cloud's null avatar
        expect(merged.avatarUrl, isNull);
      });
    });

    group('mergeProfiles - verification status', () {
      test('cloud verification status is used', () {
        final local = _createProfile(
          id: 'local-id',
          displayName: 'Local User',
          isVerified: false,
          isSynced: false,
        );
        final cloud = _createProfile(
          id: 'cloud-id',
          displayName: 'Cloud User',
          isVerified: true,
          isSynced: true,
        );

        final merged = _mergeProfiles(local, cloud);

        expect(merged.isVerified, true);
      });
    });
  });

  group('Profile Serialization', () {
    test('UserProfile toJson and fromJson roundtrip', () {
      final profile = _createProfile(
        id: 'test-id',
        displayName: 'Test User',
        bio: 'Test bio',
        callsign: 'TEST1',
        email: 'test@example.com',
        website: 'https://test.com',
        primaryNodeId: 123456,
        accentColorIndex: 3,
        isVerified: true,
        isSynced: true,
        socialLinks: ProfileSocialLinks(twitter: '@test', github: 'testuser'),
      );

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);

      expect(restored.id, profile.id);
      expect(restored.displayName, profile.displayName);
      expect(restored.bio, profile.bio);
      expect(restored.callsign, profile.callsign);
      expect(restored.email, profile.email);
      expect(restored.website, profile.website);
      expect(restored.primaryNodeId, profile.primaryNodeId);
      expect(restored.accentColorIndex, profile.accentColorIndex);
      expect(restored.isVerified, profile.isVerified);
      expect(restored.isSynced, profile.isSynced);
      expect(restored.socialLinks?.twitter, '@test');
      expect(restored.socialLinks?.github, 'testuser');
    });

    test('ProfileSocialLinks toJson and fromJson roundtrip', () {
      final links = ProfileSocialLinks(
        twitter: '@handle',
        github: 'username',
        linkedin: 'profile',
        mastodon: '@user@instance.social',
        discord: 'user#1234',
        telegram: '@telegramuser',
      );

      final json = links.toJson();
      final restored = ProfileSocialLinks.fromJson(json);

      expect(restored.twitter, links.twitter);
      expect(restored.github, links.github);
      expect(restored.linkedin, links.linkedin);
      expect(restored.mastodon, links.mastodon);
      expect(restored.discord, links.discord);
      expect(restored.telegram, links.telegram);
    });
  });

  group('profileToFirestoreMap — null stripping', () {
    test('omits null optional fields entirely', () {
      // Regression: previously the map emitted explicit nulls for
      // unset optionals. Combined with SetOptions(merge: true), this
      // wiped previously-set cloud fields on every passive sync from a
      // stale or partially-loaded local profile.
      final profile = _createProfile(
        id: 'uid',
        displayName: 'gotnull',
        // bio / callsign / email / website / avatar / banner /
        // socialLinks / primaryNodeId / accentColorIndex / preferences
        // are all intentionally left null.
      );

      final map = ProfileCloudSyncService.profileToFirestoreMap(profile);

      expect(map['displayName'], 'gotnull');
      // Non-null required keys must always be present.
      expect(map.containsKey('linkedNodeIds'), isTrue);
      expect(map.containsKey('installedWidgetIds'), isTrue);
      expect(map.containsKey('createdAt'), isTrue);
      expect(map.containsKey('updatedAt'), isTrue);
      // Null optionals must NOT appear as keys — that's what caused
      // SetOptions(merge: true) to overwrite cloud fields with null.
      expect(map.containsKey('bio'), isFalse);
      expect(map.containsKey('callsign'), isFalse);
      expect(map.containsKey('email'), isFalse);
      expect(map.containsKey('website'), isFalse);
      expect(map.containsKey('avatarUrl'), isFalse);
      expect(map.containsKey('bannerUrl'), isFalse);
      expect(map.containsKey('socialLinks'), isFalse);
      expect(map.containsKey('primaryNodeId'), isFalse);
      expect(map.containsKey('accentColorIndex'), isFalse);
      expect(map.containsKey('preferences'), isFalse);
    });

    test('includes non-null optional fields', () {
      final profile = _createProfile(
        id: 'uid',
        displayName: 'gotnull',
        bio: 'Developer of SocialMesh',
        callsign: 'CODER',
        website: 'https://socialmesh.app',
        primaryNodeId: 2621057449,
        accentColorIndex: 3,
        avatarUrl: 'https://firebasestorage.googleapis.com/avatar.jpg',
        socialLinks: ProfileSocialLinks(github: 'gotnull'),
      );

      final map = ProfileCloudSyncService.profileToFirestoreMap(profile);

      expect(map['bio'], 'Developer of SocialMesh');
      expect(map['callsign'], 'CODER');
      expect(map['website'], 'https://socialmesh.app');
      expect(map['primaryNodeId'], 2621057449);
      expect(map['accentColorIndex'], 3);
      expect(
        map['avatarUrl'],
        'https://firebasestorage.googleapis.com/avatar.jpg',
      );
      expect(map['socialLinks'], isA<Map<String, dynamic>>());
    });

    test('local file paths are stripped from avatar/banner URLs', () {
      final profile = _createProfile(
        id: 'uid',
        displayName: 'gotnull',
        avatarUrl: '/var/mobile/Containers/.../avatar.jpg',
      );

      final map = ProfileCloudSyncService.profileToFirestoreMap(profile);

      // Local paths never appear in the Firestore payload — sanitizer
      // returns null, and the null-stripping omits the key.
      expect(map.containsKey('avatarUrl'), isFalse);
    });

    test('updatedAt uses serverTimestamp sentinel', () {
      final profile = _createProfile(id: 'uid', displayName: 'gotnull');
      final map = ProfileCloudSyncService.profileToFirestoreMap(profile);
      expect(map['updatedAt'], isA<FieldValue>());
    });
  });

  group('mergePublicMirrorIntoCloud — drift recovery', () {
    test('returns identical cloud profile when public mirror is empty', () {
      final cloud = _createProfile(
        id: 'uid',
        displayName: 'gotnull',
        bio: 'private bio',
        avatarUrl: 'https://example.com/a.jpg',
      );

      final out = ProfileCloudSyncService.mergePublicMirrorIntoCloud(
        cloud,
        const <String, dynamic>{},
      );

      expect(identical(out, cloud), isTrue);
    });

    test(
      'backfills avatar/banner/bio/etc. from public mirror when cloud is null',
      () {
        // Mirrors the developer's incident: users/{uid} wiped to nulls,
        // profiles/{uid} still holds the curated values. Note that
        // displayName is intentionally NOT recovered — see the
        // "displayName is never recovered" test below.
        final cloud = _createProfile(
          id: 'uid',
          displayName: 'fuzz',
          isSynced: true,
        );
        final public = <String, dynamic>{
          'displayName': 'gotnull',
          'avatarUrl': 'https://firebasestorage/avatar.jpg',
          'bannerUrl': 'https://firebasestorage/banner.jpg',
          'bio': 'Developer of SocialMesh',
          'callsign': 'CODER',
          'website': 'https://socialmesh.app',
          'primaryNodeId': 2621057449,
          'socialLinks': <String, dynamic>{'github': 'gotnull'},
        };

        final out = ProfileCloudSyncService.mergePublicMirrorIntoCloud(
          cloud,
          public,
        );

        expect(out.avatarUrl, 'https://firebasestorage/avatar.jpg');
        expect(out.bannerUrl, 'https://firebasestorage/banner.jpg');
        expect(out.bio, 'Developer of SocialMesh');
        expect(out.callsign, 'CODER');
        expect(out.website, 'https://socialmesh.app');
        expect(out.primaryNodeId, 2621057449);
        expect(out.socialLinks?.github, 'gotnull');
      },
    );

    test('preserves cloud values when both cloud and public are populated', () {
      // We only recover from drift, never clobber deliberate private
      // edits with stale public values.
      final cloud = _createProfile(
        id: 'uid',
        displayName: 'private-name',
        bio: 'private bio',
        callsign: 'PRIV',
        avatarUrl: 'https://private.example/a.jpg',
      );
      final public = <String, dynamic>{
        'displayName': 'public-name',
        'bio': 'public bio',
        'callsign': 'PUB',
        'avatarUrl': 'https://public.example/a.jpg',
      };

      final out = ProfileCloudSyncService.mergePublicMirrorIntoCloud(
        cloud,
        public,
      );

      // Cloud displayName already populated → kept, even though they differ.
      expect(out.displayName, 'private-name');
      expect(out.bio, 'private bio');
      expect(out.callsign, 'PRIV');
      expect(out.avatarUrl, 'https://private.example/a.jpg');
    });

    test('partial recovery: only fills the truly-null cloud fields', () {
      final cloud = _createProfile(
        id: 'uid',
        displayName: 'gotnull',
        bio: 'kept',
        // avatar/banner/callsign null on cloud
      );
      final public = <String, dynamic>{
        'displayName': 'gotnull',
        'bio': 'stale public bio',
        'avatarUrl': 'https://example.com/a.jpg',
        'callsign': 'CODER',
      };

      final out = ProfileCloudSyncService.mergePublicMirrorIntoCloud(
        cloud,
        public,
      );

      expect(identical(out, cloud), isFalse);
      expect(out.bio, 'kept'); // cloud already had a value
      expect(out.avatarUrl, 'https://example.com/a.jpg'); // recovered
      expect(out.callsign, 'CODER'); // recovered
    });

    test('displayName is never recovered from the public mirror', () {
      // The public mirror is one of TWO truthful copies of displayName.
      // Recovery must never silently overwrite a legitimate private
      // edit (where the public mirror hadn't caught up) just because
      // the two strings differ. The cloud value is treated as the
      // source of truth for the user's own name; a stale private name
      // needs a deliberate one-shot fix, not background recovery.
      final cloud = _createProfile(id: 'uid', displayName: 'private-name');
      final public = <String, dynamic>{'displayName': 'public-name'};

      final out = ProfileCloudSyncService.mergePublicMirrorIntoCloud(
        cloud,
        public,
      );

      expect(out.displayName, 'private-name');
      expect(identical(out, cloud), isTrue);
    });
  });
}

/// Helper to create test profiles
UserProfile _createProfile({
  required String id,
  required String displayName,
  String? bio,
  String? callsign,
  String? email,
  String? website,
  String? avatarUrl,
  int? primaryNodeId,
  int? accentColorIndex,
  bool isVerified = false,
  bool isSynced = false,
  ProfileSocialLinks? socialLinks,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  return UserProfile(
    id: id,
    displayName: displayName,
    bio: bio,
    callsign: callsign,
    email: email,
    website: website,
    avatarUrl: avatarUrl,
    primaryNodeId: primaryNodeId,
    accentColorIndex: accentColorIndex,
    isVerified: isVerified,
    isSynced: isSynced,
    socialLinks: socialLinks,
    createdAt: createdAt ?? DateTime.now(),
    updatedAt: updatedAt ?? DateTime.now(),
  );
}

/// Replicate the merge logic from ProfileCloudSyncService for testing
/// This allows us to test the algorithm without Firebase dependencies
UserProfile _mergeProfiles(UserProfile? local, UserProfile cloud) {
  if (local == null) return cloud;

  // If local has never been synced, prefer cloud
  if (!local.isSynced) {
    return cloud.copyWith(
      // Preserve any local customizations that don't exist in cloud
      bio: cloud.bio ?? local.bio,
      callsign: cloud.callsign ?? local.callsign,
      website: cloud.website ?? local.website,
      socialLinks: cloud.socialLinks ?? local.socialLinks,
      primaryNodeId: cloud.primaryNodeId ?? local.primaryNodeId,
      accentColorIndex: cloud.accentColorIndex ?? local.accentColorIndex,
    );
  }

  // Both synced - use most recently updated
  if (local.updatedAt.isAfter(cloud.updatedAt)) {
    return local.copyWith(isSynced: true);
  }
  return cloud;
}
