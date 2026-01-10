import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../models/mesh_models.dart';
import '../models/social.dart';
import '../services/social_service.dart';
import '../services/content_moderation_service.dart';
import 'app_providers.dart';
import 'auth_providers.dart';
import 'profile_providers.dart';

// ===========================================================================
// FOLLOW OPERATION LOCKS
// ===========================================================================

/// Set of user IDs currently being processed by toggleFollow to prevent
/// concurrent operations that could cause race conditions.
final _followOperationsInProgress = <String>{};

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
  // Only query reports if user is admin
  final profile = ref.watch(userProfileProvider).value;
  if (profile?.isAdmin != true) {
    return Stream.value(0);
  }

  final service = ref.watch(socialServiceProvider);
  return service.watchPendingReports().map((reports) => reports.length);
});

/// Provider for pending moderation queue count (for badge)
final pendingModerationCountProvider = StreamProvider<int>((ref) {
  // Only query moderation queue if user is admin
  final profile = ref.watch(userProfileProvider).value;
  if (profile?.isAdmin != true) {
    return Stream.value(0);
  }

  final service = ref.watch(socialServiceProvider);
  return service.watchModerationQueue().map((items) => items.length);
});

/// Combined count of all pending content needing review
final totalPendingContentCountProvider = StreamProvider<int>((ref) {
  final reports = ref.watch(pendingReportCountProvider);
  final moderation = ref.watch(pendingModerationCountProvider);

  final reportCount = reports.when(
    data: (count) => count,
    loading: () => 0,
    error: (e, s) => 0,
  );
  final moderationCount = moderation.when(
    data: (count) => count,
    loading: () => 0,
    error: (e, s) => 0,
  );

  return Stream.value(reportCount + moderationCount);
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

/// Notifier to cache batch-loaded follow states for efficiency.
/// Used by lists to avoid N+1 queries when displaying follow buttons.
class BatchFollowStatesNotifier extends Notifier<Map<String, FollowState>> {
  @override
  Map<String, FollowState> build() => {};

  /// Pre-load follow states for a list of user IDs.
  /// Call this before rendering a list with follow buttons.
  Future<void> preloadFollowStates(List<String> userIds) async {
    if (userIds.isEmpty) return;

    final service = ref.read(socialServiceProvider);

    // Filter out IDs we already have cached
    final uncachedIds = userIds.where((id) => !state.containsKey(id)).toList();
    if (uncachedIds.isEmpty) return;

    // Batch fetch follow states
    final followingMap = await service.batchIsFollowing(uncachedIds);
    final pendingMap = await service.batchHasPendingRequests(uncachedIds);

    // Update cache with new states
    final newStates = <String, FollowState>{};
    for (final id in uncachedIds) {
      newStates[id] = FollowState(
        isFollowing: followingMap[id] ?? false,
        hasPendingRequest: pendingMap[id] ?? false,
      );
    }

    state = {...state, ...newStates};
  }

  /// Get cached follow state for a user, or null if not loaded.
  FollowState? getFollowState(String userId) => state[userId];

  /// Update a single user's follow state (after toggle).
  void updateFollowState(String userId, FollowState newState) {
    state = Map<String, FollowState>.from(state)..[userId] = newState;
  }

  /// Clear cached state for a user (to force refresh).
  void invalidateUser(String userId) {
    final newState = Map<String, FollowState>.from(state);
    newState.remove(userId);
    state = newState;
  }

  /// Clear all cached states.
  void clear() => state = {};
}

/// Provider for batch-loaded follow states cache.
final batchFollowStatesProvider =
    NotifierProvider<BatchFollowStatesNotifier, Map<String, FollowState>>(
      BatchFollowStatesNotifier.new,
    );

/// Provider to get follow state from batch cache, with fallback to individual provider.
/// Use this in lists where batch loading has been done.
final cachedFollowStateProvider = Provider.autoDispose
    .family<AsyncValue<FollowState>, String>((ref, targetUserId) {
      // First check the batch cache
      final cache = ref.watch(batchFollowStatesProvider);
      final cached = cache[targetUserId];

      if (cached != null) {
        return AsyncValue.data(cached);
      }

      // Fall back to individual provider if not in cache
      return ref.watch(followStateProvider(targetUserId));
    });

/// Helper to toggle follow status.
/// For private accounts, sends a follow request instead of instant follow.
/// For accounts with pending requests, cancels the request.
Future<void> toggleFollow(WidgetRef ref, String targetUserId) async {
  // Prevent concurrent operations on the same user
  if (_followOperationsInProgress.contains(targetUserId)) {
    return;
  }
  _followOperationsInProgress.add(targetUserId);

  try {
    final service = ref.read(socialServiceProvider);
    final currentUser = ref.read(currentUserProvider);
    final currentState = await ref.read(
      followStateProvider(targetUserId).future,
    );

    // Get target profile for optimistic updates (needed to know current counts)
    final targetProfile = ref
        .read(publicProfileStreamProvider(targetUserId))
        .value;
    final myProfile = currentUser != null
        ? ref.read(publicProfileStreamProvider(currentUser.uid)).value
        : null;

    if (currentState.isFollowing) {
      // Unfollow - apply optimistic decrements
      if (targetProfile != null) {
        ref
            .read(profileCountAdjustmentsProvider.notifier)
            .decrement(
              targetUserId,
              ProfileCountType.followers,
              targetProfile.followerCount,
            );
      }
      if (myProfile != null && currentUser != null) {
        ref
            .read(profileCountAdjustmentsProvider.notifier)
            .decrement(
              currentUser.uid,
              ProfileCountType.following,
              myProfile.followingCount,
            );
      }
      await service.unfollowUser(targetUserId);
    } else if (currentState.hasPendingRequest) {
      // Cancel pending request - no count changes
      await service.cancelFollowRequest(targetUserId);
    } else {
      // Follow or send request
      final result = await service.followUser(targetUserId);
      // Only apply optimistic counts if it's an instant follow (not a request)
      if (result == 'followed') {
        if (targetProfile != null) {
          ref
              .read(profileCountAdjustmentsProvider.notifier)
              .increment(
                targetUserId,
                ProfileCountType.followers,
                targetProfile.followerCount,
              );
        }
        if (myProfile != null && currentUser != null) {
          ref
              .read(profileCountAdjustmentsProvider.notifier)
              .increment(
                currentUser.uid,
                ProfileCountType.following,
                myProfile.followingCount,
              );
        }
      }
    }

    // Update batch cache immediately for responsive UI
    final newState = FollowState(
      isFollowing: !currentState.isFollowing && !currentState.hasPendingRequest,
      hasPendingRequest: false,
    );
    ref
        .read(batchFollowStatesProvider.notifier)
        .updateFollowState(targetUserId, newState);

    // Invalidate to refresh both users' states
    ref.invalidate(followStateProvider(targetUserId));
    // Invalidate profile streams so follower/following counts update immediately
    ref.invalidate(publicProfileStreamProvider(targetUserId));
    if (currentUser != null) {
      ref.invalidate(publicProfileStreamProvider(currentUser.uid));
    }
  } finally {
    _followOperationsInProgress.remove(targetUserId);
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

  // Get profiles for optimistic updates
  final requesterProfile = ref
      .read(publicProfileStreamProvider(requesterId))
      .value;
  final myProfile = currentUser != null
      ? ref.read(publicProfileStreamProvider(currentUser.uid)).value
      : null;

  // Apply optimistic count updates:
  // - requester's following count goes up
  // - my follower count goes up
  if (requesterProfile != null) {
    ref
        .read(profileCountAdjustmentsProvider.notifier)
        .increment(
          requesterId,
          ProfileCountType.following,
          requesterProfile.followingCount,
        );
  }
  if (myProfile != null && currentUser != null) {
    ref
        .read(profileCountAdjustmentsProvider.notifier)
        .increment(
          currentUser.uid,
          ProfileCountType.followers,
          myProfile.followerCount,
        );
  }

  try {
    await service.acceptFollowRequest(requesterId);
  } catch (e) {
    // Rollback optimistic updates on failure
    if (requesterProfile != null) {
      ref
          .read(profileCountAdjustmentsProvider.notifier)
          .decrement(
            requesterId,
            ProfileCountType.following,
            requesterProfile.followingCount,
          );
    }
    if (myProfile != null && currentUser != null) {
      ref
          .read(profileCountAdjustmentsProvider.notifier)
          .decrement(
            currentUser.uid,
            ProfileCountType.followers,
            myProfile.followerCount,
          );
    }
    rethrow;
  }

  // Invalidate related providers
  ref.invalidate(pendingFollowRequestsProvider);
  ref.invalidate(pendingFollowRequestsCountProvider);
  ref.invalidate(followStateProvider(requesterId));
  // Invalidate profile streams so follower counts update immediately
  ref.invalidate(publicProfileStreamProvider(requesterId));
  ref.invalidate(optimisticProfileProvider(requesterId));
  if (currentUser != null) {
    ref.invalidate(publicProfileStreamProvider(currentUser.uid));
    ref.invalidate(optimisticProfileProvider(currentUser.uid));
  }
}

/// Decline a follow request
Future<void> declineFollowRequest(WidgetRef ref, String requesterId) async {
  final service = ref.read(socialServiceProvider);
  try {
    await service.declineFollowRequest(requesterId);
  } catch (e) {
    // Re-throw to allow caller to handle the error
    rethrow;
  }

  // Invalidate related providers
  ref.invalidate(pendingFollowRequestsProvider);
  ref.invalidate(pendingFollowRequestsCountProvider);
}

/// Remove a follower (for private accounts)
Future<void> removeFollower(WidgetRef ref, String followerId) async {
  final service = ref.read(socialServiceProvider);
  final currentUser = ref.read(currentUserProvider);

  // Get profiles for optimistic updates
  final followerProfile = ref
      .read(publicProfileStreamProvider(followerId))
      .value;
  final myProfile = currentUser != null
      ? ref.read(publicProfileStreamProvider(currentUser.uid)).value
      : null;

  // Apply optimistic count updates:
  // - follower's following count goes down
  // - my follower count goes down
  if (followerProfile != null) {
    ref
        .read(profileCountAdjustmentsProvider.notifier)
        .decrement(
          followerId,
          ProfileCountType.following,
          followerProfile.followingCount,
        );
  }
  if (myProfile != null && currentUser != null) {
    ref
        .read(profileCountAdjustmentsProvider.notifier)
        .decrement(
          currentUser.uid,
          ProfileCountType.followers,
          myProfile.followerCount,
        );
  }

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
  AppLogging.social('🔗 [unlinkNode] Starting unlink for nodeId: $nodeId');

  final service = ref.read(socialServiceProvider);
  AppLogging.social(
    '🔗 [unlinkNode] Got socialService, calling unlinkNodeFromProfile...',
  );

  try {
    await service.unlinkNodeFromProfile(nodeId);
    AppLogging.social('🔗 [unlinkNode] Firestore unlink completed');
  } catch (e, stackTrace) {
    AppLogging.social('🔗 [unlinkNode] Firestore unlink FAILED: $e');
    AppLogging.social('🔗 [unlinkNode] Stack trace: $stackTrace');
    rethrow;
  }

  // Update local profile storage to persist linked nodes across app restarts
  final userProfileNotifier = ref.read(userProfileProvider.notifier);
  final currentProfile = ref.read(userProfileProvider).value;
  AppLogging.social(
    '🔗 [unlinkNode] Current profile: ${currentProfile != null ? "exists" : "null"}, '
    'linkedNodeIds: ${currentProfile?.linkedNodeIds}',
  );

  if (currentProfile != null) {
    final updatedLinkedNodes = [...currentProfile.linkedNodeIds]
      ..remove(nodeId);
    final newPrimaryId = currentProfile.primaryNodeId == nodeId
        ? (updatedLinkedNodes.isNotEmpty ? updatedLinkedNodes.first : null)
        : currentProfile.primaryNodeId;
    AppLogging.social(
      '🔗 [unlinkNode] Updating local profile: '
      'updatedLinkedNodes=$updatedLinkedNodes, newPrimaryId=$newPrimaryId',
    );
    try {
      await userProfileNotifier.updateLinkedNodes(
        updatedLinkedNodes,
        primaryNodeId: newPrimaryId,
        clearPrimaryNodeId: newPrimaryId == null,
      );
      AppLogging.social('🔗 [unlinkNode] Local profile update completed');
    } catch (e, stackTrace) {
      AppLogging.social('🔗 [unlinkNode] Local profile update FAILED: $e');
      AppLogging.social('🔗 [unlinkNode] Stack trace: $stackTrace');
      // Don't rethrow - Firestore already updated
    }
  }

  // Invalidate providers to refresh state
  AppLogging.social('🔗 [unlinkNode] Invalidating providers...');
  ref.invalidate(linkedNodeIdsProvider);
  ref.invalidate(isNodeLinkedProvider(nodeId));
  ref.invalidate(profileByNodeIdProvider(nodeId));
  // Also invalidate the user's public profile so UI updates
  final currentUser = ref.read(currentUserProvider);
  AppLogging.social('🔗 [unlinkNode] Current user: ${currentUser?.uid}');
  if (currentUser != null) {
    ref.invalidate(publicProfileProvider(currentUser.uid));
    AppLogging.social('🔗 [unlinkNode] Invalidated publicProfileProvider');
  }
  AppLogging.social('🔗 [unlinkNode] Unlink complete');
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
        AppLogging.social(
          'Failed to update linked node metadata for $nodeId: $e',
        );
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
        AppLogging.social(
          '✅ Updated linked node metadata for ${node.displayName} (${node.nodeNum})',
        );
      })
      .catchError((e) {
        // Silently fail - opportunistic update
        AppLogging.social('Failed to update linked node metadata: $e');
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
      state = {...state, userId: const UserPostsState(isLoading: true)};
      _startWatching(userId);
    }
    return state[userId]!;
  }

  /// Ensures we are watching posts for a user (safe to call during provider build via microtask)
  void ensureWatching(String userId) {
    if (!state.containsKey(userId)) {
      state = {...state, userId: const UserPostsState(isLoading: true)};
      _startWatching(userId);
    }
  }

  void _startWatching(String userId) {
    // Cancel any existing subscription first to prevent race conditions
    final existing = _subscriptions[userId];
    if (existing != null) {
      existing.cancel();
      _subscriptions.remove(userId);
    }

    final service = ref.read(socialServiceProvider);
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
  final allStates = ref.watch(userPostsNotifierProvider);
  final existingState = allStates[userId];

  // If no state exists for this user, schedule initialization after build
  if (existingState == null) {
    // Use Future.microtask to avoid modifying state during build
    Future.microtask(() {
      ref.read(userPostsNotifierProvider.notifier).ensureWatching(userId);
    });
    // Return loading state while we wait for initialization
    return const UserPostsState(isLoading: true);
  }

  return existingState;
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
          .increment(post.authorId, ProfileCountType.posts, currentCount);

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
/// Throws on error for caller to handle
Future<Comment> addComment(
  WidgetRef ref,
  String postId,
  String content, {
  String? parentId,
}) async {
  final service = ref.read(socialServiceProvider);
  return service.createComment(
    postId: postId,
    content: content,
    parentId: parentId,
  );
}

/// Helper to delete a comment
/// Throws on error for caller to handle
Future<void> deleteComment(WidgetRef ref, String commentId) async {
  final service = ref.read(socialServiceProvider);
  await service.deleteComment(commentId);
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

/// Types of profile counts we can optimistically update.
enum ProfileCountType { posts, followers, following }

/// Tracks optimistic count updates for posts, followers, and following.
/// Stores the expected counts after optimistic updates.
/// When stream emits the expected count, we know server has synced.
class ProfileCountAdjustmentsNotifier
    extends Notifier<Map<String, OptimisticCounts>> {
  @override
  Map<String, OptimisticCounts> build() => {};

  /// Record an optimistic increment for a specific count type.
  void increment(String userId, ProfileCountType type, int currentServerCount) {
    final existing = state[userId] ?? const OptimisticCounts();
    final updated = existing.increment(type, currentServerCount);
    state = {...state, userId: updated};
  }

  /// Record an optimistic decrement for a specific count type.
  void decrement(String userId, ProfileCountType type, int currentServerCount) {
    final existing = state[userId] ?? const OptimisticCounts();
    final updated = existing.decrement(type, currentServerCount);
    state = {...state, userId: updated};
  }

  void reset(String userId) {
    final newState = Map<String, OptimisticCounts>.from(state);
    newState.remove(userId);
    state = newState;
  }

  void resetType(String userId, ProfileCountType type) {
    final existing = state[userId];
    if (existing == null) return;

    final updated = existing.resetType(type);
    if (updated.isEmpty) {
      final newState = Map<String, OptimisticCounts>.from(state);
      newState.remove(userId);
      state = newState;
    } else {
      state = {...state, userId: updated};
    }
  }

  /// Get the adjustment to apply for a specific count type given server count.
  /// Returns 0 if server has caught up to expected count.
  int getAdjustment(String userId, ProfileCountType type, int serverCount) {
    final optimistic = state[userId];
    if (optimistic == null) return 0;

    final count = optimistic.getCount(type);
    if (count == null) return 0;

    // Server has synced when it matches the expected count
    if (serverCount == count.expectedCount) {
      // Auto-clear the optimistic state for this type since server caught up
      Future.microtask(() => resetType(userId, type));
      return 0;
    }

    // If server moved past our baseline in the expected direction, it synced
    final isIncrement = count.expectedCount > count.baselineCount;
    if (isIncrement && serverCount >= count.expectedCount) {
      Future.microtask(() => resetType(userId, type));
      return 0;
    }
    if (!isIncrement && serverCount <= count.expectedCount) {
      Future.microtask(() => resetType(userId, type));
      return 0;
    }

    // Server hasn't caught up yet, apply the difference
    return count.expectedCount - serverCount;
  }

  /// Legacy method for backwards compatibility with post count adjustments.
  @Deprecated('Use increment(userId, ProfileCountType.posts, count) instead')
  void incrementPosts(String userId, int currentServerCount) {
    increment(userId, ProfileCountType.posts, currentServerCount);
  }

  /// Legacy method for backwards compatibility.
  @Deprecated('Use decrement(userId, ProfileCountType.posts, count) instead')
  void decrementPosts(String userId, int currentServerCount) {
    decrement(userId, ProfileCountType.posts, currentServerCount);
  }
}

/// Single optimistic count tracker.
class OptimisticCount {
  final int baselineCount;
  final int expectedCount;

  const OptimisticCount({
    required this.baselineCount,
    required this.expectedCount,
  });
}

/// Container for all optimistic counts for a profile.
class OptimisticCounts {
  final OptimisticCount? posts;
  final OptimisticCount? followers;
  final OptimisticCount? following;

  const OptimisticCounts({this.posts, this.followers, this.following});

  bool get isEmpty => posts == null && followers == null && following == null;

  OptimisticCount? getCount(ProfileCountType type) {
    switch (type) {
      case ProfileCountType.posts:
        return posts;
      case ProfileCountType.followers:
        return followers;
      case ProfileCountType.following:
        return following;
    }
  }

  OptimisticCounts increment(ProfileCountType type, int currentServerCount) {
    final existing = getCount(type);
    final baseline = existing?.baselineCount ?? currentServerCount;
    final newExpected = (existing?.expectedCount ?? currentServerCount) + 1;
    final newCount = OptimisticCount(
      baselineCount: baseline,
      expectedCount: newExpected,
    );

    switch (type) {
      case ProfileCountType.posts:
        return OptimisticCounts(
          posts: newCount,
          followers: followers,
          following: following,
        );
      case ProfileCountType.followers:
        return OptimisticCounts(
          posts: posts,
          followers: newCount,
          following: following,
        );
      case ProfileCountType.following:
        return OptimisticCounts(
          posts: posts,
          followers: followers,
          following: newCount,
        );
    }
  }

  OptimisticCounts decrement(ProfileCountType type, int currentServerCount) {
    final existing = getCount(type);
    final baseline = existing?.baselineCount ?? currentServerCount;
    final newExpected = ((existing?.expectedCount ?? currentServerCount) - 1)
        .clamp(0, 999999);
    final newCount = OptimisticCount(
      baselineCount: baseline,
      expectedCount: newExpected,
    );

    switch (type) {
      case ProfileCountType.posts:
        return OptimisticCounts(
          posts: newCount,
          followers: followers,
          following: following,
        );
      case ProfileCountType.followers:
        return OptimisticCounts(
          posts: posts,
          followers: newCount,
          following: following,
        );
      case ProfileCountType.following:
        return OptimisticCounts(
          posts: posts,
          followers: followers,
          following: newCount,
        );
    }
  }

  OptimisticCounts resetType(ProfileCountType type) {
    switch (type) {
      case ProfileCountType.posts:
        return OptimisticCounts(followers: followers, following: following);
      case ProfileCountType.followers:
        return OptimisticCounts(posts: posts, following: following);
      case ProfileCountType.following:
        return OptimisticCounts(posts: posts, followers: followers);
    }
  }
}

/// Global provider for all profile count adjustments.
final profileCountAdjustmentsProvider =
    NotifierProvider<
      ProfileCountAdjustmentsNotifier,
      Map<String, OptimisticCounts>
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

        final notifier = ref.read(profileCountAdjustmentsProvider.notifier);

        // Get adjustments for all count types
        final postAdjustment = notifier.getAdjustment(
          userId,
          ProfileCountType.posts,
          profile.postCount,
        );
        final followerAdjustment = notifier.getAdjustment(
          userId,
          ProfileCountType.followers,
          profile.followerCount,
        );
        final followingAdjustment = notifier.getAdjustment(
          userId,
          ProfileCountType.following,
          profile.followingCount,
        );

        // If no adjustments needed, return original profile
        if (postAdjustment == 0 &&
            followerAdjustment == 0 &&
            followingAdjustment == 0) {
          return profile;
        }

        // Apply all optimistic adjustments
        return profile.copyWith(
          postCount: (profile.postCount + postAdjustment).clamp(0, 999999),
          followerCount: (profile.followerCount + followerAdjustment).clamp(
            0,
            999999,
          ),
          followingCount: (profile.followingCount + followingAdjustment).clamp(
            0,
            999999,
          ),
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

/// AsyncNotifier for managing user's moderation status with acknowledgment.
/// Supports real-time updates and action methods.
class ModerationStatusNotifier extends AsyncNotifier<ModerationStatus?> {
  /// Track the last known "severe" status to prevent downgrade flicker
  ModerationStatus? _lastKnownSevereStatus;

  @override
  Future<ModerationStatus?> build() async {
    final service = ref.watch(contentModerationServiceProvider);

    // Subscribe to stream for real-time updates
    final subscription = service.watchModerationStatus().listen((status) {
      _handleStreamUpdate(status);
    });

    // Clean up subscription when provider is disposed
    ref.onDispose(() {
      subscription.cancel();
    });

    // Initial fetch with full details (Cloud Function is authoritative)
    try {
      final fullStatus = await service.getModerationStatus();
      final enriched = _enrichWithHistory(fullStatus);

      // Track severe status
      if (_isSevereStatus(enriched)) {
        _lastKnownSevereStatus = enriched;
      }

      return enriched;
    } catch (e) {
      AppLogging.social('Error fetching moderation status: $e');
      // Return last known severe status if we had one (prevents flicker)
      if (_lastKnownSevereStatus != null) {
        return _lastKnownSevereStatus;
      }
      return null;
    }
  }

  /// Handle stream updates - only update if data is "more severe" or matches
  void _handleStreamUpdate(ModerationStatus? status) {
    if (status == null) return;

    final currentStatus = state.maybeWhen(data: (s) => s, orElse: () => null);

    // If current status is suspended/banned, don't let stream downgrade it
    // unless the stream ALSO shows suspended/banned (real lift)
    if (currentStatus != null && _isSevereStatus(currentStatus)) {
      if (!_isSevereStatus(status)) {
        // Stream is trying to downgrade from severe - ignore it
        // This prevents the flicker where Firestore hasn't synced yet
        AppLogging.social(
          '[ModerationStatus] Ignoring stream downgrade from severe status',
        );
        return;
      }
    }

    // Stream has actual data - update if it shows issues
    if (_hasActualModerationData(status)) {
      _enrichStatus(status);
      _lastKnownSevereStatus = status;
    }
  }

  /// Check if status represents a severe restriction (suspended or banned)
  bool _isSevereStatus(ModerationStatus status) {
    return status.isSuspended || status.isPermanentlyBanned;
  }

  /// Check if status has actual moderation data (not just default clear status)
  bool _hasActualModerationData(ModerationStatus status) {
    return status.activeStrikes > 0 ||
        status.activeWarnings > 0 ||
        status.isSuspended ||
        status.isPermanentlyBanned;
  }

  /// Enrich status from stream with unacknowledged count
  Future<void> _enrichStatus(ModerationStatus status) async {
    final service = ref.read(contentModerationServiceProvider);
    try {
      final strikes = await service.getUnacknowledgedStrikes();
      final history = strikes
          .map((s) => ModerationHistoryItem.fromStrike(s))
          .toList();

      state = AsyncData(
        ModerationStatus(
          activeStrikes: status.activeStrikes,
          activeWarnings: status.activeWarnings,
          isSuspended: status.isSuspended,
          suspendedUntil: status.suspendedUntil,
          isPermanentlyBanned: status.isPermanentlyBanned,
          strikes: strikes,
          unacknowledgedCount: strikes.where((s) => !s.acknowledged).length,
          lastReason: strikes.isNotEmpty ? strikes.first.reason : null,
          history: history,
        ),
      );
    } catch (e) {
      // Use basic status if enrichment fails
      state = AsyncData(status);
    }
  }

  /// Enrich full status with history items
  ModerationStatus _enrichWithHistory(ModerationStatus status) {
    final history = status.strikes
        .map((s) => ModerationHistoryItem.fromStrike(s))
        .toList();

    return ModerationStatus(
      activeStrikes: status.activeStrikes,
      activeWarnings: status.activeWarnings,
      isSuspended: status.isSuspended,
      suspendedUntil: status.suspendedUntil,
      isPermanentlyBanned: status.isPermanentlyBanned,
      strikes: status.strikes,
      unacknowledgedCount: status.strikes.where((s) => !s.acknowledged).length,
      lastReason: status.strikes.isNotEmpty
          ? status.strikes.first.reason
          : null,
      history: history,
    );
  }

  /// Acknowledge all unacknowledged strikes/warnings
  Future<void> acknowledgeAll() async {
    final currentStatus = state.maybeWhen(
      data: (status) => status,
      orElse: () => null,
    );
    if (currentStatus == null) return;

    // Find unacknowledged strikes
    final unacknowledged = currentStatus.strikes.where((s) => !s.acknowledged);
    if (unacknowledged.isEmpty) {
      // Nothing to acknowledge - don't invalidate (prevents flash)
      return;
    }

    final service = ref.read(contentModerationServiceProvider);
    for (final strike in unacknowledged) {
      try {
        await service.acknowledgeStrike(strike.id);
      } catch (e) {
        AppLogging.social('Error acknowledging strike ${strike.id}: $e');
      }
    }

    // Update local state immediately instead of full invalidation
    // This prevents the flash from re-fetching
    state = AsyncData(
      ModerationStatus(
        activeStrikes: currentStatus.activeStrikes,
        activeWarnings: currentStatus.activeWarnings,
        isSuspended: currentStatus.isSuspended,
        suspendedUntil: currentStatus.suspendedUntil,
        isPermanentlyBanned: currentStatus.isPermanentlyBanned,
        strikes: currentStatus.strikes
            .map(
              (s) => UserStrike(
                id: s.id,
                userId: s.userId,
                type: s.type,
                reason: s.reason,
                createdAt: s.createdAt,
                expiresAt: s.expiresAt,
                contentId: s.contentId,
                contentType: s.contentType,
                acknowledged: true, // Mark all as acknowledged
              ),
            )
            .toList(),
        unacknowledgedCount: 0,
        lastReason: currentStatus.lastReason,
        history: currentStatus.history,
      ),
    );
  }

  /// Acknowledge a specific strike
  Future<void> acknowledgeStrike(String strikeId) async {
    final currentStatus = state.maybeWhen(
      data: (status) => status,
      orElse: () => null,
    );

    final service = ref.read(contentModerationServiceProvider);
    await service.acknowledgeStrike(strikeId);

    // Update local state immediately instead of invalidating
    if (currentStatus != null) {
      final updatedStrikes = currentStatus.strikes.map((s) {
        if (s.id == strikeId) {
          return UserStrike(
            id: s.id,
            userId: s.userId,
            type: s.type,
            reason: s.reason,
            createdAt: s.createdAt,
            expiresAt: s.expiresAt,
            contentId: s.contentId,
            contentType: s.contentType,
            acknowledged: true,
          );
        }
        return s;
      }).toList();

      state = AsyncData(
        ModerationStatus(
          activeStrikes: currentStatus.activeStrikes,
          activeWarnings: currentStatus.activeWarnings,
          isSuspended: currentStatus.isSuspended,
          suspendedUntil: currentStatus.suspendedUntil,
          isPermanentlyBanned: currentStatus.isPermanentlyBanned,
          strikes: updatedStrikes,
          unacknowledgedCount: updatedStrikes
              .where((s) => !s.acknowledged)
              .length,
          lastReason: currentStatus.lastReason,
          history: currentStatus.history,
        ),
      );
    }
  }
}

/// Provider for the current user's moderation status.
/// Uses AsyncNotifier for rich functionality including acknowledgment.
final moderationStatusProvider =
    AsyncNotifierProvider<ModerationStatusNotifier, ModerationStatus?>(
      ModerationStatusNotifier.new,
    );

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
