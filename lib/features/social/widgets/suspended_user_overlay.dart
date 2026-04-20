// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../providers/social_providers.dart';
import '../../../utils/email_launcher.dart';
import '../../../utils/snackbar.dart';

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

  String _formatDuration(BuildContext context, DateTime? until) {
    if (until == null) return context.l10n.socialSuspendedIndefinitely;

    final now = DateTime.now();
    final difference = until.difference(now);

    if (difference.isNegative) return context.l10n.socialSuspendedShortly;

    if (difference.inDays > 0) {
      final days = difference.inDays;
      return days > 1
          ? context.l10n.socialSuspendedDaysPlural(days)
          : context.l10n.socialSuspendedDaysSingular(days);
    } else if (difference.inHours > 0) {
      final hours = difference.inHours;
      return hours > 1
          ? context.l10n.socialSuspendedHoursPlural(hours)
          : context.l10n.socialSuspendedHoursSingular(hours);
    } else {
      final minutes = difference.inMinutes;
      return minutes > 1
          ? context.l10n.socialSuspendedMinutesPlural(minutes)
          : context.l10n.socialSuspendedMinutesSingular(minutes);
    }
  }

  Future<void> _contactSupport(BuildContext context) async {
    await launchEmailCompose(
      context: context,
      to: 'support@socialmesh.app',
      subject: context.l10n.socialSuspendedAppealSubject,
      body: context.l10n.socialSuspendedAppealBody,
    );
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
                tooltip: context.l10n.socialSuspendedGoBack,
              ),
            ),
            // Main content
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Warning icon with glow
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.errorRed.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.errorRed.withValues(alpha: 0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      size: 64,
                      color: AppTheme.errorRed,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing32),

                  // Title
                  Text(
                    isPermanent
                        ? context.l10n.socialSuspendedPermanent
                        : context.l10n.socialSuspendedTemporary,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing16),

                  // Duration info
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radius12),
                      border: Border.all(
                        color: AppTheme.errorRed.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppTheme.errorRed,
                          size: 20,
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        Text(
                          isPermanent
                              ? context.l10n.socialSuspendedIndefinite
                              : context.l10n.socialSuspendedRemaining(
                                  _formatDuration(context, suspendedUntil),
                                ),
                          style: const TextStyle(
                            color: AppTheme.errorRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing24),

                  // Explanation
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
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
                            const SizedBox(width: AppTheme.spacing8),
                            Text(
                              context.l10n.socialSuspendedWhyTitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        Text(
                          reason ?? context.l10n.socialSuspendedDefaultReason,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        if (strikeCount > 0) ...[
                          const SizedBox(height: AppTheme.spacing16),
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AccentColors.orange,
                                size: 16,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Text(
                                context.l10n.socialSuspendedStrikesCount(
                                  strikeCount,
                                ),
                                style: const TextStyle(
                                  color: AccentColors.orange,
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
                  const SizedBox(height: AppTheme.spacing24),

                  // What you can do
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing20),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
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
                            const SizedBox(width: AppTheme.spacing8),
                            Text(
                              context.l10n.socialSuspendedWhatCanIDo,
                              style: TextStyle(
                                color: accentColor.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        _BulletPoint(
                          text: isPermanent
                              ? context.l10n.socialSuspendedWaitAppeal
                              : context.l10n.socialSuspendedWaitPeriod,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        _BulletPoint(
                          text: context.l10n.socialSuspendedReviewGuidelines,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        _BulletPoint(
                          text: context.l10n.socialSuspendedContactSupport,
                          accentColor: accentColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing32),

                  // Contact support button
                  BouncyTap(
                    onTap: () => _contactSupport(context),
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
                        borderRadius: BorderRadius.circular(AppTheme.radius30),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.email_outlined, color: Colors.white),
                          const SizedBox(width: AppTheme.spacing12),
                          Text(
                            context.l10n.socialContactSupportButton,
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
                  const SizedBox(height: AppTheme.spacing16),

                  // Email hint
                  BouncyTap(
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(text: 'support@socialmesh.app'),
                      );
                      showSuccessSnackBar(
                        context,
                        context.l10n.socialEmailCopied,
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
                        const SizedBox(width: AppTheme.spacing8),
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
        const SizedBox(width: AppTheme.spacing12),
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
