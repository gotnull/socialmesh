import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isYearly = true;
  Package? _selectedPackage;

  @override
  Widget build(BuildContext context) {
    final currentTier = ref.watch(currentTierProvider);
    final currentState = ref.watch(subscriptionStateProvider);
    final isLoading = ref.watch(subscriptionLoadingProvider);
    final error = ref.watch(subscriptionErrorProvider);
    final offeringsAsync = ref.watch(offeringsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current status card
            _buildCurrentStatusCard(currentTier, currentState),
            const SizedBox(height: 24),

            // Billing toggle
            if (currentTier == SubscriptionTier.free) _buildBillingToggle(),

            if (currentTier == SubscriptionTier.free)
              const SizedBox(height: 24),

            // Plan cards from RevenueCat offerings
            if (currentTier != SubscriptionTier.pro)
              offeringsAsync.when(
                data: (offerings) =>
                    _buildOfferingCards(offerings, currentTier),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Failed to load plans: $e'),
              ),

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

            // Subscribe button
            if (_selectedPackage != null &&
                currentTier == SubscriptionTier.free) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: isLoading ? null : _subscribe,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_getSubscribeButtonText()),
              ),
            ],

            // One-time purchases
            const SizedBox(height: 32),
            _buildOneTimePurchases(),

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
                    onPressed: () => _openUrl('https://yourapp.com/terms'),
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
                    onPressed: () => _openUrl('https://yourapp.com/privacy'),
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

  Widget _buildCurrentStatusCard(
    SubscriptionTier tier,
    SubscriptionState state,
  ) {
    final plan = SubscriptionPlans.getPlan(tier);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (tier) {
      case SubscriptionTier.free:
        statusColor = AppTheme.textTertiary;
        statusText = 'Free Plan';
        statusIcon = Icons.person_outline;
      case SubscriptionTier.premium:
        statusColor = context.accentColor;
        statusText = 'Premium';
        statusIcon = Icons.star;
      case SubscriptionTier.pro:
        statusColor = AppTheme.accentOrange;
        statusText = 'Pro';
        statusIcon = Icons.workspace_premium;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withValues(alpha: 0.3),
            statusColor.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    Text(
                      plan.description,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.isTrialing) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.warningYellow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: AppTheme.warningYellow,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${state.trialDaysRemaining} days left in trial',
                    style: const TextStyle(
                      color: AppTheme.warningYellow,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (state.expiresAt != null && !state.isTrialing) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  state.willRenew ? Icons.autorenew : Icons.event_busy,
                  color: AppTheme.textTertiary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  state.willRenew
                      ? 'Renews ${_formatDate(state.expiresAt!)}'
                      : 'Expires ${_formatDate(state.expiresAt!)}',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillingToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isYearly = false;
                _selectedPackage = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isYearly ? AppTheme.darkCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Monthly',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: !_isYearly
                            ? AppTheme.textPrimary
                            : AppTheme.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _isYearly = true;
                _selectedPackage = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isYearly ? AppTheme.darkCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Yearly',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _isYearly
                                ? AppTheme.textPrimary
                                : AppTheme.textTertiary,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: context.accentColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Save 50%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferingCards(
    Offerings? offerings,
    SubscriptionTier currentTier,
  ) {
    if (offerings == null || offerings.current == null) {
      return const Text(
        'No subscription plans available',
        style: TextStyle(color: AppTheme.textTertiary),
      );
    }

    final offering = offerings.current!;
    final packages = _isYearly
        ? offering.availablePackages
              .where((p) => p.packageType == PackageType.annual)
              .toList()
        : offering.availablePackages
              .where((p) => p.packageType == PackageType.monthly)
              .toList();

    if (packages.isEmpty) {
      return Text(
        'No plans available for this billing period',
        style: TextStyle(color: AppTheme.textTertiary),
      );
    }

    return Column(
      children: packages.map((package) {
        final isSelected = _selectedPackage?.identifier == package.identifier;
        final product = package.storeProduct;
        final isPro = package.identifier.toLowerCase().contains('pro');

        Color planColor = isPro ? AppTheme.accentOrange : context.accentColor;
        String planName = isPro ? 'Pro' : 'Premium';
        String planDescription = isPro
            ? 'Full power for teams & professionals'
            : 'Enhanced features for enthusiasts';

        // Get features from local model
        final plan = isPro ? SubscriptionPlans.pro : SubscriptionPlans.premium;

        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = package),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? planColor : AppTheme.darkBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? planColor
                                  : AppTheme.darkBorder,
                              width: 2,
                            ),
                            color: isSelected ? planColor : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          planName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: planColor,
                          ),
                        ),
                      ],
                    ),
                    if (isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: planColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'BEST VALUE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: planColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  planDescription,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      product.priceString,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _isYearly ? '/year' : '/month',
                        style: TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_isYearly) ...[
                      const Spacer(),
                      Text(
                        'Save 50%',
                        style: TextStyle(
                          color: context.accentColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.darkBorder),
                const SizedBox(height: 16),
                // Feature list
                ...plan.features.take(5).map((feature) {
                  final info = FeatureInfo.getInfo(feature);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: planColor, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            info?.name ?? feature.name,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (plan.features.length > 5)
                  Text(
                    '+ ${plan.features.length - 5} more features',
                    style: TextStyle(
                      color: planColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOneTimePurchases() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'One-time Purchases',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Unlock specific features without a subscription',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ...OneTimePurchases.allPurchases.map((purchase) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryPink.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getPurchaseIcon(purchase.id),
                    color: AppTheme.secondaryPink,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        purchase.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
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
                OutlinedButton(
                  onPressed: () => _purchaseItem(purchase),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  child: Text('\$${purchase.price.toStringAsFixed(2)}'),
                ),
              ],
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
      default:
        return Icons.shopping_bag;
    }
  }

  String _getSubscribeButtonText() {
    if (_selectedPackage == null) return 'Select a plan';
    return 'Subscribe - ${_selectedPackage!.storeProduct.priceString}${_isYearly ? '/year' : '/month'}';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  Future<void> _subscribe() async {
    if (_selectedPackage == null) return;

    final success = await purchasePackage(ref, _selectedPackage!);
    if (mounted && success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Subscription activated!')));
    }
  }

  Future<void> _purchaseItem(OneTimePurchase purchase) async {
    final success = await purchaseProduct(ref, purchase.productId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? '${purchase.name} unlocked!' : 'Purchase failed',
          ),
        ),
      );
    }
  }

  Future<void> _restorePurchases() async {
    final success = await restorePurchases(ref);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Purchases restored successfully'
                : 'No purchases to restore',
          ),
        ),
      );
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
