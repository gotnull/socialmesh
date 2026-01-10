import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../providers/social_providers.dart';

/// Full-screen blocking overlay for suspended users.
/// Prevents any interaction with social features until suspension is lifted.
class SuspendedUserOverlay extends ConsumerWidget {
  final Widget child;

  const SuspendedUserOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(moderationStatusProvider);

    return statusAsync.when(
      data: (status) {
        if (status == null || !status.isSuspended) {
          return child;
        }

        return Stack(
          children: [
            // Blurred/dimmed background showing the actual content
            IgnorePointer(
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.7),
                  BlendMode.srcATop,
                ),
                child: child,
              ),
            ),
            // Suspension notice overlay
            _SuspensionNotice(
              suspendedUntil: status.suspendedUntil,
              reason: status.lastReason,
              strikeCount: status.activeStrikes,
            ),
          ],
        );
      },
      // During loading, show child but keep checking
      // This prevents flash on initial load
      loading: () => child,
      // On error, show child (fail open for UX, but log it)
      error: (e, _) {
        AppLogging.social('Error loading moderation status: $e');
        return child;
      },
    );
  }
}

class _SuspensionNotice extends StatelessWidget {
  final DateTime? suspendedUntil;
  final String? reason;
  final int strikeCount;

  const _SuspensionNotice({
    this.suspendedUntil,
    this.reason,
    required this.strikeCount,
  });

  String _formatDuration(DateTime? until) {
    if (until == null) return 'indefinitely';

    final now = DateTime.now();
    final difference = until.difference(now);

    if (difference.isNegative) return 'shortly';

    if (difference.inDays > 0) {
      final days = difference.inDays;
      return '$days day${days > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      return '$hours hour${hours > 1 ? 's' : ''}';
    } else {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes > 1 ? 's' : ''}';
    }
  }

  Future<void> _contactSupport() async {
    // Use Uri.encodeFull to avoid + encoding for spaces
    const subject = 'Account Suspension Appeal';
    const body =
        'Hi,\n\nI would like to appeal my account suspension.\n\nPlease review my case.\n\nThank you.';
    final uri = Uri.parse(
      'mailto:support@socialmesh.app?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPermanent = suspendedUntil == null;
    final accentColor = context.accentColor;

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Stack(
          children: [
            // Back button at top-left
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Go back',
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Warning icon with glow
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      size: 64,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    isPermanent
                        ? 'Account Suspended'
                        : 'Posting Temporarily Suspended',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Duration info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPermanent
                              ? 'Indefinite suspension'
                              : 'Remaining: ${_formatDuration(suspendedUntil)}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Explanation
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.white.withValues(alpha: 0.7),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Why am I seeing this?',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          reason ??
                              'Your account has been suspended due to repeated '
                                  'violations of our community guidelines.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        if (strikeCount > 0) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$strikeCount strike${strikeCount > 1 ? 's' : ''} on your account',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // What you can do
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.help_outline,
                              color: accentColor.withValues(alpha: 0.9),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'What can I do?',
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _BulletPoint(
                          text: isPermanent
                              ? 'Wait for your appeal to be reviewed'
                              : 'Wait for the suspension period to end',
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 8),
                        _BulletPoint(
                          text: 'Review our community guidelines',
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 8),
                        _BulletPoint(
                          text: 'Contact support to appeal this decision',
                          accentColor: accentColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Contact support button
                  BouncyTap(
                    onTap: _contactSupport,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor,
                            HSLColor.fromColor(accentColor)
                                .withLightness(
                                  (HSLColor.fromColor(accentColor).lightness *
                                          0.7)
                                      .clamp(0.0, 1.0),
                                )
                                .toColor(),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.email_outlined, color: Colors.white),
                          SizedBox(width: 12),
                          Text(
                            'Contact Support',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email hint
                  BouncyTap(
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(text: 'support@socialmesh.app'),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Email copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.copy,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'support@socialmesh.app',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
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
}

class _BulletPoint extends StatelessWidget {
  final String text;
  final Color accentColor;

  const _BulletPoint({required this.text, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
