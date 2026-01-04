import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/snackbar.dart';

/// Action bar for posts showing like, comment, and share buttons.
class PostActionsBar extends ConsumerWidget {
  const PostActionsBar({
    super.key,
    required this.post,
    this.onCommentTap,
    this.onShareTap,
    this.showCounts = true,
    this.iconSize = 24,
    this.commentCountOverride,
  });

  final Post post;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final bool showCounts;
  final double iconSize;

  /// Override the comment count (use actual count from comments stream)
  final int? commentCountOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final commentCount = commentCountOverride ?? post.commentCount;

    return Row(
      children: [
        // Like button
        _LikeButton(
          post: post,
          currentUserId: currentUser?.uid,
          iconSize: iconSize,
          showCount: showCounts,
        ),
        const SizedBox(width: 16),

        // Comment button
        _ActionButton(
          icon: Icons.chat_bubble_outline,
          count: showCounts ? commentCount : null,
          onTap: onCommentTap,
          iconSize: iconSize,
          color: theme.colorScheme.onSurface.withAlpha(180),
        ),
        const SizedBox(width: 16),

        // Share button
        _ActionButton(
          icon: Icons.share_outlined,
          onTap: onShareTap,
          iconSize: iconSize,
          color: theme.colorScheme.onSurface.withAlpha(180),
        ),

        const Spacer(),

        // Bookmark (future feature placeholder)
        // _ActionButton(
        //   icon: Icons.bookmark_border,
        //   onTap: () {},
        //   iconSize: iconSize,
        //   color: theme.colorScheme.onSurface.withAlpha(180),
        // ),
      ],
    );
  }
}

class _LikeButton extends ConsumerStatefulWidget {
  const _LikeButton({
    required this.post,
    required this.currentUserId,
    required this.iconSize,
    required this.showCount,
  });

  final Post post;
  final String? currentUserId;
  final double iconSize;
  final bool showCount;

  @override
  ConsumerState<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<_LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isLiking = false;

  // Optimistic state
  bool? _optimisticIsLiked;
  int? _optimisticLikeCount;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLike(bool currentlyLiked) async {
    if (widget.currentUserId == null) {
      showInfoSnackBar(context, 'Sign in to like posts');
      return;
    }

    if (_isLiking) return;

    setState(() {
      _isLiking = true;
      // Optimistic update
      _optimisticIsLiked = !currentlyLiked;
      _optimisticLikeCount =
          (widget.post.likeCount + (_optimisticIsLiked! ? 1 : -1)).clamp(
            0,
            999999,
          );
    });

    // Play animation
    await _controller.forward();
    _controller.reverse();

    try {
      final service = ref.read(socialServiceProvider);
      if (_optimisticIsLiked!) {
        await service.likePost(widget.post.id);
      } else {
        await service.unlikePost(widget.post.id);
      }
    } catch (e) {
      // Revert optimistic update on error
      if (mounted) {
        setState(() {
          _optimisticIsLiked = currentlyLiked;
          _optimisticLikeCount = widget.post.likeCount;
        });
        showErrorSnackBar(context, 'Failed to like: $e');
      }
    } finally {
      if (mounted) {
        // Clear optimistic state after a delay to let Firestore update
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLiking = false;
              _optimisticIsLiked = null;
              _optimisticLikeCount = null;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.currentUserId == null) {
      return _ActionButton(
        icon: Icons.favorite_border,
        count: widget.showCount ? widget.post.likeCount : null,
        onTap: () => _handleLike(false),
        iconSize: widget.iconSize,
        color: theme.colorScheme.onSurface.withAlpha(180),
      );
    }

    final likeStatus = ref.watch(likeStatusStreamProvider(widget.post.id));

    return likeStatus.when(
      data: (serverIsLiked) {
        // Use optimistic state if available, otherwise use server state
        final isLiked = _optimisticIsLiked ?? serverIsLiked;
        final likeCount = _optimisticLikeCount ?? widget.post.likeCount;

        return ScaleTransition(
          scale: _scaleAnimation,
          child: _ActionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            count: widget.showCount ? likeCount : null,
            onTap: _isLiking ? null : () => _handleLike(isLiked),
            iconSize: widget.iconSize,
            color: isLiked
                ? Colors.red
                : theme.colorScheme.onSurface.withAlpha(180),
          ),
        );
      },
      loading: () => _ActionButton(
        icon: Icons.favorite_border,
        count: widget.showCount ? widget.post.likeCount : null,
        onTap: null,
        iconSize: widget.iconSize,
        color: theme.colorScheme.onSurface.withAlpha(100),
      ),
      error: (_, _) => _ActionButton(
        icon: Icons.favorite_border,
        count: widget.showCount ? widget.post.likeCount : null,
        onTap: () => _handleLike(false),
        iconSize: widget.iconSize,
        color: theme.colorScheme.onSurface.withAlpha(180),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    this.count,
    this.onTap,
    required this.iconSize,
    required this.color,
  });

  final IconData icon;
  final int? count;
  final VoidCallback? onTap;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: color),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 4),
              Text(
                _formatCount(count!),
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
