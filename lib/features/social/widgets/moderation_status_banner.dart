import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/animations.dart';
import '../../../providers/social_providers.dart';
import '../screens/moderation_status_screen.dart';

/// Banner showing current moderation status (warnings, strikes).
/// Displayed at top of social screens when user has active moderation items.
class ModerationStatusBanner extends ConsumerWidget {
  const ModerationStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(moderationStatusProvider);

    return statusAsync.when(
      data: (status) {
        if (status == null) return const SizedBox.shrink();

        // Check for unacknowledged items or active status
        final hasUnacknowledged = status.unacknowledgedCount > 0;
        final hasActiveWarnings = status.activeWarnings > 0;
        final hasActiveStrikes = status.activeStrikes > 0;

        if (!hasUnacknowledged && !hasActiveWarnings && !hasActiveStrikes) {
          return const SizedBox.shrink();
        }

        // Determine severity and colors
        Color backgroundColor;
        Color textColor;
        IconData icon;
        String message;

        if (hasActiveStrikes) {
          backgroundColor = Colors.orange.withValues(alpha: 0.15);
          textColor = Colors.orange;
          icon = Icons.warning_amber_rounded;
          message = hasUnacknowledged
              ? 'You have ${status.activeStrikes} strike${status.activeStrikes > 1 ? 's' : ''} - tap to review'
              : '${status.activeStrikes} active strike${status.activeStrikes > 1 ? 's' : ''} on your account';
        } else if (hasActiveWarnings) {
          backgroundColor = Colors.amber.withValues(alpha: 0.15);
          textColor = Colors.amber.shade700;
          icon = Icons.info_outline;
          message = hasUnacknowledged
              ? 'You have ${status.activeWarnings} warning${status.activeWarnings > 1 ? 's' : ''} - tap to review'
              : '${status.activeWarnings} active warning${status.activeWarnings > 1 ? 's' : ''}';
        } else {
          return const SizedBox.shrink();
        }

        return BouncyTap(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ModerationStatusScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: textColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (hasUnacknowledged) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: textColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${status.unacknowledgedCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.chevron_right,
                  color: textColor.withValues(alpha: 0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
