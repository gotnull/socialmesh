// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../config/revenuecat_config.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../providers/connectivity_providers.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/animated_gold_button.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/widgets/verified_badge.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../services/audio/rtttl_library_service.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';
import '../automations/automations_screen.dart';
import '../dashboard/widget_dashboard_screen.dart';
import '../external_purchase/alternative_payment_link.dart';
import '../external_purchase/payment_method_chooser_sheet.dart';
import '../external_purchase/redeem_unlock_code_sheet.dart';
import 'ifttt_config_screen.dart';
import 'ringtone_screen.dart';
import 'theme_settings_screen.dart';
import 'translation_settings_screen.dart';
import 'widgets/restore_purchases_button.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with LifecycleSafeMixin<SubscriptionScreen> {
  int _ringtoneCount = 0;
  final _rtttlLibraryService = RtttlLibraryService();

  @override
  void initState() {
    super.initState();
    _loadRingtoneCount();
  }

  Future<void> _loadRingtoneCount() async {
    final count = await _rtttlLibraryService.getToneCount();
    if (!mounted) return;
    safeSetState(() => _ringtoneCount = count);
  }

  String get _ringtoneCountFormatted {
    if (_ringtoneCount == 0) return '7,000+';
    if (_ringtoneCount >= 1000) {
      return '${(_ringtoneCount / 1000).toStringAsFixed(1)}k+'.replaceAll(
        '.0',
        '',
      );
    }
    return '$_ringtoneCount+';
  }

  @override
  Widget build(BuildContext context) {
    final error = ref.watch(subscriptionErrorProvider);
    final purchaseState = ref.watch(purchaseStateProvider);

    // Check if all features are unlocked
    final ownedCount = OneTimePurchases.completePackPurchases
        .where((p) => purchaseState.hasPurchased(p.productId))
        .length;
    final allUnlocked =
        ownedCount == OneTimePurchases.completePackPurchases.length ||
        purchaseState.hasPurchased(RevenueCatConfig.completePackProductId);

    return GlassScaffold(
      title: context.l10n.subscriptionPremiumTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Header - only show if not all unlocked
              if (!allUnlocked) ...[
                _buildHeader(),
                SizedBox(height: AppTheme.spacing24),
              ],

              // Featured Translation Pack (standalone add-on)
              if (AppFeatureFlags.isTranslationEnabled) ...[
                _buildFeaturedTranslationCard(),
                const SizedBox(height: AppTheme.spacing16),
              ],

              // Complete Pack Bundle (hero card with grouped benefits)
              _buildBundleCard(),

              // Error message
              if (error != null) ...[
                const SizedBox(height: AppTheme.spacing16),
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                  ),
                  child: Text(
                    error,
                    style: const TextStyle(color: AppTheme.errorRed),
                  ),
                ),
              ],

              // Restore Purchases button
              const RestorePurchasesButton(),

              // Show individual packs section
              if (!allUnlocked) ...[
                const SizedBox(height: AppTheme.spacing24),
                // Divider with "or buy individually"
                Row(
                  children: [
                    Expanded(child: Divider(color: context.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        context.l10n.subscriptionOrBuyIndividually,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: context.border)),
                  ],
                ),
                SizedBox(height: AppTheme.spacing24),
              ] else ...[
                const SizedBox(height: AppTheme.spacing24),
                // Divider with "Included Features"
                Row(
                  children: [
                    Expanded(child: Divider(color: context.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        context.l10n.subscriptionIncludedFeatures,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: context.border)),
                  ],
                ),
                SizedBox(height: AppTheme.spacing24),
              ],
              // One-time purchases (shows OWNED or price depending on state)
              _buildOneTimePurchases(),

              // Restore Purchases button (bottom)
              const RestorePurchasesButton(),

              // Support fallback: redeem unlock code. Low-emphasis text
              // link — primary CTAs above remain the canonical path.
              // Stays visible whenever any external provider (Stripe
              // or BMC) is on, since codes route through the shared
              // entitlement merge regardless of which provider issued
              // the original checkout.
              if (AppFeatureFlags.isExternalPurchaseEnabled)
                Center(
                  child: TextButton(
                    onPressed: () => showRedeemUnlockCodeSheet(context),
                    child: Text(
                      context.l10n.unlockCodeFallback,
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),

              // Terms & Privacy
              const SizedBox(height: AppTheme.spacing16),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => LegalDocumentSheet.showTerms(context),
                      child: Text(
                        context.l10n.subscriptionTerms,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '•',
                      style: TextStyle(color: context.textTertiary),
                    ), // lint-allow: hardcoded-string
                    TextButton(
                      onPressed: () => LegalDocumentSheet.showPrivacy(context),
                      child: Text(
                        context.l10n.subscriptionPrivacy,
                        style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.accentColor.withValues(alpha: 0.3),
            context.accentColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              color: context.accentColor,
              size: 28,
            ),
          ),
          SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.subscriptionUnlockFeatures,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.accentColor,
                  ),
                ),
                Text(
                  context.l10n.subscriptionOneTimePurchases,
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedTranslationCard() {
    final purchaseState = ref.watch(purchaseStateProvider);
    final isLoading = ref.watch(subscriptionLoadingProvider);
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );

    final translationPack = OneTimePurchases.translationPack;
    final isPurchased = purchaseState.hasPurchased(translationPack.productId);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AccentColors.teal.withValues(alpha: 0.25),
            AccentColors.teal.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: AccentColors.teal.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AccentColors.teal.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              AppTheme.spacing20,
              AppTheme.spacing20,
              AppTheme.spacing16,
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AccentColors.teal,
                    borderRadius: BorderRadius.circular(AppTheme.radius14),
                  ),
                  child: const Icon(
                    Icons.translate,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              storeProducts[translationPack.productId]?.title ??
                                  context
                                      .l10n
                                      .subscriptionFallbackTranslationPack,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          if (!isPurchased)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AccentColors.teal,
                                    AccentColors.cyan,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius6,
                                ),
                              ),
                              child: Text(
                                context.l10n.subscriptionNewAddon,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        context.l10n.subscriptionFeaturedTranslationSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Price and CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              0,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            child: Row(
              children: [
                if (isPurchased) ...[
                  Icon(Icons.check_circle, color: AccentColors.teal, size: 22),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    context.l10n.subscriptionOwned,
                    style: TextStyle(
                      color: AccentColors.teal,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ] else ...[
                  Text(
                    storeProducts[translationPack.productId]?.priceString ??
                        '\$${translationPack.price.toStringAsFixed(2)}', // lint-allow: hardcoded-string
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 44,
                    child: FilledButton(
                      onPressed: isLoading
                          ? null
                          : () => _purchaseItem(translationPack),
                      style: FilledButton.styleFrom(
                        backgroundColor: AccentColors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radius12,
                          ),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              context.l10n.subscriptionGetTranslation,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBundleCard() {
    final purchaseState = ref.watch(purchaseStateProvider);
    final isLoading = ref.watch(subscriptionLoadingProvider);
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );

    // Check if user already owns all individual packs
    final ownedCount = OneTimePurchases.completePackPurchases
        .where((p) => purchaseState.hasPurchased(p.productId))
        .length;
    final ownsAll = ownedCount == OneTimePurchases.completePackPurchases.length;
    final ownsBundle = purchaseState.hasPurchased(
      RevenueCatConfig.completePackProductId,
    );

    if (ownsAll || ownsBundle) {
      // User already has everything - show owned state
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.accentColor.withValues(alpha: 0.2),
              context.accentColor.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(color: context.accentColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radius14),
              ),
              child: Icon(Icons.verified, color: context.accentColor, size: 32),
            ),
            SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.subscriptionAllUnlocked,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.accentColor,
                    ),
                  ),
                  Text(
                    context.l10n.subscriptionThankYou,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Calculate actual discount from store prices (localized)
    final bundlePrice =
        storeProducts[RevenueCatConfig.completePackProductId]?.price;
    final individualTotal = [
      RevenueCatConfig.themePackProductId,
      RevenueCatConfig.ringtonePackProductId,
      RevenueCatConfig.widgetPackProductId,
      RevenueCatConfig.automationsPackProductId,
      RevenueCatConfig.iftttPackProductId,
      RevenueCatConfig.translationPackProductId,
    ].fold<double>(0, (sum, id) => sum + (storeProducts[id]?.price ?? 0));

    // Use actual store prices if available, otherwise fall back to model
    final discountPercent = (bundlePrice != null && individualTotal > 0)
        ? ((1 - bundlePrice / individualTotal) * 100).round()
        : OneTimePurchases.bundleDiscountPercent;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.accentColor.withValues(alpha: 0.3),
            AppTheme.primaryPurple.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: context.accentColor.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.accentColor.withValues(alpha: 0.3),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppTheme.primaryPurple.withValues(alpha: 0.15),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with MOST POPULAR + SAVE badges
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              AppTheme.spacing20,
              AppTheme.spacing20,
              AppTheme.spacing16,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.accentColor, AppTheme.primaryPurple],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radius14),
                      ),
                      child: Icon(
                        Icons.all_inclusive,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const Positioned(
                      top: -14,
                      right: -14,
                      child: SimpleVerifiedBadge(size: 24),
                    ),
                  ],
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              context.l10n.subscriptionCompletePack,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      // Badges row
                      Wrap(
                        spacing: AppTheme.spacing6,
                        runSpacing: AppTheme.spacing4,
                        children: [
                          _buildBadge(
                            context.l10n.subscriptionPopularBadge,
                            context.accentColor,
                            Colors.white,
                          ),
                          _buildBadge(
                            context.l10n.subscriptionSavePercent(
                              discountPercent.toString(),
                            ),
                            AppTheme.warningYellow,
                            Colors.black,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        context.l10n.subscriptionCompletePackSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Grouped feature list
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing10,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppTheme.radius12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personalisation group
                _buildGroupHeader(
                  context.l10n.subscriptionGroupPersonalisation,
                ),
                _buildBundleFeature(
                  Icons.palette,
                  storeProducts[RevenueCatConfig.themePackProductId]?.title ??
                      context.l10n.subscriptionFallbackThemePack,
                  context.l10n.subscriptionAccentColors,
                ),
                _buildBundleFeature(
                  Icons.music_note,
                  storeProducts[RevenueCatConfig.ringtonePackProductId]
                          ?.title ??
                      context.l10n.subscriptionFallbackRingtonePack,
                  context.l10n.subscriptionTones(_ringtoneCountFormatted),
                ),
                const SizedBox(height: AppTheme.spacing6),
                // Automation group
                _buildGroupHeader(context.l10n.subscriptionGroupAutomation),
                _buildBundleFeature(
                  Icons.auto_awesome,
                  storeProducts[RevenueCatConfig.automationsPackProductId]
                          ?.title ??
                      context.l10n.subscriptionFallbackAutomations,
                  context.l10n.subscriptionTriggersSchedules,
                ),
                _buildBundleFeature(
                  Icons.webhook,
                  storeProducts[RevenueCatConfig.iftttPackProductId]?.title ??
                      context.l10n.subscriptionFallbackIfttt,
                  context.l10n.subscriptionAppIntegrations,
                ),
                const SizedBox(height: AppTheme.spacing6),
                // Dashboard group
                _buildGroupHeader(context.l10n.subscriptionGroupDashboard),
                _buildBundleFeature(
                  Icons.widgets,
                  storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
                      context.l10n.subscriptionFallbackWidgetPack,
                  context.l10n.subscriptionUnlimitedWidgets,
                ),
                // Communication group (if translation enabled)
                if (AppFeatureFlags.isTranslationEnabled) ...[
                  const SizedBox(height: AppTheme.spacing6),
                  _buildGroupHeader(
                    context.l10n.subscriptionGroupCommunication,
                  ),
                  _buildBundleFeature(
                    Icons.translate,
                    storeProducts[RevenueCatConfig.translationPackProductId]
                            ?.title ??
                        context.l10n.subscriptionFallbackTranslationPack,
                    context.l10n.subscriptionTranslationWithAllowance,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing16),

          // Price display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing20),
            child: Center(
              child: Column(
                children: [
                  Text(
                    storeProducts[RevenueCatConfig.completePackProductId]
                            ?.priceString ??
                        '\$${OneTimePurchases.bundlePrice.toStringAsFixed(2)}', // lint-allow: hardcoded-string
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    context.l10n.subscriptionBestValue,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.warningYellow,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing12),

          // Full-width CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: SizedBox(
              width: double.infinity,
              child: AnimatedGoldButton(
                text: context.l10n.subscriptionGetAll,
                isLoading: isLoading,
                onTap: _purchaseBundle,
              ),
            ),
          ),

          // Alternative payment (secondary). Hidden once the bundle is
          // owned — no fallback path is meaningful at that point.
          if (!purchaseState.hasPurchased(
            RevenueCatConfig.completePackProductId,
          ))
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              child: Center(
                child: AlternativePaymentLink(
                  productId: RevenueCatConfig.completePackProductId,
                ),
              ),
            ),

          // Lifetime reinforcement
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            child: Center(
              child: Text(
                context.l10n.subscriptionLifetimeReinforcement,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing2, bottom: 2),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: context.accentColor.withValues(alpha: 0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildBundleFeature(IconData icon, String name, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Text(
              detail,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  // Connectivity gate for new purchases. The first read of
  // isOnlineProvider can return a stale "offline" value in two cases
  // observed on iOS:
  //   1. Cold boot: the provider initialises with platformConnected=false
  //      and only flips to true after the first ~2s reachability ping.
  //   2. After the Stripe Payment Sheet dismisses, iOS occasionally
  //      fires a transient `none` event on connectivity_plus's
  //      onConnectivityChanged stream, flipping the cached state to
  //      offline until the next periodic check (~10s later).
  //
  // Both produce false-negative "Purchase blocked — offline" snackbars
  // when the network is actually live. Force a fresh checkNow() before
  // surfacing the offline error: if the platform genuinely is down the
  // re-check stays false and we still block; if it was stale we
  // recover transparently.
  Future<bool> _ensureOnlineForPurchase(String productId) async {
    if (ref.read(isOnlineProvider)) return true;
    AppLogging.subscriptions(
      '[SubscriptionScreen] isOnline=false on first read for $productId '
      '— forcing connectivity refresh before blocking',
    );
    await ref.read(connectivityStatusProvider.notifier).checkNow();
    if (!mounted) return false;
    if (ref.read(isOnlineProvider)) {
      AppLogging.subscriptions(
        '[SubscriptionScreen] connectivity refresh corrected stale offline '
        'for $productId — proceeding',
      );
      return true;
    }
    AppLogging.subscriptions(
      '[SubscriptionScreen] Purchase blocked — offline confirmed after refresh '
      '($productId)',
    );
    if (!mounted) return false;
    showErrorSnackBar(context, context.l10n.premiumPurchaseRequiresInternet);
    return false;
  }

  Future<void> _purchaseBundle() async {
    // Capture haptics before any await
    final haptics = ref.haptics;
    haptics.buttonTap();

    final bundleId = RevenueCatConfig.completePackProductId;
    if (!await _ensureOnlineForPurchase(bundleId)) return;
    if (!mounted) return;

    // Chunk C: route the bundle CTA through the chooser sheet, exactly
    // like every individual pack. The chooser handles already-owned
    // gracefully:
    //   - App Store path: RevenueCat's _handleAlreadyOwned returns
    //     success without charging, then onSuccess fires the unlock
    //     celebration.
    //   - Stripe path: legitimate fresh purchase (cross-platform
    //     unlock when the user can't or won't transact via the store).
    // The pre-chooser restorePurchases short-circuit that used to live
    // here was inconsistent with individual packs and hid the chooser
    // from any user whose StoreKit history already contained the
    // bundle - including the test sandbox.
    await showPaymentMethodChooserSheet(
      context: context,
      ref: ref,
      productId: bundleId,
      productName: 'Complete Pack',
      priceAud: 14.99,
      onSuccess: _showAllUnlockedCelebration,
    );
  }

  Widget _buildOneTimePurchases() {
    final purchaseState = ref.watch(purchaseStateProvider);
    final storeProductsAsync = ref.watch(storeProductsProvider);
    final storeProducts = storeProductsAsync.when(
      data: (data) => data,
      loading: () => <String, StoreProductInfo>{},
      error: (e, s) => <String, StoreProductInfo>{},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...OneTimePurchases.allPurchases
            .where((p) => p.id != 'translation_pack')
            .map((purchase) {
              final isPurchased = purchaseState.hasPurchased(
                purchase.productId,
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      child: InkWell(
                        onTap: isPurchased
                            ? null
                            : () => _purchaseItem(purchase),
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                        child: Container(
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                            border: Border.all(
                              color: isPurchased
                                  ? context.accentColor.withValues(alpha: 0.5)
                                  : context.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: context.accentColor.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radius10,
                                  ),
                                ),
                                child: Icon(
                                  _getPurchaseIcon(purchase.id),
                                  color: context.accentColor,
                                  size: 22,
                                ),
                              ),
                              SizedBox(width: AppTheme.spacing16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            storeProducts[purchase.productId]
                                                    ?.title ??
                                                purchase.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 16,
                                              color: context.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isPurchased) ...[
                                          SizedBox(width: AppTheme.spacing8),
                                          Icon(
                                            Icons.check_circle,
                                            color: context.accentColor,
                                            size: 18,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      _getDescription(purchase),
                                      style: TextStyle(
                                        color: context.textTertiary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: AppTheme.spacing12),
                              if (isPurchased)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.accentColor.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius8,
                                    ),
                                  ),
                                  child: Text(
                                    context.l10n.subscriptionOwned,
                                    style: TextStyle(
                                      color: context.accentColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radius8,
                                    ),
                                    border: Border.all(
                                      color: context.accentColor,
                                    ),
                                  ),
                                  child: Text(
                                    storeProducts[purchase.productId]
                                            ?.priceString ??
                                        '\$${purchase.price.toStringAsFixed(2)}', // lint-allow: hardcoded-string
                                    style: TextStyle(
                                      color: context.accentColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (!isPurchased)
                      AlternativePaymentLink(productId: purchase.productId),
                  ],
                ),
              );
            }),
      ],
    );
  }

  String _getDescription(OneTimePurchase purchase) {
    // Dynamic description for ringtone pack with actual count
    if (purchase.id == 'ringtone_pack') {
      return context.l10n.subscriptionSearchableTones(_ringtoneCountFormatted);
    }
    return purchase.description;
  }

  IconData _getPurchaseIcon(String purchaseId) {
    switch (purchaseId) {
      case 'theme_pack':
        return Icons.palette;
      case 'ringtone_pack':
        return Icons.music_note;
      case 'widget_pack':
        return Icons.widgets;
      case 'automations_pack':
        return Icons.auto_awesome;
      case 'ifttt_pack':
        return Icons.webhook;
      case 'translation_pack':
        return Icons.translate;
      default:
        return Icons.shopping_bag;
    }
  }

  Future<void> _purchaseItem(OneTimePurchase purchase) async {
    // Capture haptics before any await
    final haptics = ref.haptics;
    haptics.buttonTap();

    if (!await _ensureOnlineForPurchase(purchase.productId)) return;
    if (!mounted) return;

    // Chunk C: route every pack CTA through the chooser sheet. When
    // Stripe is disabled, the chooser short-circuits straight to the
    // store IAP path, preserving pre-Chunk-C behavior.
    await showPaymentMethodChooserSheet(
      context: context,
      ref: ref,
      productId: purchase.productId,
      productName: purchase.name,
      priceAud: purchase.price,
      onSuccess: () {
        // Check if all features are now unlocked.
        final purchaseState = ref.read(purchaseStateProvider);
        final allPurchases = OneTimePurchases.allPurchases;
        final ownedCount = allPurchases
            .where((p) => purchaseState.hasPurchased(p.productId))
            .length;

        if (ownedCount == allPurchases.length) {
          _showAllUnlockedCelebration();
        } else {
          _showUnlockedSnackBar(purchase);
        }
      },
    );
  }

  void _showUnlockedSnackBar(OneTimePurchase purchase) {
    final navigator = Navigator.of(context);
    final Widget targetScreen = switch (purchase.unlocksFeature) {
      PremiumFeature.homeWidgets => const WidgetDashboardScreen(
        autoOpenPicker: true,
      ),
      PremiumFeature.automations => const AutomationsScreen(),
      PremiumFeature.premiumThemes => const ThemeSettingsScreen(),
      PremiumFeature.customRingtones => const RingtoneScreen(),
      PremiumFeature.iftttIntegration => const IftttConfigScreen(),
      PremiumFeature.translation => const TranslationSettingsScreen(),
    };

    showActionSnackBar(
      context,
      context.l10n.premiumPurchaseUnlocked(purchase.name),
      actionLabel: context.l10n.subscriptionView,
      onAction: () {
        navigator.push(MaterialPageRoute(builder: (_) => targetScreen));
      },
      type: SnackBarType.success,
    );
  }

  void _showAllUnlockedCelebration() {
    AppBottomSheet.show(
      context: context,
      isDismissible: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Lottie animation
          SizedBox(
            width: 200,
            height: 200,
            child: Lottie.asset(
              'assets/lottie/unlocked.json',
              repeat: true,
              fit: BoxFit.contain,
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
          Text(
            context.l10n.subscriptionAllUnlockedCelebration,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: context.accentColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.subscriptionCelebrationMessage,
            style: TextStyle(
              fontSize: 15,
              color: context.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spacing24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => safeNavigatorPop(),
              style: FilledButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              child: Text(
                context.l10n.subscriptionAwesome,
                style: context.titleSmallStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
