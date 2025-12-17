import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  SharedPreferences? _prefs;
  Directory? _avatarDir;

  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _initAvatarDirectory();
  }

  Future<void> _initAvatarDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    _avatarDir = Directory('${appDir.path}/$_avatarDirName');
    if (!await _avatarDir!.exists()) {
      await _avatarDir!.create(recursive: true);
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

  /// Get the current user profile
  Future<UserProfile?> getProfile() async {
    final json = _preferences.getString(_profileKey);
    if (json == null) return null;

    try {
      return UserProfile.fromJsonString(json);
    } catch (e) {
      debugPrint('Error parsing profile: $e');
      return null;
    }
  }

  /// Save the user profile
  Future<void> saveProfile(UserProfile profile) async {
    await _preferences.setString(_profileKey, profile.toJsonString());
  }

  /// Delete the user profile
  Future<void> deleteProfile() async {
    await _preferences.remove(_profileKey);
    await _clearAvatarImages();
  }

  /// Check if a profile exists
  bool hasProfile() {
    return _preferences.containsKey(_profileKey);
  }

  /// Get or create profile (creates guest profile if none exists)
  Future<UserProfile> getOrCreateProfile() async {
    final existing = await getProfile();
    if (existing != null) return existing;

    final guest = UserProfile.guest();
    await saveProfile(guest);
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
