import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/share_link_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../core/widgets/node_avatar.dart';
import '../../../models/mesh_models.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import '../../../services/user_presence_service.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';
import '../../map/map_screen.dart';
import '../../messaging/messaging_screen.dart'
    show ChatScreen, ConversationType;
import '../../navigation/main_shell.dart';
import '../../profile/profile_screen.dart';
import '../../settings/linked_devices_screen.dart';
import '../../settings/settings_screen.dart';
import '../widgets/follow_button.dart';
import 'create_post_screen.dart';
import 'follow_requests_screen.dart';
import 'followers_screen.dart';
import 'post_detail_screen.dart';
import 'user_search_screen.dart';

/// Social profile screen with followers, following, posts, and linked devices.
class ProfileSocialScreen extends ConsumerStatefulWidget {
  const ProfileSocialScreen({
    super.key,
    required this.userId,
    this.showAppBar = true,
  });

  final String userId;

  /// Whether to show the SliverAppBar. Set to false when embedding in tabs.
  final bool showAppBar;

  @override
  ConsumerState<ProfileSocialScreen> createState() =>
      _ProfileSocialScreenState();
}

class _ProfileSocialScreenState extends ConsumerState<ProfileSocialScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Force refresh streams to get latest data from server
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(publicProfileStreamProvider(widget.userId));
      ref.read(userPostsNotifierProvider.notifier).getOrCreate(widget.userId);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
            edgeOffset: widget.showAppBar
                ? 0
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
              slivers: [
                if (widget.showAppBar)
                  _buildSliverAppBar(context, profile, isOwnProfile),
                SliverToBoxAdapter(
                  child: _buildProfileHeader(
                    context,
                    profile,
                    isOwnProfile,
                    isFollowing,
                  ),
                ),
                // Linked devices - only visible to self or followers
                if (canViewContent)
                  SliverToBoxAdapter(
                    child: _LinkedDevicesSection(
                      linkedNodeIds: profile.linkedNodeIds,
                      primaryNodeId: profile.primaryNodeId,
                      isOwnProfile: isOwnProfile,
                      onManageDevices: () => _navigateToLinkedDevices(),
                    ),
                  ),
                // Posts section - only visible if allowed
                if (canViewContent) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.grid_on_outlined,
                            size: 16,
                            color: context.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Posts',
                            style: TextStyle(
                              color: context.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildPostsGrid(context, postsState, isOwnProfile),
                ] else
                  _buildPrivateAccountSliver(context, profile),
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
    return SliverAppBar(
      backgroundColor: context.background,
      floating: true,
      snap: true,
      leading: isOwnProfile ? const HamburgerMenuButton() : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (profile.isPrivate && !isOwnProfile) ...[
            Icon(Icons.lock_outline, color: context.textSecondary, size: 16),
            const SizedBox(width: 4),
          ],
          Text(
            profile.displayName,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (profile.isVerified) ...[
            const SizedBox(width: 4),
            Icon(Icons.verified, color: context.accentColor, size: 18),
          ],
        ],
      ),
      actions: [
        if (isOwnProfile) ...[
          IconButton(
            icon: Icon(Icons.search, color: context.textPrimary),
            onPressed: _navigateToUserSearch,
            tooltip: 'Search users',
          ),
          _FollowRequestsBadge(
            child: IconButton(
              icon: Icon(Icons.person_add_outlined, color: context.textPrimary),
              onPressed: _navigateToFollowRequests,
              tooltip: 'Follow requests',
            ),
          ),
          IconButton(
            icon: Icon(Icons.add_box_outlined, color: context.textPrimary),
            onPressed: _navigateToCreatePost,
            tooltip: 'Create post',
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
          // Top row: Avatar + Stats
          Row(
            children: [
              // Avatar with online status
              Consumer(
                builder: (context, ref, child) {
                  final isOnlineAsync = ref.watch(
                    userOnlineStatusProvider(widget.userId),
                  );
                  final isOnline =
                      isOnlineAsync.whenOrNull(data: (value) => value) ?? false;

                  debugPrint(
                    '🟢 Profile online status for ${widget.userId}: isOnline=$isOnline, asyncState=${isOnlineAsync.toString()}',
                  );

                  // Check for active stories here
                  // When stories are implemented, use this structure:
                  // final hasActiveStory = ...; // check story status
                  // if (hasActiveStory) {
                  //   avatarWidget = Container(
                  //     width: 88,
                  //     height: 88,
                  //     decoration: const BoxDecoration(
                  //       shape: BoxShape.circle,
                  //       gradient: LinearGradient(
                  //         begin: Alignment.topLeft,
                  //         end: Alignment.bottomRight,
                  //         colors: [
                  //           Color(0xFFFFD600), // Yellow
                  //           Color(0xFFFF7A00), // Orange
                  //           Color(0xFFFF0069), // Pink
                  //           Color(0xFFD300C5), // Purple
                  //         ],
                  //       ),
                  //     ),
                  //     padding: const EdgeInsets.all(3),
                  //     child: Container(
                  //       decoration: BoxDecoration(
                  //         color: context.background,
                  //         shape: BoxShape.circle,
                  //       ),
                  //       padding: const EdgeInsets.all(3),
                  //       child: CircleAvatar(
                  //         radius: 38,
                  //         backgroundColor: context.accentColor.withValues(alpha: 0.2),
                  //         backgroundImage: profile.avatarUrl != null
                  //             ? NetworkImage(profile.avatarUrl!)
                  //             : null,
                  //         child: profile.avatarUrl == null
                  //             ? Text(
                  //                 profile.displayName[0].toUpperCase(),
                  //                 style: TextStyle(
                  //                   fontSize: 32,
                  //                   fontWeight: FontWeight.bold,
                  //                   color: context.accentColor,
                  //                 ),
                  //               )
                  //             : null,
                  //       ),
                  //     ),
                  //   );
                  // } else if (isOnline) { ... green ring ... }
                  // else { ... no ring ... }

                  Widget avatarWidget;

                  if (isOnline) {
                    // Green ring for online status
                    avatarWidget = Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AccentColors.green,
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.background,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: context.accentColor.withValues(
                            alpha: 0.2,
                          ),
                          backgroundImage: profile.avatarUrl != null
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: profile.avatarUrl == null
                              ? Text(
                                  profile.displayName[0].toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: context.accentColor,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  } else {
                    // No ring when offline and no story
                    avatarWidget = CircleAvatar(
                      radius: 44,
                      backgroundColor: context.accentColor.withValues(
                        alpha: 0.2,
                      ),
                      backgroundImage: profile.avatarUrl != null
                          ? NetworkImage(profile.avatarUrl!)
                          : null,
                      child: profile.avatarUrl == null
                          ? Text(
                              profile.displayName[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: context.accentColor,
                              ),
                            )
                          : null,
                    );
                  }

                  return GestureDetector(
                    onTap: isOwnProfile ? _navigateToEditProfile : null,
                    child: Stack(
                      children: [
                        avatarWidget,
                        if (isOwnProfile)
                          Positioned(
                            bottom: 0,
                            right: 0,
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
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StatColumn(count: profile.postCount, label: 'Posts'),
                    _StatColumn(
                      count: profile.followerCount,
                      label: 'Followers',
                      onTap: () =>
                          _navigateToFollowers(FollowersScreenMode.followers),
                    ),
                    _StatColumn(
                      count: profile.followingCount,
                      label: 'Following',
                      onTap: () =>
                          _navigateToFollowers(FollowersScreenMode.following),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            profile.displayName,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Callsign
          if (profile.callsign != null && profile.callsign!.isNotEmpty) ...[
            const SizedBox(height: 2),
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

          // Website & Social Links
          if (profile.website != null ||
              (profile.socialLinks != null &&
                  !profile.socialLinks!.isEmpty)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (profile.website != null)
                  _ProfileLinkChip(
                    icon: Icons.link,
                    text: _formatUrl(profile.website!),
                    onTap: () => _launchUrl(profile.website!),
                  ),
                if (profile.socialLinks?.twitter != null)
                  _ProfileLinkChip(
                    icon: Icons.alternate_email,
                    text: '@${profile.socialLinks!.twitter}',
                    onTap: () => _launchUrl(
                      'https://twitter.com/${profile.socialLinks!.twitter}',
                    ),
                  ),
                if (profile.socialLinks?.mastodon != null)
                  _ProfileLinkChip(
                    icon: Icons.tag,
                    text: profile.socialLinks!.mastodon!,
                    onTap: null,
                  ),
                if (profile.socialLinks?.github != null)
                  _ProfileLinkChip(
                    icon: Icons.code,
                    text: profile.socialLinks!.github!,
                    onTap: () => _launchUrl(
                      'https://github.com/${profile.socialLinks!.github}',
                    ),
                  ),
                if (profile.socialLinks?.discord != null)
                  _ProfileLinkChip(
                    icon: Icons.discord,
                    text: profile.socialLinks!.discord!,
                    onTap: null,
                  ),
                if (profile.socialLinks?.telegram != null)
                  _ProfileLinkChip(
                    icon: Icons.send,
                    text: '@${profile.socialLinks!.telegram}',
                    onTap: () => _launchUrl(
                      'https://t.me/${profile.socialLinks!.telegram}',
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Action buttons
          if (isOwnProfile)
            Row(
              children: [
                Expanded(
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
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => ref
                      .read(shareLinkServiceProvider)
                      .shareProfile(
                        userId: widget.userId,
                        displayName: profile.displayName,
                      ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.textPrimary,
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Icon(Icons.share, size: 18),
                ),
              ],
            )
          else
            FollowButton(targetUserId: widget.userId),
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

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= postsState.posts.length) {
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

          final post = postsState.posts[index];
          return _PostGridTile(post: post, onTap: () => _navigateToPost(post));
        }, childCount: postsState.posts.length + (postsState.hasMore ? 1 : 0)),
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

  void _navigateToLinkedDevices() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LinkedDevicesScreen()),
    );
    // Refresh the profile stream when returning to pick up new linked devices
    ref.invalidate(publicProfileStreamProvider(widget.userId));
  }

  String _formatUrl(String url) {
    return url
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('www.', '');
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

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.count, required this.label, this.onTap});

  final int count;
  final String label;
  final VoidCallback? onTap;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
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
            label,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Section showing linked Meshtastic devices.
/// Only visible to followers or the profile owner.
class _LinkedDevicesSection extends ConsumerWidget {
  const _LinkedDevicesSection({
    required this.linkedNodeIds,
    required this.primaryNodeId,
    required this.isOwnProfile,
    this.onManageDevices,
  });

  final List<int> linkedNodeIds;
  final int? primaryNodeId;
  final bool isOwnProfile;
  final VoidCallback? onManageDevices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (linkedNodeIds.isEmpty) {
      if (!isOwnProfile) return const SizedBox.shrink();

      // Show "link your device" prompt for own profile
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: OutlinedButton.icon(
          onPressed: onManageDevices,
          icon: const Icon(Icons.add_link, size: 18),
          label: const Text('Link a Meshtastic device'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.accentColor,
            side: BorderSide(color: context.accentColor.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          ),
        ),
      );
    }

    final allNodes = ref.watch(nodesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.router_outlined,
                size: 16,
                color: context.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Linked Devices',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isOwnProfile)
                GestureDetector(
                  onTap: onManageDevices,
                  child: Text(
                    'Manage',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: linkedNodeIds.length,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final nodeId = linkedNodeIds[index];
                final node = allNodes[nodeId];
                final isPrimary = nodeId == primaryNodeId;

                return _LinkedDeviceChip(
                  nodeId: nodeId,
                  node: node,
                  isPrimary: isPrimary,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedDeviceChip extends StatelessWidget {
  const _LinkedDeviceChip({
    required this.nodeId,
    required this.node,
    required this.isPrimary,
  });

  final int nodeId;
  final MeshNode? node;
  final bool isPrimary;

  Color _getNodeColor(int nodeNum) {
    final colors = [
      const Color(0xFF5B4FCE),
      const Color(0xFFD946A6),
      const Color(0xFF3B82F6),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF10B981),
    ];
    return colors[nodeNum % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = node?.isOnline ?? false;

    return GestureDetector(
      onTap: () => _showNodeBottomSheet(context),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            NodeAvatar(
              text: node?.avatarName ?? nodeId.toRadixString(16)[0],
              color: _getNodeColor(nodeId),
              size: 44,
              showGradientBorder: true,
              showOnlineIndicator: true,
              onlineStatus: isOnline
                  ? OnlineStatus.online
                  : OnlineStatus.offline,
              batteryLevel: node?.batteryLevel,
              showBatteryBadge: false,
              badge: isPrimary
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: context.accentColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.background, width: 2),
                      ),
                      child: const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 8,
                      ),
                    )
                  : null,
              badgeAlignment: Alignment.topRight,
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 72,
              child: Center(
                child: AutoScrollText(
                  node?.longName ?? '!${nodeId.toRadixString(16)}',
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11,
                    fontFamily: node?.longName != null ? null : 'monospace',
                  ),
                  maxLines: 1,
                  velocity: 25.0,
                  fadeWidth: 10.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNodeBottomSheet(BuildContext context) {
    HapticFeedback.lightImpact();

    AppBottomSheet.showActions(
      context: context,
      header: Text(
        node?.displayName ?? '!${nodeId.toRadixString(16)}',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: context.textPrimary,
        ),
      ),
      actions: [
        BottomSheetAction(
          icon: Icons.message_outlined,
          iconColor: context.accentColor,
          label: 'Send Message',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                type: ConversationType.directMessage,
                nodeNum: nodeId,
                title: node?.displayName ?? '!${nodeId.toRadixString(16)}',
              ),
            ),
          ),
        ),
        if (node?.hasPosition == true)
          BottomSheetAction(
            icon: Icons.map_outlined,
            label: 'View on Map',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MapScreen(initialNodeNum: nodeId),
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact chip showing a social/website link.
class _ProfileLinkChip extends StatelessWidget {
  const _ProfileLinkChip({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.accentColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: onTap != null
                  ? context.accentColor
                  : context.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
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

/// Grid tile for a post in the profile grid.
class _PostGridTile extends StatelessWidget {
  const _PostGridTile({required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

          // Overlay with stats (shown on hover/tap for images)
          if (post.imageUrls.isNotEmpty)
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.0)),
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
