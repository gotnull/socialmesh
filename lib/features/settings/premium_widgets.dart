import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import 'subscription_screen.dart';

/// A widget that gates content behind a premium feature check.
/// Shows a paywall prompt when the user doesn't have access.
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

    final info = FeatureInfo.getInfo(feature);

    return _LockedFeatureCard(
      featureName: info?.name ?? feature.name,
      featureDescription:
          info?.description ?? 'This feature requires a premium subscription',
      minimumTier: info?.minimumTier ?? SubscriptionTier.premium,
      showUpgradeButton: showUpgradeButton,
    );
  }
}

/// Widget shown when a feature is locked
class _LockedFeatureCard extends StatelessWidget {
  final String featureName;
  final String featureDescription;
  final SubscriptionTier minimumTier;
  final bool showUpgradeButton;

  const _LockedFeatureCard({
    required this.featureName,
    required this.featureDescription,
    required this.minimumTier,
    required this.showUpgradeButton,
  });

  @override
  Widget build(BuildContext context) {
    final tierName = minimumTier == SubscriptionTier.pro ? 'Pro' : 'Premium';
    final tierColor = minimumTier == SubscriptionTier.pro
        ? AppTheme.accentOrange
        : context.accentColor;

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
              color: tierColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, color: tierColor, size: 32),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$tierName Feature',
              style: TextStyle(
                color: tierColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          if (showUpgradeButton) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openSubscription(context),
              icon: const Icon(Icons.star, size: 18),
              label: Text('Upgrade to $tierName'),
            ),
          ],
        ],
      ),
    );
  }

  void _openSubscription(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }
}

/// A button that shows an upgrade prompt if the feature is locked
class PremiumFeatureButton extends ConsumerWidget {
  final PremiumFeature feature;
  final VoidCallback onPressed;
  final Widget child;
  final ButtonStyle? style;

  const PremiumFeatureButton({
    super.key,
    required this.feature,
    required this.onPressed,
    required this.child,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFeature = ref.watch(hasFeatureProvider(feature));
    final info = FeatureInfo.getInfo(feature);
    final tierName =
        (info?.minimumTier ?? SubscriptionTier.premium) == SubscriptionTier.pro
        ? 'Pro'
        : 'Premium';

    return FilledButton(
      onPressed: hasFeature
          ? onPressed
          : () => _showUpgradePrompt(
              context,
              tierName,
              info?.name ?? feature.name,
            ),
      style: style,
      child: hasFeature
          ? child
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 16),
                const SizedBox(width: 8),
                child,
              ],
            ),
    );
  }

  void _showUpgradePrompt(
    BuildContext context,
    String tierName,
    String featureName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$tierName Feature'),
        content: Text(
          '$featureName requires a $tierName subscription. Would you like to upgrade?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

/// A list tile that shows a lock icon if the feature is locked
class PremiumFeatureListTile extends ConsumerWidget {
  final PremiumFeature feature;
  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  const PremiumFeatureListTile({
    super.key,
    required this.feature,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFeature = ref.watch(hasFeatureProvider(feature));
    final info = FeatureInfo.getInfo(feature);
    final tierColor =
        (info?.minimumTier ?? SubscriptionTier.premium) == SubscriptionTier.pro
        ? AppTheme.accentOrange
        : context.accentColor;

    return ListTile(
      leading: hasFeature
          ? leading
          : Stack(
              children: [
                if (leading != null) Opacity(opacity: 0.5, child: leading),
                Positioned.fill(
                  child: Center(
                    child: Icon(Icons.lock, size: 16, color: tierColor),
                  ),
                ),
              ],
            ),
      title: Opacity(opacity: hasFeature ? 1.0 : 0.6, child: title),
      subtitle: hasFeature
          ? subtitle
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    info?.minimumTier == SubscriptionTier.pro
                        ? 'PRO'
                        : 'PREMIUM',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: tierColor,
                    ),
                  ),
                ),
              ],
            ),
      trailing: hasFeature
          ? trailing
          : Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      onTap: hasFeature
          ? onTap
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
    );
  }
}

/// A widget that shows an upgrade banner at the bottom of the screen
class UpgradeBanner extends ConsumerWidget {
  final String? customMessage;

  const UpgradeBanner({super.key, this.customMessage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(currentTierProvider);
    final upgradePrompt = ref.watch(upgradePromptProvider);

    if (tier == SubscriptionTier.pro || upgradePrompt.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.accentColor.withValues(alpha: 0.3),
            AppTheme.secondaryPink.withValues(alpha: 0.3),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.star, color: context.accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customMessage ?? upgradePrompt,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
              ),
              child: const Text('Upgrade'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A badge that shows the subscription tier
class SubscriptionBadge extends ConsumerWidget {
  final bool showIfFree;

  const SubscriptionBadge({super.key, this.showIfFree = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(currentTierProvider);

    if (tier == SubscriptionTier.free && !showIfFree) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    switch (tier) {
      case SubscriptionTier.free:
        badgeColor = AppTheme.textTertiary;
        badgeText = 'FREE';
        badgeIcon = Icons.person_outline;
      case SubscriptionTier.premium:
        badgeColor = context.accentColor;
        badgeText = 'PREMIUM';
        badgeIcon = Icons.star;
      case SubscriptionTier.pro:
        badgeColor = AppTheme.accentOrange;
        badgeText = 'PRO';
        badgeIcon = Icons.workspace_premium;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that wraps content and shows trial info if applicable
class TrialBanner extends ConsumerWidget {
  const TrialBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTrialing = ref.watch(isTrialActiveProvider);
    final daysRemaining = ref.watch(trialDaysRemainingProvider);

    if (!isTrialing) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppTheme.warningYellow,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$daysRemaining days left in your trial',
              style: const TextStyle(
                color: AppTheme.warningYellow,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
            child: const Text('Subscribe Now'),
          ),
        ],
      ),
    );
  }
}
