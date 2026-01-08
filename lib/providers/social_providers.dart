import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mesh_models.dart';
import '../models/social.dart';
import '../services/social_service.dart';
import '../services/content_moderation_service.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'profile_providers.dart';

// ===========================================================================
// SERVICE PROVIDERS
// ===========================================================================

/// Provider for the SocialService singleton.
final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService();
});

/// Provider for the ContentModerationService singleton.
final contentModerationServiceProvider = Provider<ContentModerationService>((
  ref,
) {
  return ContentModerationService();
});

/// Provider for pending reported content count (for badge)
final pendingReportCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(socialServiceProvider);
  return service.watchPendingReports().map((reports) => reports.length);
});

// ===========================================================================
// FOLLOW STATE
// ===========================================================================

/// State for tracking follow status between current user and a target.
/// Supports both public (instant follow) and private (request-based) accounts.
class FollowState {
  const FollowState({
    this.isFollowing = false,
    this.isFollowedBy = false,
    this.hasPendingRequest = false,
    this.targetIsPrivate = false,
    this.isLoading = false,
    this.error,
  });

  /// Whether current user is following the target
  final bool isFollowing;

  /// Whether target is following the current user
  final bool isFollowedBy;

  /// Whether there's a pending follow request to the target
  final bool hasPendingRequest;

  /// Whether the target account is private
  final bool targetIsPrivate;

  final bool isLoading;
  final String? error;

  /// Both users follow each other
  bool get isMutual => isFollowing && isFollowedBy;

  /// Computed state for UI button display
  FollowButtonState get buttonState {
    if (isFollowing) return FollowButtonState.following;
    if (hasPendingRequest) return FollowButtonState.requested;
    return FollowButtonState.notFollowing;
  }

  FollowState copyWith({
    bool? isFollowing,
    bool? isFollowedBy,
    bool? hasPendingRequest,
    bool? targetIsPrivate,
    bool? isLoading,
    String? error,
  }) {
    return FollowState(
      isFollowing: isFollowing ?? this.isFollowing,
      isFollowedBy: isFollowedBy ?? this.isFollowedBy,
      hasPendingRequest: hasPendingRequest ?? this.hasPendingRequest,
      targetIsPrivate: targetIsPrivate ?? this.targetIsPrivate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Button state for follow action UI
enum FollowButtonState {
  /// Not following - show "Follow" button
  notFollowing,

  /// Request sent to private account - show "Requested" button
  requested,

  /// Following - show "Following" button
  following,
}

/// Provider for follow state with a specific user.
/// Includes follow request status for private accounts.
final followStateProvider = FutureProvider.autoDispose
    .family<FollowState, String>((ref, targetUserId) async {
      final service = ref.watch(socialServiceProvider);

      // Fetch all states in parallel
      final results = await Future.wait([
        service.isFollowing(targetUserId),
        service.isFollowedBy(targetUserId),
        service.hasPendingFollowRequest(targetUserId),
        service.getPublicProfile(targetUserId),
      ]);

      final isFollowing = results[0] as bool;
      final isFollowedBy = results[1] as bool;
      final hasPendingRequest = results[2] as bool;
      final profile = results[3] as PublicProfile?;

      return FollowState(
        isFollowing: isFollowing,
        isFollowedBy: isFollowedBy,
        hasPendingRequest: hasPendingRequest,
        targetIsPrivate: profile?.isPrivate ?? false,
      );
    });

/// Helper to toggle follow status.
/// For private accounts, sends a follow request instead of instant follow.
/// For accounts with pending requests, cancels the request.
Future<void> toggleFollow(WidgetRef ref, String targetUserId) async {
  final service = ref.read(socialServiceProvider);
  final currentUser = ref.read(currentUserProvider);
  final currentState = await ref.read(followStateProvider(targetUserId).future);

  if (currentState.isFollowing) {
    // Unfollow
    await service.unfollowUser(targetUserId);
  } else if (currentState.hasPendingRequest) {
    // Cancel pending request
    await service.cancelFollowRequest(targetUserId);
  } else {
    // Follow or send request (followUser handles private accounts internally)
    await service.followUser(targetUserId);
  }

  // Invalidate to refresh both users' states
  ref.invalidate(followStateProvider(targetUserId));
  // Invalidate profile streams so follower/following counts update immediately
  ref.invalidate(publicProfileStreamProvider(targetUserId));
  if (currentUser != null) {
    ref.invalidate(publicProfileStreamProvider(currentUser.uid));
  }
}

// ===========================================================================
// FOLLOW REQUESTS
// ===========================================================================

/// Provider for the count of pending follow requests (for badges).
final pendingFollowRequestsCountProvider = StreamProvider.autoDispose<int>((
  ref,
) {
  final service = ref.watch(socialServiceProvider);
  return service.watchPendingFollowRequestsCount();
});

/// Provider for pending follow requests with requester profiles.
final pendingFollowRequestsProvider =
    StreamProvider.autoDispose<List<FollowRequestWithProfile>>((ref) {
      final service = ref.watch(socialServiceProvider);
      return service.watchPendingFollowRequests();
    });

/// Accept a follow request
Future<void> acceptFollowRequest(WidgetRef ref, String requesterId) async {
  final service = ref.read(socialServiceProvider);
  final currentUser = ref.read(currentUserProvider);
  await service.acceptFollowRequest(requesterId);

  // Invalidate related providers
  ref.invalidate(pendingFollowRequestsProvider);
  ref.invalidate(pendingFollowRequestsCountProvider);
  ref.invalidate(followStateProvider(requesterId));
  // Invalidate profile streams so follower counts update immediately
  ref.invalidate(publicProfileStreamProvider(requesterId));
  if (currentUser != null) {
    ref.invalidate(publicProfileStreamProvider(currentUser.uid));
  }
}

/// Decline a follow request
Future<void> declineFollowRequest(WidgetRef ref, String requesterId) async {
  final service = ref.read(socialServiceProvider);
  await service.declineFollowRequest(requesterId);

  // Invalidate related providers
  ref.invalidate(pendingFollowRequestsProvider);
  ref.invalidate(pendingFollowRequestsCountProvider);
}

/// Remove a follower (for private accounts)
Future<void> removeFollower(WidgetRef ref, String followerId) async {
  final service = ref.read(socialServiceProvider);
  final currentUser = ref.read(currentUserProvider);
  await service.removeFollower(followerId);

  // Invalidate related providers
  ref.invalidate(followStateProvider(followerId));
  // Invalidate profile streams so follower counts update immediately
  ref.invalidate(publicProfileStreamProvider(followerId));
  if (currentUser != null) {
    ref.invalidate(publicProfileStreamProvider(currentUser.uid));
  }
}

/// Set account privacy setting
Future<void> setAccountPrivacy(WidgetRef ref, bool isPrivate) async {
  final service = ref.read(socialServiceProvider);
  await service.setAccountPrivacy(isPrivate);

  // Invalidate current user's profile
  final currentUser = ref.read(currentUserProvider);
  if (currentUser != null) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
  }
}

// ===========================================================================
// USER SEARCH
// ===========================================================================

/// Provider for user search results.
/// Pass the search query as the family parameter.
final userSearchProvider = FutureProvider.autoDispose
    .family<PaginatedResult<PublicProfile>, String>((ref, query) async {
      if (query.trim().isEmpty) {
        return PaginatedResult(items: [], hasMore: false);
      }
      final service = ref.watch(socialServiceProvider);
      return service.searchUsers(query);
    });

/// Provider for suggested users to follow.
final suggestedUsersProvider = FutureProvider.autoDispose<List<PublicProfile>>((
  ref,
) async {
  final service = ref.watch(socialServiceProvider);
  return service.getSuggestedUsers();
});

/// Provider for recently active users.
final recentlyActiveUsersProvider =
    FutureProvider.autoDispose<List<PublicProfile>>((ref) async {
      final service = ref.watch(socialServiceProvider);
      return service.getRecentlyActiveUsers();
    });

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

  // Get node metadata to cache for display when node isn't in local store
  final nodes = ref.read(nodesProvider);
  final node = nodes[nodeId];

  await service.linkNodeToProfile(
    nodeId,
    setPrimary: setPrimary,
    longName: node?.longName,
    shortName: node?.shortName,
    avatarColor: node?.avatarColor,
  );

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
  debugPrint('🔗 [unlinkNode] Starting unlink for nodeId: $nodeId');

  final service = ref.read(socialServiceProvider);
  debugPrint(
    '🔗 [unlinkNode] Got socialService, calling unlinkNodeFromProfile...',
  );

  try {
    await service.unlinkNodeFromProfile(nodeId);
    debugPrint('🔗 [unlinkNode] Firestore unlink completed');
  } catch (e, stackTrace) {
    debugPrint('🔗 [unlinkNode] Firestore unlink FAILED: $e');
    debugPrint('🔗 [unlinkNode] Stack trace: $stackTrace');
    rethrow;
  }

  // Update local profile storage to persist linked nodes across app restarts
  final userProfileNotifier = ref.read(userProfileProvider.notifier);
  final currentProfile = ref.read(userProfileProvider).value;
  debugPrint(
    '🔗 [unlinkNode] Current profile: ${currentProfile != null ? "exists" : "null"}, '
    'linkedNodeIds: ${currentProfile?.linkedNodeIds}',
  );

  if (currentProfile != null) {
    final updatedLinkedNodes = [...currentProfile.linkedNodeIds]
      ..remove(nodeId);
    final newPrimaryId = currentProfile.primaryNodeId == nodeId
        ? (updatedLinkedNodes.isNotEmpty ? updatedLinkedNodes.first : null)
        : currentProfile.primaryNodeId;
    debugPrint(
      '🔗 [unlinkNode] Updating local profile: '
      'updatedLinkedNodes=$updatedLinkedNodes, newPrimaryId=$newPrimaryId',
    );
    try {
      await userProfileNotifier.updateLinkedNodes(
        updatedLinkedNodes,
        primaryNodeId: newPrimaryId,
        clearPrimaryNodeId: newPrimaryId == null,
      );
      debugPrint('🔗 [unlinkNode] Local profile update completed');
    } catch (e, stackTrace) {
      debugPrint('🔗 [unlinkNode] Local profile update FAILED: $e');
      debugPrint('🔗 [unlinkNode] Stack trace: $stackTrace');
      // Don't rethrow - Firestore already updated
    }
  }

  // Invalidate providers to refresh state
  debugPrint('🔗 [unlinkNode] Invalidating providers...');
  ref.invalidate(linkedNodeIdsProvider);
  ref.invalidate(isNodeLinkedProvider(nodeId));
  ref.invalidate(profileByNodeIdProvider(nodeId));
  // Also invalidate the user's public profile so UI updates
  final currentUser = ref.read(currentUserProvider);
  debugPrint('🔗 [unlinkNode] Current user: ${currentUser?.uid}');
  if (currentUser != null) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
    debugPrint('🔗 [unlinkNode] Invalidated publicProfileProvider');
  }
  debugPrint('🔗 [unlinkNode] Unlink complete');
}

/// Refresh cached metadata for all linked nodes using current mesh data.
/// Call this when connecting to a device to ensure cached info is current.
/// This updates Firestore with the latest node names so they display correctly
/// even when viewing the profile from a different device.
Future<void> refreshLinkedNodeMetadata(Ref ref) async {
  final currentUser = ref.read(currentUserProvider);
  if (currentUser == null) return;

  final service = ref.read(socialServiceProvider);
  final nodes = ref.read(nodesProvider);
  final linkedNodeIds = ref.read(linkedNodeIdsProvider).asData?.value ?? [];

  if (linkedNodeIds.isEmpty) return;

  var updated = false;
  for (final nodeId in linkedNodeIds) {
    final node = nodes[nodeId];
    // Only update if we have meaningful node data (not just the ID)
    if (node != null && (node.longName != null || node.shortName != null)) {
      try {
        await service.updateLinkedNodeMetadata(
          nodeId,
          longName: node.longName,
          shortName: node.shortName,
          avatarColor: node.avatarColor,
        );
        updated = true;
      } catch (e) {
        // Silently fail - this is opportunistic refresh
        debugPrint('Failed to update linked node metadata for $nodeId: $e');
      }
    }
  }

  // If we updated any metadata, invalidate the profile to pick up changes
  if (updated) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
  }
}

/// Check if a node's identity fields have changed in a way that requires
/// updating the cached metadata. Only compares display-relevant fields.
bool _hasIdentityChanged(MeshNode node, MeshNode? previousNode) {
  if (previousNode == null) {
    // New node with identity data = changed
    return node.longName != null || node.shortName != null;
  }
  return node.longName != previousNode.longName ||
      node.shortName != previousNode.shortName ||
      node.avatarColor != previousNode.avatarColor;
}

/// Event-driven handler for node updates. Called from NodesNotifier when
/// a node is updated. If the node is linked to the current user's profile
/// and its identity fields have changed, updates the cached metadata in Firestore.
///
/// This is the primary mechanism for keeping linked node metadata current.
/// The connection-triggered refresh serves as a bootstrap fallback.
void onLinkedNodeUpdated(Ref ref, MeshNode node, MeshNode? previousNode) {
  // Skip if no identity change
  if (!_hasIdentityChanged(node, previousNode)) return;

  // Skip if user not signed in
  final currentUser = ref.read(currentUserProvider);
  if (currentUser == null) return;

  // Check if this node is linked to the current user (async lookup)
  final linkedNodeIds = ref.read(linkedNodeIdsProvider).asData?.value;
  if (linkedNodeIds == null || !linkedNodeIds.contains(node.nodeNum)) return;

  // Update metadata in Firestore (fire-and-forget)
  final service = ref.read(socialServiceProvider);
  service
      .updateLinkedNodeMetadata(
        node.nodeNum,
        longName: node.longName,
        shortName: node.shortName,
        avatarColor: node.avatarColor,
      )
      .then((_) {
        // Invalidate profile to pick up new metadata
        ref.invalidate(publicProfileProvider(currentUser.uid));
        debugPrint(
          '✅ Updated linked node metadata for ${node.displayName} (${node.nodeNum})',
        );
      })
      .catchError((e) {
        // Silently fail - opportunistic update
        debugPrint('Failed to update linked node metadata: $e');
      });
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
    ref.invalidate(publicProfileStreamProvider(currentUser.uid));
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

/// State for paginated user posts.
class UserPostsState {
  const UserPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.hasMore = true,
    this.lastTimestamp,
    this.error,
  });

  final List<Post> posts;
  final bool isLoading;
  final bool isRefreshing;
  final bool hasMore;
  final DateTime? lastTimestamp;
  final String? error;

  UserPostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isRefreshing,
    bool? hasMore,
    DateTime? lastTimestamp,
    String? error,
  }) {
    return UserPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      hasMore: hasMore ?? this.hasMore,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      error: error,
    );
  }
}

/// Notifier for paginated user posts
/// Uses Map to manage multiple users' posts simultaneously.
class UserPostsNotifier extends Notifier<Map<String, UserPostsState>> {
  final Map<String, StreamSubscription<List<Post>>> _subscriptions = {};

  @override
  Map<String, UserPostsState> build() {
    ref.onDispose(() {
      for (final sub in _subscriptions.values) {
        sub.cancel();
      }
      _subscriptions.clear();
    });
    return {};
  }

  UserPostsState getOrCreate(String userId) {
    if (!state.containsKey(userId)) {
      _startWatching(userId);
      state = {...state, userId: const UserPostsState(isLoading: true)};
    }
    return state[userId]!;
  }

  void _startWatching(String userId) {
    final service = ref.read(socialServiceProvider);
    _subscriptions[userId]?.cancel();
    _subscriptions[userId] = service
        .watchUserPosts(userId, limit: 20)
        .listen(
          (posts) {
            state = {
              ...state,
              userId: UserPostsState(
                posts: posts,
                hasMore: posts.length >= 20,
                lastTimestamp: posts.lastOrNull?.createdAt,
              ),
            };
          },
          onError: (e) {
            state = {...state, userId: UserPostsState(error: e.toString())};
          },
        );
  }

  Future<void> loadMore(String userId) async {
    final currentState = state[userId];
    if (currentState == null ||
        currentState.isLoading ||
        !currentState.hasMore) {
      return;
    }

    state = {...state, userId: currentState.copyWith(isLoading: true)};

    final service = ref.read(socialServiceProvider);
    try {
      final result = await service.getUserPosts(
        userId,
        startAfterId: state[userId]?.posts.lastOrNull?.id,
      );
      state = {
        ...state,
        userId: currentState.copyWith(
          posts: [...currentState.posts, ...result.items],
          hasMore: result.hasMore,
          lastTimestamp: result.lastTimestamp,
          isLoading: false,
        ),
      };
    } catch (e) {
      state = {
        ...state,
        userId: currentState.copyWith(isLoading: false, error: e.toString()),
      };
    }
  }

  Future<void> refresh(String userId) async {
    final currentState = state[userId];
    if (currentState != null) {
      state = {
        ...state,
        userId: currentState.copyWith(isRefreshing: true, error: null),
      };
    }
    _startWatching(userId);
  }

  /// Optimistically remove a post (before server confirms deletion)
  void removePost(String userId, String postId) {
    final currentState = state[userId];
    if (currentState != null) {
      state = {
        ...state,
        userId: currentState.copyWith(
          posts: currentState.posts.where((post) => post.id != postId).toList(),
        ),
      };
    }
  }
}

/// Global provider for all user posts.
final userPostsNotifierProvider =
    NotifierProvider<UserPostsNotifier, Map<String, UserPostsState>>(
      UserPostsNotifier.new,
    );

/// Helper provider to watch a specific user's posts.
final userPostsStateProvider = Provider.family<UserPostsState, String>((
  ref,
  userId,
) {
  final notifier = ref.watch(userPostsNotifierProvider.notifier);
  final allStates = ref.watch(userPostsNotifierProvider);
  return allStates[userId] ?? notifier.getOrCreate(userId);
});

/// Stream provider for real-time user posts (deprecated - use userPostsNotifierProvider).
@Deprecated('Use userPostsNotifierProvider for better pagination')
final userPostsStreamProvider = StreamProvider.autoDispose
    .family<List<Post>, String>((ref, userId) {
      final service = ref.watch(socialServiceProvider);
      return service.watchUserPosts(userId);
    });

/// Paginated user posts provider (deprecated - use userPostsNotifierProvider).
@Deprecated('Use userPostsNotifierProvider for better pagination')
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

// ===========================================================================
// CONTENT MODERATION
// ===========================================================================

/// Provider for the current user's moderation status.
/// Watches Firestore for real-time updates to suspension/strike status.
final moderationStatusProvider = StreamProvider.autoDispose<ModerationStatus?>((
  ref,
) {
  final service = ref.watch(contentModerationServiceProvider);
  return service.watchModerationStatus();
});

/// Provider for fetching full moderation status with strike history.
final fullModerationStatusProvider =
    FutureProvider.autoDispose<ModerationStatus>((ref) async {
      final service = ref.watch(contentModerationServiceProvider);
      return service.getModerationStatus();
    });

/// Provider for unacknowledged strikes (to show warning dialogs).
final unacknowledgedStrikesProvider =
    FutureProvider.autoDispose<List<UserStrike>>((ref) async {
      final service = ref.watch(contentModerationServiceProvider);
      return service.getUnacknowledgedStrikes();
    });

/// Provider for the user's sensitive content settings.
final sensitiveContentSettingsProvider =
    StreamProvider.autoDispose<SensitiveContentSettings>((ref) {
      final service = ref.watch(contentModerationServiceProvider);
      return service.watchSensitiveContentSettings();
    });

/// Helper to check if user can post content (not suspended/banned).
final canPostContentProvider = Provider.autoDispose<bool>((ref) {
  final status = ref.watch(moderationStatusProvider);
  return status.maybeWhen(
    data: (s) => s?.canPost ?? true,
    orElse: () => true, // Allow by default if status unknown
  );
});

/// Helper to acknowledge a strike.
Future<void> acknowledgeStrike(WidgetRef ref, String strikeId) async {
  final service = ref.read(contentModerationServiceProvider);
  await service.acknowledgeStrike(strikeId);
  ref.invalidate(unacknowledgedStrikesProvider);
  ref.invalidate(fullModerationStatusProvider);
}

/// Helper to update sensitive content settings.
Future<void> updateSensitiveContentSettings(
  WidgetRef ref,
  SensitiveContentSettings settings,
) async {
  final service = ref.read(contentModerationServiceProvider);
  await service.updateSensitiveContentSettings(settings);
}

/// Helper to pre-screen text content before posting.
Future<TextModerationResult> checkTextContent(
  WidgetRef ref,
  String text, {
  bool useServerCheck = false,
}) async {
  final service = ref.read(contentModerationServiceProvider);
  return service.checkText(text, useServerCheck: useServerCheck);
}

// ===========================================================================
// ADMIN: MODERATION QUEUE
// ===========================================================================

/// Provider for the moderation queue (admin only).
final moderationQueueProvider = FutureProvider.autoDispose
    .family<List<ModerationQueueItem>, String?>((ref, status) async {
      final service = ref.watch(contentModerationServiceProvider);
      return service.getModerationQueue(status: status);
    });

/// Helper to review a moderation queue item (admin only).
Future<void> reviewModerationItem(
  WidgetRef ref, {
  required String itemId,
  required String action,
  String? notes,
}) async {
  final service = ref.read(contentModerationServiceProvider);
  await service.reviewModerationItem(
    itemId: itemId,
    action: action,
    notes: notes,
  );
  ref.invalidate(moderationQueueProvider(null));
  ref.invalidate(moderationQueueProvider('pending'));
}
