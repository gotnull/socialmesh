import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../models/story.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/story_providers.dart';
import '../screens/create_story_screen.dart';
import '../screens/story_viewer_screen.dart';
import 'story_avatar.dart';

/// Horizontal scrollable bar showing story avatars at the top of the social feed.
///
/// Displays:
/// - Story groups from followed users
/// - Unviewed stories have gradient rings
/// - Viewed stories have gray rings
class StoryBar extends ConsumerWidget {
  const StoryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final storyGroupsState = ref.watch(storyGroupsProvider);

    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    final followingGroups = ref.watch(followingStoryGroupsProvider);

    AppLogging.social(
      '📖 [StoryBar] Total groups: ${storyGroupsState.groups.length}, Following groups: ${followingGroups.length}',
    );
    for (final g in storyGroupsState.groups) {
      AppLogging.social(
        '📖 [StoryBar]   Group: ${g.userId}, stories: ${g.stories.length}',
      );
    }

    // Show loading shimmer if loading and no data yet
    if (storyGroupsState.isLoading && storyGroupsState.groups.isEmpty) {
      return const _StoryBarShimmer();
    }

    // Show nothing if there are no stories from others
    if (followingGroups.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 104,
        child: EdgeFade.end(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: followingGroups.length,
            itemBuilder: (context, index) {
              final group = followingGroups[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ScaleInAnimation(
                  delay: Duration(milliseconds: 50 * index.clamp(0, 10)),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: AnimatedStoryAvatar(
                    storyGroup: group,
                    onTap: () =>
                        _onStoryGroupTap(context, ref, group, followingGroups),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
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
    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.95,
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
    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.95,
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
    // Match actual StoryAvatar sizing: 64px avatar + ring (5% width + 4% padding on each side)
    const avatarSize = 64.0;
    const ringWidth = avatarSize * 0.05;
    const ringPadding = avatarSize * 0.04;
    const totalAvatarSize = avatarSize + (ringWidth + ringPadding) * 2;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 104,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _ShimmerEffect(
                delay: Duration(milliseconds: 100 * index),
                child: SizedBox(
                  width: totalAvatarSize,
                  child: Column(
                    children: [
                      Container(
                        width: totalAvatarSize,
                        height: totalAvatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.card,
                        ),
                      ),
                      const SizedBox(height: 6),
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Shimmer effect animation for loading placeholders
class _ShimmerEffect extends StatefulWidget {
  const _ShimmerEffect({required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _started = true;
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_started) return Opacity(opacity: 0.6, child: widget.child);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                context.card,
                context.card.withValues(alpha: 0.3),
                context.card,
              ],
              stops: [
                (_animation.value - 0.3).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}
