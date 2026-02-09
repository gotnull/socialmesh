// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/social.dart';
import '../../nodedex/screens/nodedex_detail_screen.dart';
import '../../nodedex/widgets/sigil_painter.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/signal_bookmark_provider.dart';
import '../../../core/logging.dart';
import '../../../providers/social_providers.dart';
import '../screens/signal_detail_screen.dart';
import '../utils/signal_utils.dart';
import 'double_tap_heart.dart';
import '../../social/widgets/subscribe_button.dart';

/// A fullscreen gallery view for signal images with metadata overlays.
///
/// Shows images in a horizontally swipeable PageView with:
/// - Author info (avatar, name, mesh node)
/// - TTL countdown
/// - Hop count badge
/// - Location if available
/// - Comment count
/// - Content snippet
class SignalGalleryView extends ConsumerStatefulWidget {
  const SignalGalleryView({
    super.key,
    required this.signals,
    this.initialIndex = 0,
  });

  /// Signals with media to display
  final List<Post> signals;

  /// Starting index in the list
  final int initialIndex;

  /// Shows the gallery as a modal route.
  static void show(
    BuildContext context, {
    required List<Post> signals,
    int initialIndex = 0,
  }) {
    // Filter to only signals with images
    final signalsWithMedia = signals
        .where((s) => s.mediaUrls.isNotEmpty || s.imageLocalPath != null)
        .toList();

    if (signalsWithMedia.isEmpty) return;

    // Adjust initial index if needed
    final adjustedIndex = initialIndex.clamp(0, signalsWithMedia.length - 1);

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            SignalGalleryView(
              signals: signalsWithMedia,
              initialIndex: adjustedIndex,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
        opaque: false,
        barrierColor: Colors.black87,
      ),
    );
  }

  @override
  ConsumerState<SignalGalleryView> createState() => _SignalGalleryViewState();
}

class _SignalGalleryViewState extends ConsumerState<SignalGalleryView>
    with SingleTickerProviderStateMixin, LifecycleSafeMixin {
  late PageController _pageController;
  late int _currentIndex;
  int _currentImageIndex = 0; // Track current image within signal
  late AnimationController _overlayController;
  late Animation<Offset> _overlaySlideAnimation;
  late Animation<double> _overlayFadeAnimation;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Overlay animation controller
    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _overlaySlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _overlayController,
            curve: Curves.easeOutCubic,
          ),
        );

    _overlayFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _overlayController, curve: Curves.easeOut),
    );

    // Start overlay animation after a brief delay
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _overlayController.forward();
    });

    // Setup expiry timer for current signal
    _setupExpiryTimer();

    // Set immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _setupExpiryTimer() {
    _expiryTimer?.cancel();
    final signal = widget.signals[_currentIndex];
    final expiresAt = signal.expiresAt;
    if (expiresAt == null) return;

    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      // Already expired - pop immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    } else {
      // Schedule pop for when it expires
      _expiryTimer = Timer(remaining, () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _pageController.dispose();
    _overlayController.dispose();
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _onPageChanged(int index) {
    // Animate out, change page, animate in
    _overlayController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentIndex = index;
          _currentImageIndex = 0; // Reset to first image of new signal
        });
        _setupExpiryTimer(); // Reset timer for new signal
        _overlayController.forward();
      }
    });
  }

  void _onImageIndexChanged(int imageIndex) {
    setState(() => _currentImageIndex = imageIndex);
  }

  int _getImageCount(Post signal) {
    final cloudUrls = signal.mediaUrls;
    // Only count local paths if there are NO cloud URLs (same logic as _getAllImagePaths)
    final localPaths = cloudUrls.isEmpty && signal.imageLocalPaths.isNotEmpty
        ? signal.imageLocalPaths
        : (cloudUrls.isEmpty && signal.imageLocalPath != null
              ? [signal.imageLocalPath!]
              : <String>[]);
    return cloudUrls.length + localPaths.length;
  }

  @override
  Widget build(BuildContext context) {
    final signal = widget.signals[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.signals.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final signal = widget.signals[index];
              return DoubleTapLikeWrapper(
                onDoubleTap: () async {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(signalBookmarksProvider.notifier)
                      .addBookmark(signal.id);

                  // Bookmark as before
                  try {
                    ref
                        .read(signalBookmarksProvider.notifier)
                        .addBookmark(signal.id);

                    // If signal originates from the mesh (mesh_ author), skip cloud-like behavior
                    if (signal.authorId.startsWith('mesh_')) {
                      AppLogging.social(
                        'Skipping like for mesh-origin signal ${signal.id}',
                      );
                    } else {
                      final socialService = ref.read(
                        socialServiceProvider,
                      ); // captured before await
                      await socialService.likePost(signal.id);
                      AppLogging.social(
                        '📬 Like recorded for signal ${signal.id}',
                      );
                    }
                  } catch (e) {
                    AppLogging.social('Failed to like signal ${signal.id}: $e');
                  }
                },
                child: _AnimatedImagePage(
                  signal: signal,
                  isActive: index == _currentIndex,
                  onImageIndexChanged: _onImageIndexChanged,
                  onTap: () => Navigator.of(context).pop(),
                  onRequestNextSignal: () {
                    if (_currentIndex < widget.signals.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  onRequestPreviousSignal: () {
                    if (_currentIndex > 0) {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
              );
            },
          ),

          // Top bar with close button and counter
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _overlayController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: FadeTransition(
                  opacity: _overlayFadeAnimation,
                  child: _TopBar(
                    currentIndex: _currentIndex,
                    total: widget.signals.length,
                    currentImageIndex: _currentImageIndex,
                    totalImages: _getImageCount(signal),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),

          // Bottom info overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _overlaySlideAnimation,
              child: FadeTransition(
                opacity: _overlayFadeAnimation,
                child: _BottomInfoOverlay(
                  signal: signal,
                  onViewDetails: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            SignalDetailScreen(signal: signal),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top bar with close button and page indicator
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.currentIndex,
    required this.total,
    required this.currentImageIndex,
    required this.totalImages,
    required this.onClose,
  });

  final int currentIndex;
  final int total;
  final int currentImageIndex;
  final int totalImages;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
          const Spacer(),
          // Image counter (if multiple images in signal)
          if (totalImages > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library, size: 12, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    '${currentImageIndex + 1}/$totalImages',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Signal counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${currentIndex + 1} / $total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          // Placeholder for symmetry
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Individual image page with interactive viewer and animations
class _AnimatedImagePage extends StatefulWidget {
  const _AnimatedImagePage({
    required this.signal,
    required this.isActive,
    required this.onImageIndexChanged,
    required this.onTap,
    required this.onRequestNextSignal,
    required this.onRequestPreviousSignal,
  });

  final Post signal;
  final bool isActive;
  final ValueChanged<int> onImageIndexChanged;
  final VoidCallback onTap;
  final VoidCallback onRequestNextSignal;
  final VoidCallback onRequestPreviousSignal;

  @override
  State<_AnimatedImagePage> createState() => _AnimatedImagePageState();
}

class _AnimatedImagePageState extends State<_AnimatedImagePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late PageController _imagePageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(_AnimatedImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset to first image when signal changes OR when becoming active
    final signalChanged = widget.signal.id != oldWidget.signal.id;
    final becameActive = widget.isActive && !oldWidget.isActive;

    if (signalChanged || becameActive) {
      if (signalChanged) {
        // Signal changed - reset animations
        _controller.forward(from: 0);
      } else if (becameActive) {
        // Just became active (scrolled into view)
        _controller.forward(from: 0);
      }

      // Reset image index to first image
      if (_currentImageIndex != 0) {
        _currentImageIndex = 0;
        _imagePageController.jumpToPage(0);
        widget.onImageIndexChanged(0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  List<String> _getAllImagePaths() {
    final cloudUrls = widget.signal.mediaUrls;

    // Only use local paths if NO cloud URLs exist (cloud takes priority)
    final localPaths =
        cloudUrls.isEmpty && widget.signal.imageLocalPaths.isNotEmpty
        ? widget.signal.imageLocalPaths
        : (cloudUrls.isEmpty && widget.signal.imageLocalPath != null
              ? [widget.signal.imageLocalPath!]
              : <String>[]);

    // DEBUG: Log what we're actually seeing
    AppLogging.social(
      'GALLERY_DEBUG: cloudUrls.length=${cloudUrls.length}, localPaths.length=${localPaths.length}, total=${cloudUrls.length + localPaths.length}',
    );
    AppLogging.social('GALLERY_DEBUG: cloudUrls=$cloudUrls');
    AppLogging.social('GALLERY_DEBUG: localPaths=$localPaths');

    return [...cloudUrls, ...localPaths];
  }

  @override
  Widget build(BuildContext context) {
    final allImages = _getAllImagePaths();

    if (allImages.isEmpty) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Center(child: _buildErrorWidget()),
      );
    }

    // Single image - use InteractiveViewer for zoom
    if (allImages.length == 1) {
      return GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: _buildImageWidget(allImages[0])),
            ),
          ),
        ),
      );
    }

    // Multiple images - use PageView with scroll notification at boundaries
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (!widget.isActive) return false;

            // Use UserScrollNotification to detect when user is trying to scroll past boundaries
            if (notification is ScrollUpdateNotification) {
              final metrics = notification.metrics;

              // At the end and trying to scroll further
              if (metrics.pixels >= metrics.maxScrollExtent &&
                  notification.dragDetails != null &&
                  (notification.dragDetails!.delta.dx < -5)) {
                AppLogging.social(
                  'BOUNDARY_DEBUG: At end, swiping left, going to NEXT signal',
                );
                widget.onRequestNextSignal();
                return true;
              }

              // At the beginning and trying to scroll back
              if (metrics.pixels <= metrics.minScrollExtent &&
                  notification.dragDetails != null &&
                  (notification.dragDetails!.delta.dx > 5)) {
                AppLogging.social(
                  'BOUNDARY_DEBUG: At start, swiping right, going to PREVIOUS signal',
                );
                widget.onRequestPreviousSignal();
                return true;
              }
            }
            return false;
          },
          child: PageView.builder(
            controller: _imagePageController,
            physics:
                const ClampingScrollPhysics(), // Use clamping to detect boundary hits
            itemCount: allImages.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
              widget.onImageIndexChanged(index);
            },
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: widget.onTap,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(child: _buildImageWidget(allImages[index])),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String path) {
    // Check if it's a cloud URL or local path
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } else {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    }
  }

  Widget _buildErrorWidget() {
    return const Icon(
      Icons.broken_image_outlined,
      size: 64,
      color: Colors.white38,
    );
  }
}

/// Bottom overlay with signal metadata
class _BottomInfoOverlay extends ConsumerWidget {
  const _BottomInfoOverlay({required this.signal, required this.onViewDetails});

  final Post signal;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final author = signal.authorSnapshot;
    final isOwnMeshSignal =
        signal.meshNodeId != null && signal.meshNodeId == myNodeNum;

    // Get mesh node info if available
    String? meshNodeName;
    String? meshNodeShort;
    if (signal.meshNodeId != null) {
      final hexId = signal.meshNodeId!.toRadixString(16).toUpperCase();
      final shortHex = hexId.length >= 4
          ? hexId.substring(hexId.length - 4)
          : hexId;
      if (nodes.containsKey(signal.meshNodeId)) {
        final node = nodes[signal.meshNodeId]!;
        meshNodeName = node.longName ?? node.shortName ?? '!$hexId';
        meshNodeShort = node.shortName ?? shortHex;
      } else {
        meshNodeName = '!$hexId';
        meshNodeShort = shortHex;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              Row(
                children: [
                  // Avatar — use Sigil for mesh nodes, UserAvatar for cloud authors
                  if (signal.meshNodeId != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => NodeDexDetailScreen(
                              nodeNum: signal.meshNodeId!,
                            ),
                          ),
                        );
                      },
                      child: SigilAvatar(nodeNum: signal.meshNodeId!, size: 40),
                    )
                  else
                    UserAvatar(
                      initials: _getInitials(author?.displayName ?? 'Unknown'),
                      imageUrl: author?.avatarUrl,
                      size: 40,
                    ),
                  const SizedBox(width: 12),

                  // Author info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meshNodeName ?? author?.displayName ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // Time ago
                            Text(
                              formatTimeAgo(signal.createdAt),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                            if (meshNodeName != null) ...[
                              Text(
                                ' · ',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                              Icon(
                                Icons.router,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                meshNodeShort ?? '',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // View details button
                  TextButton(
                    onPressed: onViewDetails,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View'),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12),
                      ],
                    ),
                  ),

                  // Subscribe button (for cloud authors; show even if profile service is disabled)
                  if ((!signal.authorId.startsWith('mesh_') ||
                          signal.authorSnapshot != null) &&
                      !isOwnMeshSignal) ...[
                    SubscribeButton(
                      authorId:
                          signal.authorId.startsWith('mesh_') &&
                              signal.authorSnapshot != null
                          ? signal.authorId.replaceFirst('mesh_', '')
                          : signal.authorId,
                      compact: true,
                    ),
                  ],
                ],
              ),

              // Content snippet
              if (signal.content.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  signal.content,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Info badges row
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Saved/Bookmark badge
                  if (ref.watch(isSignalBookmarkedProvider(signal.id)))
                    const _InfoBadge(
                      icon: Icons.bookmark_rounded,
                      label: 'Saved',
                      color: AccentColors.yellow,
                    ),

                  // TTL badge
                  if (signal.expiresAt != null)
                    _buildTtlBadge(signal.expiresAt!),

                  // Hop count badge
                  if (signal.hopCount != null)
                    _InfoBadge(
                      icon: Icons.near_me,
                      label: signal.hopCount == 0
                          ? 'Local'
                          : '${signal.hopCount} hop${signal.hopCount! > 1 ? 's' : ''}',
                      color: getHopCountColor(signal.hopCount),
                    ),

                  // Location badge
                  if (signal.location != null)
                    _InfoBadge(
                      icon: Icons.location_on,
                      label: signal.location!.name ?? 'Location',
                      color: AccentColors.blue,
                    ),

                  // Comments badge
                  if (signal.commentCount > 0)
                    _InfoBadge(
                      icon: Icons.chat_bubble_outline,
                      label: '${signal.commentCount}',
                      color: Colors.white70,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTtlBadge(DateTime expiresAt) {
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      return const _InfoBadge(
        icon: Icons.timer_off,
        label: 'Expired',
        color: Colors.red,
      );
    }

    final minutes = remaining.inMinutes;
    final hours = remaining.inHours;

    String label;
    Color color;

    if (minutes < 5) {
      label = '${remaining.inMinutes}m left';
      color = Colors.red;
    } else if (minutes < 30) {
      label = '${minutes}m left';
      color = AppTheme.warningYellow;
    } else if (hours < 1) {
      label = '${minutes}m left';
      color = AccentColors.cyan;
    } else {
      label = '${hours}h left';
      color = AccentColors.cyan;
    }

    return _InfoBadge(icon: Icons.schedule, label: label, color: color);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, parts.first.length.clamp(0, 2))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Small info badge widget
class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
