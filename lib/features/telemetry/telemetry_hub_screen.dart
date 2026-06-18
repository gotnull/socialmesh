// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../routes/routes_screen.dart';
import 'air_quality_log_screen.dart';
import 'detection_sensor_log_screen.dart';
import 'device_metrics_log_screen.dart';
import 'environment_metrics_log_screen.dart';
import 'pax_counter_log_screen.dart';
import 'position_log_screen.dart';
import 'power_metrics_log_screen.dart';
import 'traceroute_log_screen.dart';

/// Top-level hub screen that collects every telemetry log screen behind a
/// single drawer entry ("Tools > Telemetry").
///
/// Mirrors the tiles already rendered under Settings > Telemetry Logs but
/// surfaces them outside the Settings catalogue, since these screens host
/// rich visualisations, not configuration.
class TelemetryHubScreen extends StatelessWidget {
  const TelemetryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.telemetryHubTitle,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: Text(
              l10n.telemetryHubSubtitle,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ),
        ),
        SliverList.list(
          children: [
            _SectionHeader(title: l10n.settingsSectionTelemetryLogs),
            _TelemetryHubTile(
              icon: Icons.battery_charging_full,
              title: l10n.settingsTileDeviceMetricsTitle,
              subtitle: l10n.settingsTileDeviceMetricsSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DeviceMetricsLogScreen(),
                ),
              ),
            ),
            _TelemetryHubTile(
              icon: Icons.thermostat,
              title: l10n.settingsTileEnvironmentMetricsTitle,
              subtitle: l10n.settingsTileEnvironmentMetricsSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const EnvironmentMetricsLogScreen(),
                ),
              ),
            ),
            _TelemetryHubTile(
              icon: Icons.air,
              title: l10n.settingsTileAirQualityTitle,
              subtitle: l10n.settingsTileAirQualitySubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AirQualityLogScreen(),
                ),
              ),
            ),
            _TelemetryHubTile(
              icon: Icons.bolt,
              title: l10n.settingsTilePowerMetricsTitle,
              subtitle: l10n.settingsTilePowerMetricsSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PowerMetricsLogScreen(),
                ),
              ),
            ),
            _TelemetryHubTile(
              icon: Icons.location_on_outlined,
              title: l10n.settingsTilePositionHistoryTitle,
              subtitle: l10n.settingsTilePositionHistorySubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PositionLogScreen(),
                ),
              ),
            ),
            _TelemetryHubTile(
              icon: Icons.timeline,
              title: l10n.settingsTileTracerouteHistoryTitle,
              subtitle: l10n.settingsTileTracerouteHistorySubtitle,
              onTap: () => TraceRouteLogScreen.open(context),
            ),
            _TelemetryHubTile(
              icon: Icons.people_alt_outlined,
              title: l10n.settingsTilePaxCounterLogsTitle,
              subtitle: l10n.settingsTilePaxCounterLogsSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const PaxCounterLogScreen(),
                ),
              ),
            ),
            _TelemetryHubTile(
              icon: Icons.sensors,
              title: l10n.settingsTileDetectionSensorLogsTitle,
              subtitle: l10n.settingsTileDetectionSensorLogsSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DetectionSensorLogScreen(),
                ),
              ),
            ),
            _TelemetryHubTile(
              icon: Icons.route,
              title: l10n.settingsTileRoutesTitle,
              subtitle: l10n.settingsTileRoutesSubtitle,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const RoutesScreen()),
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _TelemetryHubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TelemetryHubTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(icon, color: context.textSecondary),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      subtitle,
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
