// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/nodedex/screens/nodedex_screen.dart';
import '../../features/onboarding/widgets/mesh_node_brain.dart';
import '../../providers/help_providers.dart';
import '../../providers/whats_new_providers.dart';
import '../../services/haptic_service.dart';
import '../help/help_content.dart';
import '../navigation.dart';
import '../theme.dart';
import '../widgets/animations.dart';
import 'whats_new_registry.dart';

/// Presents the What's New bottom sheet for a given [payload].
///
/// The sheet is shown as a modal bottom sheet consistent with the app's
/// design language. It uses the Ico mascot (MeshNodeBrain) and renders
/// each [WhatsNewItem] with its icon, title, description, and optional
/// CTA / "Learn more" actions.
///
/// The sheet marks the payload as seen only when the user explicitly
/// dismisses it (tap "Got it", swipe down, or tap outside).
///
/// Call [WhatsNewSheet.showIfNeeded] from the main shell's initState
/// post-frame callback. It guards against showing more than once per
/// session via [WhatsNewState.shownThisSession].
class WhatsNewSheet {
  WhatsNewSheet._();

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

    _present(context, state.pendingPayload!, ref);
  }

  static Future<void> _present(
    BuildContext context,
    WhatsNewPayload payload,
    WidgetRef ref,
  ) async {
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
      builder: (sheetContext) => _WhatsNewSheetContent(
        payload: payload,
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
// SHEET CONTENT
// =============================================================================

class _WhatsNewSheetContent extends ConsumerWidget {
  final WhatsNewPayload payload;
  final VoidCallback onDismiss;

  const _WhatsNewSheetContent({required this.payload, required this.onDismiss});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: accentColor.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag pill
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Scrollable body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ico mascot
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: MeshNodeBrain(
                        mood: MeshBrainMood.excited,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 12),

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

                    const SizedBox(height: 20),

                    // Feature items
                    ...payload.items.map(
                      (item) => _WhatsNewItemCard(
                        item: item,
                        onDismissSheet: onDismiss,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Dismiss button
                    SizedBox(
                      width: double.infinity,
                      child: BouncyTap(
                        onTap: onDismiss,
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
            ),
          ],
        ),
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

  const _WhatsNewItemCard({required this.item, required this.onDismissSheet});

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

          // Action buttons
          if (item.deepLinkRoute != null || item.helpTopicId != null) ...[
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
      final navContext = navigatorKey.currentContext;
      if (navContext == null) return;

      // Map known deep link routes to screens
      if (item.deepLinkRoute == '/nodedex') {
        Navigator.of(
          navContext,
        ).push(MaterialPageRoute<void>(builder: (_) => const NodeDexScreen()));
      }
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
      if (item.deepLinkRoute == '/nodedex') {
        Navigator.of(
          navContext,
        ).push(MaterialPageRoute<void>(builder: (_) => const NodeDexScreen()));
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
}
