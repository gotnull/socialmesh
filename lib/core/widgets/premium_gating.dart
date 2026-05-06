// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/l10n_extension.dart';
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

  String _defaultMessage(BuildContext context) {
    switch (feature) {
      case PremiumFeature.automations:
        return context.l10n.premiumPreviewAutomations;
      case PremiumFeature.iftttIntegration:
        return context.l10n.premiumPreviewIfttt;
      case PremiumFeature.homeWidgets:
        return context.l10n.premiumPreviewWidgets;
      case PremiumFeature.customRingtones:
        return context.l10n.premiumPreviewRingtones;
      case PremiumFeature.premiumThemes:
        return context.l10n.premiumPreviewThemes;
      case PremiumFeature.translation:
        return context.l10n.premiumPreviewTranslation;
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
              SemanticColors.divider.withValues(alpha: 0.9),
              SemanticColors.placeholder.withValues(alpha: 0.9),
            ],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.white, size: 18),
            const SizedBox(width: AppTheme.spacing10),
            Expanded(
              child: Text(
                customMessage ?? _defaultMessage(context),
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
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
              child: Text(
                context.l10n.premiumUpgrade,
                style: const TextStyle(
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
          colors: [SemanticColors.muted, SemanticColors.divider],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: SemanticColors.disabled.withValues(alpha: 0.3),
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
            const SizedBox(width: AppTheme.spacing6),
            Icon(Icons.lock, size: 14, color: SemanticColors.muted),
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
              backgroundColor: WidgetStateProperty.all(SemanticColors.muted),
            ),
            icon: Icon(Icons.lock, size: 16, color: SemanticColors.disabled),
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
            icon: Icon(Icons.lock, size: 16, color: SemanticColors.muted),
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
      return ThemedSwitch(value: value, onChanged: onChanged);
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
              child: ThemedSwitch(value: false, onChanged: (_) {}),
            ),
          ),
          Icon(Icons.lock, size: 14, color: SemanticColors.muted),
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
        maxLength: 100,
        controller: controller,
        decoration: baseDecoration.copyWith(counterText: ''),
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
            maxLength: 100,
            controller: controller,
            decoration: baseDecoration.copyWith(
              counterText: '',
              suffixIcon: Icon(
                Icons.lock,
                size: 18,
                color: SemanticColors.muted,
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
      case PremiumFeature.translation:
        return Icons.translate;
    }
  }

  String get _headline {
    switch (widget.feature) {
      case PremiumFeature.automations:
        return context.l10n.premiumHeadlineAutomations;
      case PremiumFeature.iftttIntegration:
        return context.l10n.premiumHeadlineIfttt;
      case PremiumFeature.homeWidgets:
        return context.l10n.premiumHeadlineWidgetsAlt;
      case PremiumFeature.customRingtones:
        return context.l10n.premiumHeadlineRingtonesAlt;
      case PremiumFeature.premiumThemes:
        return context.l10n.premiumHeadlineThemes;
      case PremiumFeature.translation:
        return context.l10n.premiumHeadlineTranslation;
    }
  }

  String get _description {
    if (widget.customDescription != null) return widget.customDescription!;

    switch (widget.feature) {
      case PremiumFeature.automations:
        return context.l10n.premiumDescAutomations;
      case PremiumFeature.iftttIntegration:
        return context.l10n.premiumDescIfttt;
      case PremiumFeature.homeWidgets:
        return context.l10n.premiumDescWidgets;
      case PremiumFeature.customRingtones:
        return context.l10n.premiumDescRingtones;
      case PremiumFeature.premiumThemes:
        return context.l10n.premiumDescThemes;
      case PremiumFeature.translation:
        return context.l10n.premiumDescTranslation;
    }
  }

  List<_Benefit> get _benefits {
    switch (widget.feature) {
      case PremiumFeature.automations:
        return [
          _Benefit(
            Icons.notifications_active,
            context.l10n.premiumBenefitSmartAlerts,
            context.l10n.premiumBenefitSmartAlertsDesc,
          ),
          _Benefit(
            Icons.schedule,
            context.l10n.premiumBenefitScheduledActions,
            context.l10n.premiumBenefitScheduledActionsShort,
          ),
          _Benefit(
            Icons.location_on,
            context.l10n.premiumBenefitGeofenceTriggers,
            context.l10n.premiumBenefitGeofenceTriggersShort,
          ),
        ];
      case PremiumFeature.iftttIntegration:
        return [
          _Benefit(
            Icons.home,
            context.l10n.premiumBenefitSmartHome,
            context.l10n.premiumBenefitSmartHomeDesc,
          ),
          _Benefit(
            Icons.notifications,
            context.l10n.premiumBenefitCrossPlatform,
            context.l10n.premiumBenefitCrossPlatformDesc,
          ),
          _Benefit(
            Icons.table_chart,
            context.l10n.premiumBenefitLogging,
            context.l10n.premiumBenefitLoggingDesc,
          ),
        ];
      case PremiumFeature.homeWidgets:
        return [
          _Benefit(
            Icons.show_chart,
            context.l10n.premiumBenefitLiveChartsAlt,
            context.l10n.premiumBenefitLiveChartsAltDesc,
          ),
          _Benefit(
            Icons.battery_full,
            context.l10n.premiumBenefitMonitoring,
            context.l10n.premiumBenefitMonitoringDesc,
          ),
          _Benefit(
            Icons.dashboard_customize,
            context.l10n.premiumBenefitCustomLayouts,
            context.l10n.premiumBenefitCustomLayoutsDesc,
          ),
        ];
      case PremiumFeature.customRingtones:
        return [
          _Benefit(
            Icons.library_music,
            context.l10n.premiumBenefit10000Tones,
            context.l10n.premiumBenefit10000TonesDesc,
          ),
          _Benefit(
            Icons.search,
            context.l10n.premiumBenefitEasySearch,
            context.l10n.premiumBenefitEasySearchDesc,
          ),
          _Benefit(
            Icons.star,
            context.l10n.premiumBenefitCustomPresets,
            context.l10n.premiumBenefitCustomPresetsDesc,
          ),
        ];
      case PremiumFeature.premiumThemes:
        return [
          _Benefit(
            Icons.palette,
            context.l10n.premiumBenefit15Colors,
            context.l10n.premiumBenefit15ColorsDesc,
          ),
          _Benefit(
            Icons.auto_awesome,
            context.l10n.premiumBenefitExclusive,
            context.l10n.premiumBenefitExclusiveDesc,
          ),
        ];
      case PremiumFeature.translation:
        return [
          _Benefit(
            Icons.translate,
            context.l10n.premiumBenefitInstantTranslation,
            context.l10n.premiumBenefitInstantTranslationDesc,
          ),
          _Benefit(
            Icons.language,
            context.l10n.premiumBenefitAutoDetect,
            context.l10n.premiumBenefitAutoDetectDesc,
          ),
          _Benefit(
            Icons.cached,
            context.l10n.premiumBenefitSmartCache,
            context.l10n.premiumBenefitSmartCacheDesc,
          ),
        ];
    }
  }

  Future<void> _handlePurchase() async {
    final purchase = _purchase;
    if (purchase == null) return;

    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      showErrorSnackBar(context, context.l10n.premiumPurchaseRequiresInternet);
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
          showSuccessSnackBar(
            context,
            context.l10n.premiumPurchaseUnlocked(purchase.name),
          );
          safeNavigatorPop(true);

        case PurchaseResult.canceled:
          safeSetState(() => _isLoading = false);

        case PurchaseResult.error:
          haptics.error();
          showErrorSnackBar(context, context.l10n.premiumPurchaseFailed);
          safeSetState(() => _isLoading = false);
      }
    } catch (e) {
      showErrorSnackBar(context, context.l10n.premiumPurchaseError);
      safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      showErrorSnackBar(context, context.l10n.premiumRestoreRequiresInternet);
      return;
    }

    safeSetState(() => _isLoading = true);

    try {
      final restored = await restorePurchases(ref);

      if (!mounted) return;

      if (restored) {
        final hasFeature = ref.read(hasFeatureProvider(widget.feature));
        if (hasFeature) {
          showSuccessSnackBar(context, context.l10n.premiumRestoreSuccess);
          safeNavigatorPop(true);
          return;
        }
      }

      showInfoSnackBar(context, context.l10n.premiumRestoreNone);
      safeSetState(() => _isLoading = false);
    } catch (e) {
      showErrorSnackBar(context, context.l10n.premiumRestoreFailed);
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
        storePrice ??
        '\$${_purchase?.price.toStringAsFixed(2) ?? "3.99"}'; // lint-allow: hardcoded-string

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
                color: SemanticColors.muted,
                borderRadius: BorderRadius.circular(AppTheme.radius2),
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
                const SizedBox(height: AppTheme.spacing20),

                // Headline
                Text(
                  _headline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),

                // Description
                Text(
                  _description,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing24),

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
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius10,
                            ),
                          ),
                          child: Icon(
                            b.icon,
                            color: context.accentColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
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
                const SizedBox(height: AppTheme.spacing20),

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
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
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
                              Icon(_featureIcon, color: Colors.white),
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                context.l10n.premiumUnlockFor(displayPrice),
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
                const SizedBox(height: AppTheme.spacing8),

                // One-time purchase note
                Text(
                  context.l10n.premiumOneTimePurchase,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: AppTheme.spacing12),

                // Secondary actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : _handleRestore,
                      child: Text(
                        context.l10n.premiumRestorePurchases,
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        context.l10n.premiumNotNow,
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
        borderRadius: BorderRadius.circular(AppTheme.radius16),
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
          childrenPadding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            0,
            16,
            16,
          ),
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
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
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
                        const SizedBox(width: AppTheme.spacing8),
                        Text(
                          context.l10n.premiumExample,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: context.accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      exampleTitle!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
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
              const SizedBox(height: AppTheme.spacing12),
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
                label: Text(context.l10n.premiumUnlockFeature),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
