import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../settings/settings_screen.dart';
import '../widgets/follow_button.dart';
import '../widgets/post_card.dart';
import '../widgets/social_stats_bar.dart';
import 'create_post_screen.dart';
import 'edit_profile_screen.dart';
import 'followers_screen.dart';
import 'post_detail_screen.dart';

/// Profile screen with social features (followers, following, posts).
class ProfileSocialScreen extends ConsumerStatefulWidget {
  const ProfileSocialScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<ProfileSocialScreen> createState() =>
      _ProfileSocialScreenState();
}

class _ProfileSocialScreenState extends ConsumerState<ProfileSocialScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final isOwnProfile = currentUser?.uid == widget.userId;

    final profileAsync = ref.watch(publicProfileProvider(widget.userId));
    final postsStream = ref.watch(userPostsStreamProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: profileAsync.when(
          data: (profile) => Text(profile?.displayName ?? 'Profile'),
          loading: () => const Text('Profile'),
          error: (_, _) => const Text('Profile'),
        ),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }
          return _buildProfileContent(
            context,
            profile,
            postsStream,
            isOwnProfile,
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load profile: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    ref.invalidate(publicProfileProvider(widget.userId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    PublicProfile profile,
    AsyncValue<List<Post>> postsAsync,
    bool isOwnProfile,
  ) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(publicProfileProvider(widget.userId));
        ref.invalidate(userPostsStreamProvider(widget.userId));
      },
      child: CustomScrollView(
        slivers: [
          // Profile header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: profile.avatarUrl != null
                        ? NetworkImage(profile.avatarUrl!)
                        : null,
                    child: profile.avatarUrl == null
                        ? Text(
                            profile.displayName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Name and verification
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        profile.displayName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.verified, color: theme.colorScheme.primary),
                      ],
                    ],
                  ),

                  // Callsign
                  if (profile.callsign != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      profile.callsign!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],

                  // Bio
                  if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      profile.bio!,
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Follow button or Edit profile
                  if (isOwnProfile)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditProfileScreen(profile: profile),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                    )
                  else
                    FollowButton(targetUserId: widget.userId),

                  const SizedBox(height: 16),

                  // Stats bar
                  SocialStatsBar(
                    followerCount: profile.followerCount,
                    followingCount: profile.followingCount,
                    postCount: profile.postCount,
                    onFollowersTap: () =>
                        _navigateToFollowers(FollowersScreenMode.followers),
                    onFollowingTap: () =>
                        _navigateToFollowers(FollowersScreenMode.following),
                    onPostsTap: () {
                      // Scroll to posts
                    },
                  ),
                ],
              ),
            ),
          ),

          // Posts section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Posts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (isOwnProfile)
                    TextButton.icon(
                      onPressed: _navigateToCreatePost,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New'),
                    ),
                ],
              ),
            ),
          ),

          // Posts list
          postsAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.article_outlined,
                          size: 48,
                          color: theme.colorScheme.primary.withAlpha(100),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isOwnProfile
                              ? 'You haven\'t posted yet'
                              : 'No posts yet',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.textTheme.bodyLarge?.color?.withAlpha(
                              150,
                            ),
                          ),
                        ),
                        if (isOwnProfile) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _navigateToCreatePost,
                            icon: const Icon(Icons.add),
                            label: const Text('Create Post'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final post = posts[index];
                  return PostCard(
                    post: post,
                    onTap: () => _navigateToPost(post),
                    onAuthorTap: () {}, // Already on profile
                    onCommentTap: () =>
                        _navigateToPost(post, focusComment: true),
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
              child: Center(child: Text('Failed to load posts: $error')),
            ),
          ),
        ],
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

  void _sharePost(Post post) {
    Share.share(
      'Check out this post on Socialmesh!\nhttps://socialmesh.app/post/${post.id}',
      subject: 'Socialmesh Post',
    );
  }

  void _showPostOptions(Post post, bool isOwnPost) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete Post',
                  style: TextStyle(color: Colors.red),
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
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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
