import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/subscription_models.dart';
import '../../providers/subscription_providers.dart';
import '../theme.dart';
import 'premium_upsell_sheet.dart';

/// A widget that provides "look but don't touch" premium feature gating.
///
/// Users can see and explore premium features, but when they try to take
/// action (save, enable, run), they're gently intercepted with an upsell.
///
/// Usage:
/// ```dart
/// PremiumFeatureGate(
///   feature: PremiumFeature.automations,
///   child: AutomationEditor(),
///   onAttemptAction: () => _save(),
/// )
/// ```
class PremiumFeatureGate extends ConsumerWidget {
  /// The premium feature being gated
  final PremiumFeature feature;

  /// The child widget (always rendered for exploration)
  final Widget child;

  /// Badge position, defaults to top-right
  final Alignment badgeAlignment;

  /// Whether to show the premium badge overlay
  final bool showBadge;

  const PremiumFeatureGate({
    super.key,
    required this.feature,
    required this.child,
    this.badgeAlignment = Alignment.topRight,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasFeature = ref.watch(hasFeatureProvider(feature));

    if (hasFeature || !showBadge) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: badgeAlignment == Alignment.topRight ? -4 : null,
          left: badgeAlignment == Alignment.topLeft ? -4 : null,
          child: const PremiumBadge(),
        ),
      ],
    );
  }
}

/// A small premium badge that indicates a feature requires premium
class PremiumBadge extends StatelessWidget {
  final double size;

  const PremiumBadge({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
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
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.star_rounded, size: size * 0.6, color: Colors.white),
    );
  }
}

/// A chip-style premium indicator for list items
class PremiumChip extends StatelessWidget {
  final String? label;
  final bool compact;

  const PremiumChip({super.key, this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade400, Colors.orange.shade600],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Colors.white),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper to check if premium is required before an action and show upsell
///
/// Returns true if action can proceed, false if blocked by premium
Future<bool> checkPremiumOrShowUpsell({
  required BuildContext context,
  required WidgetRef ref,
  required PremiumFeature feature,
  String? featureDescription,
}) async {
  final hasFeature = ref.read(hasFeatureProvider(feature));

  if (hasFeature) {
    return true;
  }

  // Show upsell sheet
  final purchased = await showPremiumUpsellSheet(
    context: context,
    ref: ref,
    feature: feature,
    featureDescription: featureDescription,
  );

  return purchased;
}

/// Shows the premium upsell bottom sheet
///
/// Returns true if purchase was successful, false otherwise
Future<bool> showPremiumUpsellSheet({
  required BuildContext context,
  required WidgetRef ref,
  required PremiumFeature feature,
  String? featureDescription,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: context.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => PremiumUpsellSheet(
      feature: feature,
      featureDescription: featureDescription,
    ),
  );

  return result ?? false;
}
