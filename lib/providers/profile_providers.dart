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

    // Initialize and load local profile
    await profileService.initialize();
    final localProfile = await profileService.getOrCreateProfile();
    debugPrint(
      '[UserProfile] Loaded local profile: ${localProfile.displayName}',
    );

    // Check if user is already signed in (persisted session)
    final user = ref.read(currentUserProvider);
    if (user != null) {
      debugPrint('[UserProfile] User already signed in, syncing from cloud');
      // Update sync status
      ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);

      try {
        // Perform full sync with cloud
        final synced = await profileCloudSyncService.fullSync(user.uid);
        if (synced != null) {
          debugPrint(
            '[UserProfile] Cloud sync complete: ${synced.displayName}',
          );
          ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.synced);
          return synced;
        }
      } catch (e) {
        debugPrint('[UserProfile] Cloud sync failed: $e');
        ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.error);
        ref.read(syncErrorProvider.notifier).setError(e.toString());
        // Fall back to local profile on error
      }
    }

    return localProfile;
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

  /// Save avatar from file (and upload to cloud if signed in)
  Future<void> saveAvatarFromFile(File imageFile) async {
    final profile = state.value;
    if (profile == null) return;

    try {
      // Save locally first
      await profileService.saveAvatarFromFile(profile.id, imageFile);

      // If user is signed in, also upload to cloud
      final user = ref.read(currentUserProvider);
      if (user != null) {
        debugPrint('[UserProfile] User signed in, uploading avatar to cloud');
        final cloudUrl = await profileCloudSyncService.uploadAvatar(
          user.uid,
          imageFile,
        );

        // Update profile with cloud URL
        final updated = profile.copyWith(avatarUrl: cloudUrl, isSynced: true);
        await profileService.saveProfile(updated);
        state = AsyncValue.data(updated);
      } else {
        await refresh();
      }
    } catch (e, st) {
      debugPrint('[UserProfile] Error saving avatar: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Delete avatar (and from cloud if signed in)
  Future<void> deleteAvatar() async {
    final profile = state.value;
    if (profile == null) return;

    try {
      // Delete locally
      await profileService.deleteAvatar(profile.id);

      // If signed in, also delete from cloud
      final user = ref.read(currentUserProvider);
      if (user != null) {
        debugPrint('[UserProfile] Deleting avatar from cloud');
        await profileCloudSyncService.deleteCloudAvatar(user.uid);
      }

      await refresh();
    } catch (e, st) {
      debugPrint('[UserProfile] Error deleting avatar: $e');
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
      // Sync profile data
      final synced = await profileCloudSyncService.fullSync(uid);
      if (synced != null) {
        state = AsyncValue.data(synced);

        // Also sync avatar if it's a local file path
        if (synced.avatarUrl != null && !synced.avatarUrl!.startsWith('http')) {
          debugPrint('[UserProfile] Syncing local avatar to cloud');
          await profileCloudSyncService.syncAvatarToCloud(uid);
          await refresh();
        }
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

/// Sync status for UI feedback
enum SyncStatus { idle, syncing, synced, error }

/// Notifier for sync status
class SyncStatusNotifier extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;

  void setStatus(SyncStatus status) => state = status;
}

/// Provider for tracking sync status
final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

/// Notifier for sync error message
class SyncErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String? error) => state = error;
}

/// Provider for the last sync error message
final syncErrorProvider = NotifierProvider<SyncErrorNotifier, String?>(
  SyncErrorNotifier.new,
);

/// Tracks the previous user ID to detect sign-in
class PreviousUserNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setUserId(String? userId) => state = userId;
}

final _previousUserProvider = NotifierProvider<PreviousUserNotifier, String?>(
  PreviousUserNotifier.new,
);

/// Auto-sync provider that triggers sync when auth state changes
/// This should be watched by a widget high in the tree (e.g., main_shell)
final autoSyncProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final previousUser = ref.read(_previousUserProvider);

  // Update previous user tracker
  ref.read(_previousUserProvider.notifier).setUserId(user?.uid);

  // If user just signed in (was null, now has value)
  if (previousUser == null && user != null) {
    debugPrint('[AutoSync] User signed in, triggering sync');
    _triggerAutoSync(ref, user.uid);
  }
});

/// Trigger automatic sync with status tracking
Future<void> _triggerAutoSync(Ref ref, String uid) async {
  ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);
  ref.read(syncErrorProvider.notifier).setError(null);

  try {
    await ref.read(userProfileProvider.notifier).fullSync(uid);
    ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.synced);
    debugPrint('[AutoSync] Sync completed successfully');
  } catch (e) {
    debugPrint('[AutoSync] Sync failed: $e');
    ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.error);
    ref.read(syncErrorProvider.notifier).setError(e.toString());
  }
}

/// Manually trigger sync (for pull-to-refresh or retry)
Future<void> triggerManualSync(WidgetRef ref) async {
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.syncing);
  ref.read(syncErrorProvider.notifier).setError(null);

  try {
    await ref.read(userProfileProvider.notifier).fullSync(user.uid);
    ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.synced);
  } catch (e) {
    ref.read(syncStatusProvider.notifier).setStatus(SyncStatus.error);
    ref.read(syncErrorProvider.notifier).setError(e.toString());
    rethrow;
  }
}
