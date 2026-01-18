import 'package:cloud_firestore/cloud_firestore.dart';

import 'social.dart';

/// Types of social activities that appear in the activity feed.
enum SocialActivityType {
  /// Someone liked your story
  storyLike,

  /// Someone viewed your story
  storyView,

  /// Someone started following you
  follow,

  /// Someone requested to follow you (private account)
  followRequest,

  /// Someone liked your post
  postLike,

  /// Someone liked your signal
  signalLike,

  /// Someone commented on your post
  postComment,

  /// Someone mentioned you in a post or comment
  mention,

  /// Someone replied to your comment
  commentReply,

  /// Someone liked your comment
  commentLike,
}

/// A single activity item in the activity feed.
///
/// Stored in `users/{userId}/activities/{activityId}` collection.
class SocialActivity {
  /// Unique activity ID
  final String id;

  /// Type of activity
  final SocialActivityType type;

  /// User who performed the action (actor)
  final String actorId;

  /// Snapshot of actor's profile for display
  final PostAuthorSnapshot? actorSnapshot;

  /// Target user (usually the recipient of the activity)
  final String targetUserId;

  /// Reference to related content (story ID, post ID, etc.)
  final String? contentId;

  /// Optional preview image URL (e.g., story thumbnail)
  final String? previewImageUrl;

  /// Optional text content (e.g., comment preview)
  final String? textContent;

  /// When the activity occurred
  final DateTime createdAt;

  /// Whether the activity has been read/seen
  final bool isRead;

  const SocialActivity({
    required this.id,
    required this.type,
    required this.actorId,
    this.actorSnapshot,
    required this.targetUserId,
    this.contentId,
    this.previewImageUrl,
    this.textContent,
    required this.createdAt,
    this.isRead = false,
  });

  /// Human-readable description of the activity
  String get description {
    final actorName = actorSnapshot?.displayName ?? 'Someone';
    switch (type) {
      case SocialActivityType.storyLike:
        return '$actorName liked your story';
      case SocialActivityType.storyView:
        return '$actorName viewed your story';
      case SocialActivityType.follow:
        return '$actorName started following you';
      case SocialActivityType.followRequest:
        return '$actorName requested to follow you';
      case SocialActivityType.postLike:
        return '$actorName liked your post';
      case SocialActivityType.signalLike:
        return '$actorName liked your signal';
      case SocialActivityType.postComment:
        return '$actorName commented on your post';
      case SocialActivityType.mention:
        return '$actorName mentioned you';
      case SocialActivityType.commentReply:
        return '$actorName replied to your comment';
      case SocialActivityType.commentLike:
        return '$actorName liked your comment';
    }
  }

  /// Icon for the activity type
  String get iconName {
    switch (type) {
      case SocialActivityType.storyLike:
      case SocialActivityType.postLike:
      case SocialActivityType.signalLike:
      case SocialActivityType.commentLike:
        return 'favorite';
      case SocialActivityType.storyView:
        return 'visibility';
      case SocialActivityType.follow:
      case SocialActivityType.followRequest:
        return 'person_add';
      case SocialActivityType.postComment:
      case SocialActivityType.commentReply:
        return 'chat_bubble';
      case SocialActivityType.mention:
        return 'alternate_email';
    }
  }

  factory SocialActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SocialActivity(
      id: doc.id,
      type: SocialActivityType.values.firstWhere(
        (e) => e.name == (data['type'] as String? ?? 'follow'),
        orElse: () => SocialActivityType.follow,
      ),
      actorId: data['actorId'] as String,
      actorSnapshot: data['actorSnapshot'] != null
          ? PostAuthorSnapshot.fromMap(
              data['actorSnapshot'] as Map<String, dynamic>,
            )
          : null,
      targetUserId: data['targetUserId'] as String,
      contentId: data['contentId'] as String?,
      previewImageUrl: data['previewImageUrl'] as String?,
      textContent: data['textContent'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type.name,
      'actorId': actorId,
      if (actorSnapshot != null) 'actorSnapshot': actorSnapshot!.toMap(),
      'targetUserId': targetUserId,
      if (contentId != null) 'contentId': contentId,
      if (previewImageUrl != null) 'previewImageUrl': previewImageUrl,
      if (textContent != null) 'textContent': textContent,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': isRead,
    };
  }

  SocialActivity copyWith({
    String? id,
    SocialActivityType? type,
    String? actorId,
    PostAuthorSnapshot? actorSnapshot,
    String? targetUserId,
    String? contentId,
    String? previewImageUrl,
    String? textContent,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return SocialActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      actorId: actorId ?? this.actorId,
      actorSnapshot: actorSnapshot ?? this.actorSnapshot,
      targetUserId: targetUserId ?? this.targetUserId,
      contentId: contentId ?? this.contentId,
      previewImageUrl: previewImageUrl ?? this.previewImageUrl,
      textContent: textContent ?? this.textContent,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SocialActivity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// State for the activity feed
class ActivityFeedState {
  final List<SocialActivity> activities;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int unreadCount;

  const ActivityFeedState({
    this.activities = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.unreadCount = 0,
  });

  ActivityFeedState copyWith({
    List<SocialActivity>? activities,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? unreadCount,
  }) {
    return ActivityFeedState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
