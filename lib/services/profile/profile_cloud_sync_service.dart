import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/user_profile.dart';
import 'profile_service.dart';

/// Service for syncing user profile data with Firebase.
///
/// Handles:
/// - Firestore document sync for profile data
/// - Firebase Storage for avatar images
/// - Conflict resolution (local-first with server merge)
class ProfileCloudSyncService {
  static const String _usersCollection = 'users';
  static const String _avatarsFolder = 'profile_avatars';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ProfileService _localService;

  ProfileCloudSyncService(this._localService);

  /// Reference to the user's profile document
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection(_usersCollection).doc(uid);
  }

  /// Reference to avatar storage path
  Reference _avatarRef(String uid) {
    return _storage.ref().child(_avatarsFolder).child('$uid.jpg');
  }

  // --- Firestore Profile Sync ---

  /// Sync local profile to Firestore
  Future<void> syncToCloud(String uid) async {
    debugPrint('[ProfileSync] Syncing to cloud for uid: $uid');

    final localProfile = await _localService.getProfile();
    if (localProfile == null) {
      debugPrint('[ProfileSync] No local profile to sync');
      return;
    }

    try {
      // Update the profile ID to match Firebase user
      final profileForCloud = localProfile.copyWith(id: uid, isSynced: true);

      // Convert to Firestore-compatible map
      final data = _profileToFirestore(profileForCloud);

      // Use merge to avoid overwriting fields we don't manage
      await _userDoc(uid).set(data, SetOptions(merge: true));

      // Update local profile with synced status
      await _localService.saveProfile(profileForCloud);

      debugPrint('[ProfileSync] Successfully synced to cloud');
    } catch (e) {
      debugPrint('[ProfileSync] Error syncing to cloud: $e');
      rethrow;
    }
  }

  /// Fetch profile from Firestore and merge with local
  Future<UserProfile?> syncFromCloud(String uid) async {
    debugPrint('[ProfileSync] Syncing from cloud for uid: $uid');

    try {
      final doc = await _userDoc(uid).get();

      if (!doc.exists || doc.data() == null) {
        debugPrint('[ProfileSync] No cloud profile found');
        return null;
      }

      final cloudProfile = _profileFromFirestore(uid, doc.data()!);
      final localProfile = await _localService.getProfile();

      // Merge profiles - use cloud as source of truth for synced data
      final merged = _mergeProfiles(localProfile, cloudProfile);

      // Save merged profile locally
      await _localService.saveProfile(merged);

      debugPrint('[ProfileSync] Successfully synced from cloud');
      return merged;
    } catch (e) {
      debugPrint('[ProfileSync] Error syncing from cloud: $e');
      rethrow;
    }
  }

  /// Two-way sync: push local changes and pull remote changes
  Future<UserProfile?> fullSync(String uid) async {
    debugPrint('[ProfileSync] Starting full sync for uid: $uid');

    try {
      // First, fetch any remote changes
      final cloudDoc = await _userDoc(uid).get();
      final localProfile = await _localService.getOrCreateProfile();

      UserProfile finalProfile;

      if (!cloudDoc.exists || cloudDoc.data() == null) {
        // No cloud profile - push local to cloud
        debugPrint('[ProfileSync] No cloud profile, pushing local');
        final profileForCloud = localProfile.copyWith(id: uid, isSynced: true);
        await _userDoc(uid).set(_profileToFirestore(profileForCloud));
        finalProfile = profileForCloud;
      } else {
        // Cloud profile exists - merge with local
        final cloudProfile = _profileFromFirestore(uid, cloudDoc.data()!);
        finalProfile = _mergeProfiles(localProfile, cloudProfile);

        // Push merged version back to cloud
        await _userDoc(
          uid,
        ).set(_profileToFirestore(finalProfile), SetOptions(merge: true));
      }

      // Save final profile locally
      await _localService.saveProfile(finalProfile);

      debugPrint('[ProfileSync] Full sync complete');
      return finalProfile;
    } catch (e) {
      debugPrint('[ProfileSync] Error during full sync: $e');
      rethrow;
    }
  }

  /// Delete cloud profile data
  Future<void> deleteCloudProfile(String uid) async {
    debugPrint('[ProfileSync] Deleting cloud profile for uid: $uid');

    try {
      // Delete Firestore document
      await _userDoc(uid).delete();

      // Delete avatar from storage
      try {
        await _avatarRef(uid).delete();
      } catch (e) {
        // Avatar might not exist, ignore
        debugPrint('[ProfileSync] Avatar delete failed (may not exist): $e');
      }

      debugPrint('[ProfileSync] Cloud profile deleted');
    } catch (e) {
      debugPrint('[ProfileSync] Error deleting cloud profile: $e');
      rethrow;
    }
  }

  // --- Firebase Storage Avatar Sync ---

  /// Upload avatar to Firebase Storage
  Future<String> uploadAvatar(String uid, File imageFile) async {
    debugPrint('[ProfileSync] Uploading avatar for uid: $uid');

    try {
      final ref = _avatarRef(uid);

      // Upload with metadata
      await ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uid': uid},
        ),
      );

      // Get download URL
      final downloadUrl = await ref.getDownloadURL();

      debugPrint('[ProfileSync] Avatar uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('[ProfileSync] Error uploading avatar: $e');
      rethrow;
    }
  }

  /// Download avatar from Firebase Storage to local cache
  Future<File?> downloadAvatar(String uid) async {
    debugPrint('[ProfileSync] Downloading avatar for uid: $uid');

    try {
      final ref = _avatarRef(uid);

      // Get app directory for caching
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/profile_avatars/avatar_$uid.jpg');

      // Ensure directory exists
      await localFile.parent.create(recursive: true);

      // Download to local file
      await ref.writeToFile(localFile);

      debugPrint('[ProfileSync] Avatar downloaded to: ${localFile.path}');
      return localFile;
    } catch (e) {
      debugPrint('[ProfileSync] Error downloading avatar: $e');
      return null;
    }
  }

  /// Delete avatar from Firebase Storage
  Future<void> deleteCloudAvatar(String uid) async {
    debugPrint('[ProfileSync] Deleting cloud avatar for uid: $uid');

    try {
      await _avatarRef(uid).delete();
      debugPrint('[ProfileSync] Cloud avatar deleted');
    } catch (e) {
      debugPrint('[ProfileSync] Error deleting cloud avatar: $e');
      // Don't rethrow - avatar might not exist
    }
  }

  /// Sync local avatar to cloud and update profile with URL
  Future<void> syncAvatarToCloud(String uid) async {
    final profile = await _localService.getProfile();
    if (profile == null || profile.avatarUrl == null) return;

    // Check if it's a local file path (not already a URL)
    if (!profile.avatarUrl!.startsWith('http')) {
      final localFile = File(profile.avatarUrl!);
      if (await localFile.exists()) {
        final cloudUrl = await uploadAvatar(uid, localFile);

        // Update profile with cloud URL
        await _localService.saveProfile(
          profile.copyWith(avatarUrl: cloudUrl, isSynced: true),
        );
      }
    }
  }

  // --- Helper Methods ---

  /// Convert UserProfile to Firestore-compatible map
  Map<String, dynamic> _profileToFirestore(UserProfile profile) {
    return {
      'displayName': profile.displayName,
      'bio': profile.bio,
      'callsign': profile.callsign,
      'email': profile.email,
      'website': profile.website,
      'avatarUrl': profile.avatarUrl,
      'socialLinks': profile.socialLinks?.toJson(),
      'primaryNodeId': profile.primaryNodeId,
      'accentColorIndex': profile.accentColorIndex,
      'installedWidgetIds': profile.installedWidgetIds,
      'isVerified': profile.isVerified,
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Create UserProfile from Firestore document
  UserProfile _profileFromFirestore(String uid, Map<String, dynamic> data) {
    debugPrint(
      '[ProfileSync] Parsing Firestore data: displayName=${data['displayName']}, avatarUrl=${data['avatarUrl']}',
    );
    return UserProfile(
      id: uid,
      displayName: data['displayName'] as String? ?? 'Mesh User',
      bio: data['bio'] as String?,
      callsign: data['callsign'] as String?,
      email: data['email'] as String?,
      website: data['website'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      socialLinks: data['socialLinks'] != null
          ? ProfileSocialLinks.fromJson(
              data['socialLinks'] as Map<String, dynamic>,
            )
          : null,
      primaryNodeId: data['primaryNodeId'] as int?,
      accentColorIndex: data['accentColorIndex'] as int?,
      installedWidgetIds:
          (data['installedWidgetIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      isVerified: data['isVerified'] as bool? ?? false,
      isSynced: true,
      createdAt: data['createdAt'] != null
          ? DateTime.parse(data['createdAt'] as String)
          : DateTime.now(),
      updatedAt: data['updatedAt'] is Timestamp
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Merge local and cloud profiles with conflict resolution
  /// Strategy: Use cloud values for synced fields, preserve local customizations
  UserProfile _mergeProfiles(UserProfile? local, UserProfile cloud) {
    debugPrint(
      '[ProfileSync] Merging profiles - local.isSynced: ${local?.isSynced}, cloud.avatarUrl: ${cloud.avatarUrl}',
    );
    if (local == null) return cloud;

    // Merge installed widget IDs (union of both)
    final mergedWidgetIds = <String>{
      ...local.installedWidgetIds,
      ...cloud.installedWidgetIds,
    }.toList();

    // If local has never been synced, prefer cloud
    if (!local.isSynced) {
      debugPrint('[ProfileSync] Local not synced, using cloud profile');
      return cloud.copyWith(
        // Preserve any local customizations that don't exist in cloud
        bio: cloud.bio ?? local.bio,
        callsign: cloud.callsign ?? local.callsign,
        website: cloud.website ?? local.website,
        socialLinks: cloud.socialLinks ?? local.socialLinks,
        primaryNodeId: cloud.primaryNodeId ?? local.primaryNodeId,
        accentColorIndex: cloud.accentColorIndex ?? local.accentColorIndex,
        installedWidgetIds: mergedWidgetIds,
      );
    }

    // Both synced - use most recently updated
    debugPrint(
      '[ProfileSync] Both synced - local.updatedAt: ${local.updatedAt}, cloud.updatedAt: ${cloud.updatedAt}',
    );
    if (local.updatedAt.isAfter(cloud.updatedAt)) {
      debugPrint('[ProfileSync] Local is newer, using local');
      return local.copyWith(
        isSynced: true,
        installedWidgetIds: mergedWidgetIds,
      );
    }
    debugPrint('[ProfileSync] Cloud is newer, using cloud');
    return cloud.copyWith(installedWidgetIds: mergedWidgetIds);
  }
}

/// Singleton instance
late ProfileCloudSyncService profileCloudSyncService;

/// Initialize the cloud sync service (call after profileService.initialize())
void initProfileCloudSyncService() {
  profileCloudSyncService = ProfileCloudSyncService(profileService);
}
