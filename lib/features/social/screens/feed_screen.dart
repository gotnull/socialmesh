import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme.dart';
import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../screens/create_post_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_social_screen.dart';
import '../widgets/post_card.dart';

/// The main social screen showing the current user's profile header with an explore feed.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _profileChecked = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _ensureProfileExists();
  }

  Future<void> _ensureProfileExists() async {
    if (_profileChecked) return;
    _profileChecked = true;

    try {
      final socialService = ref.read(socialServiceProvider);
      await socialService.ensureProfileExists();
    } catch (e) {
      debugPrint('Failed to ensure profile exists: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(exploreProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: context.background,
      body: currentUser == null
          ? _buildSignInPrompt(context)
          : _buildSocialContent(context, currentUser.uid),
      floatingActionButton: currentUser != null
          ? FloatingActionButton(
              onPressed: _navigateToCreatePost,
              backgroundColor: context.accentColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildSocialContent(BuildContext context, String userId) {
    final profileAsync = ref.watch(publicProfileProvider(userId));
    final exploreState = ref.watch(exploreProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(publicProfileProvider(userId));
        await ref.read(exploreProvider.notifier).refresh();
      },
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: context.background,
            floating: true,
            snap: true,
            title: Text(
              'Social',
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.person_outline, color: context.textPrimary),
                onPressed: () => _navigateToProfile(userId),
                tooltip: 'My Profile',
              ),
            ],
          ),

          // Profile summary card
          SliverToBoxAdapter(
            child: profileAsync.when(
              data: (profile) => profile != null
                  ? _ProfileSummaryCard(
                      profile: profile,
                      onTap: () => _navigateToProfile(userId),
                    )
                  : const SizedBox.shrink(),
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.explore, size: 20, color: context.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Explore',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Explore posts
          if (exploreState.posts.isEmpty && exploreState.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (exploreState.posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyExploreFeed(),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= exploreState.posts.length) {
                    return _buildLoadingIndicator();
                  }

                  final post = exploreState.posts[index];
                  return PostCard(
                    post: post,
                    onTap: () => _navigateToPost(post),
                    onAuthorTap: () => _navigateToProfile(post.authorId),
                    onCommentTap: () =>
                        _navigateToPost(post, focusComment: true),
                    onShareTap: () => _sharePost(post.id),
                    onMoreTap: () => _showPostOptions(post),
                  );
                },
                childCount:
                    exploreState.posts.length + (exploreState.hasMore ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_outline, size: 64, color: context.textTertiary),
            const SizedBox(height: 16),
            Text(
              'Sign in to access Social',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with other mesh users, share posts, and explore the community.',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyExploreFeed() {
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
                Icons.explore_outlined,
                size: 48,
                color: context.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No posts yet',
              style: TextStyle(
                color: context.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share something with the mesh community!',
              style: TextStyle(color: context.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _navigateToCreatePost,
              icon: const Icon(Icons.add),
              label: const Text('Create your first post'),
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
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

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSocialScreen(userId: userId),
      ),
    );
  }

  void _navigateToCreatePost() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );
    ref.read(exploreProvider.notifier).refresh();
  }

  void _sharePost(String postId) {
    Share.share(
      'Check out this post on Socialmesh!\nhttps://socialmesh.app/post/$postId',
      subject: 'Socialmesh Post',
    );
  }

  void _showPostOptions(Post post) {
    final currentUser = ref.read(currentUserProvider);
    final isOwnPost = currentUser?.uid == post.authorId;

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
            if (!isOwnPost) ...[
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Follow User'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  try {
                    await toggleFollow(ref, post.authorId);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Following user')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmBlockUser(post.authorId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(post.id, post.authorId);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _sharePost(post.id);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
        ref.read(exploreProvider.notifier).removePost(post.id);
        await ref.read(socialServiceProvider).deletePost(post.id);
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

  Future<void> _confirmBlockUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Block User', style: TextStyle(color: context.textPrimary)),
        content: Text(
          'You will no longer see posts from this user. You can unblock them later in settings.',
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
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await blockUser(ref, userId);
        ref.read(exploreProvider.notifier).refresh();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User blocked')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to block: $e')));
        }
      }
    }
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted. Thank you.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to report: $e')));
        }
      }
    }
  }
}

// =============================================================================
// PROFILE SUMMARY CARD
// =============================================================================

/// A compact profile summary card shown at the top of the social feed.
class _ProfileSummaryCard extends StatelessWidget {
  const _ProfileSummaryCard({required this.profile, required this.onTap});

  final PublicProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 32,
              backgroundColor: context.accentColor.withValues(alpha: 0.2),
              backgroundImage: profile.avatarUrl != null
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child: profile.avatarUrl == null
                  ? Text(
                      profile.displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: context.accentColor,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            // Name and stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.displayName,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          color: context.accentColor,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  if (profile.callsign != null &&
                      profile.callsign!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.callsign!,
                      style: TextStyle(
                        color: context.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStat(
                        context,
                        profile.postCount.toString(),
                        'posts',
                      ),
                      const SizedBox(width: 16),
                      _buildStat(
                        context,
                        profile.followerCount.toString(),
                        'followers',
                      ),
                      const SizedBox(width: 16),
                      _buildStat(
                        context,
                        profile.followingCount.toString(),
                        'following',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String count, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
      ],
    );
  }
}
