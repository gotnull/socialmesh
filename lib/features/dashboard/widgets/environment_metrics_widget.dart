// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../models/telemetry_log.dart';
import '../../../providers/telemetry_providers.dart';
import '../../telemetry/environment_metrics_log_screen.dart';
import 'dashboard_widget.dart';

/// Environment Metrics Widget — quick-access tile showing the most recent
/// environmental readings (temperature, humidity, pressure) across the mesh,
/// tapping anywhere opens the full environment metrics log screen.
class EnvironmentMetricsContent extends ConsumerWidget {
  const EnvironmentMetricsContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(environmentMetricsLogsProvider);

    return logsAsync.when(
      loading: () => const WidgetLoadingState(),
      error: (_, _) => WidgetEmptyState(
        icon: Icons.thermostat,
        message: context.l10n.telemetryEnvironmentNoMetrics,
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return InkWell(
            onTap: () => _openLogScreen(context),
            child: WidgetEmptyState(
              icon: Icons.thermostat,
              message: context.l10n.telemetryEnvironmentNoMetrics,
              actionLabel: context.l10n.dashboardEnvironmentMetricsOpenLog,
              onAction: () => _openLogScreen(context),
            ),
          );
        }

        final latest = logs.first;
        return InkWell(
          onTap: () => _openLogScreen(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: AppTheme.spacing8,
                  runSpacing: AppTheme.spacing8,
                  children: _readingTiles(context, latest),
                ),
                SizedBox(height: AppTheme.spacing10),
                Row(
                  children: [
                    Icon(Icons.history, size: 12, color: context.textTertiary),
                    SizedBox(width: AppTheme.spacing4),
                    Expanded(
                      child: Text(
                        context.l10n.dashboardEnvironmentMetricsUpdated(
                          _formatTimeAgo(context, latest.timestamp),
                        ),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                    Text(
                      context.l10n.dashboardEnvironmentMetricsViewAll,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.accentColor,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacing2),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: context.accentColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _readingTiles(BuildContext context, EnvironmentMetricsLog log) {
    final tiles = <Widget>[];
    if (log.temperature != null) {
      tiles.add(
        _ReadingChip(
          icon: Icons.thermostat,
          label: context.l10n.telemetryEnvironmentLegendTemperature,
          value: '${log.temperature!.toStringAsFixed(1)}°C',
        ),
      );
    }
    if (log.humidity != null) {
      tiles.add(
        _ReadingChip(
          icon: Icons.water_drop,
          label: context.l10n.telemetryEnvironmentLegendHumidity,
          value: '${log.humidity!.toStringAsFixed(0)}%',
        ),
      );
    }
    if (log.barometricPressure != null) {
      tiles.add(
        _ReadingChip(
          icon: Icons.compress,
          label: context.l10n.telemetryEnvironmentLegendPressure,
          value: '${log.barometricPressure!.toStringAsFixed(0)} hPa',
        ),
      );
    }
    if (log.iaq != null) {
      tiles.add(
        _ReadingChip(
          icon: Icons.eco,
          label: context.l10n.telemetryEnvironmentLegendIaq,
          value: '${log.iaq}',
        ),
      );
    }
    if (log.lux != null) {
      tiles.add(
        _ReadingChip(
          icon: Icons.light_mode,
          label: context.l10n.telemetryEnvironmentLegendLight,
          value: '${log.lux!.toStringAsFixed(0)} lx',
        ),
      );
    }
    if (log.windSpeed != null) {
      tiles.add(
        _ReadingChip(
          icon: Icons.wind_power,
          label: context.l10n.telemetryEnvironmentLegendWind,
          value: '${log.windSpeed!.toStringAsFixed(1)} m/s',
        ),
      );
    }
    return tiles;
  }

  String _formatTimeAgo(BuildContext context, DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return context.l10n.commonJustNow;
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _openLogScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const EnvironmentMetricsLogScreen(),
      ),
    );
  }
}

class _ReadingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadingChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: context.background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.accentColor),
          SizedBox(width: AppTheme.spacing6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
