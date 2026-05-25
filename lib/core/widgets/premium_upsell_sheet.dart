// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
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

/// Premium upsell sheet that explains value and provides upgrade path.
///
/// This is the "interception" point for the "look but don't touch" pattern.
/// Users land here when they try to save/enable a premium feature.
///
/// Key UX principles:
/// - Explain why this is valuable (not just "upgrade required")
/// - Show exactly what they would unlock
/// - Provide immediate upgrade path
/// - Allow backing out without losing configuration
class PremiumUpsellSheet extends ConsumerStatefulWidget {
  final PremiumFeature feature;
  final String? featureDescription;

  const PremiumUpsellSheet({
    super.key,
    required this.feature,
    this.featureDescription,
  });

  @override
  ConsumerState<PremiumUpsellSheet> createState() => _PremiumUpsellSheetState();
}

class _PremiumUpsellSheetState extends ConsumerState<PremiumUpsellSheet>
    with LifecycleSafeMixin<PremiumUpsellSheet> {
  bool _isLoading = false;

  /// Get the purchase info for this feature
  OneTimePurchase? get _purchase =>
      OneTimePurchases.getByFeature(widget.feature);

  /// Get feature-specific benefits
  List<_FeatureBenefit> get _benefits {
    switch (widget.feature) {
      case PremiumFeature.automations:
        return [
          _FeatureBenefit(
            icon: Icons.bolt,
            title: context.l10n.premiumBenefitUnlimitedAutomations,
            description: context.l10n.premiumBenefitUnlimitedAutomationsDesc,
          ),
          _FeatureBenefit(
            icon: Icons.notifications_active,
            title: context.l10n.premiumBenefitSmartNotifications,
            description: context.l10n.premiumBenefitSmartNotificationsDesc,
          ),
          _FeatureBenefit(
            icon: Icons.schedule,
            title: context.l10n.premiumBenefitScheduledActions,
            description: context.l10n.premiumBenefitScheduledActionsDesc,
          ),
          _FeatureBenefit(
            icon: Icons.location_on,
            title: context.l10n.premiumBenefitGeofenceTriggers,
            description: context.l10n.premiumBenefitGeofenceTriggersDesc,
          ),
        ];
      case PremiumFeature.iftttIntegration:
        return [
          _FeatureBenefit(
            icon: Icons.webhook,
            title: context.l10n.premiumBenefitConnect700,
            description: context.l10n.premiumBenefitConnect700Desc,
          ),
          _FeatureBenefit(
            icon: Icons.home,
            title: context.l10n.premiumBenefitSmartHomeControl,
            description: context.l10n.premiumBenefitSmartHomeControlDesc,
          ),
          _FeatureBenefit(
            icon: Icons.notifications,
            title: context.l10n.premiumBenefitCrossPlatformAlerts,
            description: context.l10n.premiumBenefitCrossPlatformAlertsDesc,
          ),
        ];
      case PremiumFeature.premiumThemes:
        return [
          _FeatureBenefit(
            icon: Icons.palette,
            title: context.l10n.premiumBenefit12Colors,
            description: context.l10n.premiumBenefit12ColorsDesc,
          ),
          _FeatureBenefit(
            icon: Icons.auto_awesome,
            title: context.l10n.premiumBenefitExclusiveStyles,
            description: context.l10n.premiumBenefitExclusiveStylesDesc,
          ),
        ];
      case PremiumFeature.customRingtones:
        return [
          _FeatureBenefit(
            icon: Icons.library_music,
            title: context.l10n.premiumBenefit7000Ringtones,
            description: context.l10n.premiumBenefit7000RingtonesDesc,
          ),
          _FeatureBenefit(
            icon: Icons.search,
            title: context.l10n.premiumBenefitSearchableLibrary,
            description: context.l10n.premiumBenefitSearchableLibraryDesc,
          ),
        ];
      case PremiumFeature.homeWidgets:
        return [
          _FeatureBenefit(
            icon: Icons.dashboard_customize,
            title: context.l10n.premiumBenefitCustomDashboards,
            description: context.l10n.premiumBenefitCustomDashboardsDesc,
          ),
          _FeatureBenefit(
            icon: Icons.show_chart,
            title: context.l10n.premiumBenefitLiveCharts,
            description: context.l10n.premiumBenefitLiveChartsDesc,
          ),
          _FeatureBenefit(
            icon: Icons.battery_charging_full,
            title: context.l10n.premiumBenefitBatterySensors,
            description: context.l10n.premiumBenefitBatterySensorsDesc,
          ),
        ];
      case PremiumFeature.translation:
        return [
          _FeatureBenefit(
            icon: Icons.translate,
            title: context.l10n.premiumBenefitInstantTranslation,
            description: context.l10n.premiumBenefitInstantTranslationDesc,
          ),
          _FeatureBenefit(
            icon: Icons.language,
            title: context.l10n.premiumBenefitAutoDetect,
            description: context.l10n.premiumBenefitAutoDetectDesc,
          ),
          _FeatureBenefit(
            icon: Icons.cached,
            title: context.l10n.premiumBenefitSmartCache,
            description: context.l10n.premiumBenefitSmartCacheDesc,
          ),
        ];
    }
  }

  /// Get the value proposition headline
  String get _headline {
    switch (widget.feature) {
      case PremiumFeature.automations:
        return context.l10n.premiumHeadlineAutomations;
      case PremiumFeature.iftttIntegration:
        return context.l10n.premiumHeadlineIfttt;
      case PremiumFeature.premiumThemes:
        return context.l10n.premiumHeadlineThemes;
      case PremiumFeature.customRingtones:
        return context.l10n.premiumHeadlineRingtones;
      case PremiumFeature.homeWidgets:
        return context.l10n.premiumHeadlineWidgets;
      case PremiumFeature.translation:
        return context.l10n.premiumHeadlineTranslation;
    }
  }

  /// Get contextual subtitle
  String get _subtitle {
    if (widget.featureDescription != null) {
      return widget.featureDescription!;
    }

    switch (widget.feature) {
      case PremiumFeature.automations:
        return context.l10n.premiumSubtitleAutomations;
      case PremiumFeature.iftttIntegration:
        return context.l10n.premiumSubtitleIfttt;
      case PremiumFeature.premiumThemes:
        return context.l10n.premiumSubtitleThemes;
      case PremiumFeature.customRingtones:
        return context.l10n.premiumSubtitleRingtones;
      case PremiumFeature.homeWidgets:
        return context.l10n.premiumSubtitleWidgets;
      case PremiumFeature.translation:
        return context.l10n.premiumSubtitleTranslation;
    }
  }

  /// Feature-specific icon for the header.
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
          // Close sheet and return success
          safeNavigatorPop(true);

        case PurchaseResult.canceled:
          // User canceled, do nothing
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
        // Check if this specific feature was restored
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
    final purchase = _purchase;
    final storeProductsAsync = ref.watch(storeProductsProvider);

    // Get actual price from store
    final storePrice = storeProductsAsync.when(
      data: (products) => products[purchase?.productId]?.priceString,
      loading: () => null,
      error: (error, stack) => null,
    );

    final displayPrice =
        storePrice ??
        '\$${purchase?.price.toStringAsFixed(2) ?? "3.99"}'; // lint-allow: hardcoded-string

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radius20),
          ),
        ),
        child: Column(
          children: [
            // Handle
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
                clipBehavior: Clip.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing20,
                ),
                children: [
                  // Premium icon
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.warningYellow, AccentColors.orange],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.warningYellow.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(_featureIcon, size: 40, color: Colors.white),
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

                  // Subtitle
                  Text(
                    _subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing24),

                  // Benefits list
                  ..._benefits.map(
                    (benefit) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius12,
                              ),
                            ),
                            child: Icon(
                              benefit.icon,
                              color: context.accentColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  benefit.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  benefit.description,
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing8),

                  // "Your automation is safe" message
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(
                        color: AppTheme.successGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: AppTheme.successGreen,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Expanded(
                          child: Text(
                            context.l10n.premiumConfigSaved,
                            style: TextStyle(
                              color: AppTheme.successGreen,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacing24),

                  // Purchase button
                  BouncyTap(
                    onTap: _isLoading ? null : _handlePurchase,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.warningYellow, AccentColors.orange],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.warningYellow.withValues(
                              alpha: 0.3,
                            ),
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

                  const SizedBox(height: AppTheme.spacing12),

                  // One-time purchase note
                  Text(
                    context.l10n.premiumOneTimePurchase,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),

                  const SizedBox(height: AppTheme.spacing16),

                  // Restore purchases
                  TextButton(
                    onPressed: _isLoading ? null : _handleRestore,
                    child: Text(
                      context.l10n.premiumRestorePurchases,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // Bottom padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureBenefit {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureBenefit({
    required this.icon,
    required this.title,
    required this.description,
  });
}
