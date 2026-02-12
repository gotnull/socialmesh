// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
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
            title: 'Unlimited Automations',
            description: 'Create as many rules as you need',
          ),
          _FeatureBenefit(
            icon: Icons.notifications_active,
            title: 'Smart Notifications',
            description: 'Get alerts for battery, offline nodes, and more',
          ),
          _FeatureBenefit(
            icon: Icons.schedule,
            title: 'Scheduled Actions',
            description: 'Run automations at specific times',
          ),
          _FeatureBenefit(
            icon: Icons.location_on,
            title: 'Geofence Triggers',
            description: 'React when nodes enter or exit areas',
          ),
        ];
      case PremiumFeature.iftttIntegration:
        return [
          _FeatureBenefit(
            icon: Icons.webhook,
            title: 'Connect 700+ Services',
            description: 'Smart home, notifications, spreadsheets & more',
          ),
          _FeatureBenefit(
            icon: Icons.home,
            title: 'Smart Home Control',
            description: 'Trigger lights, locks, and devices',
          ),
          _FeatureBenefit(
            icon: Icons.notifications,
            title: 'Cross-Platform Alerts',
            description: 'Send to Slack, Discord, email, and more',
          ),
        ];
      case PremiumFeature.premiumThemes:
        return [
          _FeatureBenefit(
            icon: Icons.palette,
            title: '12 Premium Colors',
            description: 'Personalize every screen and button',
          ),
          _FeatureBenefit(
            icon: Icons.auto_awesome,
            title: 'Exclusive Styles',
            description: 'Unique accent combinations',
          ),
        ];
      case PremiumFeature.customRingtones:
        return [
          _FeatureBenefit(
            icon: Icons.library_music,
            title: '7,000+ Ringtones',
            description: 'Classic melodies, TV themes, games & more',
          ),
          _FeatureBenefit(
            icon: Icons.search,
            title: 'Searchable Library',
            description: 'Find any tune instantly',
          ),
        ];
      case PremiumFeature.homeWidgets:
        return [
          _FeatureBenefit(
            icon: Icons.dashboard_customize,
            title: 'Custom Dashboards',
            description: 'Build your own widget layouts',
          ),
          _FeatureBenefit(
            icon: Icons.show_chart,
            title: 'Live Charts & Gauges',
            description: 'Visualize telemetry in real-time',
          ),
          _FeatureBenefit(
            icon: Icons.battery_charging_full,
            title: 'Battery & Sensors',
            description: 'Monitor everything at a glance',
          ),
        ];
    }
  }

  /// Get the value proposition headline
  String get _headline {
    switch (widget.feature) {
      case PremiumFeature.automations:
        return 'Automate Your Mesh';
      case PremiumFeature.iftttIntegration:
        return 'Connect Everything';
      case PremiumFeature.premiumThemes:
        return 'Make It Yours';
      case PremiumFeature.customRingtones:
        return 'Sound Library';
      case PremiumFeature.homeWidgets:
        return 'Your Dashboard';
    }
  }

  /// Get contextual subtitle
  String get _subtitle {
    if (widget.featureDescription != null) {
      return widget.featureDescription!;
    }

    switch (widget.feature) {
      case PremiumFeature.automations:
        return 'Save this automation and unlock the full power of automatic alerts, messages, and smart triggers.';
      case PremiumFeature.iftttIntegration:
        return 'Connect your mesh network to hundreds of apps and services.';
      case PremiumFeature.premiumThemes:
        return 'Express yourself with 12 stunning accent colors.';
      case PremiumFeature.customRingtones:
        return 'Access a massive library of notification sounds.';
      case PremiumFeature.homeWidgets:
        return 'Build custom dashboards with live data visualizations.';
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
          // Close sheet and return success
          Navigator.of(context).pop(true);

        case PurchaseResult.canceled:
          // User canceled, do nothing
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
        // Check if this specific feature was restored
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
    final purchase = _purchase;
    final storeProductsAsync = ref.watch(storeProductsProvider);

    // Get actual price from store
    final storePrice = storeProductsAsync.when(
      data: (products) => products[purchase?.productId]?.priceString,
      loading: () => null,
      error: (error, stack) => null,
    );

    final displayPrice =
        storePrice ?? '\$${purchase?.price.toStringAsFixed(2) ?? "3.99"}';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
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
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        colors: [Colors.amber.shade400, Colors.orange.shade600],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
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

                // Subtitle
                Text(
                  _subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

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
                            color: context.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            benefit.icon,
                            color: context.accentColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
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

                const SizedBox(height: 8),

                // "Your automation is safe" message
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your configuration is saved. After purchase, just tap save again.',
                          style: TextStyle(
                            color: AppTheme.successGreen,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Purchase button
                BouncyTap(
                  onTap: _isLoading ? null : _handlePurchase,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade400, Colors.orange.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withValues(alpha: 0.3),
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

                const SizedBox(height: 12),

                // One-time purchase note
                Text(
                  'One-time purchase • Yours forever',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),

                const SizedBox(height: 16),

                // Restore purchases
                TextButton(
                  onPressed: _isLoading ? null : _handleRestore,
                  child: Text(
                    'Restore Purchases',
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
