import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme.dart';
import '../../../core/logging.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import '../../navigation/main_shell.dart';
import '../../../providers/signal_bookmark_provider.dart';
import '../screens/presence_feed_screen.dart';
import '../utils/signal_utils.dart';
import 'proximity_indicator.dart';
import 'signal_gallery_view.dart';
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
    this.isLive = false,
  });

  final Post signal;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onComment;
  final bool showActions;
  final bool isBookmarked;
  final bool isLive;

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
              isLive: isLive,
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
            if (signal.location != null) _SignalLocation(signal: signal),

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
    this.isLive = false,
    this.onDelete,
    this.onReport,
  });

  final Post signal;
  final bool isBookmarked;
  final bool isLive;
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
                      formatActiveTime(signal.createdAt),
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    if (isLive) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AccentColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
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
}

class _SignalImage extends StatelessWidget {
  const _SignalImage({required this.signal});

  final Post signal;

  void _showFullscreenImage(BuildContext context) {
    final hasCloudImage = signal.mediaUrls.isNotEmpty;
    final hasLocalImage = signal.imageLocalPath != null;

    if (hasCloudImage || hasLocalImage) {
      // Use SignalGalleryView to show the same info as the gallery view
      SignalGalleryView.show(context, signals: [signal], initialIndex: 0);
    }
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

/// Tappable location row that opens in-app map
class _SignalLocation extends StatelessWidget {
  const _SignalLocation({required this.signal});

  final Post signal;

  void _openMap(BuildContext context) {
    // If we're already inside a PresenceFeedScreen, update it in-place instead
    // of pushing a new screen to avoid stacking multiple presence screens.
    final presenceState = context
        .findAncestorStateOfType<State<PresenceFeedScreen>>();
    if (presenceState != null) {
      try {
        (presenceState as dynamic).showSignalOnMap(signal);
        return;
      } catch (e) {
        AppLogging.signals('showSignalOnMap failed, falling back to push: $e');
      }
    }

    // If not in-place, navigate back to the app root (MainShell), switch to the
    // Signals tab, then focus the signal on the existing PresenceFeedScreen.
    // This avoids pushing duplicate PresenceFeedScreen instances and keeps the
    // hamburger menu/drawer behavior intact.
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Switch main shell to Signals tab
    try {
      // Use provider container to switch tab
      final container = ProviderScope.containerOf(context);
      container.read(mainShellIndexProvider.notifier).setIndex(2);
    } catch (e) {
      AppLogging.signals('Failed to set main shell index: $e');
    }

    // After the frame, focus the signal on the in-place PresenceFeedScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final presenceState = presenceFeedScreenKey.currentState;
      if (presenceState != null) {
        try {
          (presenceState as dynamic).showSignalOnMap(signal);
          return;
        } catch (e) {
          AppLogging.signals('Failed to focus presence feed on signal: $e');
        }
      }

      // As a last resort, push a new PresenceFeedScreen focused on this signal
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PresenceFeedScreen(
            initialViewMode: SignalViewMode.map,
            initialCenter: LatLng(
              signal.location!.latitude,
              signal.location!.longitude,
            ),
            initialSelectedSignalId: signal.id,
          ),
        ),
      );
    });
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
                  signal.location!.name ?? 'View Location',
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
