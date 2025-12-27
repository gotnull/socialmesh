import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme.dart';
import '../../models/telemetry_log.dart';
import '../../providers/splash_mesh_provider.dart';
import '../../providers/telemetry_providers.dart';
import '../../providers/app_providers.dart';

/// Environment metrics history screen with filtering and graph views
class EnvironmentMetricsLogScreen extends ConsumerStatefulWidget {
  const EnvironmentMetricsLogScreen({super.key});

  @override
  ConsumerState<EnvironmentMetricsLogScreen> createState() =>
      _EnvironmentMetricsLogScreenState();
}

class _EnvironmentMetricsLogScreenState
    extends ConsumerState<EnvironmentMetricsLogScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showGraph = false;
  _GraphMetric _selectedMetric = _GraphMetric.temperature;

  List<EnvironmentMetricsLog> _filterLogs(List<EnvironmentMetricsLog> logs) {
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

  bool get _hasActiveFilters => _startDate != null || _endDate != null;

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(environmentMetricsLogsProvider);
    final nodes = ref.watch(nodesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Environment'),
        actions: [
          if (_hasActiveFilters)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filters',
              onPressed: _clearFilters,
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              child: const Icon(Icons.date_range),
            ),
            tooltip: 'Date range',
            onPressed: _selectDateRange,
          ),
          IconButton(
            icon: Icon(_showGraph ? Icons.list : Icons.show_chart),
            tooltip: _showGraph ? 'List view' : 'Graph view',
            onPressed: () => setState(() => _showGraph = !_showGraph),
          ),
        ],
      ),
      body: SafeArea(
        child: logsAsync.when(
          loading: () => const ScreenLoadingIndicator(),
          error: (e, s) => Center(child: Text('Error: $e')),
          data: (logs) {
            final filtered = _filterLogs(logs)
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

            if (filtered.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.thermostat,
                      size: 64,
                      color: context.textTertiary,
                    ),
                    SizedBox(height: 16),
                    Text(
                      _hasActiveFilters
                          ? 'No metrics match filters'
                          : 'No environment history',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ],
                ),
              );
            }

            if (_showGraph) {
              return _EnvironmentGraphView(
                logs: filtered,
                selectedMetric: _selectedMetric,
                onMetricChanged: (m) => setState(() => _selectedMetric = m),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final log = filtered[index];
                final nodeName =
                    nodes[log.nodeNum]?.displayName ??
                    '!${log.nodeNum.toRadixString(16).toUpperCase()}';

                return _EnvironmentMetricsCard(log: log, nodeName: nodeName);
              },
            );
          },
        ),
      ),
    );
  }
}

enum _GraphMetric {
  temperature('Temp', '°C', Icons.thermostat),
  humidity('Humid', '%', Icons.water_drop),
  pressure('Press', 'hPa', Icons.compress);

  final String label;
  final String unit;
  final IconData icon;

  const _GraphMetric(this.label, this.unit, this.icon);
}

class _EnvironmentGraphView extends StatelessWidget {
  final List<EnvironmentMetricsLog> logs;
  final _GraphMetric selectedMetric;
  final ValueChanged<_GraphMetric> onMetricChanged;

  const _EnvironmentGraphView({
    required this.logs,
    required this.selectedMetric,
    required this.onMetricChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Prepare data points sorted by time
    final sortedLogs = List<EnvironmentMetricsLog>.from(logs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final spots = <FlSpot>[];
    double? minY;
    double? maxY;

    for (int i = 0; i < sortedLogs.length; i++) {
      final log = sortedLogs[i];
      double? value;

      switch (selectedMetric) {
        case _GraphMetric.temperature:
          value = log.temperature;
        case _GraphMetric.humidity:
          value = log.humidity;
        case _GraphMetric.pressure:
          value = log.barometricPressure;
      }

      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
        minY = minY == null ? value : math.min(minY, value);
        maxY = maxY == null ? value : math.max(maxY, value);
      }
    }

    // Add padding to Y range
    final yPadding = spots.isNotEmpty ? ((maxY ?? 0) - (minY ?? 0)) * 0.1 : 0.0;
    minY = (minY ?? 0) - yPadding;
    maxY = (maxY ?? 100) + yPadding;

    return Column(
      children: [
        // Metric selector - always visible with scrollable tabs
        Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_GraphMetric>(
              segments: _GraphMetric.values
                  .map(
                    (m) => ButtonSegment(
                      value: m,
                      label: Text(m.label),
                      icon: Icon(m.icon),
                    ),
                  )
                  .toList(),
              selected: {selectedMetric},
              onSelectionChanged: (s) => onMetricChanged(s.first),
            ),
          ),
        ),

        // Show empty state if no data for selected metric
        if (spots.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selectedMetric.icon,
                    size: 48,
                    color: context.textTertiary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No ${selectedMetric.label.toLowerCase()} data',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Try selecting a different metric',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Stats summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _StatsRow(logs: sortedLogs, metric: selectedMetric),
          ),

          SizedBox(height: 16),

          // Graph
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 24, 16),
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: ((maxY - minY) / 4).clamp(1, 100),
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: context.border.withValues(alpha: 0.5),
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
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: math.max(1, spots.length / 6),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= sortedLogs.length) {
                            return const SizedBox.shrink();
                          }
                          final log = sortedLogs[index];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('HH:mm').format(log.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: context.textTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: ((maxY - minY) / 4).clamp(1, 100),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toStringAsFixed(1)}${selectedMetric.unit}',
                            style: TextStyle(
                              fontSize: 10,
                              color: context.textTertiary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: _getMetricColor(selectedMetric),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: spots.length < 30,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 3,
                              color: Colors.white,
                              strokeWidth: 2,
                              strokeColor: _getMetricColor(selectedMetric),
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _getMetricColor(
                              selectedMetric,
                            ).withValues(alpha: 0.3),
                            _getMetricColor(
                              selectedMetric,
                            ).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => context.card,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          final index = spot.x.toInt();
                          final log = sortedLogs[index];
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(1)}${selectedMetric.unit}\n${DateFormat('MMM d HH:mm').format(log.timestamp)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getMetricColor(_GraphMetric metric) {
    switch (metric) {
      case _GraphMetric.temperature:
        return AppTheme.errorRed;
      case _GraphMetric.humidity:
        return AccentColors.cyan;
      case _GraphMetric.pressure:
        return AppTheme.primaryPurple;
    }
  }
}

class _StatsRow extends StatelessWidget {
  final List<EnvironmentMetricsLog> logs;
  final _GraphMetric metric;

  const _StatsRow({required this.logs, required this.metric});

  @override
  Widget build(BuildContext context) {
    final values = <double>[];
    for (final log in logs) {
      double? value;
      switch (metric) {
        case _GraphMetric.temperature:
          value = log.temperature;
        case _GraphMetric.humidity:
          value = log.humidity;
        case _GraphMetric.pressure:
          value = log.barometricPressure;
      }
      if (value != null) values.add(value);
    }

    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

    final min = values.reduce(math.min);
    final max = values.reduce(math.max);
    final avg = values.reduce((a, b) => a + b) / values.length;
    final current = values.last;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            label: 'Current',
            value: '${current.toStringAsFixed(1)}${metric.unit}',
            color: Theme.of(context).colorScheme.primary,
          ),
          _StatItem(
            label: 'Avg',
            value: '${avg.toStringAsFixed(1)}${metric.unit}',
            color: context.textSecondary,
          ),
          _StatItem(
            label: 'Min',
            value: '${min.toStringAsFixed(1)}${metric.unit}',
            color: AccentColors.cyan,
          ),
          _StatItem(
            label: 'Max',
            value: '${max.toStringAsFixed(1)}${metric.unit}',
            color: AppTheme.errorRed,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _EnvironmentMetricsCard extends StatelessWidget {
  final EnvironmentMetricsLog log;
  final String nodeName;

  const _EnvironmentMetricsCard({required this.log, required this.nodeName});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final timeFormat = DateFormat('HH:mm:ss');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.thermostat,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nodeName,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${dateFormat.format(log.timestamp)} ${timeFormat.format(log.timestamp)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Metrics
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (log.temperature != null)
                  _MetricChip(
                    icon: Icons.thermostat,
                    label: 'Temperature',
                    value: '${log.temperature!.toStringAsFixed(1)}°C',
                    color: _getTemperatureColor(log.temperature!),
                  ),
                if (log.humidity != null)
                  _MetricChip(
                    icon: Icons.water_drop,
                    label: 'Humidity',
                    value: '${log.humidity!.toStringAsFixed(1)}%',
                    color: AccentColors.cyan,
                  ),
                if (log.barometricPressure != null)
                  _MetricChip(
                    icon: Icons.compress,
                    label: 'Pressure',
                    value: '${log.barometricPressure!.toStringAsFixed(1)} hPa',
                    color: AppTheme.primaryPurple,
                  ),
                if (log.gasResistance != null)
                  _MetricChip(
                    icon: Icons.air,
                    label: 'Gas',
                    value: '${log.gasResistance!.toStringAsFixed(0)} Ω',
                    color: context.textTertiary,
                  ),
                if (log.iaq != null)
                  _MetricChip(
                    icon: Icons.eco,
                    label: 'IAQ',
                    value: '${log.iaq}',
                    color: _getIaqColor(log.iaq!),
                  ),
                if (log.lux != null)
                  _MetricChip(
                    icon: Icons.light_mode,
                    label: 'Light',
                    value: '${log.lux!.toStringAsFixed(0)} lux',
                    color: AppTheme.warningYellow,
                  ),
                if (log.windSpeed != null)
                  _MetricChip(
                    icon: Icons.wind_power,
                    label: 'Wind',
                    value: '${log.windSpeed!.toStringAsFixed(1)} m/s',
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

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
