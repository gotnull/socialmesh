// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:social_media_buttons/social_media_icons.dart';
import '../../../services/share_link_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/content_moderation_warning.dart';
import '../../../core/widgets/default_banner.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../models/social.dart';
import '../../../providers/activity_providers.dart';
import '../../../services/user_presence_service.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';
import '../../../utils/validation.dart';
import '../../profile/profile_screen.dart';
import '../../settings/settings_screen.dart';
import '../widgets/follow_button.dart';
import '../widgets/subscribe_button.dart';
import '../widgets/moderation_status_banner.dart';
import '../widgets/story_bar.dart';
import 'activity_timeline_screen.dart';
import 'create_post_screen.dart';
import 'create_story_screen.dart';
import 'follow_requests_screen.dart';
import 'followers_screen.dart';
import 'post_detail_screen.dart';
import 'story_viewer_screen.dart';
import 'user_search_screen.dart';
import '../../../providers/story_providers.dart';
import '../../../models/story.dart';
import '../../navigation/main_shell.dart';

/// Filter options for posts
enum PostFilter {
  all('All'),
  photos('Photos'),
  location('Location'),
  nodes('Nodes');

  const PostFilter(this.label);
  final String label;
}

/// Social profile screen with followers, following, posts, and linked devices.
class ProfileSocialScreen extends ConsumerStatefulWidget {
  const ProfileSocialScreen({
    super.key,
    required this.userId,
    this.showAppBar = true,
    this.showStoryBar = false,
    this.showModerationBanner = false,
    this.showHamburgerMenu = false,
  });

  final String userId;

  /// Whether to show the SliverAppBar. Set to false when embedding in tabs.
  final bool showAppBar;

  /// Whether to show the StoryBar at the top (only for own profile in Social tab).
  final bool showStoryBar;

  /// Whether to show the moderation status banner (only for own profile in Social tab).
  final bool showModerationBanner;

  /// Whether to show the hamburger menu instead of back button (for main drawer screens).
  final bool showHamburgerMenu;

  @override
  ConsumerState<ProfileSocialScreen> createState() =>
      _ProfileSocialScreenState();
}

class _ProfileSocialScreenState extends ConsumerState<ProfileSocialScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late final TabController _tabController;
  PostFilter _selectedFilter = PostFilter.all;

  // Shattered ring animation
  AnimationController? _shatterController;
  bool _hasPlayedShatterAnimation = false;
  String? _lastProfileIdWithStories;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: PostFilter.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    // Force refresh streams to get latest data from server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(publicProfileStreamProvider(widget.userId));
      ref.read(userPostsNotifierProvider.notifier).getOrCreate(widget.userId);
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() => _selectedFilter = PostFilter.values[_tabController.index]);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _shatterController?.dispose();
    super.dispose();
  }

  void _initShatterAnimation() {
    _shatterController?.dispose();

    _shatterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _shatterController!.forward();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      ref.read(userPostsNotifierProvider.notifier).loadMore(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.uid == widget.userId;
    final profileAsync = ref.watch(optimisticProfileProvider(widget.userId));
    final postsState = ref.watch(userPostsStateProvider(widget.userId));
    final followStateAsync = isOwnProfile
        ? null
        : ref.watch(followStateProvider(widget.userId));

    return Scaffold(
      backgroundColor: context.background,
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return _buildProfileNotFound(context);
          }

          final followState = followStateAsync?.value;
          final isFollowing = followState?.isFollowing ?? false;

          // Check if we can see this profile's content
          // Private profiles only show content to followers
          final canViewContent =
              isOwnProfile || !profile.isPrivate || isFollowing;

          return RefreshIndicator(
            displacement: 40,
            edgeOffset: widget.showAppBar
                ? 220 +
                      MediaQuery.of(context)
                          .padding
                          .top // Banner height (180) + avatar overlap (40)
                : MediaQuery.of(context).padding.top,
            onRefresh: () async {
              ref
                  .read(profileCountAdjustmentsProvider.notifier)
                  .reset(widget.userId);
              ref.invalidate(publicProfileStreamProvider(widget.userId));
              if (canViewContent) {
                await ref
                    .read(userPostsNotifierProvider.notifier)
                    .refresh(widget.userId);
              }
              if (!isOwnProfile) {
                ref.invalidate(followStateProvider(widget.userId));
              }
            },
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (widget.showAppBar)
                  _buildSliverAppBar(context, profile, isOwnProfile),
                // Show StoryBar at top if enabled (for Social hub screen)
                if (widget.showStoryBar)
                  const SliverToBoxAdapter(child: StoryBar()),
                // Show moderation banner if enabled (for own profile)
                if (widget.showModerationBanner && isOwnProfile)
                  const SliverToBoxAdapter(child: ModerationStatusBanner()),
                SliverToBoxAdapter(
                  child: _buildProfileHeader(
                    context,
                    profile,
                    isOwnProfile,
                    isFollowing,
                  ),
                ),
                // Posts section - only visible if allowed
                if (canViewContent) ...[
                  // Posts filter tabs
                  SliverToBoxAdapter(
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorColor: context.accentColor,
                      labelColor: context.accentColor,
                      unselectedLabelColor: context.textSecondary,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                      dividerColor: context.border,
                      tabs: PostFilter.values
                          .map((filter) => Tab(text: filter.label))
                          .toList(),
                    ),
                  ),
                  _buildPostsGrid(context, postsState, isOwnProfile),
                ] else
                  _buildPrivateAccountSliver(context, profile),
                // Bottom safe area padding
                SliverPadding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(context, error),
      ),
    );
  }

  Widget _buildProfileNotFound(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: context.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'Profile not found',
            style: TextStyle(color: context.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Failed to load profile',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(color: context.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () =>
                  ref.invalidate(publicProfileStreamProvider(widget.userId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(
    BuildContext context,
    PublicProfile profile,
    bool isOwnProfile,
  ) {
    const bannerHeight = 180.0;
    const avatarSize = 80.0;
    const avatarOverlap = 40.0;

    return SliverAppBar(
      backgroundColor: context.background.withValues(alpha: 0.8),
      foregroundColor: context.textPrimary,
      pinned: true,
      expandedHeight: bannerHeight + avatarOverlap,
      collapsedHeight: kToolbarHeight,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: widget.showHamburgerMenu ? const HamburgerMenuButton() : null,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FlexibleSpaceBar(
            background: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                // Banner image with shimmer loading
                Positioned.fill(
                  bottom: avatarOverlap,
                  child: ClipRect(
                    child: BouncyTap(
                      onTap: isOwnProfile
                          ? () => _showBannerOptions(profile)
                          : null,
                      scaleFactor: 0.98,
                      enabled: isOwnProfile,
                      child: profile.bannerUrl != null
                          ? Image.network(
                              profile.bannerUrl!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              frameBuilder:
                                  (
                                    context,
                                    child,
                                    frame,
                                    wasSynchronouslyLoaded,
                                  ) {
                                    if (wasSynchronouslyLoaded) return child;
                                    return AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: frame != null
                                          ? child
                                          : const DefaultBanner(),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) =>
                                  const DefaultBanner(),
                            )
                          : const DefaultBanner(),
                    ),
                  ),
                ),
                // Gradient overlay for readability - fades into background at bottom
                Positioned.fill(
                  bottom: avatarOverlap,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.2),
                          Colors.transparent,
                          context.background.withValues(alpha: 0.7),
                          context.background,
                        ],
                        stops: const [0.0, 0.15, 0.4, 0.85, 1.0],
                      ),
                    ),
                  ),
                ),
                // Avatar overlapping the banner
                Positioned(
                  left: 16,
                  bottom: 0,
                  child: Consumer(
                    builder: (context, ref, _) {
                      // Check if user has stories
                      final userStoriesAsync = ref.watch(
                        userStoriesProvider(widget.userId),
                      );
                      final hasStories =
                          userStoriesAsync.whenOrNull(
                            data: (stories) => stories.isNotEmpty,
                          ) ??
                          false;

                      // Check if current user has viewed all stories
                      final viewedStoriesState = ref.watch(
                        viewedStoriesProvider,
                      );
                      final allViewed =
                          userStoriesAsync.whenOrNull(
                            data: (stories) => stories.every(
                              (s) => viewedStoriesState.hasViewed(s.id),
                            ),
                          ) ??
                          true;

                      final hasUnviewed = hasStories && !allViewed;
                      final accentColor = context.accentColor;
                      final gradientColors = AccentColors.gradientFor(
                        accentColor,
                      );

                      // Use same proportions as StoryAvatar for consistency
                      final ringWidth = avatarSize * 0.05;
                      final ringPadding = avatarSize * 0.04;
                      final totalRingSize =
                          avatarSize + (ringWidth + ringPadding) * 2;

                      // Trigger shatter animation on first visit with stories
                      if (hasStories &&
                          !isOwnProfile &&
                          _lastProfileIdWithStories != widget.userId) {
                        _lastProfileIdWithStories = widget.userId;
                        _hasPlayedShatterAnimation = false;
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _initShatterAnimation();
                            setState(() => _hasPlayedShatterAnimation = true);
                          }
                        });
                      }

                      // Determine if we should show the shatter animation
                      final showShatterAnimation =
                          hasStories &&
                          !isOwnProfile &&
                          _hasPlayedShatterAnimation &&
                          _shatterController != null;

                      return BouncyTap(
                        onTap: () {
                          if (hasStories) {
                            // Open story viewer
                            final stories = userStoriesAsync.value ?? [];
                            if (stories.isNotEmpty) {
                              final group = StoryGroup(
                                userId: widget.userId,
                                stories: stories,
                                lastStoryAt: stories.first.createdAt,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StoryViewerScreen(
                                    storyGroups: [group],
                                    initialGroupIndex: 0,
                                  ),
                                ),
                              );
                            }
                          } else if (isOwnProfile) {
                            // No stories - add new story
                            _navigateToCreateStory();
                          }
                        },
                        scaleFactor: 0.95,
                        // Always use totalRingSize for consistent layout (no shifting)
                        child: SizedBox(
                          width: totalRingSize + 8,
                          height: totalRingSize + 8,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.background,
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Gradient ring for stories (animated shatter effect or static)
                                // Always render the ring container for consistent sizing
                                if (hasStories)
                                  showShatterAnimation
                                      ? AnimatedBuilder(
                                          animation: _shatterController!,
                                          builder: (context, _) {
                                            return CustomPaint(
                                              size: Size(
                                                totalRingSize,
                                                totalRingSize,
                                              ),
                                              painter: _ShatteredRingPainter(
                                                progress:
                                                    _shatterController!.value,
                                                gradientColors: hasUnviewed
                                                    ? gradientColors
                                                    : [
                                                        Colors.grey.shade500,
                                                        Colors.grey.shade400,
                                                        Colors.grey.shade500,
                                                      ],
                                                ringWidth: ringWidth,
                                                backgroundColor:
                                                    context.background,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          width: totalRingSize,
                                          height: totalRingSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: hasUnviewed
                                                ? SweepGradient(
                                                    colors: [
                                                      gradientColors[0],
                                                      gradientColors[1],
                                                      gradientColors[2],
                                                      gradientColors[1],
                                                      gradientColors[0],
                                                    ],
                                                    stops: const [
                                                      0.0,
                                                      0.25,
                                                      0.5,
                                                      0.75,
                                                      1.0,
                                                    ],
                                                    // Offset seam to bottom where it's less visible
                                                    startAngle: math.pi / 2,
                                                  )
                                                : SweepGradient(
                                                    colors: [
                                                      Colors.grey.shade500,
                                                      Colors.grey.shade400,
                                                      Colors.grey.shade500,
                                                      Colors.grey.shade400,
                                                      Colors.grey.shade500,
                                                    ],
                                                    stops: const [
                                                      0.0,
                                                      0.25,
                                                      0.5,
                                                      0.75,
                                                      1.0,
                                                    ],
                                                    // Offset seam to bottom where it's less visible
                                                    startAngle: math.pi / 2,
                                                  ),
                                          ),
                                          child: Center(
                                            child: Container(
                                              width:
                                                  totalRingSize - ringWidth * 2,
                                              height:
                                                  totalRingSize - ringWidth * 2,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: context.background,
                                              ),
                                            ),
                                          ),
                                        ),
                                // Avatar with shimmer loading and scale-in animation
                                // Always positioned with ring offset for consistent placement
                                Positioned(
                                  left: ringWidth + ringPadding,
                                  top: ringWidth + ringPadding,
                                  child: ShimmerAvatar(
                                    imageUrl: profile.avatarUrl,
                                    radius: avatarSize / 2,
                                    fallbackText: profile.displayName[0]
                                        .toUpperCase(),
                                    backgroundColor: context.accentColor
                                        .withValues(alpha: 0.2),
                                    animateIn: true,
                                    animationDelay: const Duration(
                                      milliseconds: 100,
                                    ),
                                  ),
                                ),
                                // Add story button for own profile (always visible)
                                if (isOwnProfile)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: BouncyTap(
                                      onTap: _navigateToCreateStory,
                                      scaleFactor: 0.85,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: context.accentColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: context.background,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.add,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
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
              ],
            ),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profile.isPrivate) ...[
            Icon(Icons.lock, color: context.textPrimary, size: 16),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              profile.displayName,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (profile.isVerified || isAppOwner(profile.id)) ...[
            const SimpleVerifiedBadge(size: 18),
          ],
        ],
      ),
      centerTitle: true,
      actions: [
        if (isOwnProfile) ...[
          IconButton(
            icon: Icon(Icons.search, color: context.textPrimary),
            onPressed: _navigateToUserSearch,
            tooltip: 'Search',
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.textPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Settings',
          ),
        ] else ...[
          IconButton(
            icon: Icon(Icons.share_outlined, color: context.textPrimary),
            onPressed: () => _shareProfile(profile),
          ),
          IconButton(
            icon: Icon(Icons.more_vert, color: context.textPrimary),
            onPressed: () => _showProfileOptions(profile),
          ),
        ],
      ],
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    PublicProfile profile,
    bool isOwnProfile,
    bool isFollowing,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats row - full width, centered
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SlideInAnimation(
                delay: const Duration(milliseconds: 0),
                duration: const Duration(milliseconds: 300),
                beginOffset: const Offset(0, 0.3),
                child: Consumer(
                  builder: (context, ref, _) {
                    final postsState = ref.watch(
                      userPostsStateProvider(widget.userId),
                    );
                    return _StatColumn(
                      count: postsState.posts.length,
                      label: 'Posts',
                      singularLabel: 'Post',
                      onTap: null,
                    );
                  },
                ),
              ),
              SlideInAnimation(
                delay: const Duration(milliseconds: 50),
                duration: const Duration(milliseconds: 300),
                beginOffset: const Offset(0, 0.3),
                child: _StatColumn(
                  count: profile.followerCount,
                  label: 'Followers',
                  singularLabel: 'Follower',
                  onTap: () =>
                      _navigateToFollowers(FollowersScreenMode.followers),
                ),
              ),
              SlideInAnimation(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 300),
                beginOffset: const Offset(0, 0.3),
                child: _StatColumn(
                  count: profile.followingCount,
                  label: 'Following',
                  onTap: () =>
                      _navigateToFollowers(FollowersScreenMode.following),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Online status chip
          Consumer(
            builder: (context, ref, _) {
              final isOnlineAsync = ref.watch(
                userOnlineStatusProvider(widget.userId),
              );
              final isOnline =
                  isOnlineAsync.whenOrNull(data: (value) => value) ?? false;

              if (!isOnline) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AccentColors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AccentColors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AccentColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Online',
                        style: TextStyle(
                          color: AccentColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Callsign
          if (profile.callsign != null && profile.callsign!.isNotEmpty) ...[
            Text(
              profile.callsign!,
              style: TextStyle(
                color: context.accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              profile.bio!,
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
          ],

          // Joined date
          if (profile.createdAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: context.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Joined ${_formatJoinedDate(profile.createdAt!)}',
                  style: TextStyle(color: context.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ],

          // Website & Social Links - Horizontal scrollable circular icons
          if (profile.website != null ||
              (profile.socialLinks != null &&
                  !profile.socialLinks!.isEmpty)) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 44,
              child: EdgeFade.end(
                child: _AnimatedSocialIconsRow(
                  profile: profile,
                  onLaunchUrl: _launchUrl,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          if (isOwnProfile) ...[
            // Main action row with Edit profile and action icons
            Row(
              children: [
                Expanded(
                  child: SlideInAnimation(
                    delay: const Duration(milliseconds: 150),
                    duration: const Duration(milliseconds: 300),
                    beginOffset: const Offset(0, 0.3),
                    child: OutlinedButton(
                      onPressed: _navigateToEditProfile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        side: BorderSide(color: context.border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: const Text('Edit profile'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleInAnimation(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: _ActionIconButton(
                    icon: Icons.share,
                    onTap: () => ref
                        .read(shareLinkServiceProvider)
                        .shareProfile(
                          userId: widget.userId,
                          displayName: profile.displayName,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleInAnimation(
                  delay: const Duration(milliseconds: 250),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: _FollowRequestsBadge(
                    child: _ActionIconButton(
                      icon: Icons.person_add_outlined,
                      onTap: _navigateToFollowRequests,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleInAnimation(
                  delay: const Duration(milliseconds: 300),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: _ActivityBadge(
                    child: _ActionIconButton(
                      icon: Icons.favorite_border,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ActivityTimelineScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleInAnimation(
                  delay: const Duration(milliseconds: 350),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: _ActionIconButton(
                    icon: Icons.add_box_outlined,
                    onTap: _navigateToCreatePost,
                  ),
                ),
              ],
            ),
          ] else
            SlideInAnimation(
              delay: const Duration(milliseconds: 150),
              duration: const Duration(milliseconds: 300),
              beginOffset: const Offset(0, 0.3),
              child: Row(
                children: [
                  FollowButton(targetUserId: widget.userId),
                  const SizedBox(width: 8),
                  SubscribeButton(authorId: widget.userId),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid(
    BuildContext context,
    UserPostsState postsState,
    bool isOwnProfile,
  ) {
    if (postsState.posts.isEmpty && postsState.isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => Container(
              color: context.surface,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            childCount: 9,
          ),
        ),
      );
    }

    if (postsState.posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyPosts(context, isOwnProfile),
      );
    }

    // Filter posts based on selected filter
    final filteredPosts = _filterPosts(postsState.posts);

    if (filteredPosts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyFilteredPosts(context),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= filteredPosts.length) {
            return postsState.hasMore
                ? Container(
                    color: context.surface,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const SizedBox.shrink();
          }

          final post = filteredPosts[index];
          return _PostGridTile(post: post, onTap: () => _navigateToPost(post));
        }, childCount: filteredPosts.length + (postsState.hasMore ? 1 : 0)),
      ),
    );
  }

  List<Post> _filterPosts(List<Post> posts) {
    switch (_selectedFilter) {
      case PostFilter.all:
        return posts;
      case PostFilter.photos:
        return posts.where((p) => p.mediaUrls.isNotEmpty).toList();
      case PostFilter.location:
        return posts.where((p) => p.location != null).toList();
      case PostFilter.nodes:
        return posts.where((p) => p.nodeId != null).toList();
    }
  }

  Widget _buildEmptyFilteredPosts(BuildContext context) {
    final filterInfo = switch (_selectedFilter) {
      PostFilter.photos => (Icons.image_outlined, 'No photo posts'),
      PostFilter.location => (Icons.location_on_outlined, 'No location posts'),
      PostFilter.nodes => (Icons.router_outlined, 'No node posts'),
      PostFilter.all => (Icons.grid_on_outlined, 'No posts'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(filterInfo.$1, size: 48, color: context.textTertiary),
            const SizedBox(height: 16),
            Text(
              filterInfo.$2,
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different filter',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateAccountSliver(
    BuildContext context,
    PublicProfile profile,
  ) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.textTertiary, width: 2),
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: context.textTertiary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'This Account is Private',
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Follow ${profile.displayName} to see their posts and linked devices.',
                style: TextStyle(color: context.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyPosts(BuildContext context, bool isOwnProfile) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.textTertiary, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: 48,
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isOwnProfile ? 'Share your first post' : 'No posts yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isOwnProfile) ...[
              const SizedBox(height: 8),
              Text(
                'Share photos and stories about your mesh adventures',
                style: TextStyle(color: context.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _navigateToCreatePost,
                style: FilledButton.styleFrom(
                  backgroundColor: context.accentColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Create Post'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToFollowers(FollowersScreenMode mode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FollowersScreen(userId: widget.userId, initialMode: mode),
      ),
    );
  }

  void _navigateToPost(Post post, {bool focusComment = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(postId: post.id, focusCommentInput: focusComment),
      ),
    );
  }

  void _navigateToCreatePost() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );
  }

  void _navigateToUserSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserSearchScreen()),
    );
  }

  void _navigateToFollowRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FollowRequestsScreen()),
    );
  }

  void _navigateToEditProfile() {
    // Navigate to the main Profile screen for editing
    // This keeps profile data in ONE place
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  void _showBannerOptions(PublicProfile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.photo_library, color: context.accentColor),
              title: Text(
                profile.bannerUrl != null ? 'Change banner' : 'Add banner',
                style: TextStyle(color: context.textPrimary),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickBanner();
              },
            ),
            if (profile.bannerUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Remove banner',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeBanner();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBanner() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      try {
        final file = File(result.files.first.path!);
        await ref.read(userProfileProvider.notifier).saveBannerFromFile(file);
        ref.invalidate(userProfileProvider);
        ref.invalidate(publicProfileStreamProvider(widget.userId));
        if (mounted) {
          showSuccessSnackBar(context, 'Banner updated');
        }
      } catch (e) {
        if (mounted) {
          if (e.toString().contains('Content policy violation') ||
              e.toString().contains('violates content policy')) {
            await ContentModerationWarning.show(
              context,
              result: ContentModerationCheckResult(
                passed: false,
                action: 'reject',
                categories: ['Inappropriate Content'],
              ),
            );
          } else {
            showErrorSnackBar(context, 'Failed to upload banner: $e');
          }
        }
      }
    }
  }

  Future<void> _removeBanner() async {
    try {
      await ref.read(userProfileProvider.notifier).deleteBanner();
      ref.invalidate(userProfileProvider);
      ref.invalidate(publicProfileStreamProvider(widget.userId));
      if (mounted) {
        showSuccessSnackBar(context, 'Banner removed');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed to remove banner: $e');
      }
    }
  }

  void _navigateToCreateStory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateStoryScreen()),
    );
  }

  String _formatJoinedDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Future<void> _launchUrl(String url) async {
    final uri = url.startsWith('http')
        ? Uri.parse(url)
        : Uri.parse('https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _shareProfile(PublicProfile profile) {
    ref
        .read(shareLinkServiceProvider)
        .shareProfile(userId: profile.id, displayName: profile.displayName);
  }

  void _showProfileOptions(PublicProfile profile) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report'),
              onTap: () {
                Navigator.pop(context);
                _reportProfile(profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Block'),
              onTap: () {
                Navigator.pop(context);
                _blockUser(profile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
                _shareProfile(profile);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _reportProfile(PublicProfile profile) {
    showSuccessSnackBar(context, 'Report submitted');
  }

  void _blockUser(PublicProfile profile) {
    showSuccessSnackBar(context, '${profile.displayName} blocked');
  }
}

// ===========================================================================
// HELPER WIDGETS
// ===========================================================================

/// Compact action icon button for profile actions
class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.9,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: context.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: context.textPrimary, size: 20),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.count,
    required this.label,
    this.singularLabel,
    this.onTap,
  });

  final int count;
  final String label;
  final String? singularLabel;
  final VoidCallback? onTap;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _getLabel() {
    if (count == 1 && singularLabel != null) {
      return singularLabel!;
    }
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Text(
          _formatCount(count),
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _getLabel(),
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
      ],
    );

    if (onTap == null) return content;

    return BouncyTap(onTap: onTap, scaleFactor: 0.95, child: content);
  }
}

/// Compact chip showing a social/website link.
/// Sexy circular social icon button with brand color
class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Tooltip(
        message: tooltip,
        child: BouncyTap(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: onTap != null ? color : context.textTertiary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Animated row of social icons with staggered entry animation
class _AnimatedSocialIconsRow extends StatelessWidget {
  const _AnimatedSocialIconsRow({
    required this.profile,
    required this.onLaunchUrl,
  });

  final PublicProfile profile;
  final void Function(String url) onLaunchUrl;

  @override
  Widget build(BuildContext context) {
    final icons = <Widget>[];
    var index = 0;

    void addIcon(Widget icon) {
      icons.add(
        ScaleInAnimation(
          delay: Duration(milliseconds: 50 * index),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: icon,
        ),
      );
      index++;
    }

    if (profile.website != null) {
      addIcon(
        _SocialIconButton(
          icon: Icons.language,
          color: context.accentColor,
          onTap: () => onLaunchUrl(profile.website!),
          tooltip: _formatUrl(profile.website!),
        ),
      );
    }
    if (profile.socialLinks?.twitter != null) {
      addIcon(
        _SocialIconButton(
          icon: SocialMediaIcons.twitter,
          color: const Color(0xFF000000),
          onTap: () =>
              onLaunchUrl('https://x.com/${profile.socialLinks!.twitter}'),
          tooltip: '@${profile.socialLinks!.twitter}',
        ),
      );
    }
    if (profile.socialLinks?.github != null) {
      addIcon(
        _SocialIconButton(
          icon: SocialMediaIcons.github_circled,
          color: const Color(0xFF6E5494),
          onTap: () =>
              onLaunchUrl('https://github.com/${profile.socialLinks!.github}'),
          tooltip: profile.socialLinks!.github!,
        ),
      );
    }
    if (profile.socialLinks?.discord != null) {
      addIcon(
        _SocialIconButton(
          icon: Icons.discord,
          color: const Color(0xFF5865F2),
          onTap: () {
            Clipboard.setData(
              ClipboardData(text: profile.socialLinks!.discord!),
            );
            showInfoSnackBar(
              context,
              'Discord username copied: ${profile.socialLinks!.discord}',
              duration: const Duration(seconds: 2),
            );
          },
          tooltip: profile.socialLinks!.discord!,
        ),
      );
    }
    if (profile.socialLinks?.telegram != null) {
      addIcon(
        _SocialIconButton(
          icon: Icons.telegram,
          color: const Color(0xFF0088CC),
          onTap: () =>
              onLaunchUrl('https://t.me/${profile.socialLinks!.telegram}'),
          tooltip: '@${profile.socialLinks!.telegram}',
        ),
      );
    }
    if (profile.socialLinks?.linkedin != null) {
      addIcon(
        _SocialIconButton(
          icon: SocialMediaIcons.linkedin,
          color: const Color(0xFF0A66C2),
          onTap: () => onLaunchUrl(
            'https://linkedin.com/in/${profile.socialLinks!.linkedin}',
          ),
          tooltip: profile.socialLinks!.linkedin!,
        ),
      );
    }
    if (profile.socialLinks?.mastodon != null) {
      addIcon(
        _SocialIconButton(
          icon: Icons.tag,
          color: const Color(0xFF6364FF),
          onTap: null,
          tooltip: profile.socialLinks!.mastodon!,
        ),
      );
    }

    return ListView(scrollDirection: Axis.horizontal, children: icons);
  }

  static String _formatUrl(String url) {
    return url
        .replaceFirst('https://', '')
        .replaceFirst('http://', '')
        .replaceFirst('www.', '');
  }
}

/// Widget that shows a badge with pending follow requests count.
class _FollowRequestsBadge extends ConsumerWidget {
  const _FollowRequestsBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(pendingFollowRequestsCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) return child;
        return Badge(
          label: Text(count > 99 ? '99+' : count.toString()),
          child: child,
        );
      },
      loading: () => child,
      error: (_, _) => child,
    );
  }
}

/// Widget that shows a badge with unread activity count.
class _ActivityBadge extends ConsumerWidget {
  const _ActivityBadge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUnread = ref.watch(hasUnreadActivitiesProvider);

    if (!hasUnread) return child;
    // Show a simple dot badge for unread activities
    return Badge(
      backgroundColor: context.accentColor,
      smallSize: 10,
      child: child,
    );
  }
}

/// Grid tile for a post in the profile grid.
class _PostGridTile extends StatelessWidget {
  const _PostGridTile({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.95,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background - image or content preview
          if (post.imageUrls.isNotEmpty)
            Image.network(
              post.imageUrls.first,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildTextPreview(context),
            )
          else
            _buildTextPreview(context),

          // Overlay with gradient at top for icons visibility
          if (post.imageUrls.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 40,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

          // Multi-image indicator
          if (post.imageUrls.length > 1)
            Positioned(
              top: 8,
              right: 8,
              child: Icon(
                Icons.collections,
                color: Colors.white,
                size: 16,
                shadows: [
                  Shadow(
                    blurRadius: 4,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),

          // Node indicator
          if (post.nodeId != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.router, color: Colors.white, size: 14),
              ),
            ),

          // Location indicator
          if (post.location != null)
            Positioned(
              top: 8,
              left: post.nodeId != null ? 36 : 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),

          // Stats overlay at bottom for text posts
          if (post.imageUrls.isEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${post.likeCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextPreview(BuildContext context) {
    return Container(
      color: context.surface,
      padding: const EdgeInsets.all(8),
      child: Center(
        child: Text(
          post.content.isNotEmpty ? post.content : 'No content',
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 11,
            height: 1.3,
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// Custom painter that creates a "shattered glass" effect for the story ring.
/// The ring starts as broken fragments that fly in and assemble together.
class _ShatteredRingPainter extends CustomPainter {
  _ShatteredRingPainter({
    required this.progress,
    required this.gradientColors,
    required this.ringWidth,
    required this.backgroundColor,
  });

  final double progress;
  final List<Color> gradientColors;
  final double ringWidth;
  final Color backgroundColor;

  // Pre-defined shard configurations - 8 equal segments (12.5% each)
  static const _shardConfigs = [
    _ShardConfig(0.000, 0.125, 1.2, -0.35, 0.20), // Segment 1
    _ShardConfig(0.125, 0.250, 0.9, 0.40, 0.15), // Segment 2
    _ShardConfig(0.250, 0.375, 1.4, 0.30, -0.25), // Segment 3
    _ShardConfig(0.375, 0.500, 1.0, -0.20, -0.40), // Segment 4
    _ShardConfig(0.500, 0.625, 1.3, -0.45, -0.15), // Segment 5
    _ShardConfig(0.625, 0.750, 0.8, -0.30, 0.35), // Segment 6
    _ShardConfig(0.750, 0.875, 1.1, 0.25, 0.30), // Segment 7
    _ShardConfig(0.875, 1.000, 1.0, 0.15, -0.20), // Segment 8
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final innerRadius = outerRadius - ringWidth;

    // Create gradient shader - offset seam to bottom to match final state
    final gradient = SweepGradient(
      colors: [
        gradientColors[0],
        gradientColors[1],
        gradientColors[2],
        gradientColors[1],
        gradientColors[0],
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      startAngle: math.pi / 2,
    );

    final rect = Rect.fromCircle(center: center, radius: outerRadius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;

    // Background paint for inner circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    // When fully assembled, just draw a simple ring - no individual shards
    if (progress >= 1.0) {
      // Draw complete outer circle
      canvas.drawCircle(center, outerRadius, paint);
      // Cut out inner circle
      canvas.drawCircle(center, innerRadius, bgPaint);
      return;
    }

    // Apply easing curve for more satisfying animation
    final easedProgress = _easeOutBack(progress);

    // Draw each shard with its own animation offset
    for (final config in _shardConfigs) {
      _drawShard(
        canvas,
        center,
        outerRadius,
        innerRadius,
        config,
        easedProgress,
        paint,
      );
    }

    // Draw inner circle to create ring effect (cutout)
    canvas.drawCircle(center, innerRadius, bgPaint);

    // Draw particle effects during assembly
    if (progress > 0.3 && progress < 0.95) {
      _drawSparkles(canvas, center, outerRadius, progress);
    }
  }

  void _drawShard(
    Canvas canvas,
    Offset center,
    double outerRadius,
    double innerRadius,
    _ShardConfig config,
    double progress,
    Paint paint,
  ) {
    // Calculate shard's assembly progress with stagger
    final shardDelay = config.startAngle * 0.3;
    final shardProgress = ((progress - shardDelay) / (1 - shardDelay)).clamp(
      0.0,
      1.0,
    );

    if (shardProgress <= 0) return;

    // Calculate offset - starts far away and moves to center
    final distanceMultiplier = (1 - shardProgress) * config.distanceScale;
    final offsetX = config.offsetX * distanceMultiplier * outerRadius;
    final offsetY = config.offsetY * distanceMultiplier * outerRadius;

    // Rotation effect - shards rotate as they approach
    final rotation = (1 - shardProgress) * config.distanceScale * 0.5;

    // Scale effect - shards grow slightly as they approach
    final scale = 0.6 + (shardProgress * 0.4);

    canvas.save();

    // Apply transformations centered around the ring
    canvas.translate(center.dx, center.dy);
    canvas.translate(offsetX, offsetY);
    canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    // Draw the arc segment
    final startAngle = config.startAngle * 2 * math.pi - math.pi / 2;
    final sweepAngle = (config.endAngle - config.startAngle) * 2 * math.pi;

    final path = Path()
      ..moveTo(
        center.dx + innerRadius * math.cos(startAngle),
        center.dy + innerRadius * math.sin(startAngle),
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        sweepAngle,
        false,
      )
      ..arcTo(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle + sweepAngle,
        -sweepAngle,
        false,
      )
      ..close();

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawSparkles(
    Canvas canvas,
    Offset center,
    double radius,
    double progress,
  ) {
    final random = math.Random(42); // Fixed seed for consistent sparkles
    final sparkleProgress = ((progress - 0.3) / 0.65).clamp(0.0, 1.0);

    for (var i = 0; i < 12; i++) {
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = radius * (0.8 + random.nextDouble() * 0.4);
      final sparkleDelay = random.nextDouble() * 0.5;
      final sparkleAlpha = ((sparkleProgress - sparkleDelay) * 3).clamp(
        0.0,
        1.0,
      );

      if (sparkleAlpha <= 0) continue;

      final fadeOut = sparkleAlpha > 0.5 ? (1 - sparkleAlpha) * 2 : 1.0;
      final sparkleSize = 2 + random.nextDouble() * 2;

      final x = center.dx + math.cos(angle) * distance * sparkleProgress;
      final y = center.dy + math.sin(angle) * distance * sparkleProgress;

      final colorIndex = i % gradientColors.length;
      final sparklePaint = Paint()
        ..color = gradientColors[colorIndex].withValues(alpha: fadeOut * 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), sparkleSize * fadeOut, sparklePaint);
    }
  }

  // Smooth easing that settles perfectly at 1.0 without overshoot
  double _easeOutBack(double t) {
    // Use easeOutQuart - fast start, smooth landing
    // This ensures shards align perfectly at the end
    final t1 = 1 - t;
    return 1 - t1 * t1 * t1 * t1;
  }

  @override
  bool shouldRepaint(_ShatteredRingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Configuration for a single shard in the shattered ring effect
class _ShardConfig {
  const _ShardConfig(
    this.startAngle,
    this.endAngle,
    this.distanceScale,
    this.offsetX,
    this.offsetY,
  );

  /// Start angle as fraction of full circle (0.0 - 1.0)
  final double startAngle;

  /// End angle as fraction of full circle (0.0 - 1.0)
  final double endAngle;

  /// How far the shard starts from center (multiplier)
  final double distanceScale;

  /// X offset direction (-1.0 to 1.0)
  final double offsetX;

  /// Y offset direction (-1.0 to 1.0)
  final double offsetY;
}
