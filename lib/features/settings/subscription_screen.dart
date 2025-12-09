import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme.dart';
import '../../core/widgets/legal_document_sheet.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/subscription/subscription_service.dart';
import '../../utils/snackbar.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(subscriptionLoadingProvider);
    final error = ref.watch(subscriptionErrorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Upgrades')),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),

            // One-time purchases
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

            // Restore purchases
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: isLoading ? null : _restorePurchases,
                child: const Text('Restore Purchases'),
              ),
            ),

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
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text('•', style: TextStyle(color: AppTheme.textTertiary)),
                  TextButton(
                    onPressed: () => LegalDocumentSheet.showPrivacy(context),
                    child: Text(
                      'Privacy',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
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
          const SizedBox(width: 16),
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
                const Text(
                  'One-time purchases, yours forever',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOneTimePurchases() {
    final purchaseState = ref.watch(purchaseStateProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...OneTimePurchases.allPurchases.map((purchase) {
          final isPurchased = purchaseState.hasPurchased(purchase.productId);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: AppTheme.darkCard,
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
                          : AppTheme.darkBorder,
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
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  purchase.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                if (isPurchased) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.check_circle,
                                    color: context.accentColor,
                                    size: 18,
                                  ),
                                ],
                              ],
                            ),
                            Text(
                              purchase.description,
                              style: const TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            'Owned',
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
        backgroundColor: AppTheme.darkCard,
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
              const SizedBox(height: 16),
              Text(
                '🎉 All Features Unlocked!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: context.accentColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'You now have access to everything SocialMesh has to offer. Thank you for your support!',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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

  Future<void> _restorePurchases() async {
    ref.haptics.buttonTap();
    final success = await restorePurchases(ref);
    if (mounted) {
      if (success) {
        ref.haptics.success();
        showSuccessSnackBar(context, 'Purchases restored successfully');
      } else {
        showInfoSnackBar(context, 'No purchases to restore');
      }
    }
  }
}
