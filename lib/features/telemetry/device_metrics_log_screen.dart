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
import '../../core/widgets/datetime_picker_sheet.dart';
import '../../core/widgets/edge_fade.dart';
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
  battery('Battery', Icons.battery_full),
  voltage('Voltage', Icons.bolt),
  channel('Channel', Icons.signal_cellular_alt),
  airUtil('Air Util', Icons.wifi),
  uptime('Uptime', Icons.timer);

  final String label;
  final IconData? icon;

  const _MetricFilter(this.label, this.icon);
}

// =============================================================================
// Screen
// =============================================================================

/// Device metrics history screen — battery, voltage, utilization logs.
///
/// Follows the standard screen architecture:
/// GlassScaffold → pinned SearchFilterHeaderDelegate → chart → SliverList.
/// Always-visible multi-metric overlay chart (matching Android/iOS reference
/// apps) sits between the filter header and the card list. All metrics are
/// overlaid on a single chart: battery / channel util / air util share the
/// left 0–100 % axis; voltage uses the right axis.
/// Date-range filtering via app bar actions.
class DeviceMetricsLogScreen extends ConsumerStatefulWidget {
  const DeviceMetricsLogScreen({super.key});

  @override
  ConsumerState<DeviceMetricsLogScreen> createState() =>
      _DeviceMetricsLogScreenState();
}

class _DeviceMetricsLogScreenState extends ConsumerState<DeviceMetricsLogScreen>
    with LifecycleSafeMixin<DeviceMetricsLogScreen> {
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

  List<DeviceMetricsLog> _applyDateFilter(List<DeviceMetricsLog> logs) {
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

  List<DeviceMetricsLog> _applyMetricFilter(List<DeviceMetricsLog> logs) {
    return switch (_activeFilter) {
      _MetricFilter.all => logs,
      _MetricFilter.battery =>
        logs.where((l) => l.batteryLevel != null).toList(),
      _MetricFilter.voltage => logs.where((l) => l.voltage != null).toList(),
      _MetricFilter.channel =>
        logs.where((l) => l.channelUtilization != null).toList(),
      _MetricFilter.airUtil => logs.where((l) => l.airUtilTx != null).toList(),
      _MetricFilter.uptime =>
        logs.where((l) => l.uptimeSeconds != null).toList(),
    };
  }

  List<DeviceMetricsLog> _applySearch(
    List<DeviceMetricsLog> logs,
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

  int _countForFilter(List<DeviceMetricsLog> logs, _MetricFilter filter) {
    return switch (filter) {
      _MetricFilter.all => logs.length,
      _MetricFilter.battery => logs.where((l) => l.batteryLevel != null).length,
      _MetricFilter.voltage => logs.where((l) => l.voltage != null).length,
      _MetricFilter.channel =>
        logs.where((l) => l.channelUtilization != null).length,
      _MetricFilter.airUtil => logs.where((l) => l.airUtilTx != null).length,
      _MetricFilter.uptime => logs.where((l) => l.uptimeSeconds != null).length,
    };
  }

  Color? _colorForFilter(_MetricFilter filter) {
    return switch (filter) {
      _MetricFilter.all => null,
      _MetricFilter.battery => AccentColors.green,
      _MetricFilter.voltage => AppTheme.warningYellow,
      _MetricFilter.channel => AppTheme.primaryBlue,
      _MetricFilter.airUtil => AppTheme.primaryMagenta,
      _MetricFilter.uptime => AccentColors.cyan,
    };
  }

  // ---------------------------------------------------------------------------
  // Date range picker
  // ---------------------------------------------------------------------------

  // Uses DatePickerSheet, not banned Material dialogs.
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
    final logsAsync = ref.watch(deviceMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        title: 'Device Metrics',
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

              // Pinned chart legend — stays visible like a section header
              // while the chart + list scroll beneath it.
              if (filtered.length >= 2)
                () {
                  final legendItems = <Widget>[
                    if (filtered.any((l) => l.batteryLevel != null))
                      _LegendItem(color: AccentColors.green, label: 'Battery'),
                    if (filtered.any((l) => l.voltage != null))
                      _LegendItem(
                        color: AppTheme.warningYellow,
                        label: 'Voltage',
                      ),
                    if (filtered.any((l) => l.channelUtilization != null))
                      _LegendItem(
                        color: AppTheme.primaryBlue,
                        label: 'Ch Util',
                      ),
                    if (filtered.any((l) => l.airUtilTx != null))
                      _LegendItem(
                        color: AppTheme.primaryMagenta,
                        label: 'Air Util',
                      ),
                  ];
                  if (legendItems.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverPersistentHeader(
                    pinned: true,
                    delegate: _ChartLegendHeaderDelegate(
                      legendItems: legendItems,
                      readingsCount: filtered.length,
                    ),
                  );
                }(),

              // Chart — always visible when there is data (matches
              // Android BaseMetricScreen / iOS DeviceMetricsLog).
              if (filtered.length >= 2)
                SliverToBoxAdapter(child: _DeviceMetricsChart(logs: filtered)),

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
                              Icons.battery_unknown,
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
                                : 'No device metrics yet',
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
                      return _DeviceMetricsCard(log: log, nodeName: nodeName);
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
// Chart — all metrics overlaid, matching Android/iOS reference apps
// =============================================================================

class _DeviceMetricsChart extends StatelessWidget {
  final List<DeviceMetricsLog> logs;

  const _DeviceMetricsChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    // Sort oldest → newest for left-to-right rendering.
    final sorted = List<DeviceMetricsLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Build per-metric spot lists. Left axis: 0-100 %. Right axis: voltage.
    final batterySpots = <FlSpot>[];
    final chUtilSpots = <FlSpot>[];
    final airUtilSpots = <FlSpot>[];
    final voltageSpots = <FlSpot>[];
    double vMin = double.infinity;
    double vMax = double.negativeInfinity;

    for (int i = 0; i < sorted.length; i++) {
      final log = sorted[i];
      final x = i.toDouble();
      if (log.batteryLevel != null) {
        batterySpots.add(FlSpot(x, log.batteryLevel!.toDouble().clamp(0, 100)));
      }
      if (log.channelUtilization != null) {
        chUtilSpots.add(FlSpot(x, log.channelUtilization!.clamp(0, 100)));
      }
      if (log.airUtilTx != null) {
        airUtilSpots.add(FlSpot(x, log.airUtilTx!.clamp(0, 100)));
      }
      if (log.voltage != null) {
        voltageSpots.add(FlSpot(x, log.voltage!));
        vMin = math.min(vMin, log.voltage!);
        vMax = math.max(vMax, log.voltage!);
      }
    }

    final hasLeftAxis =
        batterySpots.isNotEmpty ||
        chUtilSpots.isNotEmpty ||
        airUtilSpots.isNotEmpty;
    final hasRightAxis = voltageSpots.isNotEmpty;

    if (!hasLeftAxis && !hasRightAxis) return const SizedBox.shrink();

    // Voltage axis padding
    final vPad = hasRightAxis ? ((vMax - vMin) * 0.15).clamp(0.1, 1.0) : 0.0;
    final vAxisMin = hasRightAxis ? vMin - vPad : 0.0;
    final vAxisMax = hasRightAxis ? vMax + vPad : 5.0;

    // Normalise voltage spots into 0–100 range to share the same Y space.
    final vRange = vAxisMax - vAxisMin;
    final normVoltageSpots = voltageSpots
        .map((s) => FlSpot(s.x, ((s.y - vAxisMin) / vRange) * 100))
        .toList();

    // Collect line bar data.
    final lineBars = <LineChartBarData>[
      if (batterySpots.length >= 2)
        _line(batterySpots, AccentColors.green, true),
      if (chUtilSpots.length >= 2)
        _line(chUtilSpots, AppTheme.primaryBlue, false),
      if (airUtilSpots.length >= 2)
        _line(airUtilSpots, AppTheme.primaryMagenta, false),
      if (normVoltageSpots.length >= 2)
        _line(normVoltageSpots, AppTheme.warningYellow, true),
    ];

    if (lineBars.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, 16, 0),
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
                  rightTitles: AxisTitles(
                    sideTitles: hasRightAxis
                        ? SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: 25,
                            getTitlesWidget: (value, _) {
                              final actual = (value / 100) * vRange + vAxisMin;
                              return Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  '${actual.toStringAsFixed(1)}V',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.warningYellow.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : const SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 25,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.textTertiary,
                        ),
                      ),
                    ),
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
                      // Reverse-map voltage from normalised value.
                      final isVoltage = color == AppTheme.warningYellow;
                      final display = isVoltage
                          ? '${((spot.y / 100) * vRange + vAxisMin).toStringAsFixed(2)}V'
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

          // Bottom spacing
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

// =============================================================================
// Pinned chart legend — frosted glass header matching SectionHeaderDelegate
// =============================================================================

/// Renders the chart legend (coloured dots + labels + readings count) as a
/// pinned sliver header with backdrop blur, matching [SectionHeaderDelegate].
class _ChartLegendHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<Widget> legendItems;
  final int readingsCount;

  _ChartLegendHeaderDelegate({
    required this.legendItems,
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
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    children: legendItems,
                  ),
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
    return readingsCount != oldDelegate.readingsCount ||
        legendItems.length != oldDelegate.legendItems.length;
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
// Card
// =============================================================================

class _DeviceMetricsCard extends StatelessWidget {
  final DeviceMetricsLog log;
  final String nodeName;

  const _DeviceMetricsCard({required this.log, required this.nodeName});

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
                Icon(Icons.memory, size: 16, color: context.accentColor),
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

            // Battery indicator
            if (log.batteryLevel != null) ...[
              Row(
                children: [
                  Icon(
                    _getBatteryIcon(log.batteryLevel!),
                    size: 20,
                    color: _getBatteryColor(log.batteryLevel!),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radius4),
                      child: LinearProgressIndicator(
                        value:
                            (log.batteryLevel! > 100
                                ? 100
                                : log.batteryLevel!) /
                            100,
                        backgroundColor: context.surface,
                        color: _getBatteryColor(log.batteryLevel!),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    log.batteryLevel! > 100
                        ? 'Charging'
                        : '${log.batteryLevel}%',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: _getBatteryColor(log.batteryLevel!),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
            ],

            // Metric chips — single-line pill layout matching SectionFilterChip
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (log.voltage != null)
                  _MetricChip(
                    icon: Icons.bolt,
                    label: '${log.voltage!.toStringAsFixed(2)}V',
                    color: AppTheme.warningYellow,
                  ),
                if (log.channelUtilization != null)
                  _MetricChip(
                    icon: Icons.signal_cellular_alt,
                    label: 'Ch ${log.channelUtilization!.toStringAsFixed(1)}%',
                    color: AppTheme.primaryBlue,
                  ),
                if (log.airUtilTx != null)
                  _MetricChip(
                    icon: Icons.wifi,
                    label: 'Air ${log.airUtilTx!.toStringAsFixed(1)}%',
                    color: AppTheme.primaryMagenta,
                  ),
                if (log.uptimeSeconds != null)
                  _MetricChip(
                    icon: Icons.timer,
                    label: _formatUptime(log.uptimeSeconds!),
                    color: AccentColors.cyan,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBatteryIcon(int level) {
    if (level > 100) return Icons.battery_charging_full;
    if (level <= 10) return Icons.battery_alert;
    if (level <= 20) return Icons.battery_1_bar;
    if (level <= 40) return Icons.battery_2_bar;
    if (level <= 60) return Icons.battery_4_bar;
    if (level <= 80) return Icons.battery_5_bar;
    return Icons.battery_full;
  }

  Color _getBatteryColor(int level) {
    if (level > 100) return AccentColors.cyan; // Charging
    if (level <= 10) return AppTheme.errorRed;
    if (level <= 20) return AccentColors.orange;
    if (level <= 40) return AppTheme.warningYellow;
    return AccentColors.green;
  }

  String _formatUptime(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
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
