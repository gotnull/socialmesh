// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:socialmesh/core/logging.dart';

import '../models/social.dart';
import '../models/social_activity.dart';

/// Service for managing social activities and the activity feed.
///
/// Activities are stored per-user for efficient querying of "my activity feed".
///
/// ## nodeNum baking
///
/// All activity creation methods accept an optional [actorNodeNum] parameter.
/// When provided, this value is baked into the [PostAuthorSnapshot.nodeNum]
/// field of the activity document, ensuring that activity tiles can render
/// a deterministic SigilAvatar without async cloud lookups.
///
/// Callers in the provider/UI layer have access to [myNodeNumProvider] and
/// should always pass the current node number when available. The Firestore
/// profile lookup in [_getActorSnapshot] is still performed for displayName,
/// avatarUrl, and isVerified, but the caller-provided nodeNum takes priority
/// over whatever the profile document contains.
class SocialActivityService {
  SocialActivityService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore,
      _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  /// Get Firestore instance, safely checking if Firebase is initialized.
  FirebaseFirestore? get _firestoreInstance {
    if (_firestore != null) return _firestore;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseFirestore.instance;
  }

  /// Get Auth instance, safely checking if Firebase is initialized.
  FirebaseAuth? get _authInstance {
    if (_auth != null) return _auth;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance;
  }

  String? get _currentUserId => _authInstance?.currentUser?.uid;

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
  ///
  /// [actorNodeNum] — the actor's mesh node number, if known by the caller.
  /// When provided, this value is baked into the activity's
  /// [PostAuthorSnapshot.nodeNum] so that activity tiles can render a
  /// deterministic SigilAvatar without relying on async cloud profile
  /// lookups. If the Firestore profile also contains a nodeNum, the
  /// caller-provided value takes priority (the caller is closer to the
  /// live mesh state).
  Future<void> createActivity({
    required SocialActivityType type,
    required String targetUserId,
    String? contentId,
    String? previewImageUrl,
    String? textContent,
    int? actorNodeNum,
  }) async {
    final currentUserId = _currentUserId;

    AppLogging.social(
      '📬 [ActivityService] createActivity START\n'
      '  type: ${type.name}\n'
      '  targetUserId: $targetUserId\n'
      '  contentId: $contentId\n'
      '  currentUserId: $currentUserId\n'
      '  actorNodeNum: $actorNodeNum\n'
      '  textContent: ${textContent?.substring(0, textContent.length.clamp(0, 50))}...',
    );

    if (currentUserId == null) {
      AppLogging.social(
        '📬 [ActivityService] SKIP: currentUserId is null (not authenticated)',
      );
      return;
    }

    // Don't create activity for own actions
    if (currentUserId == targetUserId) {
      AppLogging.social(
        '📬 [ActivityService] SKIP: actor == target (self-action)',
      );
      return;
    }

    try {
      // Get actor snapshot from Firestore (for displayName, avatarUrl, etc.)
      AppLogging.social(
        '📬 [ActivityService] Fetching actor snapshot for $currentUserId',
      );
      final actorSnapshot = await _getActorSnapshot(
        currentUserId,
        overrideNodeNum: actorNodeNum,
      );
      AppLogging.social(
        '📬 [ActivityService] Actor snapshot: '
        '${actorSnapshot?.displayName ?? 'null'}, '
        'nodeNum: ${actorSnapshot?.nodeNum}',
      );

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
      final docPath = 'users/$targetUserId/activities';
      AppLogging.social('📬 [ActivityService] Writing to Firestore: $docPath');

      final firestore = _firestoreInstance;
      if (firestore == null) {
        AppLogging.social(
          '📬 [ActivityService] SKIP: Firebase not initialized',
        );
        return;
      }

      final docRef = await firestore
          .collection('users')
          .doc(targetUserId)
          .collection('activities')
          .add(activity.toFirestore());

      AppLogging.social(
        '📬 [ActivityService] SUCCESS: Created ${type.name} activity\n'
        '  docId: ${docRef.id}\n'
        '  path: $docPath/${docRef.id}\n'
        '  targetUserId: $targetUserId\n'
        '  actorId: $currentUserId\n'
        '  bakedNodeNum: ${actorSnapshot?.nodeNum}',
      );
    } catch (e, stackTrace) {
      AppLogging.social(
        '📬 [ActivityService] ERROR creating activity:\n'
        '  error: $e\n'
        '  type: ${type.name}\n'
        '  targetUserId: $targetUserId\n'
        '  stackTrace: $stackTrace',
      );
    }
  }

  /// Create a story like activity
  Future<void> createStoryLikeActivity({
    required String storyId,
    required String storyOwnerId,
    String? storyThumbnailUrl,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.storyLike,
      targetUserId: storyOwnerId,
      contentId: storyId,
      previewImageUrl: storyThumbnailUrl,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a follow activity
  Future<void> createFollowActivity({
    required String followedUserId,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.follow,
      targetUserId: followedUserId,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a post like activity
  Future<void> createPostLikeActivity({
    required String postId,
    required String postOwnerId,
    String? postThumbnailUrl,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.postLike,
      targetUserId: postOwnerId,
      contentId: postId,
      previewImageUrl: postThumbnailUrl,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a signal like activity
  Future<void> createSignalLikeActivity({
    required String signalId,
    required String signalOwnerId,
    String? signalThumbnailUrl,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.signalLike,
      targetUserId: signalOwnerId,
      contentId: signalId,
      previewImageUrl: signalThumbnailUrl,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a signal comment activity (when someone comments on your signal)
  Future<void> createSignalCommentActivity({
    required String signalId,
    required String signalOwnerId,
    required String commentPreview,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.signalComment,
      targetUserId: signalOwnerId,
      contentId: signalId,
      textContent: commentPreview,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a signal comment reply activity (when someone replies to your
  /// comment on a signal)
  Future<void> createSignalCommentReplyActivity({
    required String signalId,
    required String originalCommentAuthorId,
    required String replyPreview,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.signalCommentReply,
      targetUserId: originalCommentAuthorId,
      contentId: signalId,
      textContent: replyPreview,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a signal response vote activity (when someone upvotes your
  /// response on a signal)
  Future<void> createSignalResponseVoteActivity({
    required String signalId,
    required String responseAuthorId,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.signalResponseVote,
      targetUserId: responseAuthorId,
      contentId: signalId,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a comment activity
  Future<void> createCommentActivity({
    required String postId,
    required String postOwnerId,
    required String commentPreview,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.postComment,
      targetUserId: postOwnerId,
      contentId: postId,
      textContent: commentPreview,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a comment reply activity (when someone replies to your comment)
  Future<void> createCommentReplyActivity({
    required String postId,
    required String originalCommentAuthorId,
    required String replyPreview,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.commentReply,
      targetUserId: originalCommentAuthorId,
      contentId: postId,
      textContent: replyPreview,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a comment like activity
  Future<void> createCommentLikeActivity({
    required String postId,
    required String commentAuthorId,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.commentLike,
      targetUserId: commentAuthorId,
      contentId: postId,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a follow request activity (for private accounts)
  Future<void> createFollowRequestActivity({
    required String targetUserId,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.followRequest,
      targetUserId: targetUserId,
      actorNodeNum: actorNodeNum,
    );
  }

  /// Create a mention activity
  Future<void> createMentionActivity({
    required String mentionedUserId,
    required String contentId,
    required String textContent,
    String? previewImageUrl,
    int? actorNodeNum,
  }) async {
    await createActivity(
      type: SocialActivityType.mention,
      targetUserId: mentionedUserId,
      contentId: contentId,
      textContent: textContent,
      previewImageUrl: previewImageUrl,
      actorNodeNum: actorNodeNum,
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

    final firestore = _firestoreInstance;
    if (firestore == null) return [];

    var query = firestore
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

    final firestore = _firestoreInstance;
    if (firestore == null) return Stream.value([]);

    return firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(SocialActivity.fromFirestore).toList(),
        )
        .handleError((Object e) {
          AppLogging.social('Activities stream error: $e');
        });
  }

  /// Get count of unread activities.
  Stream<int> watchUnreadCount() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return Stream.value(0);

    final firestore = _firestoreInstance;
    if (firestore == null) return Stream.value(0);

    return firestore
        .collection('users')
        .doc(currentUserId)
        .collection('activities')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((Object e) {
          AppLogging.social('Unread count stream error: $e');
        });
  }

  // ===========================================================================
  // ACTIVITY MANAGEMENT
  // ===========================================================================

  /// Mark all activities as read.
  Future<void> markAllAsRead() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    final firestore = _firestoreInstance;
    if (firestore == null) return;

    final batch = firestore.batch();
    final unreadDocs = await firestore
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

    final firestore = _firestoreInstance;
    if (firestore == null) return;

    await firestore
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

    final firestore = _firestoreInstance;
    if (firestore == null) return;

    await firestore
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

    final firestore = _firestoreInstance;
    if (firestore == null) return;

    final batch = firestore.batch();
    final allDocs = await firestore
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
  ///
  /// Reads the Firestore profile for displayName, avatarUrl, and isVerified.
  /// If [overrideNodeNum] is provided (from the caller who knows the live
  /// mesh state), it takes priority over whatever nodeNum exists in the
  /// profile document.
  Future<PostAuthorSnapshot?> _getActorSnapshot(
    String userId, {
    int? overrideNodeNum,
  }) async {
    try {
      final firestore = _firestoreInstance;
      if (firestore == null) {
        // Firebase not ready — if we have a nodeNum from the caller, return
        // a minimal snapshot so the activity still gets a baked nodeNum.
        if (overrideNodeNum != null) {
          return PostAuthorSnapshot(
            displayName: 'User',
            nodeNum: overrideNodeNum,
          );
        }
        return null;
      }

      final doc = await firestore.collection('profiles').doc(userId).get();
      if (!doc.exists) {
        // Profile not synced yet — if we have a nodeNum from the caller,
        // return a minimal snapshot with just the nodeNum baked in.
        if (overrideNodeNum != null) {
          return PostAuthorSnapshot(
            displayName: 'User',
            nodeNum: overrideNodeNum,
          );
        }
        return null;
      }

      final data = doc.data()!;
      // Caller-provided nodeNum takes priority over profile's primaryNodeId.
      // The caller (provider/UI layer) has direct access to the live mesh
      // state via myNodeNumProvider, which is more current than whatever
      // the profile document was last synced with.
      final resolvedNodeNum =
          overrideNodeNum ?? (data['primaryNodeId'] as int?);

      return PostAuthorSnapshot(
        displayName: data['displayName'] as String? ?? 'User',
        avatarUrl: data['avatarUrl'] as String?,
        isVerified: data['isVerified'] as bool? ?? false,
        nodeNum: resolvedNodeNum,
      );
    } catch (e) {
      AppLogging.social('Error getting actor snapshot: $e');
      // Even on error, if the caller provided a nodeNum, return a minimal
      // snapshot so the activity document has a baked nodeNum for rendering.
      if (overrideNodeNum != null) {
        return PostAuthorSnapshot(
          displayName: 'User',
          nodeNum: overrideNodeNum,
        );
      }
      return null;
    }
  }
}
