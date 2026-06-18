// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/time_format.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Screen showing power metrics history — per-channel voltage and current
/// readings broadcast by nodes with a power-monitoring sensor (INA-style
/// multi-channel monitors).
///
/// Mirrors the air-quality / device-metrics log family: a node-scope label,
/// then a reverse-chronological list of reading cards. Power data is logged by
/// [TelemetryLoggerNotifier] but, until now, had no dedicated screen even
/// though device / environment / air-quality each do.
class PowerMetricsLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const PowerMetricsLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = nodeNum != null
        ? ref.watch(nodePowerMetricsLogsProvider(nodeNum!))
        : ref.watch(powerMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? context.l10n.telemetryAllNodes;

    return GlassScaffold(
      title: context.l10n.telemetryPowerMetricsTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing8,
          ),
          sliver: SliverToBoxAdapter(
            child: Text(
              nodeName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ),
        ),
        logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: _PowerEmptyState(),
              );
            }
            final sortedLogs = logs.reversed.toList();
            return SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final log = sortedLogs[index];
                  final name =
                      nodes[log.nodeNum]?.displayName ??
                      '!${log.nodeNum.toRadixString(16).toUpperCase()}';
                  return _PowerMetricsCard(log: log, nodeName: name);
                }, childCount: sortedLogs.length),
              ),
            );
          },
          loading: () =>
              const SliverFillRemaining(child: ScreenLoadingIndicator()),
          error: (e, _) => SliverFillRemaining(
            child: Center(
              child: Text(context.l10n.telemetryError(e.toString())),
            ),
          ),
        ),
      ],
    );
  }
}

/// Informative empty state: explains that power readings require a node with a
/// power-monitoring sensor, so an empty list reads as "expected" rather than
/// "broken". Matches the device-metrics empty-state visual language.
class _PowerEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius16),
              ),
              child: Icon(Icons.bolt, size: 40, color: context.textTertiary),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              context.l10n.telemetryPowerNoData,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.telemetryPowerNoDataDescription,
              style: TextStyle(fontSize: 14, color: context.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerMetricsCard extends StatelessWidget {
  final PowerMetricsLog log;
  final String nodeName;

  const _PowerMetricsCard({required this.log, required this.nodeName});

  @override
  Widget build(BuildContext context) {
    final timeFormat = AppTimeFormat.dateAndTime(context);
    final channels = <Widget>[
      if (log.ch1Voltage != null || log.ch1Current != null)
        _ChannelRow(
          channel: 1,
          voltage: log.ch1Voltage,
          current: log.ch1Current,
        ),
      if (log.ch2Voltage != null || log.ch2Current != null)
        _ChannelRow(
          channel: 2,
          voltage: log.ch2Voltage,
          current: log.ch2Current,
        ),
      if (log.ch3Voltage != null || log.ch3Current != null)
        _ChannelRow(
          channel: 3,
          voltage: log.ch3Voltage,
          current: log.ch3Current,
        ),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, size: 16, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: Text(
                  nodeName,
                  style: context.titleSmallStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                timeFormat.format(log.timestamp),
                style: context.bodySmallStyle?.copyWith(
                  color: context.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          ...channels,
        ],
      ),
    );
  }
}

/// One power channel's readings: channel label + voltage + current chips.
class _ChannelRow extends StatelessWidget {
  final int channel;
  final double? voltage;
  final double? current;

  const _ChannelRow({
    required this.channel,
    required this.voltage,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              context.l10n.telemetryPowerChannel(channel),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing8,
              children: [
                if (voltage != null)
                  _PowerChip(
                    icon: Icons.bolt,
                    label: context.l10n.telemetryDeviceMetricsVoltageValue(
                      voltage!.toStringAsFixed(2),
                    ),
                    color: AppTheme.warningYellow,
                  ),
                if (current != null)
                  _PowerChip(
                    icon: Icons.electric_meter,
                    label: context.l10n.telemetryPowerCurrentValue(
                      current!.toStringAsFixed(1),
                    ),
                    color: AppTheme.primaryBlue,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only data chip styled to match the device-metrics chips.
class _PowerChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _PowerChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
