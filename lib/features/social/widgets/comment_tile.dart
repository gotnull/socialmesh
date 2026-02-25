// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/verified_badge.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../services/social_service.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../utils/snackbar.dart';
import 'package:socialmesh/core/theme.dart';

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
                child: UserAvatar(
                  imageUrl: comment.author?.avatarUrl,
                  initials: (comment.author?.displayName ?? 'U')[0],
                  size: depth == 0 ? 36 : 28,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),

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
                          const SizedBox(width: AppTheme.spacing4),
                          const SimpleVerifiedBadge(size: 14),
                        ],
                        const SizedBox(width: AppTheme.spacing8),
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
                    const SizedBox(height: AppTheme.spacing4),

                    // Comment text
                    Text(
                      comment.comment.content,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppTheme.spacing8),

                    // Actions
                    Row(
                      children: [
                        // Like button
                        _CommentLikeButton(
                          commentId: comment.comment.id,
                          likeCount: comment.comment.likeCount,
                          currentUserId: currentUser?.uid,
                        ),
                        const SizedBox(width: AppTheme.spacing16),

                        // Reply button (only show if we haven't hit max depth)
                        if (depth < maxDepth)
                          InkWell(
                            onTap: () => onReplyTap?.call(comment),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius4,
                            ),
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
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: 'Delete Comment',
      message: 'Are you sure you want to delete this comment?',
      confirmLabel: 'Delete',
      isDestructive: true,
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
  bool _optimisticLiked = false;
  int _optimisticLikeCount = 0;
  bool _hasOptimisticState = false;

  int get _displayLikeCount =>
      _hasOptimisticState ? _optimisticLikeCount : widget.likeCount;

  Future<void> _handleLike() async {
    if (widget.currentUserId == null) return;

    // Capture providers before any await
    final socialService = ref.read(socialServiceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final queue = ref.read(mutationQueueProvider);

    // Determine current state (use optimistic if pending, else fetch)
    final currentlyLiked = _hasOptimisticState
        ? _optimisticLiked
        : await socialService.isCommentLiked(widget.commentId);
    final currentCount = _displayLikeCount;

    final newLiked = !currentlyLiked;
    final newCount = (currentCount + (newLiked ? 1 : -1)).clamp(0, 999999);

    try {
      await queue.enqueue<void>(
        key: 'comment-like:${widget.commentId}',
        optimisticApply: () {
          safeSetState(() {
            _optimisticLiked = newLiked;
            _optimisticLikeCount = newCount;
            _hasOptimisticState = true;
          });
        },
        execute: () async {
          if (newLiked) {
            await socialService.likeComment(
              widget.commentId,
              actorNodeNum: myNodeNum,
            );
          } else {
            await socialService.unlikeComment(widget.commentId);
          }
        },
        commitApply: (_) {},
        rollbackApply: () {
          safeSetState(() {
            _optimisticLiked = currentlyLiked;
            _optimisticLikeCount = currentCount;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: widget.currentUserId != null ? _handleLike : null,
      borderRadius: BorderRadius.circular(AppTheme.radius4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hasOptimisticState && _optimisticLiked
                  ? Icons.favorite
                  : Icons.favorite_border,
              size: 14,
              color: _hasOptimisticState && _optimisticLiked
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface.withAlpha(150),
            ),
            if (_displayLikeCount > 0) ...[
              const SizedBox(width: AppTheme.spacing4),
              Text(
                _displayLikeCount.toString(),
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
