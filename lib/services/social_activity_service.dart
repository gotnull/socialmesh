import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/social.dart';
import '../models/social_activity.dart';

/// Service for managing social activities and the activity feed.
///
/// Activities are stored per-user for efficient querying of "my activity feed".
class SocialActivityService {
  SocialActivityService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _currentUserId => _auth.currentUser?.uid;

  static const int _pageSize = 20;

  // ===========================================================================
  // ACTIVITY CREATION
  // ===========================================================================

  /// Create a new activity for a user's feed.
  ///
  /// This is typically called when:
  /// - Someone likes a story → notify story owner
  /// - Someone follows → notify followed user
  /// - Someone comments → notify post owner
  /// - etc.
  Future<void> createActivity({
    required SocialActivityType type,
    required String targetUserId,
    String? contentId,
    String? previewImageUrl,
    String? textContent,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    // Don't create activity for own actions
    if (currentUserId == targetUserId) return;

    try {
      // Get actor snapshot
      final actorSnapshot = await _getActorSnapshot(currentUserId);

      final activity = SocialActivity(
        id: '', // Will be set by Firestore
        type: type,
        actorId: currentUserId,
        actorSnapshot: actorSnapshot,
        targetUserId: targetUserId,
        contentId: contentId,
        previewImageUrl: previewImageUrl,
        textContent: textContent,
        createdAt: DateTime.now(),
      );

      // Store in target user's activity feed
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('activities')
          .add(activity.toFirestore());

      AppLogging.social(
        '📬 [ActivityService] Created ${type.name} activity for user $targetUserId',
      );
    } catch (e) {
      AppLogging.social('📬 [ActivityService] Error creating activity: $e');
    }
  }

  /// Create a story like activity
  Future<void> createStoryLikeActivity({
    required String storyId,
    required String storyOwnerId,
    String? storyThumbnailUrl,
  }) async {
    await createActivity(
      type: SocialActivityType.storyLike,
      targetUserId: storyOwnerId,
      contentId: storyId,
      previewImageUrl: storyThumbnailUrl,
    );
  }

  /// Create a follow activity
  Future<void> createFollowActivity({required String followedUserId}) async {
    await createActivity(
      type: SocialActivityType.follow,
      targetUserId: followedUserId,
    );
  }

  /// Create a post like activity
  Future<void> createPostLikeActivity({
    required String postId,
    required String postOwnerId,
    String? postThumbnailUrl,
  }) async {
    await createActivity(
      type: SocialActivityType.postLike,
      targetUserId: postOwnerId,
      contentId: postId,
      previewImageUrl: postThumbnailUrl,
    );
  }

  /// Create a comment activity
  Future<void> createCommentActivity({
    required String postId,
    required String postOwnerId,
    required String commentPreview,
  }) async {
    await createActivity(
      type: SocialActivityType.postComment,
      targetUserId: postOwnerId,
      contentId: postId,
      textContent: commentPreview,
    );
  }

  /// Create a comment reply activity (when someone replies to your comment)
  Future<void> createCommentReplyActivity({
    required String postId,
    required String originalCommentAuthorId,
    required String replyPreview,
  }) async {
    await createActivity(
      type: SocialActivityType.commentReply,
      targetUserId: originalCommentAuthorId,
      contentId: postId,
      textContent: replyPreview,
    );
  }

  /// Create a comment like activity
  Future<void> createCommentLikeActivity({
    required String postId,
    required String commentAuthorId,
  }) async {
    await createActivity(
      type: SocialActivityType.commentLike,
      targetUserId: commentAuthorId,
      contentId: postId,
    );
  }

  /// Create a follow request activity (for private accounts)
  Future<void> createFollowRequestActivity({
    required String targetUserId,
  }) async {
    await createActivity(
      type: SocialActivityType.followRequest,
      targetUserId: targetUserId,
    );
  }

  /// Create a mention activity
  Future<void> createMentionActivity({
    required String mentionedUserId,
    required String contentId,
    required String textContent,
    String? previewImageUrl,
  }) async {
    await createActivity(
      type: SocialActivityType.mention,
      targetUserId: mentionedUserId,
      contentId: contentId,
      textContent: textContent,
      previewImageUrl: previewImageUrl,
    );
  }

  // ===========================================================================
  // ACTIVITY RETRIEVAL
  // ===========================================================================

  /// Get paginated activities for the current user.
  Future<List<SocialActivity>> getActivities({
    DocumentSnapshot? startAfter,
    int limit = _pageSize,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return [];

    var query = _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map(SocialActivity.fromFirestore).toList();
  }

  /// Stream of activities for real-time updates.
  Stream<List<SocialActivity>> watchActivities({int limit = 50}) {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(SocialActivity.fromFirestore).toList(),
        );
  }

  /// Get count of unread activities.
  Stream<int> watchUnreadCount() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return Stream.value(0);

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ===========================================================================
  // ACTIVITY MANAGEMENT
  // ===========================================================================

  /// Mark all activities as read.
  Future<void> markAllAsRead() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    final unreadDocs = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in unreadDocs.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  /// Mark a specific activity as read.
  Future<void> markAsRead(String activityId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .doc(activityId)
        .update({'isRead': true});
  }

  /// Delete an activity.
  Future<void> deleteActivity(String activityId) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .doc(activityId)
        .delete();
  }

  /// Clear all activities.
  Future<void> clearAllActivities() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final batch = _firestore.batch();
    final allDocs = await _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .get();

    for (final doc in allDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  /// Get actor snapshot for the current user.
  Future<PostAuthorSnapshot?> _getActorSnapshot(String userId) async {
    try {
      final doc = await _firestore.collection('profiles').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return PostAuthorSnapshot(
        displayName: data['displayName'] as String? ?? 'User',
        avatarUrl: data['avatarUrl'] as String?,
        isVerified: data['isVerified'] as bool? ?? false,
      );
    } catch (e) {
      AppLogging.social('Error getting actor snapshot: $e');
      return null;
    }
  }
}
