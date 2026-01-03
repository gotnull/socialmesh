import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../screens/create_post_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/profile_social_screen.dart';
import '../widgets/feed_item_tile.dart';
import '../widgets/post_card.dart';

/// The main feed screen with tabs for Following and Explore.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _followingScrollController = ScrollController();
  final ScrollController _exploreScrollController = ScrollController();
  bool _profileChecked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _followingScrollController.addListener(_onFollowingScroll);
    _exploreScrollController.addListener(_onExploreScroll);
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
    _tabController.dispose();
    _followingScrollController.removeListener(_onFollowingScroll);
    _followingScrollController.dispose();
    _exploreScrollController.removeListener(_onExploreScroll);
    _exploreScrollController.dispose();
    super.dispose();
  }

  void _onFollowingScroll() {
    if (_followingScrollController.position.pixels >=
        _followingScrollController.position.maxScrollExtent - 200) {
      ref.read(feedProvider.notifier).loadMore();
    }
  }

  void _onExploreScroll() {
    if (_exploreScrollController.position.pixels >=
        _exploreScrollController.position.maxScrollExtent - 200) {
      ref.read(exploreProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Following'),
            Tab(text: 'Explore'),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withAlpha(150),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                ref.read(feedProvider.notifier).refresh();
              } else {
                ref.read(exploreProvider.notifier).refresh();
              }
            },
          ),
        ],
      ),
      body: currentUser == null
          ? _buildSignInPrompt(context)
          : TabBarView(
              controller: _tabController,
              children: [_buildFollowingTab(), _buildExploreTab()],
            ),
      floatingActionButton: currentUser != null
          ? FloatingActionButton(
              onPressed: _navigateToCreatePost,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildFollowingTab() {
    final feedState = ref.watch(feedProvider);

    if (feedState.items.isEmpty && feedState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (feedState.items.isEmpty) {
      return _buildEmptyFollowingFeed();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(feedProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _followingScrollController,
        itemCount: feedState.items.length + (feedState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= feedState.items.length) {
            return _buildLoadingIndicator();
          }

          final item = feedState.items[index];
          return FeedItemTile(
            feedItem: item,
            onTap: () => _navigateToPostFromFeedItem(item),
            onAuthorTap: () => _navigateToProfile(item.authorId),
            onCommentTap: () =>
                _navigateToPostFromFeedItem(item, focusComment: true),
            onShareTap: () => _sharePost(item.postId),
            onMoreTap: () => _showFeedItemOptions(item),
          );
        },
      ),
    );
  }

  Widget _buildExploreTab() {
    final exploreState = ref.watch(exploreProvider);

    if (exploreState.posts.isEmpty && exploreState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (exploreState.posts.isEmpty) {
      return _buildEmptyExploreFeed();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(exploreProvider.notifier).refresh(),
      child: ListView.builder(
        controller: _exploreScrollController,
        itemCount: exploreState.posts.length + (exploreState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= exploreState.posts.length) {
            return _buildLoadingIndicator();
          }

          final post = exploreState.posts[index];
          return PostCard(
            post: post,
            onTap: () => _navigateToPostFromPost(post),
            onAuthorTap: () => _navigateToProfile(post.authorId),
            onCommentTap: () =>
                _navigateToPostFromPost(post, focusComment: true),
            onShareTap: () => _sharePost(post.id),
            onMoreTap: () => _showPostOptions(post),
          );
        },
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: theme.colorScheme.primary.withAlpha(150),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign in to see your feed',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Follow other mesh users and see their posts in your feed.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFollowingFeed() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dynamic_feed_outlined,
              size: 64,
              color: theme.colorScheme.primary.withAlpha(150),
            ),
            const SizedBox(height: 16),
            Text(
              'Your feed is empty',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Follow other mesh users to see their posts here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.explore),
              label: const Text('Explore posts'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyExploreFeed() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: theme.colorScheme.primary.withAlpha(150),
            ),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share something with the mesh community!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withAlpha(150),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _navigateToCreatePost,
              icon: const Icon(Icons.add),
              label: const Text('Create your first post'),
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

  void _navigateToPostFromFeedItem(FeedItem item, {bool focusComment = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          postId: item.postId,
          focusCommentInput: focusComment,
        ),
      ),
    );
  }

  void _navigateToPostFromPost(Post post, {bool focusComment = false}) {
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
    // Refresh explore tab after creating a post
    ref.read(exploreProvider.notifier).refresh();
  }

  void _sharePost(String postId) {
    Share.share(
      'Check out this post on Socialmesh!\nhttps://socialmesh.app/post/$postId',
      subject: 'Socialmesh Post',
    );
  }

  void _showFeedItemOptions(FeedItem item) {
    final currentUser = ref.read(currentUserProvider);
    final isOwnPost = currentUser?.uid == item.authorId;

    _showOptionsSheet(
      postId: item.postId,
      authorId: item.authorId,
      isOwnPost: isOwnPost,
      onDelete: () async {
        // Optimistically remove from feed immediately
        ref.read(feedProvider.notifier).removePost(item.postId);
        await ref.read(socialServiceProvider).deletePost(item.postId);
      },
    );
  }

  void _showPostOptions(Post post) {
    final currentUser = ref.read(currentUserProvider);
    final isOwnPost = currentUser?.uid == post.authorId;

    _showOptionsSheet(
      postId: post.id,
      authorId: post.authorId,
      isOwnPost: isOwnPost,
      onDelete: () async {
        // Optimistically remove from explore immediately
        ref.read(exploreProvider.notifier).removePost(post.id);
        await ref.read(socialServiceProvider).deletePost(post.id);
      },
    );
  }

  void _showOptionsSheet({
    required String postId,
    required String authorId,
    required bool isOwnPost,
    required Future<void> Function() onDelete,
  }) {
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
                  _confirmDeletePost(postId, onDelete);
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
                    await toggleFollow(ref, authorId);
                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Following user')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Failed: \$e')),
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
                  _confirmBlockUser(authorId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(postId, authorId);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _sharePost(postId);
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

  Future<void> _confirmDeletePost(
    String postId,
    Future<void> Function() onDelete,
  ) async {
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
        await onDelete();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Post deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete: \$e')));
        }
      }
    }
  }

  Future<void> _confirmBlockUser(String userId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
          'You will no longer see posts from this user. You can unblock them later in settings.',
        ),
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
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await blockUser(ref, userId);
        ref.read(feedProvider.notifier).refresh();
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
          ).showSnackBar(SnackBar(content: Text('Failed to block: \$e')));
        }
      }
    }
  }

  Future<void> _reportPost(String postId, String authorId) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this post?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Describe the issue...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
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
          ).showSnackBar(SnackBar(content: Text('Failed to report: \$e')));
        }
      }
    }
  }
}
