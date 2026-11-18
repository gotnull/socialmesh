// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/logging.dart';
import '../models/social.dart';

/// Service for the public profile document and the mesh nodes linked to it.
///
/// Reads and writes `profiles/{userId}` in Firestore directly.
class SocialService {
  SocialService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _currentUserId => _auth.currentUser?.uid;

  // ===========================================================================
  // PUBLIC PROFILES
  // ===========================================================================

  /// Ensures the current user has a profile document in Firestore.
  /// Creates one if it doesn't exist, using Firebase Auth display name.
  /// Runs before a node is linked, so the profile document exists to update.
  Future<void> ensureProfileExists() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in');
    }

    final docRef = _firestore.collection('profiles').doc(user.uid);

    // Force server check to avoid cache issues
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      doc = await docRef.get(const GetOptions(source: Source.server));
    } catch (e) {
      doc = await docRef.get();
    }

    // Try to get the user's app profile (from 'users' collection) to sync displayName
    String? userProfileDisplayName;
    String? userProfileAvatarUrl;
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      if (userDoc.exists) {
        final userData = userDoc.data();
        userProfileDisplayName = userData?['displayName'] as String?;
        userProfileAvatarUrl = userData?['avatarUrl'] as String?;
      }
    } catch (e) {
      // Ignore - will use OAuth displayName as fallback
    }

    if (!doc.exists) {
      // Create profile - prefer users collection displayName over OAuth name
      var displayName =
          userProfileDisplayName ??
          user.displayName ??
          user.email?.split('@').first ??
          'User';
      final avatarUrl = userProfileAvatarUrl ?? user.photoURL;

      // Ensure display name is unique - append numbers if taken
      displayName = await _generateUniqueDisplayName(displayName, user.uid);

      await docRef.set({
        'displayName': displayName,
        'displayNameLower': displayName.toLowerCase(),
        'avatarUrl': avatarUrl,
        'bio': null,
        'callsign': null,
        'followerCount': 0,
        'followingCount': 0,
        'postCount': 0,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Profile exists - check if we need to sync displayName from users collection
      final currentDisplayName = doc.data()?['displayName'] as String?;
      if (userProfileDisplayName != null &&
          userProfileDisplayName.isNotEmpty &&
          userProfileDisplayName != currentDisplayName) {
        // Check if the new display name is available before syncing
        final isTaken = await isDisplayNameTaken(
          userProfileDisplayName,
          user.uid,
        );
        if (!isTaken) {
          // Sync the displayName from users collection to profiles collection
          final updates = <String, dynamic>{
            'displayName': userProfileDisplayName,
            'displayNameLower': userProfileDisplayName.toLowerCase(),
            'updatedAt': FieldValue.serverTimestamp(),
          };
          // Also sync avatar if users collection has one
          if (userProfileAvatarUrl != null && userProfileAvatarUrl.isNotEmpty) {
            updates['avatarUrl'] = userProfileAvatarUrl;
          }
          await docRef.update(updates);
        }
        // If taken, silently skip - user will need to choose a different name manually
      }
    }
  }

  /// Get a user's public profile.
  Future<PublicProfile?> getPublicProfile(String userId) async {
    AppLogging.auth('Social: getPublicProfile() called for userId=$userId');
    return _getPublicProfile(userId);
  }

  /// Find a user by their linked mesh node ID.
  /// Returns null if no user has this node in their linkedNodeIds.
  Future<PublicProfile?> getProfileByNodeId(int nodeId) async {
    AppLogging.auth('Social: getProfileByNodeId() - START for nodeId=$nodeId');
    try {
      // Query using array-contains on linkedNodeIds
      final query = await _firestore
          .collection('profiles')
          .where('linkedNodeIds', arrayContains: nodeId)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        AppLogging.auth(
          'Social: getProfileByNodeId() - No profile found for nodeId=$nodeId',
        );
        return null;
      }
      final profile = PublicProfile.fromFirestore(query.docs.first);
      AppLogging.auth(
        'Social: getProfileByNodeId() - Found: userId=${profile.id}, displayName=${profile.displayName}',
      );
      return profile;
    } catch (e) {
      AppLogging.auth('Social: getProfileByNodeId() - ERROR: $e');
      return null;
    }
  }

  /// Link a mesh node to the current user's profile.
  /// If setPrimary is true, also sets it as the primary node.
  /// Optionally caches node metadata (longName, shortName, avatarColor) for display.
  Future<void> linkNodeToProfile(
    int nodeId, {
    bool setPrimary = false,
    String? longName,
    String? shortName,
    int? avatarColor,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to link nodes');
    }

    await ensureProfileExists();

    final docRef = _firestore.collection('profiles').doc(currentUserId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw StateError('Profile does not exist');
    }

    final currentLinkedNodes =
        (doc.data()?['linkedNodeIds'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];

    // Add node if not already linked
    if (!currentLinkedNodes.contains(nodeId)) {
      currentLinkedNodes.add(nodeId);
    }

    final updates = <String, dynamic>{
      'linkedNodeIds': currentLinkedNodes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Also update primary if requested or if this is the first node
    if (setPrimary || currentLinkedNodes.length == 1) {
      updates['primaryNodeId'] = nodeId;
    }

    // Store node metadata for display when node isn't in local cache
    if (longName != null || shortName != null || avatarColor != null) {
      final nodeIdKey = nodeId.toString();
      updates['linkedNodeMetadata.$nodeIdKey'] = {
        'nodeId': nodeId,
        if (longName != null) 'longName': longName,
        if (shortName != null) 'shortName': shortName,
        if (avatarColor != null) 'avatarColor': avatarColor,
      };
    }

    await docRef.update(updates);
  }

  /// Update cached metadata for a linked node.
  Future<void> updateLinkedNodeMetadata(
    int nodeId, {
    String? longName,
    String? shortName,
    int? avatarColor,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final docRef = _firestore.collection('profiles').doc(currentUserId);
    final nodeIdKey = nodeId.toString();

    await docRef.update({
      'linkedNodeMetadata.$nodeIdKey': {
        'nodeId': nodeId,
        if (longName != null) 'longName': longName,
        if (shortName != null) 'shortName': shortName,
        if (avatarColor != null) 'avatarColor': avatarColor,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unlink a mesh node from the current user's profile.
  Future<void> unlinkNodeFromProfile(int nodeId) async {
    AppLogging.social(
      '[SocialService.unlinkNodeFromProfile] Starting for nodeId: $nodeId',
    );

    final currentUserId = _currentUserId;
    AppLogging.social(
      '[SocialService.unlinkNodeFromProfile] currentUserId: $currentUserId',
    );
    if (currentUserId == null) {
      AppLogging.social(
        '[SocialService.unlinkNodeFromProfile] ERROR: Not signed in',
      );
      throw StateError('Must be signed in to unlink nodes');
    }

    final docRef = _firestore.collection('profiles').doc(currentUserId);
    AppLogging.social(
      '[SocialService.unlinkNodeFromProfile] Fetching profile doc...',
    );
    final doc = await docRef.get();

    if (!doc.exists) {
      AppLogging.social(
        '[SocialService.unlinkNodeFromProfile] Profile doc does not exist, returning early',
      );
      return;
    }

    AppLogging.social(
      '[SocialService.unlinkNodeFromProfile] Profile doc exists, parsing data...',
    );
    final currentLinkedNodes =
        (doc.data()?['linkedNodeIds'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];
    final currentPrimaryId = doc.data()?['primaryNodeId'] as int?;
    AppLogging.social(
      '[SocialService.unlinkNodeFromProfile] Current state: '
      'linkedNodes=$currentLinkedNodes, primaryId=$currentPrimaryId',
    );

    // Remove the node
    final removed = currentLinkedNodes.remove(nodeId);
    AppLogging.social(
      '[SocialService.unlinkNodeFromProfile] Removed nodeId $nodeId: $removed, '
      'remaining: $currentLinkedNodes',
    );

    final updates = <String, dynamic>{
      'linkedNodeIds': currentLinkedNodes,
      'updatedAt': FieldValue.serverTimestamp(),
      // Remove the cached metadata for this node
      'linkedNodeMetadata.${nodeId.toString()}': FieldValue.delete(),
    };

    // If we removed the primary node, set a new one or clear it
    if (currentPrimaryId == nodeId) {
      updates['primaryNodeId'] = currentLinkedNodes.isNotEmpty
          ? currentLinkedNodes.first
          : null;
      AppLogging.social(
        '[SocialService.unlinkNodeFromProfile] Primary node removed, '
        'new primary: ${updates['primaryNodeId']}',
      );
    }

    AppLogging.social(
      '[SocialService.unlinkNodeFromProfile] Updating Firestore with: $updates',
    );
    try {
      await docRef.update(updates);
      AppLogging.social(
        '[SocialService.unlinkNodeFromProfile] Firestore update SUCCESS',
      );
    } catch (e, stackTrace) {
      AppLogging.social(
        '[SocialService.unlinkNodeFromProfile] Firestore update FAILED: $e',
      );
      AppLogging.social(
        '[SocialService.unlinkNodeFromProfile] Stack trace: $stackTrace',
      );
      rethrow;
    }
  }

  /// Set a linked node as the primary node.
  Future<void> setPrimaryNode(int nodeId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to set primary node');
    }

    final docRef = _firestore.collection('profiles').doc(currentUserId);
    final doc = await docRef.get();

    if (!doc.exists) {
      throw StateError('Profile does not exist');
    }

    final currentLinkedNodes =
        (doc.data()?['linkedNodeIds'] as List<dynamic>?)
            ?.map((e) => e as int)
            .toList() ??
        [];

    // Only allow setting primary if node is already linked
    if (!currentLinkedNodes.contains(nodeId)) {
      throw ArgumentError('Node must be linked before setting as primary');
    }

    await docRef.update({
      'primaryNodeId': nodeId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Watch the current user's linked node IDs with real-time updates.
  Stream<List<int>> watchLinkedNodeIds() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('profiles')
        .doc(currentUserId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return <int>[];
          return (doc.data()?['linkedNodeIds'] as List<dynamic>?)
                  ?.map((e) => e as int)
                  .toList() ??
              <int>[];
        })
        .handleError((Object e) {
          AppLogging.social('Linked node IDs stream error: $e');
        });
  }

  /// Stream a user's public profile with real-time updates from server.
  Stream<PublicProfile?> watchPublicProfile(String userId) {
    return _firestore
        .collection('profiles')
        .doc(userId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return PublicProfile.fromFirestore(doc);
        })
        .handleError((Object e) {
          AppLogging.social('Public profile stream error: $e');
        });
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
    // We store displayNameLower for efficient querying
    final query = await _firestore
        .collection('profiles')
        .where('displayNameLower', isEqualTo: normalizedName)
        .limit(2) // Only need to find one other user
        .get();

    // Check if any results belong to a different user
    for (final doc in query.docs) {
      if (excludeUserId == null || doc.id != excludeUserId) {
        return true; // Found another user with this name
      }
    }
    return false;
  }

  /// Generate a unique display name by appending numbers if the base name is taken.
  /// Sanitizes the name to match validation rules (no spaces, valid chars only).
  Future<String> _generateUniqueDisplayName(
    String baseName,
    String excludeUserId,
  ) async {
    // Sanitize: replace spaces with underscores, remove invalid chars
    var sanitized = baseName
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._]'), '');

    // Ensure not empty and meets minimum length
    if (sanitized.length < 2) {
      sanitized = 'user_$sanitized';
    }

    // Truncate to leave room for numbers (max 30 chars)
    if (sanitized.length > 25) {
      sanitized = sanitized.substring(0, 25);
    }

    // Check if base name is available
    if (!await isDisplayNameTaken(sanitized, excludeUserId)) {
      return sanitized;
    }

    // Try appending numbers until we find an available name
    for (var i = 1; i < 1000; i++) {
      final candidate = '$sanitized$i';
      if (!await isDisplayNameTaken(candidate, excludeUserId)) {
        return candidate;
      }
    }

    // Fallback: use timestamp-based unique name
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  // ===========================================================================
  // PRIVATE HELPERS
  // ===========================================================================

  Future<PublicProfile?> _getPublicProfile(String userId) async {
    AppLogging.auth('Social: _getPublicProfile() - START for userId=$userId');
    // Try server first for fresh data, fall back to cache
    DocumentSnapshot<Map<String, dynamic>> doc;
    try {
      AppLogging.auth('Social: _getPublicProfile() - Fetching from server...');
      doc = await _firestore
          .collection('profiles')
          .doc(userId)
          .get(const GetOptions(source: Source.server));
      AppLogging.auth('Social: _getPublicProfile() - Server fetch complete');
    } catch (e) {
      // Server fetch failed, try cache
      AppLogging.auth(
        'Social: _getPublicProfile() - Server failed ($e), trying cache...',
      );
      doc = await _firestore.collection('profiles').doc(userId).get();
    }
    if (!doc.exists) {
      AppLogging.auth(
        'Social: _getPublicProfile() - PROFILE NOT FOUND for userId=$userId',
      );
      return null;
    }
    final profile = PublicProfile.fromFirestore(doc);
    AppLogging.auth(
      'Social: _getPublicProfile() - Found: displayName=${profile.displayName}, isVerified=${profile.isVerified}',
    );
    return profile;
  }
}
