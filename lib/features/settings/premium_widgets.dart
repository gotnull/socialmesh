import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import 'subscription_screen.dart';

/// A widget that gates content behind a premium feature check.
/// Shows a purchase prompt when the user doesn't have access.
class PremiumFeatureGate extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget child;
  final Widget? lockedChild;
  final bool showUpgradeButton;

  const PremiumFeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.lockedChild,
    this.showUpgradeButton = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFeature = ref.watch(hasFeatureProvider(feature));

    if (hasFeature) {
      return child;
    }

    if (lockedChild != null) {
      return lockedChild!;
    }

    final purchase = OneTimePurchases.getByFeature(feature);

    return _LockedFeatureCard(
      featureName: purchase?.name ?? feature.name,
      featureDescription: purchase?.description ?? 'This feature requires a purchase',
      price: purchase?.price ?? 0,
      showUpgradeButton: showUpgradeButton,
    );
  }
}

/// Widget shown when a feature is locked
class _LockedFeatureCard extends StatelessWidget {
  final String featureName;
  final String featureDescription;
  final double price;
  final bool showUpgradeButton;

  const _LockedFeatureCard({
    required this.featureName,
    required this.featureDescription,
    required this.price,
    required this.showUpgradeButton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.darkBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, color: context.accentColor, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            featureName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            featureDescription,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (showUpgradeButton) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: Text(price > 0 ? 'Unlock for \$${price.toStringAsFixed(2)}' : 'View Upgrades'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A simple inline lock icon that can be added to indicate premium features
class PremiumBadge extends StatelessWidget {
  final double size;

  const PremiumBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.accentColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock, size: size - 4, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            'PRO',
            style: TextStyle(
              fontSize: size - 4,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// A row item with premium lock indicator
class PremiumFeatureRow extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget child;
  final VoidCallback? onTap;
  final bool showLockIfLocked;

  const PremiumFeatureRow({
    super.key,
    required this.feature,
    required this.child,
    this.onTap,
    this.showLockIfLocked = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFeature = ref.watch(hasFeatureProvider(feature));

    return GestureDetector(
      onTap: hasFeature
          ? onTap
          : () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
      child: Row(
        children: [
          Expanded(child: child),
          if (!hasFeature && showLockIfLocked) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.lock_outline,
              size: 16,
              color: context.accentColor,
            ),
          ],
        ],
      ),
    );
  }
}

/// Check if user has a feature and show upgrade dialog if not
Future<bool> checkFeatureOrShowUpgrade(
  BuildContext context,
  WidgetRef ref,
  PremiumFeature feature,
) async {
  final hasFeature = ref.read(hasFeatureProvider(feature));

  if (hasFeature) {
    return true;
  }

  final purchase = OneTimePurchases.getByFeature(feature);

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: context.accentColor),
          const SizedBox(width: 12),
          Text(purchase?.name ?? 'Premium Feature'),
        ],
      ),
      content: Text(
        purchase?.description ?? 'This feature requires a purchase to unlock.',
        style: const TextStyle(color: AppTheme.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            );
          },
          child: Text(purchase != null ? 'Unlock \$${purchase.price.toStringAsFixed(2)}' : 'View Upgrades'),
        ),
      ],
    ),
  );

  return false;
}
