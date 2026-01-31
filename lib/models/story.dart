// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';

import 'social.dart';

/// Type of media in a story
enum StoryMediaType { image, video }

/// Visibility options for stories
enum StoryVisibility {
  /// Visible to everyone
  public,

  /// Visible only to followers
  followersOnly,

  /// Visible only to close friends
  closeFriends,
}

/// Text overlay on a story
class TextOverlay {
  /// The text content
  final String text;

  /// X position as percentage (0.0 - 1.0)
  final double x;

  /// Y position as percentage (0.0 - 1.0)
  final double y;

  /// Font size in pixels
  final double fontSize;

  /// Color as hex string (e.g., '#FFFFFF')
  final String color;

  /// Optional font family name
  final String? fontFamily;

  /// Text alignment
  final String alignment;

  /// Background color (optional, for text box style)
  final String? backgroundColor;

  const TextOverlay({
    required this.text,
    required this.x,
    required this.y,
    this.fontSize = 24,
    this.color = '#FFFFFF',
    this.fontFamily,
    this.alignment = 'center',
    this.backgroundColor,
  });

  factory TextOverlay.fromMap(Map<String, dynamic> map) {
    return TextOverlay(
      text: map['text'] as String,
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 24,
      color: map['color'] as String? ?? '#FFFFFF',
      fontFamily: map['fontFamily'] as String?,
      alignment: map['alignment'] as String? ?? 'center',
      backgroundColor: map['backgroundColor'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'color': color,
      if (fontFamily != null) 'fontFamily': fontFamily,
      'alignment': alignment,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
    };
  }

  TextOverlay copyWith({
    String? text,
    double? x,
    double? y,
    double? fontSize,
    String? color,
    String? fontFamily,
    String? alignment,
    String? backgroundColor,
  }) {
    return TextOverlay(
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      fontFamily: fontFamily ?? this.fontFamily,
      alignment: alignment ?? this.alignment,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}

/// Represents an ephemeral story that expires after 24 hours.
///
/// Stored in `stories/{storyId}` collection.
class Story {
  /// Unique story identifier
  final String id;

  /// User ID of the story author
  final String authorId;

  /// Denormalized author info for display
  final PostAuthorSnapshot? authorSnapshot;

  /// URL to the media file in Firebase Storage
  final String mediaUrl;

  /// Type of media (image or video)
  final StoryMediaType mediaType;

  /// Thumbnail URL for videos
  final String? thumbnailUrl;

  /// Duration to show the story in seconds (default 5 for images)
  final int duration;

  /// When the story was created
  final DateTime createdAt;

  /// When the story expires (24 hours after creation)
  final DateTime expiresAt;

  /// Total view count
  final int viewCount;

  /// Total like/favorite count
  final int likeCount;

  /// Optional location data
  final PostLocation? location;

  /// Optional mesh node reference (as hex string)
  final String? nodeId;

  /// User IDs mentioned in the story
  final List<String> mentions;

  /// Hashtags in the story
  final List<String> hashtags;

  /// Optional text overlay
  final TextOverlay? textOverlay;

  /// Visibility setting
  final StoryVisibility visibility;

  const Story({
    required this.id,
    required this.authorId,
    this.authorSnapshot,
    required this.mediaUrl,
    this.mediaType = StoryMediaType.image,
    this.thumbnailUrl,
    this.duration = 5,
    required this.createdAt,
    required this.expiresAt,
    this.viewCount = 0,
    this.likeCount = 0,
    this.location,
    this.nodeId,
    this.mentions = const [],
    this.hashtags = const [],
    this.textOverlay,
    this.visibility = StoryVisibility.public,
  });

  /// Whether the story has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Whether this is a video story
  bool get isVideo => mediaType == StoryMediaType.video;

  /// Time remaining until expiry
  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  factory Story.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Story(
      id: doc.id,
      authorId: data['authorId'] as String,
      authorSnapshot: data['authorSnapshot'] != null
          ? PostAuthorSnapshot.fromMap(
              data['authorSnapshot'] as Map<String, dynamic>,
            )
          : null,
      mediaUrl: data['mediaUrl'] as String,
      mediaType: StoryMediaType.values.firstWhere(
        (e) => e.name == (data['mediaType'] as String? ?? 'image'),
        orElse: () => StoryMediaType.image,
      ),
      thumbnailUrl: data['thumbnailUrl'] as String?,
      duration: data['duration'] as int? ?? 5,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 24)),
      viewCount: data['viewCount'] as int? ?? 0,
      likeCount: data['likeCount'] as int? ?? 0,
      location: data['location'] != null
          ? PostLocation.fromMap(data['location'] as Map<String, dynamic>)
          : null,
      nodeId: data['nodeId'] as String?,
      mentions:
          (data['mentions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      hashtags:
          (data['hashtags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      textOverlay: data['textOverlay'] != null
          ? TextOverlay.fromMap(data['textOverlay'] as Map<String, dynamic>)
          : null,
      visibility: StoryVisibility.values.firstWhere(
        (e) => e.name == (data['visibility'] as String? ?? 'public'),
        orElse: () => StoryVisibility.public,
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'authorId': authorId,
      if (authorSnapshot != null) 'authorSnapshot': authorSnapshot!.toMap(),
      'mediaUrl': mediaUrl,
      'mediaType': mediaType.name,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewCount': 0,
      'likeCount': 0,
      if (location != null) 'location': location!.toMap(),
      if (nodeId != null) 'nodeId': nodeId,
      'mentions': mentions,
      'hashtags': hashtags,
      if (textOverlay != null) 'textOverlay': textOverlay!.toMap(),
      'visibility': visibility.name,
    };
  }

  Story copyWith({
    String? id,
    String? authorId,
    PostAuthorSnapshot? authorSnapshot,
    String? mediaUrl,
    StoryMediaType? mediaType,
    String? thumbnailUrl,
    int? duration,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? viewCount,
    int? likeCount,
    PostLocation? location,
    String? nodeId,
    List<String>? mentions,
    List<String>? hashtags,
    TextOverlay? textOverlay,
    StoryVisibility? visibility,
  }) {
    return Story(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorSnapshot: authorSnapshot ?? this.authorSnapshot,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      location: location ?? this.location,
      nodeId: nodeId ?? this.nodeId,
      mentions: mentions ?? this.mentions,
      hashtags: hashtags ?? this.hashtags,
      textOverlay: textOverlay ?? this.textOverlay,
      visibility: visibility ?? this.visibility,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Story && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Story(id: $id, authorId: $authorId, mediaType: $mediaType)';
}

/// A record of a user viewing a story
class StoryView {
  /// The user who viewed
  final String viewerId;

  /// When they viewed
  final DateTime viewedAt;

  const StoryView({required this.viewerId, required this.viewedAt});

  factory StoryView.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryView(
      viewerId: data['userId'] as String? ?? doc.id,
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'userId': viewerId, 'viewedAt': FieldValue.serverTimestamp()};
  }
}

/// A record of a user liking a story
class StoryLike {
  /// The user who liked
  final String likerId;

  /// When they liked
  final DateTime likedAt;

  const StoryLike({required this.likerId, required this.likedAt});

  factory StoryLike.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StoryLike(
      likerId: data['userId'] as String? ?? doc.id,
      likedAt: (data['likedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {'userId': likerId, 'likedAt': FieldValue.serverTimestamp()};
  }
}

/// A group of stories from a single user
class StoryGroup {
  /// The user ID
  final String userId;

  /// User's profile (for display)
  final PostAuthorSnapshot? profile;

  /// All active stories from this user, sorted by creation time
  final List<Story> stories;

  /// Whether there are any unviewed stories
  final bool hasUnviewed;

  /// Most recent story timestamp
  final DateTime lastStoryAt;

  const StoryGroup({
    required this.userId,
    this.profile,
    required this.stories,
    this.hasUnviewed = false,
    required this.lastStoryAt,
  });

  /// Get the first unviewed story, or the first story if all viewed
  Story? get currentStory {
    if (stories.isEmpty) return null;
    return stories.first;
  }

  /// Number of stories in this group
  int get storyCount => stories.length;

  StoryGroup copyWith({
    String? userId,
    PostAuthorSnapshot? profile,
    List<Story>? stories,
    bool? hasUnviewed,
    DateTime? lastStoryAt,
  }) {
    return StoryGroup(
      userId: userId ?? this.userId,
      profile: profile ?? this.profile,
      stories: stories ?? this.stories,
      hasUnviewed: hasUnviewed ?? this.hasUnviewed,
      lastStoryAt: lastStoryAt ?? this.lastStoryAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoryGroup && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}

/// State for tracking which stories the current user has viewed
class ViewedStoriesState {
  /// Map of storyId to viewedAt timestamp
  final Map<String, DateTime> viewedStories;

  const ViewedStoriesState({this.viewedStories = const {}});

  /// Check if a story has been viewed
  bool hasViewed(String storyId) => viewedStories.containsKey(storyId);

  /// Mark a story as viewed
  ViewedStoriesState markViewed(String storyId) {
    return ViewedStoriesState(
      viewedStories: {...viewedStories, storyId: DateTime.now()},
    );
  }
}
