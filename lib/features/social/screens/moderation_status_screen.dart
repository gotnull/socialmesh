import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
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

class _ModerationStatusScreenState
    extends ConsumerState<ModerationStatusScreen> {
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
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(moderationStatusProvider);

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        title: const Text('Account Status'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _contactSupport,
          ),
        ],
      ),
      body: statusAsync.when(
        data: (status) {
          if (status == null) {
            return _buildGoodStanding();
          }
          return _buildStatusContent(status);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading status: $e')),
      ),
    );
  }

  Widget _buildGoodStanding() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.verified_rounded,
                size: 64,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account in Good Standing',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You have no active warnings or strikes.\nKeep up the great work!',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withValues(alpha: 0.7),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current status card
          _StatusOverviewCard(status: status),
          const SizedBox(height: 24),

          // Strike meter
          if (status.activeStrikes > 0) ...[
            _StrikeMeterCard(strikeCount: status.activeStrikes),
            const SizedBox(height: 24),
          ],

          // Guidelines reminder
          _GuidelinesCard(),
          const SizedBox(height: 24),

          // History section
          if (status.history.isNotEmpty) ...[
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ...status.history.map((item) => _HistoryItemCard(item: item)),
          ],

          const SizedBox(height: 32),

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
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.email_outlined,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Questions? Contact Support',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
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
      statusColor = Colors.red;
      statusIcon = Icons.block_rounded;
      statusText = 'Suspended';
    } else if (hasStrikes) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning_amber_rounded;
      statusText = 'Warning: Strikes Active';
    } else if (hasWarnings) {
      statusColor = Colors.amber;
      statusIcon = Icons.info_outline;
      statusText = 'Warnings Active';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle_outline;
      statusText = 'Good Standing';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withValues(alpha: 0.2),
            statusColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withValues(alpha: 0.2),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    if (isSuspended && status.suspendedUntil != null) ...[
                      const SizedBox(height: 4),
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
            const SizedBox(height: 16),
            Divider(color: statusColor.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Warnings',
                  value: '${status.activeWarnings}',
                  color: Colors.amber,
                ),
                _StatItem(
                  label: 'Strikes',
                  value: '${status.activeStrikes}',
                  color: Colors.orange,
                ),
                _StatItem(
                  label: 'Max Strikes',
                  value: '3',
                  color: Colors.red.withValues(alpha: 0.5),
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
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
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
              const Icon(Icons.trending_up, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Strike Meter',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Text(
                '$strikeCount / $maxStrikes',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                    borderRadius: BorderRadius.circular(4),
                    color: isActive
                        ? (index == maxStrikes - 1 ? Colors.red : Colors.orange)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Text(
            strikeCount >= maxStrikes
                ? '⚠️ Maximum strikes reached. Your account may be suspended.'
                : '${maxStrikes - strikeCount} strike${maxStrikes - strikeCount > 1 ? 's' : ''} remaining before suspension.',
            style: TextStyle(
              fontSize: 13,
              color: strikeCount >= maxStrikes
                  ? Colors.red.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.6),
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
      padding: const EdgeInsets.all(20),
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
              const SizedBox(width: 8),
              const Text(
                'Community Guidelines',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Please ensure your content follows our guidelines:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          _GuidelineItem(text: 'No explicit or adult content'),
          _GuidelineItem(text: 'No violent or graphic imagery'),
          _GuidelineItem(text: 'No harassment or hate speech'),
          _GuidelineItem(text: 'No spam or misleading content'),
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
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
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
        typeColor = Colors.amber;
        typeIcon = Icons.info_outline;
      case ModerationActionType.strike:
        typeColor = Colors.orange;
        typeIcon = Icons.warning_amber_rounded;
      case ModerationActionType.suspension:
        typeColor = Colors.red;
        typeIcon = Icons.block_rounded;
      case ModerationActionType.cleared:
        typeColor = Colors.green;
        typeIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: typeColor.withValues(alpha: 0.15),
            ),
            child: Icon(typeIcon, color: typeColor, size: 16),
          ),
          const SizedBox(width: 12),
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
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                if (item.reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.reason!,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                if (item.contentType != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.contentType!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.5),
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
