// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/features/settings/account_subscriptions_screen.dart';

import '../../../core/theme.dart';
import '../../../core/logging.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/presence_confidence.dart';
import '../../nodedex/screens/nodedex_detail_screen.dart';
import '../../nodedex/widgets/sigil_painter.dart';
import '../../../models/social.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connectivity_providers.dart';
import '../../../providers/presence_providers.dart';
import '../../navigation/main_shell.dart';
import '../../../providers/signal_bookmark_provider.dart';
import '../screens/presence_feed_screen.dart';
import '../utils/signal_utils.dart';
import 'proximity_indicator.dart';
import 'signal_gallery_view.dart';
import 'signal_ttl_footer.dart';
import '../../social/widgets/subscribe_button.dart';
import 'signal_presence_context.dart';

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

            // Presence context (intent, status, encounter hints)
            if (signal.meshNodeId != null)
              _SignalPresenceContextWrapper(signal: signal),

            // Image(s) - stacked if multiple
            if (signal.mediaUrls.isNotEmpty ||
                signal.imageLocalPath != null ||
                signal.imageLocalPaths.isNotEmpty ||
                signal.hasPendingCloudImage)
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
    final myNodeNum = ref.watch(myNodeNumProvider);
    final isMeshSignal = signal.authorId.startsWith('mesh_');
    final isOwnMeshSignal =
        signal.meshNodeId != null && signal.meshNodeId == myNodeNum;

    // AppLogging.signals(
    //   'SignalHeader: id=${signal.id}, authorId=${signal.authorId}, isMeshSignal=$isMeshSignal, hasAuthorSnapshot=${signal.authorSnapshot != null}',
    // );

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar — use Sigil for mesh nodes, UserAvatar for cloud authors
          if (isMeshSignal && signal.meshNodeId != null)
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        NodeDexDetailScreen(nodeNum: signal.meshNodeId!),
                  ),
                );
              },
              child: SigilAvatar(nodeNum: signal.meshNodeId!, size: 40),
            )
          else
            UserAvatar(
              imageUrl: avatarUrl,
              size: 40,
              foregroundColor: avatarColor,
              fallbackIcon: Icons.person,
            ),
          const SizedBox(width: 12),

          // Author info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: Name + Bookmark
                Row(
                  children: [
                    Expanded(
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
                // Row 2: ShortName · Time · Live indicator · Proximity
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
                          color: context.accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    ProximityBadge(hopCount: signal.hopCount),
                  ],
                ),
              ],
            ),
          ),

          // Subscribe button for cloud authors (show even if profile service is disabled)
          if ((!isMeshSignal || signal.authorSnapshot != null) &&
              !isOwnMeshSignal) ...[
            const SizedBox(width: 8),
            SubscribeButton(
              authorId:
                  signal.authorId.startsWith('mesh_') &&
                      signal.authorSnapshot != null
                  ? signal.authorId.replaceFirst('mesh_', '')
                  : signal.authorId,
              compact: true,
            ),
          ],

          // More options menu
          if (onDelete != null || onReport != null)
            AppBarOverflowMenu<String>(
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

class _SignalImage extends ConsumerWidget {
  const _SignalImage({required this.signal});

  final Post signal;

  void _showFullscreenImage(BuildContext context) {
    final hasCloudImages = signal.mediaUrls.isNotEmpty;
    final hasLocalImages =
        signal.imageLocalPath != null || signal.imageLocalPaths.isNotEmpty;

    if (hasCloudImages || hasLocalImages) {
      SignalGalleryView.show(context, signals: [signal], initialIndex: 0);
    }
  }

  void _openAccountScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountSubscriptionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Collect all images (cloud and local)
    final cloudUrls = signal.mediaUrls;

    // Only use local paths if NO cloud URLs exist (cloud takes priority)
    final localPaths = cloudUrls.isEmpty && signal.imageLocalPaths.isNotEmpty
        ? signal.imageLocalPaths
        : (cloudUrls.isEmpty && signal.imageLocalPath != null
              ? [signal.imageLocalPath!]
              : <String>[]);

    final hasPendingImage = signal.hasPendingCloudImage;
    final totalImages = cloudUrls.length + localPaths.length;

    if (totalImages == 0 && !hasPendingImage) {
      return const SizedBox.shrink();
    }

    final isSignedIn = ref
        .watch(authStateProvider)
        .maybeWhen(data: (user) => user != null, orElse: () => false);
    final isOnline = ref.watch(isOnlineProvider);
    final showSignInPlaceholder =
        !isSignedIn && (cloudUrls.isNotEmpty || hasPendingImage);
    final onTap = showSignInPlaceholder
        ? () => _openAccountScreen(context)
        : () => _showFullscreenImage(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: onTap,
        child: ClipPath(
          clipper: _SquircleClipper(radius: 48),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildImageContent(
              context,
              cloudUrls,
              localPaths,
              showSignInPlaceholder,
              isOnline,
              hasPendingImage,
              totalImages,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(
    BuildContext context,
    List<String> cloudUrls,
    List<String> localPaths,
    bool showSignInPlaceholder,
    bool isOnline,
    bool hasPendingImage,
    int totalImages,
  ) {
    if (showSignInPlaceholder) {
      return _buildSignInPlaceholder(context);
    }

    if (hasPendingImage && cloudUrls.isEmpty && localPaths.isEmpty) {
      return _buildPendingPlaceholder(context);
    }

    // Single image - show normally
    if (totalImages == 1) {
      final imageWidget = cloudUrls.isNotEmpty
          ? _buildCloudImage(cloudUrls.first, isOnline)
          : _buildLocalImage(localPaths.first);

      return _buildImageContainer(
        context,
        imageWidget,
        cloudUrls.isNotEmpty,
        totalImages,
      );
    }

    // Multiple images - stacked layout like the reference image
    return _buildStackedImages(
      context,
      cloudUrls,
      localPaths,
      isOnline,
      totalImages,
    );
  }

  Widget _buildStackedImages(
    BuildContext context,
    List<String> cloudUrls,
    List<String> localPaths,
    bool isOnline,
    int totalImages,
  ) {
    // Show up to 4 images in stacked layout
    final displayCount = totalImages.clamp(1, 4);

    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Stack(
        clipBehavior: Clip.hardEdge, // Clip images that extend beyond bounds
        children: [
          // Build each image with rotation and offset (render first)
          for (int i = 0; i < displayCount; i++)
            _buildStackedImageLayer(
              context,
              i,
              displayCount,
              cloudUrls,
              localPaths,
              isOnline,
            ),

          // Gradient overlay at bottom (on top of images)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
          ),

          // Count badge and storage badge (on top of everything)
          _buildImageBadges(context, cloudUrls.isNotEmpty, totalImages),
        ],
      ),
    );
  }

  Widget _buildStackedImageLayer(
    BuildContext context,
    int index,
    int totalCount,
    List<String> cloudUrls,
    List<String> localPaths,
    bool isOnline,
  ) {
    // Calculate rotation and offset for stacked effect
    final rotations = [0.0, -2.0, 2.5, -1.5]; // degrees
    final offsets = [
      Offset.zero,
      const Offset(-8, 4),
      const Offset(8, 6),
      const Offset(-4, 8),
    ];

    final rotation = rotations[index % rotations.length];
    final offset = offsets[index % offsets.length];

    // Get the image source
    final imageIndex = index;
    Widget imageWidget;

    if (imageIndex < cloudUrls.length) {
      imageWidget = _buildCloudImage(cloudUrls[imageIndex], isOnline);
    } else {
      final localIndex = imageIndex - cloudUrls.length;
      if (localIndex < localPaths.length) {
        imageWidget = _buildLocalImage(localPaths[localIndex]);
      } else {
        return const SizedBox.shrink();
      }
    }

    return Positioned(
      left: 10 + offset.dx,
      top: 10 + offset.dy,
      right: 10 - offset.dx,
      bottom: 10 - offset.dy,
      child: Transform.rotate(
        angle: rotation * (3.14159 / 180), // Convert to radians
        child: Container(
          decoration: BoxDecoration(
            color: context.card, // Background color for loading state
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.border.withValues(alpha: 0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: imageWidget,
          ),
        ),
      ),
    );
  }

  Widget _buildImageContainer(
    BuildContext context,
    Widget imageWidget,
    bool isCloud,
    int totalImages,
  ) {
    return Stack(
      children: [
        imageWidget,
        // Gradient overlay at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),
        _buildImageBadges(context, isCloud, totalImages),
      ],
    );
  }

  Widget _buildImageBadges(
    BuildContext context,
    bool isCloud,
    int totalImages,
  ) {
    return Positioned(
      bottom: 10,
      left: 10,
      right: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Storage badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCloud ? Icons.cloud_done_rounded : Icons.phone_android,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 5),
                Text(
                  isCloud ? 'Cloud' : 'Local',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Count badge (only if multiple images)
          if (totalImages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, size: 12, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    '$totalImages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCloudImage(String url, bool isOnline) {
    return Image.network(
      url,
      key: ValueKey('${signal.id}_image_$isOnline'),
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return Container(
          width: double.infinity,
          height: 200,
          color: ctx.card,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ctx.accentColor,
            ),
          ),
        );
      },
      errorBuilder: (ctx, error, stack) => Container(
        width: double.infinity,
        height: 200,
        color: ctx.card,
        child: Icon(Icons.broken_image, color: ctx.textTertiary),
      ),
    );
  }

  Widget _buildLocalImage(String path) {
    return Image.file(
      File(path),
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      errorBuilder: (ctx, error, stack) => Container(
        width: double.infinity,
        height: 200,
        color: ctx.card,
        child: Icon(Icons.broken_image, color: ctx.textTertiary),
      ),
    );
  }

  Widget _buildSignInPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      color: context.card,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image, size: 32, color: context.accentColor),
            const SizedBox(height: 8),
            Text(
              'Sign in to view attached media',
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _openAccountScreen(context),
              style: TextButton.styleFrom(
                foregroundColor: context.accentColor,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.accentColor.withValues(alpha: 0.15),
            context.accentColor.withValues(alpha: 0.05),
            context.card,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Animated mesh pattern background
          Positioned.fill(
            child: CustomPaint(
              painter: _SyncingMeshPainter(
                color: context.accentColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Pulsing glow effect
          Center(
            child: _PulsingGlow(
              color: context.accentColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated cloud icon with arrow
                  _SyncingCloudIcon(color: context.accentColor),
                  const SizedBox(height: 12),
                  // Animated text
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        context.accentColor,
                        context.accentColor.withValues(alpha: 0.6),
                        context.accentColor,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      'Syncing media',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Animated dots
                  _AnimatedDots(color: context.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Squircle clipper using ContinuousRectangleBorder for iOS-style rounded corners
class _SquircleClipper extends CustomClipper<ui.Path> {
  _SquircleClipper({required this.radius});

  final double radius;

  @override
  ui.Path getClip(Size size) {
    return ContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    ).getOuterPath(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(_SquircleClipper oldClipper) => oldClipper.radius != radius;
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

// ═══════════════════════════════════════════════════════════════════════════════
// SYNCING ANIMATION WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Pulsing glow effect wrapper
class _PulsingGlow extends StatefulWidget {
  const _PulsingGlow({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  State<_PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<_PulsingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowOpacity = 0.1 + (_controller.value * 0.15);
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glowOpacity),
                blurRadius: 40 + (_controller.value * 20),
                spreadRadius: 10 + (_controller.value * 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Animated cloud icon with bouncing arrow
class _SyncingCloudIcon extends StatefulWidget {
  const _SyncingCloudIcon({required this.color});

  final Color color;

  @override
  State<_SyncingCloudIcon> createState() => _SyncingCloudIconState();
}

class _SyncingCloudIconState extends State<_SyncingCloudIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final bounce = Curves.easeInOut.transform(_controller.value) * 6;
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color.withValues(alpha: 0.3),
                widget.color.withValues(alpha: 0.15),
              ],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.color.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 28,
                color: widget.color.withValues(alpha: 0.6),
              ),
              Transform.translate(
                offset: Offset(0, -bounce),
                child: Icon(
                  Icons.arrow_upward_rounded,
                  size: 18,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Animated typing dots
class _AnimatedDots extends StatefulWidget {
  const _AnimatedDots({required this.color});

  final Color color;

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (math.sin(progress * math.pi)).clamp(0.3, 1.0);
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

/// Mesh pattern painter for background
class _SyncingMeshPainter extends CustomPainter {
  _SyncingMeshPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;

    // Draw diagonal lines
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i + size.height, 0),
        Offset(i, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SyncingMeshPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Wrapper that resolves presence data and renders SignalPresenceContext.
///
/// Priority for presence data:
/// 1. signal.presenceInfo (embedded at send time - most accurate)
/// 2. nodeExtendedPresenceProvider (cached from recent packets - fallback)
class _SignalPresenceContextWrapper extends ConsumerWidget {
  const _SignalPresenceContextWrapper({required this.signal});

  final Post signal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodeNum = signal.meshNodeId;
    if (nodeNum == null) return const SizedBox.shrink();

    // Resolve presence info: signal-embedded first, then cached
    ExtendedPresenceInfo? displayPresence;

    // Priority 1: Presence info embedded in the signal itself
    if (signal.presenceInfo != null && signal.presenceInfo!.isNotEmpty) {
      displayPresence = ExtendedPresenceInfo.fromJson(signal.presenceInfo);
    }

    // Priority 2: Cached node extended presence
    displayPresence ??= ref.watch(nodeExtendedPresenceProvider(nodeNum));

    // Get encounter info
    final encounter = ref.watch(nodeEncounterProvider(nodeNum));

    // Get presence info for last-seen bucket and back nearby
    final presence = ref.watch(presenceForNodeProvider(nodeNum));

    return SignalPresenceContext(
      intent: displayPresence?.intent,
      shortStatus: displayPresence?.shortStatus,
      encounterCount: encounter?.encounterCount,
      lastSeenBucket: presence?.lastSeenBucket,
      isBackNearby: presence?.isBackNearby ?? false,
    );
  }
}
