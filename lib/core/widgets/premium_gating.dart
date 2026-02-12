// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../safety/lifecycle_mixin.dart';
import '../../models/subscription_models.dart';
import '../../providers/connectivity_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/subscription/subscription_service.dart';
import '../../utils/snackbar.dart';
import '../theme.dart';
import 'animations.dart';

// =============================================================================
// PREMIUM GATING v2 - Unified Premium Gating Components
// =============================================================================
//
// Philosophy: Premium features are VISIBLE, EXPLAINABLE, TEASING, but NOT USABLE.
//
// Components:
// - PremiumPreviewBanner: Banner shown at top of screens in preview mode
// - LockOverlay: Wraps widgets to intercept taps and show lock indicator
// - DisabledControlWithLock: For specific controls (buttons, toggles, etc.)
// - PremiumInfoSheet: Bottom sheet with upgrade CTA (replaces PremiumUpsellSheet)
//
// =============================================================================

/// Banner shown at top of premium-gated screens to indicate preview/read-only mode.
///
/// Usage:
/// ```dart
/// Column(
///   children: [
///     if (!hasPremium) PremiumPreviewBanner(feature: PremiumFeature.automations),
///     Expanded(child: content),
///   ],
/// )
/// ```
class PremiumPreviewBanner extends ConsumerWidget {
  final PremiumFeature feature;
  final String? customMessage;

  const PremiumPreviewBanner({
    super.key,
    required this.feature,
    this.customMessage,
  });

  String get _defaultMessage {
    switch (feature) {
      case PremiumFeature.automations:
        return 'Preview Mode — Upgrade to create automations';
      case PremiumFeature.iftttIntegration:
        return 'Preview Mode — Upgrade to connect services';
      case PremiumFeature.homeWidgets:
        return 'Preview Mode — Upgrade to build widgets';
      case PremiumFeature.customRingtones:
        return 'Preview Mode — Upgrade to access full library';
      case PremiumFeature.premiumThemes:
        return 'Preview Mode — Upgrade to unlock all colors';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPremium = ref.watch(hasFeatureProvider(feature));
    if (hasPremium) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () =>
          showPremiumInfoSheet(context: context, ref: ref, feature: feature),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade700.withValues(alpha: 0.9),
              Colors.grey.shade800.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                customMessage ?? _defaultMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps any widget to show a lock overlay and intercept taps when locked.
///
/// When locked, tapping anywhere on the child opens PremiumInfoSheet.
/// The child is rendered normally but with reduced opacity and a lock badge.
///
/// Usage:
/// ```dart
/// LockOverlay(
///   feature: PremiumFeature.widgets,
///   child: MyWidgetCard(),
/// )
/// ```
class LockOverlay extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget child;
  final bool showLockBadge;
  final double lockedOpacity;
  final Alignment badgeAlignment;

  const LockOverlay({
    super.key,
    required this.feature,
    required this.child,
    this.showLockBadge = true,
    this.lockedOpacity = 0.6,
    this.badgeAlignment = Alignment.topRight,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPremium = ref.watch(hasFeatureProvider(feature));

    if (hasPremium) {
      return child;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showPremiumInfoSheet(context: context, ref: ref, feature: feature);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: lockedOpacity,
            child: IgnorePointer(child: child),
          ),
          if (showLockBadge)
            Positioned(
              top:
                  badgeAlignment == Alignment.topRight ||
                      badgeAlignment == Alignment.topLeft
                  ? -6
                  : null,
              bottom:
                  badgeAlignment == Alignment.bottomRight ||
                      badgeAlignment == Alignment.bottomLeft
                  ? -6
                  : null,
              right:
                  badgeAlignment == Alignment.topRight ||
                      badgeAlignment == Alignment.bottomRight
                  ? -6
                  : null,
              left:
                  badgeAlignment == Alignment.topLeft ||
                      badgeAlignment == Alignment.bottomLeft
                  ? -6
                  : null,
              child: const _LockBadge(),
            ),
        ],
      ),
    );
  }
}

/// Lock badge shown on locked content
class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade500, Colors.grey.shade700],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(Icons.lock, size: 12, color: Colors.white),
    );
  }
}

/// Wraps a specific control (button, toggle, input) to disable and add lock when premium-gated.
///
/// When locked:
/// - Control is visually disabled (greyed out)
/// - Lock icon shown inline
/// - Tap opens PremiumInfoSheet instead of performing action
///
/// Usage:
/// ```dart
/// DisabledControlWithLock(
///   feature: PremiumFeature.iftttIntegration,
///   child: ElevatedButton(onPressed: _save, child: Text('Save')),
/// )
/// ```
class DisabledControlWithLock extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget child;
  final bool showInlineLock;

  const DisabledControlWithLock({
    super.key,
    required this.feature,
    required this.child,
    this.showInlineLock = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPremium = ref.watch(hasFeatureProvider(feature));

    if (hasPremium) {
      return child;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        showPremiumInfoSheet(context: context, ref: ref, feature: feature);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(opacity: 0.5, child: IgnorePointer(child: child)),
          if (showInlineLock) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock, size: 14, color: Colors.grey.shade500),
          ],
        ],
      ),
    );
  }
}

/// A button that is disabled when premium is required, with lock icon.
///
/// Usage:
/// ```dart
/// PremiumButton(
///   feature: PremiumFeature.automations,
///   onPressed: _save,
///   child: Text('Save Automation'),
/// )
/// ```
class PremiumButton extends ConsumerWidget {
  final PremiumFeature feature;
  final VoidCallback onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool filled;

  const PremiumButton({
    super.key,
    required this.feature,
    required this.onPressed,
    required this.child,
    this.style,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPremium = ref.watch(hasFeatureProvider(feature));

    if (hasPremium) {
      return filled
          ? FilledButton(onPressed: onPressed, style: style, child: child)
          : OutlinedButton(onPressed: onPressed, style: style, child: child);
    }

    return filled
        ? FilledButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              showPremiumInfoSheet(
                context: context,
                ref: ref,
                feature: feature,
              );
            },
            style: style?.copyWith(
              backgroundColor: WidgetStateProperty.all(Colors.grey.shade600),
            ),
            icon: Icon(Icons.lock, size: 16, color: Colors.grey.shade300),
            label: child,
          )
        : OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              showPremiumInfoSheet(
                context: context,
                ref: ref,
                feature: feature,
              );
            },
            style: style,
            icon: Icon(Icons.lock, size: 16, color: Colors.grey.shade500),
            label: Opacity(opacity: 0.7, child: child),
          );
  }
}

/// A switch/toggle that is disabled when premium is required.
class PremiumSwitch extends ConsumerWidget {
  final PremiumFeature feature;
  final bool value;
  final ValueChanged<bool> onChanged;

  const PremiumSwitch({
    super.key,
    required this.feature,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPremium = ref.watch(hasFeatureProvider(feature));

    if (hasPremium) {
      return Switch.adaptive(value: value, onChanged: onChanged);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showPremiumInfoSheet(context: context, ref: ref, feature: feature);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: 0.5,
            child: IgnorePointer(
              child: Switch.adaptive(value: false, onChanged: (_) {}),
            ),
          ),
          Icon(Icons.lock, size: 14, color: Colors.grey.shade500),
        ],
      ),
    );
  }
}

/// A text field that is disabled when premium is required.
class PremiumTextField extends ConsumerWidget {
  final PremiumFeature feature;
  final TextEditingController? controller;
  final String? hintText;
  final InputDecoration? decoration;
  final int? maxLines;

  const PremiumTextField({
    super.key,
    required this.feature,
    this.controller,
    this.hintText,
    this.decoration,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPremium = ref.watch(hasFeatureProvider(feature));

    final baseDecoration = decoration ?? InputDecoration(hintText: hintText);

    if (hasPremium) {
      return TextField(
        controller: controller,
        decoration: baseDecoration,
        maxLines: maxLines,
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        showPremiumInfoSheet(context: context, ref: ref, feature: feature);
      },
      child: AbsorbPointer(
        child: Opacity(
          opacity: 0.5,
          child: TextField(
            controller: controller,
            decoration: baseDecoration.copyWith(
              suffixIcon: Icon(
                Icons.lock,
                size: 18,
                color: Colors.grey.shade500,
              ),
            ),
            maxLines: maxLines,
            enabled: false,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PremiumInfoSheet - The unified premium upgrade bottom sheet
// =============================================================================

/// Shows the premium info sheet for a feature.
///
/// Returns true if purchase was successful, false otherwise.
Future<bool> showPremiumInfoSheet({
  required BuildContext context,
  required WidgetRef ref,
  required PremiumFeature feature,
  String? customDescription,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => PremiumInfoSheet(
      feature: feature,
      customDescription: customDescription,
    ),
  );

  return result ?? false;
}

/// Premium info bottom sheet with feature benefits and upgrade CTA.
///
/// This is the ONLY sheet that should be shown when users tap locked controls.
/// It replaces PremiumUpsellSheet for consistency.
class PremiumInfoSheet extends ConsumerStatefulWidget {
  final PremiumFeature feature;
  final String? customDescription;

  const PremiumInfoSheet({
    super.key,
    required this.feature,
    this.customDescription,
  });

  @override
  ConsumerState<PremiumInfoSheet> createState() => _PremiumInfoSheetState();
}

class _PremiumInfoSheetState extends ConsumerState<PremiumInfoSheet>
    with LifecycleSafeMixin<PremiumInfoSheet> {
  bool _isLoading = false;

  OneTimePurchase? get _purchase =>
      OneTimePurchases.getByFeature(widget.feature);

  IconData get _featureIcon {
    switch (widget.feature) {
      case PremiumFeature.automations:
        return Icons.bolt;
      case PremiumFeature.iftttIntegration:
        return Icons.webhook;
      case PremiumFeature.homeWidgets:
        return Icons.widgets;
      case PremiumFeature.customRingtones:
        return Icons.music_note;
      case PremiumFeature.premiumThemes:
        return Icons.palette;
    }
  }

  String get _headline {
    switch (widget.feature) {
      case PremiumFeature.automations:
        return 'Automate Your Mesh';
      case PremiumFeature.iftttIntegration:
        return 'Connect Everything';
      case PremiumFeature.homeWidgets:
        return 'Build Your Dashboard';
      case PremiumFeature.customRingtones:
        return 'Unlock Sound Library';
      case PremiumFeature.premiumThemes:
        return 'Make It Yours';
    }
  }

  String get _description {
    if (widget.customDescription != null) return widget.customDescription!;

    switch (widget.feature) {
      case PremiumFeature.automations:
        return 'Create powerful automations that trigger alerts, send messages, and react to mesh events automatically.';
      case PremiumFeature.iftttIntegration:
        return 'Connect your mesh network to 700+ apps and services via IFTTT webhooks.';
      case PremiumFeature.homeWidgets:
        return 'Build custom dashboard widgets with live data, charts, and real-time monitoring.';
      case PremiumFeature.customRingtones:
        return 'Access 7,000+ ringtones from classic tunes to TV themes and movie soundtracks.';
      case PremiumFeature.premiumThemes:
        return 'Personalize your app with 12 stunning accent colors.';
    }
  }

  List<_Benefit> get _benefits {
    switch (widget.feature) {
      case PremiumFeature.automations:
        return [
          const _Benefit(
            Icons.notifications_active,
            'Smart Alerts',
            'Battery low, node offline, and more',
          ),
          const _Benefit(
            Icons.schedule,
            'Scheduled Actions',
            'Run at specific times',
          ),
          const _Benefit(
            Icons.location_on,
            'Geofence Triggers',
            'React to location events',
          ),
        ];
      case PremiumFeature.iftttIntegration:
        return [
          const _Benefit(
            Icons.home,
            'Smart Home',
            'Control lights, locks, and devices',
          ),
          const _Benefit(
            Icons.notifications,
            'Cross-Platform',
            'Slack, Discord, email alerts',
          ),
          const _Benefit(
            Icons.table_chart,
            'Logging',
            'Save events to spreadsheets',
          ),
        ];
      case PremiumFeature.homeWidgets:
        return [
          const _Benefit(
            Icons.show_chart,
            'Live Charts',
            'Real-time data visualization',
          ),
          const _Benefit(
            Icons.battery_full,
            'Monitoring',
            'Battery, sensors, telemetry',
          ),
          const _Benefit(
            Icons.dashboard_customize,
            'Custom Layouts',
            'Build your own views',
          ),
        ];
      case PremiumFeature.customRingtones:
        return [
          const _Benefit(
            Icons.library_music,
            '10,000+ Tones',
            'Massive searchable library',
          ),
          const _Benefit(
            Icons.search,
            'Easy Search',
            'Find any tune instantly',
          ),
          const _Benefit(Icons.star, 'Custom Presets', 'Save your favorites'),
        ];
      case PremiumFeature.premiumThemes:
        return [
          const _Benefit(Icons.palette, '15 Colors', 'Premium accent options'),
          const _Benefit(
            Icons.auto_awesome,
            'Exclusive',
            'Unique combinations',
          ),
        ];
    }
  }

  Future<void> _handlePurchase() async {
    final purchase = _purchase;
    if (purchase == null) return;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      showErrorSnackBar(context, 'Purchases require an internet connection.');
      return;
    }

    safeSetState(() => _isLoading = true);

    // Capture haptic service before await
    final haptics = ref.haptics;

    try {
      haptics.buttonTap();
      final result = await purchaseProduct(ref, purchase.productId);

      if (!mounted) return;

      switch (result) {
        case PurchaseResult.success:
          haptics.success();
          showSuccessSnackBar(context, '${purchase.name} unlocked!');
          Navigator.of(context).pop(true);

        case PurchaseResult.canceled:
          safeSetState(() => _isLoading = false);

        case PurchaseResult.error:
          haptics.error();
          showErrorSnackBar(context, 'Purchase failed. Please try again.');
          safeSetState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Something went wrong. Please try again.');
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      showErrorSnackBar(
        context,
        'Restoring purchases requires an internet connection.',
      );
      return;
    }

    safeSetState(() => _isLoading = true);

    try {
      final restored = await restorePurchases(ref);

      if (!mounted) return;

      if (restored) {
        final hasFeature = ref.read(hasFeatureProvider(widget.feature));
        if (hasFeature) {
          showSuccessSnackBar(context, 'Purchases restored!');
          Navigator.of(context).pop(true);
          return;
        }
      }

      showInfoSnackBar(context, 'No purchases found to restore');
      safeSetState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to restore purchases');
      safeSetState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storePrice = storeProductsAsync.whenOrNull(
      data: (products) => products[_purchase?.productId]?.priceString,
    );
    final displayPrice =
        storePrice ?? '\$${_purchase?.price.toStringAsFixed(2) ?? "3.99"}';

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                // Feature icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          context.accentColor,
                          context.accentColor.withValues(alpha: 0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.accentColor.withValues(alpha: 0.25),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Icon(_featureIcon, size: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                // Headline
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  _description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Benefits
                ..._benefits.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            b.icon,
                            color: context.accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                b.subtitle,
                                style: TextStyle(
                                  color: context.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Purchase button
                BouncyTap(
                  onTap: _isLoading ? null : _handlePurchase,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.accentColor,
                          context.accentColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: context.accentColor.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Unlock for $displayPrice',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // One-time purchase note
                Text(
                  'One-time purchase • Yours forever',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // Secondary actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : _handleRestore,
                      child: Text(
                        'Restore Purchases',
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        'Not now',
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefit {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Benefit(this.icon, this.title, this.subtitle);
}

// =============================================================================
// Explanation Card for features like IFTTT
// =============================================================================

/// An explanatory card shown above premium-gated sections.
/// Explains what the feature does and why it's valuable.
///
/// Usage:
/// ```dart
/// PremiumExplanationCard(
///   feature: PremiumFeature.iftttIntegration,
///   title: 'Connect to 700+ Services',
///   description: 'Trigger smart home devices, log events to spreadsheets...',
///   exampleTitle: 'Example: Node goes offline',
///   exampleDescription: 'Automatically turn on a smart light...',
/// )
/// ```
class PremiumExplanationCard extends ConsumerWidget {
  final PremiumFeature feature;
  final String title;
  final String description;
  final String? exampleTitle;
  final String? exampleDescription;
  final bool initiallyExpanded;

  const PremiumExplanationCard({
    super.key,
    required this.feature,
    required this.title,
    required this.description,
    this.exampleTitle,
    this.exampleDescription,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPremium = ref.watch(hasFeatureProvider(feature));

    // Hide if premium is unlocked
    if (hasPremium) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: context.textSecondary,
          collapsedIconColor: context.textSecondary,
          leading: Icon(
            Icons.lock_outline,
            color: context.textSecondary,
            size: 24,
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Text(
            description,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            if (exampleTitle != null && exampleDescription != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: context.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Example',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: context.accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exampleTitle!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      exampleDescription!,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showPremiumInfoSheet(
                  context: context,
                  ref: ref,
                  feature: feature,
                ),
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text('Unlock Feature'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
