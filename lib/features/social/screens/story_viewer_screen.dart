import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../models/story.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../providers/story_providers.dart';
import '../../../utils/snackbar.dart';
import 'profile_social_screen.dart';

/// Full-screen story viewer with auto-advance and swipe navigation.
///
/// Features:
/// - Progress bars showing story progress
/// - Auto-advance after duration
/// - Tap left/right to navigate
/// - Long press to pause
/// - Swipe down to close
/// - View count and viewers list for own stories
class StoryViewerScreen extends ConsumerStatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.storyGroups,
    this.initialGroupIndex = 0,
    this.initialStoryIndex = 0,
  });

  /// All story groups to display
  final List<StoryGroup> storyGroups;

  /// Which group to start with
  final int initialGroupIndex;

  /// Which story within the initial group to start with
  final int initialStoryIndex;

  @override
  ConsumerState<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends ConsumerState<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _groupPageController;
  late int _currentGroupIndex;
  late int _currentStoryIndex;
  late AnimationController _progressController;
  Timer? _autoAdvanceTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _currentGroupIndex = widget.initialGroupIndex;
    _currentStoryIndex = widget.initialStoryIndex;
    _groupPageController = PageController(
      initialPage: widget.initialGroupIndex,
    );

    _progressController = AnimationController(vsync: this);
    _progressController.addStatusListener(_onProgressComplete);

    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markCurrentStoryViewed();
      _startProgress();
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _progressController.removeStatusListener(_onProgressComplete);
    _progressController.dispose();
    _groupPageController.dispose();

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  StoryGroup get _currentGroup => widget.storyGroups[_currentGroupIndex];
  Story get _currentStory => _currentGroup.stories[_currentStoryIndex];
  bool get _isOwnStory =>
      _currentStory.authorId == ref.read(currentUserProvider)?.uid;

  void _startProgress() {
    final duration = Duration(seconds: _currentStory.duration);
    _progressController.duration = duration;
    _progressController.forward(from: 0);
  }

  void _pauseProgress() {
    _progressController.stop();
    setState(() => _isPaused = true);
  }

  void _resumeProgress() {
    _progressController.forward();
    setState(() => _isPaused = false);
  }

  void _onProgressComplete(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _goToNextStory();
    }
  }

  void _markCurrentStoryViewed() {
    if (!_isOwnStory) {
      markStoryViewed(ref, _currentStory.id);
    }
  }

  void _goToNextStory() {
    if (_currentStoryIndex < _currentGroup.stories.length - 1) {
      // Next story in current group
      setState(() => _currentStoryIndex++);
      _markCurrentStoryViewed();
      _startProgress();
    } else if (_currentGroupIndex < widget.storyGroups.length - 1) {
      // Next group
      setState(() {
        _currentGroupIndex++;
        _currentStoryIndex = 0;
      });
      _groupPageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _markCurrentStoryViewed();
      _startProgress();
    } else {
      // End of all stories
      Navigator.pop(context);
    }
  }

  void _goToPreviousStory() {
    if (_currentStoryIndex > 0) {
      // Previous story in current group
      setState(() => _currentStoryIndex--);
      _startProgress();
    } else if (_currentGroupIndex > 0) {
      // Previous group (last story)
      setState(() {
        _currentGroupIndex--;
        _currentStoryIndex = _currentGroup.stories.length - 1;
      });
      _groupPageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _startProgress();
    } else {
      // At the beginning, restart current story
      _startProgress();
    }
  }

  void _onTapDown(TapDownDetails details) {
    final width = MediaQuery.of(context).size.width;
    final tapX = details.globalPosition.dx;

    if (tapX < width * 0.3) {
      _goToPreviousStory();
    } else if (tapX > width * 0.7) {
      _goToNextStory();
    }
  }

  void _onGroupPageChanged(int index) {
    if (index != _currentGroupIndex) {
      setState(() {
        _currentGroupIndex = index;
        _currentStoryIndex = 0;
      });
      _markCurrentStoryViewed();
      _startProgress();
    }
  }

  void _showViewers() {
    AppBottomSheet.show(
      context: context,
      child: _ViewersSheet(storyId: _currentStory.id),
    );
  }

  void _showOptions() {
    // Capture values before showing sheet (for use in async callback)
    final storyId = _currentStory.id;
    final storyService = ref.read(storyServiceProvider);
    final story = _currentStory;
    final isOwnStory = _isOwnStory;

    final actions = <BottomSheetAction>[];

    // Delete option for own stories
    if (isOwnStory) {
      actions.add(
        BottomSheetAction(
          icon: Icons.delete_outline,
          label: 'Delete story',
          isDestructive: true,
          onTap: () async {
            final confirm = await AppBottomSheet.showConfirm(
              context: context,
              title: 'Delete story?',
              message: 'This story will be permanently deleted.',
              confirmLabel: 'Delete',
              isDestructive: true,
            );
            if (confirm == true && mounted) {
              try {
                await storyService.deleteStory(storyId);
                if (mounted) {
                  showSuccessSnackBar(context, 'Story deleted');
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  showErrorSnackBar(context, 'Failed to delete story: $e');
                }
              }
            }
          },
        ),
      );
    }

    // Location option
    if (story.location != null) {
      actions.add(
        BottomSheetAction(
          icon: Icons.location_on_outlined,
          label: story.location!.name ?? 'View location',
          subtitle:
              '${story.location!.latitude.toStringAsFixed(4)}, ${story.location!.longitude.toStringAsFixed(4)}',
        ),
      );
    }

    // Share option
    actions.add(
      BottomSheetAction(
        icon: Icons.share_outlined,
        label: 'Share',
        onTap: () {
          // Share functionality would go here
        },
      ),
    );

    // Report option for other people's stories
    if (!isOwnStory) {
      actions.add(
        BottomSheetAction(
          icon: Icons.flag_outlined,
          label: 'Report story',
          isDestructive: true,
          onTap: () => _reportStory(story),
        ),
      );
    }

    AppBottomSheet.showActions(context: context, actions: actions);
  }

  Future<void> _reportStory(Story story) async {
    final reason = await _showReportReasonPicker();
    if (reason == null || !mounted) return;

    try {
      final socialService = ref.read(socialServiceProvider);
      await socialService.reportStory(
        storyId: story.id,
        authorId: story.authorId,
        reason: reason,
        mediaUrl: story.mediaUrl,
        mediaType: story.mediaType.name,
      );

      if (mounted) {
        showSuccessSnackBar(context, 'Story reported. We\'ll review it soon.');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to report story: $e');
      }
    }
  }

  Future<String?> _showReportReasonPicker() async {
    return AppBottomSheet.showActions<String>(
      context: context,
      header: Text(
        'Why are you reporting this story?',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.warning_outlined,
          label: 'Spam or misleading',
          value: 'spam',
        ),
        BottomSheetAction(
          icon: Icons.person_off_outlined,
          label: 'Harassment or bullying',
          value: 'harassment',
        ),
        BottomSheetAction(
          icon: Icons.dangerous_outlined,
          label: 'Violence or dangerous content',
          value: 'violence',
        ),
        BottomSheetAction(
          icon: Icons.no_adult_content,
          label: 'Nudity or sexual content',
          value: 'nudity',
        ),
        BottomSheetAction(
          icon: Icons.copyright,
          label: 'Copyright violation',
          value: 'copyright',
        ),
        BottomSheetAction(
          icon: Icons.more_horiz,
          label: 'Other',
          value: 'other',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: (_) => _pauseProgress(),
        onLongPressEnd: (_) => _resumeProgress(),
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: PageView.builder(
          controller: _groupPageController,
          itemCount: widget.storyGroups.length,
          onPageChanged: _onGroupPageChanged,
          itemBuilder: (context, groupIndex) {
            final group = widget.storyGroups[groupIndex];
            final story = groupIndex == _currentGroupIndex
                ? _currentStory
                : group.stories.first;

            return Stack(
              fit: StackFit.expand,
              children: [
                // Story content
                _StoryContent(
                  story: story,
                  onLoadError: () {
                    // Image failed to load (likely removed by moderation)
                    // Skip to next story
                    if (groupIndex == _currentGroupIndex) {
                      _goToNextStory();
                    }
                  },
                ),

                // Gradient overlay for readability
                _GradientOverlay(),

                // Progress bars
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  right: 8,
                  child: _ProgressBars(
                    storyCount: group.stories.length,
                    currentIndex: groupIndex == _currentGroupIndex
                        ? _currentStoryIndex
                        : 0,
                    progress: groupIndex == _currentGroupIndex
                        ? _progressController
                        : null,
                  ),
                ),

                // Header (user info, close button)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 8,
                  right: 8,
                  child: _StoryHeader(
                    story: story,
                    onClose: () => Navigator.pop(context),
                    onOptions: _showOptions,
                    onProfileTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileSocialScreen(userId: story.authorId),
                        ),
                      );
                    },
                  ),
                ),

                // Footer (view count for own stories, like button for others)
                if (groupIndex == _currentGroupIndex)
                  Positioned(
                    bottom: MediaQuery.of(context).padding.bottom + 16,
                    left: 16,
                    right: 16,
                    child: _isOwnStory
                        ? _OwnerStoryFooter(
                            story: story,
                            onViewersTap: _showViewers,
                          )
                        : _ViewerStoryFooter(
                            story: story,
                            onLiked: () {
                              // Brief haptic feedback
                              HapticFeedback.lightImpact();
                            },
                          ),
                  ),

                // Pause indicator
                if (_isPaused)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.pause,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StoryContent extends StatefulWidget {
  const _StoryContent({required this.story, this.onLoadError});

  final Story story;
  final VoidCallback? onLoadError;

  @override
  State<_StoryContent> createState() => _StoryContentState();
}

class _StoryContentState extends State<_StoryContent> {
  bool _hasError = false;

  @override
  Widget build(BuildContext context) {
    // If image failed to load (likely removed by moderation), skip this story
    if (_hasError) {
      // Notify parent to skip to next story
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onLoadError?.call();
      });
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        widget.story.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (_, error, stackTrace) {
          // Mark as error and trigger skip
          if (!_hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() => _hasError = true);
                widget.onLoadError?.call();
              }
            });
          }
          // Show nothing while transitioning
          return Container(color: Colors.black);
        },
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        children: [
          // Top gradient
          Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
          const Spacer(),
          // Bottom gradient
          Container(
            height: 150,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({
    required this.storyCount,
    required this.currentIndex,
    this.progress,
  });

  final int storyCount;
  final int currentIndex;
  final AnimationController? progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(storyCount, (index) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index < storyCount - 1 ? 4 : 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                height: 3,
                child: index < currentIndex
                    ? Container(color: Colors.white)
                    : index == currentIndex && progress != null
                    ? AnimatedBuilder(
                        animation: progress!,
                        builder: (context, _) {
                          return LinearProgressIndicator(
                            value: progress!.value,
                            backgroundColor: Colors.white38,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          );
                        },
                      )
                    : Container(color: Colors.white38),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({
    required this.story,
    required this.onClose,
    required this.onOptions,
    required this.onProfileTap,
  });

  final Story story;
  final VoidCallback onClose;
  final VoidCallback onOptions;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onProfileTap,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: story.authorSnapshot?.avatarUrl != null
                    ? NetworkImage(story.authorSnapshot!.avatarUrl!)
                    : null,
                child: story.authorSnapshot?.avatarUrl == null
                    ? Text(
                        (story.authorSnapshot?.displayName ?? 'U')[0]
                            .toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        story.authorSnapshot?.displayName ?? 'User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (story.authorSnapshot?.isVerified ?? false) ...[
                        const SizedBox(width: 4),
                        const SimpleVerifiedBadge(size: 14),
                      ],
                    ],
                  ),
                  Text(
                    timeago.format(story.createdAt),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: onOptions,
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: onClose,
        ),
      ],
    );
  }
}

class _OwnerStoryFooter extends StatelessWidget {
  const _OwnerStoryFooter({required this.story, required this.onViewersTap});

  final Story story;
  final VoidCallback onViewersTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Views button
        GestureDetector(
          onTap: onViewersTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '${story.viewCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  story.viewCount == 1 ? 'view' : 'views',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ),
        if (story.likeCount > 0) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  '${story.likeCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ViewerStoryFooter extends ConsumerWidget {
  const _ViewerStoryFooter({required this.story, this.onLiked});

  final Story story;
  final VoidCallback? onLiked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLikedAsync = ref.watch(storyLikeStatusProvider(story.id));
    final isLiked = isLikedAsync.maybeWhen(data: (v) => v, orElse: () => false);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () async {
            final wasLiked = await toggleStoryLike(ref, story.id);
            if (wasLiked) {
              onLiked?.call();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isLiked
                  ? Colors.redAccent.withValues(alpha: 0.3)
                  : Colors.black38,
              borderRadius: BorderRadius.circular(28),
              border: isLiked
                  ? Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.5),
                      width: 1,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(isLiked),
                    color: isLiked ? Colors.redAccent : Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isLiked ? 'Liked' : 'Like',
                  style: TextStyle(
                    color: isLiked ? Colors.redAccent : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewersSheet extends ConsumerWidget {
  const _ViewersSheet({required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewersAsync = ref.watch(storyViewersProvider(storyId));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Viewers',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: context.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          Flexible(
            child: viewersAsync.when(
              data: (viewers) {
                if (viewers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_off_outlined,
                          size: 48,
                          color: context.textTertiary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No views yet',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: viewers.length,
                  itemBuilder: (context, index) {
                    final view = viewers[index];
                    return _ViewerTile(view: view);
                  },
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Error loading viewers',
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerTile extends ConsumerWidget {
  const _ViewerTile({required this.view});

  final StoryView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get profile for viewer
    final service = ref.watch(storyServiceProvider);

    return FutureBuilder(
      future: service.getPublicProfile(view.viewerId),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundImage: profile?.avatarUrl != null
                ? NetworkImage(profile!.avatarUrl!)
                : null,
            child: profile?.avatarUrl == null
                ? Text(
                    (profile?.displayName ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          title: Text(
            profile?.displayName ?? 'User',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            timeago.format(view.viewedAt),
            style: TextStyle(color: context.textTertiary, fontSize: 12),
          ),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileSocialScreen(userId: view.viewerId),
              ),
            );
          },
        );
      },
    );
  }
}
