import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../models/user_profile.dart';

/// Service for managing user profile data with local storage.
///
/// Supports:
/// - Local profile storage using SharedPreferences
/// - Avatar image storage in app documents
/// - Profile import/export for backup
class ProfileService {
  static const String _profileKey = 'user_profile';
  static const String _avatarDirName = 'profile_avatars';
  static const String _bannerDirName = 'profile_banners';

  SharedPreferences? _prefs;
  Directory? _avatarDir;
  Directory? _bannerDir;

  /// Initialize the service
  Future<void> initialize() async {
    AppLogging.auth('ProfileService: initialize() - START');
    _prefs = await SharedPreferences.getInstance();
    await _initAvatarDirectory();
    await _initBannerDirectory();
    AppLogging.auth('ProfileService: initialize() - ✅ COMPLETE');
  }

  Future<void> _initAvatarDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _avatarDir = Directory('${appDir.path}/$_avatarDirName');
    if (!await _avatarDir!.exists()) {
      await _avatarDir!.create(recursive: true);
      AppLogging.auth('ProfileService: Created avatar directory');
    }
  }

  Future<void> _initBannerDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _bannerDir = Directory('${appDir.path}/$_bannerDirName');
    if (!await _bannerDir!.exists()) {
      await _bannerDir!.create(recursive: true);
      AppLogging.auth('ProfileService: Created banner directory');
    }
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError(
        'ProfileService not initialized. Call initialize() first.',
      );
    }
    return _prefs!;
  }

  Directory get _avatarDirectory {
    if (_avatarDir == null) {
      throw StateError(
        'ProfileService not initialized. Call initialize() first.',
      );
    }
    return _avatarDir!;
  }

  Directory get _bannerDirectory {
    if (_bannerDir == null) {
      throw StateError(
        'ProfileService not initialized. Call initialize() first.',
      );
    }
    return _bannerDir!;
  }

  /// Get the current user profile
  Future<UserProfile?> getProfile() async {
    AppLogging.auth('ProfileService: getProfile() - START');

    // Force reload SharedPreferences from disk to avoid stale cache
    // This is important on iOS where NSUserDefaults can cache values
    await _preferences.reload();

    final json = _preferences.getString(_profileKey);
    if (json == null) {
      AppLogging.auth(
        'ProfileService: getProfile() - ❌ NO PROFILE FOUND (key missing)',
      );
      return null;
    }

    try {
      final profile = UserProfile.fromJsonString(json);
      AppLogging.auth(
        'ProfileService: getProfile() - ✅ Found profile: id=${profile.id}, displayName=${profile.displayName}',
      );
      return profile;
    } catch (e) {
      AppLogging.auth(
        'ProfileService: getProfile() - ❌ ERROR parsing profile: $e',
      );
      return null;
    }
  }

  /// Save the user profile
  Future<void> saveProfile(UserProfile profile) async {
    AppLogging.auth(
      'ProfileService: saveProfile() - Saving: id=${profile.id}, displayName=${profile.displayName}, isSynced=${profile.isSynced}',
    );
    await _preferences.setString(_profileKey, profile.toJsonString());
    AppLogging.auth('ProfileService: saveProfile() - ✅ SAVED');
  }

  /// Delete the user profile
  Future<void> deleteProfile() async {
    AppLogging.auth('ProfileService: deleteProfile() - START');
    await _preferences.remove(_profileKey);
    await _clearAvatarImages();
    await _clearBannerImages();
    AppLogging.auth('ProfileService: deleteProfile() - ✅ DELETED');
  }

  /// Check if a profile exists
  bool hasProfile() {
    final exists = _preferences.containsKey(_profileKey);
    AppLogging.auth('ProfileService: hasProfile() - $exists');
    return exists;
  }

  /// Get or create profile (creates guest profile if none exists)
  Future<UserProfile> getOrCreateProfile() async {
    AppLogging.auth('ProfileService: getOrCreateProfile() - START');
    final existing = await getProfile();
    if (existing != null) {
      // Migrate legacy "meshuser" name to "Guest" for unsigned-out users
      if (existing.displayName == 'meshuser' && !existing.isSynced) {
        AppLogging.auth(
          'ProfileService: getOrCreateProfile() - 🔄 Migrating legacy meshuser to Guest',
        );
        final migrated = existing.copyWith(displayName: 'Guest');
        await saveProfile(migrated);
        return migrated;
      }
      AppLogging.auth(
        'ProfileService: getOrCreateProfile() - ✅ Returning existing: ${existing.displayName}',
      );
      return existing;
    }

    AppLogging.auth(
      'ProfileService: getOrCreateProfile() - Creating new guest profile',
    );
    final guest = UserProfile.guest();
    await saveProfile(guest);
    AppLogging.auth(
      'ProfileService: getOrCreateProfile() - ✅ Created guest: id=${guest.id}',
    );
    return guest;
  }

  /// Update profile with changes
  Future<UserProfile> updateProfile({
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
    final current = await getOrCreateProfile();
    final updated = current.copyWith(
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
    await saveProfile(updated);
    return updated;
  }

  // Avatar management

  /// Get the path for storing an avatar image
  String _getAvatarPath(String profileId) {
    return '${_avatarDirectory.path}/avatar_$profileId.jpg';
  }

  /// Save avatar image from file
  Future<String> saveAvatarFromFile(String profileId, File imageFile) async {
    final avatarPath = _getAvatarPath(profileId);

    // Copy the image to our avatar directory
    await imageFile.copy(avatarPath);

    // Update profile with local avatar URL
    final profile = await getOrCreateProfile();
    await saveProfile(profile.copyWith(avatarUrl: avatarPath));

    return avatarPath;
  }

  /// Save avatar image from bytes
  Future<String> saveAvatarFromBytes(String profileId, Uint8List bytes) async {
    final avatarPath = _getAvatarPath(profileId);
    final avatarFile = File(avatarPath);

    await avatarFile.writeAsBytes(bytes);

    // Update profile with local avatar URL
    final profile = await getOrCreateProfile();
    await saveProfile(profile.copyWith(avatarUrl: avatarPath));

    return avatarPath;
  }

  /// Get avatar file if it exists
  Future<File?> getAvatarFile(String profileId) async {
    final avatarPath = _getAvatarPath(profileId);
    final file = File(avatarPath);
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Delete avatar image
  Future<void> deleteAvatar(String profileId) async {
    final avatarPath = _getAvatarPath(profileId);
    final file = File(avatarPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Update profile to remove avatar URL
    final profile = await getProfile();
    if (profile != null) {
      await saveProfile(profile.copyWith(clearAvatarUrl: true));
    }
  }

  /// Clear all avatar images
  Future<void> _clearAvatarImages() async {
    if (await _avatarDirectory.exists()) {
      final files = await _avatarDirectory.list().toList();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    }
  }

  // Banner management

  /// Get the path for storing a banner image
  String _getBannerPath(String profileId) {
    return '${_bannerDirectory.path}/banner_$profileId.jpg';
  }

  /// Save banner image from file
  Future<String> saveBannerFromFile(String profileId, File imageFile) async {
    final bannerPath = _getBannerPath(profileId);

    // Copy the image to our banner directory
    await imageFile.copy(bannerPath);

    // Update profile with local banner URL
    final profile = await getOrCreateProfile();
    await saveProfile(profile.copyWith(bannerUrl: bannerPath));

    return bannerPath;
  }

  /// Delete banner image
  Future<void> deleteBanner(String profileId) async {
    final bannerPath = _getBannerPath(profileId);
    final file = File(bannerPath);
    if (await file.exists()) {
      await file.delete();
    }

    // Update profile to remove banner URL
    final profile = await getProfile();
    if (profile != null) {
      await saveProfile(profile.copyWith(clearBannerUrl: true));
    }
  }

  /// Clear all banner images
  Future<void> _clearBannerImages() async {
    if (await _bannerDirectory.exists()) {
      final files = await _bannerDirectory.list().toList();
      for (final file in files) {
        if (file is File) {
          await file.delete();
        }
      }
    }
  }

  // Export/Import for backup

  /// Export profile as JSON string (for backup)
  Future<String?> exportProfile() async {
    final profile = await getProfile();
    if (profile == null) return null;
    return profile.toJsonString();
  }

  /// Import profile from JSON string (for restore)
  Future<UserProfile> importProfile(String jsonString) async {
    final profile = UserProfile.fromJsonString(jsonString);
    await saveProfile(profile);
    return profile;
  }

  /// Get shareable profile data (compact format for QR codes)
  Future<SharedProfileData?> getShareableData() async {
    final profile = await getProfile();
    if (profile == null) return null;
    return SharedProfileData.fromProfile(profile);
  }
}

/// Singleton instance for convenience
final profileService = ProfileService();
