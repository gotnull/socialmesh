// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/navigation/main_shell.dart';
import '../../features/nodedex/screens/nodedex_screen.dart';
import '../../features/onboarding/widgets/mesh_node_brain.dart';
import '../../features/reachability/mesh_reachability_screen.dart';
import '../../features/world_mesh/world_mesh_screen.dart';
import '../../providers/help_providers.dart';
import '../../providers/whats_new_providers.dart';
import '../../services/haptic_service.dart';
import '../help/help_content.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import 'whats_new_registry.dart';

/// Presents the What's New bottom sheet as a swipeable carousel of all
/// historical payloads.
///
/// Each page sizes to its natural content height — no fixed heights, no
/// scrolling, no [PageView]. Swipe gestures use velocity detection on
/// [onHorizontalDragEnd] for a natural feel, and page transitions use
/// [SlideTransition] + [FadeTransition] via [AnimatedSwitcher].
///
/// The container follows the exact same pattern as [AppBottomSheet.build]:
/// [context.card] background, top border radius of 20, drag pill with
/// standard margin, [Column] with [MainAxisSize.min].
///
/// Call [WhatsNewSheet.showIfNeeded] from the main shell's initState
/// post-frame callback. It guards against showing more than once per
/// session via [WhatsNewState.shownThisSession].
class WhatsNewSheet {
  WhatsNewSheet._();

  /// Opens the What's New carousel in read-only mode (no CTA buttons,
  /// no deep links). Intended for the Settings screen so users can
  /// browse feature history without navigating away.
  static Future<void> showHistory(BuildContext context) async {
    HapticFeedback.mediumImpact();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 400),
        reverseDuration: const Duration(milliseconds: 300),
      ),
      builder: (sheetContext) => _WhatsNewCarousel(
        readOnly: true,
        onDismiss: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  /// Shows the What's New sheet if there is a pending payload that has
  /// not yet been presented this session.
  ///
  /// Safe to call during startup: uses [addPostFrameCallback] and
  /// verifies the navigator context is available before presenting.
  static void showIfNeeded(WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(whatsNewProvider);

      if (!state.isLoaded) {
        // State hasn't loaded yet — schedule a retry after a short delay
        Future<void>.delayed(const Duration(milliseconds: 500), () {
          _tryShow(ref);
        });
        return;
      }

      _tryShow(ref);
    });
  }

  static void _tryShow(WidgetRef ref) {
    final state = ref.read(whatsNewProvider);
    if (state.shownThisSession) return;
    if (!state.hasPending) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Mark as shown immediately to prevent duplicate triggers from rebuilds
    ref.read(whatsNewProvider.notifier).markShownThisSession();

    _present(context, ref);
  }

  static Future<void> _present(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      transitionAnimationController: AnimationController(
        vsync: Navigator.of(context),
        duration: const Duration(milliseconds: 400),
        reverseDuration: const Duration(milliseconds: 300),
      ),
      builder: (sheetContext) => _WhatsNewCarousel(
        readOnly: false,
        onDismiss: () {
          ref.read(whatsNewProvider.notifier).markSeen();
          Navigator.of(sheetContext).pop();
        },
      ),
    );

    // If the user swiped down or tapped outside (sheet closed without
    // the dismiss button), still mark as seen.
    ref.read(whatsNewProvider.notifier).markSeen();
  }
}

// =============================================================================
// CAROUSEL WRAPPER
// =============================================================================

class _WhatsNewCarousel extends ConsumerStatefulWidget {
  final VoidCallback onDismiss;
  final bool readOnly;

  const _WhatsNewCarousel({required this.onDismiss, this.readOnly = false});

  @override
  ConsumerState<_WhatsNewCarousel> createState() => _WhatsNewCarouselState();
}

class _WhatsNewCarouselState extends ConsumerState<_WhatsNewCarousel> {
  late final List<WhatsNewPayload> _payloads;
  int _currentPage = 0;

  /// Tracks swipe direction so AnimatedSwitcher can slide the correct way.
  bool _swipingForward = true;

  @override
  void initState() {
    super.initState();
    // All payloads in reverse chronological order (newest first)
    _payloads = WhatsNewRegistry.allPayloads.reversed.toList();
  }

  void _goToPage(int index) {
    if (index == _currentPage) return;
    if (index < 0 || index >= _payloads.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _swipingForward = index > _currentPage;
      _currentPage = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      // Velocity-only swipe detection — no mid-drag firing.
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -200) {
          // Swiped left → next page
          _goToPage(_currentPage + 1);
        } else if (velocity > 200) {
          // Swiped right → previous page
          _goToPage(_currentPage - 1);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        // Matches AppBottomSheet.build() exactly
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewPadding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag pill — matches AppBottomSheet._DragPill
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: context.textTertiary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Page content — sizes to its natural height, no scroll
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  // Determine slide direction from the key match.
                  // The NEW child slides in from the swipe direction;
                  // the OLD child slides out the opposite way.
                  final isIncoming = child.key == ValueKey<int>(_currentPage);
                  final slideOffset = Tween<Offset>(
                    begin: Offset(
                      isIncoming
                          ? (_swipingForward ? 0.15 : -0.15)
                          : (_swipingForward ? -0.15 : 0.15),
                      0,
                    ),
                    end: Offset.zero,
                  ).animate(animation);

                  return SlideTransition(
                    position: slideOffset,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                layoutBuilder: (currentChild, previousChildren) {
                  // Stack children so the outgoing page doesn't cause a
                  // layout jump while fading out.
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: _WhatsNewPage(
                  key: ValueKey<int>(_currentPage),
                  payload: _payloads[_currentPage],
                  onDismissSheet: widget.onDismiss,
                  readOnly: widget.readOnly,
                ),
              ),

              // Page indicator dots + dismiss button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_payloads.length > 1) ...[
                      _PageIndicator(
                        count: _payloads.length,
                        current: _currentPage,
                        accentColor: accentColor,
                        onDotTap: _goToPage,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Dismiss button
                    SizedBox(
                      width: double.infinity,
                      child: BouncyTap(
                        onTap: widget.onDismiss,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.border),
                          ),
                          child: Center(
                            child: Text(
                              'Got it',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTheme.fontFamily,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PAGE INDICATOR DOTS — tappable
// =============================================================================

class _PageIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color accentColor;
  final ValueChanged<int> onDotTap;

  const _PageIndicator({
    required this.count,
    required this.current,
    required this.accentColor,
    required this.onDotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return GestureDetector(
          onTap: () => onDotTap(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            // Extra padding for comfortable tap target
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: isActive ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor
                    : context.textTertiary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// =============================================================================
// SINGLE PAGE CONTENT (one payload)
// =============================================================================

class _WhatsNewPage extends ConsumerWidget {
  final WhatsNewPayload payload;
  final VoidCallback onDismissSheet;
  final bool readOnly;

  const _WhatsNewPage({
    super.key,
    required this.payload,
    required this.onDismissSheet,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // MeshNodeBrain at size N renders at N*1.6 — accommodate that.
    const mascotSize = 56.0;
    const mascotRenderSize = mascotSize * 1.6; // 89.6

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ico mascot — SizedBox matches actual render size
          SizedBox(
            width: mascotRenderSize,
            height: mascotRenderSize,
            child: MeshNodeBrain(mood: MeshBrainMood.excited, size: mascotSize),
          ),
          const SizedBox(height: 4),

          // Headline
          Text(
            payload.headline,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: AppTheme.fontFamily,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          // Subtitle
          if (payload.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              payload.subtitle!,
              style: TextStyle(
                fontSize: 13,
                fontFamily: AppTheme.fontFamily,
                color: context.textTertiary,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 16),

          // Feature items
          ...payload.items.map(
            (item) => _WhatsNewItemCard(
              item: item,
              onDismissSheet: onDismissSheet,
              readOnly: readOnly,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// INDIVIDUAL FEATURE CARD
// =============================================================================

class _WhatsNewItemCard extends ConsumerWidget {
  final WhatsNewItem item;
  final VoidCallback onDismissSheet;
  final bool readOnly;

  const _WhatsNewItemCard({
    required this.item,
    required this.onDismissSheet,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;
    final itemColor = item.iconColor ?? accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: itemColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: icon + title
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: itemColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: itemColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.fontFamily,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            item.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              fontFamily: AppTheme.fontFamily,
              color: context.textSecondary,
            ),
          ),

          // Action buttons (hidden in read-only / history mode)
          if (!readOnly &&
              (item.deepLinkRoute != null || item.helpTopicId != null)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // Primary CTA
                if (item.deepLinkRoute != null)
                  Expanded(
                    child: BouncyTap(
                      onTap: () => _handleDeepLink(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: itemColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: itemColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            item.ctaLabel ?? 'Open',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTheme.fontFamily,
                              color: SemanticColors.onAccent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Spacer between buttons
                if (item.deepLinkRoute != null && item.helpTopicId != null)
                  const SizedBox(width: 10),

                // Learn more
                if (item.helpTopicId != null)
                  Expanded(
                    child: BouncyTap(
                      onTap: () => _handleLearnMore(context, ref),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: itemColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Learn more',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: AppTheme.fontFamily,
                              color: itemColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleDeepLink(BuildContext context, WidgetRef ref) {
    ref.haptics.tabChange();

    // Capture notifier BEFORE popping — once the sheet is unmounted
    // ref becomes invalid and any ref.read() silently fails.
    final whatsNewNotifier = ref.read(whatsNewProvider.notifier);

    // Mark as seen and close sheet
    whatsNewNotifier.markSeen();
    Navigator.of(context).pop();

    // Navigate after sheet closes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = item.deepLinkRoute;
      if (route == null) return;
      _navigateToRoute(route);
    });
  }

  void _handleLearnMore(BuildContext context, WidgetRef ref) {
    ref.haptics.tabChange();

    // Capture notifier references BEFORE popping the sheet.
    // Once the sheet is popped this widget is unmounted and ref becomes
    // invalid — any ref.read() after that silently fails.
    final whatsNewNotifier = ref.read(whatsNewProvider.notifier);
    final helpNotifier = ref.read(helpProvider.notifier);

    // Mark popup as seen and close sheet
    whatsNewNotifier.markSeen();
    Navigator.of(context).pop();

    // Navigate to the feature screen first, THEN start the help tour.
    // The tour overlay only renders inside a HelpTourController, which
    // lives on the destination screen — starting the tour without
    // navigating there means nothing visible happens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navContext = navigatorKey.currentContext;
      if (navContext == null) return;

      // Navigate to the feature screen (same logic as _handleDeepLink)
      final route = item.deepLinkRoute;
      if (route != null) {
        _navigateToRoute(route);
      }

      // Start the help tour after navigation so the HelpTourController
      // on the destination screen can pick it up.
      if (item.helpTopicId != null) {
        final topicId = item.helpTopicId!;
        final topic = HelpContent.getTopic(topicId);
        if (topic != null) {
          // Reset the topic first in case it was previously completed,
          // then start the tour. Use a delay to let the push animation
          // settle and the destination screen build its HelpTourController.
          Future<void>.delayed(const Duration(milliseconds: 600), () {
            helpNotifier.resetTopic(topicId);
            helpNotifier.startTour(topicId);
          });
        }
      }
    });
  }

  /// Navigates to the screen corresponding to [route].
  ///
  /// Bottom-nav routes (e.g. `/signals`) switch tabs via
  /// [mainShellIndexProvider] so the shell chrome stays intact.
  /// Drawer-only routes push a new [MaterialPageRoute].
  static void _navigateToRoute(String route) {
    // Bottom-nav tab routes — switch tab index instead of pushing.
    final tabIndex = _tabIndexForRoute(route);
    if (tabIndex != null) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;
      final container = ProviderScope.containerOf(ctx, listen: false);
      container.read(mainShellIndexProvider.notifier).setIndex(tabIndex);
      return;
    }

    // Drawer / push routes.
    final navContext = navigatorKey.currentContext;
    if (navContext == null) return;

    final Widget? screen = _screenForRoute(route);
    if (screen != null) {
      Navigator.of(
        navContext,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
    }
  }

  /// Returns the bottom-nav tab index for routes that live in the
  /// main shell, or null for routes that should be pushed.
  static int? _tabIndexForRoute(String route) {
    switch (route) {
      case '/signals':
        return 2; // Signals tab
      default:
        return null;
    }
  }

  /// Maps a deep link route string to the corresponding screen widget
  /// for routes that are pushed (not tab-based).
  static Widget? _screenForRoute(String route) {
    switch (route) {
      case '/nodedex':
        return const NodeDexScreen();
      case '/world-map':
        return const WorldMeshScreen();
      case '/reachability':
        return const MeshReachabilityScreen();
      default:
        return null;
    }
  }
}
