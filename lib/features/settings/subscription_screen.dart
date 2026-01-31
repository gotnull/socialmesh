// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../config/revenuecat_config.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/animated_gold_button.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../core/widgets/verified_badge.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../services/audio/rtttl_library_service.dart';
import '../../services/haptic_service.dart';
import '../../services/subscription/subscription_service.dart';
import '../../utils/snackbar.dart';
import 'widgets/restore_purchases_button.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  int _ringtoneCount = 0;
  final _rtttlLibraryService = RtttlLibraryService();

  @override
  void initState() {
    super.initState();
    _loadRingtoneCount();
  }

  Future<void> _loadRingtoneCount() async {
    final count = await _rtttlLibraryService.getToneCount();
    if (mounted) {
      setState(() => _ringtoneCount = count);
    }
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
    final ownedCount = OneTimePurchases.allIndividualPurchases
        .where((p) => purchaseState.hasPurchased(p.productId))
        .length;
    final allUnlocked =
        ownedCount == OneTimePurchases.allIndividualPurchases.length ||
        purchaseState.hasPurchased(RevenueCatConfig.completePackProductId);

    return GlassScaffold.body(
      title: 'Premium',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header - only show if not all unlocked
            if (!allUnlocked) ...[_buildHeader(), SizedBox(height: 24)],

            // Complete Pack Bundle (prominent)
            _buildBundleCard(),

            // Restore Purchases button
            const RestorePurchasesButton(),

            // Show individual packs section
            if (!allUnlocked) ...[
              const SizedBox(height: 24),
              // Divider with "or buy individually"
              Row(
                children: [
                  Expanded(child: Divider(color: context.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or buy individually',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: context.border)),
                ],
              ),
              SizedBox(height: 24),
            ] else ...[
              const SizedBox(height: 24),
              // Divider with "Included Features"
              Row(
                children: [
                  Expanded(child: Divider(color: context.border)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Included Features',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: context.border)),
                ],
              ),
              SizedBox(height: 24),
            ],
            // One-time purchases (shows OWNED or price depending on state)
            _buildOneTimePurchases(),

            // Error message
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error,
                  style: const TextStyle(color: AppTheme.errorRed),
                ),
              ),
            ],

            // Restore Purchases button
            const RestorePurchasesButton(),

            // Terms & Privacy
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => LegalDocumentSheet.showTerms(context),
                    child: Text(
                      'Terms',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text('•', style: TextStyle(color: context.textTertiary)),
                  TextButton(
                    onPressed: () => LegalDocumentSheet.showPrivacy(context),
                    child: Text(
                      'Privacy',
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.accentColor.withValues(alpha: 0.3),
            context.accentColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              color: context.accentColor,
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unlock Features',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.accentColor,
                  ),
                ),
                Text(
                  'One-time purchases, yours forever',
                  style: TextStyle(color: context.textSecondary, fontSize: 14),
                ),
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
    final ownedCount = OneTimePurchases.allIndividualPurchases
        .where((p) => purchaseState.hasPurchased(p.productId))
        .length;
    final ownsAll =
        ownedCount == OneTimePurchases.allIndividualPurchases.length;
    final ownsBundle = purchaseState.hasPurchased(
      RevenueCatConfig.completePackProductId,
    );

    if (ownsAll || ownsBundle) {
      // User already has everything - show owned state
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.accentColor.withValues(alpha: 0.2),
              context.accentColor.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.accentColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.verified, color: context.accentColor, size: 32),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Features Unlocked',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.accentColor,
                    ),
                  ),
                  Text(
                    'Thank you for your support!',
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
            context.accentColor.withValues(alpha: 0.25),
            AppTheme.primaryPurple.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: context.accentColor.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with badge
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                        borderRadius: BorderRadius.circular(14),
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Complete Pack',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warningYellow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SAVE $discountPercent%',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Everything. Forever. One price.',
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

          // Feature list
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildBundleFeature(
                  Icons.music_note,
                  storeProducts[RevenueCatConfig.ringtonePackProductId]
                          ?.title ??
                      'Ringtone Pack',
                  '$_ringtoneCountFormatted tones',
                ),
                _buildBundleFeature(
                  Icons.palette,
                  storeProducts[RevenueCatConfig.themePackProductId]?.title ??
                      'Theme Pack',
                  '12 accent colors',
                ),
                _buildBundleFeature(
                  Icons.widgets,
                  storeProducts[RevenueCatConfig.widgetPackProductId]?.title ??
                      'Widget Pack',
                  'Unlimited custom widgets',
                ),
                _buildBundleFeature(
                  Icons.auto_awesome,
                  storeProducts[RevenueCatConfig.automationsPackProductId]
                          ?.title ??
                      'Automations',
                  'Triggers & schedules',
                ),
                _buildBundleFeature(
                  Icons.webhook,
                  storeProducts[RevenueCatConfig.iftttPackProductId]?.title ??
                      'IFTTT',
                  '700+ app integrations',
                ),
              ],
            ),
          ),

          // Price and CTA
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeProducts[RevenueCatConfig.completePackProductId]
                                ?.priceString ??
                            '\$${OneTimePurchases.bundlePrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Best value - all features',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.warningYellow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedGoldButton(
                  text: 'Get All',
                  isLoading: isLoading,
                  onTap: _purchaseBundle,
                ),
              ],
            ),
          ),
        ],
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
              const SizedBox(width: 10),
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
          const SizedBox(height: 2),
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

  Future<void> _purchaseBundle() async {
    ref.haptics.buttonTap();

    // If already owned, short-circuit and celebrate
    final purchaseState = ref.read(purchaseStateProvider);
    final bundleId = RevenueCatConfig.completePackProductId;
    if (purchaseState.hasPurchased(bundleId)) {
      ref.haptics.success();
      _showAllUnlockedCelebration();
      return;
    }

    // Try restoring first to detect cross-account ownership without prompting the store
    final restored = await restorePurchases(ref);
    if (restored) {
      final refreshedState = ref.read(purchaseStateProvider);
      if (refreshedState.hasPurchased(bundleId)) {
        ref.haptics.success();
        _showAllUnlockedCelebration();
        return;
      }
    }

    final result = await purchaseProduct(
      ref,
      RevenueCatConfig.completePackProductId,
    );
    if (mounted) {
      switch (result) {
        case PurchaseResult.success:
          ref.haptics.success();
          _showAllUnlockedCelebration();
        case PurchaseResult.canceled:
          break;
        case PurchaseResult.error:
          ref.haptics.error();
          showErrorSnackBar(context, 'Purchase failed. Please try again.');
      }
    }
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
        ...OneTimePurchases.allPurchases.map((purchase) {
          final isPurchased = purchaseState.hasPurchased(purchase.productId);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: context.card,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: isPurchased ? null : () => _purchaseItem(purchase),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                          color: context.accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getPurchaseIcon(purchase.id),
                          color: context.accentColor,
                          size: 22,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    storeProducts[purchase.productId]?.title ??
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
                                  SizedBox(width: 8),
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
                      SizedBox(width: 12),
                      if (isPurchased)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'OWNED',
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
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.accentColor),
                          ),
                          child: Text(
                            storeProducts[purchase.productId]?.priceString ??
                                '\$${purchase.price.toStringAsFixed(2)}',
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
          );
        }),
      ],
    );
  }

  String _getDescription(OneTimePurchase purchase) {
    // Dynamic description for ringtone pack with actual count
    if (purchase.id == 'ringtone_pack') {
      return '$_ringtoneCountFormatted searchable RTTTL tones';
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
      default:
        return Icons.shopping_bag;
    }
  }

  Future<void> _purchaseItem(OneTimePurchase purchase) async {
    ref.haptics.buttonTap();
    final result = await purchaseProduct(ref, purchase.productId);
    if (mounted) {
      switch (result) {
        case PurchaseResult.success:
          ref.haptics.success();
          // Check if all features are now unlocked
          final purchaseState = ref.read(purchaseStateProvider);
          final allPurchases = OneTimePurchases.allPurchases;
          final ownedCount = allPurchases
              .where((p) => purchaseState.hasPurchased(p.productId))
              .length;

          if (ownedCount == allPurchases.length) {
            // All features unlocked! Show celebration
            _showAllUnlockedCelebration();
          } else {
            showSuccessSnackBar(context, '${purchase.name} unlocked!');
          }
        case PurchaseResult.canceled:
          // User canceled - no message needed
          break;
        case PurchaseResult.error:
          ref.haptics.error();
          showErrorSnackBar(context, 'Purchase failed. Please try again.');
      }
    }
  }

  void _showAllUnlockedCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: context.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              SizedBox(height: 16),
              Text(
                'All Features Unlocked!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.accentColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'You now have access to everything Socialmesh has to offer. Thank you for your support!',
                style: TextStyle(
                  fontSize: 15,
                  color: context.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
