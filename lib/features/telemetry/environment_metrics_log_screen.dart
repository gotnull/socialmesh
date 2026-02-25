// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/edge_fade.dart';
import '../../core/widgets/datetime_picker_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

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
  const EnvironmentMetricsLogScreen({super.key});

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
    final start = await DatePickerSheet.show(
      context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      title: 'Start Date',
    );
    if (!mounted || start == null) return;

    final end = await DatePickerSheet.show(
      context,
      initialDate: _endDate ?? start,
      firstDate: start,
      lastDate: DateTime.now(),
      title: 'End Date',
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
    final logsAsync = ref.watch(environmentMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        title: 'Environment Metrics',
        actions: [
          if (_hasDateFilter)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear date filter',
              onPressed: _clearDateFilter,
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasDateFilter,
              child: const Icon(Icons.date_range),
            ),
            tooltip: 'Date range',
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
                  'Error: $e',
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

              // Pinned search + filter chips
              SliverPersistentHeader(
                pinned: true,
                delegate: SearchFilterHeaderDelegate(
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  onSearchChanged: (value) =>
                      safeSetState(() => _searchQuery = value),
                  hintText: 'Search by node',
                  textScaler: MediaQuery.textScalerOf(context),
                  rebuildKey: Object.hashAll([_activeFilter, ...counts.values]),
                  filterChips: [
                    for (final filter in _MetricFilter.values)
                      SectionFilterChip(
                        label: filter.label,
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
                    items: [
                      if (filtered.any((l) => l.temperature != null))
                        _LegendItem(
                          color: AppTheme.errorRed,
                          label: 'Temperature',
                        ),
                      if (filtered.any((l) => l.humidity != null))
                        _LegendItem(
                          color: AccentColors.cyan,
                          label: 'Humidity',
                        ),
                    ],
                    readingsCount: filtered.length,
                  ),
                ),

              // Chart — always visible when there is data (matches
              // Android BaseMetricScreen / iOS EnvironmentMetricsLog).
              if (filtered.length >= 2)
                SliverToBoxAdapter(
                  child: _EnvironmentMetricsChart(logs: filtered),
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
                                ? 'No metrics match filters'
                                : 'No environment metrics yet',
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
                                ? 'Try adjusting your search or filters'
                                : 'Metrics will appear when your device reports telemetry',
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
                              label: const Text('Clear all filters'),
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
                      final nodeName =
                          nodes[log.nodeNum]?.displayName ??
                          '!${log.nodeNum.toRadixString(16).toUpperCase()}';
                      return _EnvironmentMetricsCard(
                        log: log,
                        nodeName: nodeName,
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

  const _EnvironmentMetricsCard({required this.log, required this.nodeName});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm:ss');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — node name + timestamp
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
                ),
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
                    label: '${log.temperature!.toStringAsFixed(1)}°C',
                    color: _getTemperatureColor(log.temperature!),
                  ),
                if (log.humidity != null)
                  _MetricChip(
                    icon: Icons.water_drop,
                    label: '${log.humidity!.toStringAsFixed(1)}%',
                    color: AccentColors.cyan,
                  ),
                if (log.barometricPressure != null)
                  _MetricChip(
                    icon: Icons.compress,
                    label: '${log.barometricPressure!.toStringAsFixed(1)} hPa',
                    color: AppTheme.primaryPurple,
                  ),
                if (log.gasResistance != null)
                  _MetricChip(
                    icon: Icons.air,
                    label: '${log.gasResistance!.toStringAsFixed(0)} Ω',
                    color: AccentColors.green,
                  ),
                if (log.iaq != null)
                  _MetricChip(
                    icon: Icons.eco,
                    label: 'IAQ ${log.iaq}',
                    color: _getIaqColor(log.iaq!),
                  ),
                if (log.lux != null)
                  _MetricChip(
                    icon: Icons.light_mode,
                    label: '${log.lux!.toStringAsFixed(0)} lux',
                    color: AppTheme.warningYellow,
                  ),
                if (log.windSpeed != null)
                  _MetricChip(
                    icon: Icons.wind_power,
                    label: '${log.windSpeed!.toStringAsFixed(1)} m/s',
                    color: AppTheme.primaryBlue,
                  ),
              ],
            ),
          ],
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

  const _EnvironmentMetricsChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    // Sort oldest → newest for left-to-right rendering.
    final sorted = List<EnvironmentMetricsLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Build per-metric spot lists.
    // Left axis: temperature (°C). Right axis: humidity (%).
    // Pressure is excluded from chart — range (e.g. 1000–1030 hPa) would
    // compress the other lines. Shown only in cards.
    final tempSpots = <FlSpot>[];
    final humiditySpots = <FlSpot>[];
    double tMin = double.infinity;
    double tMax = double.negativeInfinity;

    for (int i = 0; i < sorted.length; i++) {
      final log = sorted[i];
      final x = i.toDouble();
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
                                '${actual.toStringAsFixed(0)}°C',
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
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: math.max(1, sorted.length / 5),
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= sorted.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('HH:mm').format(sorted[idx].timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    maxContentWidth: 180,
                    getTooltipColor: (_) => context.card,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final idx = spot.x.toInt().clamp(0, sorted.length - 1);
                      final log = sorted[idx];
                      final color = spot.bar.color ?? context.textPrimary;
                      final isTemp = color == AppTheme.errorRed;
                      final display = isTemp
                          ? '${((spot.y / 100) * tRange + tAxisMin).toStringAsFixed(1)}°C'
                          : '${spot.y.toStringAsFixed(1)}%';
                      return LineTooltipItem(
                        '$display\n${DateFormat('MMM d HH:mm').format(log.timestamp)}',
                        TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
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
                  '$readingsCount readings',
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
