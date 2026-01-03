import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../services/social_service.dart';
import '../widgets/post_actions_bar.dart';
import 'profile_social_screen.dart';

/// Screen showing a single post with its comments.
class PostDetailScreen extends ConsumerStatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.postId,
    this.focusCommentInput = false,
  });

  final String postId;
  final bool focusCommentInput;

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? _replyingToId;
  String? _replyingToAuthor;
  bool _isSubmitting = false;
  final Set<String> _deletingCommentIds = {};
  final Set<String> _deletedCommentIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.focusCommentInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final postAsync = ref.watch(postStreamProvider(widget.postId));
    final commentsAsync = ref.watch(commentsStreamProvider(widget.postId));

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: postAsync.when(
          data: (post) {
            if (post == null) {
              return const Center(child: Text('Post not found'));
            }

            // Get actual comment count from stream (excluding deleted)
            final actualCommentCount = commentsAsync.when(
              data: (comments) => comments
                  .where((c) => !_deletedCommentIds.contains(c.comment.id))
                  .length,
              loading: () => post.commentCount,
              error: (e, s) => post.commentCount,
            );

            return Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      // Post content
                      SliverToBoxAdapter(
                        child: _PostContent(
                          post: post,
                          onAuthorTap: () => _navigateToProfile(post.authorId),
                          onCommentTap: () => _commentFocusNode.requestFocus(),
                          onShareTap: () => _sharePost(post),
                          onMoreTap: () => _showPostOptions(post),
                          commentCount: actualCommentCount,
                        ),
                      ),

                      const SliverToBoxAdapter(child: Divider(height: 1)),

                      // Comments header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Comments',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      // Comments list
                      commentsAsync.when(
                        data: (comments) => _buildCommentsSliver(comments),
                        loading: () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                        error: (e, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(child: Text('Error: $e')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Comment input
                if (currentUser != null)
                  _CommentInput(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    replyingTo: _replyingToAuthor,
                    isSubmitting: _isSubmitting,
                    onCancelReply: _cancelReply,
                    onSubmit: () => _submitComment(post.id),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }

  /// Build a sliver list of comments with threaded replies.
  Widget _buildCommentsSliver(List<CommentWithAuthor> allComments) {
    // Filter out deleted comments (optimistic deletion)
    final visibleComments = allComments
        .where((c) => !_deletedCommentIds.contains(c.comment.id))
        .toList();

    if (visibleComments.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Text(
              'No comments yet. Be the first!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).textTheme.bodyMedium?.color?.withAlpha(150),
              ),
            ),
          ),
        ),
      );
    }

    // Organize comments into tree structure
    final rootComments = visibleComments
        .where((c) => c.comment.parentId == null)
        .toList();
    final repliesMap = <String, List<CommentWithAuthor>>{};

    for (final c in visibleComments) {
      if (c.comment.parentId != null) {
        repliesMap.putIfAbsent(c.comment.parentId!, () => []).add(c);
      }
    }

    // Flatten tree into display list with depth info
    final displayList = <_CommentDisplayItem>[];
    void addWithReplies(CommentWithAuthor comment, int depth) {
      displayList.add(_CommentDisplayItem(comment: comment, depth: depth));
      final replies = repliesMap[comment.comment.id] ?? [];
      for (final reply in replies) {
        addWithReplies(reply, depth + 1);
      }
    }

    for (final root in rootComments) {
      addWithReplies(root, 0);
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = displayList[index];
        final commentId = item.comment.comment.id;
        return _CommentTile(
          key: ValueKey(commentId),
          comment: item.comment,
          depth: item.depth,
          onReplyTap: () => _handleReplyTo(item.comment),
          onAuthorTap: () => _navigateToProfile(item.comment.comment.authorId),
          isDeleting: _deletingCommentIds.contains(commentId),
          onDelete: () => _deleteComment(commentId),
        );
      }, childCount: displayList.length),
    );
  }

  Future<void> _deleteComment(String commentId) async {
    if (_deletingCommentIds.contains(commentId) ||
        _deletedCommentIds.contains(commentId)) {
      return; // Already deleting or deleted
    }

    // Immediately hide the comment (optimistic)
    setState(() {
      _deletingCommentIds.add(commentId);
      _deletedCommentIds.add(commentId); // Hide immediately
    });

    try {
      await ref.read(socialServiceProvider).deleteComment(commentId);
      if (mounted) {
        setState(() {
          _deletingCommentIds.remove(commentId);
          // Keep in _deletedCommentIds to filter stream results
        });
      }
    } catch (e) {
      if (mounted) {
        // Deletion failed - restore the comment
        setState(() {
          _deletingCommentIds.remove(commentId);
          _deletedCommentIds.remove(commentId);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
      }
    }
  }

  void _handleReplyTo(CommentWithAuthor comment) {
    setState(() {
      _replyingToId = comment.comment.id;
      _replyingToAuthor = comment.author?.displayName ?? 'Unknown';
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToId = null;
      _replyingToAuthor = null;
    });
  }

  Future<void> _submitComment(String postId) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      await addComment(ref, postId, content, parentId: _replyingToId);
      _commentController.clear();
      _cancelReply();
      // Stream will automatically update - no need to invalidate
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSocialScreen(userId: userId),
      ),
    );
  }

  void _sharePost(Post post) {
    Share.share(
      'Check out this post on Socialmesh!\nhttps://socialmesh.app/post/${post.id}',
      subject: 'Socialmesh Post',
    );
  }

  void _showPostOptions(Post post) {
    final currentUser = ref.read(currentUserProvider);
    final isOwnPost = currentUser?.uid == post.authorId;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
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
                  Navigator.pop(ctx);
                  _confirmDeletePost(post);
                },
              ),
            if (!isOwnPost) ...[
              ListTile(
                leading: const Icon(Icons.person_off_outlined),
                title: const Text('Block User'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmBlockUser(post.authorId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report Post'),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportPost(post.id, post.authorId);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(ctx);
                _sharePost(post);
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
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
        if (mounted) {
          Navigator.pop(context);
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
      builder: (ctx) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
          'You will no longer see posts from this user. You can unblock them later in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await blockUser(ref, userId);
        if (mounted) {
          Navigator.pop(context);
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
          ).showSnackBar(SnackBar(content: Text('Failed to report: $e')));
        }
      }
    }
  }
}

/// Short time ago format like Instagram (1h, 2d, 3w)
String _shortTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
  return '${(diff.inDays / 365).floor()}y';
}

/// Helper class for displaying comments with depth.
class _CommentDisplayItem {
  final CommentWithAuthor comment;
  final int depth;

  _CommentDisplayItem({required this.comment, required this.depth});
}

/// Individual comment tile with threading support.
class _CommentTile extends ConsumerStatefulWidget {
  const _CommentTile({
    super.key,
    required this.comment,
    required this.depth,
    this.onReplyTap,
    this.onAuthorTap,
    this.onDelete,
    this.isDeleting = false,
  });

  final CommentWithAuthor comment;
  final int depth;
  final VoidCallback? onReplyTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onDelete;
  final bool isDeleting;

  @override
  ConsumerState<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends ConsumerState<_CommentTile> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.comment.comment.likeCount;
    _checkLikeStatus();
  }

  Future<void> _checkLikeStatus() async {
    final socialService = ref.read(socialServiceProvider);
    final isLiked = await socialService.isCommentLiked(
      widget.comment.comment.id,
    );
    if (mounted) {
      setState(() => _isLiked = isLiked);
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() {
      _isLiking = true;
      // Optimistic update
      if (_isLiked) {
        _isLiked = false;
        _likeCount = (_likeCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likeCount += 1;
      }
    });

    try {
      final socialService = ref.read(socialServiceProvider);
      if (_isLiked) {
        await socialService.likeComment(widget.comment.comment.id);
      } else {
        await socialService.unlikeComment(widget.comment.comment.id);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount = _isLiked
              ? _likeCount + 1
              : (_likeCount - 1).clamp(0, 999999);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLiking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final isOwnComment = currentUser?.uid == widget.comment.comment.authorId;
    final isReply = widget.depth > 0;

    // Instagram-style: replies have smaller indent
    final leftPadding = isReply ? 54.0 : 16.0; // Align with parent content

    return GestureDetector(
      onLongPress: () => _showOptionsMenu(context, isOwnComment),
      child: Container(
        padding: EdgeInsets.only(
          left: leftPadding,
          right: 12,
          top: isReply ? 8 : 12,
          bottom: isReply ? 8 : 12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar - smaller for replies
            GestureDetector(
              onTap: widget.onAuthorTap,
              child: CircleAvatar(
                radius: isReply ? 12 : 16,
                backgroundImage: widget.comment.author?.avatarUrl != null
                    ? NetworkImage(widget.comment.author!.avatarUrl!)
                    : null,
                child: widget.comment.author?.avatarUrl == null
                    ? Text(
                        (widget.comment.author?.displayName ?? 'U')[0]
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: isReply ? 10 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 10),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Instagram-style: name + comment on same line for short comments
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: [
                        TextSpan(
                          text: widget.comment.author?.displayName ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isReply ? 13 : 14,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        if (widget.comment.author?.isVerified == true)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                size: 12,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        TextSpan(
                          text:
                              ' ${widget.comment.comment.content.replaceAll(RegExp(r'\s+'), ' ')}',
                          style: TextStyle(
                            fontSize: isReply ? 13 : 14,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // Actions row - compact
                  Row(
                    children: [
                      // Time - short format
                      Text(
                        _shortTimeAgo(widget.comment.comment.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                          fontSize: 12,
                        ),
                      ),

                      // Like count text (if > 0)
                      if (_likeCount > 0) ...[
                        const SizedBox(width: 16),
                        Text(
                          '$_likeCount ${_likeCount == 1 ? 'like' : 'likes'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.hintColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],

                      // Reply button - text only like Instagram
                      if (widget.depth < 3) ...[
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: widget.onReplyTap,
                          child: Text(
                            'Reply',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.hintColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],

                      // Show deleting indicator
                      if (widget.isDeleting) ...[
                        const SizedBox(width: 16),
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Like button on right - Instagram style
            GestureDetector(
              onTap: currentUser != null ? _toggleLike : null,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  size: isReply ? 14 : 16,
                  color: _isLiked ? Colors.red : theme.hintColor.withAlpha(150),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context, bool isOwnComment) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: theme.hintColor.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Delete option - only for own comments
            if (isOwnComment)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Delete',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context);
                },
              ),

            // Report option - only for others' comments
            if (!isOwnComment)
              ListTile(
                leading: Icon(
                  Icons.flag_outlined,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Report',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportComment(context);
                },
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _reportComment(BuildContext context) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _ReportReasonDialog(),
    );

    if (reason != null && reason.isNotEmpty && mounted) {
      try {
        final socialService = ref.read(socialServiceProvider);
        await socialService.reportComment(
          commentId: widget.comment.comment.id,
          reason: reason,
        );
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Comment reported')),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Failed to report: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDelete != null) {
      widget.onDelete!();
    }
  }
}

class _PostContent extends StatelessWidget {
  const _PostContent({
    required this.post,
    this.onAuthorTap,
    this.onCommentTap,
    this.onShareTap,
    this.onMoreTap,
    this.commentCount,
  });

  final Post post;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onMoreTap;
  final int? commentCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = post.authorSnapshot;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author header
          Row(
            children: [
              GestureDetector(
                onTap: onAuthorTap,
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: snapshot?.avatarUrl != null
                      ? NetworkImage(snapshot!.avatarUrl!)
                      : null,
                  child: snapshot?.avatarUrl == null
                      ? Text(
                          (snapshot?.displayName ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: onAuthorTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            snapshot?.displayName ?? 'Unknown User',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (snapshot?.isVerified == true) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      Text(
                        timeago.format(post.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withAlpha(
                            150,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onMoreTap,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content
          if (post.content.isNotEmpty)
            Text(post.content, style: theme.textTheme.bodyLarge),

          // Images
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildImages(context),
          ],

          // Location
          if (post.location != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: theme.colorScheme.primary.withAlpha(180),
                ),
                const SizedBox(width: 4),
                Text(
                  post.location!.name ?? 'Location',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary.withAlpha(180),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          PostActionsBar(
            post: post,
            onCommentTap: onCommentTap,
            onShareTap: onShareTap,
            commentCountOverride: commentCount,
          ),
        ],
      ),
    );
  }

  Widget _buildImages(BuildContext context) {
    if (post.imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          post.imageUrls.first,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 200,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: CircularProgressIndicator()),
            );
          },
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: post.imageUrls.take(4).map((url) {
            return Image.network(url, fit: BoxFit.cover);
          }).toList(),
        ),
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
    required this.controller,
    required this.focusNode,
    this.replyingTo,
    required this.isSubmitting,
    this.onCancelReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? replyingTo;
  final bool isSubmitting;
  final VoidCallback? onCancelReply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply indicator
            if (replyingTo != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Icon(
                      Icons.reply,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Replying to $replyingTo',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onCancelReply,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

            // Input field
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        hintText: replyingTo != null
                            ? 'Write a reply...'
                            : 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSubmit(),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                  const SizedBox(width: 8),
                  isSubmitting
                      ? const SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : IconButton(
                          icon: Icon(
                            Icons.send,
                            color: theme.colorScheme.primary,
                          ),
                          onPressed: onSubmit,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for selecting a report reason
class _ReportReasonDialog extends StatefulWidget {
  @override
  State<_ReportReasonDialog> createState() => _ReportReasonDialogState();
}

class _ReportReasonDialogState extends State<_ReportReasonDialog> {
  String? _selectedReason;

  static const _reasons = [
    'Spam',
    'Harassment or bullying',
    'Hate speech',
    'Violence or threats',
    'Nudity or sexual content',
    'False information',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Report Comment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Why are you reporting this comment?',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ..._reasons.map(
            (reason) => InkWell(
              onTap: () => setState(() => _selectedReason = reason),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      _selectedReason == reason
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 20,
                      color: _selectedReason == reason
                          ? theme.colorScheme.primary
                          : theme.hintColor,
                    ),
                    const SizedBox(width: 12),
                    Text(reason, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedReason != null
              ? () => Navigator.pop(context, _selectedReason)
              : null,
          child: const Text('Report'),
        ),
      ],
    );
  }
}
