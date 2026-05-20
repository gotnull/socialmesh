// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../models/meshcore_contact.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/meshcore_providers.dart';

/// MeshCore-flavoured equivalent of `MeshHealthContent`. Health score
/// (0-100) blends connection status, fresh-contact count, and aggregate
/// SNR from recent contact adverts.
///
/// Scoring weights (parallels the Meshtastic health scorer but with
/// MeshCore-appropriate signals):
///   - Disconnected returns 0 immediately.
///   - 50 base points for being connected.
///   - Up to 20 points for fresh contacts (lastSeen within 1h).
///   - Up to 20 points for aggregate SNR (median across contacts that
///     report SNR; falls through cleanly when no contacts carry SNR).
///   - Up to 10 points for channel reach (number of configured channels).
class MeshCoreMeshHealthContent extends ConsumerWidget {
  const MeshCoreMeshHealthContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final linkStatus = ref.watch(linkStatusProvider);
    final contactsState = ref.watch(meshCoreContactsProvider);
    final channelsState = ref.watch(meshCoreChannelsProvider);

    final isConnected = linkStatus.isConnected;
    final now = DateTime.now();
    final freshContacts = contactsState.contacts
        .where((c) => now.difference(c.lastSeen).inHours < 1)
        .length;
    final contactsWithSnr = contactsState.contacts
        .where((c) => c.snrDb != null)
        .toList();
    final medianSnr = _medianSnr(contactsWithSnr);
    final channelCount = channelsState.channels.length;

    final score = _calculateHealthScore(
      isConnected: isConnected,
      freshContactCount: freshContacts,
      medianSnr: medianSnr,
      channelCount: channelCount,
    );
    final status = _statusLabel(context, score);
    final color = _statusColor(score);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: context.border,
                    valueColor: AlwaysStoppedAnimation(
                      context.border.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(color),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${score.round()}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _HealthFactor(
                icon: Icons.link_rounded,
                label: l10n.meshcoreWidgetMeshHealthConnectionLabel,
                status: isConnected
                    ? l10n.meshcoreWidgetMeshHealthOnline
                    : l10n.meshcoreWidgetMeshHealthOffline,
                isGood: isConnected,
              ),
              _HealthFactor(
                icon: Icons.people_outline_rounded,
                label: l10n.meshcoreWidgetMeshHealthFreshLabel,
                status: '$freshContacts',
                isGood: freshContacts > 0,
              ),
              _HealthFactor(
                icon: Icons.signal_cellular_alt_rounded,
                label: l10n.meshcoreWidgetMeshHealthSnrLabel,
                status: medianSnr != null
                    ? '${medianSnr.toStringAsFixed(0)} dB'
                    : l10n.meshcoreWidgetMeshHealthSnrUnknown,
                isGood: medianSnr != null && medianSnr >= -7,
              ),
              _HealthFactor(
                icon: Icons.forum_outlined,
                label: l10n.meshcoreWidgetMeshHealthChannelsLabel,
                status: '$channelCount',
                isGood: channelCount > 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double? _medianSnr(List<MeshCoreContact> contactsWithSnr) {
    if (contactsWithSnr.isEmpty) return null;
    final values = contactsWithSnr.map((c) => c.snrDb!).toList()..sort();
    return values[values.length ~/ 2];
  }

  String _statusLabel(BuildContext context, double score) {
    final l10n = context.l10n;
    if (score >= 80) return l10n.meshcoreWidgetMeshHealthStatusExcellent;
    if (score >= 60) return l10n.meshcoreWidgetMeshHealthStatusGood;
    if (score >= 40) return l10n.meshcoreWidgetMeshHealthStatusFair;
    if (score > 0) return l10n.meshcoreWidgetMeshHealthStatusPoor;
    return l10n.meshcoreWidgetMeshHealthOffline;
  }

  Color _statusColor(double score) {
    if (score >= 70) return AccentColors.green;
    if (score >= 40) return AppTheme.warningYellow;
    return AppTheme.errorRed;
  }
}

// Visible for testing: the scoring function is pure and protocol-only,
// so a unit test can pin the curve without spinning up Riverpod.
@visibleForTesting
double calculateMeshCoreHealthScoreForTesting({
  required bool isConnected,
  required int freshContactCount,
  required double? medianSnr,
  required int channelCount,
}) {
  return _calculateHealthScore(
    isConnected: isConnected,
    freshContactCount: freshContactCount,
    medianSnr: medianSnr,
    channelCount: channelCount,
  );
}

double _calculateHealthScore({
  required bool isConnected,
  required int freshContactCount,
  required double? medianSnr,
  required int channelCount,
}) {
  if (!isConnected) return 0;
  double score = 50;
  if (freshContactCount > 0) {
    score += freshContactCount.clamp(0, 10) * 2;
  }
  if (medianSnr != null) {
    if (medianSnr >= 0) {
      score += 20;
    } else if (medianSnr >= -7) {
      score += 15;
    } else if (medianSnr >= -12) {
      score += 10;
    } else if (medianSnr >= -18) {
      score += 5;
    }
  }
  if (channelCount > 0) {
    score += channelCount.clamp(0, 5) * 2;
  }
  return score.clamp(0.0, 100.0);
}

class _HealthFactor extends StatelessWidget {
  final IconData icon;
  final String label;
  final String status;
  final bool isGood;

  const _HealthFactor({
    required this.icon,
    required this.label,
    required this.status,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 18,
          color: isGood ? context.accentColor : context.textTertiary,
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isGood ? context.textPrimary : context.textSecondary,
          ),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
        ),
      ],
    );
  }
}
