import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_profile.dart';

/// Post visibility options
enum PostVisibility {
  /// Visible to everyone
  public,

  /// Visible only to followers
  followersOnly,

  /// Visible only to the author
  private,
}

/// Follow request status for private accounts
enum FollowRequestStatus {
  /// Request is pending approval
  pending,

  /// Request was approved (becomes a follow)
  approved,

  /// Request was declined
  declined,
}

/// Represents a follow request for private accounts.
///
/// Document ID format: `{requesterId}_{targetId}` for idempotent operations.
/// Stored in `follow_requests/{requesterId}_{targetId}` collection.
class FollowRequest {
  /// Document ID (requesterId_targetId)
  final String id;

  /// The user who is requesting to follow
  final String requesterId;

  /// The user being requested to be followed
  final String targetId;

  /// Status of the request
  final FollowRequestStatus status;

  /// When the request was created
  final DateTime createdAt;

  /// When the request was responded to (approved/declined)
  final DateTime? respondedAt;

  const FollowRequest({
    required this.id,
    required this.requesterId,
    required this.targetId,
    this.status = FollowRequestStatus.pending,
    required this.createdAt,
    this.respondedAt,
  });

  /// Generate document ID for this follow request
  String get documentId => '${requesterId}_$targetId';

  factory FollowRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FollowRequest(
      id: doc.id,
      requesterId: data['requesterId'] as String,
      targetId: data['targetId'] as String,
      status: FollowRequestStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'pending'),
        orElse: () => FollowRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requesterId': requesterId,
      'targetId': targetId,
      'status': status.name,
      'createdAt': FieldValue.serverTimestamp(),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
    };
  }

  FollowRequest copyWith({
    String? id,
    String? requesterId,
    String? targetId,
    FollowRequestStatus? status,
    DateTime? createdAt,
    DateTime? respondedAt,
  }) {
    return FollowRequest(
      id: id ?? this.id,
      requesterId: requesterId ?? this.requesterId,
      targetId: targetId ?? this.targetId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FollowRequest &&
        other.requesterId == requesterId &&
        other.targetId == targetId;
  }

  @override
  int get hashCode => Object.hash(requesterId, targetId);

  @override
  String toString() =>
      'FollowRequest(requesterId: $requesterId, targetId: $targetId, status: $status)';
}

/// Follow request with requester profile information
class FollowRequestWithProfile {
  final FollowRequest request;
  final PublicProfile? profile;

  const FollowRequestWithProfile({required this.request, this.profile});
}

/// Represents a follow relationship between two users.
///
/// Document ID format: `{followerId}_{followeeId}` for idempotent operations.
/// Stored in `follows/{followerId}_{followeeId}` collection.
class Follow {
  /// Document ID (followerId_followeeId)
  final String id;

  /// The user who is following
  final String followerId;

  /// The user being followed
  final String followeeId;

  /// When the follow relationship was created
  final DateTime createdAt;

  const Follow({
    required this.id,
    required this.followerId,
    required this.followeeId,
    required this.createdAt,
  });

  /// Generate document ID for this follow relationship
  String get documentId => '${followerId}_$followeeId';

  factory Follow.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Follow(
      id: doc.id,
      followerId: data['followerId'] as String,
      followeeId: data['followeeId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'followerId': followerId,
      'followeeId': followeeId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Follow &&
        other.followerId == followerId &&
        other.followeeId == followeeId;
  }

  @override
  int get hashCode => Object.hash(followerId, followeeId);

  @override
  String toString() =>
      'Follow(followerId: $followerId, followeeId: $followeeId)';
}

/// Denormalized author snapshot for posts
class PostAuthorSnapshot {
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  const PostAuthorSnapshot({
    required this.displayName,
    this.avatarUrl,
    this.isVerified = false,
  });

  factory PostAuthorSnapshot.fromMap(Map<String, dynamic> map) {
    return PostAuthorSnapshot(
      displayName: map['displayName'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      isVerified: map['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'isVerified': isVerified,
    };
  }
}

/// Represents a user post in the social feed.
///
/// Posts are immutable except for deletion.
/// Stored in `posts/{postId}` collection.
class Post {
  /// Unique post identifier
  final String id;

  /// User ID of the post author
  final String authorId;

  /// Text content of the post
  final String content;

  /// Optional media URLs (images, etc.)
  final List<String> mediaUrls;

  /// Optional location data
  final PostLocation? location;

  /// Optional mesh node reference (as hex string)
  final String? nodeId;

  /// When the post was created
  final DateTime createdAt;

  /// Number of comments on this post (Cloud Function maintained)
  final int commentCount;

  /// Number of likes on this post (Cloud Function maintained)
  final int likeCount;

  /// Optional author snapshot (populated when fetching posts)
  final PostAuthorSnapshot? authorSnapshot;

  /// Convenience getter for image URLs (alias for mediaUrls)
  List<String> get imageUrls => mediaUrls;

  const Post({
    required this.id,
    required this.authorId,
    required this.content,
    this.mediaUrls = const [],
    this.location,
    this.nodeId,
    required this.createdAt,
    this.commentCount = 0,
    this.likeCount = 0,
    this.authorSnapshot,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] as String,
      content: data['content'] as String,
      mediaUrls:
          (data['mediaUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      location: data['location'] != null
          ? PostLocation.fromMap(data['location'] as Map<String, dynamic>)
          : null,
      nodeId: data['nodeId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commentCount: data['commentCount'] as int? ?? 0,
      likeCount: data['likeCount'] as int? ?? 0,
      authorSnapshot: data['authorSnapshot'] != null
          ? PostAuthorSnapshot.fromMap(
              data['authorSnapshot'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      'content': content,
      'mediaUrls': mediaUrls,
      if (location != null) 'location': location!.toMap(),
      if (nodeId != null) 'nodeId': nodeId,
      if (authorSnapshot != null) 'authorSnapshot': authorSnapshot!.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
      'commentCount': 0,
      'likeCount': 0,
    };
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? content,
    List<String>? mediaUrls,
    PostLocation? location,
    String? nodeId,
    DateTime? createdAt,
    int? commentCount,
    int? likeCount,
    PostAuthorSnapshot? authorSnapshot,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      location: location ?? this.location,
      nodeId: nodeId ?? this.nodeId,
      createdAt: createdAt ?? this.createdAt,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      authorSnapshot: authorSnapshot ?? this.authorSnapshot,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Post && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Post(id: $id, authorId: $authorId)';
}

/// Location data for a post
class PostLocation {
  final double latitude;
  final double longitude;
  final String? name;

  const PostLocation({
    required this.latitude,
    required this.longitude,
    this.name,
  });

  factory PostLocation.fromMap(Map<String, dynamic> map) {
    return PostLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (name != null) 'name': name,
    };
  }
}

/// A feed item represents a post in a user's personalized feed.
///
/// Feed items are denormalized copies of posts with author profile snapshot.
/// Stored in `feeds/{userId}/items/{postId}` subcollection.
class FeedItem {
  /// The original post ID
  final String postId;

  /// Post author's user ID
  final String authorId;

  /// Snapshot of author profile at time of fan-out
  final FeedAuthorSnapshot author;

  /// Post content
  final String content;

  /// Optional media URLs
  final List<String> mediaUrls;

  /// Optional location
  final PostLocation? location;

  /// Optional mesh node reference (as hex string)
  final String? nodeId;

  /// When the post was created
  final DateTime createdAt;

  /// Current comment count
  final int commentCount;

  /// Current like count
  final int likeCount;

  const FeedItem({
    required this.postId,
    required this.authorId,
    required this.author,
    required this.content,
    this.mediaUrls = const [],
    this.location,
    this.nodeId,
    required this.createdAt,
    this.commentCount = 0,
    this.likeCount = 0,
  });

  factory FeedItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FeedItem(
      postId: doc.id,
      authorId: data['authorId'] as String,
      author: FeedAuthorSnapshot.fromMap(
        data['author'] as Map<String, dynamic>,
      ),
      content: data['content'] as String,
      mediaUrls:
          (data['mediaUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      location: data['location'] != null
          ? PostLocation.fromMap(data['location'] as Map<String, dynamic>)
          : null,
      nodeId: data['nodeId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commentCount: data['commentCount'] as int? ?? 0,
      likeCount: data['likeCount'] as int? ?? 0,
    );
  }

  /// Convenience getter for image URLs (alias for mediaUrls)
  List<String> get imageUrls => mediaUrls;

  /// Get the author snapshot for display
  FeedAuthorSnapshot get authorSnapshot => author;

  /// Convert FeedItem to a Post object
  Post toPost() {
    return Post(
      id: postId,
      authorId: authorId,
      content: content,
      mediaUrls: mediaUrls,
      location: location,
      nodeId: nodeId,
      createdAt: createdAt,
      commentCount: commentCount,
      likeCount: likeCount,
      authorSnapshot: PostAuthorSnapshot(
        displayName: author.displayName,
        avatarUrl: author.avatarUrl,
        isVerified: author.isVerified,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FeedItem && other.postId == postId;
  }

  @override
  int get hashCode => postId.hashCode;

  @override
  String toString() => 'FeedItem(postId: $postId, authorId: $authorId)';
}

/// Denormalized author snapshot for feed items
class FeedAuthorSnapshot {
  final String displayName;
  final String? avatarUrl;
  final String? callsign;
  final bool isVerified;

  const FeedAuthorSnapshot({
    required this.displayName,
    this.avatarUrl,
    this.callsign,
    this.isVerified = false,
  });

  factory FeedAuthorSnapshot.fromMap(Map<String, dynamic> map) {
    return FeedAuthorSnapshot(
      displayName: map['displayName'] as String,
      avatarUrl: map['avatarUrl'] as String?,
      callsign: map['callsign'] as String?,
      isVerified: map['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (callsign != null) 'callsign': callsign,
      'isVerified': isVerified,
    };
  }
}

/// Represents a comment on a post.
///
/// Comments support threading via parentId.
/// Stored in `comments/{commentId}` collection.
class Comment {
  /// Unique comment identifier
  final String id;

  /// The post this comment belongs to
  final String postId;

  /// User ID of the comment author
  final String authorId;

  /// Parent comment ID for threading (null for root comments)
  final String? parentId;

  /// Text content of the comment
  final String content;

  /// When the comment was created
  final DateTime createdAt;

  /// Number of replies to this comment (Cloud Function maintained)
  final int replyCount;

  /// Number of likes on this comment (Cloud Function maintained)
  final int likeCount;

  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    this.parentId,
    required this.content,
    required this.createdAt,
    this.replyCount = 0,
    this.likeCount = 0,
  });

  /// Whether this is a root-level comment (not a reply)
  bool get isRootComment => parentId == null;

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: data['postId'] as String,
      authorId: data['authorId'] as String,
      parentId: data['parentId'] as String?,
      content: data['content'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyCount: data['replyCount'] as int? ?? 0,
      likeCount: data['likeCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'authorId': authorId,
      'parentId': parentId,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
      'replyCount': 0,
      'likeCount': 0,
    };
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? parentId,
    String? content,
    DateTime? createdAt,
    int? replyCount,
    int? likeCount,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      parentId: parentId ?? this.parentId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Comment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Comment(id: $id, postId: $postId, parentId: $parentId)';
}

/// Represents a like on a post.
///
/// Document ID format: `{userId}_{postId}` for idempotent operations.
/// Stored in `likes/{userId}_{postId}` collection.
class Like {
  /// Document ID (userId_postId)
  final String id;

  /// The user who liked the post
  final String userId;

  /// The post that was liked
  final String postId;

  /// When the like was created
  final DateTime createdAt;

  const Like({
    required this.id,
    required this.userId,
    required this.postId,
    required this.createdAt,
  });

  /// Generate document ID for this like
  String get documentId => '${userId}_$postId';

  factory Like.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Like(
      id: doc.id,
      userId: data['userId'] as String,
      postId: data['postId'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'postId': postId,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Like && other.userId == userId && other.postId == postId;
  }

  @override
  int get hashCode => Object.hash(userId, postId);

  @override
  String toString() => 'Like(userId: $userId, postId: $postId)';
}

/// Cached metadata for a linked mesh node.
///
/// Stored in profile's `linkedNodeMetadata` map to ensure node info
/// is available even when the device isn't actively connected to the mesh.
class LinkedNodeInfo {
  final int nodeId;
  final String? longName;
  final String? shortName;
  final int? avatarColor;

  const LinkedNodeInfo({
    required this.nodeId,
    this.longName,
    this.shortName,
    this.avatarColor,
  });

  factory LinkedNodeInfo.fromJson(Map<String, dynamic> json) {
    return LinkedNodeInfo(
      nodeId: json['nodeId'] as int,
      longName: json['longName'] as String?,
      shortName: json['shortName'] as String?,
      avatarColor: json['avatarColor'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'nodeId': nodeId,
    if (longName != null) 'longName': longName,
    if (shortName != null) 'shortName': shortName,
    if (avatarColor != null) 'avatarColor': avatarColor,
  };

  /// Get the display name (long name or short name or hex ID)
  String get displayName =>
      longName ?? shortName ?? '!${nodeId.toRadixString(16)}';

  /// Get the avatar name (short name first character or hex ID first character)
  String get avatarName {
    if (shortName != null && shortName!.isNotEmpty) {
      return shortName!;
    }
    if (longName != null && longName!.isNotEmpty) {
      return longName![0].toUpperCase();
    }
    return nodeId.toRadixString(16)[0].toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkedNodeInfo &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId;

  @override
  int get hashCode => nodeId.hashCode;
}

/// Public profile data for social features.
///
/// This is the denormalized public view of a user profile.
/// Stored in `profiles/{userId}` collection.
class PublicProfile {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bannerUrl;
  final String? bio;
  final String? callsign;
  final String? website;
  final ProfileSocialLinks? socialLinks;
  final int? primaryNodeId;
  final List<int> linkedNodeIds;
  final Map<int, LinkedNodeInfo> linkedNodeMetadata;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final bool isVerified;
  final bool isPrivate;
  final DateTime? createdAt;

  const PublicProfile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.callsign,
    this.website,
    this.socialLinks,
    this.primaryNodeId,
    this.linkedNodeIds = const [],
    this.linkedNodeMetadata = const {},
    this.followerCount = 0,
    this.followingCount = 0,
    this.postCount = 0,
    this.isVerified = false,
    this.isPrivate = false,
    this.createdAt,
  });

  factory PublicProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Parse linkedNodeMetadata map
    final metadataMap = <int, LinkedNodeInfo>{};
    final rawMetadata = data['linkedNodeMetadata'] as Map<String, dynamic>?;
    if (rawMetadata != null) {
      for (final entry in rawMetadata.entries) {
        final nodeId = int.tryParse(entry.key);
        if (nodeId != null && entry.value is Map<String, dynamic>) {
          metadataMap[nodeId] = LinkedNodeInfo.fromJson(
            entry.value as Map<String, dynamic>,
          );
        }
      }
    }

    return PublicProfile(
      id: doc.id,
      displayName: data['displayName'] as String? ?? 'Unknown',
      avatarUrl: data['avatarUrl'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      bio: data['bio'] as String?,
      callsign: data['callsign'] as String?,
      website: data['website'] as String?,
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
      linkedNodeMetadata: metadataMap,
      followerCount: data['followerCount'] as int? ?? 0,
      followingCount: data['followingCount'] as int? ?? 0,
      postCount: data['postCount'] as int? ?? 0,
      isVerified: data['isVerified'] as bool? ?? false,
      isPrivate: data['isPrivate'] as bool? ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Check if this profile has a specific node linked
  bool hasNodeLinked(int nodeId) => linkedNodeIds.contains(nodeId);

  /// Get cached node info for a linked node (if available)
  LinkedNodeInfo? getLinkedNodeInfo(int nodeId) => linkedNodeMetadata[nodeId];

  /// Convert to FeedAuthorSnapshot for embedding in feed items
  FeedAuthorSnapshot toAuthorSnapshot() {
    return FeedAuthorSnapshot(
      displayName: displayName,
      avatarUrl: avatarUrl,
      callsign: callsign,
      isVerified: isVerified,
    );
  }

  /// Create a copy with updated fields
  PublicProfile copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    String? callsign,
    String? website,
    ProfileSocialLinks? socialLinks,
    int? primaryNodeId,
    List<int>? linkedNodeIds,
    Map<int, LinkedNodeInfo>? linkedNodeMetadata,
    int? followerCount,
    int? followingCount,
    int? postCount,
    bool? isVerified,
    bool? isPrivate,
    DateTime? createdAt,
  }) {
    return PublicProfile(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      callsign: callsign ?? this.callsign,
      website: website ?? this.website,
      socialLinks: socialLinks ?? this.socialLinks,
      primaryNodeId: primaryNodeId ?? this.primaryNodeId,
      linkedNodeIds: linkedNodeIds ?? this.linkedNodeIds,
      linkedNodeMetadata: linkedNodeMetadata ?? this.linkedNodeMetadata,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      postCount: postCount ?? this.postCount,
      isVerified: isVerified ?? this.isVerified,
      isPrivate: isPrivate ?? this.isPrivate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublicProfile && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PublicProfile(id: $id, displayName: $displayName)';
}
