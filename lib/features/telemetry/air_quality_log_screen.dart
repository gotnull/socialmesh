// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/time_format.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../models/mesh_models.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';
import '../map/map_screen.dart';
import 'air_quality_timeline.dart';

/// Screen showing air quality metrics history
class AirQualityLogScreen extends ConsumerWidget {
  final int? nodeNum;

  const AirQualityLogScreen({super.key, this.nodeNum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airAsync = nodeNum != null
        ? ref.watch(nodeAirQualityMetricsLogsProvider(nodeNum!))
        : ref.watch(airQualityMetricsLogsProvider);
    // Gas resistance rides in environment rows on the wire; merged into
    // this timeline so gas sensors appear under Air Quality too.
    final envAsync = nodeNum != null
        ? ref.watch(nodeEnvironmentMetricsLogsProvider(nodeNum!))
        : ref.watch(environmentMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final node = nodeNum != null ? nodes[nodeNum] : null;
    final nodeName = node?.displayName ?? context.l10n.telemetryAllNodes;

    return GlassScaffold(
      title: context.l10n.telemetryAirQualityTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        _buildLogsSliver(context, airAsync, envAsync, nodes),
      ],
    );
  }

  Widget _buildLogsSliver(
    BuildContext context,
    AsyncValue<List<AirQualityMetricsLog>> airAsync,
    AsyncValue<List<EnvironmentMetricsLog>> envAsync,
    Map<int, MeshNode> nodes,
  ) {
    if (airAsync.hasError || envAsync.hasError) {
      final error = airAsync.hasError ? airAsync.error : envAsync.error;
      return SliverFillRemaining(
        child: Center(
          child: Text(context.l10n.telemetryError(error.toString())),
        ),
      );
    }
    final airLogs = airAsync.value;
    final envLogs = envAsync.value;
    if (airLogs == null || envLogs == null) {
      return const SliverFillRemaining(child: ScreenLoadingIndicator());
    }

    final entries = buildAirQualityTimeline(airLogs, envLogs);
    if (entries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmptyState(context),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final entry = entries[index];
          final entryNode = nodes[entry.nodeNum];
          final entryNodeName =
              entryNode?.displayName ??
              '!${entry.nodeNum.toRadixString(16).toUpperCase()}';
          return _AirQualityCard(
            entry: entry,
            nodeName: entryNodeName,
            onShowOnMap: entryNode?.hasPosition == true
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(initialNodeNum: entry.nodeNum),
                    ),
                  )
                : null,
          );
        }, childCount: entries.length),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
              child: Icon(Icons.air, size: 40, color: context.textTertiary),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              context.l10n.telemetryAirQualityNoData,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.telemetryAirQualityNoDataDescription,
              style: TextStyle(fontSize: 14, color: context.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AirQualityCard extends StatelessWidget {
  final AirQualityTimelineEntry entry;
  final String nodeName;

  /// Non-null only when the sharing node has a usable position - the
  /// map centring silently no-ops without one, which reads as a broken
  /// tap.
  final VoidCallback? onShowOnMap;

  const _AirQualityCard({
    required this.entry,
    required this.nodeName,
    this.onShowOnMap,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = AppTimeFormat.dateAndTime(context);
    final log = entry.airQuality;

    final hasPmStandard =
        log != null &&
        (log.pm10Standard != null ||
            log.pm25Standard != null ||
            log.pm100Standard != null);
    final hasOtherAirQuality =
        log != null &&
        (hasPmStandard ||
            log.pm10Environmental != null ||
            log.pm25Environmental != null ||
            log.pm100Environmental != null ||
            log.particles03um != null ||
            log.particles05um != null ||
            log.particles10um != null ||
            log.particles25um != null ||
            log.particles50um != null ||
            log.particles100um != null ||
            log.co2 != null);
    final hasAnyAirSection = hasOtherAirQuality || log?.iaq != null;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header - sharing node + map affordance
        Row(
          children: [
            Icon(Icons.air, size: 16, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing8),
            Expanded(
              child: Text(
                nodeName,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onShowOnMap != null)
              Tooltip(
                message: context.l10n.telemetryShowOnMap,
                child: Icon(
                  Icons.map_outlined,
                  size: 16,
                  color: context.textTertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              timeFormat.format(entry.timestamp),
              style: context.bodySmallStyle?.copyWith(
                color: context.textTertiary,
              ),
            ),
            if (log?.pm25Standard != null)
              _AqiIndicator(pm25: log!.pm25Standard!),
          ],
        ),
        if (hasAnyAirSection || entry.gasResistance != null)
          const SizedBox(height: AppTheme.spacing16),

        if (log != null)
          ..._buildAirSections(
            context,
            log,
            hasPmStandard: hasPmStandard,
            hasOtherAirQuality: hasOtherAirQuality,
          ),

        // Gas resistance (BME680/688), merged from environment rows
        if (entry.gasResistance != null) ...[
          if (hasAnyAirSection) ...[
            const SizedBox(height: AppTheme.spacing12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: AppTheme.spacing12),
          ],
          _GasResistanceIndicator(ohms: entry.gasResistance!),
        ],
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onShowOnMap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: body,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAirSections(
    BuildContext context,
    AirQualityMetricsLog log, {
    required bool hasPmStandard,
    required bool hasOtherAirQuality,
  }) {
    return [
      // PM values
      if (hasPmStandard) ...[
        Text(
          context.l10n.telemetryAirQualityPmStandard,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Row(
          children: [
            if (log.pm10Standard != null)
              Expanded(
                child: _PmTile(
                  label: context.l10n.telemetryAirQualityPm10Label,
                  value: log.pm10Standard!,
                ),
              ),
            if (log.pm25Standard != null)
              Expanded(
                child: _PmTile(
                  label: context.l10n.telemetryAirQualityPm25Label,
                  value: log.pm25Standard!,
                  highlight: true,
                ),
              ),
            if (log.pm100Standard != null)
              Expanded(
                child: _PmTile(
                  label: context.l10n.telemetryAirQualityPm100Label,
                  value: log.pm100Standard!,
                ),
              ),
          ],
        ),
      ],

      // Environmental PM
      if (log.pm10Environmental != null || log.pm25Environmental != null) ...[
        const SizedBox(height: AppTheme.spacing12),
        Text(
          context.l10n.telemetryAirQualityPmEnvironmental,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Row(
          children: [
            if (log.pm10Environmental != null)
              Expanded(
                child: _PmTile(
                  label: context.l10n.telemetryAirQualityPm10Label,
                  value: log.pm10Environmental!,
                ),
              ),
            if (log.pm25Environmental != null)
              Expanded(
                child: _PmTile(
                  label: context.l10n.telemetryAirQualityPm25Label,
                  value: log.pm25Environmental!,
                ),
              ),
            if (log.pm100Environmental != null)
              Expanded(
                child: _PmTile(
                  label: context.l10n.telemetryAirQualityPm100Label,
                  value: log.pm100Environmental!,
                ),
              ),
          ],
        ),
      ],

      // Particle counts
      if (log.particles03um != null || log.particles05um != null) ...[
        const SizedBox(height: AppTheme.spacing12),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: AppTheme.spacing12),
        Text(
          context.l10n.telemetryAirQualityParticleCounts,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (log.particles03um != null)
              _ParticleChip(
                label: context.l10n.telemetryAirQualityParticle03um,
                count: log.particles03um!,
              ),
            if (log.particles05um != null)
              _ParticleChip(
                label: context.l10n.telemetryAirQualityParticle05um,
                count: log.particles05um!,
              ),
            if (log.particles10um != null)
              _ParticleChip(
                label: context.l10n.telemetryAirQualityParticle10um,
                count: log.particles10um!,
              ),
            if (log.particles25um != null)
              _ParticleChip(
                label: context.l10n.telemetryAirQualityParticle25um,
                count: log.particles25um!,
              ),
            if (log.particles50um != null)
              _ParticleChip(
                label: context.l10n.telemetryAirQualityParticle50um,
                count: log.particles50um!,
              ),
            if (log.particles100um != null)
              _ParticleChip(
                label: context.l10n.telemetryAirQualityParticle100um,
                count: log.particles100um!,
              ),
          ],
        ),
      ],

      // CO2
      if (log.co2 != null) ...[
        const SizedBox(height: AppTheme.spacing12),
        const Divider(color: Colors.white12, height: 1),
        const SizedBox(height: AppTheme.spacing12),
        _Co2Indicator(ppm: log.co2!),
      ],

      // IAQ (Indoor Air Quality index, from the BME680/688 VOC sensor)
      if (log.iaq != null) ...[
        if (hasOtherAirQuality) ...[
          const SizedBox(height: AppTheme.spacing12),
          const Divider(color: Colors.white12, height: 1),
        ],
        const SizedBox(height: AppTheme.spacing12),
        _IaqIndicator(iaq: log.iaq!),
      ],
    ];
  }
}

class _GasResistanceIndicator extends StatelessWidget {
  final double ohms;

  const _GasResistanceIndicator({required this.ohms});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.air, color: AccentColors.green, size: 24),
        const SizedBox(width: AppTheme.spacing12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.telemetryEnvGasResistanceValue(
                ohms.toStringAsFixed(0),
              ),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AccentColors.green,
              ),
            ),
            Text(
              context.l10n.telemetryAirQualityGasResistanceLabel,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AqiIndicator extends StatelessWidget {
  final int pm25;

  const _AqiIndicator({required this.pm25});

  Color _getAqiColor() {
    if (pm25 <= 12) return AccentColors.green;
    if (pm25 <= 35) return AppTheme.warningYellow;
    if (pm25 <= 55) return AccentColors.orange;
    if (pm25 <= 150) return AppTheme.errorRed;
    return const Color(0xFF8B008B); // Purple for hazardous
  }

  String _getAqiLabel(BuildContext context) {
    if (pm25 <= 12) return context.l10n.telemetryAqiGood;
    if (pm25 <= 35) return context.l10n.telemetryAqiModerate;
    if (pm25 <= 55) return context.l10n.telemetryAqiUnhealthySensitive;
    if (pm25 <= 150) return context.l10n.telemetryAqiUnhealthy;
    return context.l10n.telemetryAqiHazardous;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getAqiColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Text(
        _getAqiLabel(context),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _PmTile extends StatelessWidget {
  final String label;
  final int value;
  final bool highlight;

  const _PmTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(AppTheme.spacing8),
      decoration: BoxDecoration(
        color: highlight
            ? AccentColors.teal.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: highlight
            ? Border.all(color: AccentColors.teal.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: highlight ? AccentColors.teal : Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          Text(
            context.l10n.telemetryAirQualityUnitMicrogram,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticleChip extends StatelessWidget {
  final String label;
  final int count;

  const _ParticleChip({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _Co2Indicator extends StatelessWidget {
  final int ppm;

  const _Co2Indicator({required this.ppm});

  Color _getCo2Color() {
    if (ppm < 800) return AccentColors.green;
    if (ppm < 1000) return AppTheme.warningYellow;
    if (ppm < 2000) return AccentColors.orange;
    return AppTheme.errorRed;
  }

  String _getCo2Label(BuildContext context) {
    if (ppm < 800) return context.l10n.telemetryCo2Excellent;
    if (ppm < 1000) return context.l10n.telemetryCo2Good;
    if (ppm < 2000) return context.l10n.telemetryCo2Fair;
    return context.l10n.telemetryCo2Poor;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getCo2Color();
    return Row(
      children: [
        Icon(Icons.co2, color: color, size: 24),
        const SizedBox(width: AppTheme.spacing12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$ppm ppm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              context.l10n.telemetryCo2Label(_getCo2Label(context)),
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _IaqIndicator extends StatelessWidget {
  final int iaq;

  const _IaqIndicator({required this.iaq});

  Color _getIaqColor() {
    if (iaq <= 50) return AccentColors.green;
    if (iaq <= 100) return AccentColors.lime;
    if (iaq <= 150) return AppTheme.warningYellow;
    if (iaq <= 200) return AccentColors.orange;
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getIaqColor();
    return Row(
      children: [
        Icon(Icons.eco, color: color, size: 24),
        const SizedBox(width: AppTheme.spacing12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.telemetryEnvIaqValue(iaq.toString()),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            Text(
              context.l10n.widgetBuilderBindingIaqIndexDesc,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
