import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../map/map_screen.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/fullscreen_gallery.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import 'proximity_indicator.dart';
import 'signal_ttl_footer.dart';

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
    this.onReport,
    this.onComment,
    this.showActions = true,
    this.isBookmarked = false,
  });

  final Post signal;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onComment;
  final bool showActions;
  final bool isBookmarked;

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
              isBookmarked: isBookmarked,
              onDelete: showActions ? onDelete : null,
              onReport: showActions ? onReport : null,
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

            // Location - tappable to open in maps
            if (signal.location != null)
              _SignalLocation(location: signal.location!),

            // Footer with TTL
            SignalTTLFooter(signal: signal, onComment: onComment),
          ],
        ),
      ),
    );
  }
}

class _SignalHeader extends ConsumerWidget {
  const _SignalHeader({
    required this.signal,
    this.isBookmarked = false,
    this.onDelete,
    this.onReport,
  });

  final Post signal;
  final bool isBookmarked;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final isMeshSignal = signal.authorId.startsWith('mesh_');

    // Get author info
    String authorName = 'Anonymous';
    String? authorShortName;
    String? avatarUrl;
    Color avatarColor = context.accentColor;

    if (signal.authorSnapshot != null) {
      authorName = signal.authorSnapshot!.displayName;
      avatarUrl = signal.authorSnapshot!.avatarUrl;
    } else if (isMeshSignal && signal.meshNodeId != null) {
      // Look up node info
      final hexId = signal.meshNodeId!.toRadixString(16).toUpperCase();
      final shortHex = hexId.length >= 4
          ? hexId.substring(hexId.length - 4)
          : hexId;
      final node = nodes[signal.meshNodeId!];
      if (node != null) {
        authorName = node.longName ?? node.shortName ?? '!$hexId';
        authorShortName = node.shortName ?? shortHex;
        avatarColor = Color((node.hardwareModel?.hashCode ?? 0) | 0xFF000000);
      } else {
        authorName = '!$hexId';
        authorShortName = shortHex;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          UserAvatar(
            imageUrl: avatarUrl,
            size: 40,
            foregroundColor: avatarColor,
            fallbackIcon: isMeshSignal ? Icons.router : Icons.person,
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
                    const SizedBox(width: 6),
                    ProximityBadge(hopCount: signal.hopCount),
                    if (isBookmarked) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.bookmark_rounded,
                        size: 16,
                        color: AccentColors.yellow,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (isMeshSignal && authorShortName != null) ...[
                      Text(
                        authorShortName,
                        style: TextStyle(
                          color: AccentColors.cyan,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    Text(
                      _timeAgo(signal.createdAt),
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // More options menu
          if (onDelete != null || onReport != null)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: context.textTertiary,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    onDelete?.call();
                  case 'report':
                    onReport?.call();
                }
              },
              itemBuilder: (context) => [
                if (onDelete != null)
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          color: context.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Delete',
                          style: TextStyle(color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                if (onReport != null)
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: context.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Report',
                          style: TextStyle(color: context.textPrimary),
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

/// Tappable location row that opens in-app map
class _SignalLocation extends StatelessWidget {
  const _SignalLocation({required this.location});

  final PostLocation location;

  void _openMap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          initialLatitude: location.latitude,
          initialLongitude: location.longitude,
          initialLocationLabel: location.name ?? 'Signal Location',
          locationOnlyMode: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: () => _openMap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: context.accentColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, size: 16, color: context.accentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  location.name ?? 'View Location',
                  style: TextStyle(
                    color: context.accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.open_in_new,
                size: 12,
                color: context.accentColor.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
