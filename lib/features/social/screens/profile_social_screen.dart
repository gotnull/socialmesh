import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/node_avatar.dart';
import '../../../models/mesh_models.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../profile/profile_screen.dart';
import '../../settings/linked_devices_screen.dart';
import '../../settings/settings_screen.dart';
import '../widgets/follow_button.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'followers_screen.dart';
import 'post_detail_screen.dart';

/// Instagram-style profile screen with followers, following, posts, and linked devices.
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
  @override
  void initState() {
    super.initState();
    // Force refresh streams to get latest data from server
    // DON'T reset optimistic adjustments here - the Firestore write may not have
    // synced yet. Keep the adjustment so the UI shows correct count until stream updates.
    // Adjustments are only reset on explicit pull-to-refresh.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(publicProfileStreamProvider(widget.userId));
      ref.invalidate(userPostsStreamProvider(widget.userId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.uid == widget.userId;
    // Use optimistic provider for instant post count updates
    final profileAsync = ref.watch(optimisticProfileProvider(widget.userId));
    final postsStream = ref.watch(userPostsStreamProvider(widget.userId));
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
              // Reset optimistic adjustments on refresh (stream will have latest)
              ref
                  .read(profileCountAdjustmentsProvider.notifier)
                  .reset(widget.userId);
              ref.invalidate(publicProfileStreamProvider(widget.userId));
              ref.invalidate(userPostsStreamProvider(widget.userId));
              if (!isOwnProfile) {
                ref.invalidate(followStateProvider(widget.userId));
              }
            },
            child: CustomScrollView(
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
                // Linked devices section (only visible to followers or own profile)
                if (isOwnProfile || isFollower)
                  SliverToBoxAdapter(
                    child: _LinkedDevicesSection(
                      linkedNodeIds: profile.linkedNodeIds,
                      primaryNodeId: profile.primaryNodeId,
                      isOwnProfile: isOwnProfile,
                    ),
                  ),
                // Posts section header
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
                // Posts list
                _buildPostsSliver(context, postsStream, isOwnProfile),
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
                  onPressed: () => Share.share(
                    'Check out my profile on Socialmesh!\nhttps://socialmesh.app/user/${widget.userId}',
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
    AsyncValue<List<Post>> postsAsync,
    bool isOwnProfile,
  ) {
    return postsAsync.when(
      data: (posts) {
        if (posts.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyPosts(context, isOwnProfile),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final post = posts[index];
            return PostCard(
              post: post,
              onTap: () => _navigateToPost(post),
              onAuthorTap: () {},
              onCommentTap: () => _navigateToPost(post, focusComment: true),
              onShareTap: () => _sharePost(post),
              onMoreTap: () => _showPostOptions(post, isOwnProfile),
            );
          }, childCount: posts.length),
        );
      },
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Failed to load posts',
            style: TextStyle(color: context.textSecondary),
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

  void _navigateToEditProfile() {
    // Navigate to the main Profile screen for editing
    // This keeps profile data in ONE place
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
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
    Share.share(
      'Check out ${profile.displayName} on Socialmesh!\nhttps://socialmesh.app/user/${profile.id}',
      subject: '${profile.displayName} on Socialmesh',
    );
  }

  void _sharePost(Post post) {
    Share.share(
      'Check out this post on Socialmesh!\nhttps://socialmesh.app/post/${post.id}',
      subject: 'Socialmesh Post',
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Report submitted')));
  }

  void _blockUser(PublicProfile profile) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${profile.displayName} blocked')));
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
        await socialService.deletePost(post.id);
        ref.invalidate(userPostsStreamProvider(widget.userId));

        // Apply optimistic post count decrement for instant UI feedback
        final currentProfile = ref
            .read(publicProfileStreamProvider(post.authorId))
            .value;
        final currentCount = currentProfile?.postCount ?? 0;
        ref
            .read(profileCountAdjustmentsProvider.notifier)
            .decrement(post.authorId, currentCount);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Post deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
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
  });

  final List<int> linkedNodeIds;
  final int? primaryNodeId;
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (linkedNodeIds.isEmpty) {
      if (!isOwnProfile) return const SizedBox.shrink();

      // Show "link your device" prompt for own profile
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LinkedDevicesScreen()),
          ),
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LinkedDevicesScreen(),
                    ),
                  ),
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

    return Container(
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
                    color: isOnline ? AccentColors.green : context.textTertiary,
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
                    child: const Icon(Icons.star, color: Colors.white, size: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            node?.shortName ?? '!${nodeId.toRadixString(16).substring(0, 4)}',
            style: TextStyle(color: context.textSecondary, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
