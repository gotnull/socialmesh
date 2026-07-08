// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/time_format.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/datetime_picker_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../core/widgets/time_series_axis.dart';
import '../../core/units/temperature_format.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';
import '../map/map_screen.dart';
import 'metric_chart_tooltip.dart';

// =============================================================================
// Filter enum
// =============================================================================

enum _MetricFilter {
  all('All', null),
  temperature('Temp', Icons.thermostat),
  humidity('Humidity', Icons.water_drop),
  pressure('Pressure', Icons.compress),
  gas('Gas', Icons.air),
  iaq('IAQ', Icons.eco),
  light('Light', Icons.light_mode),
  wind('Wind', Icons.wind_power);

  final String label;
  final IconData? icon;

  const _MetricFilter(this.label, this.icon);
}

// =============================================================================
// Screen
// =============================================================================

/// Environment metrics history screen — temperature, humidity, pressure logs.
///
/// Follows the standard screen architecture:
/// GlassScaffold → pinned SearchFilterHeaderDelegate → SliverList.
/// Date-range filtering via app bar actions.
class EnvironmentMetricsLogScreen extends ConsumerStatefulWidget {
  final int? nodeNum;

  const EnvironmentMetricsLogScreen({super.key, this.nodeNum});

  @override
  ConsumerState<EnvironmentMetricsLogScreen> createState() =>
      _EnvironmentMetricsLogScreenState();
}

class _EnvironmentMetricsLogScreenState
    extends ConsumerState<EnvironmentMetricsLogScreen>
    with LifecycleSafeMixin<EnvironmentMetricsLogScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _MetricFilter _activeFilter = _MetricFilter.all;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // ---------------------------------------------------------------------------
  // Filtering helpers
  // ---------------------------------------------------------------------------

  bool get _hasDateFilter => _startDate != null || _endDate != null;

  void _clearDateFilter() {
    safeSetState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  List<EnvironmentMetricsLog> _applyDateFilter(
    List<EnvironmentMetricsLog> logs,
  ) {
    return logs.where((log) {
      if (_startDate != null && log.timestamp.isBefore(_startDate!)) {
        return false;
      }
      if (_endDate != null &&
          log.timestamp.isAfter(_endDate!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  List<EnvironmentMetricsLog> _applyMetricFilter(
    List<EnvironmentMetricsLog> logs,
  ) {
    return switch (_activeFilter) {
      _MetricFilter.all => logs,
      _MetricFilter.temperature =>
        logs.where((l) => l.temperature != null).toList(),
      _MetricFilter.humidity => logs.where((l) => l.humidity != null).toList(),
      _MetricFilter.pressure =>
        logs.where((l) => l.barometricPressure != null).toList(),
      _MetricFilter.gas => logs.where((l) => l.gasResistance != null).toList(),
      _MetricFilter.iaq => logs.where((l) => l.iaq != null).toList(),
      _MetricFilter.light => logs.where((l) => l.lux != null).toList(),
      _MetricFilter.wind => logs.where((l) => l.windSpeed != null).toList(),
    };
  }

  List<EnvironmentMetricsLog> _applySearch(
    List<EnvironmentMetricsLog> logs,
    Map<int, dynamic> nodes,
  ) {
    if (_searchQuery.isEmpty) return logs;
    final query = _searchQuery.toLowerCase();
    return logs.where((log) {
      final node = nodes[log.nodeNum];
      final name =
          (node?.displayName as String?) ??
          '!${log.nodeNum.toRadixString(16).toUpperCase()}';
      return name.toLowerCase().contains(query) ||
          log.nodeNum.toString().contains(query);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Filter chip counts
  // ---------------------------------------------------------------------------

  int _countForFilter(List<EnvironmentMetricsLog> logs, _MetricFilter filter) {
    return switch (filter) {
      _MetricFilter.all => logs.length,
      _MetricFilter.temperature =>
        logs.where((l) => l.temperature != null).length,
      _MetricFilter.humidity => logs.where((l) => l.humidity != null).length,
      _MetricFilter.pressure =>
        logs.where((l) => l.barometricPressure != null).length,
      _MetricFilter.gas => logs.where((l) => l.gasResistance != null).length,
      _MetricFilter.iaq => logs.where((l) => l.iaq != null).length,
      _MetricFilter.light => logs.where((l) => l.lux != null).length,
      _MetricFilter.wind => logs.where((l) => l.windSpeed != null).length,
    };
  }

  List<Widget> _legendItemsFor(
    BuildContext context,
    _MetricFilter filter,
    List<EnvironmentMetricsLog> filtered,
  ) {
    final l10n = context.l10n;
    if (filter == _MetricFilter.all) {
      return [
        if (filtered.any((l) => l.temperature != null))
          _LegendItem(
            color: AppTheme.errorRed,
            label: l10n.telemetryEnvironmentLegendTemperature,
          ),
        if (filtered.any((l) => l.humidity != null))
          _LegendItem(
            color: AccentColors.cyan,
            label: l10n.telemetryEnvironmentLegendHumidity,
          ),
      ];
    }
    return [
      _LegendItem(
        color: _colorForFilter(filter) ?? context.accentColor,
        label: _legendLabelFor(context, filter),
      ),
    ];
  }

  String _legendLabelFor(BuildContext context, _MetricFilter filter) {
    final l10n = context.l10n;
    return switch (filter) {
      _MetricFilter.all => '',
      _MetricFilter.temperature => l10n.telemetryEnvironmentLegendTemperature,
      _MetricFilter.humidity => l10n.telemetryEnvironmentLegendHumidity,
      _MetricFilter.pressure => l10n.telemetryEnvironmentLegendPressure,
      _MetricFilter.gas => l10n.telemetryEnvironmentLegendGas,
      _MetricFilter.iaq => l10n.telemetryEnvironmentLegendIaq,
      _MetricFilter.light => l10n.telemetryEnvironmentLegendLight,
      _MetricFilter.wind => l10n.telemetryEnvironmentLegendWind,
    };
  }

  Color? _colorForFilter(_MetricFilter filter) {
    return switch (filter) {
      _MetricFilter.all => null,
      _MetricFilter.temperature => AppTheme.errorRed,
      _MetricFilter.humidity => AccentColors.cyan,
      _MetricFilter.pressure => AppTheme.primaryPurple,
      _MetricFilter.gas => AccentColors.green,
      _MetricFilter.iaq => AccentColors.lime,
      _MetricFilter.light => AppTheme.warningYellow,
      _MetricFilter.wind => AppTheme.primaryBlue,
    };
  }

  // ---------------------------------------------------------------------------
  // Date range picker
  // ---------------------------------------------------------------------------

  Future<void> _selectDateRange() async {
    final l10n = context.l10n;
    final start = await DatePickerSheet.show(
      context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      title: l10n.telemetryStartDate,
    );
    if (!mounted || start == null) return;

    final end = await DatePickerSheet.show(
      context,
      initialDate: _endDate ?? start,
      firstDate: start,
      lastDate: DateTime.now(),
      title: l10n.telemetryEndDate,
    );
    if (!mounted || end == null) return;

    safeSetState(() {
      _startDate = start;
      _endDate = end;
    });
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scopedNodeNum = widget.nodeNum;
    final units = ref.watch(measurementUnitsProvider);
    final logsAsync = scopedNodeNum != null
        ? ref.watch(nodeEnvironmentMetricsLogsProvider(scopedNodeNum))
        : ref.watch(environmentMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);
    final scopedNodeName = scopedNodeNum != null
        ? (nodes[scopedNodeNum]?.displayName ??
              '!${scopedNodeNum.toRadixString(16).toUpperCase()}')
        : null;

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        title: context.l10n.telemetryEnvironmentTitle,
        actions: [
          if (_hasDateFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: context.l10n.telemetryClearDateFilterTooltip,
              onPressed: _clearDateFilter,
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasDateFilter,
              child: const Icon(Icons.date_range),
            ),
            tooltip: context.l10n.telemetryDateRangeTooltip,
            onPressed: _selectDateRange,
          ),
        ],
        slivers: logsAsync.when(
          loading: () => [
            const SliverFillRemaining(child: ScreenLoadingIndicator()),
          ],
          error: (e, s) => [
            SliverFillRemaining(
              child: Center(
                child: Text(
                  context.l10n.telemetryError(e.toString()),
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            ),
          ],
          data: (logs) {
            // Apply date filter first (before counting chips).
            final dateLogs = _applyDateFilter(logs);

            // Compute per-filter counts on date-filtered set.
            final counts = {
              for (final f in _MetricFilter.values)
                f: _countForFilter(dateLogs, f),
            };

            // Apply metric filter + search.
            final filtered = _applySearch(_applyMetricFilter(dateLogs), nodes)
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

            return [
              // Top padding below the glass app bar
              const SliverToBoxAdapter(
                child: SizedBox(height: AppTheme.spacing8),
              ),

              // Scoped node name subtitle — only when filtering by a single node
              if (scopedNodeName != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    0,
                    AppTheme.spacing16,
                    AppTheme.spacing8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      scopedNodeName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ),

              // Pinned search + filter chips
              SliverPersistentHeader(
                pinned: true,
                delegate: SearchFilterHeaderDelegate(
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  onSearchChanged: (value) =>
                      safeSetState(() => _searchQuery = value),
                  hintText: context.l10n.telemetrySearchByNode,
                  textScaler: MediaQuery.textScalerOf(context),
                  rebuildKey: Object.hashAll([_activeFilter, ...counts.values]),
                  filterChips: [
                    for (final filter in _MetricFilter.values)
                      StatusFilterChip(
                        label: switch (filter) {
                          _MetricFilter.all => context.l10n.telemetryFilterAll,
                          _MetricFilter.temperature =>
                            context.l10n.telemetryEnvironmentFilterTemp,
                          _MetricFilter.humidity =>
                            context.l10n.telemetryEnvironmentFilterHumidity,
                          _MetricFilter.pressure =>
                            context.l10n.telemetryEnvironmentFilterPressure,
                          _MetricFilter.gas =>
                            context.l10n.telemetryEnvironmentFilterGas,
                          _MetricFilter.iaq =>
                            context.l10n.telemetryEnvironmentFilterIaq,
                          _MetricFilter.light =>
                            context.l10n.telemetryEnvironmentFilterLight,
                          _MetricFilter.wind =>
                            context.l10n.telemetryEnvironmentFilterWind,
                        },
                        count: counts[filter],
                        isSelected: _activeFilter == filter,
                        icon: filter.icon,
                        color: _colorForFilter(filter),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          safeSetState(() => _activeFilter = filter);
                        },
                      ),
                  ],
                ),
              ),

              // Pinned chart legend — frosted glass, stays visible while
              // the list scrolls beneath it (matching section header UX).
              if (filtered.length >= 2)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _ChartLegendHeaderDelegate(
                    items: _legendItemsFor(context, _activeFilter, filtered),
                    readingsCount: filtered.length,
                  ),
                ),

              // Chart — always visible when there is data (matches
              // Android BaseMetricScreen / iOS EnvironmentMetricsLog).
              if (filtered.length >= 2)
                SliverToBoxAdapter(
                  child: _EnvironmentMetricsChart(
                    logs: filtered,
                    activeFilter: _activeFilter,
                    units: units,
                  ),
                ),

              // Content — empty state or list
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
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
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius16,
                              ),
                            ),
                            child: Icon(
                              Icons.thermostat,
                              size: 40,
                              color: context.textTertiary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing24),
                          Text(
                            _hasDateFilter ||
                                    _activeFilter != _MetricFilter.all ||
                                    _searchQuery.isNotEmpty
                                ? context.l10n.telemetryNoMetricsMatchFilters
                                : context.l10n.telemetryEnvironmentNoMetrics,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: context.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppTheme.spacing8),
                          Text(
                            _hasDateFilter ||
                                    _activeFilter != _MetricFilter.all ||
                                    _searchQuery.isNotEmpty
                                ? context.l10n.telemetryTryAdjustingFilters
                                : context.l10n.telemetryMetricsWillAppear,
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_activeFilter != _MetricFilter.all ||
                              _searchQuery.isNotEmpty ||
                              _hasDateFilter) ...[
                            const SizedBox(height: AppTheme.spacing16),
                            FilledButton.icon(
                              onPressed: () {
                                _searchController.clear();
                                safeSetState(() {
                                  _searchQuery = '';
                                  _activeFilter = _MetricFilter.all;
                                  _startDate = null;
                                  _endDate = null;
                                });
                              },
                              icon: const Icon(Icons.filter_alt_off, size: 18),
                              label: Text(
                                context.l10n.telemetryClearAllFilters,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppTheme.spacing8),
                    itemBuilder: (context, index) {
                      final log = filtered[index];
                      final logNode = nodes[log.nodeNum];
                      final nodeName =
                          logNode?.displayName ??
                          '!${log.nodeNum.toRadixString(16).toUpperCase()}';
                      return _EnvironmentMetricsCard(
                        log: log,
                        nodeName: nodeName,
                        units: units,
                        onTap: logNode?.hasPosition == true
                            ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      MapScreen(initialNodeNum: log.nodeNum),
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),

              // Bottom safe-area padding
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 16,
                ),
              ),
            ];
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Card
// =============================================================================

class _EnvironmentMetricsCard extends StatelessWidget {
  final EnvironmentMetricsLog log;
  final String nodeName;
  final MeasurementUnits units;

  /// Non-null only when the sharing node has a usable position - the
  /// map centring silently no-ops without one, which reads as a broken
  /// tap.
  final VoidCallback? onTap;

  const _EnvironmentMetricsCard({
    required this.log,
    required this.nodeName,
    required this.units,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = AppTimeFormat.fullDate(context);
    final timeFormat = AppTimeFormat.timeWithSeconds(context);

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — node name + timestamp + map affordance
              Row(
                children: [
                  Icon(Icons.thermostat, size: 16, color: context.accentColor),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      nodeName,
                      style: Theme.of(context).textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${dateFormat.format(log.timestamp)} ${timeFormat.format(log.timestamp)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: AppTheme.spacing8),
                    Tooltip(
                      message: context.l10n.telemetryShowOnMap,
                      child: Icon(
                        Icons.map_outlined,
                        size: 16,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppTheme.spacing12),

              // Metric chips — single-line pill layout matching SectionFilterChip
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (log.temperature != null)
                    _MetricChip(
                      icon: Icons.thermostat,
                      label: formatTemperatureCelsius(
                        log.temperature!,
                        units,
                        context.l10n,
                      ),
                      color: _getTemperatureColor(log.temperature!),
                    ),
                  if (log.humidity != null)
                    _MetricChip(
                      icon: Icons.water_drop,
                      label: context.l10n.telemetryEnvHumidityValue(
                        log.humidity!.toStringAsFixed(1),
                      ),
                      color: AccentColors.cyan,
                    ),
                  if (log.barometricPressure != null)
                    _MetricChip(
                      icon: Icons.compress,
                      label: context.l10n.telemetryEnvPressureValue(
                        log.barometricPressure!.toStringAsFixed(1),
                      ),
                      color: AppTheme.primaryPurple,
                    ),
                  if (log.gasResistance != null)
                    _MetricChip(
                      icon: Icons.air,
                      label: context.l10n.telemetryEnvGasResistanceValue(
                        log.gasResistance!.toStringAsFixed(0),
                      ),
                      color: AccentColors.green,
                    ),
                  if (log.iaq != null)
                    _MetricChip(
                      icon: Icons.eco,
                      label: context.l10n.telemetryEnvIaqValue(
                        log.iaq!.toString(),
                      ),
                      color: _getIaqColor(log.iaq!),
                    ),
                  if (log.lux != null)
                    _MetricChip(
                      icon: Icons.light_mode,
                      label: context.l10n.telemetryEnvLuxValue(
                        log.lux!.toStringAsFixed(0),
                      ),
                      color: AppTheme.warningYellow,
                    ),
                  if (log.windSpeed != null)
                    _MetricChip(
                      icon: Icons.wind_power,
                      label: context.l10n.telemetryEnvWindSpeedValue(
                        log.windSpeed!.toStringAsFixed(1),
                      ),
                      color: AppTheme.primaryBlue,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTemperatureColor(double temp) {
    if (temp < 0) return AccentColors.cyan;
    if (temp < 15) return AccentColors.blue;
    if (temp < 25) return AccentColors.green;
    if (temp < 35) return AccentColors.orange;
    return AppTheme.errorRed;
  }

  Color _getIaqColor(int iaq) {
    if (iaq <= 50) return AccentColors.green;
    if (iaq <= 100) return AccentColors.lime;
    if (iaq <= 150) return AppTheme.warningYellow;
    if (iaq <= 200) return AccentColors.orange;
    return AppTheme.errorRed;
  }
}

// =============================================================================
// Chart — all metrics overlaid, matching Android/iOS reference apps
// =============================================================================

class _EnvironmentMetricsChart extends StatelessWidget {
  final List<EnvironmentMetricsLog> logs;
  final _MetricFilter activeFilter;
  final MeasurementUnits units;

  const _EnvironmentMetricsChart({
    required this.logs,
    required this.activeFilter,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    // Sort oldest → newest for left-to-right rendering.
    final sorted = List<EnvironmentMetricsLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (activeFilter != _MetricFilter.all) {
      return _buildSingleMetricChart(context, sorted, activeFilter);
    }

    // Overlay mode ("All" filter): temperature (left °C axis) +
    // humidity (right % axis), both normalised into a shared 0–100 range.
    // Pressure and other metrics are excluded — their ranges compress the
    // two lines. They render in the cards below instead.
    final tempSpots = <FlSpot>[];
    final humiditySpots = <FlSpot>[];
    double tMin = double.infinity;
    double tMax = double.negativeInfinity;

    // x = actual sample time (epoch ms), so gaps between readings render
    // proportionally instead of every reading getting an equal slot.
    for (final log in sorted) {
      final x = TimeSeriesAxis.xOf(log.timestamp);
      if (log.temperature != null) {
        tempSpots.add(FlSpot(x, log.temperature!));
        tMin = math.min(tMin, log.temperature!);
        tMax = math.max(tMax, log.temperature!);
      }
      if (log.humidity != null) {
        humiditySpots.add(FlSpot(x, log.humidity!));
      }
    }

    final hasTemp = tempSpots.length >= 2;
    final hasHumidity = humiditySpots.length >= 2;

    if (!hasTemp && !hasHumidity) return const SizedBox.shrink();

    // Explicit x-domain (previously implicit from the spots): duplicate
    // timestamps would otherwise hand fl_chart a zero-width span.
    final xDomain = TimeSeriesAxis.domainOf(
      sorted.first.timestamp,
      sorted.last.timestamp,
    );

    // Compute shared Y range. Humidity is 0-100%. Temperature is variable.
    // Normalise temperature into 0–100 range so both share the same Y space.
    final tPad = hasTemp ? ((tMax - tMin) * 0.15).clamp(1.0, 10.0) : 0.0;
    final tAxisMin = hasTemp ? tMin - tPad : 0.0;
    final tAxisMax = hasTemp ? tMax + tPad : 50.0;
    final tRange = tAxisMax - tAxisMin;

    final normTempSpots = tempSpots
        .map((s) => FlSpot(s.x, ((s.y - tAxisMin) / tRange) * 100))
        .toList();

    final lineBars = <LineChartBarData>[
      if (hasTemp) _line(normTempSpots, AppTheme.errorRed, true),
      if (hasHumidity) _line(humiditySpots, AccentColors.cyan, false),
    ];

    if (lineBars.isEmpty) return const SizedBox.shrink();

    // Legend is now pinned in _ChartLegendHeaderDelegate above.
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: xDomain.minX,
                maxX: xDomain.maxX,
                minY: 0,
                maxY: 100,
                lineBarsData: lineBars,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: hasTemp
                        ? SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            interval: 25,
                            getTitlesWidget: (value, _) {
                              final actual = (value / 100) * tRange + tAxisMin;
                              return Text(
                                formatTemperatureCelsiusAscii(
                                  actual,
                                  units,
                                  fractionDigits: 0,
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.errorRed.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              );
                            },
                          )
                        : const SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: hasHumidity
                        ? SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 25,
                            getTitlesWidget: (value, _) => Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                '${value.toInt()}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AccentColors.cyan.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: TimeSeriesAxis.bottomTitles(
                      context,
                      minX: xDomain.minX,
                      maxX: xDomain.maxX,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: metricTouchTooltipData(
                    context,
                    formatValue: (spot) {
                      final isTemp = spot.bar.color == AppTheme.errorRed;
                      return isTemp
                          ? formatTemperatureCelsiusAscii(
                              (spot.y / 100) * tRange + tAxisMin,
                              units,
                            )
                          : '${spot.y.toStringAsFixed(1)}%';
                    },
                    timestampOf: TimeSeriesAxis.timestampOfSpot,
                  ),
                ),
              ),
            ),
          ),

          // Bottom spacing (readings count is now in the pinned legend header)
          const SizedBox(height: AppTheme.spacing8),
        ],
      ),
    );
  }

  Widget _buildSingleMetricChart(
    BuildContext context,
    List<EnvironmentMetricsLog> sorted,
    _MetricFilter filter,
  ) {
    final spots = <FlSpot>[];
    double yMin = double.infinity;
    double yMax = double.negativeInfinity;
    // x = actual sample time (epoch ms), so gaps between readings render
    // proportionally instead of every reading getting an equal slot.
    for (final log in sorted) {
      final v = _valueOf(filter, log);
      if (v == null) continue;
      spots.add(FlSpot(TimeSeriesAxis.xOf(log.timestamp), v));
      yMin = math.min(yMin, v);
      yMax = math.max(yMax, v);
    }

    if (spots.length < 2) return const SizedBox.shrink();

    // Domain from the spot edges, not the sorted-list edges: logs at the
    // ends of the window may lack this metric and would add dead space.
    final xDomain = TimeSeriesAxis.domain(spots.first.x, spots.last.x);

    final color = _chartColorForFilter(filter);
    // Pad the Y axis a little so the peaks/valleys don't hug the edges.
    final range = yMax - yMin;
    final pad = range == 0 ? math.max(yMax.abs() * 0.05, 1.0) : range * 0.15;
    final axisMin = yMin - pad;
    final axisMax = yMax + pad;
    final axisRange = axisMax - axisMin;
    final interval = axisRange <= 0 ? 1.0 : axisRange / 4;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: xDomain.minX,
                maxX: xDomain.maxX,
                minY: axisMin,
                maxY: axisMax,
                lineBarsData: [_line(spots, color, true)],
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: context.border.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 56,
                      interval: interval,
                      getTitlesWidget: (value, _) => Text(
                        _formatAxisValue(filter, value, units),
                        style: TextStyle(
                          fontSize: 10,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: TimeSeriesAxis.bottomTitles(
                      context,
                      minX: xDomain.minX,
                      maxX: xDomain.maxX,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textTertiary,
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: metricTouchTooltipData(
                    context,
                    formatValue: (spot) =>
                        _formatTooltipValue(filter, spot.y, units),
                    timestampOf: TimeSeriesAxis.timestampOfSpot,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
        ],
      ),
    );
  }

  static double? _valueOf(_MetricFilter filter, EnvironmentMetricsLog log) {
    return switch (filter) {
      _MetricFilter.all => null,
      _MetricFilter.temperature => log.temperature,
      _MetricFilter.humidity => log.humidity,
      _MetricFilter.pressure => log.barometricPressure,
      _MetricFilter.gas => log.gasResistance,
      _MetricFilter.iaq => log.iaq?.toDouble(),
      _MetricFilter.light => log.lux,
      _MetricFilter.wind => log.windSpeed,
    };
  }

  static Color _chartColorForFilter(_MetricFilter filter) {
    return switch (filter) {
      _MetricFilter.all => AppTheme.errorRed,
      _MetricFilter.temperature => AppTheme.errorRed,
      _MetricFilter.humidity => AccentColors.cyan,
      _MetricFilter.pressure => AppTheme.primaryPurple,
      _MetricFilter.gas => AccentColors.green,
      _MetricFilter.iaq => AccentColors.lime,
      _MetricFilter.light => AppTheme.warningYellow,
      _MetricFilter.wind => AppTheme.primaryBlue,
    };
  }

  static String _formatAxisValue(
    _MetricFilter filter,
    double value,
    MeasurementUnits units,
  ) {
    return switch (filter) {
      _MetricFilter.temperature => formatTemperatureCelsiusAscii(
        value,
        units,
        fractionDigits: 0,
      ),
      _MetricFilter.humidity => '${value.toStringAsFixed(0)}%',
      _MetricFilter.pressure => '${value.toStringAsFixed(0)} hPa',
      _MetricFilter.gas => _formatLargeNumber(value, unit: 'Ω'),
      _MetricFilter.iaq => value.toStringAsFixed(0),
      _MetricFilter.light => _formatLargeNumber(value, unit: 'lx'),
      _MetricFilter.wind => '${value.toStringAsFixed(1)} m/s',
      _MetricFilter.all => value.toStringAsFixed(0),
    };
  }

  static String _formatTooltipValue(
    _MetricFilter filter,
    double value,
    MeasurementUnits units,
  ) {
    return switch (filter) {
      _MetricFilter.temperature => formatTemperatureCelsiusAscii(value, units),
      _MetricFilter.humidity => '${value.toStringAsFixed(1)}%',
      _MetricFilter.pressure => '${value.toStringAsFixed(1)} hPa',
      _MetricFilter.gas => _formatLargeNumber(value, unit: 'Ω', decimals: 2),
      _MetricFilter.iaq => value.toStringAsFixed(0),
      _MetricFilter.light => _formatLargeNumber(value, unit: 'lx', decimals: 1),
      _MetricFilter.wind => '${value.toStringAsFixed(1)} m/s',
      _MetricFilter.all => value.toStringAsFixed(1),
    };
  }

  static String _formatLargeNumber(
    double value, {
    required String unit,
    int decimals = 0,
  }) {
    final abs = value.abs();
    if (abs >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(decimals == 0 ? 1 : decimals)}M $unit';
    }
    if (abs >= 1e3) {
      return '${(value / 1e3).toStringAsFixed(decimals == 0 ? 1 : decimals)}k $unit';
    }
    return '${value.toStringAsFixed(decimals)} $unit';
  }

  /// Builds a [LineChartBarData] for a metric series.
  static LineChartBarData _line(
    List<FlSpot> spots,
    Color color,
    bool showArea,
  ) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.25,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: spots.length < 30,
        getDotPainter: (_, _, _, _) => FlDotCirclePainter(
          radius: 2,
          color: Colors.white,
          strokeWidth: 1.5,
          strokeColor: color,
        ),
      ),
      belowBarData: showArea
          ? BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.0),
                ],
              ),
            )
          : BarAreaData(show: false),
    );
  }
}

/// Colour dot + label used in the chart legend row.
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
      ],
    );
  }
}

// =============================================================================
// Pinned chart legend header — frosted glass, matches SectionHeaderDelegate
// =============================================================================

/// Persistent header delegate that pins the chart legend (coloured dots +
/// labels + readings count) above the chart and card list.
///
/// Uses the same frosted-glass + sticky-shadow treatment as
/// [SectionHeaderDelegate] so it feels native to the scroll view.
class _ChartLegendHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<Widget> items;
  final int readingsCount;

  _ChartLegendHeaderDelegate({
    required this.items,
    required this.readingsCount,
  });

  static const double _height = 40.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final showShadow = shrinkOffset > 0 || overlapsContent;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: StickyHeaderShadow(
          blurRadius: showShadow ? 8 : 0,
          offsetY: showShadow ? 2 : 0,
          child: Container(
            height: _height,
            color: context.background.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(spacing: 16, runSpacing: 4, children: items),
                ),
                Text(
                  context.l10n.telemetryReadingsCount(readingsCount),
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ChartLegendHeaderDelegate oldDelegate) {
    return items.length != oldDelegate.items.length ||
        readingsCount != oldDelegate.readingsCount;
  }
}

// =============================================================================
// Single-line metric chip — matches SectionFilterChip visual language
// =============================================================================

/// Read-only data chip styled to match [SectionFilterChip].
///
/// Single-line horizontal layout: icon + label text.
/// Pill shape, tinted background, subtle border — identical to the
/// design system chips used across Nodes, NodeDex, Channels, etc.
class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricChip({
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
