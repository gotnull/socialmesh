import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../models/story.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/story_providers.dart';
import '../screens/create_story_screen.dart';
import '../screens/story_viewer_screen.dart';
import 'story_avatar.dart';

/// Horizontal scrollable bar showing story avatars at the top of the social feed.
///
/// Displays:
/// - Current user's "Add Story" button (always first)
/// - Story groups from followed users
/// - Unviewed stories have gradient rings
/// - Viewed stories have gray rings
class StoryBar extends ConsumerWidget {
  const StoryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final storyGroupsState = ref.watch(storyGroupsProvider);
    final myStoriesAsync = ref.watch(
      myStoriesProvider,
    ); // Direct stream of own stories
    final myAvatarUrl = ref.watch(profileAvatarUrlProvider);

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    final myGroup = ref.watch(myStoryGroupProvider);
    final followingGroups = ref.watch(followingStoryGroupsProvider);

    // Check if user has stories from direct provider (more reliable)
    final hasOwnStories = myStoriesAsync.when(
      data: (stories) => stories.isNotEmpty,
      loading: () => myGroup?.stories.isNotEmpty ?? false,
      error: (_, _) => false,
    );

    // Show loading shimmer if loading and no data yet
    if (storyGroupsState.isLoading && storyGroupsState.groups.isEmpty) {
      return const _StoryBarShimmer();
    }

    // Show nothing if there are no stories and user hasn't posted
    // (we still show the add button though)
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 1 + followingGroups.length, // +1 for add/own story button
        itemBuilder: (context, index) {
          if (index == 0) {
            // "Add Story" / Own stories button
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: StoryAvatar(
                userId: currentUser.uid,
                avatarUrl: myAvatarUrl,
                displayName: hasOwnStories ? 'Your story' : 'Add story',
                hasUnviewed: hasOwnStories,
                isAddButton: !hasOwnStories,
                onTap: () => _onOwnStoryTap(context, myGroup, myStoriesAsync),
              ),
            );
          }

          final group = followingGroups[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AnimatedStoryAvatar(
              storyGroup: group,
              onTap: () =>
                  _onStoryGroupTap(context, ref, group, followingGroups),
            ),
          );
        },
      ),
    );
  }

  void _onOwnStoryTap(
    BuildContext context,
    StoryGroup? myGroup,
    AsyncValue<List<Story>> myStoriesAsync,
  ) {
    final stories = myStoriesAsync.when(
      data: (list) => list,
      loading: () => <Story>[],
      error: (_, _) => <Story>[],
    );

    if (stories.isNotEmpty) {
      // View own stories
      final group =
          myGroup ??
          StoryGroup(
            userId: stories.first.authorId,
            stories: stories,
            lastStoryAt: stories.first.createdAt,
            profile: stories.first.authorSnapshot,
          );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StoryViewerScreen(storyGroups: [group], initialGroupIndex: 0),
        ),
      );
    } else {
      // No stories - create new story
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreateStoryScreen()),
      );
    }
  }

  void _onStoryGroupTap(
    BuildContext context,
    WidgetRef ref,
    StoryGroup group,
    List<StoryGroup> allGroups,
  ) {
    final index = allGroups.indexOf(group);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryViewerScreen(
          storyGroups: allGroups,
          initialGroupIndex: index >= 0 ? index : 0,
        ),
      ),
    );
  }
}

/// Compact story bar variant for profile pages
class CompactStoryBar extends ConsumerWidget {
  const CompactStoryBar({
    super.key,
    required this.userId,
    this.showAddButton = false,
  });

  final String userId;
  final bool showAddButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storiesAsync = ref.watch(userStoriesProvider(userId));
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.uid == userId;

    return storiesAsync.when(
      data: (stories) {
        if (stories.isEmpty && !showAddButton) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              if (isOwnProfile && showAddButton)
                _AddStoryButton(
                  hasStories: stories.isNotEmpty,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateStoryScreen(),
                      ),
                    );
                  },
                ),
              if (stories.isNotEmpty)
                Expanded(
                  child: SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 8),
                      itemCount: stories.length,
                      itemBuilder: (context, index) {
                        final story = stories[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _StoryThumbnail(
                            story: story,
                            onTap: () {
                              final group = StoryGroup(
                                userId: userId,
                                stories: stories,
                                lastStoryAt: stories.first.createdAt,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StoryViewerScreen(
                                    storyGroups: [group],
                                    initialGroupIndex: 0,
                                    initialStoryIndex: index,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 80),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _AddStoryButton extends StatelessWidget {
  const _AddStoryButton({required this.hasStories, required this.onTap});

  final bool hasStories;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 80,
        margin: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.brandGradientHorizontal,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(color: context.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryThumbnail extends StatelessWidget {
  const _StoryThumbnail({required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                story.thumbnailUrl ?? story.mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: context.card,
                  child: Icon(
                    story.isVideo ? Icons.videocam : Icons.image,
                    color: context.textTertiary,
                  ),
                ),
              ),
              if (story.isVideo)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shimmer loading state for story bar
class _StoryBarShimmer extends StatelessWidget {
  const _StoryBarShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.card,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 48,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
