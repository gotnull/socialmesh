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
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';
import '../../map/map_screen.dart';
import '../../messaging/messaging_screen.dart'
    show ChatScreen, ConversationType;
import '../../profile/profile_screen.dart';
import '../../settings/linked_devices_screen.dart';
import '../../settings/settings_screen.dart';
import '../widgets/follow_button.dart';
import '../widgets/post_card.dart';
import '../widgets/post_skeleton.dart';
import 'create_post_screen.dart';
import 'followers_screen.dart';
import 'post_detail_screen.dart';

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
          final isFollower = followState?.isFollowedBy ?? false;
          final isFollowing = followState?.isFollowing ?? false;

          return RefreshIndicator(
            onRefresh: () async {
              ref
                  .read(profileCountAdjustmentsProvider.notifier)
                  .reset(widget.userId);
              ref.invalidate(publicProfileStreamProvider(widget.userId));
              await ref
                  .read(userPostsNotifierProvider.notifier)
                  .refresh(widget.userId);
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
                if (isOwnProfile || isFollower)
                  SliverToBoxAdapter(
                    child: _LinkedDevicesSection(
                      linkedNodeIds: profile.linkedNodeIds,
                      primaryNodeId: profile.primaryNodeId,
                      isOwnProfile: isOwnProfile,
                      onManageDevices: () => _navigateToLinkedDevices(),
                    ),
                  ),
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
                _buildPostsSliver(context, postsState, isOwnProfile),
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
      leading: isOwnProfile
          ? IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            )
          : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            icon: Icon(Icons.add_box_outlined, color: context.textPrimary),
            onPressed: _navigateToCreatePost,
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: context.textPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
              // Avatar
              GestureDetector(
                onTap: isOwnProfile ? _navigateToEditProfile : null,
                child: Stack(
                  children: [
                    CircleAvatar(
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
                    ),
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

  Widget _buildPostsSliver(
    BuildContext context,
    UserPostsState postsState,
    bool isOwnProfile,
  ) {
    if (postsState.posts.isEmpty && postsState.isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 16),
          child: PostSkeletonList(count: 3),
        ),
      );
    }

    if (postsState.posts.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyPosts(context, isOwnProfile),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index >= postsState.posts.length) {
          return postsState.hasMore
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : const SizedBox.shrink();
        }

        final post = postsState.posts[index];
        return PostCard(
          post: post,
          onTap: () => _navigateToPost(post),
          onAuthorTap: () {},
          onCommentTap: () => _navigateToPost(post, focusComment: true),
          onShareTap: () => _sharePost(post),
          onMoreTap: () => _showPostOptions(post, isOwnProfile),
          onLocationTap: _handleLocationTap,
          onNodeTap: _handleNodeTap,
        );
      }, childCount: postsState.posts.length + (postsState.hasMore ? 1 : 0)),
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

  void _sharePost(Post post) {
    ref.read(shareLinkServiceProvider).sharePost(postId: post.id);
  }

  void _handleLocationTap(PostLocation location) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialLatitude: location.latitude,
          initialLongitude: location.longitude,
          initialLocationLabel: location.name,
        ),
      ),
    );
  }

  void _handleNodeTap(String nodeId) {
    // nodeId is stored as hex string (e.g., "A1B2C3D4")
    final nodeNum = int.tryParse(nodeId, radix: 16);
    if (nodeNum == null) {
      showErrorSnackBar(context, 'Invalid node ID');
      return;
    }

    final nodes = ref.read(nodesProvider);
    final node = nodes[nodeNum];

    AppBottomSheet.showActions(
      context: context,
      header: Text(
        node?.longName ?? 'Node $nodeId',
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
                nodeNum: nodeNum,
                title: node?.longName ?? 'Node $nodeId',
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
                builder: (_) => MapScreen(initialNodeNum: nodeNum),
              ),
            ),
          ),
      ],
    );
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

  void _showPostOptions(Post post, bool isOwnPost) {
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
            if (isOwnPost)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppTheme.errorRed,
                ),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeletePost(post);
                },
              ),
            if (!isOwnPost)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(post.id, post.authorId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _sharePost(post);
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

  Future<void> _reportPost(String postId, String authorId) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Report Post',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Why are you reporting this post?',
              style: TextStyle(color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Describe the issue...',
                border: const OutlineInputBorder(),
                hintStyle: TextStyle(color: context.textTertiary),
              ),
              style: TextStyle(color: context.textPrimary),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: context.accentColor),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (reason != null && reason.isNotEmpty && mounted) {
      try {
        final socialService = ref.read(socialServiceProvider);
        await socialService.reportPost(postId, reason);
        if (mounted) {
          showSuccessSnackBar(context, 'Report submitted. Thank you.');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to report: $e');
        }
      }
    }
  }

  Future<void> _confirmDeletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Post',
          style: TextStyle(color: context.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this post?',
          style: TextStyle(color: context.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: context.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final socialService = ref.read(socialServiceProvider);
        ref
            .read(userPostsNotifierProvider.notifier)
            .removePost(widget.userId, post.id);
        await socialService.deletePost(post.id);

        final currentProfile = ref
            .read(publicProfileStreamProvider(post.authorId))
            .value;
        final currentCount = currentProfile?.postCount ?? 0;
        ref
            .read(profileCountAdjustmentsProvider.notifier)
            .decrement(post.authorId, currentCount);

        if (mounted) {
          showSuccessSnackBar(context, 'Post deleted');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Failed to delete: $e');
        }
      }
    }
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
            Stack(
              children: [
                NodeAvatar(
                  text: node?.avatarName ?? nodeId.toRadixString(16)[0],
                  color: _getNodeColor(nodeId),
                  size: 44,
                ),
                // Online indicator
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOnline
                          ? AccentColors.green
                          : context.textTertiary,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.background, width: 2),
                    ),
                  ),
                ),
                // Primary badge
                if (isPrimary)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
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
                    ),
                  ),
              ],
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
