import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/social.dart';
import '../models/story.dart';
import '../services/story_service.dart';
import 'auth_providers.dart';

// ===========================================================================
// SERVICE PROVIDER
// ===========================================================================

/// Provider for the StoryService singleton.
final storyServiceProvider = Provider<StoryService>((ref) {
  return StoryService();
});

// ===========================================================================
// MY STORIES
// ===========================================================================

/// Stream provider for current user's active stories.
final myStoriesProvider = StreamProvider<List<Story>>((ref) {
  final service = ref.watch(storyServiceProvider);
  return service.watchMyStories();
});

// ===========================================================================
// STORY GROUPS
// ===========================================================================

/// State for story groups with loading/error handling.
class StoryGroupsState {
  final List<StoryGroup> groups;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;

  const StoryGroupsState({
    this.groups = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  StoryGroupsState copyWith({
    List<StoryGroup>? groups,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) {
    return StoryGroupsState(
      groups: groups ?? this.groups,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }
}

/// Notifier for story groups (the story bar data).
class StoryGroupsNotifier extends Notifier<StoryGroupsState> {
  StreamSubscription<List<StoryGroup>>? _subscription;

  @override
  StoryGroupsState build() {
    ref.onDispose(() => _subscription?.cancel());
    _startWatching();
    return const StoryGroupsState(isLoading: true);
  }

  void _startWatching() {
    final service = ref.read(storyServiceProvider);
    _subscription?.cancel();
    _subscription = service.watchStoryGroups().listen(
      (groups) {
        state = StoryGroupsState(groups: groups);
      },
      onError: (e) {
        state = StoryGroupsState(error: e.toString());
      },
    );
  }

  /// Refresh story groups
  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true);
    try {
      final service = ref.read(storyServiceProvider);
      final groups = await service.getStoryGroups();
      state = StoryGroupsState(groups: groups);
    } catch (e) {
      state = state.copyWith(isRefreshing: false, error: e.toString());
    }
  }

  /// Update a group's hasUnviewed status after viewing stories
  void markGroupViewed(String userId) {
    final updatedGroups = state.groups.map((group) {
      if (group.userId == userId) {
        return group.copyWith(hasUnviewed: false);
      }
      return group;
    }).toList();
    state = state.copyWith(groups: updatedGroups);
  }
}

/// Provider for story groups.
final storyGroupsProvider =
    NotifierProvider<StoryGroupsNotifier, StoryGroupsState>(
      StoryGroupsNotifier.new,
    );

// ===========================================================================
// VIEWED STORIES STATE
// ===========================================================================

/// Notifier for tracking which stories have been viewed locally.
/// This provides immediate UI feedback before server sync.
class ViewedStoriesNotifier extends Notifier<ViewedStoriesState> {
  @override
  ViewedStoriesState build() {
    return const ViewedStoriesState();
  }

  /// Mark a story as viewed (optimistic local update)
  void markViewed(String storyId) {
    state = state.markViewed(storyId);
  }

  /// Check if a story has been viewed locally
  bool hasViewed(String storyId) => state.hasViewed(storyId);
}

/// Provider for viewed stories state.
final viewedStoriesProvider =
    NotifierProvider<ViewedStoriesNotifier, ViewedStoriesState>(
      ViewedStoriesNotifier.new,
    );

// ===========================================================================
// STORY CREATION
// ===========================================================================

/// State for story creation process.
class CreateStoryState {
  final bool isUploading;
  final double uploadProgress;
  final String? error;
  final Story? createdStory;

  const CreateStoryState({
    this.isUploading = false,
    this.uploadProgress = 0,
    this.error,
    this.createdStory,
  });

  CreateStoryState copyWith({
    bool? isUploading,
    double? uploadProgress,
    String? error,
    Story? createdStory,
  }) {
    return CreateStoryState(
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      createdStory: createdStory ?? this.createdStory,
    );
  }
}

/// Notifier for creating stories.
class CreateStoryNotifier extends Notifier<CreateStoryState> {
  @override
  CreateStoryState build() {
    return const CreateStoryState();
  }

  /// Create a new story
  Future<Story?> createStory({
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
    state = const CreateStoryState(isUploading: true, uploadProgress: 0);

    try {
      final service = ref.read(storyServiceProvider);
      final story = await service.createStory(
        mediaFile: mediaFile,
        mediaType: mediaType,
        duration: duration,
        location: location,
        nodeId: nodeId,
        mentions: mentions,
        hashtags: hashtags,
        textOverlay: textOverlay,
        visibility: visibility,
      );

      state = CreateStoryState(createdStory: story);

      // Refresh story groups to include the new story
      ref.read(storyGroupsProvider.notifier).refresh();

      // Also invalidate user stories provider for the current user
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        ref.invalidate(userStoriesProvider(currentUser.uid));
      }

      return story;
    } catch (e) {
      state = CreateStoryState(error: e.toString());
      return null;
    }
  }

  /// Reset state after creation
  void reset() {
    state = const CreateStoryState();
  }
}

/// Provider for story creation.
final createStoryProvider =
    NotifierProvider<CreateStoryNotifier, CreateStoryState>(
      CreateStoryNotifier.new,
    );

// ===========================================================================
// STORY VIEWERS
// ===========================================================================

/// Provider for story viewers (for story owner).
final storyViewersProvider = StreamProvider.autoDispose
    .family<List<StoryView>, String>((ref, storyId) {
      final service = ref.watch(storyServiceProvider);
      return service.watchStoryViewers(storyId);
    });

// ===========================================================================
// STORY LIKES
// ===========================================================================

/// Provider to check if current user has liked a story.
final storyLikeStatusProvider = StreamProvider.autoDispose.family<bool, String>(
  (ref, storyId) {
    final service = ref.watch(storyServiceProvider);
    return service.watchStoryLikeStatus(storyId);
  },
);

/// Provider to get likes for a story.
final storyLikesProvider = FutureProvider.autoDispose
    .family<List<StoryLike>, String>((ref, storyId) async {
      final service = ref.watch(storyServiceProvider);
      return service.getStoryLikes(storyId);
    });

/// Like or unlike a story.
Future<bool> toggleStoryLike(WidgetRef ref, String storyId) async {
  final service = ref.read(storyServiceProvider);
  final isLiked = await service.hasLikedStory(storyId);

  if (isLiked) {
    await service.unlikeStory(storyId);
    return false;
  } else {
    await service.likeStory(storyId);
    return true;
  }
}

// ===========================================================================
// SINGLE USER'S STORIES
// ===========================================================================

/// Provider to get stories for a specific user.
/// Also pre-populates viewed state from server.
final userStoriesProvider = FutureProvider.autoDispose
    .family<List<Story>, String>((ref, userId) async {
      final service = ref.watch(storyServiceProvider);
      final stories = await service.getUserStories(userId);

      // Pre-populate viewed state from server
      if (stories.isNotEmpty) {
        final storyIds = stories.map((s) => s.id).toList();
        final viewedIds = await service.getViewedStoryIds(storyIds);
        final viewedNotifier = ref.read(viewedStoriesProvider.notifier);
        for (final id in viewedIds) {
          viewedNotifier.markViewed(id);
        }
      }

      return stories;
    });

// ===========================================================================
// STORY ACTIONS
// ===========================================================================

/// Mark a story as viewed (both local and server).
Future<void> markStoryViewed(WidgetRef ref, String storyId) async {
  // Optimistic local update
  ref.read(viewedStoriesProvider.notifier).markViewed(storyId);

  // Server update
  final service = ref.read(storyServiceProvider);
  await service.markStoryViewed(storyId);
}

/// Delete a story.
Future<void> deleteStory(WidgetRef ref, String storyId) async {
  debugPrint('🗑️ [deleteStory provider] Starting delete for storyId=$storyId');
  try {
    final service = ref.read(storyServiceProvider);
    debugPrint(
      '🗑️ [deleteStory provider] Got story service, calling deleteStory...',
    );
    await service.deleteStory(storyId);
    debugPrint('🗑️ [deleteStory provider] Service deleteStory completed');

    // Refresh story groups
    debugPrint('🗑️ [deleteStory provider] Refreshing story groups...');
    ref.read(storyGroupsProvider.notifier).refresh();
    debugPrint('🗑️ [deleteStory provider] Story groups refreshed');

    // Also invalidate user stories provider for the current user
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      debugPrint(
        '🗑️ [deleteStory provider] Invalidating userStoriesProvider for ${currentUser.uid}',
      );
      ref.invalidate(userStoriesProvider(currentUser.uid));
    }

    // Invalidate myStoriesProvider as well
    ref.invalidate(myStoriesProvider);
    debugPrint('🗑️ [deleteStory provider] All providers invalidated');
  } catch (e, stack) {
    debugPrint('🗑️ [deleteStory provider] ERROR: $e');
    debugPrint('🗑️ [deleteStory provider] Stack: $stack');
    rethrow;
  }
}

// ===========================================================================
// HELPER PROVIDERS
// ===========================================================================

/// Provider to check if current user has any active stories.
final hasActiveStoriesProvider = Provider<bool>((ref) {
  final myStories = ref.watch(myStoriesProvider);
  return myStories.when(
    data: (stories) => stories.isNotEmpty,
    loading: () => false,
    error: (error, stackTrace) => false,
  );
});

/// Provider to get the current user's story group (for "Add Story" display).
final myStoryGroupProvider = Provider<StoryGroup?>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return null;

  final groupsState = ref.watch(storyGroupsProvider);
  return groupsState.groups.cast<StoryGroup?>().firstWhere(
    (g) => g?.userId == currentUser.uid,
    orElse: () => null,
  );
});

/// Provider to get following users' story groups (excluding own).
/// All groups with stories are shown - viewed status affects ring color only.
final followingStoryGroupsProvider = Provider<List<StoryGroup>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return [];

  final groupsState = ref.watch(storyGroupsProvider);

  // Return all groups except own - don't filter by hasUnviewed
  // The ring color will show viewed/unviewed status
  return groupsState.groups.where((g) => g.userId != currentUser.uid).toList();
});
