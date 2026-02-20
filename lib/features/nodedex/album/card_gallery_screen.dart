// SPDX-License-Identifier: GPL-3.0-or-later

// Card Gallery Screen — horizontal PageView for browsing collectible cards.
//
// A full-screen modal route that displays SigilCards in a swipeable
// horizontal carousel. Features:
//
//   - Centered card with peek at adjacent cards (viewport fraction 0.85)
//   - Smooth scale and opacity transitions for unfocused cards
//   - Holographic shimmer overlay on rare, epic, and legendary cards
//   - Tap-to-flip animation revealing the stats back side
//   - Position indicator (dots for small collections, counter for large)
//   - Bottom info bar with node name, rarity badge, and navigation hints
//   - Close button and swipe-down-to-dismiss gesture
//
// Navigation:
//   - Opened from the album grid when a filled slot is tapped
//   - Can be opened at any index via the [initialIndex] parameter
//   - Swipe left/right to browse through all cards in album order
//   - Tap a card to flip it (front ↔ back)
//   - Tap the close button or swipe down to dismiss
//
// Data flow:
//   - Reads albumFlatEntriesProvider for the ordered card list
//   - Reads nodeDexTraitProvider and nodeDexPatinaProvider per card
//   - Writes to galleryIndexProvider to track current position
//   - Writes to cardFlipStateProvider for flip toggling
//   - Resets flip state on dismiss
//
// Performance:
//   - PageView lazily builds only visible + adjacent pages
//   - HolographicEffect uses a single CustomPainter per card
//   - CardFlipWidget owns a single AnimationController
//   - Position indicator avoids rebuilds via selective watching
//
// Accessibility:
//   - Respects reduce-motion via the [animate] parameter
//   - All interactive elements have semantic labels
//   - Sufficient contrast on all text and controls

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';

import '../../../core/theme.dart';
import '../../../services/haptic_service.dart';
import '../models/nodedex_entry.dart';
import '../providers/nodedex_providers.dart';
import '../services/sigil_generator.dart';

import '../widgets/sigil_card.dart';
import 'album_constants.dart';
import 'album_providers.dart';
import 'card_flip_widget.dart';
import 'holographic_effect.dart';

// =============================================================================
// Public API — show the gallery
// =============================================================================

/// Opens the card gallery as a full-screen modal route.
///
/// [initialIndex] determines which card is shown first.
/// [animate] controls all animations (holographic, flip, transitions).
///
/// Usage:
/// ```dart
/// showCardGallery(
///   context: context,
///   initialIndex: tappedCardIndex,
///   animate: !reduceMotion,
/// );
/// ```
void showCardGallery({
  required BuildContext context,
  int initialIndex = 0,
  bool animate = true,
}) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black87,
      barrierDismissible: true,
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CardGalleryScreen(initialIndex: initialIndex, animate: animate);
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeIn = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final scaleIn = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );

        return FadeTransition(
          opacity: fadeIn,
          child: ScaleTransition(scale: scaleIn, child: child),
        );
      },
    ),
  );
}

// =============================================================================
// Card Gallery Screen
// =============================================================================

/// Full-screen horizontal card gallery for browsing collectible SigilCards.
///
/// Displays cards in a PageView with peek at adjacent cards, holographic
/// shimmer on rare+ tiers, and tap-to-flip animation. The gallery resets
/// all flip states when dismissed.
class CardGalleryScreen extends ConsumerStatefulWidget {
  /// The index of the card to display first.
  final int initialIndex;

  /// Whether animations are enabled.
  final bool animate;

  const CardGalleryScreen({
    super.key,
    this.initialIndex = 0,
    this.animate = true,
  });

  @override
  ConsumerState<CardGalleryScreen> createState() => _CardGalleryScreenState();
}

class _CardGalleryScreenState extends ConsumerState<CardGalleryScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: AlbumConstants.galleryViewportFraction,
    );

    // Set initial gallery index in provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(galleryIndexProvider.notifier).setIndex(widget.initialIndex);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    ref.read(galleryIndexProvider.notifier).setIndex(index);

    // Light haptic on page change.
    ref.read(hapticServiceProvider).trigger(HapticType.selection);
  }

  void _dismiss() {
    // Reset all flip states when leaving the gallery.
    ref.read(cardFlipStateProvider.notifier).resetAll();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(albumFlatEntriesProvider);
    final totalCards = entries.length;

    if (totalCards == 0) {
      return _EmptyGallery(onClose: _dismiss);
    }

    // Clamp current page to valid range.
    final safePage = _currentPage.clamp(0, totalCards - 1);
    final currentEntry = entries[safePage];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          // Swipe down to dismiss.
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              _dismiss();
            }
          },
          child: SafeArea(
            child: Column(
              children: [
                // Top bar with close button and position counter.
                _GalleryTopBar(
                  currentIndex: safePage,
                  totalCount: totalCards,
                  onClose: _dismiss,
                ),

                // Card PageView.
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: totalCards,
                    onPageChanged: _onPageChanged,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return _GalleryPage(
                        entry: entries[index],
                        pageController: _pageController,
                        pageIndex: index,
                        animate: widget.animate,
                      );
                    },
                  ),
                ),

                // Bottom info bar.
                _GalleryBottomBar(
                  entry: currentEntry,
                  currentIndex: safePage,
                  totalCount: totalCards,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Gallery page — a single card in the PageView
// =============================================================================

/// A single page in the gallery PageView.
///
/// Renders a SigilCard wrapped in CardFlipWidget with holographic
/// shimmer overlay. Applies scale and opacity transforms based on
/// the page's scroll position relative to the viewport center.
class _GalleryPage extends ConsumerWidget {
  final NodeDexEntry entry;
  final PageController pageController;
  final int pageIndex;
  final bool animate;

  const _GalleryPage({
    required this.entry,
    required this.pageController,
    required this.pageIndex,
    required this.animate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traitResult = ref.watch(nodeDexTraitProvider(entry.nodeNum));
    final patinaResult = ref.watch(nodeDexPatinaProvider(entry.nodeNum));
    final trait = traitResult.primary;
    final sigil = entry.sigil ?? SigilGenerator.generate(entry.nodeNum);
    final hexId =
        '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final displayName = entry.localNickname ?? entry.lastKnownName ?? hexId;
    final rarity = CardRarityVisuals.fromNodeData(
      encounterCount: entry.encounterCount,
      trait: trait,
    );

    // Resolve device info: prefer cached data from NodeDexEntry (persisted
    // across sessions), fall back to live MeshNode if currently online.
    final nodes = ref.watch(nodesProvider);
    final liveNode = nodes[entry.nodeNum];
    final hardwareModel = entry.lastKnownHardware ?? liveNode?.hardwareModel;
    final role = entry.lastKnownRole ?? liveNode?.role;
    final firmwareVersion =
        entry.lastKnownFirmware ?? liveNode?.firmwareVersion;

    return AnimatedBuilder(
      animation: pageController,
      builder: (context, child) {
        double pageOffset = 0.0;
        if (pageController.position.hasContentDimensions) {
          pageOffset =
              (pageController.page ?? pageIndex.toDouble()) -
              pageIndex.toDouble();
        }

        // Distance from center (0 = focused, 1 = fully off-screen).
        final distance = pageOffset.abs().clamp(0.0, 1.0);

        // Scale: focused cards are full size, off-cards recede gently.
        final scale = lerpDouble(1.0, 0.88, distance)!;

        // Opacity: off-cards dim but remain legible for context.
        final opacity = lerpDouble(1.0, 0.5, distance)!;

        // 3D Y-axis rotation: subtle tilt away (~8 degrees max).
        // Cards feel like they're on a carousel, not a spinning wheel.
        final rotationY = pageOffset.clamp(-1.0, 1.0) * -0.14;

        // Vertical parallax: off-center cards sink slightly.
        final translateY = distance * 12.0;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // subtle perspective
            ..rotateY(rotationY)
            ..translate(0.0, translateY)
            ..scale(scale),
          child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        );
      },
      child: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Compute card width to fit nicely in the viewport.
            final maxWidth = constraints.maxWidth - 32;
            final maxHeight = constraints.maxHeight - 24;
            // Respect 5:7 aspect ratio.
            final cardWidthFromHeight = maxHeight / 1.4;
            final cardWidth = math
                .min(maxWidth, cardWidthFromHeight)
                .clamp(200.0, 380.0);

            return Stack(
              alignment: Alignment.center,
              children: [
                // The flippable card.
                CardFlipWidget(
                  entry: entry,
                  traitResult: traitResult,
                  patinaResult: patinaResult,
                  displayName: displayName,
                  hexId: hexId,
                  width: cardWidth,
                  animate: animate,
                  front: Stack(
                    children: [
                      // The SigilCard itself.
                      SigilCard(
                        nodeNum: entry.nodeNum,
                        sigil: sigil,
                        displayName: displayName,
                        hexId: hexId,
                        traitResult: traitResult,
                        entry: entry,
                        hardwareModel: hardwareModel,
                        role: role,
                        firmwareVersion: firmwareVersion,
                        animated: animate,
                        width: cardWidth,
                      ),

                      // Holographic shimmer overlay.
                      if (rarity.index >= CardRarity.rare.index)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AlbumConstants.slotBorderRadius,
                            ),
                            child: HolographicEffect(
                              rarityIndex: rarity.index,
                              animate: animate,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Gallery top bar
// =============================================================================

/// Top bar with close button and optional position counter.
class _GalleryTopBar extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final VoidCallback onClose;

  const _GalleryTopBar({
    required this.currentIndex,
    required this.totalCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Close button.
          _GlassButton(
            icon: Icons.close_rounded,
            onTap: onClose,
            semanticLabel: 'Close gallery',
          ),

          const Spacer(),

          // Position counter.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Text(
              '${currentIndex + 1} / $totalCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: AppTheme.fontFamily,
                color: Colors.white.withValues(alpha: 0.8),
                letterSpacing: 0.5,
              ),
            ),
          ),

          const Spacer(),

          // Flip hint button.
          _GlassButton(
            icon: Icons.flip_rounded,
            onTap: () {
              // Hint — visual only, actual flip is on card tap.
            },
            semanticLabel: 'Tap card to flip',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Gallery bottom bar
// =============================================================================

/// Bottom info bar showing the current card's name, rarity, and traits.
///
/// Also displays a page indicator (dots for small collections,
/// hidden for large ones since the counter is in the top bar).
class _GalleryBottomBar extends ConsumerWidget {
  final NodeDexEntry entry;
  final int currentIndex;
  final int totalCount;

  const _GalleryBottomBar({
    required this.entry,
    required this.currentIndex,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traitResult = ref.watch(nodeDexTraitProvider(entry.nodeNum));
    final trait = traitResult.primary;
    final rarity = CardRarityVisuals.fromNodeData(
      encounterCount: entry.encounterCount,
      trait: trait,
    );
    final hexId =
        '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    final displayName = entry.localNickname ?? entry.lastKnownName ?? hexId;

    return Container(
      height: AlbumConstants.galleryBottomBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Page indicator dots (only for small collections).
          if (totalCount <= AlbumConstants.galleryMaxDots) ...[
            _PageIndicatorDots(
              currentIndex: currentIndex,
              totalCount: totalCount,
              activeColor: rarity.borderColor,
            ),
            const SizedBox(height: 8),
          ],

          // Node info row.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Trait dot.
              if (trait != NodeTrait.unknown) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: trait.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: trait.color.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // Name.
              Flexible(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 8),

              // Rarity badge.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: rarity.borderColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: rarity.borderColor.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  rarity.label,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: rarity.borderColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Hint text.
          Text(
            'Tap card to flip \u2022 Swipe to browse',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.35),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Page indicator dots
// =============================================================================

/// A row of small dots indicating the current page position.
///
/// The active dot is slightly larger and colored with the card's
/// rarity accent. Inactive dots are semi-transparent white.
class _PageIndicatorDots extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final Color activeColor;

  const _PageIndicatorDots({
    required this.currentIndex,
    required this.totalCount,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalCount, (index) {
        final isActive = index == currentIndex;
        final size = isActive
            ? AlbumConstants.galleryActiveDotSize
            : AlbumConstants.galleryDotSize;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: size,
          height: size,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? activeColor : Colors.white.withValues(alpha: 0.2),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

// =============================================================================
// Glass button
// =============================================================================

/// A semi-transparent circular button with a glassmorphic look.
///
/// Used for the close and flip hint buttons in the gallery top bar.
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const _GlassButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Empty gallery
// =============================================================================

/// Shown when the gallery is opened with no cards available.
///
/// This is a defensive fallback — normally the gallery is only
/// opened when cards exist.
class _EmptyGallery extends StatelessWidget {
  final VoidCallback onClose;

  const _EmptyGallery({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            // Close button.
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: _GlassButton(
                  icon: Icons.close_rounded,
                  onTap: onClose,
                  semanticLabel: 'Close gallery',
                ),
              ),
            ),

            const Spacer(),

            Icon(
              Icons.collections_bookmark_outlined,
              size: 48,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 12),
            Text(
              'No cards to display',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Discover nodes to fill your collection',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}
