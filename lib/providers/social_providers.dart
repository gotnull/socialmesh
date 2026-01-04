import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social.dart';
import '../services/social_service.dart';
import 'auth_providers.dart';
import 'profile_providers.dart';

// ===========================================================================
// SERVICE PROVIDER
// ===========================================================================

/// Provider for the SocialService singleton.
final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService();
});

// ===========================================================================
// FOLLOW STATE
// ===========================================================================

/// State for tracking follow status between current user and a target.
class FollowState {
  const FollowState({
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.isLoading = false,
    this.error,
  });

  final bool isFollowing;
  final bool isFollowedBy;
  final bool isLoading;
  final String? error;

  bool get isMutual => isFollowing && isFollowedBy;

  FollowState copyWith({
    bool? isFollowing,
    bool? isFollowedBy,
    bool? isLoading,
    String? error,
  }) {
    return FollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Provider for follow state with a specific user.
/// Use AutoDisposeFutureProvider for simple async loading, combined with
/// a notifier for actions.
final followStateProvider = FutureProvider.autoDispose
    .family<FollowState, String>((ref, targetUserId) async {
      final service = ref.watch(socialServiceProvider);
      final isFollowing = await service.isFollowing(targetUserId);
      final isFollowedBy = await service.isFollowedBy(targetUserId);
      return FollowState(isFollowing: isFollowing, isFollowedBy: isFollowedBy);
    });

/// Helper to toggle follow status (call this and then invalidate provider)
Future<void> toggleFollow(WidgetRef ref, String targetUserId) async {
  final service = ref.read(socialServiceProvider);
  final currentState = await ref.read(followStateProvider(targetUserId).future);

  if (currentState.isFollowing) {
    await service.unfollowUser(targetUserId);
  } else {
    await service.followUser(targetUserId);
  }

  // Invalidate to refresh
  ref.invalidate(followStateProvider(targetUserId));
}

// ===========================================================================
// PROFILE BY NODE ID & LINKED NODES
// ===========================================================================

/// Provider to find a user's public profile by their linked mesh node ID.
/// Returns null if no user has this node in their linkedNodeIds.
final profileByNodeIdProvider = FutureProvider.autoDispose
    .family<PublicProfile?, int>((ref, nodeId) async {
      final service = ref.watch(socialServiceProvider);
      return service.getProfileByNodeId(nodeId);
    });

/// Provider for current user's linked node IDs with real-time updates.
/// Uses local profile data as fallback when Firestore is unavailable.
final linkedNodeIdsProvider = StreamProvider.autoDispose<List<int>>((ref) {
  final service = ref.watch(socialServiceProvider);
  try {
    return service.watchLinkedNodeIds();
  } catch (e) {
    // Fallback to local profile if Firestore is unavailable
    final localProfile = ref.read(userProfileProvider).value;
    return Stream.value(localProfile?.linkedNodeIds ?? []);
  }
});

/// Provider to check if a specific node is linked to current user's profile.
/// Now watches the linkedNodeIds stream for real-time updates.
final isNodeLinkedProvider = StreamProvider.autoDispose.family<bool, int>((
  ref,
  nodeId,
) {
  final service = ref.watch(socialServiceProvider);
  return service.watchLinkedNodeIds().map(
    (linkedNodes) => linkedNodes.contains(nodeId),
  );
});

/// Link a node to current user's profile
Future<void> linkNode(
  WidgetRef ref,
  int nodeId, {
  bool setPrimary = false,
}) async {
  final service = ref.read(socialServiceProvider);
  await service.linkNodeToProfile(nodeId, setPrimary: setPrimary);

  // Update local profile storage to persist linked nodes across app restarts
  final userProfileNotifier = ref.read(userProfileProvider.notifier);
  final currentProfile = ref.read(userProfileProvider).value;
  if (currentProfile != null) {
    final updatedLinkedNodes = [...currentProfile.linkedNodeIds];
    if (!updatedLinkedNodes.contains(nodeId)) {
      updatedLinkedNodes.add(nodeId);
    }
    await userProfileNotifier.updateLinkedNodes(
      updatedLinkedNodes,
      primaryNodeId: setPrimary || updatedLinkedNodes.length == 1
          ? nodeId
          : currentProfile.primaryNodeId,
    );
  }

  // Invalidate providers to refresh state
  ref.invalidate(linkedNodeIdsProvider);
  ref.invalidate(isNodeLinkedProvider(nodeId));
  ref.invalidate(profileByNodeIdProvider(nodeId));
  // Also invalidate the user's public profile so UI updates
  final currentUser = ref.read(currentUserProvider);
  if (currentUser != null) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
  }
}

/// Unlink a node from current user's profile
Future<void> unlinkNode(WidgetRef ref, int nodeId) async {
  final service = ref.read(socialServiceProvider);
  await service.unlinkNodeFromProfile(nodeId);

  // Update local profile storage to persist linked nodes across app restarts
  final userProfileNotifier = ref.read(userProfileProvider.notifier);
  final currentProfile = ref.read(userProfileProvider).value;
  if (currentProfile != null) {
    final updatedLinkedNodes = [...currentProfile.linkedNodeIds]
      ..remove(nodeId);
    final newPrimaryId = currentProfile.primaryNodeId == nodeId
        ? (updatedLinkedNodes.isNotEmpty ? updatedLinkedNodes.first : null)
        : currentProfile.primaryNodeId;
    await userProfileNotifier.updateLinkedNodes(
      updatedLinkedNodes,
      primaryNodeId: newPrimaryId,
      clearPrimaryNodeId: newPrimaryId == null,
    );
  }

  // Invalidate providers to refresh state
  ref.invalidate(linkedNodeIdsProvider);
  ref.invalidate(isNodeLinkedProvider(nodeId));
  ref.invalidate(profileByNodeIdProvider(nodeId));
  // Also invalidate the user's public profile so UI updates
  final currentUser = ref.read(currentUserProvider);
  if (currentUser != null) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
  }
}

/// Set a linked node as the primary node
Future<void> setPrimaryNode(WidgetRef ref, int nodeId) async {
  final service = ref.read(socialServiceProvider);
  await service.setPrimaryNode(nodeId);

  // Update local profile storage to persist primary node across app restarts
  final userProfileNotifier = ref.read(userProfileProvider.notifier);
  final currentProfile = ref.read(userProfileProvider).value;
  if (currentProfile != null) {
    await userProfileNotifier.updateLinkedNodes(
      currentProfile.linkedNodeIds,
      primaryNodeId: nodeId,
    );
  }

  // Invalidate providers to refresh state
  ref.invalidate(linkedNodeIdsProvider);
  // Also invalidate the user's public profile so UI updates
  final currentUser = ref.read(currentUserProvider);
  if (currentUser != null) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
  }
}

// ===========================================================================
// FOLLOWERS/FOLLOWING LISTS
// ===========================================================================

/// State for paginated followers list.
class FollowersState {
  const FollowersState({
    this.followers = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.lastId,
    this.error,
  });

  final List<FollowWithProfile> followers;
  final bool hasMore;
  final bool isLoading;
  final String? lastId;
  final String? error;

  FollowersState copyWith({
    List<FollowWithProfile>? followers,
    bool? hasMore,
    bool? isLoading,
    String? lastId,
    String? error,
  }) {
    return FollowersState(
      followers: followers ?? this.followers,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      lastId: lastId ?? this.lastId,
      error: error,
    );
  }
}

/// Provider for paginated followers.
final followersProvider = FutureProvider.autoDispose
    .family<PaginatedResult<FollowWithProfile>, String>((ref, userId) async {
      final service = ref.watch(socialServiceProvider);
      return service.getFollowers(userId);
    });

/// State for paginated following list.
class FollowingState {
  const FollowingState({
    this.following = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.lastId,
    this.error,
  });

  final List<FollowWithProfile> following;
  final bool hasMore;
  final bool isLoading;
  final String? lastId;
  final String? error;

  FollowingState copyWith({
    List<FollowWithProfile>? following,
    bool? hasMore,
    bool? isLoading,
    String? lastId,
    String? error,
  }) {
    return FollowingState(
      following: following ?? this.following,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      lastId: lastId ?? this.lastId,
      error: error,
    );
  }
}

/// Provider for paginated following.
final followingProvider = FutureProvider.autoDispose
    .family<PaginatedResult<FollowWithProfile>, String>((ref, userId) async {
      final service = ref.watch(socialServiceProvider);
      return service.getFollowing(userId);
    });

// ===========================================================================
// FEED
// ===========================================================================

/// State for the current user's feed.
class FeedState {
  const FeedState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.lastTimestamp,
    this.error,
  });

  final List<FeedItem> items;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final DateTime? lastTimestamp;
  final String? error;

  FeedState copyWith({
    List<FeedItem>? items,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    DateTime? lastTimestamp,
    String? error,
  }) {
    return FeedState(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      error: error,
    );
  }
}

/// Notifier for managing the current user's feed.
class FeedNotifier extends Notifier<FeedState> {
  StreamSubscription<List<FeedItem>>? _subscription;

  @override
  FeedState build() {
    ref.onDispose(() => _subscription?.cancel());
    _startWatching();
    return const FeedState(isLoading: true);
  }

  void _startWatching() {
    final service = ref.read(socialServiceProvider);
    _subscription?.cancel();
    _subscription = service
        .watchFeed(limit: 20)
        .listen(
          (items) {
            state = FeedState(
              items: items,
              hasMore: items.length >= 20,
              lastTimestamp: items.lastOrNull?.createdAt,
            );
          },
          onError: (e) {
            state = FeedState(error: e.toString());
          },
        );
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    final service = ref.read(socialServiceProvider);
    try {
      final result = await service.getFeed(startAfter: state.lastTimestamp);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        lastTimestamp: result.lastTimestamp,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, error: null);
    _startWatching();
  }

  /// Optimistically remove a post from the feed (before server confirms deletion)
  void removePost(String postId) {
    state = state.copyWith(
      items: state.items.where((item) => item.postId != postId).toList(),
    );
  }
}

/// Provider for the current user's feed.
final feedProvider = NotifierProvider<FeedNotifier, FeedState>(
  FeedNotifier.new,
);

// ===========================================================================
// EXPLORE FEED (ALL PUBLIC POSTS)
// ===========================================================================

/// State for the explore feed (all public posts).
class ExploreState {
  const ExploreState({
    this.posts = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.lastTimestamp,
    this.error,
  });

  final List<Post> posts;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final DateTime? lastTimestamp;
  final String? error;

  ExploreState copyWith({
    List<Post>? posts,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    DateTime? lastTimestamp,
    String? error,
  }) {
    return ExploreState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      error: error,
    );
  }
}

/// Notifier for managing the explore feed.
class ExploreNotifier extends Notifier<ExploreState> {
  StreamSubscription<List<Post>>? _subscription;

  @override
  ExploreState build() {
    ref.onDispose(() => _subscription?.cancel());
    _startWatching();
    return const ExploreState(isLoading: true);
  }

  void _startWatching() {
    final service = ref.read(socialServiceProvider);
    _subscription?.cancel();
    _subscription = service
        .watchExplorePosts(limit: 20)
        .listen(
          (posts) {
            state = ExploreState(
              posts: posts,
              hasMore: posts.length >= 20,
              lastTimestamp: posts.lastOrNull?.createdAt,
            );
          },
          onError: (e) {
            state = ExploreState(error: e.toString());
          },
        );
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);

    final service = ref.read(socialServiceProvider);
    try {
      final result = await service.getExplorePosts(
        startAfter: state.lastTimestamp,
      );
      state = state.copyWith(
        posts: [...state.posts, ...result.items],
        hasMore: result.hasMore,
        lastTimestamp: result.lastTimestamp,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, error: null);
    _startWatching();
  }

  /// Optimistically remove a post from the explore feed (before server confirms deletion)
  void removePost(String postId) {
    state = state.copyWith(
      posts: state.posts.where((post) => post.id != postId).toList(),
    );
  }
}

/// Provider for the explore feed.
final exploreProvider = NotifierProvider<ExploreNotifier, ExploreState>(
  ExploreNotifier.new,
);

// ===========================================================================
// USER POSTS
// ===========================================================================

/// Stream provider for real-time user posts.
final userPostsStreamProvider = StreamProvider.autoDispose
    .family<List<Post>, String>((ref, userId) {
      final service = ref.watch(socialServiceProvider);
      return service.watchUserPosts(userId);
    });

/// Paginated user posts provider.
final userPostsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<Post>, String>((ref, userId) async {
      final service = ref.watch(socialServiceProvider);
      return service.getUserPosts(userId);
    });

/// Stream provider for a single post with real-time updates.
final postStreamProvider = StreamProvider.autoDispose.family<Post?, String>((
  ref,
  postId,
) {
  final service = ref.watch(socialServiceProvider);
  return service.watchPost(postId);
});

// ===========================================================================
// POST CREATION
// ===========================================================================

/// State for post creation.
class CreatePostState {
  const CreatePostState({
    this.isCreating = false,
    this.error,
    this.createdPost,
  });

  final bool isCreating;
  final String? error;
  final Post? createdPost;
}

/// Notifier for creating posts.
class CreatePostNotifier extends Notifier<CreatePostState> {
  @override
  CreatePostState build() => const CreatePostState();

  Future<Post?> createPost({
    required String content,
    List<String>? mediaUrls,
    PostLocation? location,
    String? nodeId,
  }) async {
    state = const CreatePostState(isCreating: true);

    final service = ref.read(socialServiceProvider);
    try {
      final post = await service.createPost(
        content: content,
        imageUrls: mediaUrls,
        location: location,
        nodeId: nodeId,
      );
      state = CreatePostState(createdPost: post);

      // Apply optimistic post count increment immediately
      // Get current server count from stream (or 0 if not loaded)
      final currentProfile = ref
          .read(publicProfileStreamProvider(post.authorId))
          .value;
      final currentCount = currentProfile?.postCount ?? 0;

      ref
          .read(profileCountAdjustmentsProvider.notifier)
          .increment(post.authorId, currentCount);

      return post;
    } catch (e) {
      state = CreatePostState(error: e.toString());
      return null;
    }
  }

  void reset() {
    state = const CreatePostState();
  }
}

/// Provider for post creation.
final createPostProvider =
    NotifierProvider<CreatePostNotifier, CreatePostState>(
      CreatePostNotifier.new,
    );

// ===========================================================================
// COMMENTS
// ===========================================================================

/// Stream provider for real-time comments.
final commentsStreamProvider = StreamProvider.autoDispose
    .family<List<CommentWithAuthor>, String>((ref, postId) {
      final service = ref.watch(socialServiceProvider);
      return service.watchComments(postId);
    });

/// Paginated comments provider.
final commentsProvider = FutureProvider.autoDispose
    .family<PaginatedResult<CommentWithAuthor>, String>((ref, postId) async {
      final service = ref.watch(socialServiceProvider);
      return service.getComments(postId);
    });

/// Helper to add a comment
Future<Comment?> addComment(
  WidgetRef ref,
  String postId,
  String content, {
  String? parentId,
}) async {
  final service = ref.read(socialServiceProvider);
  try {
    return await service.createComment(
      postId: postId,
      content: content,
      parentId: parentId,
    );
  } catch (e) {
    return null;
  }
}

/// Helper to delete a comment
Future<bool> deleteComment(WidgetRef ref, String commentId) async {
  final service = ref.read(socialServiceProvider);
  try {
    await service.deleteComment(commentId);
    return true;
  } catch (e) {
    return false;
  }
}

// ===========================================================================
// LIKES
// ===========================================================================

/// Stream provider for real-time like status.
final likeStatusStreamProvider = StreamProvider.autoDispose
    .family<bool, String>((ref, postId) {
      final service = ref.watch(socialServiceProvider);
      return service.watchLikeStatus(postId);
    });

/// Provider for like status (one-time check).
final likeStatusProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  postId,
) async {
  final service = ref.watch(socialServiceProvider);
  return service.hasLikedPost(postId);
});

/// Helper to toggle like status
Future<void> toggleLike(WidgetRef ref, String postId) async {
  final service = ref.read(socialServiceProvider);
  final isLiked = await service.hasLikedPost(postId);

  if (isLiked) {
    await service.unlikePost(postId);
  } else {
    await service.likePost(postId);
  }
}

// ===========================================================================
// PUBLIC PROFILE
// ===========================================================================

/// Tracks optimistic post count updates.
/// Stores the expected post count after optimistic updates.
/// When stream emits the expected count, we know server has synced.
class ProfileCountAdjustmentsNotifier
    extends Notifier<Map<String, OptimisticCount>> {
  @override
  Map<String, OptimisticCount> build() => {};

  /// Record an optimistic increment. Stores the baseline and expected count.
  void increment(String userId, int currentServerCount) {
    final existing = state[userId];
    final baseline = existing?.baselineCount ?? currentServerCount;
    final newExpected = (existing?.expectedCount ?? currentServerCount) + 1;
    state = {
      ...state,
      userId: OptimisticCount(
        baselineCount: baseline,
        expectedCount: newExpected,
      ),
    };
  }

  /// Record an optimistic decrement.
  void decrement(String userId, int currentServerCount) {
    final existing = state[userId];
    final baseline = existing?.baselineCount ?? currentServerCount;
    final newExpected = (existing?.expectedCount ?? currentServerCount) - 1;
    state = {
      ...state,
      userId: OptimisticCount(
        baselineCount: baseline,
        expectedCount: newExpected.clamp(0, 999999),
      ),
    };
  }

  void reset(String userId) {
    final newState = Map<String, OptimisticCount>.from(state);
    newState.remove(userId);
    state = newState;
  }

  /// Get the adjustment to apply given the current server count.
  /// Returns 0 if server has caught up to expected count.
  int getAdjustment(String userId, int serverCount) {
    final optimistic = state[userId];
    if (optimistic == null) return 0;

    // Server has synced when it matches the expected count
    if (serverCount == optimistic.expectedCount) {
      // Auto-clear the optimistic state since server caught up
      Future.microtask(() => reset(userId));
      return 0;
    }

    // If server moved past our baseline in the expected direction, it synced
    // For increments: baseline=5, expected=6, server becomes 6+ means synced
    // For decrements: baseline=5, expected=4, server becomes 4 or less means synced
    final isIncrement = optimistic.expectedCount > optimistic.baselineCount;
    if (isIncrement && serverCount >= optimistic.expectedCount) {
      Future.microtask(() => reset(userId));
      return 0;
    }
    if (!isIncrement && serverCount <= optimistic.expectedCount) {
      Future.microtask(() => reset(userId));
      return 0;
    }

    // Server hasn't caught up yet, apply the difference
    return optimistic.expectedCount - serverCount;
  }
}

/// Class to track optimistic counts for post count updates.
class OptimisticCount {
  /// The server count when we started tracking.
  final int baselineCount;

  /// The expected count after optimistic updates.
  final int expectedCount;

  const OptimisticCount({
    required this.baselineCount,
    required this.expectedCount,
  });
}

/// Global provider for all profile count adjustments.
final profileCountAdjustmentsProvider =
    NotifierProvider<
      ProfileCountAdjustmentsNotifier,
      Map<String, OptimisticCount>
    >(ProfileCountAdjustmentsNotifier.new);

/// Provider for a public profile (async).
final publicProfileProvider = FutureProvider.autoDispose
    .family<PublicProfile?, String>((ref, userId) async {
      final service = ref.watch(socialServiceProvider);
      return service.getPublicProfile(userId);
    });

/// Stream provider for real-time public profile updates.
/// Not auto-disposed to keep stream active across navigation.
final publicProfileStreamProvider =
    StreamProvider.family<PublicProfile?, String>((ref, userId) {
      final service = ref.watch(socialServiceProvider);
      return service.watchPublicProfile(userId);
    });

/// Combined provider that merges stream data with optimistic adjustments.
/// Use this instead of publicProfileStreamProvider for UI that needs instant updates.
final optimisticProfileProvider =
    Provider.family<AsyncValue<PublicProfile?>, String>((ref, userId) {
      final profileAsync = ref.watch(publicProfileStreamProvider(userId));
      // Watch the adjustments map to trigger rebuilds
      ref.watch(profileCountAdjustmentsProvider);

      return profileAsync.whenData((profile) {
        if (profile == null) return profile;

        // Get dynamic adjustment based on current server count
        final adjustment = ref
            .read(profileCountAdjustmentsProvider.notifier)
            .getAdjustment(userId, profile.postCount);

        if (adjustment == 0) return profile;

        // Apply optimistic adjustment to post count
        return profile.copyWith(
          postCount: (profile.postCount + adjustment).clamp(0, 999999),
        );
      });
    });

// ===========================================================================
// BLOCKS
// ===========================================================================

/// Provider to check if a user is blocked.
final isBlockedProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  userId,
) async {
  final service = ref.watch(socialServiceProvider);
  return service.hasBlocked(userId);
});

/// Provider for blocked user IDs.
final blockedUsersProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final service = ref.watch(socialServiceProvider);
  return service.getBlockedUserIds();
});

/// Helper to block a user
Future<void> blockUser(WidgetRef ref, String userId) async {
  final service = ref.read(socialServiceProvider);
  await service.blockUser(userId);
  ref.invalidate(isBlockedProvider(userId));
  ref.invalidate(blockedUsersProvider);
}

/// Helper to unblock a user
Future<void> unblockUser(WidgetRef ref, String userId) async {
  final service = ref.read(socialServiceProvider);
  await service.unblockUser(userId);
  ref.invalidate(isBlockedProvider(userId));
  ref.invalidate(blockedUsersProvider);
}
