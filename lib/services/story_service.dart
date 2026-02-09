// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:socialmesh/core/logging.dart';
import 'package:uuid/uuid.dart';

import '../models/social.dart';
import '../models/story.dart';
import 'social_activity_service.dart';

/// Service for story operations: create, delete, view tracking, and retrieval.
///
/// Stories are ephemeral content that expires after 24 hours.
/// Uses Firestore for data and Firebase Storage for media.
class StoryService {
  StoryService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  String? get _currentUserId => _auth.currentUser?.uid;

  // ===========================================================================
  // STORY CREATION
  // ===========================================================================

  /// Create a new story with media upload.
  ///
  /// [mediaFile] - The image or video file to upload
  /// [mediaType] - Type of media (image or video)
  /// [duration] - How long to display (default 5s for images)
  /// [location] - Optional location data
  /// [nodeId] - Optional mesh node reference
  /// [textOverlay] - Optional text overlay
  /// [visibility] - Who can see the story
  Future<Story> createStory({
    required File mediaFile,
    StoryMediaType mediaType = StoryMediaType.image,
    int? duration,
    PostLocation? location,
    String? nodeId,
    List<String>? mentions,
    List<String>? hashtags,
    TextOverlay? textOverlay,
    StoryVisibility visibility = StoryVisibility.public,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to create stories');
    }

    // Generate IDs
    final storyId = _uuid.v4();
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    // Upload media to Firebase Storage
    final mediaUrl = await _uploadStoryMedia(
      userId: currentUserId,
      storyId: storyId,
      file: mediaFile,
      isVideo: mediaType == StoryMediaType.video,
    );

    // Validate image with Cloud Function (only for images, not videos)
    if (mediaType == StoryMediaType.image) {
      try {
        final validation = await FirebaseFunctions.instance
            .httpsCallable('validateImages')
            .call({
              'imageUrls': [mediaUrl],
            });

        if (validation.data['passed'] == false) {
          // Delete uploaded file
          await _storage
              .ref()
              .child('stories/$currentUserId/$storyId')
              .delete();
          throw Exception(
            validation.data['message'] ?? 'Content policy violation',
          );
        }
      } catch (e) {
        // Cleanup on error
        await _storage
            .ref()
            .child('stories/$currentUserId/$storyId')
            .delete()
            .catchError((_) {});
        rethrow;
      }
    }

    // Get author snapshot
    final authorSnapshot = await _getAuthorSnapshot(currentUserId);

    // Create story document
    final story = Story(
      id: storyId,
      authorId: currentUserId,
      authorSnapshot: authorSnapshot,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      duration: duration ?? (mediaType == StoryMediaType.video ? 15 : 5),
      createdAt: now,
      expiresAt: expiresAt,
      location: location,
      nodeId: nodeId,
      mentions: mentions ?? [],
      hashtags: hashtags ?? [],
      textOverlay: textOverlay,
      visibility: visibility,
    );

    await _firestore
        .collection('stories')
        .doc(storyId)
        .set(story.toFirestore());

    // Update user's hasActiveStory flag
    await _firestore.collection('users').doc(currentUserId).set({
      'hasActiveStory': true,
      'lastStoryAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return story;
  }

  /// Upload media file to Firebase Storage
  Future<String> _uploadStoryMedia({
    required String userId,
    required String storyId,
    required File file,
    bool isVideo = false,
  }) async {
    final extension = path.extension(file.path).toLowerCase();
    final fileName = isVideo ? 'media$extension' : 'media.jpg';
    final ref = _storage.ref().child('stories/$userId/$storyId/$fileName');

    final metadata = SettableMetadata(
      contentType: isVideo ? 'video/mp4' : 'image/jpeg',
      customMetadata: {'storyId': storyId, 'userId': userId},
    );

    await ref.putFile(file, metadata);
    return ref.getDownloadURL();
  }

  /// Get author snapshot for the current user
  Future<PostAuthorSnapshot?> _getAuthorSnapshot(String userId) async {
    try {
      final doc = await _firestore.collection('profiles').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return PostAuthorSnapshot(
        displayName: data['displayName'] as String? ?? 'User',
        avatarUrl: data['avatarUrl'] as String?,
        isVerified: data['isVerified'] as bool? ?? false,
        nodeNum: data['primaryNodeId'] as int?,
      );
    } catch (e) {
      AppLogging.social('Error getting author snapshot: $e');
      return null;
    }
  }

  // ===========================================================================
  // STORY DELETION
  // ===========================================================================

  /// Delete a story and its media
  Future<void> deleteStory(String storyId) async {
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Starting delete for storyId=$storyId',
    );

    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      AppLogging.social('🗑️ [StoryService.deleteStory] ERROR: Not signed in');
      throw StateError('Must be signed in to delete stories');
    }
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Current user: $currentUserId',
    );

    // Get the story to verify ownership
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Fetching story document...',
    );
    final storyDoc = await _firestore.collection('stories').doc(storyId).get();
    if (!storyDoc.exists) {
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Story document does not exist, returning',
      );
      return;
    }
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Story document exists, data: ${storyDoc.data()}',
    );

    final story = Story.fromFirestore(storyDoc);
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Story authorId: ${story.authorId}, currentUserId: $currentUserId',
    );
    if (story.authorId != currentUserId) {
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] ERROR: Cannot delete another user\'s story',
      );
      throw StateError('Cannot delete another user\'s story');
    }

    // Delete media from storage
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Deleting media from storage...',
    );
    try {
      final storageRef = _storage.ref().child(
        'stories/$currentUserId/$storyId',
      );
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Storage path: stories/$currentUserId/$storyId',
      );
      final items = await storageRef.listAll();
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Found ${items.items.length} media items to delete',
      );
      for (final item in items.items) {
        AppLogging.social(
          '🗑️ [StoryService.deleteStory] Deleting: ${item.fullPath}',
        );
        await item.delete();
      }
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Media deleted successfully',
      );
    } catch (e, stack) {
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Error deleting story media: $e',
      );
      AppLogging.social('🗑️ [StoryService.deleteStory] Stack: $stack');
    }

    // Delete viewers subcollection FIRST (before deleting story document)
    // This is required because the viewers permission rule checks the parent story's authorId
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Deleting viewers subcollection...',
    );
    try {
      final viewsSnapshot = await _firestore
          .collection('stories')
          .doc(storyId)
          .collection('viewers')
          .get();
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Found ${viewsSnapshot.docs.length} viewer docs to delete',
      );
      for (final doc in viewsSnapshot.docs) {
        await doc.reference.delete();
      }
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Viewers deleted successfully',
      );
    } catch (e, stack) {
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Error deleting viewers: $e',
      );
      AppLogging.social('🗑️ [StoryService.deleteStory] Stack: $stack');
    }

    // Delete story document (after viewers are deleted)
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Deleting story document...',
    );
    try {
      await _firestore.collection('stories').doc(storyId).delete();
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] Story document deleted successfully',
      );
    } catch (e, stack) {
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] ERROR deleting story document: $e',
      );
      AppLogging.social('🗑️ [StoryService.deleteStory] Stack: $stack');
      rethrow;
    }

    // Check if user has any remaining stories and update flag
    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Checking for remaining stories...',
    );
    final remainingStories = await _firestore
        .collection('stories')
        .where('authorId', isEqualTo: currentUserId)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .limit(1)
        .get();

    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Remaining stories: ${remainingStories.docs.length}',
    );
    if (remainingStories.docs.isEmpty) {
      AppLogging.social(
        '🗑️ [StoryService.deleteStory] No remaining stories, setting hasActiveStory=false',
      );
      await _firestore.collection('users').doc(currentUserId).set({
        'hasActiveStory': false,
      }, SetOptions(merge: true));
    }

    AppLogging.social(
      '🗑️ [StoryService.deleteStory] Delete completed successfully',
    );
  }

  // ===========================================================================
  // STORY RETRIEVAL
  // ===========================================================================

  /// Get current user's active stories
  Stream<List<Story>> watchMyStories() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('stories')
        .where('authorId', isEqualTo: currentUserId)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Story.fromFirestore).toList());
  }

  /// Get stories from users the current user follows
  Stream<List<Story>> watchFollowingStories() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    // First get the list of users we follow
    return _firestore
        .collection('follows')
        .where('followerId', isEqualTo: currentUserId)
        .snapshots()
        .asyncMap((followsSnapshot) async {
          if (followsSnapshot.docs.isEmpty) return <Story>[];

          final followedUserIds = followsSnapshot.docs
              .map((d) => d.data()['followeeId'] as String)
              .toList();

          // Firestore 'whereIn' has a limit of 30, so batch if needed
          final stories = <Story>[];
          for (var i = 0; i < followedUserIds.length; i += 30) {
            final batch = followedUserIds.skip(i).take(30).toList();
            final snapshot = await _firestore
                .collection('stories')
                .where('authorId', whereIn: batch)
                .where('expiresAt', isGreaterThan: Timestamp.now())
                .orderBy('expiresAt')
                .orderBy('createdAt', descending: true)
                .get();
            stories.addAll(snapshot.docs.map(Story.fromFirestore));
          }

          // Sort by creation time, newest first
          stories.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return stories;
        });
  }

  /// Get stories for a specific user
  Future<List<Story>> getUserStories(String userId) async {
    final snapshot = await _firestore
        .collection('stories')
        .where('authorId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(Story.fromFirestore).toList();
  }

  /// Get a single story by ID
  Future<Story?> getStory(String storyId) async {
    final doc = await _firestore.collection('stories').doc(storyId).get();
    if (!doc.exists) return null;
    return Story.fromFirestore(doc);
  }

  // ===========================================================================
  // VIEW TRACKING
  // ===========================================================================

  /// Mark a story as viewed by the current user
  Future<void> markStoryViewed(String storyId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    // Get the story to check ownership
    final storyDoc = await _firestore.collection('stories').doc(storyId).get();
    if (!storyDoc.exists) return;

    final story = Story.fromFirestore(storyDoc);

    // Don't record view for own stories
    if (story.authorId == currentUserId) return;

    // Create view record
    final viewRef = _firestore
        .collection('stories')
        .doc(storyId)
        .collection('viewers')
        .doc(currentUserId);

    final existingView = await viewRef.get();
    if (existingView.exists) return; // Already viewed

    final view = StoryView(viewerId: currentUserId, viewedAt: DateTime.now());
    await viewRef.set(view.toFirestore());

    // Increment view count
    await _firestore.collection('stories').doc(storyId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  /// Get viewers of a story (only for story owner)
  Future<List<StoryView>> getStoryViewers(String storyId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    // Verify ownership
    final storyDoc = await _firestore.collection('stories').doc(storyId).get();
    if (!storyDoc.exists) return [];

    final story = Story.fromFirestore(storyDoc);
    if (story.authorId != currentUserId) return [];

    final snapshot = await _firestore
        .collection('stories')
        .doc(storyId)
        .collection('viewers')
        .orderBy('viewedAt', descending: true)
        .limit(500)
        .get();

    return snapshot.docs.map(StoryView.fromFirestore).toList();
  }

  /// Stream of viewers for a story
  Stream<List<StoryView>> watchStoryViewers(String storyId) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('stories')
        .doc(storyId)
        .collection('viewers')
        .orderBy('viewedAt', descending: true)
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(StoryView.fromFirestore).toList());
  }

  /// Check if current user has viewed a story
  Future<bool> hasViewedStory(String storyId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final doc = await _firestore
        .collection('stories')
        .doc(storyId)
        .collection('viewers')
        .doc(currentUserId)
        .get();

    return doc.exists;
  }

  /// Get IDs of stories the current user has viewed
  Future<Set<String>> getViewedStoryIds(List<String> storyIds) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return {};

    final viewedIds = <String>{};
    for (final storyId in storyIds) {
      final doc = await _firestore
          .collection('stories')
          .doc(storyId)
          .collection('viewers')
          .doc(currentUserId)
          .get();
      if (doc.exists) {
        viewedIds.add(storyId);
      }
    }
    return viewedIds;
  }

  // ===========================================================================
  // STORY GROUPS
  // ===========================================================================

  /// Get stories grouped by user for the story bar display
  Future<List<StoryGroup>> getStoryGroups() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    // Get following list
    final followsSnapshot = await _firestore
        .collection('follows')
        .where('followerId', isEqualTo: currentUserId)
        .get();

    final followedUserIds = followsSnapshot.docs
        .map((d) => d.data()['followeeId'] as String)
        .toList();

    AppLogging.social(
      '📖 [StoryGroups] Following ${followedUserIds.length} users: $followedUserIds',
    );

    // Add current user to get their stories too
    final userIds = [currentUserId, ...followedUserIds];

    // Get all active stories
    final stories = <Story>[];
    for (var i = 0; i < userIds.length; i += 30) {
      final batch = userIds.skip(i).take(30).toList();
      AppLogging.social('📖 [StoryGroups] Querying stories for batch: $batch');
      final snapshot = await _firestore
          .collection('stories')
          .where('authorId', whereIn: batch)
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .get();
      AppLogging.social(
        '📖 [StoryGroups] Found ${snapshot.docs.length} stories in batch',
      );
      stories.addAll(snapshot.docs.map(Story.fromFirestore));
    }

    AppLogging.social(
      '📖 [StoryGroups] Total stories found: ${stories.length}',
    );

    // Group by user
    final groupedByUser = <String, List<Story>>{};
    for (final story in stories) {
      groupedByUser.putIfAbsent(story.authorId, () => []).add(story);
    }

    // Check viewed status
    final allStoryIds = stories.map((s) => s.id).toList();
    final viewedIds = await getViewedStoryIds(allStoryIds);

    // Create story groups
    final groups = <StoryGroup>[];
    for (final entry in groupedByUser.entries) {
      final userId = entry.key;
      final userStories = entry.value;

      // Sort stories by creation time
      userStories.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Check if any are unviewed (don't count own stories)
      final hasUnviewed =
          userId != currentUserId &&
          userStories.any((s) => !viewedIds.contains(s.id));

      groups.add(
        StoryGroup(
          userId: userId,
          profile: userStories.first.authorSnapshot,
          stories: userStories,
          hasUnviewed: hasUnviewed,
          lastStoryAt: userStories
              .map((s) => s.createdAt)
              .reduce((a, b) => a.isAfter(b) ? a : b),
        ),
      );
    }

    // Sort: own stories first, then unviewed, then by recency
    groups.sort((a, b) {
      // Own stories first
      if (a.userId == currentUserId) return -1;
      if (b.userId == currentUserId) return 1;

      // Unviewed before viewed
      if (a.hasUnviewed && !b.hasUnviewed) return -1;
      if (!a.hasUnviewed && b.hasUnviewed) return 1;

      // Most recent first
      return b.lastStoryAt.compareTo(a.lastStoryAt);
    });

    return groups;
  }

  /// Stream of story groups for real-time updates
  Stream<List<StoryGroup>> watchStoryGroups() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return Stream.value([]);

    // Watch for any story changes
    return _firestore
        .collection('stories')
        .where('expiresAt', isGreaterThan: Timestamp.now())
        .orderBy('expiresAt')
        .snapshots()
        .asyncMap((_) => getStoryGroups());
  }

  // ===========================================================================
  // STORY LIKES
  // ===========================================================================

  /// Like/favorite a story
  ///
  /// Returns true if this is a new like, false if already liked
  Future<bool> likeStory(String storyId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to like stories');
    }

    final storyRef = _firestore.collection('stories').doc(storyId);
    final likeRef = storyRef.collection('likes').doc(currentUserId);

    // Check if already liked
    final existingLike = await likeRef.get();
    if (existingLike.exists) {
      return false;
    }

    // Get the story to find the owner
    final storyDoc = await storyRef.get();
    if (!storyDoc.exists) {
      return false;
    }
    final story = Story.fromFirestore(storyDoc);

    // Create the like
    await likeRef.set({
      'userId': currentUserId,
      'likedAt': FieldValue.serverTimestamp(),
    });

    // Increment like count
    await storyRef.update({'likeCount': FieldValue.increment(1)});

    // Create activity for story owner
    final activityService = SocialActivityService(
      firestore: _firestore,
      auth: _auth,
    );
    await activityService.createStoryLikeActivity(
      storyId: storyId,
      storyOwnerId: story.authorId,
      storyThumbnailUrl: story.mediaUrl,
    );

    return true;
  }

  /// Unlike a story
  Future<void> unlikeStory(String storyId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw StateError('Must be signed in to unlike stories');
    }

    final storyRef = _firestore.collection('stories').doc(storyId);
    final likeRef = storyRef.collection('likes').doc(currentUserId);

    // Check if like exists
    final existingLike = await likeRef.get();
    if (!existingLike.exists) {
      return;
    }

    // Delete the like
    await likeRef.delete();

    // Decrement like count
    await storyRef.update({'likeCount': FieldValue.increment(-1)});
  }

  /// Check if the current user has liked a story
  Future<bool> hasLikedStory(String storyId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return false;

    final likeDoc = await _firestore
        .collection('stories')
        .doc(storyId)
        .collection('likes')
        .doc(currentUserId)
        .get();

    return likeDoc.exists;
  }

  /// Stream to watch like status for a story
  Stream<bool> watchStoryLikeStatus(String storyId) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return Stream.value(false);

    return _firestore
        .collection('stories')
        .doc(storyId)
        .collection('likes')
        .doc(currentUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Get list of users who liked a story
  Future<List<StoryLike>> getStoryLikes(String storyId) async {
    final snapshot = await _firestore
        .collection('stories')
        .doc(storyId)
        .collection('likes')
        .orderBy('likedAt', descending: true)
        .get();

    return snapshot.docs.map(StoryLike.fromFirestore).toList();
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  /// Get public profile for a user
  Future<PublicProfile?> getPublicProfile(String userId) async {
    final doc = await _firestore.collection('profiles').doc(userId).get();
    if (!doc.exists) return null;
    return PublicProfile.fromFirestore(doc);
  }
}
