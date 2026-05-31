// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../providers/social_providers.dart';
import '../../../services/content_moderation_service.dart';

/// Detailed moderation status screen showing history and current status.
class ModerationStatusScreen extends ConsumerStatefulWidget {
  const ModerationStatusScreen({super.key});

  @override
  ConsumerState<ModerationStatusScreen> createState() =>
      _ModerationStatusScreenState();
}

class _ModerationStatusScreenState extends ConsumerState<ModerationStatusScreen>
    with LifecycleSafeMixin<ModerationStatusScreen> {
  @override
  void initState() {
    super.initState();
    // Mark items as acknowledged when viewing this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(moderationStatusProvider.notifier).acknowledgeAll();
    });
  }

  Future<void> _contactSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@socialmesh.app',
      queryParameters: {
        'subject': 'Moderation Question',
        'body':
            'Hi,\n\nI have a question about content moderation '
            'on my account.\n\nThank you.',
      },
    );

    if (await canLaunchUrl(uri)) {
      if (!canUpdateUI) return;
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(moderationStatusProvider);

    return GlassScaffold(
      title: context.l10n.socialAccountStatusTitle,
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          onPressed: _contactSupport,
        ),
      ],
      slivers: [
        statusAsync.when(
          data: (status) {
            if (status == null) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _buildGoodStanding(),
              );
            }
            return SliverToBoxAdapter(child: _buildStatusContent(status));
          },
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(context.l10n.socialAccountStatusError(e.toString())),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoodStanding() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.successGreen.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 64,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              context.l10n.socialAccountGoodStanding,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              context.l10n.socialAccountGoodStandingDesc,
              style: TextStyle(
                fontSize: 15,
                color: context.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusContent(ModerationStatus status) {
    // If no active warnings or strikes, show good standing
    if (status.activeWarnings == 0 &&
        status.activeStrikes == 0 &&
        !status.isSuspended &&
        status.history.isEmpty) {
      return _buildGoodStanding();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current status card
          _StatusOverviewCard(status: status),
          const SizedBox(height: AppTheme.spacing24),

          // Strike meter
          if (status.activeStrikes > 0) ...[
            _StrikeMeterCard(strikeCount: status.activeStrikes),
            const SizedBox(height: AppTheme.spacing24),
          ],

          // Guidelines reminder
          _GuidelinesCard(),
          const SizedBox(height: AppTheme.spacing24),

          // History section
          if (status.history.isNotEmpty) ...[
            Text(
              context.l10n.socialAccountRecentActivity,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            ...status.history.map((item) => _HistoryItemCard(item: item)),
          ],

          const SizedBox(height: AppTheme.spacing32),

          // Contact support
          Center(
            child: BouncyTap(
              onTap: _contactSupport,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  border: Border.all(
                    color: context.isDarkMode
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: context.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Text(
                      context.l10n.socialContactSupport,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing32),
        ],
      ),
    );
  }
}

class _StatusOverviewCard extends StatelessWidget {
  final ModerationStatus status;

  const _StatusOverviewCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final isSuspended = status.isSuspended;
    final hasStrikes = status.activeStrikes > 0;
    final hasWarnings = status.activeWarnings > 0;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isSuspended) {
      statusColor = AppTheme.errorRed;
      statusIcon = Icons.block_rounded;
      statusText = context.l10n.socialAccountSuspended;
    } else if (hasStrikes) {
      statusColor = AccentColors.orange;
      statusIcon = Icons.warning_amber_rounded;
      statusText = context.l10n.socialAccountWarningStrikesActive;
    } else if (hasWarnings) {
      statusColor = AppTheme.warningYellow;
      statusIcon = Icons.info_outline;
      statusText = context.l10n.socialAccountWarningsActive;
    } else {
      statusColor = AppTheme.successGreen;
      statusIcon = Icons.check_circle_outline;
      statusText = context.l10n.socialAccountGoodStandingLabel;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.2),
            statusColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.2),
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    if (isSuspended && status.suspendedUntil != null) ...[
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        'Until ${DateFormat.yMMMd().add_jm().format(status.suspendedUntil!)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: statusColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasStrikes || hasWarnings) ...[
            const SizedBox(height: AppTheme.spacing16),
            Divider(color: statusColor.withValues(alpha: 0.2)),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: context.l10n.socialAccountWarnings,
                  value: '${status.activeWarnings}',
                  color: AppTheme.warningYellow,
                ),
                _StatItem(
                  label: context.l10n.socialAccountStrikes,
                  value: '${status.activeStrikes}',
                  color: AccentColors.orange,
                ),
                _StatItem(
                  label: context.l10n.socialAccountMaxStrikes,
                  value: '3',
                  color: AppTheme.errorRed.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textTertiary),
        ),
      ],
    );
  }
}

class _StrikeMeterCard extends StatelessWidget {
  final int strikeCount;
  static const int maxStrikes = 3;

  const _StrikeMeterCard({required this.strikeCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: AccentColors.orange,
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.socialAccountStrikeMeter,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '$strikeCount / $maxStrikes',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AccentColors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          // Visual strike meter
          Row(
            children: List.generate(maxStrikes, (index) {
              final isActive = index < strikeCount;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    right: index < maxStrikes - 1 ? 8 : 0,
                  ),
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radius4),
                    color: isActive
                        ? (index == maxStrikes - 1
                              ? AppTheme.errorRed
                              : AccentColors.orange)
                        : context.isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            strikeCount >= maxStrikes
                ? '⚠️ Maximum strikes reached. Your account may be suspended.'
                : '${maxStrikes - strikeCount} strike${maxStrikes - strikeCount > 1 ? 's' : ''} remaining before suspension.',
            style: TextStyle(
              fontSize: 13,
              color: strikeCount >= maxStrikes
                  ? AppTheme.errorRed.withValues(alpha: 0.9)
                  : context.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidelinesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GradientBorderContainer(
      borderRadius: 16,
      borderWidth: 2,
      accentOpacity: 0.2,
      backgroundColor: context.accentColor.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_outlined,
                color: context.accentColor.withValues(alpha: 0.9),
                size: 20,
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                context.l10n.socialCommunityGuidelines,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            'Please ensure your content follows our guidelines:',
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing12),
          _GuidelineItem(text: context.l10n.socialGuidelineNoExplicit),
          _GuidelineItem(text: context.l10n.socialGuidelineNoViolentImagery),
          _GuidelineItem(text: context.l10n.socialGuidelineNoHarassment),
          _GuidelineItem(text: context.l10n.socialGuidelineNoSpam),
        ],
      ),
    );
  }
}

class _GuidelineItem extends StatelessWidget {
  final String text;

  const _GuidelineItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: context.accentColor.withValues(alpha: 0.7),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItemCard extends StatelessWidget {
  final ModerationHistoryItem item;

  const _HistoryItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    Color typeColor;
    IconData typeIcon;

    switch (item.type) {
      case ModerationActionType.warning:
        typeColor = AppTheme.warningYellow;
        typeIcon = Icons.info_outline;
      case ModerationActionType.strike:
        typeColor = AccentColors.orange;
        typeIcon = Icons.warning_amber_rounded;
      case ModerationActionType.suspension:
        typeColor = AppTheme.errorRed;
        typeIcon = Icons.block_rounded;
      case ModerationActionType.cleared:
        typeColor = AppTheme.successGreen;
        typeIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: typeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: typeColor.withValues(alpha: 0.15),
            ),
            child: Icon(typeIcon, color: typeColor, size: 16),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.type.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: typeColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat.yMMMd().format(item.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
                if (item.reason != null) ...[
                  const SizedBox(height: AppTheme.spacing4),
                  Text(
                    item.reason!,
                    style: TextStyle(fontSize: 13, color: context.textTertiary),
                  ),
                ],
                if (item.contentType != null) ...[
                  const SizedBox(height: AppTheme.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: context.isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radius6),
                    ),
                    child: Text(
                      item.contentType!,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
