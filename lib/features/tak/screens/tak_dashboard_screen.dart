// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../models/tak_event.dart';
import '../providers/tak_dashboard_provider.dart';
import '../providers/tak_filter_provider.dart';
import '../utils/cot_affiliation.dart';
import 'tak_navigate_screen.dart';
import 'tak_screen.dart';

/// Situational Awareness Dashboard showing force disposition, threat
/// proximity, and connection status at a glance.
class TakDashboardScreen extends ConsumerWidget {
  const TakDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(takDashboardProvider);

    AppLogging.tak(
      'Dashboard: friendly=${dashboard.friendlyCount}, '
      'hostile=${dashboard.hostileCount}, '
      'neutral=${dashboard.neutralCount}, '
      'unknown=${dashboard.unknownCount}',
    );

    if (dashboard.nearestHostile != null) {
      AppLogging.tak(
        'Dashboard: nearest hostile='
        '${dashboard.nearestHostile!.callsign ?? dashboard.nearestHostile!.uid}'
        ' at ${dashboard.nearestHostileDistanceKm?.toStringAsFixed(1)} km',
      );
    }

    if (dashboard.nearestUnknown != null) {
      AppLogging.tak(
        'Dashboard: nearest unknown='
        '${dashboard.nearestUnknown!.callsign ?? dashboard.nearestUnknown!.uid}'
        ' at ${dashboard.nearestUnknownDistanceKm?.toStringAsFixed(1)} km',
      );
    }

    AppLogging.tak(
      'Dashboard: ${dashboard.trackedCount} tracked, '
      '${dashboard.staleCount} stale, '
      '${dashboard.isConnected ? "connected" : "disconnected"}, '
      '${dashboard.isPublishing ? "publishing @ ${dashboard.publishIntervalSeconds}s" : "not publishing"}',
    );

    return GlassScaffold(
      title: 'SA Dashboard',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(UiConstants.defaultPadding),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _ForceCountGrid(dashboard: dashboard),
              const SizedBox(height: 16),
              _ThreatProximityCard(dashboard: dashboard),
              const SizedBox(height: 16),
              _StatusSummaryCard(dashboard: dashboard),
            ]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Force count grid
// ---------------------------------------------------------------------------

class _ForceCountGrid extends ConsumerWidget {
  const _ForceCountGrid({required this.dashboard});

  final TakDashboardState dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Force Disposition',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ForceCountCell(
                label: 'Friendly',
                count: dashboard.friendlyCount,
                color: CotAffiliationColors.friendly,
                affiliation: CotAffiliation.friendly,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ForceCountCell(
                label: 'Hostile',
                count: dashboard.hostileCount,
                color: CotAffiliationColors.hostile,
                affiliation: CotAffiliation.hostile,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ForceCountCell(
                label: 'Neutral',
                count: dashboard.neutralCount,
                color: CotAffiliationColors.neutral,
                affiliation: CotAffiliation.neutral,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ForceCountCell(
                label: 'Unknown',
                count: dashboard.unknownCount,
                color: CotAffiliationColors.unknown,
                affiliation: CotAffiliation.unknown,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ForceCountCell extends ConsumerWidget {
  const _ForceCountCell({
    required this.label,
    required this.count,
    required this.color,
    required this.affiliation,
  });

  final String label;
  final int count;
  final Color color;
  final CotAffiliation affiliation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.haptics.itemSelect();
        // Set filter to this affiliation, then navigate to TakScreen.
        final notifier = ref.read(takFilterProvider.notifier);
        notifier.clearAll();
        notifier.toggleAffiliation(affiliation);
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const TakScreen()));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Threat proximity card
// ---------------------------------------------------------------------------

class _ThreatProximityCard extends ConsumerWidget {
  const _ThreatProximityCard({required this.dashboard});

  final TakDashboardState dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Threat Proximity',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _ProximityRow(
            icon: Icons.warning_amber_rounded,
            iconColor: CotAffiliationColors.hostile,
            label: dashboard.nearestHostile != null
                ? 'Nearest hostile: '
                      '${dashboard.nearestHostile!.callsign ?? dashboard.nearestHostile!.uid}'
                : 'No hostile contacts',
            distance: dashboard.nearestHostileDistanceKm,
            event: dashboard.nearestHostile,
          ),
          const SizedBox(height: 8),
          _ProximityRow(
            icon: Icons.help_outline,
            iconColor: CotAffiliationColors.unknown,
            label: dashboard.nearestUnknown != null
                ? 'Nearest unknown: '
                      '${dashboard.nearestUnknown!.callsign ?? dashboard.nearestUnknown!.uid}'
                : 'No unknown contacts',
            distance: dashboard.nearestUnknownDistanceKm,
            event: dashboard.nearestUnknown,
          ),
        ],
      ),
    );
  }
}

class _ProximityRow extends ConsumerWidget {
  const _ProximityRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.distance,
    this.event,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final double? distance;
  final TakEvent? event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: event != null
          ? () {
              ref.haptics.itemSelect();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TakNavigateScreen(
                    targetUid: event!.uid,
                    initialCallsign: event!.callsign ?? event!.uid,
                  ),
                ),
              );
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
            ),
          ),
          if (distance != null)
            Text(
              formatDistance(distance!),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status summary card
// ---------------------------------------------------------------------------

class _StatusSummaryCard extends StatelessWidget {
  const _StatusSummaryCard({required this.dashboard});

  final TakDashboardState dashboard;

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Connection status
          _StatusRow(
            icon: dashboard.isConnected ? Icons.link : Icons.link_off,
            iconColor: dashboard.isConnected ? Colors.green : Colors.grey,
            label: 'Connection',
            value: dashboard.isConnected ? 'Connected' : 'Disconnected',
          ),
          const SizedBox(height: 8),
          // Last event
          _StatusRow(
            icon: Icons.schedule,
            iconColor: context.textTertiary,
            label: 'Last event',
            value: dashboard.lastEventTime != null
                ? _relativeTime(dashboard.lastEventTime!)
                : 'None',
          ),
          const SizedBox(height: 8),
          // Total entities
          _StatusRow(
            icon: Icons.people_outline,
            iconColor: context.textTertiary,
            label: 'Total entities',
            value: '${dashboard.totalCount}',
          ),
          const SizedBox(height: 8),
          // Tracked entities
          _StatusRow(
            icon: Icons.visibility,
            iconColor: context.textTertiary,
            label: 'Tracked',
            value: '${dashboard.trackedCount}',
            subtitle: dashboard.trackedCallsigns.isNotEmpty
                ? dashboard.trackedCallsigns.join(', ')
                : null,
          ),
          const SizedBox(height: 8),
          // Stale entities
          _StatusRow(
            icon: dashboard.staleCount > 0
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            iconColor: dashboard.staleCount > 0 ? Colors.orange : Colors.green,
            label: 'Stale entities',
            value: '${dashboard.staleCount}',
          ),
          const SizedBox(height: 8),
          // Position publishing
          _StatusRow(
            icon: Icons.publish,
            iconColor: dashboard.isPublishing
                ? Colors.green
                : context.textTertiary,
            label: 'Position publishing',
            value: dashboard.isPublishing
                ? 'Active (${dashboard.publishIntervalSeconds}s)'
                : 'Disabled',
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.textSecondary),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
              ),
            ),
            if (subtitle != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  subtitle!,
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
