import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/fullscreen_gallery.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';

/// Card widget for displaying a signal.
///
/// Signals show:
/// - Author info (node ID if from mesh, profile if authenticated)
/// - Content text
/// - Optional image (with local/cloud state indicator)
/// - TTL countdown
/// - Location (if available)
///
/// NO likes, NO social counters - signals are ephemeral presence.
class SignalCard extends StatelessWidget {
  const SignalCard({
    super.key,
    required this.signal,
    this.onTap,
    this.onDelete,
    this.onComment,
    this.showActions = true,
  });

  final Post signal;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onComment;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _SignalHeader(
              signal: signal,
              onDelete: showActions ? onDelete : null,
            ),

            // Content
            if (signal.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  signal.content,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),

            // Image
            if (signal.mediaUrls.isNotEmpty || signal.imageLocalPath != null)
              _SignalImage(signal: signal),

            // Location
            if (signal.location != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: context.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        signal.location!.name ?? 'Location attached',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            // Footer with TTL
            _SignalFooter(signal: signal, onComment: onComment),
          ],
        ),
      ),
    );
  }
}

class _SignalHeader extends ConsumerWidget {
  const _SignalHeader({required this.signal, this.onDelete});

  final Post signal;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final isMeshSignal = signal.authorId.startsWith('mesh_');

    // Get author info
    String authorName = 'Anonymous';
    String? avatarUrl;
    Color avatarColor = context.accentColor;

    if (signal.authorSnapshot != null) {
      authorName = signal.authorSnapshot!.displayName;
      avatarUrl = signal.authorSnapshot!.avatarUrl;
    } else if (isMeshSignal && signal.meshNodeId != null) {
      // Look up node info
      final node = nodes[signal.meshNodeId!];
      if (node != null) {
        authorName =
            node.longName ??
            node.shortName ??
            '!${signal.meshNodeId!.toRadixString(16)}';
        avatarColor = Color((node.hardwareModel?.hashCode ?? 0) | 0xFF000000);
      } else {
        authorName = '!${signal.meshNodeId!.toRadixString(16)}';
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: avatarUrl != null
                  ? Colors.transparent
                  : avatarColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: avatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: avatarColor.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.person,
                            color: avatarColor,
                            size: 20,
                          ),
                        );
                      },
                      errorBuilder: (ctx, error, stack) => Container(
                        color: avatarColor.withValues(alpha: 0.2),
                        child: Icon(Icons.person, color: avatarColor, size: 20),
                      ),
                    ),
                  )
                : Icon(
                    isMeshSignal ? Icons.router : Icons.person,
                    color: avatarColor,
                    size: 20,
                  ),
          ),
          const SizedBox(width: 12),

          // Author info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMeshSignal) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sensors,
                              size: 10,
                              color: context.accentColor,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'nearby',
                              style: TextStyle(
                                color: context.accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _timeAgo(signal.createdAt),
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),

          // Delete button
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: Icon(
                Icons.more_vert,
                color: context.textTertiary,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inMinutes < 1) return 'Active now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h';
    return 'Active ${diff.inDays}d';
  }
}

class _SignalImage extends StatelessWidget {
  const _SignalImage({required this.signal});

  final Post signal;

  void _showFullscreenImage(BuildContext context) {
    final hasCloudImage = signal.mediaUrls.isNotEmpty;
    final hasLocalImage = signal.imageLocalPath != null;

    if (hasCloudImage) {
      // Use standard fullscreen gallery for network images
      FullscreenGallery.show(
        context,
        images: signal.mediaUrls,
        initialIndex: 0,
      );
    } else if (hasLocalImage) {
      // Show fullscreen local image
      _showLocalImageFullscreen(context, signal.imageLocalPath!);
    }
  }

  void _showLocalImageFullscreen(BuildContext context, String localPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LocalImageFullscreen(imagePath: localPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCloudImage = signal.mediaUrls.isNotEmpty;
    final hasLocalImage = signal.imageLocalPath != null;

    if (!hasCloudImage && !hasLocalImage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => _showFullscreenImage(context),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: hasCloudImage
                  ? Image.network(
                      signal.mediaUrls.first,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: double.infinity,
                          height: 200,
                          color: context.card,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.accentColor,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (ctx, error, stack) => Container(
                        width: double.infinity,
                        height: 200,
                        color: context.card,
                        child: Icon(
                          Icons.broken_image,
                          color: context.textTertiary,
                        ),
                      ),
                    )
                  : Image.file(
                      File(signal.imageLocalPath!),
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => Container(
                        width: double.infinity,
                        height: 200,
                        color: context.card,
                        child: Icon(
                          Icons.broken_image,
                          color: context.textTertiary,
                        ),
                      ),
                    ),
            ),

            // Image state indicator
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      signal.imageState == ImageState.cloud
                          ? Icons.cloud_done
                          : Icons.phone_android,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      signal.imageState == ImageState.cloud
                          ? 'Image synced'
                          : 'Image attached locally',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen viewer for local image files
class _LocalImageFullscreen extends StatelessWidget {
  const _LocalImageFullscreen({required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.broken_image,
                color: Colors.white54,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Footer widget for signal cards showing TTL countdown and reply count.
/// Countdown is computed from expiresAt on each build - no local timer needed.
/// The parent provider ticks every second and triggers rebuilds.
class _SignalFooter extends StatelessWidget {
  const _SignalFooter({required this.signal, this.onComment});

  final Post signal;
  final VoidCallback? onComment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // TTL indicator
          if (signal.expiresAt != null) ...[
            Icon(
              Icons.schedule,
              size: 14,
              color: _isExpiringSoon ? Colors.orange : context.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              _expiresIn,
              style: TextStyle(
                color: _isExpiringSoon ? Colors.orange : context.textTertiary,
                fontSize: 12,
                fontWeight: _isExpiringSoon
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ],

          const Spacer(),

          // Reply indicator - tappable to open replies
          GestureDetector(
            onTap: onComment,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 14,
                    color: onComment != null
                        ? context.textSecondary
                        : context.textTertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${signal.commentCount}',
                    style: TextStyle(
                      color: onComment != null
                          ? context.textSecondary
                          : context.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isExpiringSoon {
    if (signal.expiresAt == null) return false;
    final remaining = signal.expiresAt!.difference(DateTime.now());
    return remaining.inMinutes < 5 && !remaining.isNegative;
  }

  String get _expiresIn {
    if (signal.expiresAt == null) return '';

    final remaining = signal.expiresAt!.difference(DateTime.now());

    if (remaining.isNegative) return 'Faded';
    if (remaining.inSeconds < 60) return 'Fades in ${remaining.inSeconds}s';
    if (remaining.inMinutes < 60) return 'Fades in ${remaining.inMinutes}m';
    if (remaining.inHours < 24) return 'Fades in ${remaining.inHours}h';
    return 'Fades in ${remaining.inDays}d';
  }
}
