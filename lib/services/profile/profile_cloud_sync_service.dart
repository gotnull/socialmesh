// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/logging.dart';
import '../../models/user_profile.dart';
import 'profile_service.dart';

/// Service for syncing user profile data with Firebase.
///
/// Handles:
/// - Firestore document sync for profile data (`users` collection)
/// - Firestore public profile sync (`profiles` collection for social features)
/// - Firebase Storage for avatar images
/// - Conflict resolution (local-first with server merge)
class ProfileCloudSyncService {
  static const String _usersCollection = 'users';
  static const String _profilesCollection = 'profiles';
  static const String _avatarsFolder = 'profile_avatars';
  static const String _bannersFolder = 'profile_banners';

  /// Debounce window for fullSync to prevent redundant writes
  static const Duration _syncDebounceWindow = Duration(seconds: 2);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ProfileService _localService;

  /// Track in-flight sync operations to avoid duplicates
  Future<UserProfile?>? _activeSyncFuture;
  String? _activeSyncUid;
  DateTime? _lastSyncTime;

  ProfileCloudSyncService(this._localService);

  /// Reference to the user's profile document
  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection(_usersCollection).doc(uid);
  }

  /// Reference to the public profile document (for social features)
  DocumentReference<Map<String, dynamic>> _publicProfileDoc(String uid) {
    return _firestore.collection(_profilesCollection).doc(uid);
  }

  /// Reference to avatar storage path
  Reference _avatarRef(String uid) {
    return _storage.ref().child(_avatarsFolder).child('$uid.jpg');
  }

  /// Reference to banner storage path
  Reference _bannerRef(String uid) {
    return _storage.ref().child(_bannersFolder).child('$uid.jpg');
  }

  // --- Firestore Profile Sync ---

  /// Sync local profile to Firestore (both `users` and `profiles` collections)
  Future<void> syncToCloud(String uid) async {
    AppLogging.auth('ProfileSync: Syncing to cloud for uid: $uid');

    final localProfile = await _localService.getProfile();
    if (localProfile == null) {
      AppLogging.auth('ProfileSync: No local profile to sync');
      return;
    }

    try {
      // Update the profile ID to match Firebase user
      final profileForCloud = localProfile.copyWith(id: uid, isSynced: true);

      // Convert to Firestore-compatible map
      final data = _profileToFirestore(profileForCloud);

      // Use merge to avoid overwriting fields we don't manage
      await _userDoc(uid).set(data, SetOptions(merge: true));

      // Also sync public fields to `profiles` collection for social features
      await _syncPublicProfile(uid, profileForCloud);

      // Update local profile with synced status
      await _localService.saveProfile(profileForCloud);

      AppLogging.auth('ProfileSync: Successfully synced to cloud');
    } catch (e) {
      AppLogging.auth('ProfileSync: Error syncing to cloud: $e');
      rethrow;
    }
  }

  /// Check if a display name is already taken by another user.
  /// Returns true if the name is taken, false if available.
  Future<bool> isDisplayNameTaken(
    String displayName, [
    String? excludeUserId,
  ]) async {
    final normalizedName = displayName.trim().toLowerCase();
    if (normalizedName.isEmpty) return false;

    // Query for profiles with this display name (case-insensitive via lowercase field)
    final query = await _firestore
        .collection(_profilesCollection)
        .where('displayNameLower', isEqualTo: normalizedName)
        .limit(2)
        .get();

    // Check if any results belong to a different user
    for (final doc in query.docs) {
      if (excludeUserId == null || doc.id != excludeUserId) {
        return true;
      }
    }
    return false;
  }

  /// Look up a user's Firebase UID by their display name.
  /// Returns null if no user found with that display name.
  /// Display names are unique and case-insensitive.
  Future<String?> getUserIdByDisplayName(String displayName) async {
    AppLogging.qr(
      '🔗 ProfileSync: getUserIdByDisplayName called with "$displayName"',
    );

    final normalizedName = displayName.trim().toLowerCase();
    if (normalizedName.isEmpty) {
      AppLogging.qr(
        'QR - 🔗 ProfileSync: Empty displayName after normalization',
      );
      return null;
    }

    AppLogging.qr(
      '🔗 ProfileSync: Querying Firestore for displayNameLower="$normalizedName"',
    );

    try {
      final query = await _firestore
          .collection(_profilesCollection)
          .where('displayNameLower', isEqualTo: normalizedName)
          .limit(1)
          .get();

      AppLogging.qr(
        'QR - 🔗 ProfileSync: Query returned ${query.docs.length} docs',
      );

      if (query.docs.isEmpty) {
        AppLogging.qr(
          '🔗 ProfileSync: No user found with displayName: $displayName',
        );
        return null;
      }

      final userId = query.docs.first.id;
      final docData = query.docs.first.data();
      AppLogging.qr(
        '🔗 ProfileSync: Found userId=$userId for displayName=$displayName, '
        'doc keys=${docData.keys.toList()}',
      );
      return userId;
    } catch (e) {
      AppLogging.qr(
        '🔗 ProfileSync: ERROR looking up displayName "$displayName": $e',
      );
      return null;
    }
  }

  /// Sync only the public-facing profile fields to `profiles` collection
  /// This is the collection used by social features (followers, posts, etc.)
  Future<void> _syncPublicProfile(String uid, UserProfile profile) async {
    AppLogging.auth('ProfileSync: Syncing public profile for uid: $uid');

    // Check display name uniqueness before syncing
    if (profile.displayName.isNotEmpty) {
      final isTaken = await isDisplayNameTaken(profile.displayName, uid);
      if (isTaken) {
        throw DisplayNameTakenException(profile.displayName);
      }
    }

    final docRef = _publicProfileDoc(uid);
    final doc = await docRef.get();

    final publicData = <String, dynamic>{
      'displayName': profile.displayName,
      'displayNameLower': profile.displayName.toLowerCase(),
      'avatarUrl': profile.avatarUrl,
      'bannerUrl': profile.bannerUrl,
      'bio': profile.bio,
      'callsign': profile.callsign,
      'website': profile.website,
      'socialLinks': profile.socialLinks?.toJson(),
      'primaryNodeId': profile.primaryNodeId,
      'linkedNodeIds': profile.linkedNodeIds,
      // Note: isVerified is NOT included - managed by admin only
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      // Document doesn't exist - create with counter fields set to 0
      publicData['followerCount'] = 0;
      publicData['followingCount'] = 0;
      publicData['postCount'] = 0;
      publicData['createdAt'] = FieldValue.serverTimestamp();
      await docRef.set(publicData);
      AppLogging.auth('ProfileSync: Created new public profile');
    } else {
      // Document exists - update without touching counter fields
      await docRef.update(publicData);
      AppLogging.auth('ProfileSync: Updated existing public profile');
    }
  }

  /// Fetch profile from Firestore and merge with local
  Future<UserProfile?> syncFromCloud(String uid) async {
    AppLogging.auth('ProfileSync: Syncing from cloud for uid: $uid');

    try {
      final doc = await _userDoc(uid).get();

      if (!doc.exists || doc.data() == null) {
        AppLogging.auth('ProfileSync: No cloud profile found');
        return null;
      }

      final cloudProfile = _profileFromFirestore(uid, doc.data()!);
      final localProfile = await _localService.getProfile();

      // Merge profiles - use cloud as source of truth for synced data
      final merged = _mergeProfiles(localProfile, cloudProfile);

      // Save merged profile locally
      await _localService.saveProfile(merged);

      AppLogging.auth('ProfileSync: Successfully synced from cloud');
      return merged;
    } catch (e) {
      AppLogging.auth('ProfileSync: Error syncing from cloud: $e');
      rethrow;
    }
  }

  /// Two-way sync: push local changes and pull remote changes
  ///
  /// Includes deduplication: if called multiple times within [_syncDebounceWindow]
  /// for the same uid, returns the existing in-flight future.
  Future<UserProfile?> fullSync(String uid) async {
    // Check if we're already syncing for this uid
    if (_activeSyncFuture != null && _activeSyncUid == uid) {
      AppLogging.auth(
        '☁️ fullSync: Already syncing for $uid, returning active future',
      );
      return _activeSyncFuture;
    }

    // Check if we synced recently (within debounce window)
    final now = DateTime.now();
    if (_lastSyncTime != null &&
        _activeSyncUid == uid &&
        now.difference(_lastSyncTime!) < _syncDebounceWindow) {
      AppLogging.auth(
        '☁️ fullSync: Skipping sync for $uid (within debounce window)',
      );
      // Return cached local profile instead of re-syncing
      return _localService.getProfile();
    }

    // Start new sync
    _activeSyncUid = uid;
    _activeSyncFuture = _doFullSync(uid);

    try {
      final result = await _activeSyncFuture;
      _lastSyncTime = DateTime.now();
      return result;
    } finally {
      _activeSyncFuture = null;
    }
  }

  /// Internal implementation of full sync (no deduplication)
  Future<UserProfile?> _doFullSync(String uid) async {
    AppLogging.auth('');
    AppLogging.auth(
      '╔══════════════════════════════════════════════════════════════',
    );
    AppLogging.auth('║ ☁️ ProfileCloudSyncService.fullSync() CALLED');
    AppLogging.auth('║ ☁️ uid: $uid');
    AppLogging.auth(
      '╠══════════════════════════════════════════════════════════════',
    );

    try {
      // First, fetch any remote changes
      AppLogging.auth('║ 📥 Fetching cloud doc for uid: $uid');
      final cloudDoc = await _userDoc(uid).get();
      AppLogging.auth('║ 📥 Cloud doc exists: ${cloudDoc.exists}');

      AppLogging.auth('║ 💾 Getting local profile...');
      final localProfile = await _localService.getOrCreateProfile();
      AppLogging.auth('║ 💾 Local profile:');
      AppLogging.auth('║    - displayName: ${localProfile.displayName}');
      AppLogging.auth('║    - id: ${localProfile.id}');
      AppLogging.auth('║    - isSynced: ${localProfile.isSynced}');

      // Check if local profile belongs to a different user OR is not for this user at all
      // We should NOT merge local data if:
      // 1. It was synced to a different account (isSynced && id != uid)
      // 2. It's a local-only profile that doesn't belong to this user (id != uid)
      // In both cases, prefer cloud data over local to avoid leaking data between accounts
      final localIdMatchesUid = localProfile.id == uid;
      final localIsForDifferentUser = !localIdMatchesUid;

      AppLogging.auth('║ 🔍 Check: localIdMatchesUid = $localIdMatchesUid');
      AppLogging.auth(
        '║ 🔍 Check: localIsForDifferentUser = $localIsForDifferentUser',
      );
      AppLogging.auth('║    - localProfile.isSynced: ${localProfile.isSynced}');
      AppLogging.auth('║    - localProfile.id: ${localProfile.id}');
      AppLogging.auth('║    - uid: $uid');

      if (localIsForDifferentUser) {
        AppLogging.auth(
          '║ ⚠️ LOCAL IS FOR DIFFERENT USER - will prefer cloud data',
        );
      }

      UserProfile finalProfile;

      if (!cloudDoc.exists || cloudDoc.data() == null) {
        // No cloud profile exists
        AppLogging.auth('║ 📭 NO CLOUD PROFILE EXISTS');
        if (localIsForDifferentUser) {
          // Local belongs to different user - create fresh profile for this user
          AppLogging.auth(
            '║ 🆕 Creating fresh profile for new user (local was for different user)',
          );
          final freshProfile = UserProfile.guest().copyWith(
            id: uid,
            isSynced: true,
          );
          await _userDoc(uid).set(_profileToFirestore(freshProfile));
          await _syncPublicProfile(uid, freshProfile);
          finalProfile = freshProfile;
          AppLogging.auth(
            '║ ✅ Created fresh profile: ${freshProfile.displayName}',
          );
        } else {
          // Local profile ID matches this user - push to cloud
          AppLogging.auth(
            '║ 📤 Pushing local profile to cloud (local.id matches uid)',
          );
          final profileForCloud = localProfile.copyWith(
            id: uid,
            isSynced: true,
          );
          await _userDoc(uid).set(_profileToFirestore(profileForCloud));
          await _syncPublicProfile(uid, profileForCloud);
          finalProfile = profileForCloud;
          AppLogging.auth(
            '║ ✅ Pushed local to cloud: ${profileForCloud.displayName}',
          );
        }
      } else {
        // Cloud profile exists
        AppLogging.auth('║ 📬 CLOUD PROFILE EXISTS');
        final cloudProfile = _profileFromFirestore(uid, cloudDoc.data()!);
        AppLogging.auth('║ ☁️ Cloud profile:');
        AppLogging.auth('║    - displayName: ${cloudProfile.displayName}');
        AppLogging.auth('║    - id: ${cloudProfile.id}');
        AppLogging.auth('║    - isSynced: ${cloudProfile.isSynced}');

        if (localIsForDifferentUser) {
          // Local belongs to different user - just use cloud profile
          AppLogging.auth(
            '║ ➡️ Using CLOUD profile (local is for different user)',
          );
          finalProfile = cloudProfile;
        } else {
          // Local is for this user - merge with cloud
          AppLogging.auth(
            '║ 🔀 MERGING local + cloud profiles (local.id matches uid)',
          );
          finalProfile = _mergeProfiles(localProfile, cloudProfile);
          AppLogging.auth('║ 🔀 Merged result: ${finalProfile.displayName}');

          // Push merged version back to cloud
          await _userDoc(
            uid,
          ).set(_profileToFirestore(finalProfile), SetOptions(merge: true));
          await _syncPublicProfile(uid, finalProfile);
        }
      }

      // Save final profile locally
      AppLogging.auth(
        '║ 💾 Saving final profile locally: ${finalProfile.displayName}',
      );
      await _localService.saveProfile(finalProfile);

      AppLogging.auth('║ ✅ Full sync COMPLETE');
      AppLogging.auth(
        '║ 📤 Returning: ${finalProfile.displayName} (id: ${finalProfile.id})',
      );
      AppLogging.auth(
        '╚══════════════════════════════════════════════════════════════',
      );
      AppLogging.auth('');
      return finalProfile;
    } catch (e) {
      AppLogging.auth('║ ❌ ERROR during full sync: $e');
      AppLogging.auth(
        '╚══════════════════════════════════════════════════════════════',
      );
      AppLogging.auth('');
      rethrow;
    }
  }

  /// Delete cloud profile data (from both `users` and `profiles` collections)
  Future<void> deleteCloudProfile(String uid) async {
    AppLogging.auth('ProfileSync: Deleting cloud profile for uid: $uid');

    try {
      // Delete from both collections
      await _userDoc(uid).delete();
      await _publicProfileDoc(uid).delete();

      // Delete avatar from storage
      try {
        await _avatarRef(uid).delete();
      } catch (e) {
        // Avatar might not exist, ignore
        AppLogging.auth(
          'ProfileSync: Avatar delete failed (may not exist): $e',
        );
      }

      AppLogging.auth('ProfileSync: Cloud profile deleted');
    } catch (e) {
      AppLogging.auth('ProfileSync: Error deleting cloud profile: $e');
      rethrow;
    }
  }

  // --- Firebase Storage Avatar Sync ---

  /// Upload avatar to Firebase Storage
  Future<String> uploadAvatar(String uid, File imageFile) async {
    AppLogging.auth('ProfileSync: Uploading avatar for uid: $uid');

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

      // Validate image with Cloud Function
      try {
        final validation = await FirebaseFunctions.instance
            .httpsCallable('validateImages')
            .call({
              'imageUrls': [downloadUrl],
            });

        if (validation.data['passed'] == false) {
          // Delete uploaded file
          await ref.delete();
          throw Exception(
            validation.data['message'] ?? 'Content policy violation',
          );
        }
      } catch (e) {
        // Cleanup on error
        await ref.delete().catchError((_) {});
        rethrow;
      }

      AppLogging.auth('ProfileSync: Avatar uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      AppLogging.auth('ProfileSync: Error uploading avatar: $e');
      rethrow;
    }
  }

  /// Download avatar from Firebase Storage to local cache
  Future<File?> downloadAvatar(String uid) async {
    AppLogging.auth('ProfileSync: Downloading avatar for uid: $uid');

    try {
      final ref = _avatarRef(uid);

      // Get app directory for caching
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/profile_avatars/avatar_$uid.jpg');

      // Ensure directory exists
      await localFile.parent.create(recursive: true);

      // Download to local file
      await ref.writeToFile(localFile);

      AppLogging.auth('ProfileSync: Avatar downloaded to: ${localFile.path}');
      return localFile;
    } catch (e) {
      AppLogging.auth('ProfileSync: Error downloading avatar: $e');
      return null;
    }
  }

  /// Delete avatar from Firebase Storage
  Future<void> deleteCloudAvatar(String uid) async {
    AppLogging.auth('ProfileSync: Deleting cloud avatar for uid: $uid');

    try {
      await _avatarRef(uid).delete();
      AppLogging.auth('ProfileSync: Cloud avatar deleted');
    } catch (e) {
      AppLogging.auth('ProfileSync: Error deleting cloud avatar: $e');
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

  // --- Firebase Storage Banner Sync ---

  /// Upload banner to Firebase Storage
  Future<String> uploadBanner(String uid, File imageFile) async {
    AppLogging.auth('ProfileSync: Uploading banner for uid: $uid');

    try {
      final ref = _bannerRef(uid);

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

      // Validate image with Cloud Function
      try {
        final validation = await FirebaseFunctions.instance
            .httpsCallable('validateImages')
            .call({
              'imageUrls': [downloadUrl],
            });

        if (validation.data['passed'] == false) {
          // Delete uploaded file
          await ref.delete();
          throw Exception(
            validation.data['message'] ?? 'Content policy violation',
          );
        }
      } catch (e) {
        // Cleanup on error
        await ref.delete().catchError((_) {});
        rethrow;
      }

      AppLogging.auth('ProfileSync: Banner uploaded: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      AppLogging.auth('ProfileSync: Error uploading banner: $e');
      rethrow;
    }
  }

  /// Download banner from Firebase Storage to local cache
  Future<File?> downloadBanner(String uid) async {
    AppLogging.auth('ProfileSync: Downloading banner for uid: $uid');

    try {
      final ref = _bannerRef(uid);

      // Get app directory for caching
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/profile_banners/banner_$uid.jpg');

      // Ensure directory exists
      await localFile.parent.create(recursive: true);

      // Download to local file
      await ref.writeToFile(localFile);

      AppLogging.auth('ProfileSync: Banner downloaded to: ${localFile.path}');
      return localFile;
    } catch (e) {
      AppLogging.auth('ProfileSync: Error downloading banner: $e');
      return null;
    }
  }

  /// Delete banner from Firebase Storage
  Future<void> deleteCloudBanner(String uid) async {
    AppLogging.auth('ProfileSync: Deleting cloud banner for uid: $uid');

    try {
      await _bannerRef(uid).delete();
      AppLogging.auth('ProfileSync: Cloud banner deleted');
    } catch (e) {
      AppLogging.auth('ProfileSync: Error deleting cloud banner: $e');
      // Don't rethrow - banner might not exist
    }
  }

  /// Sync local banner to cloud and update profile with URL
  Future<void> syncBannerToCloud(String uid) async {
    final profile = await _localService.getProfile();
    if (profile == null || profile.bannerUrl == null) return;

    // Check if it's a local file path (not already a URL)
    if (!profile.bannerUrl!.startsWith('http')) {
      final localFile = File(profile.bannerUrl!);
      if (await localFile.exists()) {
        final cloudUrl = await uploadBanner(uid, localFile);

        // Update profile with cloud URL
        await _localService.saveProfile(
          profile.copyWith(bannerUrl: cloudUrl, isSynced: true),
        );
      }
    }
  }

  // --- Helper Methods ---

  /// Convert UserProfile to Firestore-compatible map
  /// Note: Social counters (followerCount, followingCount, postCount) are NOT included
  /// because they are managed by Cloud Functions triggers and should never be
  /// overwritten by the client.
  Map<String, dynamic> _profileToFirestore(UserProfile profile) {
    return {
      'displayName': profile.displayName,
      'bio': profile.bio,
      'callsign': profile.callsign,
      'email': profile.email,
      'website': profile.website,
      'avatarUrl': profile.avatarUrl,
      'bannerUrl': profile.bannerUrl,
      'socialLinks': profile.socialLinks?.toJson(),
      'primaryNodeId': profile.primaryNodeId,
      'linkedNodeIds': profile.linkedNodeIds,
      'accentColorIndex': profile.accentColorIndex,
      'installedWidgetIds': profile.installedWidgetIds,
      'preferences': profile.preferences?.toJson(),
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
      // Do NOT include: followerCount, followingCount, postCount, isVerified
      // These are managed by Cloud Functions / admin only
    };
  }

  /// Create UserProfile from Firestore document
  /// Note: Social counters are read from cloud but never written back by client
  UserProfile _profileFromFirestore(String uid, Map<String, dynamic> data) {
    AppLogging.auth(
      'ProfileSync: Parsing Firestore data: displayName=${data['displayName']}, avatarUrl=${data['avatarUrl']}, accentColorIndex=${data['accentColorIndex']}',
    );
    return UserProfile(
      id: uid,
      displayName: data['displayName'] as String? ?? 'Guest',
      bio: data['bio'] as String?,
      callsign: data['callsign'] as String?,
      email: data['email'] as String?,
      website: data['website'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      socialLinks: data['socialLinks'] != null
          ? ProfileSocialLinks.fromJson(
              data['socialLinks'] as Map<String, dynamic>,
            )
          : null,
      primaryNodeId: data['primaryNodeId'] as int?,
      linkedNodeIds:
          (data['linkedNodeIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      accentColorIndex: data['accentColorIndex'] as int?,
      installedWidgetIds:
          (data['installedWidgetIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      preferences: data['preferences'] != null
          ? UserPreferences.fromJson(
              data['preferences'] as Map<String, dynamic>,
            )
          : null,
      isVerified: data['isVerified'] as bool? ?? false,
      isSynced: true,
      // Social counters (read-only from cloud, managed by Cloud Functions)
      followerCount: data['followerCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      postCount: data['postCount'] as int? ?? 0,
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
  /// For installedWidgetIds and linkedNodeIds: use the newer profile's list (NOT union) to respect deletions
  UserProfile _mergeProfiles(UserProfile? local, UserProfile cloud) {
    AppLogging.auth(
      'ProfileSync: Merging profiles - local.isSynced: ${local?.isSynced}, cloud.avatarUrl: ${cloud.avatarUrl}',
    );
    if (local == null) return cloud;

    // If local has never been synced, prefer cloud but merge widget IDs (union)
    // This preserves any local installations made before first sync
    if (!local.isSynced) {
      AppLogging.auth('ProfileSync: Local not synced, using cloud profile');
      // Only use union for first-time sync to preserve local installations
      final mergedWidgetIds = <String>{
        ...local.installedWidgetIds,
        ...cloud.installedWidgetIds,
      }.toList();
      // Merge linked nodes (union for first sync)
      final mergedLinkedNodes = <int>{
        ...local.linkedNodeIds,
        ...cloud.linkedNodeIds,
      }.toList();
      AppLogging.auth(
        'ProfileSync: First sync - merging widget IDs: local=${local.installedWidgetIds}, cloud=${cloud.installedWidgetIds}, merged=$mergedWidgetIds',
      );
      return cloud.copyWith(
        // Preserve any local customizations that don't exist in cloud
        bio: cloud.bio ?? local.bio,
        callsign: cloud.callsign ?? local.callsign,
        website: cloud.website ?? local.website,
        socialLinks: cloud.socialLinks ?? local.socialLinks,
        primaryNodeId: cloud.primaryNodeId ?? local.primaryNodeId,
        linkedNodeIds: mergedLinkedNodes,
        accentColorIndex: cloud.accentColorIndex ?? local.accentColorIndex,
        installedWidgetIds: mergedWidgetIds,
        preferences: cloud.preferences ?? local.preferences,
      );
    }

    // Both synced - use most recently updated
    // IMPORTANT: Use the newer profile's installedWidgetIds and linkedNodeIds (NOT union) to respect deletions
    AppLogging.auth(
      'ProfileSync: Both synced - local.updatedAt: ${local.updatedAt}, cloud.updatedAt: ${cloud.updatedAt}',
    );
    if (local.updatedAt.isAfter(cloud.updatedAt)) {
      AppLogging.auth(
        'ProfileSync: Local is newer, using local installedWidgetIds: ${local.installedWidgetIds}',
      );
      return local.copyWith(isSynced: true);
    }
    AppLogging.auth(
      'ProfileSync: Cloud is newer, using cloud installedWidgetIds: ${cloud.installedWidgetIds}',
    );
    AppLogging.auth(
      'ProfileSync: Cloud accentColorIndex: ${cloud.accentColorIndex}',
    );
    return cloud;
  }

  /// Attempt to read the user profile from Firestore's offline cache.
  ///
  /// Used as a fallback when fullSync fails due to network errors and the
  /// local SharedPreferences profile is stale (e.g. displayName is "Guest").
  /// Firestore persists documents locally after the first successful read,
  /// so this can return the real profile even in airplane mode.
  Future<UserProfile?> getProfileFromCache(String uid) async {
    AppLogging.auth(
      '[ProfileCloudSync] getProfileFromCache() — '
      'attempting Firestore cache read for uid: $uid',
    );
    try {
      final doc = await _userDoc(
        uid,
      ).get(const GetOptions(source: Source.cache));
      if (!doc.exists || doc.data() == null) {
        AppLogging.auth(
          '[ProfileCloudSync] getProfileFromCache() — '
          'no cached doc found',
        );
        return null;
      }
      final profile = _profileFromFirestore(uid, doc.data()!);
      AppLogging.auth(
        '[ProfileCloudSync] getProfileFromCache() — '
        'SUCCESS: displayName="${profile.displayName}", '
        'id=${profile.id}',
      );
      return profile;
    } catch (e) {
      AppLogging.auth(
        '[ProfileCloudSync] getProfileFromCache() — '
        'FAILED: $e',
      );
      return null;
    }
  }
}

/// Exception thrown when a display name is already taken.
class DisplayNameTakenException implements Exception {
  DisplayNameTakenException(this.displayName);

  final String displayName;

  @override
  String toString() =>
      'The display name "$displayName" is already taken. Please choose a different name.';
}

/// Singleton instance — nullable because Firebase init is async and may fail.
/// All access must go through [profileCloudSyncServiceOrNull] or the provider.
ProfileCloudSyncService? profileCloudSyncServiceOrNull;

/// Whether the cloud sync service has been initialized.
bool get isProfileCloudSyncServiceInitialized =>
    profileCloudSyncServiceOrNull != null;

/// Legacy accessor kept for call-sites that are already guarded by
/// null-checks or try/catch. Prefer [profileCloudSyncServiceOrNull].
ProfileCloudSyncService get profileCloudSyncService {
  final svc = profileCloudSyncServiceOrNull;
  if (svc == null) {
    throw StateError(
      'profileCloudSyncService accessed before Firebase initialization. '
      'Use profileCloudSyncServiceOrNull for safe access.',
    );
  }
  return svc;
}

/// Initialize the cloud sync service (call after profileService.initialize())
void initProfileCloudSyncService() {
  profileCloudSyncServiceOrNull = ProfileCloudSyncService(profileService);
}
