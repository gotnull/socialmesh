// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../services/social_service.dart';
import '../../../utils/snackbar.dart';

/// A tile displaying a comment with reply capability.
class CommentTile extends ConsumerWidget {
  const CommentTile({
    super.key,
    required this.comment,
    this.onReplyTap,
    this.onAuthorTap,
    this.onLikeTap,
    this.depth = 0,
    this.maxDepth = 3,
  });

  final CommentWithAuthor comment;
  final void Function(CommentWithAuthor)? onReplyTap;
  final void Function(String authorId)? onAuthorTap;
  final VoidCallback? onLikeTap;
  final int depth;
  final int maxDepth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final isOwnComment = currentUser?.uid == comment.comment.authorId;

    // Indent based on depth
    final leftPadding = depth * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thread line for replies
          if (depth > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              height: 1,
              width: 24,
              color: theme.dividerColor.withAlpha(100),
            ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              GestureDetector(
                onTap: () => onAuthorTap?.call(comment.comment.authorId),
                child: CircleAvatar(
                  radius: depth == 0 ? 18 : 14,
                  backgroundImage: comment.author?.avatarUrl != null
                      ? NetworkImage(comment.author!.avatarUrl!)
                      : null,
                  child: comment.author?.avatarUrl == null
                      ? Text(
                          (comment.author?.displayName ?? 'U')[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: depth == 0 ? 14 : 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author name and time
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              onAuthorTap?.call(comment.comment.authorId),
                          child: Text(
                            comment.author?.displayName ?? 'Unknown',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (comment.author?.isVerified == true) ...[
                          const SizedBox(width: 4),
                          const SimpleVerifiedBadge(size: 14),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          timeago.format(comment.comment.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withAlpha(
                              150,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Comment text
                    Text(
                      comment.comment.content,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),

                    // Actions
                    Row(
                      children: [
                        // Like button
                        _CommentLikeButton(
                          commentId: comment.comment.id,
                          likeCount: comment.comment.likeCount,
                          currentUserId: currentUser?.uid,
                        ),
                        const SizedBox(width: 16),

                        // Reply button (only show if we haven't hit max depth)
                        if (depth < maxDepth)
                          InkWell(
                            onTap: () => onReplyTap?.call(comment),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                'Reply',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                        const Spacer(),

                        // Delete button for own comments
                        if (isOwnComment)
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: theme.colorScheme.error.withAlpha(180),
                            ),
                            onPressed: () => _confirmDelete(context, ref),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
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

    if (confirmed == true && context.mounted) {
      try {
        await deleteComment(ref, comment.comment.id);
      } catch (e) {
        if (context.mounted) {
          showErrorSnackBar(context, 'Failed to delete: $e');
        }
      }
    }
  }
}

class _CommentLikeButton extends ConsumerStatefulWidget {
  const _CommentLikeButton({
    required this.commentId,
    required this.likeCount,
    required this.currentUserId,
  });

  final String commentId;
  final int likeCount;
  final String? currentUserId;

  @override
  ConsumerState<_CommentLikeButton> createState() => _CommentLikeButtonState();
}

class _CommentLikeButtonState extends ConsumerState<_CommentLikeButton>
    with LifecycleSafeMixin {
  bool _isLiking = false;

  Future<void> _handleLike() async {
    if (widget.currentUserId == null || _isLiking) return;

    safeSetState(() => _isLiking = true);
    try {
      final socialService = ref.read(
        socialServiceProvider,
      ); // captured before await
      // Check current like status and toggle
      final currentlyLiked = await socialService.isCommentLiked(
        widget.commentId,
      );
      if (currentlyLiked) {
        await socialService.unlikeComment(widget.commentId);
      } else {
        await socialService.likeComment(widget.commentId);
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed: $e');
      }
    } finally {
      safeSetState(() => _isLiking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: widget.currentUserId != null ? _handleLike : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLiking)
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              )
            else
              Icon(
                Icons.favorite_border,
                size: 14,
                color: theme.colorScheme.onSurface.withAlpha(150),
              ),
            if (widget.likeCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                widget.likeCount.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
