import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/subscription_providers.dart';

/// Gold color used for verified/authorised badges
const Color kGoldBadgeColor = Color(0xFFFFD700);

/// A verified badge widget that displays differently based on badge type:
/// - Gold badge for users with all premium features (Authorised)
/// - Standard verified badge from Firestore (admin-managed)
class VerifiedBadge extends ConsumerWidget {
  /// The size of the badge icon
  final double size;

  /// Whether the user is verified (from Firestore)
  final bool isVerified;

  /// Whether to check if current user has all premium features
  /// If true, shows gold badge for current user if they have all features
  final bool checkPremiumStatus;

  /// Optional user ID - if provided and matches current user, checks premium status
  final String? userId;

  const VerifiedBadge({
    super.key,
    this.size = 16,
    this.isVerified = false,
    this.checkPremiumStatus = false,
    this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check if current user should show gold badge
    final hasAllPremium = checkPremiumStatus
        ? ref.watch(hasAllPremiumFeaturesProvider)
        : false;

    // Show gold badge if user has all premium features
    if (hasAllPremium) {
      return Icon(Icons.verified, size: size, color: kGoldBadgeColor);
    }

    // Show standard verified badge if verified in Firestore
    if (isVerified) {
      return Icon(
        Icons.verified,
        size: size,
        color: kGoldBadgeColor, // Also gold for admin-verified users
      );
    }

    // No badge
    return const SizedBox.shrink();
  }
}

/// A simple verified badge that always shows with gold color
/// Use this for displaying verified status without checking premium
class SimpleVerifiedBadge extends StatelessWidget {
  final double size;

  const SimpleVerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.verified, size: size, color: kGoldBadgeColor);
  }
}
