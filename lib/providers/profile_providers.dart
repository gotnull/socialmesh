import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../services/profile/profile_cloud_sync_service.dart';
import '../services/profile/profile_service.dart';
import 'auth_providers.dart';

/// Provider for the profile service instance
final profileServiceProvider = Provider<ProfileService>((ref) {
  return profileService;
});

/// Provider for cloud sync service
final profileCloudSyncServiceProvider = Provider<ProfileCloudSyncService>((
  ref,
) {
  return profileCloudSyncService;
});

/// Notifier for managing user profile state using AsyncNotifier pattern
class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    debugPrint('[UserProfile] build() called - loading profile');
    return _loadProfile();
  }

  Future<UserProfile?> _loadProfile() async {
    debugPrint('[UserProfile] _loadProfile() entered');
    await profileService.initialize();
    final profile = await profileService.getOrCreateProfile();
    debugPrint('[UserProfile] Loaded profile: ${profile.displayName}');
    return profile;
  }

  /// Refresh profile from storage
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_loadProfile);
  }

  /// Update profile fields
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? callsign,
    String? website,
    ProfileSocialLinks? socialLinks,
    int? primaryNodeId,
    int? accentColorIndex,
    bool clearBio = false,
    bool clearCallsign = false,
    bool clearWebsite = false,
    bool clearSocialLinks = false,
    bool clearPrimaryNodeId = false,
  }) async {
    try {
      final updated = await profileService.updateProfile(
        displayName: displayName,
        bio: bio,
        callsign: callsign,
        website: website,
        socialLinks: socialLinks,
        primaryNodeId: primaryNodeId,
        accentColorIndex: accentColorIndex,
        clearBio: clearBio,
        clearCallsign: clearCallsign,
        clearWebsite: clearWebsite,
        clearSocialLinks: clearSocialLinks,
        clearPrimaryNodeId: clearPrimaryNodeId,
      );
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Save avatar from file
  Future<void> saveAvatarFromFile(File imageFile) async {
    final profile = state.value;
    if (profile == null) return;

    try {
      await profileService.saveAvatarFromFile(profile.id, imageFile);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete avatar
  Future<void> deleteAvatar() async {
    final profile = state.value;
    if (profile == null) return;

    try {
      await profileService.deleteAvatar(profile.id);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete profile entirely
  Future<void> deleteProfile() async {
    try {
      await profileService.deleteProfile();
      // Create a new guest profile
      final guest = await profileService.getOrCreateProfile();
      state = AsyncValue.data(guest);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Merge with Firebase Auth user data and sync to cloud
  Future<void> mergeWithAuthUser({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
  }) async {
    final current = state.value;
    if (current == null) return;

    try {
      // If this is a guest profile, upgrade it to the Firebase user
      final updated = current.copyWith(
        id: uid,
        email: email,
        displayName: current.displayName == 'Mesh User'
            ? (displayName ?? email?.split('@').first)
            : null,
        avatarUrl: current.avatarUrl == null ? photoUrl : null,
        isSynced: true,
      );
      await profileService.saveProfile(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Sync profile to cloud (requires authenticated user)
  Future<void> syncToCloud(String uid) async {
    try {
      await profileCloudSyncService.syncToCloud(uid);
      await refresh();
    } catch (e, st) {
      debugPrint('[UserProfile] Error syncing to cloud: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Sync profile from cloud (requires authenticated user)
  Future<void> syncFromCloud(String uid) async {
    try {
      final synced = await profileCloudSyncService.syncFromCloud(uid);
      if (synced != null) {
        state = AsyncValue.data(synced);
      }
    } catch (e, st) {
      debugPrint('[UserProfile] Error syncing from cloud: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Full two-way sync with cloud (requires authenticated user)
  Future<void> fullSync(String uid) async {
    try {
      final synced = await profileCloudSyncService.fullSync(uid);
      if (synced != null) {
        state = AsyncValue.data(synced);
      }
    } catch (e, st) {
      debugPrint('[UserProfile] Error during full sync: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Upload avatar to cloud and update profile with cloud URL
  Future<void> uploadAvatarToCloud(String uid, File imageFile) async {
    try {
      // First save locally
      final profile = state.value;
      if (profile == null) return;

      await profileService.saveAvatarFromFile(profile.id, imageFile);

      // Then upload to cloud
      final cloudUrl = await profileCloudSyncService.uploadAvatar(
        uid,
        imageFile,
      );

      // Update profile with cloud URL
      final updated = profile.copyWith(avatarUrl: cloudUrl, isSynced: true);
      await profileService.saveProfile(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      debugPrint('[UserProfile] Error uploading avatar: $e');
      state = AsyncValue.error(e, st);
    }
  }
}

/// Provider for the current user profile
final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(
      UserProfileNotifier.new,
    );

/// Provider for checking if profile is complete
final isProfileCompleteProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null) return false;

  // Profile is considered complete if it has at least a display name
  return profile.displayName.isNotEmpty && profile.displayName != 'Mesh User';
});

/// Provider for profile display name
final profileDisplayNameProvider = Provider<String>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return profile?.displayName ?? 'Mesh User';
});

/// Provider for profile avatar URL
final profileAvatarUrlProvider = Provider<String?>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  return profile?.avatarUrl;
});

/// Provider for whether profile is synced
final isProfileSyncedProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).value;
  final isSignedIn = ref.watch(isSignedInProvider);
  return profile?.isSynced == true && isSignedIn;
});

/// Provider for shareable profile data
final shareableProfileProvider = FutureProvider<SharedProfileData?>((
  ref,
) async {
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null) return null;
  return SharedProfileData.fromProfile(profile);
});
