// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../core/logging.dart';
import '../../models/user_profile.dart';
import 'profile_service.dart';

/// Placeholder display names that are seeded automatically when no real
/// name is available. The public-mirror uniqueness check must skip these
/// — multiple accounts legitimately share them, and a `Guest`-named
/// account would otherwise never get a `profiles/{uid}` doc written
/// (the check throws on the first sync and aborts mid-flight).
@visibleForTesting
const Set<String> placeholderDisplayNames = {'Guest', 'New User'};

/// Sanitise an auth-provider display name so it passes Firestore rules.
///
/// Rules require `^[a-zA-Z0-9._]+$`, 2-30 chars, no leading/trailing period,
/// no consecutive periods, and not all digits.
/// Returns `null` if the result cannot satisfy those constraints.
String? _sanitizeDisplayName(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  // Replace spaces & hyphens with underscores, strip everything else.
  var clean = raw
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');
  // Collapse consecutive periods / underscores.
  clean = clean
      .replaceAll(RegExp(r'\.{2,}'), '.')
      .replaceAll(RegExp(r'_{2,}'), '_');
  // Trim leading/trailing periods and underscores.
  clean = clean.replaceAll(RegExp(r'^[._]+|[._]+\$'), '');
  // Enforce length.
  if (clean.length > 30) clean = clean.substring(0, 30);
  if (clean.length < 2) return null;
  // Must not be all digits.
  if (RegExp(r'^[0-9]+$').hasMatch(clean)) return null;
  return clean;
}

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

  /// Re-encode an image file as JPEG.
  ///
  /// iOS devices may produce HEIC files even when the app names them .jpg.
  /// Maximum dimension for avatar images (longest side)
  static const int _avatarMaxDimension = 1024;

  /// Maximum dimension for banner images (longest side)
  static const int _bannerMaxDimension = 2048;

  /// JPEG quality for profile image uploads (0-100)
  static const int _jpegQuality = 85;

  /// Decodes an image file (including HEIC), resizes to fit within
  /// [maxDimension] on the longest side, and re-encodes as JPEG at
  /// [_jpegQuality]. This keeps uploads well under the 10 MB Storage
  /// rule limit.
  static Future<Uint8List> _prepareImageForUpload(
    File imageFile, {
    required int maxDimension,
  }) async {
    AppLogging.auth(
      'ProfileSync: _prepareImageForUpload path: ${imageFile.path}, '
      'maxDimension: $maxDimension',
    );
    final fileSize = await imageFile.length();
    AppLogging.auth(
      'ProfileSync: _prepareImageForUpload source file size: $fileSize bytes',
    );
    final bytes = await imageFile.readAsBytes();
    AppLogging.auth(
      'ProfileSync: _prepareImageForUpload read ${bytes.length} bytes',
    );
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      AppLogging.auth(
        'ProfileSync: _prepareImageForUpload image decode failed',
      );
      throw const FormatException(
        'Unable to decode image', // lint-allow: hardcoded-string
      );
    }
    AppLogging.auth(
      'ProfileSync: _prepareImageForUpload decoded: '
      '${decoded.width}x${decoded.height}',
    );

    // Resize if the image exceeds the max dimension on either side
    final longestSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;
    if (longestSide > maxDimension) {
      AppLogging.auth(
        'ProfileSync: _prepareImageForUpload resizing from '
        '${decoded.width}x${decoded.height} '
        '(longest side $longestSide > $maxDimension)',
      );
      if (decoded.width >= decoded.height) {
        decoded = img.copyResize(decoded, width: maxDimension);
      } else {
        decoded = img.copyResize(decoded, height: maxDimension);
      }
      AppLogging.auth(
        'ProfileSync: _prepareImageForUpload resized to '
        '${decoded.width}x${decoded.height}',
      );
    }

    final result = Uint8List.fromList(
      img.encodeJpg(decoded, quality: _jpegQuality),
    );
    AppLogging.auth(
      'ProfileSync: _prepareImageForUpload JPEG encoded: '
      '${result.length} bytes (quality: $_jpegQuality)',
    );

    if (result.length > 5 * 1024 * 1024) {
      AppLogging.auth(
        'ProfileSync: _prepareImageForUpload WARNING — result is '
        '${result.length} bytes (>5 MB), may be close to storage limit',
      );
    }

    return result;
  }

  /// Build a public URL for a storage file (no token needed — rules allow
  /// public read for avatars and banners).
  ///
  /// Appends a `v` query parameter (upload epoch millis) so that each upload
  /// produces a distinct URL, busting the OS HTTP cache (NSURLCache / OkHttp)
  /// and Flutter's ImageCache in one shot.
  static String _publicUrl(String folder, String uid) {
    final path = Uri.encodeComponent('$folder/$uid.jpg');
    final v = DateTime.now().millisecondsSinceEpoch;
    return 'https://firebasestorage.googleapis.com/v0/b/'
        'social-mesh-app.firebasestorage.app/o/$path?alt=media&v=$v';
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
      final data = profileToFirestoreMap(profileForCloud);

      // Sync the public mirror first. The uniqueness check on displayName
      // lives inside _syncPublicProfile; if it throws, we want users/{uid}
      // to remain untouched rather than half-updated.
      await _syncPublicProfile(uid, profileForCloud);

      // Use merge to avoid overwriting fields we don't manage
      await _userDoc(uid).set(data, SetOptions(merge: true));

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

    final docRef = _publicProfileDoc(uid);
    final doc = await docRef.get();

    // Only run the uniqueness check when the display name is actually
    // changing AND is not a placeholder. A passive sync (e.g. on app
    // launch) must never throw DisplayNameTakenException for the user's
    // own existing name — that throw used to abort the public-profile
    // write mid-flight, leaving users/{uid} and profiles/{uid} out of
    // sync. Placeholder names like "Guest" and "New User" are seeded
    // automatically when no real name is available, so multiple users
    // legitimately share them; running the uniqueness check against
    // those values would fail for every account that never picked a
    // name and would leave the public mirror permanently missing.
    if (profile.displayName.isNotEmpty &&
        !placeholderDisplayNames.contains(profile.displayName)) {
      final existingName = doc.exists
          ? (doc.data()?['displayName'] as String?)
          : null;
      final nameChanged =
          existingName == null || existingName != profile.displayName;
      if (nameChanged) {
        final isTaken = await isDisplayNameTaken(profile.displayName, uid);
        if (isTaken) {
          throw DisplayNameTakenException(profile.displayName);
        }
      }
    }

    // Null entries are stripped for the same reason as profileToFirestoreMap:
    // writing nulls would wipe existing cloud fields when a stale or
    // partially-loaded local profile is synced.
    final publicData = <String, dynamic>{
      'displayName': profile.displayName,
      'displayNameLower': profile.displayName.toLowerCase(),
      'linkedNodeIds': profile.linkedNodeIds,
      // Note: isVerified is NOT included - managed by admin only
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final safeAvatarUrl = _sanitizeUrlForCloud(profile.avatarUrl);
    if (safeAvatarUrl != null) publicData['avatarUrl'] = safeAvatarUrl;
    final safeBannerUrl = _sanitizeUrlForCloud(profile.bannerUrl);
    if (safeBannerUrl != null) publicData['bannerUrl'] = safeBannerUrl;
    final bio = profile.bio;
    if (bio != null) publicData['bio'] = bio;
    final callsign = profile.callsign;
    if (callsign != null) publicData['callsign'] = callsign;
    final website = profile.website;
    if (website != null) publicData['website'] = website;
    final socialLinks = profile.socialLinks?.toJson();
    if (socialLinks != null) publicData['socialLinks'] = socialLinks;
    final primaryNodeId = profile.primaryNodeId;
    if (primaryNodeId != null) publicData['primaryNodeId'] = primaryNodeId;

    if (!doc.exists) {
      // Document doesn't exist - create with counter fields set to 0
      publicData['followerCount'] = 0;
      publicData['followingCount'] = 0;
      publicData['postCount'] = 0;
      publicData['createdAt'] = FieldValue.serverTimestamp();
      await docRef.set(publicData);
      AppLogging.auth('ProfileSync: Created new public profile');
    } else {
      // Use set(merge: true) instead of update() so the call succeeds even
      // if some fields were missing on the existing doc.
      await docRef.set(publicData, SetOptions(merge: true));
      AppLogging.auth('ProfileSync: Updated existing public profile');
    }
  }

  /// Backfill any fields that are present in the public mirror
  /// (`profiles/{uid}`) but missing from the private user doc
  /// (`users/{uid}`). Recovers from past drift caused by partial writes —
  /// e.g. the `profileToFirestoreMap` null-stomp bug that wiped users/{uid}
  /// while leaving profiles/{uid} intact.
  ///
  /// If anything is backfilled, the corrected fields are also written
  /// back to `users/{uid}` so subsequent reads see the recovered state.
  Future<UserProfile> _recoverDriftFromPublicMirror(
    String uid,
    UserProfile cloud,
  ) async {
    final publicDoc = await _publicProfileDoc(uid).get();
    if (!publicDoc.exists) return cloud;
    final public = publicDoc.data();
    if (public == null) return cloud;

    final recovered = mergePublicMirrorIntoCloud(cloud, public);
    if (identical(recovered, cloud)) return cloud;

    AppLogging.auth(
      'ProfileSync: 🩹 Drift recovered from profiles/{uid} → '
      'avatar=${recovered.avatarUrl != cloud.avatarUrl}, '
      'banner=${recovered.bannerUrl != cloud.bannerUrl}, '
      'bio=${recovered.bio != cloud.bio}, '
      'callsign=${recovered.callsign != cloud.callsign}, '
      'website=${recovered.website != cloud.website}, '
      'primaryNodeId=${recovered.primaryNodeId != cloud.primaryNodeId}, '
      'socialLinks=${recovered.socialLinks != cloud.socialLinks}',
    );

    // Persist the recovered fields back to users/{uid}. Stripped-null
    // payload + merge:true means only the newly-filled keys are written.
    await _userDoc(
      uid,
    ).set(profileToFirestoreMap(recovered), SetOptions(merge: true));
    return recovered;
  }

  /// Pure-logic counterpart of [_recoverDriftFromPublicMirror]: given a
  /// cloud-side `UserProfile` and the raw `profiles/{uid}` document data,
  /// return a profile whose null fields are backfilled from the public
  /// mirror. Returns the same `cloud` instance (via `identical`) when
  /// nothing changes — callers can use `identical(out, cloud)` as a
  /// no-op signal.
  @visibleForTesting
  static UserProfile mergePublicMirrorIntoCloud(
    UserProfile cloud,
    Map<String, dynamic> public,
  ) {
    final recoveredAvatarUrl =
        cloud.avatarUrl ?? public['avatarUrl'] as String?;
    final recoveredBannerUrl =
        cloud.bannerUrl ?? public['bannerUrl'] as String?;
    final recoveredBio = cloud.bio ?? public['bio'] as String?;
    final recoveredCallsign = cloud.callsign ?? public['callsign'] as String?;
    final recoveredWebsite = cloud.website ?? public['website'] as String?;
    final recoveredPrimaryNodeId =
        cloud.primaryNodeId ?? public['primaryNodeId'] as int?;
    final publicSocialLinks = public['socialLinks'] as Map<String, dynamic>?;
    final recoveredSocialLinks =
        cloud.socialLinks ??
        (publicSocialLinks != null
            ? ProfileSocialLinks.fromJson(publicSocialLinks)
            : null);
    // displayName is intentionally NOT recovered from the public mirror.
    // The cloud doc is the source of truth for the user's own name —
    // pulling from public would clobber legitimate private edits where
    // the public mirror hadn't caught up yet. If a past null-stomp left
    // users/{uid}.displayName at an Auth-fallback shape, that needs a
    // manual / one-shot fix, not silent drift recovery on every sync.

    final didRecover =
        recoveredAvatarUrl != cloud.avatarUrl ||
        recoveredBannerUrl != cloud.bannerUrl ||
        recoveredBio != cloud.bio ||
        recoveredCallsign != cloud.callsign ||
        recoveredWebsite != cloud.website ||
        recoveredPrimaryNodeId != cloud.primaryNodeId ||
        recoveredSocialLinks != cloud.socialLinks;
    if (!didRecover) return cloud;

    return cloud.copyWith(
      avatarUrl: recoveredAvatarUrl,
      bannerUrl: recoveredBannerUrl,
      bio: recoveredBio,
      callsign: recoveredCallsign,
      website: recoveredWebsite,
      primaryNodeId: recoveredPrimaryNodeId,
      socialLinks: recoveredSocialLinks,
    );
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
  /// Full two-way sync between local profile and Firestore.
  ///
  /// [authDisplayName] is the display name from Firebase Auth (e.g. Google
  /// account name). When a brand-new cloud profile must be created for a
  /// first-time user, this name is used instead of the default "Guest".
  Future<UserProfile?> fullSync(String uid, {String? authDisplayName}) async {
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
    _activeSyncFuture = _doFullSync(uid, authDisplayName: authDisplayName);

    try {
      final result = await _activeSyncFuture;
      _lastSyncTime = DateTime.now();
      return result;
    } finally {
      _activeSyncFuture = null;
    }
  }

  /// Internal implementation of full sync (no deduplication)
  Future<UserProfile?> _doFullSync(
    String uid, {
    String? authDisplayName,
  }) async {
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
          // Local belongs to different user - create fresh profile for this user.
          // Use the Firebase Auth display name (e.g. from Google) if available
          // so the user doesn't end up with "Guest" as their cloud name.
          // Sanitise first — auth names contain spaces ("Simon Cusa") but
          // Firestore rules require ^[a-zA-Z0-9._]+$.
          final name = _sanitizeDisplayName(authDisplayName);
          AppLogging.auth(
            '║ 🆕 Creating fresh profile for new user '
            '(local was for different user, authDisplayName=$authDisplayName, '
            'sanitized=$name)',
          );
          final freshProfile = (name != null && name.isNotEmpty)
              ? UserProfile.fromFirebaseUser(uid: uid, displayName: name)
              : UserProfile.guest().copyWith(id: uid, isSynced: true);
          // Public mirror first so a uniqueness throw cannot leave
          // users/{uid} half-written. Always merge, never overwrite — if
          // a concurrent write or stale cache made cloudDoc appear
          // missing when it actually exists, a bare set() would wipe it.
          await _syncPublicProfile(uid, freshProfile);
          await _userDoc(
            uid,
          ).set(profileToFirestoreMap(freshProfile), SetOptions(merge: true));
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
          await _syncPublicProfile(uid, profileForCloud);
          await _userDoc(uid).set(
            profileToFirestoreMap(profileForCloud),
            SetOptions(merge: true),
          );
          finalProfile = profileForCloud;
          AppLogging.auth(
            '║ ✅ Pushed local to cloud: ${profileForCloud.displayName}',
          );
        }
      } else {
        // Cloud profile exists
        AppLogging.auth('║ 📬 CLOUD PROFILE EXISTS');
        final rawCloudProfile = _profileFromFirestore(uid, cloudDoc.data()!);
        AppLogging.auth('║ ☁️ Cloud profile:');
        AppLogging.auth('║    - displayName: ${rawCloudProfile.displayName}');
        AppLogging.auth('║    - id: ${rawCloudProfile.id}');
        AppLogging.auth('║    - isSynced: ${rawCloudProfile.isSynced}');

        // Recover any fields that drifted out of users/{uid} but still
        // live in profiles/{uid}. A previous bug (null entries in
        // profileToFirestoreMap + non-merge set()) could wipe avatar,
        // banner, bio, etc. on the private doc while leaving the public
        // mirror intact when its uniqueness check threw mid-flight. This
        // pulls those fields back so the user's own app surfaces match
        // what every other reader (admin dashboard, other users) sees.
        final cloudProfile = await _recoverDriftFromPublicMirror(
          uid,
          rawCloudProfile,
        );

        if (localIsForDifferentUser) {
          // Local belongs to different user - just use cloud profile.
          // If the cloud profile still has a stale "Guest" name (e.g. from a
          // previous app version) but the auth provider has a real name,
          // patch the cloud doc so the user doesn't stay as "Guest".
          final patchedName = _sanitizeDisplayName(authDisplayName);
          if (cloudProfile.displayName == 'Guest' &&
              patchedName != null &&
              patchedName.isNotEmpty) {
            AppLogging.auth(
              '║ ➡️ Using CLOUD profile, patching stale Guest name '
              '→ $patchedName (raw=$authDisplayName)',
            );
            finalProfile = cloudProfile.copyWith(displayName: patchedName);
            await _syncPublicProfile(uid, finalProfile);
            await _userDoc(
              uid,
            ).set(profileToFirestoreMap(finalProfile), SetOptions(merge: true));
          } else {
            AppLogging.auth(
              '║ ➡️ Using CLOUD profile (local is for different user)',
            );
            finalProfile = cloudProfile;
          }
        } else {
          // Local is for this user - merge with cloud
          AppLogging.auth(
            '║ 🔀 MERGING local + cloud profiles (local.id matches uid)',
          );
          finalProfile = _mergeProfiles(localProfile, cloudProfile);
          AppLogging.auth('║ 🔀 Merged result: ${finalProfile.displayName}');

          // Push merged version back to cloud (public mirror first so a
          // uniqueness throw cannot leave users/{uid} half-written).
          await _syncPublicProfile(uid, finalProfile);
          await _userDoc(
            uid,
          ).set(profileToFirestoreMap(finalProfile), SetOptions(merge: true));
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
    AppLogging.auth(
      'ProfileSync: uploadAvatar called — uid: $uid, path: ${imageFile.path}',
    );

    try {
      final fileSize = await imageFile.length();
      AppLogging.auth(
        'ProfileSync: uploadAvatar source file size: $fileSize bytes',
      );

      final ref = _avatarRef(uid);
      AppLogging.auth('ProfileSync: uploadAvatar storageRef: ${ref.fullPath}');

      // Re-encode as JPEG, resize to max 1024px — iOS may provide HEIC data
      AppLogging.auth(
        'ProfileSync: uploadAvatar starting image preparation...',
      );
      final jpegBytes = await _prepareImageForUpload(
        imageFile,
        maxDimension: _avatarMaxDimension,
      );
      AppLogging.auth(
        'ProfileSync: uploadAvatar JPEG ready: ${jpegBytes.length} bytes',
      );

      // Upload with metadata
      AppLogging.auth('ProfileSync: uploadAvatar calling putData...');
      await ref.putData(
        jpegBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uid': uid},
        ),
      );
      AppLogging.auth('ProfileSync: uploadAvatar putData complete');

      // Get download URL
      AppLogging.auth('ProfileSync: uploadAvatar calling getDownloadURL...');
      final downloadUrl = await ref.getDownloadURL();
      AppLogging.auth('ProfileSync: uploadAvatar getDownloadURL: $downloadUrl');

      // Validate image with Cloud Function
      AppLogging.auth(
        'ProfileSync: uploadAvatar calling validateImages Cloud Function...',
      );
      try {
        final validation = await FirebaseFunctions.instance
            .httpsCallable('validateImages')
            .call({
              'imageUrls': [downloadUrl],
            });

        AppLogging.auth(
          'ProfileSync: uploadAvatar validateImages response: ${validation.data}',
        );
        if (validation.data['passed'] == false) {
          AppLogging.auth(
            'ProfileSync: uploadAvatar failed content policy: ${validation.data["message"]}',
          );
          // Delete uploaded file
          await ref.delete();
          throw Exception(
            validation.data['message'] ??
                'Content policy violation', // lint-allow: hardcoded-string
          );
        }
        AppLogging.auth(
          'ProfileSync: uploadAvatar passed content policy check',
        );
      } catch (e) {
        AppLogging.auth(
          'ProfileSync: uploadAvatar validateImages error (cleaning up): $e',
        );
        // Cleanup on error
        await ref.delete().catchError((_) {});
        rethrow;
      }

      final publicUrl = _publicUrl(_avatarsFolder, uid);
      AppLogging.auth(
        'ProfileSync: uploadAvatar complete — downloadUrl: $downloadUrl, publicUrl: $publicUrl',
      );
      return publicUrl;
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
    AppLogging.auth('ProfileSync: syncAvatarToCloud called for uid: $uid');
    final profile = await _localService.getProfile();
    if (profile == null) {
      AppLogging.auth(
        'ProfileSync: syncAvatarToCloud — no local profile found, skipping',
      );
      return;
    }
    if (profile.avatarUrl == null) {
      AppLogging.auth(
        'ProfileSync: syncAvatarToCloud — avatarUrl is null, skipping',
      );
      return;
    }

    AppLogging.auth(
      'ProfileSync: syncAvatarToCloud — avatarUrl: ${profile.avatarUrl}',
    );

    // Check if it's a local file path (not already a URL)
    if (!profile.avatarUrl!.startsWith('http')) {
      AppLogging.auth(
        'ProfileSync: syncAvatarToCloud — is local path, checking file exists...',
      );
      final localFile = File(profile.avatarUrl!);
      final exists = await localFile.exists();
      AppLogging.auth(
        'ProfileSync: syncAvatarToCloud — local file exists: $exists',
      );
      if (exists) {
        final cloudUrl = await uploadAvatar(uid, localFile);
        AppLogging.auth(
          'ProfileSync: syncAvatarToCloud — uploaded, cloudUrl: $cloudUrl',
        );

        // Update profile with cloud URL
        final updated = profile.copyWith(avatarUrl: cloudUrl, isSynced: true);
        await _localService.saveProfile(updated);
        AppLogging.auth(
          'ProfileSync: syncAvatarToCloud — local profile updated with cloud URL',
        );

        // Push the cloud URL to Firestore so other clients can see it
        await _syncPublicProfile(uid, updated);
        AppLogging.auth('ProfileSync: syncAvatarToCloud — complete');
      } else {
        AppLogging.auth(
          'ProfileSync: syncAvatarToCloud — local file missing, cannot upload',
        );
      }
    } else {
      AppLogging.auth(
        'ProfileSync: syncAvatarToCloud — already a cloud URL, skipping upload',
      );
    }
  }

  // --- Firebase Storage Banner Sync ---

  /// Upload banner to Firebase Storage
  Future<String> uploadBanner(String uid, File imageFile) async {
    AppLogging.auth(
      'ProfileSync: uploadBanner called — uid: $uid, path: ${imageFile.path}',
    );

    try {
      final fileSize = await imageFile.length();
      AppLogging.auth(
        'ProfileSync: uploadBanner source file size: $fileSize bytes',
      );

      final ref = _bannerRef(uid);
      AppLogging.auth('ProfileSync: uploadBanner storageRef: ${ref.fullPath}');

      // Re-encode as JPEG, resize to max 2048px — iOS may provide HEIC data
      AppLogging.auth(
        'ProfileSync: uploadBanner starting image preparation...',
      );
      final jpegBytes = await _prepareImageForUpload(
        imageFile,
        maxDimension: _bannerMaxDimension,
      );
      AppLogging.auth(
        'ProfileSync: uploadBanner JPEG ready: ${jpegBytes.length} bytes',
      );

      // Upload with metadata
      AppLogging.auth('ProfileSync: uploadBanner calling putData...');
      await ref.putData(
        jpegBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {'uid': uid},
        ),
      );
      AppLogging.auth('ProfileSync: uploadBanner putData complete');

      // Get download URL
      AppLogging.auth('ProfileSync: uploadBanner calling getDownloadURL...');
      final downloadUrl = await ref.getDownloadURL();
      AppLogging.auth('ProfileSync: uploadBanner getDownloadURL: $downloadUrl');

      // Validate image with Cloud Function
      AppLogging.auth(
        'ProfileSync: uploadBanner calling validateImages Cloud Function...',
      );
      try {
        final validation = await FirebaseFunctions.instance
            .httpsCallable('validateImages')
            .call({
              'imageUrls': [downloadUrl],
            });

        AppLogging.auth(
          'ProfileSync: uploadBanner validateImages response: ${validation.data}',
        );
        if (validation.data['passed'] == false) {
          AppLogging.auth(
            'ProfileSync: uploadBanner failed content policy: ${validation.data["message"]}',
          );
          // Delete uploaded file
          await ref.delete();
          throw Exception(
            validation.data['message'] ??
                'Content policy violation', // lint-allow: hardcoded-string
          );
        }
        AppLogging.auth(
          'ProfileSync: uploadBanner passed content policy check',
        );
      } catch (e) {
        AppLogging.auth(
          'ProfileSync: uploadBanner validateImages error (cleaning up): $e',
        );
        // Cleanup on error
        await ref.delete().catchError((_) {});
        rethrow;
      }

      final publicUrl = _publicUrl(_bannersFolder, uid);
      AppLogging.auth(
        'ProfileSync: uploadBanner complete — downloadUrl: $downloadUrl, publicUrl: $publicUrl',
      );
      return publicUrl;
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
    AppLogging.auth('ProfileSync: syncBannerToCloud called for uid: $uid');
    final profile = await _localService.getProfile();
    if (profile == null) {
      AppLogging.auth(
        'ProfileSync: syncBannerToCloud — no local profile found, skipping',
      );
      return;
    }
    if (profile.bannerUrl == null) {
      AppLogging.auth(
        'ProfileSync: syncBannerToCloud — bannerUrl is null, skipping',
      );
      return;
    }

    AppLogging.auth(
      'ProfileSync: syncBannerToCloud — bannerUrl: ${profile.bannerUrl}',
    );

    // Check if it's a local file path (not already a URL)
    if (!profile.bannerUrl!.startsWith('http')) {
      AppLogging.auth(
        'ProfileSync: syncBannerToCloud — is local path, checking file exists...',
      );
      final localFile = File(profile.bannerUrl!);
      final exists = await localFile.exists();
      AppLogging.auth(
        'ProfileSync: syncBannerToCloud — local file exists: $exists',
      );
      if (exists) {
        final cloudUrl = await uploadBanner(uid, localFile);
        AppLogging.auth(
          'ProfileSync: syncBannerToCloud — uploaded, cloudUrl: $cloudUrl',
        );

        // Update profile with cloud URL
        final updated = profile.copyWith(bannerUrl: cloudUrl, isSynced: true);
        await _localService.saveProfile(updated);
        AppLogging.auth(
          'ProfileSync: syncBannerToCloud — local profile updated with cloud URL',
        );

        // Push the cloud URL to Firestore so other clients can see it
        await _syncPublicProfile(uid, updated);
        AppLogging.auth('ProfileSync: syncBannerToCloud — complete');
      } else {
        AppLogging.auth(
          'ProfileSync: syncBannerToCloud — local file missing, cannot upload',
        );
      }
    } else {
      AppLogging.auth(
        'ProfileSync: syncBannerToCloud — already a cloud URL, skipping upload',
      );
    }
  }

  // --- Helper Methods ---

  /// Returns the URL unchanged if it starts with http(s), otherwise null.
  /// Used by merge logic to preserve cloud URLs that exist locally but
  /// are missing from the Firestore document.
  static String? _preserveHttpUrl(String? url) {
    if (url == null) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return null;
  }

  /// Returns the URL only if it is an HTTP(S) URL, otherwise null.
  /// Prevents local file paths (e.g. /var/mobile/...) from being written
  /// to Firestore where they would be meaningless to other clients.
  static String? _sanitizeUrlForCloud(String? url) {
    if (url == null) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    AppLogging.auth(
      'ProfileSync: Blocked local path from Firestore write: '
      '${url.length > 60 ? '${url.substring(0, 60)}...' : url}',
    );
    return null;
  }

  /// Convert UserProfile to Firestore-compatible map
  /// Note: Social counters (followerCount, followingCount, postCount) are NOT included
  /// because they are managed by Cloud Functions triggers and should never be
  /// overwritten by the client.
  @visibleForTesting
  static Map<String, dynamic> profileToFirestoreMap(UserProfile profile) {
    // Null entries are stripped: writing `{avatarUrl: null}` with
    // `SetOptions(merge: true)` still overwrites the cloud value to null,
    // so a stale or freshly-created local profile (avatar/banner/bio not
    // yet loaded) would silently wipe existing cloud data. Omitting the
    // key entirely is the only safe default. Explicit clears must use
    // `FieldValue.delete()` at the call site.
    final data = <String, dynamic>{
      'displayName': profile.displayName,
      'linkedNodeIds': profile.linkedNodeIds,
      'installedWidgetIds': profile.installedWidgetIds,
      'createdAt': profile.createdAt.toIso8601String(),
      'updatedAt': FieldValue.serverTimestamp(),
      // Do NOT include: followerCount, followingCount, postCount, isVerified
      // These are managed by Cloud Functions / admin only
    };
    final bio = profile.bio;
    if (bio != null) data['bio'] = bio;
    final callsign = profile.callsign;
    if (callsign != null) data['callsign'] = callsign;
    final email = profile.email;
    if (email != null) data['email'] = email;
    final website = profile.website;
    if (website != null) data['website'] = website;
    final safeAvatarUrl = _sanitizeUrlForCloud(profile.avatarUrl);
    if (safeAvatarUrl != null) data['avatarUrl'] = safeAvatarUrl;
    final safeBannerUrl = _sanitizeUrlForCloud(profile.bannerUrl);
    if (safeBannerUrl != null) data['bannerUrl'] = safeBannerUrl;
    final socialLinks = profile.socialLinks?.toJson();
    if (socialLinks != null) data['socialLinks'] = socialLinks;
    final primaryNodeId = profile.primaryNodeId;
    if (primaryNodeId != null) data['primaryNodeId'] = primaryNodeId;
    final accentColorIndex = profile.accentColorIndex;
    if (accentColorIndex != null) data['accentColorIndex'] = accentColorIndex;
    final preferences = profile.preferences?.toJson();
    if (preferences != null) data['preferences'] = preferences;
    return data;
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

    // Preserve avatar/banner cloud URLs that were uploaded to Storage but
    // never written to Firestore (the original sync sanitized local paths
    // to null). If local has a valid HTTPS URL and cloud has null, keep it.
    final mergedAvatarUrl =
        cloud.avatarUrl ?? _preserveHttpUrl(local.avatarUrl);
    final mergedBannerUrl =
        cloud.bannerUrl ?? _preserveHttpUrl(local.bannerUrl);
    if (mergedAvatarUrl != cloud.avatarUrl ||
        mergedBannerUrl != cloud.bannerUrl) {
      AppLogging.auth(
        'ProfileSync: Preserving local media URLs — '
        'avatar: ${mergedAvatarUrl != cloud.avatarUrl}, '
        'banner: ${mergedBannerUrl != cloud.bannerUrl}',
      );
      return cloud.copyWith(
        avatarUrl: mergedAvatarUrl,
        bannerUrl: mergedBannerUrl,
      );
    }
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
      'The display name "$displayName" is already taken. Please choose a different name.'; // lint-allow: hardcoded-string
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
