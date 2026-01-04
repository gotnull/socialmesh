import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/social.dart';
import '../../../providers/auth_providers.dart';
import '../widgets/follow_button.dart';
import '../widgets/post_actions_bar.dart';

/// A card displaying a post in the feed.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onTap,
    this.onAuthorTap,
    this.onCommentTap,
    this.onShareTap,
    this.onMoreTap,
    this.showFollowButton = false,
    this.onLocationTap,
    this.onNodeTap,
  });

  final Post post;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onMoreTap;
  final bool showFollowButton;
  final void Function(PostLocation location)? onLocationTap;
  final void Function(String nodeId)? onNodeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final isOwnPost = currentUser?.uid == post.authorId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide(color: theme.dividerColor.withAlpha(50)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author header
              _AuthorHeader(
                post: post,
                onAuthorTap: onAuthorTap,
                onMoreTap: onMoreTap,
                showFollowButton: showFollowButton && !isOwnPost,
              ),
              const SizedBox(height: 12),

              // Post content
              if (post.content.isNotEmpty)
                Text(
                  post.content,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),

              // Images (if any)
              if (post.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PostImages(imageUrls: post.imageUrls),
              ],

              // Location tag
              if (post.location != null) ...[
                const SizedBox(height: 8),
                _LocationTag(
                  location: post.location!,
                  onTap: onLocationTap != null
                      ? () => onLocationTap!(post.location!)
                      : null,
                ),
              ],

              // Node reference
              if (post.nodeId != null) ...[
                const SizedBox(height: 8),
                _NodeTag(
                  nodeId: post.nodeId!,
                  onTap: onNodeTap != null
                      ? () => onNodeTap!(post.nodeId!)
                      : null,
                ),
              ],

              const SizedBox(height: 12),

              // Actions bar
              PostActionsBar(
                post: post,
                onCommentTap: onCommentTap,
                onShareTap: onShareTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({
    required this.post,
    this.onAuthorTap,
    this.onMoreTap,
    this.showFollowButton = false,
  });

  final Post post;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onMoreTap;
  final bool showFollowButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = post.authorSnapshot;

    return Row(
      children: [
        // Avatar
        GestureDetector(
          onTap: onAuthorTap,
          child: CircleAvatar(
            radius: 20,
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

        // Name and time
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (snapshot?.isVerified == true) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                Text(
                  timeago.format(post.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Follow button
        if (showFollowButton)
          FollowButton(targetUserId: post.authorId, compact: true),

        // More menu
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onMoreTap,
          iconSize: 20,
        ),
      ],
    );
  }
}

class _PostImages extends StatelessWidget {
  const _PostImages({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) return const SizedBox.shrink();

    if (imageUrls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            imageUrls.first,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: CircularProgressIndicator()),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Center(child: Icon(Icons.broken_image)),
              );
            },
          ),
        ),
      );
    }

    // Grid for multiple images
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 1,
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: imageUrls.take(4).map((url) {
            return Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: Icon(Icons.broken_image)),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _LocationTag extends StatelessWidget {
  const _LocationTag({required this.location, this.onTap});

  final PostLocation location;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 14,
            color: theme.colorScheme.primary.withAlpha(180),
          ),
          const SizedBox(width: 4),
          Text(
            location.name ?? 'Location',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary.withAlpha(180),
              decoration: onTap != null ? TextDecoration.underline : null,
              decorationColor: theme.colorScheme.primary.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeTag extends StatelessWidget {
  const _NodeTag({required this.nodeId, this.onTap});

  final String nodeId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer.withAlpha(100),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.router, size: 14, color: theme.colorScheme.secondary),
            const SizedBox(width: 4),
            Text(
              'Node $nodeId',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.secondary,
                decoration: onTap != null ? TextDecoration.underline : null,
                decorationColor: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
