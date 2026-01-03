import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/social.dart';
import '../widgets/post_actions_bar.dart';

/// A tile displaying a feed item (post from followed users).
class FeedItemTile extends ConsumerWidget {
  const FeedItemTile({
    super.key,
    required this.feedItem,
    this.onTap,
    this.onAuthorTap,
    this.onCommentTap,
    this.onShareTap,
    this.onMoreTap,
  });

  final FeedItem feedItem;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

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
              _FeedAuthorHeader(
                authorSnapshot: feedItem.authorSnapshot,
                createdAt: feedItem.createdAt,
                onAuthorTap: onAuthorTap,
                onMoreTap: onMoreTap,
              ),
              const SizedBox(height: 12),

              // Post content
              if (feedItem.content.isNotEmpty)
                Text(
                  feedItem.content,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 10,
                  overflow: TextOverflow.ellipsis,
                ),

              // Images (if any)
              if (feedItem.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _FeedImages(imageUrls: feedItem.imageUrls),
              ],

              // Location tag
              if (feedItem.location != null) ...[
                const SizedBox(height: 8),
                _FeedLocationTag(location: feedItem.location!),
              ],

              const SizedBox(height: 12),

              // Actions bar - convert FeedItem to Post for the actions bar
              PostActionsBar(
                post: feedItem.toPost(),
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

class _FeedAuthorHeader extends StatelessWidget {
  const _FeedAuthorHeader({
    required this.authorSnapshot,
    required this.createdAt,
    this.onAuthorTap,
    this.onMoreTap,
  });

  final FeedAuthorSnapshot authorSnapshot;
  final DateTime createdAt;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Avatar
        GestureDetector(
          onTap: onAuthorTap,
          child: CircleAvatar(
            radius: 20,
            backgroundImage: authorSnapshot.avatarUrl != null
                ? NetworkImage(authorSnapshot.avatarUrl!)
                : null,
            child: authorSnapshot.avatarUrl == null
                ? Text(
                    authorSnapshot.displayName[0].toUpperCase(),
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
                      authorSnapshot.displayName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (authorSnapshot.isVerified) ...[
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
                  timeago.format(createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ),

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

class _FeedImages extends StatelessWidget {
  const _FeedImages({required this.imageUrls});

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

class _FeedLocationTag extends StatelessWidget {
  const _FeedLocationTag({required this.location});

  final PostLocation location;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
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
          ),
        ),
      ],
    );
  }
}
