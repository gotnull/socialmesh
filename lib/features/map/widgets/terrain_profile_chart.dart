// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/los_analysis.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/terrain/elevation_service.dart';

/// Renders a terrain elevation cross-section with optional LOS and Fresnel
/// overlay when endpoint altitude data is available.
///
/// This widget is stateless and accepts pre-computed data. It has no async
/// behaviour and no Riverpod dependency.
///
/// The x-axis represents distance along the path (km). The y-axis represents
/// elevation (m). Optionally, a straight LOS line and ±60 % Fresnel zone band
/// are rendered when [losResult] is provided with [hasAltitudeData] == true.
class TerrainProfileChart extends StatelessWidget {
  /// Ordered elevation samples from [ElevationService].
  final List<ElevationSample> samples;

  /// Pre-computed terrain LOS result. Pass null for terrain-only display.
  final TerrainLosResult? losResult;

  const TerrainProfileChart({super.key, required this.samples, this.losResult});

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) return const SizedBox.shrink();

    final spots = _buildTerrainSpots();
    if (spots.isEmpty) return const SizedBox.shrink();

    final heights = spots.map((s) => s.y).toList();
    double minY = heights.reduce(math.min);
    double maxY = heights.reduce(math.max);

    // Expand range to include LOS line and Fresnel band if present.
    if (losResult != null && losResult!.hasAltitudeData) {
      for (final h in losResult!.losLineHeightsMeters) {
        minY = math.min(minY, h);
        maxY = math.max(maxY, h);
      }
      for (var i = 0; i < losResult!.perSampleFresnelRadiusMeters.length; i++) {
        final fresnelTop =
            losResult!.losLineHeightsMeters[i] +
            losResult!.perSampleFresnelRadiusMeters[i];
        final fresnelBot =
            losResult!.losLineHeightsMeters[i] -
            losResult!.perSampleFresnelRadiusMeters[i];
        maxY = math.max(maxY, fresnelTop);
        minY = math.min(minY, fresnelBot);
      }
    }

    // Ensure a minimum visible range of 20 m and add 10 % padding.
    final range = math.max(maxY - minY, 20.0);
    final padding = range * 0.10;
    minY = minY - padding;
    maxY = maxY + padding;

    final totalKm = samples.last.distanceMeters / 1000;
    final intervalX = _niceInterval(totalKm, 5);
    final intervalY = _niceInterval(maxY - minY, 5);

    final bars = <LineChartBarData>[
      // Terrain fill
      LineChartBarData(
        spots: spots,
        isCurved: false,
        color: _terrainLineColor(context),
        barWidth: 1.5,
        isStrokeCapRound: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _terrainFillColor(context).withValues(alpha: 0.45),
              _terrainFillColor(context).withValues(alpha: 0.10),
            ],
          ),
        ),
      ),
    ];

    // LOS + Fresnel overlay when altitude data is available.
    if (losResult != null && losResult!.hasAltitudeData) {
      final fresnelTopSpots = _buildFresnelBoundSpots(top: true);
      final fresnelBotSpots = _buildFresnelBoundSpots(top: false);
      final losSpots = _buildLosSpots();

      final fresnelColor = _fresnelColor(context, losResult!.verdict);

      // Fresnel upper bound (invisible line; fill above it goes to Fresnel bot)
      bars.add(
        LineChartBarData(
          spots: fresnelTopSpots,
          isCurved: false,
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            spotsLine: BarAreaSpotsLine(show: false),
            applyCutOffY: true,
            cutOffY: minY,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                fresnelColor.withValues(alpha: 0.18),
                fresnelColor.withValues(alpha: 0.18),
              ],
            ),
          ),
        ),
      );

      // Fresnel lower bound — fills below-band area with transparent color
      // so fl_chart's belowBarData from the upper bound is clipped.
      bars.add(
        LineChartBarData(
          spots: fresnelBotSpots,
          isCurved: false,
          color: Colors.transparent,
          barWidth: 0,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            spotsLine: BarAreaSpotsLine(show: false),
            color: Colors.transparent,
          ),
        ),
      );

      // LOS line itself
      bars.add(
        LineChartBarData(
          spots: losSpots,
          isCurved: false,
          color: _losLineColor(context, losResult!.verdict),
          barWidth: 2,
          dashArray: [6, 3],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: intervalY,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text(
                AppLocalizations.of(context).unitKm,
                style: TextStyle(fontSize: 10, color: _labelColor(context)),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: intervalX,
                getTitlesWidget: (value, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    value.toStringAsFixed(value < 10 ? 1 : 0),
                    style: TextStyle(fontSize: 9, color: _labelColor(context)),
                  ),
                ),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                AppLocalizations.of(context).unitM,
                style: TextStyle(fontSize: 10, color: _labelColor(context)),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: intervalY,
                getTitlesWidget: (value, _) => Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(fontSize: 9, color: _labelColor(context)),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: totalKm,
          minY: minY,
          maxY: maxY,
          lineBarsData: bars,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => Theme.of(context).cardColor,
              tooltipBorder: BorderSide(color: Theme.of(context).dividerColor),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  // Only show tooltip for the terrain series (index 0).
                  if (spot.barIndex != 0) {
                    return LineTooltipItem('', const TextStyle());
                  }
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(0)} m\n'
                    '${spot.x.toStringAsFixed(2)} km',
                    TextStyle(fontSize: 11, color: _terrainLineColor(context)),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> _buildTerrainSpots() {
    final spots = <FlSpot>[];
    for (final s in samples) {
      if (s.elevationMeters != null) {
        spots.add(FlSpot(s.distanceMeters / 1000, s.elevationMeters!));
      }
    }
    return spots;
  }

  List<FlSpot> _buildLosSpots() {
    final los = losResult;
    if (los == null) return [];
    final result = <FlSpot>[];
    for (
      var i = 0;
      i < samples.length && i < los.losLineHeightsMeters.length;
      i++
    ) {
      result.add(
        FlSpot(samples[i].distanceMeters / 1000, los.losLineHeightsMeters[i]),
      );
    }
    return result;
  }

  List<FlSpot> _buildFresnelBoundSpots({required bool top}) {
    final los = losResult;
    if (los == null) return [];
    final result = <FlSpot>[];
    for (
      var i = 0;
      i < samples.length &&
          i < los.losLineHeightsMeters.length &&
          i < los.perSampleFresnelRadiusMeters.length;
      i++
    ) {
      final h = los.losLineHeightsMeters[i];
      final r = los.perSampleFresnelRadiusMeters[i];
      result.add(FlSpot(samples[i].distanceMeters / 1000, top ? h + r : h - r));
    }
    return result;
  }

  /// Computes a round interval for axis labelling that yields approximately
  /// [targetDivisions] ticks across [range].
  static double _niceInterval(double range, int targetDivisions) {
    if (range <= 0) return 1;
    final raw = range / targetDivisions;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
    final normalized = raw / magnitude;
    double nice;
    if (normalized < 1.5) {
      nice = 1;
    } else if (normalized < 3) {
      nice = 2;
    } else if (normalized < 7) {
      nice = 5;
    } else {
      nice = 10;
    }
    return nice * magnitude.toDouble();
  }

  static Color _terrainLineColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? AccentColors.lime
        : ChartColors.gradientGreen;
  }

  static Color _terrainFillColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? ChartColors.gradientGreen
        : ChartColors.green;
  }

  static Color _labelColor(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6) ??
      SemanticColors.muted;

  static Color _losLineColor(BuildContext context, LosVerdict verdict) {
    return switch (verdict) {
      LosVerdict.clear => AppTheme.successGreen,
      LosVerdict.marginal => AppTheme.warningYellow,
      LosVerdict.obstructed => AppTheme.errorRed,
      LosVerdict.unknown => Theme.of(context).disabledColor,
    };
  }

  static Color _fresnelColor(BuildContext context, LosVerdict verdict) {
    return switch (verdict) {
      LosVerdict.clear => AppTheme.successGreen,
      LosVerdict.marginal => AppTheme.warningYellow,
      LosVerdict.obstructed => AppTheme.errorRed,
      LosVerdict.unknown => Theme.of(context).disabledColor,
    };
  }
}
